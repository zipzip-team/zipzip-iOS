//
//  SharedPhotoAPI.swift
//  zipzip-iOS
//

import Alamofire
import Foundation

protocol SharedPhotoAPI {
    func fetchPhotos(
        sharedAlbumID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedPhotoListPageResponse
    func issueUploadURLs(
        sharedAlbumID: UUID,
        files: [SharedPhotoUploadFileRequest]
    ) async throws -> SharedPhotoUploadURLListResponse
    func completeUpload(
        sharedAlbumID: UUID,
        files: [SharedPhotoUploadCompletionFileRequest],
        idempotencyKey: UUID
    ) async throws -> SharedPhotoUploadCompleteResponse
    func attachPhotos(
        sharedAlbumID: UUID,
        photoIDs: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedPhotoAttachResponse
    func detachPhotos(
        sharedAlbumID: UUID,
        photoIDs: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedPhotoDetachResponse
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

    func fetchPhotos(
        sharedAlbumID: UUID,
        cursor: String?,
        size: Int = 20
    ) async throws -> SharedPhotoListPageResponse {
        let response: APIEnvelope<SharedPhotoListPageResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.list(sharedAlbumID: sharedAlbumID, cursor: cursor, size: size)
        )
        return response.data
    }

    func issueUploadURLs(
        sharedAlbumID: UUID,
        files: [SharedPhotoUploadFileRequest]
    ) async throws -> SharedPhotoUploadURLListResponse {
        let response: APIEnvelope<SharedPhotoUploadURLListResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.issueUploadURLs(sharedAlbumID: sharedAlbumID, files: files)
        )
        return response.data
    }

    func completeUpload(
        sharedAlbumID: UUID,
        files: [SharedPhotoUploadCompletionFileRequest],
        idempotencyKey: UUID
    ) async throws -> SharedPhotoUploadCompleteResponse {
        let response: APIEnvelope<SharedPhotoUploadCompleteResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.completeUpload(
                sharedAlbumID: sharedAlbumID,
                files: files,
                idempotencyKey: idempotencyKey
            )
        )
        return response.data
    }

    func attachPhotos(
        sharedAlbumID: UUID,
        photoIDs: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedPhotoAttachResponse {
        let response: APIEnvelope<SharedPhotoAttachResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.attach(
                sharedAlbumID: sharedAlbumID,
                photoIDs: photoIDs,
                idempotencyKey: idempotencyKey
            )
        )
        return response.data
    }

