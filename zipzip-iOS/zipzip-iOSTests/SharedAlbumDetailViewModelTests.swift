import XCTest
@testable import zipzip_iOS

final class SharedAlbumDetailViewModelTests: XCTestCase {
    @MainActor
    func testLoadReadsCacheBeforeSynchronizing() async {
        let groupID = UUID()
        let albumID = UUID()
        let cached = makePhoto(displayAt: .now.addingTimeInterval(-100))
        let synchronized = makePhoto(displayAt: .now)
        let calls = ReferenceBox<[String]>([])
        let repository = makeRepository(
            cachedPhotos: { _ in
                calls.value.append("cache")
                return [cached]
            },
            synchronizePhotos: { _ in
                calls.value.append("sync")
                return [synchronized]
            }
        )
        let viewModel = SharedAlbumDetailViewModel(
            groupID: groupID,
            albumID: albumID,
            repository: repository
        )

        await viewModel.load()

        XCTAssertEqual(calls.value, ["cache", "sync"])
        XCTAssertEqual(viewModel.photos.map(\.id), [synchronized.id])
    }

    @MainActor
    func testLocalDeleteOnlyPassesMappedPhotosFromMixedSelection() async {
        let groupID = UUID()
        let albumID = UUID()
        let localPhoto = makePhoto(localIdentifier: "asset-1")
        let remotePhoto = makePhoto()
        let cachedPhotos = ReferenceBox([localPhoto, remotePhoto])
        let deletedIDs = ReferenceBox<[UUID]>([])
        let repository = makeRepository(
            cachedPhotos: { _ in cachedPhotos.value },
            synchronizePhotos: { _ in cachedPhotos.value },
            deleteLocalCopies: { ids in
                deletedIDs.value = ids
                cachedPhotos.value = cachedPhotos.value.map { photo in
                    guard ids.contains(photo.id) else { return photo }
                    return Self.copy(photo, localIdentifier: nil)
                }
                return .init(succeededCount: ids.count)
            }
        )
        let viewModel = SharedAlbumDetailViewModel(
            groupID: groupID,
            albumID: albumID,
            repository: repository
        )
        await viewModel.load()
        viewModel.enterSelectionMode()
        viewModel.togglePhotoSelection(localPhoto.id)
        viewModel.togglePhotoSelection(remotePhoto.id)

        await viewModel.deleteSelectedLocalCopies()

        XCTAssertEqual(deletedIDs.value, [localPhoto.id])
        XCTAssertFalse(viewModel.isSelectionMode)
        XCTAssertEqual(viewModel.photos.count, 2)
        XCTAssertFalse(viewModel.photos.first(where: { $0.id == localPhoto.id })?.hasLocalCopy == true)
    }

    @MainActor
    func testCopyPassesMultipleSameGroupDestinationsWithoutDetachingSource() async {
        let groupID = UUID()
        let sourceAlbumID = UUID()
        let destinations = [UUID(), UUID()]
        let photo = makePhoto()
        let copied = ReferenceBox<([UUID], UUID, [UUID])?>(nil)
        let repository = makeRepository(
            cachedPhotos: { _ in [photo] },
            synchronizePhotos: { _ in [photo] },
            copyPhotos: { photoIDs, sourceID, destinationIDs in
                copied.value = (photoIDs, sourceID, destinationIDs)
                return .init(succeededCount: photoIDs.count * destinationIDs.count)
            }
        )
        let viewModel = SharedAlbumDetailViewModel(
            groupID: groupID,
            albumID: sourceAlbumID,
            repository: repository
        )
        await viewModel.load()
        viewModel.enterSelectionMode()
        viewModel.togglePhotoSelection(photo.id)
        viewModel.presentCopySheet()
        destinations.forEach(viewModel.toggleDestinationAlbum)

        await viewModel.copySelectedPhotos()

        XCTAssertEqual(copied.value?.0, [photo.id])
        XCTAssertEqual(copied.value?.1, sourceAlbumID)
        XCTAssertEqual(copied.value?.2, destinations)
        XCTAssertFalse(viewModel.isSelectionMode)
    }

