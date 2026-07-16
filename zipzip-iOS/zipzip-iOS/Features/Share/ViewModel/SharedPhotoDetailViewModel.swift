//
//  SharedPhotoDetailViewModel.swift
//  zipzip-iOS
//

import CoreGraphics
import Foundation
import Observation
import OSLog

@MainActor
protocol SharedPhotoDetailRepository {
    func photo(id: SharedAlbumPhoto.ID) async throws -> SharedPhotoDetail
    func comments(
        photoID: SharedAlbumPhoto.ID,
        cursor: String?,
        size: Int
    ) async throws -> SharedPhotoCommentPage
    func setLike(
        photoID: SharedAlbumPhoto.ID,
        isLiked: Bool
    ) async throws -> SharedPhotoLikeState
    func deletePhoto(
        photoID: SharedAlbumPhoto.ID,
        from albumID: SharedAlbum.ID
    ) async throws -> Bool
}

@MainActor
struct SharedPhotoDetailRepositoryAdapter: SharedPhotoDetailRepository {
    let onPhoto: (SharedAlbumPhoto.ID) async throws -> SharedPhotoDetail
    let onComments: (
        SharedAlbumPhoto.ID,
        String?,
        Int
    ) async throws -> SharedPhotoCommentPage
    let onSetLike: (
        SharedAlbumPhoto.ID,
        Bool
    ) async throws -> SharedPhotoLikeState
    let onDeletePhoto: (
        SharedAlbumPhoto.ID,
        SharedAlbum.ID
    ) async throws -> Bool

    func photo(id: SharedAlbumPhoto.ID) async throws -> SharedPhotoDetail {
        try await onPhoto(id)
    }

    func comments(
        photoID: SharedAlbumPhoto.ID,
        cursor: String?,
        size: Int
    ) async throws -> SharedPhotoCommentPage {
        try await onComments(photoID, cursor, size)
    }

    func setLike(
        photoID: SharedAlbumPhoto.ID,
        isLiked: Bool
    ) async throws -> SharedPhotoLikeState {
        try await onSetLike(photoID, isLiked)
    }

    func deletePhoto(
        photoID: SharedAlbumPhoto.ID,
        from albumID: SharedAlbum.ID
    ) async throws -> Bool {
        try await onDeletePhoto(photoID, albumID)
    }
}

@Observable
@MainActor
final class SharedPhotoDetailViewModel {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "SharedPhotoDetail"
    )

    let photoID: SharedAlbumPhoto.ID
    let albumID: SharedAlbum.ID

    private(set) var detail: SharedPhotoDetail?
    private(set) var latestComment: SharedPhotoComment?
    private(set) var isLikedByMe = false
    private(set) var likeCount = 0
    private(set) var isLoading = false
    private(set) var hasLoadFailed = false
    private(set) var isUpdatingLike = false
    private(set) var isDeleting = false
    var isErrorPresented = false
    private(set) var errorMessage = ""

    private var hasLoaded = false
    private let repository: any SharedPhotoDetailRepository
    private let onPhotoDeleted: () -> Void

    init(
        photoID: SharedAlbumPhoto.ID,
        albumID: SharedAlbum.ID,
        repository: any SharedPhotoDetailRepository,
        onPhotoDeleted: @escaping () -> Void = {}
    ) {
        self.photoID = photoID
        self.albumID = albumID
        self.repository = repository
        self.onPhotoDeleted = onPhotoDeleted
    }

    var imageURL: URL? {
        guard let detail,
              detail.originalURLExpiresAt > .now
        else {
            return nil
        }
        return URL(string: detail.originalURL)
    }

    var imageSize: CGSize {
        guard let detail,
              detail.width > 0,
              detail.height > 0
        else {
            return .zero
        }
        return CGSize(width: detail.width, height: detail.height)
    }

    func load() async {
        guard !hasLoaded, !isLoading else { return }
        await loadContent()
    }

    func retry() async {
        guard !isLoading else { return }
        await loadContent()
    }

    func toggleLike() async {
        guard detail != nil, !isUpdatingLike else { return }

        let previousIsLiked = isLikedByMe
        let previousLikeCount = likeCount
        let nextIsLiked = !previousIsLiked
        isLikedByMe = nextIsLiked
        likeCount = max(previousLikeCount + (nextIsLiked ? 1 : -1), 0)
        isUpdatingLike = true
        defer { isUpdatingLike = false }

        do {
            let state = try await repository.setLike(
                photoID: photoID,
                isLiked: nextIsLiked
            )
            isLikedByMe = state.isLikedByMe
            likeCount = state.likeCount
        } catch {
            isLikedByMe = previousIsLiked
            likeCount = previousLikeCount
            presentError("좋아요를 변경하지 못했어요.", error: error)
        }
    }

    func deletePhoto() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            guard try await repository.deletePhoto(photoID: photoID, from: albumID) else {
                presentError("사진을 삭제하지 못했어요.")
                return
            }
            onPhotoDeleted()
        } catch {
            presentError("사진을 삭제하지 못했어요.", error: error)
        }
    }

    private func loadContent() async {
        isLoading = true
        hasLoadFailed = false
        defer { isLoading = false }

        do {
            let detail = try await repository.photo(id: photoID)
            self.detail = detail
            isLikedByMe = detail.isLikedByMe
            likeCount = detail.likeCount
            hasLoaded = true

            if detail.commentCount > 0 {
                do {
                    latestComment = try await fetchLatestComment()
                } catch {
                    Self.logger.error(
                        "❌ [SharedPhotoDetail] failed to load latest comment: \(String(describing: error), privacy: .public)"
                    )
                }
            } else {
                latestComment = nil
            }
        } catch {
            hasLoadFailed = true
            presentError("사진을 불러오지 못했어요.", error: error)
        }
    }

    private func fetchLatestComment() async throws -> SharedPhotoComment? {
        var cursor: String?
        var requestedCursors: Set<String> = []
        var latestComment: SharedPhotoComment?

        repeat {
            let page = try await repository.comments(
                photoID: photoID,
                cursor: cursor,
                size: 100
            )
            if let pageLatestComment = page.items.last {
                latestComment = pageLatestComment
            }
            guard page.hasNext else { break }
            guard let nextCursor = page.nextCursor,
                  requestedCursors.insert(nextCursor).inserted
            else {
                throw SharedPhotoRepositoryError.invalidPagination
            }
            cursor = nextCursor
        } while true

        return latestComment
    }

    private func presentError(_ message: String, error: Error? = nil) {
        errorMessage = message
        isErrorPresented = true
        if let error {
            Self.logger.error(
                "❌ [SharedPhotoDetail] \(message, privacy: .public) Error: \(String(describing: error), privacy: .public)"
            )
        } else {
            Self.logger.error("❌ [SharedPhotoDetail] \(message, privacy: .public)")
        }
    }
}
