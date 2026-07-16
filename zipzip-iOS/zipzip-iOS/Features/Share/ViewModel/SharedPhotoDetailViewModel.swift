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
    func createComment(
        photoID: SharedAlbumPhoto.ID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment
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
    let onCreateComment: (
        SharedAlbumPhoto.ID,
        String,
        UUID
    ) async throws -> SharedPhotoComment
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

    func createComment(
        photoID: SharedAlbumPhoto.ID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment {
        try await onCreateComment(photoID, content, idempotencyKey)
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
    private(set) var comments: [SharedPhotoComment] = []
    private(set) var latestComment: SharedPhotoComment?
    private(set) var isLikedByMe = false
    private(set) var likeCount = 0
    private(set) var commentCount = 0
    private(set) var isLoading = false
    private(set) var isLoadingComments = false
    private(set) var isSendingComment = false
    private(set) var hasLoadFailed = false
    private(set) var isUpdatingLike = false
    private(set) var isDeleting = false
    var isErrorPresented = false
    private(set) var errorMessage = ""
    var commentDraft = ""
    var isCommentsPresented = false

    private var hasLoaded = false
    private var hasLoadedComments = false
    private var commentRequestContent: String?
    private var commentIdempotencyKey: UUID?
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

    func presentComments() {
        isCommentsPresented = true
    }

    func dismissComments() {
        guard !isSendingComment else { return }
        isCommentsPresented = false
    }

    func commentsDidDismiss() {
        commentDraft = ""
        commentRequestContent = nil
        commentIdempotencyKey = nil
    }

    func loadComments() async {
        await loadComments(presentFailure: true)
    }

    func sendComment() async {
        guard detail != nil, !isSendingComment, !isLoadingComments else { return }

        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard content.count <= 1000 else {
            presentError("댓글은 1,000자 이하로 입력해 주세요.")
            return
        }

        let idempotencyKey: UUID
        if commentRequestContent == content, let commentIdempotencyKey {
            idempotencyKey = commentIdempotencyKey
        } else {
            idempotencyKey = UUID()
            commentRequestContent = content
            commentIdempotencyKey = idempotencyKey
        }

        isSendingComment = true
        defer { isSendingComment = false }

        do {
            let comment = try await repository.createComment(
                photoID: photoID,
                content: content,
                idempotencyKey: idempotencyKey
            )
            let isNewComment = !comments.contains { $0.id == comment.id }
            comments = deduplicatedComments(comments + [comment])
            latestComment = comment
            if isNewComment {
                commentCount += 1
            }
            commentCount = max(commentCount, comments.count)
            commentDraft = ""
            commentRequestContent = nil
            commentIdempotencyKey = nil
        } catch {
            presentError("댓글을 보내지 못했어요.", error: error)
        }
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
            commentCount = detail.commentCount
            hasLoaded = true

            if detail.commentCount > 0 {
                hasLoadedComments = false
                await loadComments(presentFailure: false)
            } else {
                comments = []
                latestComment = nil
                hasLoadedComments = true
            }
        } catch {
            hasLoadFailed = true
            presentError("사진을 불러오지 못했어요.", error: error)
        }
    }

    private func loadComments(presentFailure: Bool) async {
        guard !hasLoadedComments, !isLoadingComments else { return }
        isLoadingComments = true
        defer { isLoadingComments = false }

        do {
            comments = try await fetchComments()
            latestComment = comments.last
            commentCount = max(commentCount, comments.count)
            hasLoadedComments = true
        } catch {
            if presentFailure {
                presentError("댓글을 불러오지 못했어요.", error: error)
            } else {
                Self.logger.error(
                    "❌ [SharedPhotoDetail] failed to load comments: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private func fetchComments() async throws -> [SharedPhotoComment] {
        var cursor: String?
        var requestedCursors: Set<String> = []
        var comments: [SharedPhotoComment] = []

        repeat {
            let page = try await repository.comments(
                photoID: photoID,
                cursor: cursor,
                size: 100
            )
            comments.append(contentsOf: page.items)
            guard page.hasNext else { break }
            guard let nextCursor = page.nextCursor,
                  requestedCursors.insert(nextCursor).inserted
            else {
                throw SharedPhotoRepositoryError.invalidPagination
            }
            cursor = nextCursor
        } while true

        return deduplicatedComments(comments)
    }

    private func deduplicatedComments<S: Sequence>(_ comments: S) -> [SharedPhotoComment]
        where S.Element == SharedPhotoComment {
        var seenIDs: Set<SharedPhotoComment.ID> = []
        return comments.filter { seenIDs.insert($0.id).inserted }
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
