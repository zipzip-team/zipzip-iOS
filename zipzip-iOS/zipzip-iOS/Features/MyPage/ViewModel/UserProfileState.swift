//
//  UserProfileState.swift
//  zipzip-iOS
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class UserProfileState {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "UserProfile"
    )

    private let repository: UserProfileRepository

    private(set) var displayName: String?
    private(set) var ownerID: UUID?
    private(set) var isLoading = false

    private var requestID: UUID?

    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    func load(for user: AuthUser) async {
        let requestID = UUID()
        self.requestID = requestID
        ownerID = user.id
        displayName = user.displayName
        isLoading = true

        do {
            let profile = try await repository.myProfile()
            guard self.requestID == requestID, ownerID == user.id else { return }
            displayName = profile.displayName
        } catch {
            guard self.requestID == requestID, ownerID == user.id else { return }
            displayName = user.displayName
            Self.logger.error(
                """
                ❌ [UserProfile] failed to load user profile
                Error: \(String(describing: error), privacy: .public)
                """
            )
        }

        guard self.requestID == requestID else { return }
        isLoading = false
    }

    func resolvedDisplayName(for user: AuthUser) -> String {
        guard ownerID == user.id else { return user.displayName }
        return displayName ?? user.displayName
    }

    func reset() {
        requestID = nil
        displayName = nil
        ownerID = nil
        isLoading = false
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