    @MainActor
    func testPartialFailureIsReportedAndSuccessfulWorkIsKept() async {
        let photo = makePhoto()
        let repository = makeRepository(
            cachedPhotos: { _ in [photo] },
            synchronizePhotos: { _ in [photo] },
            savePhotos: { _, _ in
                .init(succeededCount: 1, failedCount: 1)
            }
        )
        let viewModel = SharedAlbumDetailViewModel(
            groupID: UUID(),
            albumID: UUID(),
            repository: repository
        )
        await viewModel.load()
        viewModel.enterSelectionMode()
        viewModel.togglePhotoSelection(photo.id)

        await viewModel.saveSelectedPhotos()

        XCTAssertTrue(viewModel.isOperationNoticePresented)
        XCTAssertEqual(viewModel.operationNoticeMessage, "2장 중 1장을 처리하지 못했어요.")
        XCTAssertFalse(viewModel.isSelectionMode)
    }

    @MainActor
    func testExpiredURLRefreshIsThrottled() async {
        let expiredPhoto = SharedAlbumPhoto(
            id: UUID(),
            originalURL: URL(string: "https://example.com/photo.jpg"),
            originalURLExpiresAt: .now.addingTimeInterval(-1),
            thumbnailStatus: .failed,
            displayAt: .now
        )
        let synchronizationCount = ReferenceBox(0)
        let repository = makeRepository(
            cachedPhotos: { _ in [expiredPhoto] },
            synchronizePhotos: { _ in
                synchronizationCount.value += 1
                return [expiredPhoto]
            }
        )
        let viewModel = SharedAlbumDetailViewModel(
            groupID: UUID(),
            albumID: UUID(),
            repository: repository
        )
        await viewModel.load()

        await viewModel.refreshExpiredURLsIfNeeded()
        await viewModel.refreshExpiredURLsIfNeeded()

        XCTAssertEqual(synchronizationCount.value, 2)
    }

    @MainActor
    private func makeRepository(
        cachedPhotos: @escaping (UUID) async throws -> [SharedAlbumPhoto] = { _ in [] },
        synchronizePhotos: @escaping (UUID) async throws -> [SharedAlbumPhoto] = { _ in [] },
        savePhotos: @escaping ([UUID], UUID) async throws -> SharedAlbumPhotoMutationResult = { ids, _ in
            .init(succeededCount: ids.count)
        },
        copyPhotos: @escaping ([UUID], UUID, [UUID]) async throws -> SharedAlbumPhotoMutationResult = { ids, _, _ in
            .init(succeededCount: ids.count)
        },
        deleteLocalCopies: @escaping ([UUID]) async throws -> SharedAlbumPhotoMutationResult = { ids in
            .init(succeededCount: ids.count)
        }
    ) -> SharedAlbumDetailRepositoryAdapter {
        SharedAlbumDetailRepositoryAdapter(
            onCachedPhotos: cachedPhotos,
            onSynchronizePhotos: synchronizePhotos,
            onRenameAlbum: { _, _, _ in true },
            onDeleteAlbum: { _, _ in true },
            onUploadPhotos: { identifiers, _ in .init(succeededCount: identifiers.count) },
            onSavePhotosToLibrary: savePhotos,
            onCopyPhotos: copyPhotos,
            onDeleteLocalCopies: deleteLocalCopies,
            onDetachPhotos: { ids, _ in .init(succeededCount: ids.count) }
        )
    }

    private func makePhoto(
        localIdentifier: String? = nil,
        displayAt: Date = .now
    ) -> SharedAlbumPhoto {
        SharedAlbumPhoto(
            id: UUID(),
            localIdentifier: localIdentifier,
            thumbnailStatus: .pending,
            displayAt: displayAt
        )
    }

    private static func copy(
        _ photo: SharedAlbumPhoto,
        localIdentifier: String?
    ) -> SharedAlbumPhoto {
        SharedAlbumPhoto(
            id: photo.id,
            localIdentifier: localIdentifier,
            originalURL: photo.originalURL,
            originalURLExpiresAt: photo.originalURLExpiresAt,
            thumbnailURL: photo.thumbnailURL,
            thumbnailURLExpiresAt: photo.thumbnailURLExpiresAt,
            thumbnailStatus: photo.thumbnailStatus,
            displayAt: photo.displayAt
        )
    }
}

private final class ReferenceBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
