//
//  UserProfileRepository.swift
//  zipzip-iOS
//

import Foundation

struct UserProfile: Equatable {
    let displayName: String
}

@MainActor
protocol UserProfileRepository {
    func myProfile() async throws -> UserProfile
}

@MainActor
final class DefaultUserProfileRepository: UserProfileRepository {
    private let api: UserProfileAPI

    init(api: UserProfileAPI) {
        self.api = api
    }

    func myProfile() async throws -> UserProfile {
        let response = try await api.fetchMyProfile()
        return UserProfile(displayName: response.displayName)
    }
}
