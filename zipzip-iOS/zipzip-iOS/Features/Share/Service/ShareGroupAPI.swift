//
//  ShareGroupAPI.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

protocol ShareGroupAPI {
    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse
    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse
    func fetchMembers(groupID: UUID, cursor: String?, size: Int) async throws -> ShareGroupMemberListPageResponse
    func fetchInviteCode(groupID: UUID) async throws -> InviteCodeResponse
    func fetchSharedAlbums(groupID: UUID, cursor: String?, size: Int) async throws -> SharedAlbumListPageResponse
    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse
    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreviewResponse
    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareGroupJoinResponse
    func updateGroupName(groupID: UUID, name: String) async throws -> ShareGroupUpdateResponse
    func deleteGroup(groupID: UUID) async throws
    func leaveGroup(groupID: UUID) async throws
    func fetchChatTimeline(groupID: UUID, cursor: String?, size: Int) async throws -> ChatTimelinePageResponse
    func createChatMessage(
        groupID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> ChatMessageResponse
    func renameSharedAlbum(id: UUID, name: String) async throws -> SharedAlbumRenameResponse
    func deleteSharedAlbum(id: UUID) async throws
    func deleteSharedAlbums(ids: [UUID], idempotencyKey: UUID) async throws -> SharedAlbumBulkDeleteResponse
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

    func fetchMembers(
        groupID: UUID,
        cursor: String?,
        size: Int = 50
    ) async throws -> ShareGroupMemberListPageResponse {
        let response: APIEnvelope<ShareGroupMemberListPageResponse> = try await networkProvider.request(
            ShareGroupEndpoint.members(groupID: groupID, cursor: cursor, size: size)
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

    func updateGroupName(groupID: UUID, name: String) async throws -> ShareGroupUpdateResponse {
        let response: APIEnvelope<ShareGroupUpdateResponse> = try await networkProvider.request(
            ShareGroupEndpoint.updateName(groupID: groupID, name: name)
        )
        return response.data
    }

    func deleteGroup(groupID: UUID) async throws {
        let _: APIVoidEnvelope = try await networkProvider.request(
            ShareGroupEndpoint.delete(groupID: groupID)
        )
    }

    func leaveGroup(groupID: UUID) async throws {
        let _: APIVoidEnvelope = try await networkProvider.request(
            ShareGroupEndpoint.leave(groupID: groupID)
        )
    }

    func fetchChatTimeline(
        groupID: UUID,
        cursor: String?,
        size: Int = 30
    ) async throws -> ChatTimelinePageResponse {
        let response: APIEnvelope<ChatTimelinePageResponse> = try await networkProvider.request(
            ShareGroupEndpoint.chatTimeline(groupID: groupID, cursor: cursor, size: size)
        )
        return response.data
    }

    func createChatMessage(
        groupID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> ChatMessageResponse {
        let response: APIEnvelope<ChatMessageResponse> = try await networkProvider.request(
            ShareGroupEndpoint.createChatMessage(
                groupID: groupID,
                content: content,
                idempotencyKey: idempotencyKey
            )
        )
        return response.data
    }

    func renameSharedAlbum(id: UUID, name: String) async throws -> SharedAlbumRenameResponse {
        let response: APIEnvelope<SharedAlbumRenameResponse> = try await networkProvider.request(
            ShareGroupEndpoint.renameSharedAlbum(id: id, name: name)
        )
        return response.data
    }

    func deleteSharedAlbum(id: UUID) async throws {
        let _: APIVoidEnvelope = try await networkProvider.request(
            ShareGroupEndpoint.deleteSharedAlbum(id: id)
        )
    }

    func deleteSharedAlbums(
        ids: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedAlbumBulkDeleteResponse {
        let response: APIEnvelope<SharedAlbumBulkDeleteResponse> = try await networkProvider.request(
            ShareGroupEndpoint.deleteSharedAlbums(ids: ids, idempotencyKey: idempotencyKey)
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

nonisolated struct ShareGroupMemberListPageResponse: Decodable {
    let items: [ShareGroupMemberResponse]
    let nextCursor: String?
    let hasNext: Bool
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

nonisolated struct ShareGroupUpdateResponse: Decodable {
    let id: UUID
    let name: String
    let updatedAt: String
}

nonisolated struct ChatTimelinePageResponse: Decodable {
    let items: [ChatTimelineItemResponse]
    let nextCursor: String?
    let hasNext: Bool
}

nonisolated struct ChatTimelineItemResponse: Decodable {
    let type: ChatTimelineItemTypeResponse
    let id: UUID
    let photoId: UUID?
    let content: String
    let author: ChatAuthorResponse
    let isAuthor: Bool
    let createdAt: String
    let updatedAt: String
}

nonisolated enum ChatTimelineItemTypeResponse: String, Decodable, Equatable {
    case chatMessage = "CHAT_MESSAGE"
    case photoComment = "PHOTO_COMMENT"
}

nonisolated struct ChatAuthorResponse: Decodable {
    let userId: UUID?
    let displayName: String?
}

nonisolated struct ChatMessageResponse: Decodable {
    let id: UUID
    let content: String
    let author: ChatAuthorResponse
    let isAuthor: Bool
    let createdAt: String
    let updatedAt: String
}

nonisolated struct SharedAlbumRenameResponse: Decodable {
    let id: UUID
    let name: String
    let updatedAt: String
}

nonisolated struct SharedAlbumBulkDeleteResponse: Decodable {
    let deletedAlbumCount: Int
    let deletedPhotoCount: Int
}

private enum ShareGroupEndpoint: APIEndpoint {
    case list(cursor: String?, size: Int)
    case detail(id: UUID)
    case members(groupID: UUID, cursor: String?, size: Int)
    case inviteCode(groupID: UUID)
    case sharedAlbums(groupID: UUID, cursor: String?, size: Int)
    case create(name: String, idempotencyKey: UUID)
    case joinPreview(inviteCode: String)
    case join(inviteCode: String, idempotencyKey: UUID)
    case updateName(groupID: UUID, name: String)
    case delete(groupID: UUID)
    case leave(groupID: UUID)
    case chatTimeline(groupID: UUID, cursor: String?, size: Int)
    case createChatMessage(groupID: UUID, content: String, idempotencyKey: UUID)
    case renameSharedAlbum(id: UUID, name: String)
    case deleteSharedAlbum(id: UUID)
    case deleteSharedAlbums(ids: [UUID], idempotencyKey: UUID)

    var path: String {
        switch self {
        case .list, .create:
            "/api/v1/shared-groups"
        case let .detail(id), let .updateName(id, _), let .delete(id):
            "/api/v1/shared-groups/\(id.uuidString)"
        case let .members(groupID, _, _):
            "/api/v1/shared-groups/\(groupID.uuidString)/members"
        case let .inviteCode(groupID):
            "/api/v1/shared-groups/\(groupID.uuidString)/invite-code"
        case let .sharedAlbums(groupID, _, _):
            "/api/v1/shared-groups/\(groupID.uuidString)/shared-albums"
        case .joinPreview:
            "/api/v1/shared-groups/join-preview"
        case .join:
            "/api/v1/shared-groups/join"
        case let .leave(groupID):
            "/api/v1/shared-groups/\(groupID.uuidString)/members/me"
        case let .chatTimeline(groupID, _, _), let .createChatMessage(groupID, _, _):
            "/api/v1/shared-groups/\(groupID.uuidString)/chat-messages"
        case let .renameSharedAlbum(id, _), let .deleteSharedAlbum(id):
            "/api/v1/shared-albums/\(id.uuidString)"
        case .deleteSharedAlbums:
            "/api/v1/shared-albums/bulk-delete"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail, .members, .inviteCode, .sharedAlbums, .joinPreview, .chatTimeline:
            .get
        case .create, .join, .createChatMessage, .deleteSharedAlbums:
            .post
        case .updateName, .renameSharedAlbum:
            .patch
        case .delete, .leave, .deleteSharedAlbum:
            .delete
        }
    }

    var headers: HTTPHeaders? {
        switch self {
        case let .create(_, idempotencyKey):
            return ["Idempotency-Key": idempotencyKey.uuidString]
        case let .join(_, idempotencyKey):
            return ["Idempotency-Key": idempotencyKey.uuidString]
        case let .createChatMessage(_, _, idempotencyKey):
            return ["Idempotency-Key": idempotencyKey.uuidString]
        case let .deleteSharedAlbums(_, idempotencyKey):
            return ["Idempotency-Key": idempotencyKey.uuidString]
        default:
            return nil
        }
    }

    var parameters: Parameters? {
        switch self {
        case let .list(cursor, size),
             let .members(_, cursor, size),
             let .sharedAlbums(_, cursor, size),
             let .chatTimeline(_, cursor, size):
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
        case let .updateName(_, name):
            return ["name": name]
        case let .createChatMessage(_, content, _):
            return ["content": content]
        case let .renameSharedAlbum(_, name):
            return ["name": name]
        case let .deleteSharedAlbums(ids, _):
            return ["sharedAlbumIds": ids.map(\.uuidString)]
        case .detail, .inviteCode, .delete, .leave, .deleteSharedAlbum:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .create, .join, .updateName, .createChatMessage, .renameSharedAlbum, .deleteSharedAlbums:
            JSONEncoding.default
        case .list, .detail, .members, .inviteCode, .sharedAlbums, .joinPreview, .delete, .leave,
             .chatTimeline, .deleteSharedAlbum:
            URLEncoding(destination: .queryString)
        }
    }
}
