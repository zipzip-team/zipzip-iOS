//
//  SharedPhotoAPI.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

protocol SharedPhotoAPI {
    func fetchPhoto(id: UUID) async throws -> SharedPhotoDetailResponse
    func fetchComments(photoID: UUID, cursor: String?, size: Int) async throws -> PhotoCommentListPageResponse
    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> PhotoCommentCreateResponse
    func likePhoto(id: UUID) async throws -> SharedPhotoLikeResponse
    func unlikePhoto(id: UUID) async throws -> SharedPhotoLikeResponse
}

final class DefaultSharedPhotoAPI: SharedPhotoAPI {
    private let networkProvider: NetworkProvider

    init(networkProvider: NetworkProvider) {
        self.networkProvider = networkProvider
    }

    func fetchPhoto(id: UUID) async throws -> SharedPhotoDetailResponse {
        let response: APIEnvelope<SharedPhotoDetailResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.detail(photoID: id)
        )
        return response.data
    }

    func fetchComments(
        photoID: UUID,
        cursor: String?,
        size: Int = 20
    ) async throws -> PhotoCommentListPageResponse {
        let response: APIEnvelope<PhotoCommentListPageResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.comments(photoID: photoID, cursor: cursor, size: size)
        )
        return response.data
    }

    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> PhotoCommentCreateResponse {
        let response: APIEnvelope<PhotoCommentCreateResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.createComment(
                photoID: photoID,
                content: content,
                idempotencyKey: idempotencyKey
            )
        )
        return response.data
    }

    func likePhoto(id: UUID) async throws -> SharedPhotoLikeResponse {
        let response: APIEnvelope<SharedPhotoLikeResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.like(photoID: id)
        )
        return response.data
    }

    func unlikePhoto(id: UUID) async throws -> SharedPhotoLikeResponse {
        let response: APIEnvelope<SharedPhotoLikeResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.unlike(photoID: id)
        )
        return response.data
    }
}

nonisolated struct SharedPhotoDetailResponse: Decodable {
    let id: UUID
    let sharedGroupId: UUID
    let sharedAlbumIds: [UUID]
    let originalUrl: String
    let originalUrlExpiresAt: String
    let thumbnailUrl: String?
    let thumbnailUrlExpiresAt: String?
    let thumbnailStatus: String
    let deviceModel: String?
    let takenAt: String?
    let displayAt: String
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isInferred: Bool
    let width: Int
    let height: Int
    let uploadedBy: SharedPhotoAuthorResponse
    let isUploader: Bool
    let likeCount: Int
    let commentCount: Int
    let isLikedByMe: Bool
    let createdAt: String
    let updatedAt: String
}

nonisolated struct SharedPhotoAuthorResponse: Decodable {
    let userId: UUID?
    let displayName: String?
}

nonisolated struct PhotoCommentListPageResponse: Decodable {
    let items: [PhotoCommentListItemResponse]
    let nextCursor: String?
    let hasNext: Bool
}

nonisolated struct PhotoCommentListItemResponse: Decodable {
    let id: UUID
    let content: String
    let author: SharedPhotoAuthorResponse
    let isAuthor: Bool
    let createdAt: String
    let updatedAt: String
}

nonisolated struct PhotoCommentCreateResponse: Decodable {
    let id: UUID
    let photoId: UUID
    let content: String
    let author: SharedPhotoAuthorResponse
    let createdAt: String
    let updatedAt: String
}

nonisolated struct SharedPhotoLikeResponse: Decodable {
    let photoId: UUID
    let isLikedByMe: Bool
    let likeCount: Int
}

private enum SharedPhotoEndpoint: APIEndpoint {
    case detail(photoID: UUID)
    case comments(photoID: UUID, cursor: String?, size: Int)
    case createComment(photoID: UUID, content: String, idempotencyKey: UUID)
    case like(photoID: UUID)
    case unlike(photoID: UUID)

    var path: String {
        switch self {
        case let .detail(photoID):
            "/api/v1/photos/\(photoID.uuidString)"
        case let .comments(photoID, _, _), let .createComment(photoID, _, _):
            "/api/v1/photos/\(photoID.uuidString)/comments"
        case let .like(photoID), let .unlike(photoID):
            "/api/v1/photos/\(photoID.uuidString)/like"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .detail, .comments:
            .get
        case .createComment:
            .post
        case .like:
            .put
        case .unlike:
            .delete
        }
    }

    var headers: HTTPHeaders? {
        switch self {
        case let .createComment(_, _, idempotencyKey):
            ["Idempotency-Key": idempotencyKey.uuidString]
        case .detail, .comments, .like, .unlike:
            nil
        }
    }

    var parameters: Parameters? {
        switch self {
        case let .comments(_, cursor, size):
            var parameters: Parameters = ["size": size]
            if let cursor {
                parameters["cursor"] = cursor
            }
            return parameters
        case let .createComment(_, content, _):
            return ["content": content]
        case .detail, .like, .unlike:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .createComment:
            JSONEncoding.default
        case .detail, .comments, .like, .unlike:
            URLEncoding(destination: .queryString)
        }
    }
}
