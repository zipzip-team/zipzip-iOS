import XCTest
@testable import zipzip_iOS

final class SharedPhotoDetailViewModelTests: XCTestCase {
    @MainActor
    func testLoadUsesLastCommentFromAscendingPages() async {
        let photoID = UUID()
        let albumID = UUID()
        let olderComment = makeComment(photoID: photoID, content: "첫 댓글")
        let latestComment = makeComment(photoID: photoID, content: "최신 댓글")
        let requestedCursors = SharedPhotoDetailBox<[String?]>([])
        let repository = makeRepository(
            detail: makeDetail(photoID: photoID, albumID: albumID, commentCount: 2),
            comments: { _, cursor, _ in
                requestedCursors.value.append(cursor)
                if cursor == nil {
                    return SharedPhotoCommentPage(
                        items: [olderComment],
                        nextCursor: "next",
                        hasNext: true
                    )
                }
                return SharedPhotoCommentPage(
                    items: [latestComment],
                    nextCursor: nil,
                    hasNext: false
                )
            }
        )
        let viewModel = SharedPhotoDetailViewModel(
            photoID: photoID,
            albumID: albumID,
            repository: repository
        )

        await viewModel.load()

        XCTAssertEqual(requestedCursors.value.count, 2)
        XCTAssertNil(requestedCursors.value[0])
        XCTAssertEqual(requestedCursors.value[1], "next")
        XCTAssertEqual(viewModel.latestComment, latestComment)
        XCTAssertEqual(viewModel.likeCount, 4)
    }

    @MainActor
    func testLikeUpdatesOnlyServerBackedDetailState() async {
        let photoID = UUID()
        let albumID = UUID()
        let requestedLikeState = SharedPhotoDetailBox<Bool?>(nil)
        let repository = makeRepository(
            detail: makeDetail(photoID: photoID, albumID: albumID),
            setLike: { id, isLiked in
                requestedLikeState.value = isLiked
                return SharedPhotoLikeState(
                    photoID: id,
                    isLikedByMe: isLiked,
                    likeCount: 5
                )
            }
        )
        let viewModel = SharedPhotoDetailViewModel(
            photoID: photoID,
            albumID: albumID,
            repository: repository
        )
        await viewModel.load()

        await viewModel.toggleLike()

        XCTAssertEqual(requestedLikeState.value, true)
        XCTAssertTrue(viewModel.isLikedByMe)
        XCTAssertEqual(viewModel.likeCount, 5)
    }

    @MainActor
    func testDeleteDetachesPhotoAndCompletesNavigation() async {
        let photoID = UUID()
        let albumID = UUID()
        let deletedPair = SharedPhotoDetailBox<(UUID, UUID)?>(nil)
        let didComplete = SharedPhotoDetailBox(false)
        let repository = makeRepository(
            detail: makeDetail(photoID: photoID, albumID: albumID),
            deletePhoto: { photoID, albumID in
                deletedPair.value = (photoID, albumID)
                return true
            }
        )
        let viewModel = SharedPhotoDetailViewModel(
            photoID: photoID,
            albumID: albumID,
            repository: repository,
            onPhotoDeleted: { didComplete.value = true }
        )

        await viewModel.deletePhoto()

        XCTAssertEqual(deletedPair.value?.0, photoID)
        XCTAssertEqual(deletedPair.value?.1, albumID)
        XCTAssertTrue(didComplete.value)
    }

    @MainActor
    private func makeRepository(
        detail: SharedPhotoDetail,
        comments: @escaping (
            SharedAlbumPhoto.ID,
            String?,
            Int
        ) async throws -> SharedPhotoCommentPage = { _, _, _ in
            SharedPhotoCommentPage(items: [], nextCursor: nil, hasNext: false)
        },
        setLike: @escaping (
            SharedAlbumPhoto.ID,
            Bool
        ) async throws -> SharedPhotoLikeState = { photoID, isLiked in
            SharedPhotoLikeState(photoID: photoID, isLikedByMe: isLiked, likeCount: 0)
        },
        deletePhoto: @escaping (
            SharedAlbumPhoto.ID,
            SharedAlbum.ID
        ) async throws -> Bool = { _, _ in true }
    ) -> SharedPhotoDetailRepositoryAdapter {
        SharedPhotoDetailRepositoryAdapter(
            onPhoto: { _ in detail },
            onComments: comments,
            onSetLike: setLike,
            onDeletePhoto: deletePhoto
        )
    }

    private func makeDetail(
        photoID: UUID,
        albumID: UUID,
        commentCount: Int = 0
    ) -> SharedPhotoDetail {
        SharedPhotoDetail(
            id: photoID,
            sharedGroupID: UUID(),
            sharedAlbumIDs: [albumID],
            originalURL: "https://cdn.example.com/photo.jpg",
            originalURLExpiresAt: .now.addingTimeInterval(3600),
            thumbnailURL: nil,
            thumbnailURLExpiresAt: nil,
            thumbnailStatus: "READY",
            deviceModel: nil,
            takenAt: nil,
            displayAt: .now,
            latitude: nil,
            longitude: nil,
            locationName: nil,
            isInferred: false,
            width: 3024,
            height: 4032,
            uploadedBy: SharedPhotoAuthor(id: nil, displayName: "집집이"),
            isUploader: true,
            likeCount: 4,
            commentCount: commentCount,
            isLikedByMe: false,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeComment(
        photoID: UUID,
        content: String
    ) -> SharedPhotoComment {
        SharedPhotoComment(
            id: UUID(),
            photoID: photoID,
            content: content,
            author: SharedPhotoAuthor(id: nil, displayName: "집집이"),
            isAuthor: false,
            createdAt: .now,
            updatedAt: .now
        )
    }
}

private final class SharedPhotoDetailBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
