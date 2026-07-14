//
//  ShareGroupAPI.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

protocol ShareGroupAPI {
    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse
}

final class DefaultShareGroupAPI: ShareGroupAPI {
    private let networkProvider: NetworkProvider

    init(networkProvider: NetworkProvider) {
        self.networkProvider = networkProvider
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse {
        let response: APIEnvelope<CreateSharedGroupResponse> = try await networkProvider.request(
            ShareGroupEndpoint.create(name: name, idempotencyKey: idempotencyKey)
        )
        return response.data
    }
}

nonisolated struct CreateSharedGroupResponse: Decodable {
    let id: UUID
    let name: String
    let inviteCode: String
}

private enum ShareGroupEndpoint: APIEndpoint {
    case create(name: String, idempotencyKey: UUID)

    var path: String {
        "/api/v1/shared-groups"
    }

    var method: HTTPMethod {
        .post
    }

    var headers: HTTPHeaders? {
        switch self {
        case let .create(_, idempotencyKey):
            ["Idempotency-Key": idempotencyKey.uuidString]
        }
    }

    var parameters: Parameters? {
        switch self {
        case let .create(name, _):
            ["name": name]
        }
    }

    var encoding: ParameterEncoding {
        JSONEncoding.default
    }
}
