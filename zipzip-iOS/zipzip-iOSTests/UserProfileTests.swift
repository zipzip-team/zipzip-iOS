import XCTest
@testable import zipzip_iOS

final class UserProfileTests: XCTestCase {
    @MainActor
    func testProfileRequestMatchesDocumentedContract() async throws {
        let provider = UserProfileRecordingNetworkProvider(json: Self.profileJSON)
        let api = DefaultUserProfileAPI(networkProvider: provider)

        let response = try await api.fetchMyProfile()

        XCTAssertEqual(response.displayName, "서버 집집이")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/users/me")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
    }

    @MainActor
    func testProfileRequestUsesCurrentBearerCredential() async throws {
        let stored = StoredSessionCredential(
            credential: AuthCredential(
                accessToken: "profile-access-token",
                refreshToken: "profile-refresh-token",
                tokenType: "Bearer",
                expiresAt: .now.addingTimeInterval(3600)
            ),
            user: AuthUser(id: UUID(), displayName: "로그인 이름"),
            appleUserIdentifier: "apple-user"
        )
        let credentialController = SessionCredentialController(
            store: UserProfileCredentialStore(credential: stored),
            authAPI: UserProfileAuthAPIStub()
        )
        _ = try await credentialController.restore()
        let provider = UserProfileRecordingNetworkProvider(json: Self.profileJSON)
        let authenticatedProvider = AuthenticatedNetworkProvider(
            provider: provider,
            credentialController: credentialController,
            onAuthenticationLost: {}
        )
        let api = DefaultUserProfileAPI(networkProvider: authenticatedProvider)

        _ = try await api.fetchMyProfile()

        XCTAssertEqual(
            provider.request?.value(forHTTPHeaderField: "Authorization"),
            "Bearer profile-access-token"
        )
    }

    @MainActor
    func testProfileRequiresDisplayNameInResponse() async throws {
        let provider = UserProfileRecordingNetworkProvider(
            json: """
            {
              "status": 200,
              "code": "USER_PROFILE_FOUND",
              "message": "내 프로필을 조회했습니다.",
              "data": {}
            }
            """
        )
        let api = DefaultUserProfileAPI(networkProvider: provider)

        do {
            _ = try await api.fetchMyProfile()
            XCTFail("displayName이 없는 성공 응답은 디코딩에 실패해야 합니다.")
        } catch is DecodingError {
        } catch {
            XCTFail("예상하지 못한 오류입니다: \(error)")
        }
    }

    @MainActor
    func testProfileStateUsesServerNameAndResetsOnLogout() async {
        let repository = UserProfileRepositoryStub(results: [.success(UserProfile(displayName: "서버 이름"))])
        let state = UserProfileState(repository: repository)
        let user = AuthUser(id: UUID(), displayName: "로그인 이름")

        await state.load(for: user)

        XCTAssertEqual(state.ownerID, user.id)
        XCTAssertEqual(state.displayName, "서버 이름")
        XCTAssertEqual(state.resolvedDisplayName(for: user), "서버 이름")
        XCTAssertEqual(
            state.resolvedDisplayName(for: AuthUser(id: UUID(), displayName: "다른 로그인 이름")),
            "다른 로그인 이름"
        )
        XCTAssertFalse(state.isErrorAlertPresented)

        state.reset()

        XCTAssertNil(state.ownerID)
        XCTAssertNil(state.displayName)
        XCTAssertFalse(state.isErrorAlertPresented)
    }

    @MainActor
    func testProfileFailureKeepsLoginFallbackAndRetryUsesServerName() async {
        let repository = UserProfileRepositoryStub(results: [
            .failure(UserProfileTestError.failed),
            .success(UserProfile(displayName: "재시도 이름"))
        ])
        let state = UserProfileState(repository: repository)
        let user = AuthUser(id: UUID(), displayName: "로그인 이름")

        await state.load(for: user)

        XCTAssertEqual(state.displayName, "로그인 이름")
        XCTAssertTrue(state.isErrorAlertPresented)
        XCTAssertFalse(state.errorAlertMessage.isEmpty)

        await state.retry()

        XCTAssertEqual(repository.requestCount, 2)
        XCTAssertEqual(state.displayName, "재시도 이름")
        XCTAssertFalse(state.isErrorAlertPresented)
    }

    @MainActor
    func testPreviousAccountResponseCannotOverwriteCurrentProfile() async {
        let repository = DelayedUserProfileRepository()
        let state = UserProfileState(repository: repository)
        let firstUser = AuthUser(id: UUID(), displayName: "첫 계정")
        let secondUser = AuthUser(id: UUID(), displayName: "둘째 계정")

        let firstLoad = Task { await state.load(for: firstUser) }
        while repository.requestCount == 0 {
            await Task.yield()
        }

        await state.load(for: secondUser)
        await firstLoad.value

        XCTAssertEqual(state.ownerID, secondUser.id)
        XCTAssertEqual(state.displayName, "둘째 서버 이름")
        XCTAssertFalse(state.isErrorAlertPresented)
    }

    private static let profileJSON = """
    {
      "status": 200,
      "code": "USER_PROFILE_FOUND",
      "message": "내 프로필을 조회했습니다.",
      "data": {
        "displayName": "서버 집집이"
      }
    }
    """
}

@MainActor
private final class UserProfileRecordingNetworkProvider: NetworkProvider {
    private let json: String
    private(set) var request: URLRequest?

    init(json: String) {
        self.json = json
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        request = try endpoint.asURLRequest()
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}

private enum UserProfileTestError: Error {
    case failed
}

@MainActor
private final class UserProfileRepositoryStub: UserProfileRepository {
    private var results: [Result<UserProfile, Error>]
    private(set) var requestCount = 0

    init(results: [Result<UserProfile, Error>]) {
        self.results = results
    }

    func myProfile() async throws -> UserProfile {
        requestCount += 1
        return try results.removeFirst().get()
    }
}

@MainActor
private final class DelayedUserProfileRepository: UserProfileRepository {
    private(set) var requestCount = 0

    func myProfile() async throws -> UserProfile {
        requestCount += 1
        if requestCount == 1 {
            try await Task.sleep(for: .milliseconds(50))
            return UserProfile(displayName: "첫 서버 이름")
        }
        return UserProfile(displayName: "둘째 서버 이름")
    }
}

private actor UserProfileCredentialStore: CredentialStore {
    private var credential: StoredSessionCredential?

    init(credential: StoredSessionCredential?) {
        self.credential = credential
    }

    func load() -> StoredSessionCredential? {
        credential
    }

    func save(_ credential: StoredSessionCredential) {
        self.credential = credential
    }

    func delete() {
        credential = nil
    }

    func delete(ifMatching credential: StoredSessionCredential) {
        if self.credential == credential {
            self.credential = nil
        }
    }
}

@MainActor
private final class UserProfileAuthAPIStub: AuthAPI {
    func loginWithApple(_ request: AppleLoginRequest) async throws -> LoginResponse {
        throw AuthSessionError.missingCredential
    }

    func issueDevelopmentTokens(_ request: DevelopmentTokenRequest) async throws -> LoginResponse {
        throw AuthSessionError.missingCredential
    }

    func deleteDevelopmentUser(testUserKey: String) async throws {}

    func refresh(refreshToken: String, idempotencyKey: UUID) async throws -> TokenRefreshResponse {
        throw AuthSessionError.missingCredential
    }

    func logout(credential: AuthCredential) async throws {}
    func withdraw(accessToken: String, tokenType: String) async throws {}
}
