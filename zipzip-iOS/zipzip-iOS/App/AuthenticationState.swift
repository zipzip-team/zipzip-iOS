//
//  AuthenticationState.swift
//  zipzip-iOS
//

import AuthenticationServices
import Foundation
import Observation

enum AuthIntent: String, Identifiable {
    case album
    case myPage
    case share

    var id: String {
        rawValue
    }
}

enum AuthSessionPhase: Equatable {
    case restoring
    case signedOut
    case signedIn(AuthUser)
}

enum AuthOperation: Equatable {
    case authenticating
    case idle
    case loggingOut
    case refreshing
    case withdrawing
}

enum AuthAccessAvailability: Equatable {
    case ready
    case temporarilyUnavailable(String)
}

@MainActor
@Observable
final class AuthenticationState {
    private let authAPI: AuthAPI
    private let credentialController: SessionCredentialController
    private let defaults: UserDefaults
    private let installationMarkerKey = "zipzip.authentication.installation-marker"
    private let localInvalidationMarkerKey = "zipzip.authentication.locally-invalidated"

    private(set) var sessionPhase: AuthSessionPhase = .restoring
    private(set) var operation: AuthOperation = .idle
    private(set) var accessAvailability: AuthAccessAvailability = .ready
    private(set) var loginErrorMessage: String?
    private(set) var accountErrorMessage: String?
    private(set) var requiresDisplayName = false

    var loginIntent: AuthIntent?
    var displayNameDraft = ""

    private var challenge: AppleSignInChallenge?
    private var loginAttemptID: UInt64 = 0
    private var didRestore = false
    private var isCheckingCredentialState = false

    init(
        authAPI: AuthAPI,
        credentialController: SessionCredentialController,
        defaults: UserDefaults = .standard
    ) {
        self.authAPI = authAPI
        self.credentialController = credentialController
        self.defaults = defaults
    }

    var isRestoring: Bool {
        sessionPhase == .restoring
    }

    var isLoggedIn: Bool {
        if case .signedIn = sessionPhase { return true }
        return false
    }

    var currentUser: AuthUser? {
        guard case let .signedIn(user) = sessionPhase else { return nil }
        return user
    }

    var isAuthenticating: Bool {
        operation == .authenticating
    }

