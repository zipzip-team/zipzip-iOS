//
//  UserProfileAPI.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

protocol UserProfileAPI {
    func fetchMyProfile() async throws -> UserProfileResponse
}

final class DefaultUserProfileAPI: UserProfileAPI {
    private let networkProvider: NetworkProvider

    init(networkProvider: NetworkProvider) {
        self.networkProvider = networkProvider
    }

    func fetchMyProfile() async throws -> UserProfileResponse {
        let response: APIEnvelope<UserProfileResponse> = try await networkProvider.request(
            UserProfileEndpoint.myProfile
        )
        return response.data
    }
}

nonisolated struct UserProfileResponse: Decodable, Equatable {
    let displayName: String
}

private enum UserProfileEndpoint: APIEndpoint {
    case myProfile

    var path: String {
        "/api/v1/users/me"
    }

    var method: HTTPMethod {
        .get
    }

    var headers: HTTPHeaders? {
        nil
    }

    var parameters: Parameters? {
        nil
    }

    var encoding: ParameterEncoding {
        URLEncoding.default
    }
}
