import XCTest
@testable import zipzip_iOS

final class AuthenticationCoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        prepareAppDependencies()
    }

    func testCredentialRefreshLeeway() {
        let valid = AuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresAt: .now.addingTimeInterval(120)
        )
        let expiring = AuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresAt: .now.addingTimeInterval(30)
        )

        XCTAssertFalse(valid.requiresRefresh)
        XCTAssertTrue(expiring.requiresRefresh)
    }

    func testChallengeUsesUniqueBase64URLValues() throws {
        let first = try AppleSignInChallenge.make()
        let second = try AppleSignInChallenge.make()

        XCTAssertNotEqual(first, second)
        XCTAssertFalse(first.nonce.isEmpty)
        XCTAssertFalse(first.state.isEmpty)
        XCTAssertFalse(first.nonce.contains("+"))
        XCTAssertFalse(first.nonce.contains("/"))
        XCTAssertFalse(first.nonce.contains("="))
    }

    func testRedactorRemovesNestedSecrets() throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "accessToken": "access-secret",
            "nested": [
                "authorizationCode": "code-secret",
                "items": [["refreshToken": "refresh-secret"]]
            ],
            "displayName": "집집 사용자"
        ])

        let redacted = NetworkSecretRedactor.redactBody(body)

        XCTAssertFalse(redacted.contains("access-secret"))
        XCTAssertFalse(redacted.contains("code-secret"))
        XCTAssertFalse(redacted.contains("refresh-secret"))
        XCTAssertTrue(redacted.contains("집집 사용자"))
    }

    func testStoredAppleSessionWithoutDevelopmentKeyStillDecodes() throws {
        let encoded = try JSONEncoder().encode(sessionCredential())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "developmentUserKey")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(StoredSessionCredential.self, from: legacyData)

        XCTAssertNil(decoded.developmentUserKey)
        XCTAssertEqual(decoded.appleUserIdentifier, "apple-user")
    }

    #if DEBUG
        func testDevelopmentAuthFlagDefaultsToDisabled() {
            XCTAssertFalse(DevelopmentAuthConfiguration.isEnabled(nil))
            XCTAssertFalse(DevelopmentAuthConfiguration.isEnabled(""))
            XCTAssertFalse(DevelopmentAuthConfiguration.isEnabled("$(DEV_AUTH_ENABLED)"))
            XCTAssertFalse(DevelopmentAuthConfiguration.isEnabled("NO"))
            XCTAssertTrue(DevelopmentAuthConfiguration.isEnabled("YES"))
        }
    #endif

    @MainActor
    func testConcurrentRefreshUsesOneRequestAndPersistsRotation() async throws {
        let initial = StoredSessionCredential(
            credential: AuthCredential(
                accessToken: "old-access",
                refreshToken: "old-refresh",
                tokenType: "Bearer",
                expiresAt: .now.addingTimeInterval(3600)
            ),
            user: AuthUser(id: UUID(), displayName: "집집 사용자"),
            appleUserIdentifier: "apple-user"
        )
        let store = TestCredentialStore(initial: initial)
        let api = TestAuthAPI()
        let controller = SessionCredentialController(store: store, authAPI: api)
        _ = try await controller.restore()

        let first = Task { try await controller.refresh() }
        while api.refreshCount == 0 {
            await Task.yield()
        }
        let second = Task { try await controller.refresh() }
        let (firstValue, secondValue) = try await(first.value, second.value)

        let refreshCount = api.refreshCount
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(firstValue.credential.accessToken, "new-access")
        XCTAssertEqual(secondValue.credential.refreshToken, "new-refresh")
        XCTAssertEqual(firstValue.refreshTokenVersion, 1)
        let persisted = await store.credential
        XCTAssertEqual(persisted?.pendingRefreshIdempotencyKey, nil)
        XCTAssertEqual(persisted?.credential.refreshToken, "new-refresh")

        let lateReplacement = try await controller.credentialAfterUnauthorized(initial.credential)
        XCTAssertEqual(lateReplacement.accessToken, "new-access")
        XCTAssertEqual(api.refreshCount, 1)

        let terminationCredential = await controller.beginTermination()
        XCTAssertEqual(terminationCredential?.credential.accessToken, "new-access")
        do {
            _ = try await controller.credentialForRequest()
            XCTFail("종료 barrier 중에는 보호 요청 credential을 제공하면 안 됩니다.")
        } catch {
            XCTAssertEqual(error as? AuthSessionError, .staleOperation)
        }
        await controller.cancelTermination()
    }

    @MainActor
    func testReusedIdempotencyKeyBlocksAutomaticRefreshLoop() async throws {
        let initial = sessionCredential()
        let store = TestCredentialStore(initial: initial)
        let api = TestAuthAPI(
            error: .server(
                statusCode: 409,
                code: "IDEMPOTENCY_KEY_REUSED",
                message: "conflict",
                body: nil
            )
        )
        let controller = SessionCredentialController(store: store, authAPI: api)
        _ = try await controller.restore()

        do {
            _ = try await controller.refresh()
            XCTFail("충돌한 멱등성 키의 갱신은 실패해야 합니다.")
        } catch let error as NetworkError {
            XCTAssertEqual(error.serverCode, "IDEMPOTENCY_KEY_REUSED")
        }

        do {
            _ = try await controller.refresh()
            XCTFail("차단된 갱신을 자동 재호출하면 안 됩니다.")
        } catch let error as AuthSessionError {
            XCTAssertEqual(error, .refreshBlocked("IDEMPOTENCY_KEY_REUSED"))
        }
        XCTAssertEqual(api.refreshCount, 1)
        let blockedCode = await store.credential?.refreshBlockedCode
        XCTAssertEqual(blockedCode, "IDEMPOTENCY_KEY_REUSED")
    }

    @MainActor
    func testTerminationWaitIsBounded() async throws {
        let store = TestCredentialStore(initial: nil)
        let api = TestAuthAPI(delay: .seconds(1))
        let controller = SessionCredentialController(store: store, authAPI: api)
        _ = try await controller.commitLogin(
            response: expiringLoginResponse(),
            appleUserIdentifier: "apple-user"
        )
        let clock = ContinuousClock()
        let start = clock.now
        let snapshot = await controller.beginTermination(
            requiresFreshCredential: true,
            timeout: .milliseconds(50)
        )

        XCTAssertNil(snapshot)
        XCTAssertLessThan(start.duration(to: clock.now), .milliseconds(500))
        XCTAssertEqual(api.refreshCount, 1)
        let credentialAfterTimeout = await controller.current()
        XCTAssertNotEqual(credentialAfterTimeout?.credential.accessToken, "new-access")
        await controller.cancelTermination()
    }

    @MainActor
    func testTerminationStartsAndAwaitsRequiredRefresh() async throws {
        for requiresFreshCredential in [false, true] {
            let store = TestCredentialStore(initial: nil)
            let api = TestAuthAPI()
            let controller = SessionCredentialController(store: store, authAPI: api)
            _ = try await controller.commitLogin(
                response: expiringLoginResponse(),
                appleUserIdentifier: "apple-user"
            )

            let snapshot = await controller.beginTermination(
                requiresFreshCredential: requiresFreshCredential,
                timeout: .seconds(1)
            )

            XCTAssertEqual(snapshot?.credential.accessToken, "new-access")
            XCTAssertEqual(snapshot?.credential.refreshToken, "new-refresh")
            XCTAssertEqual(api.refreshCount, 1)
            await controller.cancelTermination()
        }
    }

    @MainActor
    func testLocalInvalidationMarkerPreventsRestoreWhenDeleteFails() async throws {
        let store = TestCredentialStore(initial: sessionCredential(), failsDelete: true)
        let api = TestAuthAPI()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        defaults.set(true, forKey: "zipzip.authentication.installation-marker")
        defaults.set(true, forKey: "zipzip.authentication.locally-invalidated")

        let firstController = SessionCredentialController(store: store, authAPI: api)
        let firstState = AuthenticationState(
            authAPI: api,
            credentialController: firstController,
            defaults: defaults
        )
        await firstState.restore()
        XCTAssertEqual(firstState.sessionPhase, .signedOut)
        let credentialAfterFirstRestore = await store.credential
        XCTAssertNotNil(credentialAfterFirstRestore)

        let secondController = SessionCredentialController(store: store, authAPI: api)
        let secondState = AuthenticationState(
            authAPI: api,
            credentialController: secondController,
            defaults: defaults
        )
        await secondState.restore()
        XCTAssertEqual(secondState.sessionPhase, .signedOut)
        let credentialAfterSecondRestore = await store.credential
        XCTAssertNotNil(credentialAfterSecondRestore)
    }

    @MainActor
    func testAuthAPIRequestsMatchDocumentedContract() async throws {
        let provider = RecordingNetworkProvider()
        let api = DefaultAuthAPI(networkProvider: provider)
        let credential = AuthCredential(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresAt: .now.addingTimeInterval(3600)
        )
        let idempotencyKey = UUID()

        _ = try await api.loginWithApple(
            AppleLoginRequest(
                identityToken: "identity-token",
                authorizationCode: "authorization-code",
                nonce: "nonce",
                displayName: "집집 사용자"
            )
        )
        _ = try await api.issueDevelopmentTokens(
            DevelopmentTokenRequest(
                testUserKey: "ios-tester-1",
                displayName: "iOS 테스트 사용자"
            )
        )
        try await api.deleteDevelopmentUser(testUserKey: "ios-tester-1")
        _ = try await api.refresh(refreshToken: "refresh-token", idempotencyKey: idempotencyKey)
        try await api.logout(credential: credential)
        try await api.withdraw(accessToken: "access-token", tokenType: "Bearer")

        XCTAssertEqual(APIConfig.baseURL, "https://dev-api.zipzip.site")
        XCTAssertEqual(provider.requests.map { $0.url?.path }, [
            "/api/v1/auth/apple",
            "/api/v1/dev/auth/tokens",
            "/api/v1/dev/auth/users/ios-tester-1",
            "/api/v1/auth/refresh",
            "/api/v1/auth/logout",
            "/api/v1/users/me"
        ])
        XCTAssertEqual(
            provider.requests.map(\.httpMethod),
            ["POST", "POST", "DELETE", "POST", "POST", "DELETE"]
        )

        let loginBody = try requestBody(provider.requests[0])
        XCTAssertEqual(loginBody["identityToken"] as? String, "identity-token")
        XCTAssertEqual(loginBody["authorizationCode"] as? String, "authorization-code")
        XCTAssertEqual(loginBody["nonce"] as? String, "nonce")
        XCTAssertEqual(loginBody["displayName"] as? String, "집집 사용자")

        let developmentLoginBody = try requestBody(provider.requests[1])
        XCTAssertEqual(developmentLoginBody["testUserKey"] as? String, "ios-tester-1")
        XCTAssertEqual(developmentLoginBody["displayName"] as? String, "iOS 테스트 사용자")
        XCTAssertNil(provider.requests[2].httpBody)

        XCTAssertEqual(
            provider.requests[3].value(forHTTPHeaderField: "Idempotency-Key"),
            idempotencyKey.uuidString
        )
        XCTAssertEqual(try requestBody(provider.requests[3])["refreshToken"] as? String, "refresh-token")
        XCTAssertEqual(
            provider.requests[4].value(forHTTPHeaderField: "Authorization"),
            "Bearer access-token"
        )
        XCTAssertEqual(try requestBody(provider.requests[4])["refreshToken"] as? String, "refresh-token")
        XCTAssertNil(provider.requests[5].httpBody)
    }

    #if DEBUG
        @MainActor
        func testDevelopmentLoginPersistsSessionAndWithdrawDeletesDevelopmentUser() async throws {
            let store = TestCredentialStore(initial: nil)
            let api = TestAuthAPI()
            let controller = SessionCredentialController(store: store, authAPI: api)
            let state = AuthenticationState(
                authAPI: api,
                credentialController: controller,
                defaults: try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
            )
            let configuration = DevelopmentAuthConfiguration(
                testUserKey: "ios-tester-1",
                displayName: "iOS 테스트 사용자"
            )

            state.requestLogin(.share)
            await state.loginForDevelopment(configuration: configuration)

            XCTAssertTrue(state.isLoggedIn)
            XCTAssertEqual(state.currentUser?.displayName, "iOS 테스트 사용자")
            let stored = await store.credential
            XCTAssertEqual(stored?.developmentUserKey, "ios-tester-1")
            XCTAssertEqual(stored?.appleUserIdentifier, "")

            let didWithdraw = await state.withdraw()

            XCTAssertTrue(didWithdraw)
            XCTAssertEqual(api.deletedDevelopmentUserKeys, ["ios-tester-1"])
            XCTAssertEqual(api.withdrawCount, 0)
            XCTAssertFalse(state.isLoggedIn)
            let credentialAfterWithdraw = await store.credential
            XCTAssertNil(credentialAfterWithdraw)
        }
    #endif

    private func sessionCredential() -> StoredSessionCredential {
        StoredSessionCredential(
            credential: AuthCredential(
                accessToken: "old-access",
                refreshToken: "old-refresh",
                tokenType: "Bearer",
                expiresAt: .now.addingTimeInterval(3600)
            ),
            user: AuthUser(id: UUID(), displayName: "집집 사용자"),
            appleUserIdentifier: "apple-user"
        )
    }

    private func expiringLoginResponse() -> LoginResponse {
        LoginResponse(
            accessToken: "old-access",
            refreshToken: "old-refresh",
            tokenType: "Bearer",
            expiresIn: 30,
            isNewUser: false,
            isRestoredUser: false,
            user: AuthUser(id: UUID(), displayName: "집집 사용자")
        )
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private actor TestCredentialStore: CredentialStore {
    private(set) var credential: StoredSessionCredential?
    private let failsDelete: Bool

    init(initial: StoredSessionCredential?, failsDelete: Bool = false) {
        self.credential = initial
        self.failsDelete = failsDelete
    }

    func load() -> StoredSessionCredential? {
        credential
    }

    func save(_ credential: StoredSessionCredential) {
        self.credential = credential
    }

    func delete() throws {
        if failsDelete {
            throw AuthSessionError.keychain(-1)
        }
        credential = nil
    }

    func delete(ifMatching credential: StoredSessionCredential) throws {
        if self.credential == credential {
            try delete()
        }
    }
}

@MainActor
private final class TestAuthAPI: AuthAPI {
    private(set) var refreshCount = 0
    private(set) var deletedDevelopmentUserKeys: [String] = []
    private(set) var withdrawCount = 0
    private let delay: Duration
    private let error: NetworkError?

    init(delay: Duration = .milliseconds(100), error: NetworkError? = nil) {
        self.delay = delay
        self.error = error
    }

    func loginWithApple(_ request: AppleLoginRequest) async throws -> LoginResponse {
        throw AuthSessionError.missingCredential
    }

    func issueDevelopmentTokens(_ request: DevelopmentTokenRequest) async throws -> LoginResponse {
        LoginResponse(
            accessToken: "development-access",
            refreshToken: "development-refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            isNewUser: true,
            isRestoredUser: false,
            user: AuthUser(id: UUID(), displayName: request.displayName)
        )
    }

    func deleteDevelopmentUser(testUserKey: String) async throws {
        deletedDevelopmentUserKeys.append(testUserKey)
    }

    func refresh(refreshToken: String, idempotencyKey: UUID) async throws -> TokenRefreshResponse {
        refreshCount += 1
        try await Task.sleep(for: delay)
        if let error {
            throw error
        }
        return TokenRefreshResponse(
            accessToken: "new-access",
            refreshToken: "new-refresh",
            tokenType: "Bearer",
            expiresIn: 3600
        )
    }

    func logout(credential: AuthCredential) async throws {}
    func withdraw(accessToken: String, tokenType: String) async throws {
        withdrawCount += 1
    }
}

@MainActor
private final class RecordingNetworkProvider: NetworkProvider {
    private(set) var requests: [URLRequest] = []

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try endpoint.asURLRequest()
        requests.append(request)

        let json: String
        switch request.url?.path {
        case "/api/v1/auth/apple", "/api/v1/dev/auth/tokens":
            json = """
            {
              "data": {
                "accessToken": "access-token",
                "refreshToken": "refresh-token",
                "tokenType": "Bearer",
                "expiresIn": 3600,
                "isNewUser": true,
                "isRestoredUser": false,
                "user": {
                  "id": "11111111-1111-1111-1111-111111111111",
                  "displayName": "집집 사용자"
                }
              }
            }
            """
        case "/api/v1/auth/refresh":
            json = """
            {
              "data": {
                "accessToken": "new-access-token",
                "refreshToken": "new-refresh-token",
                "tokenType": "Bearer",
                "expiresIn": 3600
              }
            }
            """
        default:
            json = "{}"
        }

        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