    var trimmedDisplayName: String {
        displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isDisplayNameValid: Bool {
        (1 ... 50).contains(trimmedDisplayName.count)
    }

    func restore(minimumDuration: Duration = .zero) async {
        guard !didRestore else { return }
        didRestore = true

        async let minimumWait: Void = wait(for: minimumDuration)
        let restored: StoredSessionCredential?

        do {
            if defaults.object(forKey: installationMarkerKey) == nil {
                try? await credentialController.clear()
                defaults.set(true, forKey: installationMarkerKey)
            }
            if defaults.bool(forKey: localInvalidationMarkerKey) {
                try? await credentialController.clear()
                restored = nil
            } else {
                restored = try await credentialController.restore()
            }
            accessAvailability = .ready
        } catch {
            restored = await credentialController.current()
            if restored != nil {
                accessAvailability = .temporarilyUnavailable(error.localizedDescription)
            }
        }

        _ = await minimumWait
        if let restored {
            sessionPhase = .signedIn(restored.user)
        } else {
            sessionPhase = .signedOut
        }
    }

    func requestLogin(_ intent: AuthIntent) {
        guard !isLoggedIn else { return }
        loginErrorMessage = nil
        accountErrorMessage = nil
        loginIntent = intent
    }

    func cancelLogin() {
        guard operation != .authenticating else { return }
        resetLoginPresentation()
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let challenge = try AppleSignInChallenge.make()
            loginAttemptID &+= 1
            self.challenge = challenge
            loginErrorMessage = nil
            request.requestedScopes = [.fullName, .email]
            request.nonce = challenge.nonce
            request.state = challenge.state
        } catch {
            loginErrorMessage = error.localizedDescription
        }
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case let .success(authorization):
            guard operation == .idle else { return }
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                loginErrorMessage = "Apple 로그인 정보를 확인하지 못했습니다."
                return
            }
            operation = .authenticating
            let attemptID = loginAttemptID
            Task { await exchangeAppleCredential(credential, attemptID: attemptID) }
        case let .failure(error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                cancelLogin()
            } else {
                loginErrorMessage = "Apple 로그인에 실패했습니다. 다시 시도해 주세요."
            }
        }
    }

    func logout() async {
        guard operation == .idle else { return }
        operation = .loggingOut
        accountErrorMessage = nil
        defaults.set(true, forKey: localInvalidationMarkerKey)

        if let stored = await credentialController.beginTermination() {
            try? await authAPI.logout(credential: stored.credential)
        }
        try? await credentialController.clear()
        sessionPhase = .signedOut
        accessAvailability = .ready
        operation = .idle
    }

    func withdraw() async -> Bool {
        guard operation == .idle else { return false }
        operation = .withdrawing
        accountErrorMessage = nil

        do {
            guard let stored = await credentialController.beginTermination(
                requiresFreshCredential: true
            ) else {
                throw AuthSessionError.missingCredential
            }
            try await authAPI.withdraw(
                accessToken: stored.credential.accessToken,
                tokenType: stored.credential.tokenType
            )
            defaults.set(true, forKey: localInvalidationMarkerKey)
            try? await credentialController.clear()
            sessionPhase = .signedOut
            accessAvailability = .ready
            operation = .idle
            return true
        } catch {
            await credentialController.cancelTermination()
            accountErrorMessage = error.localizedDescription
            operation = .idle
            return false
        }
    }

    func handleAuthenticationLost() {
        defaults.set(true, forKey: localInvalidationMarkerKey)
        loginAttemptID &+= 1
        guard !isRestoring else { return }
        sessionPhase = .signedOut
        accessAvailability = .ready
    }

    func handleAppleCredentialRevocation() async {
        await invalidateLocalSession()
    }

    func checkAppleCredentialState() async {
        guard !isCheckingCredentialState,
              let stored = await credentialController.current()
        else { return }

        isCheckingCredentialState = true
        defer { isCheckingCredentialState = false }

        do {
            let state = try await appleCredentialState(for: stored.appleUserIdentifier)
            switch state {
            case .authorized:
                accessAvailability = .ready
            case .notFound, .revoked:
                await invalidateLocalSession()
            case .transferred:
                accessAvailability = .temporarilyUnavailable("Apple 계정 연결 정보를 확인하고 있습니다.")
            @unknown default:
                accessAvailability = .temporarilyUnavailable("Apple 계정 상태를 확인하지 못했습니다.")
            }
        } catch {
            accessAvailability = .temporarilyUnavailable(error.localizedDescription)
        }
    }

    private func exchangeAppleCredential(
        _ credential: ASAuthorizationAppleIDCredential,
        attemptID: UInt64
    ) async {
        guard let challenge,
              credential.state == challenge.state,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCodeData = credential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8)
        else {
            loginErrorMessage = "Apple 로그인 응답을 검증하지 못했습니다. 다시 시도해 주세요."
            operation = .idle
            return
        }
        self.challenge = nil

        let appleDisplayName = credential.fullName.flatMap {
            PersonNameComponentsFormatter().string(from: $0).nilIfBlank
        }
        let displayName = requiresDisplayName ? trimmedDisplayName : appleDisplayName

        guard !requiresDisplayName || isDisplayNameValid else {
            loginErrorMessage = "이름을 1자 이상 50자 이하로 입력해 주세요."
            operation = .idle
            return
        }

        loginErrorMessage = nil

        do {
            let response = try await authAPI.loginWithApple(
                AppleLoginRequest(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    nonce: challenge.nonce,
                    displayName: displayName
                )
            )
            guard attemptID == loginAttemptID, loginIntent != nil else {
                try? await authAPI.logout(credential: response.credential())
                operation = .idle
                return
            }
            let stored: StoredSessionCredential
            do {
                stored = try await credentialController.commitLogin(
                    response: response,
                    appleUserIdentifier: credential.user
                )
            } catch {
                try? await authAPI.logout(credential: response.credential())
                throw error
            }
            guard attemptID == loginAttemptID,
                  loginIntent != nil,
                  await credentialController.current() == stored
            else {
                try? await authAPI.logout(credential: stored.credential)
                operation = .idle
                return
            }
            defaults.removeObject(forKey: localInvalidationMarkerKey)
            sessionPhase = .signedIn(stored.user)
            accessAvailability = .ready
            operation = .idle
            resetLoginPresentation()
        } catch let error as NetworkError where error.serverCode == "DISPLAY_NAME_REQUIRED"
            || error.serverCode == "INVALID_DISPLAY_NAME" {
            requiresDisplayName = true
            loginErrorMessage = "사용할 이름을 확인한 뒤 Apple 로그인을 다시 진행해 주세요."
            operation = .idle
        } catch {
            loginErrorMessage = error.localizedDescription
            operation = .idle
        }
    }

    private func invalidateLocalSession() async {
        defaults.set(true, forKey: localInvalidationMarkerKey)
        loginAttemptID &+= 1
        try? await credentialController.clear()
        sessionPhase = .signedOut
        accessAvailability = .ready
        resetLoginPresentation()
    }

    private func resetLoginPresentation() {
        loginAttemptID &+= 1
        challenge = nil
        displayNameDraft = ""
        requiresDisplayName = false
        loginErrorMessage = nil
        loginIntent = nil
    }

    private func wait(for duration: Duration) async {
        guard duration > .zero else { return }
        try? await Task.sleep(for: duration)
    }

    private func appleCredentialState(
        for userIdentifier: String
    ) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }
}

extension String {
    fileprivate var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if DEBUG
    extension AuthenticationState {
        static func preview(isLoggedIn: Bool = false) -> AuthenticationState {
            let authAPI = PreviewAuthAPI()
            let controller = SessionCredentialController(
                store: PreviewCredentialStore(),
                authAPI: authAPI
            )
            let state = AuthenticationState(
                authAPI: authAPI,
                credentialController: controller,
                defaults: UserDefaults(suiteName: UUID().uuidString)!
            )
            state.sessionPhase = isLoggedIn
                ? .signedIn(AuthUser(id: UUID(), displayName: "집집 사용자"))
                : .signedOut
            return state
        }
    }

    private actor PreviewCredentialStore: CredentialStore {
        func load() -> StoredSessionCredential? {
            nil
        }

        func save(_ credential: StoredSessionCredential) {}
        func delete() {}
        func delete(ifMatching credential: StoredSessionCredential) {}
    }

    private struct PreviewAuthAPI: AuthAPI {
        func loginWithApple(_ request: AppleLoginRequest) async throws -> LoginResponse {
            throw AuthSessionError.missingCredential
        }

        func refresh(refreshToken: String, idempotencyKey: UUID) async throws -> TokenRefreshResponse {
            throw AuthSessionError.missingCredential
        }

        func logout(credential: AuthCredential) async throws {}
        func withdraw(accessToken: String, tokenType: String) async throws {}
    }
#endif
