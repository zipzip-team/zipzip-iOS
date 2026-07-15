//
//  ShareGroupAPI.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

protocol ShareGroupAPI {
    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse
    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse
    func fetchInviteCode(groupID: UUID) async throws -> InviteCodeResponse
    func fetchSharedAlbums(groupID: UUID, cursor: String?, size: Int) async throws -> SharedAlbumListPageResponse
    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse
    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreviewResponse
    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareGroupJoinResponse
}

final class DefaultShareGroupAPI: ShareGroupAPI {
    private let networkProvider: NetworkProvider

    init(networkProvider: NetworkProvider) {
        self.networkProvider = networkProvider
    }

    func fetchGroups(cursor: String?, size: Int = 20) async throws -> ShareGroupListPageResponse {
        let response: APIEnvelope<ShareGroupListPageResponse> = try await networkProvider.request(
            ShareGroupEndpoint.list(cursor: cursor, size: size)
        )
        return response.data
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        let response: APIEnvelope<ShareGroupDetailResponse> = try await networkProvider.request(
            ShareGroupEndpoint.detail(id: id)
        )
        return response.data
    }

    func fetchInviteCode(groupID: UUID) async throws -> InviteCodeResponse {
        let response: APIEnvelope<InviteCodeResponse> = try await networkProvider.request(
            ShareGroupEndpoint.inviteCode(groupID: groupID)
        )
        return response.data
    }

    func fetchSharedAlbums(
        groupID: UUID,
        cursor: String?,
        size: Int = 20
    ) async throws -> SharedAlbumListPageResponse {
        let response: APIEnvelope<SharedAlbumListPageResponse> = try await networkProvider.request(
            ShareGroupEndpoint.sharedAlbums(groupID: groupID, cursor: cursor, size: size)
        )
        return response.data
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse {
        let response: APIEnvelope<CreateSharedGroupResponse> = try await networkProvider.request(
            ShareGroupEndpoint.create(name: name, idempotencyKey: idempotencyKey)
        )
        return response.data
    }

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreviewResponse {
        let response: APIEnvelope<ShareGroupJoinPreviewResponse> = try await networkProvider.request(
            ShareGroupEndpoint.joinPreview(inviteCode: inviteCode)
        )
        return response.data
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareGroupJoinResponse {
        let response: APIEnvelope<ShareGroupJoinResponse> = try await networkProvider.request(
            ShareGroupEndpoint.join(inviteCode: inviteCode, idempotencyKey: idempotencyKey)
        )
        return response.data
    }
}

nonisolated struct ShareGroupListPageResponse: Decodable {
    let items: [ShareGroupSummaryResponse]
    let nextCursor: String?
    let hasNext: Bool
}

nonisolated struct ShareGroupSummaryResponse: Decodable {
    let id: UUID
    let name: String
    let myRole: ShareGroupRoleResponse
    let memberCount: Int
    let sharedAlbumCount: Int
    let photoCount: Int
    let joinedAt: String
    let updatedAt: String
}

nonisolated struct ShareGroupDetailResponse: Decodable {
    let id: UUID
    let name: String
    let myRole: ShareGroupRoleResponse
    let createdBy: ShareGroupUserResponse
    let memberCount: Int
    let sharedAlbumCount: Int
    let photoCount: Int
    let createdAt: String
    let updatedAt: String
}

nonisolated struct InviteCodeResponse: Decodable {
    let sharedGroupId: UUID
    let inviteCode: String
}

nonisolated struct SharedAlbumListPageResponse: Decodable {
    let items: [SharedAlbumResponse]
    let nextCursor: String?
    let hasNext: Bool
}

nonisolated struct SharedAlbumResponse: Decodable {
    let id: UUID
    let name: String
    let photoCount: Int
    let createdBy: ShareGroupUserResponse?
    let isCreator: Bool
    let createdAt: String
    let updatedAt: String
}

nonisolated struct ShareGroupUserResponse: Decodable {
    let userId: UUID?
    let displayName: String?
}

nonisolated enum ShareGroupRoleResponse: String, Decodable, Equatable {
    case host = "HOST"
    case member = "MEMBER"
}

nonisolated struct CreateSharedGroupResponse: Decodable {
    let id: UUID
    let name: String
    let inviteCode: String
}

nonisolated struct ShareGroupJoinPreviewResponse: Decodable {
    let sharedGroupId: UUID
    let name: String
    let representativeImageUrl: String?
    let representativeImageUrlExpiresAt: String?
    let createdBy: ShareGroupUserResponse
    let memberCount: Int
    let members: [ShareGroupMemberResponse]
    let alreadyJoined: Bool
}

nonisolated struct ShareGroupMemberResponse: Decodable {
    let userId: UUID
    let displayName: String
    let role: ShareGroupRoleResponse
    let isMe: Bool?
    let joinedAt: String?
}

nonisolated struct ShareGroupJoinResponse: Decodable {
    let sharedGroupId: UUID
    let name: String
    let myRole: ShareGroupRoleResponse
    let joinedAt: String
}

private enum ShareGroupEndpoint: APIEndpoint {
    case list(cursor: String?, size: Int)
    case detail(id: UUID)
    case inviteCode(groupID: UUID)
    case sharedAlbums(groupID: UUID, cursor: String?, size: Int)
    case create(name: String, idempotencyKey: UUID)
    case joinPreview(inviteCode: String)
    case join(inviteCode: String, idempotencyKey: UUID)

    var path: String {
        switch self {
        case .list, .create:
            "/api/v1/shared-groups"
        case let .detail(id):
            "/api/v1/shared-groups/\(id.uuidString)"
        case let .inviteCode(groupID):
            "/api/v1/shared-groups/\(groupID.uuidString)/invite-code"
        case let .sharedAlbums(groupID, _, _):
            "/api/v1/shared-groups/\(groupID.uuidString)/shared-albums"
        case .joinPreview:
            "/api/v1/shared-groups/join-preview"
        case .join:
            "/api/v1/shared-groups/join"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail, .inviteCode, .sharedAlbums, .joinPreview:
            .get
        case .create, .join:
            .post
        }
    }

    var headers: HTTPHeaders? {
        switch self {
        case let .create(_, idempotencyKey):
            return ["Idempotency-Key": idempotencyKey.uuidString]
        case let .join(_, idempotencyKey):
            return ["Idempotency-Key": idempotencyKey.uuidString]
        default:
            return nil
        }
    }

    var parameters: Parameters? {
        switch self {
        case let .list(cursor, size), let .sharedAlbums(_, cursor, size):
            var parameters: Parameters = ["size": size]
            if let cursor {
                parameters["cursor"] = cursor
            }
            return parameters
        case let .create(name, _):
            return ["name": name]
        case let .joinPreview(inviteCode):
            return ["inviteCode": inviteCode]
        case let .join(inviteCode, _):
            return ["inviteCode": inviteCode]
        case .detail, .inviteCode:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .create, .join:
            JSONEncoding.default
        case .list, .detail, .inviteCode, .sharedAlbums, .joinPreview:
            URLEncoding(destination: .queryString)
        }
    }
}
