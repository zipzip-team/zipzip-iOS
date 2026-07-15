//
//  SharedPhotoRepository.swift
//  zipzip-iOS
//

import Foundation

struct SharedPhotoAuthor: Equatable {
    let id: UUID?
    let displayName: String?
}

struct SharedPhotoDetail: Identifiable, Equatable {
    let id: UUID
    let sharedGroupID: UUID
    let sharedAlbumIDs: [UUID]
    let originalURL: String
    let originalURLExpiresAt: Date
    let thumbnailURL: String?
    let thumbnailURLExpiresAt: Date?
    let thumbnailStatus: String
    let deviceModel: String?
    let takenAt: Date?
    let displayAt: Date
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isInferred: Bool
    let width: Int
    let height: Int
    let uploadedBy: SharedPhotoAuthor
    let isUploader: Bool
    let likeCount: Int
    let commentCount: Int
    let isLikedByMe: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct SharedPhotoComment: Identifiable, Equatable {
    let id: UUID
    let photoID: UUID
    let content: String
    let author: SharedPhotoAuthor
    let isAuthor: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct SharedPhotoCommentPage {
    let items: [SharedPhotoComment]
    let nextCursor: String?
    let hasNext: Bool
}

struct SharedPhotoLikeState: Equatable {
    let photoID: UUID
    let isLikedByMe: Bool
    let likeCount: Int
}

enum SharedPhotoRepositoryError: Error, Equatable {
    case photoNotFound
    case invalidDate
}

@MainActor
protocol SharedPhotoRepository {
    func photo(id: UUID) async throws -> SharedPhotoDetail
    func comments(photoID: UUID, cursor: String?, size: Int) async throws -> SharedPhotoCommentPage
    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment
    func setLike(photoID: UUID, isLiked: Bool) async throws -> SharedPhotoLikeState
}

@MainActor
final class DefaultSharedPhotoRepository: SharedPhotoRepository {
    private let api: SharedPhotoAPI

    init(api: SharedPhotoAPI) {
        self.api = api
    }

    func photo(id: UUID) async throws -> SharedPhotoDetail {
        do {
            return try Self.makePhoto(try await api.fetchPhoto(id: id))
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    func comments(
        photoID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedPhotoCommentPage {
        do {
            let page = try await api.fetchComments(photoID: photoID, cursor: cursor, size: size)
            return SharedPhotoCommentPage(
                items: try page.items.map { try Self.makeComment($0, photoID: photoID) },
                nextCursor: page.nextCursor,
                hasNext: page.hasNext
            )
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment {
        do {
            let response = try await api.createComment(
                photoID: photoID,
                content: content,
                idempotencyKey: idempotencyKey
            )
            return try Self.makeComment(response)
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    func setLike(photoID: UUID, isLiked: Bool) async throws -> SharedPhotoLikeState {
        do {
            let response: SharedPhotoLikeResponse
            if isLiked {
                response = try await api.likePhoto(id: photoID)
            } else {
                response = try await api.unlikePhoto(id: photoID)
            }
            return SharedPhotoLikeState(
                photoID: response.photoId,
                isLikedByMe: response.isLikedByMe,
                likeCount: response.likeCount
            )
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    private static func makePhoto(_ response: SharedPhotoDetailResponse) throws -> SharedPhotoDetail {
        guard let originalURLExpiresAt = date(response.originalUrlExpiresAt),
              let displayAt = date(response.displayAt),
              let createdAt = date(response.createdAt),
              let updatedAt = date(response.updatedAt)
        else {
            throw SharedPhotoRepositoryError.invalidDate
        }

        return SharedPhotoDetail(
            id: response.id,
            sharedGroupID: response.sharedGroupId,
            sharedAlbumIDs: response.sharedAlbumIds,
            originalURL: response.originalUrl,
            originalURLExpiresAt: originalURLExpiresAt,
            thumbnailURL: response.thumbnailUrl,
            thumbnailURLExpiresAt: response.thumbnailUrlExpiresAt.flatMap(date),
            thumbnailStatus: response.thumbnailStatus,
            deviceModel: response.deviceModel,
            takenAt: response.takenAt.flatMap(date),
            displayAt: displayAt,
            latitude: response.latitude,
            longitude: response.longitude,
            locationName: response.locationName,
            isInferred: response.isInferred,
            width: response.width,
            height: response.height,
            uploadedBy: makeAuthor(response.uploadedBy),
            isUploader: response.isUploader,
            likeCount: response.likeCount,
            commentCount: response.commentCount,
            isLikedByMe: response.isLikedByMe,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func makeComment(
        _ response: PhotoCommentListItemResponse,
        photoID: UUID
    ) throws -> SharedPhotoComment {
        guard let createdAt = date(response.createdAt), let updatedAt = date(response.updatedAt) else {
            throw SharedPhotoRepositoryError.invalidDate
        }
        return SharedPhotoComment(
            id: response.id,
            photoID: photoID,
            content: response.content,
            author: makeAuthor(response.author),
            isAuthor: response.isAuthor,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func makeComment(_ response: PhotoCommentCreateResponse) throws -> SharedPhotoComment {
        guard let createdAt = date(response.createdAt), let updatedAt = date(response.updatedAt) else {
            throw SharedPhotoRepositoryError.invalidDate
        }
        return SharedPhotoComment(
            id: response.id,
            photoID: response.photoId,
            content: response.content,
            author: makeAuthor(response.author),
            isAuthor: true,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func makeAuthor(_ response: SharedPhotoAuthorResponse) -> SharedPhotoAuthor {
        SharedPhotoAuthor(id: response.userId, displayName: response.displayName)
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