    func detachPhotos(
        sharedAlbumID: UUID,
        photoIDs: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedPhotoDetachResponse {
        let response: APIEnvelope<SharedPhotoDetachResponse> = try await networkProvider.request(
            SharedPhotoEndpoint.detach(
                sharedAlbumID: sharedAlbumID,
                photoIDs: photoIDs,
                idempotencyKey: idempotencyKey
            )
        )
        return response.data
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

nonisolated struct SharedPhotoListPageResponse: Decodable {
    let items: [SharedPhotoListItemResponse]
    let nextCursor: String?
    let hasNext: Bool
}

nonisolated struct SharedPhotoListItemResponse: Decodable {
    let id: UUID
    let sharedGroupId: UUID
    let sharedAlbumId: UUID
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
    let updatedAt: String?
}

nonisolated struct SharedPhotoUploadFileRequest: Equatable {
    let contentType: String
    let sizeBytes: Int
}

nonisolated struct SharedPhotoUploadURLListResponse: Decodable {
    let uploads: [SharedPhotoUploadURLResponse]
}

nonisolated struct SharedPhotoUploadURLResponse: Decodable {
    let objectKey: String
    let uploadUrl: String
    let uploadUrlExpiresAt: String
    let contentType: String
}

nonisolated struct SharedPhotoUploadCompletionFileRequest: Equatable {
    let objectKey: String
    let deviceModel: String?
    let takenAt: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isInferred: Bool?
    let width: Int?
    let height: Int?

    init(
        objectKey: String,
        deviceModel: String? = nil,
        takenAt: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        isInferred: Bool? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.objectKey = objectKey
        self.deviceModel = deviceModel
        self.takenAt = takenAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.isInferred = isInferred
        self.width = width
        self.height = height
    }
}

nonisolated struct SharedPhotoUploadCompleteResponse: Decodable {
    let items: [SharedPhotoListItemResponse]
}

nonisolated struct SharedPhotoAttachResponse: Decodable {
    let attachedCount: Int
    let alreadyAttachedCount: Int
}

nonisolated struct SharedPhotoDetachResponse: Decodable {
    let detachedCount: Int
    let deletedPhotoCount: Int
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
    case list(sharedAlbumID: UUID, cursor: String?, size: Int)
    case issueUploadURLs(sharedAlbumID: UUID, files: [SharedPhotoUploadFileRequest])
    case completeUpload(
        sharedAlbumID: UUID,
        files: [SharedPhotoUploadCompletionFileRequest],
        idempotencyKey: UUID
    )
    case attach(sharedAlbumID: UUID, photoIDs: [UUID], idempotencyKey: UUID)
    case detach(sharedAlbumID: UUID, photoIDs: [UUID], idempotencyKey: UUID)
    case detail(photoID: UUID)
    case comments(photoID: UUID, cursor: String?, size: Int)
    case createComment(photoID: UUID, content: String, idempotencyKey: UUID)
    case like(photoID: UUID)
    case unlike(photoID: UUID)

    var path: String {
        switch self {
        case let .list(sharedAlbumID, _, _):
            "/api/v1/shared-albums/\(sharedAlbumID.uuidString)/photos"
        case let .issueUploadURLs(sharedAlbumID, _):
            "/api/v1/shared-albums/\(sharedAlbumID.uuidString)/photos/upload-urls"
        case let .completeUpload(sharedAlbumID, _, _):
            "/api/v1/shared-albums/\(sharedAlbumID.uuidString)/photos/complete"
        case let .attach(sharedAlbumID, _, _):
            "/api/v1/shared-albums/\(sharedAlbumID.uuidString)/photos/attach"
        case let .detach(sharedAlbumID, _, _):
            "/api/v1/shared-albums/\(sharedAlbumID.uuidString)/photos/detach"
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
        case .list, .detail, .comments:
            .get
        case .issueUploadURLs, .completeUpload, .attach, .detach, .createComment:
            .post
        case .like:
            .put
        case .unlike:
            .delete
        }
    }

    var headers: HTTPHeaders? {
        switch self {
        case let .completeUpload(_, _, idempotencyKey),
             let .attach(_, _, idempotencyKey),
             let .detach(_, _, idempotencyKey),
             let .createComment(_, _, idempotencyKey):
            ["Idempotency-Key": idempotencyKey.uuidString]
        case .list, .issueUploadURLs, .detail, .comments, .like, .unlike:
            nil
        }
    }

    var parameters: Parameters? {
        switch self {
        case let .list(_, cursor, size), let .comments(_, cursor, size):
            var parameters: Parameters = ["size": size]
            if let cursor {
                parameters["cursor"] = cursor
            }
            return parameters
        case let .issueUploadURLs(_, files):
            return [
                "files": files.map {
                    ["contentType": $0.contentType, "sizeBytes": $0.sizeBytes]
                }
            ]
        case let .completeUpload(_, files, _):
            return ["files": files.map(Self.completionParameters)]
        case let .attach(_, photoIDs, _), let .detach(_, photoIDs, _):
            return ["photoIds": photoIDs.map(\.uuidString)]
        case let .createComment(_, content, _):
            return ["content": content]
        case .detail, .like, .unlike:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .issueUploadURLs, .completeUpload, .attach, .detach, .createComment:
            JSONEncoding.default
        case .list, .detail, .comments, .like, .unlike:
            URLEncoding(destination: .queryString)
        }
    }

    private nonisolated static func completionParameters(
        _ file: SharedPhotoUploadCompletionFileRequest
    ) -> Parameters {
        var parameters: Parameters = ["objectKey": file.objectKey]
        parameters["deviceModel"] = file.deviceModel
        parameters["takenAt"] = file.takenAt
        parameters["latitude"] = file.latitude
        parameters["longitude"] = file.longitude
        parameters["locationName"] = file.locationName
        parameters["isInferred"] = file.isInferred
        parameters["width"] = file.width
        parameters["height"] = file.height
        return parameters
    }
}
