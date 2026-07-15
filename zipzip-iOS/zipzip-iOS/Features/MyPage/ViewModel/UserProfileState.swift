//
//  UserProfileState.swift
//  zipzip-iOS
//

import Foundation
import Observation

@MainActor
@Observable
final class UserProfileState {
    private let repository: UserProfileRepository

    private(set) var displayName: String?
    private(set) var ownerID: UUID?
    private(set) var isLoading = false
    var isErrorAlertPresented = false
    private(set) var errorAlertMessage = ""

    private var fallbackUser: AuthUser?
    private var requestID: UUID?

    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    func load(for user: AuthUser) async {
        let requestID = UUID()
        self.requestID = requestID
        fallbackUser = user
        ownerID = user.id
        displayName = user.displayName
        isLoading = true
        isErrorAlertPresented = false
        errorAlertMessage = ""

        do {
            let profile = try await repository.myProfile()
            guard self.requestID == requestID, ownerID == user.id else { return }
            displayName = profile.displayName
        } catch {
            guard self.requestID == requestID, ownerID == user.id else { return }
            displayName = user.displayName
            errorAlertMessage = "로그인 정보의 이름으로 표시합니다. 네트워크 연결 후 다시 시도해 주세요."
            isErrorAlertPresented = true
        }

        guard self.requestID == requestID else { return }
        isLoading = false
    }

    func retry() async {
        guard let fallbackUser, !isLoading else { return }
        await load(for: fallbackUser)
    }

    func resolvedDisplayName(for user: AuthUser) -> String {
        guard ownerID == user.id else { return user.displayName }
        return displayName ?? user.displayName
    }

    func dismissErrorAlert() {
        isErrorAlertPresented = false
    }

    func reset() {
        requestID = nil
        fallbackUser = nil
        displayName = nil
        ownerID = nil
        isLoading = false
        isErrorAlertPresented = false
        errorAlertMessage = ""
    }
}

#if DEBUG
    extension UserProfileState {
        static func preview(displayName: String? = nil) -> UserProfileState {
            let state = UserProfileState(
                repository: PreviewUserProfileRepository(displayName: displayName ?? "집집 사용자")
            )
            state.displayName = displayName
            return state
        }
    }

    @MainActor
    private struct PreviewUserProfileRepository: UserProfileRepository {
        let displayName: String

        func myProfile() async throws -> UserProfile {
            UserProfile(displayName: displayName)
        }
    }
#endif
