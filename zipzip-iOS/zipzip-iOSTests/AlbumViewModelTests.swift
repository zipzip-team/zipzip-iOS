import SQLiteData
import XCTest
@testable import zipzip_iOS

@MainActor
final class AlbumViewModelTests: XCTestCase {
    func testCopyingSelectedAlbumToShareKeepsPhotosInPersonalAlbum() async throws {
        let database = try appDatabase()
        let date = Date(timeIntervalSince1970: 1_900_000_000)
        let albumID = try await database.write { db in
            try AlbumRecord.insert {
                AlbumRecord.Draft(name: "가족", createdAt: date)
            }
            .execute(db)
            let albumID = Int(db.lastInsertedRowID)

            try PhotoRecord.insert {
                PhotoRecord.Draft(
                    localIdentifier: "local-photo",
                    addedAt: date,
                    addedDate: date,
                    width: 4032,
                    height: 3024
                )
            }
            .execute(db)
            let photoID = Int(db.lastInsertedRowID)

            try AlbumPhotoRecord.insert {
                ($0.albumID, $0.photoID, $0.addedAt)
            } values: {
                (albumID, photoID, date)
            }
            .execute(db)
            return albumID
        }

        let groupID = UUID()
        let groupRepository = ImportShareGroupRepository(groupID: groupID)
        let photoRepository = ImportSharedPhotoRepository(
            localIdentifiers: ["local-photo"],
            mutationResults: [
                .init(
                    succeededCount: 1,
                    succeededLocalIdentifiers: ["local-photo"]
                )
            ]
        )
        let viewModel = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            AlbumViewModel(
                albumStore: AlbumStore(),
                photoSectionsProvider: PhotoSectionsProvider(),
                sharedPhotoRepository: photoRepository,
                shareGroupRepository: groupRepository
            )
        }

        await viewModel.loadAlbums()
        let album = try XCTUnwrap(viewModel.album(for: albumID))
        viewModel.enterSelectionMode()
        viewModel.toggleSelection(for: album)

        let didCopy = await viewModel.completeShareAlbumMove(to: groupRepository.group)

        XCTAssertTrue(didCopy)
        XCTAssertEqual(viewModel.album(for: albumID)?.count, 1)
        let remainingPhotoCount = try await database.read { db in
            try AlbumPhotoRecord
                .where { $0.albumID.eq(albumID) }
                .fetchCount(db)
        }
        XCTAssertEqual(remainingPhotoCount, 1)
    }

    func testUploadFailureDoesNotCompleteCopyAndRetryUsesCreatedSharedAlbum() async throws {
        let database = try appDatabase()
        let date = Date(timeIntervalSince1970: 1_900_000_000)
        let albumID = try await database.write { db in
            try AlbumRecord.insert {
                AlbumRecord.Draft(name: "가족", createdAt: date)
            }
            .execute(db)
            let albumID = Int(db.lastInsertedRowID)

            try PhotoRecord.insert {
                PhotoRecord.Draft(
                    localIdentifier: "local-photo",
                    addedAt: date,
                    addedDate: date,
                    width: 4032,
                    height: 3024
                )
            }
            .execute(db)
            let photoID = Int(db.lastInsertedRowID)

            try AlbumPhotoRecord.insert {
                ($0.albumID, $0.photoID, $0.addedAt)
            } values: {
                (albumID, photoID, date)
            }
            .execute(db)
            return albumID
        }

        let groupID = UUID()
        let groupRepository = ImportShareGroupRepository(groupID: groupID)
        let photoRepository = ImportSharedPhotoRepository(
            localIdentifiers: ["local-photo"],
            mutationResults: [
                .init(succeededCount: 0, failedCount: 1),
                .init(
                    succeededCount: 1,
                    succeededLocalIdentifiers: ["local-photo"]
                )
            ]
        )
        let viewModel = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            AlbumViewModel(
                albumStore: AlbumStore(),
                photoSectionsProvider: PhotoSectionsProvider(),
                sharedPhotoRepository: photoRepository,
                shareGroupRepository: groupRepository
            )
        }

        await viewModel.loadAlbums()
        let album = try XCTUnwrap(viewModel.album(for: albumID))
        viewModel.enterSelectionMode()
        viewModel.toggleSelection(for: album)

        let firstAttempt = await viewModel.completeShareAlbumMove(to: groupRepository.group)
        let secondAttempt = await viewModel.completeShareAlbumMove(to: groupRepository.group)

        XCTAssertFalse(firstAttempt)
        XCTAssertTrue(secondAttempt)
        XCTAssertEqual(groupRepository.createRequests.count, 1)
        XCTAssertEqual(photoRepository.destinationAlbumIDs.count, 2)
        XCTAssertEqual(
            photoRepository.destinationAlbumIDs[0],
            photoRepository.destinationAlbumIDs[1]
        )
    }

    func testMovingSharedAlbumsCreatesMatchingPersonalAlbumsWithAllDownloadedPhotos() async throws {
        let database = try appDatabase()
        let date = Date(timeIntervalSince1970: 1_900_000_000)
        let firstLocalIdentifiers = ["family-1", "family-2"]
        let secondLocalIdentifiers = ["travel-1"]
        try await database.write { db in
            for localIdentifier in firstLocalIdentifiers + secondLocalIdentifiers {
                try PhotoRecord.insert {
                    PhotoRecord.Draft(
                        localIdentifier: localIdentifier,
                        addedAt: date,
                        addedDate: date,
                        width: 4032,
                        height: 3024
                    )
                }
                .execute(db)
            }
        }

        let groupID = UUID()
        let firstSourceAlbumID = UUID()
        let secondSourceAlbumID = UUID()
        let firstPhotoID = UUID()
        let secondPhotoID = UUID()
        let thirdPhotoID = UUID()
        let sourceAlbums = [
            SharedAlbum(
                id: firstSourceAlbumID,
                sharedGroupID: groupID,
                name: "가족",
                count: 2,
                createdBy: nil,
                isCreator: false,
                createdAt: date,
                updatedAt: date
            ),
            SharedAlbum(
                id: secondSourceAlbumID,
                sharedGroupID: groupID,
                name: "여행",
                count: 1,
                createdBy: nil,
                isCreator: false,
                createdAt: date,
                updatedAt: date
            )
        ]
        let repository = SharedAlbumCopyPhotoRepository(
            photosByAlbumID: [
                firstSourceAlbumID: [
                    SharedAlbumPhoto(id: firstPhotoID, displayAt: date),
                    SharedAlbumPhoto(id: secondPhotoID, displayAt: date)
                ],
                secondSourceAlbumID: [
                    SharedAlbumPhoto(id: thirdPhotoID, displayAt: date)
                ]
            ],
            localIdentifiersByAlbumID: [
                firstSourceAlbumID: [
                    firstPhotoID: firstLocalIdentifiers[0],
                    secondPhotoID: firstLocalIdentifiers[1]
                ],
                secondSourceAlbumID: [
                    thirdPhotoID: secondLocalIdentifiers[0]
                ]
            ]
        )
        let viewModel = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            AlbumViewModel(
                albumStore: AlbumStore(),
                sharedPhotoRepository: repository
            )
        }

        let createdAlbumIDs = await viewModel.moveSharedAlbumsToPersonalAlbums(sourceAlbums)

        XCTAssertEqual(createdAlbumIDs.count, 2)
        XCTAssertEqual(repository.synchronizedAlbumIDs, [
            firstSourceAlbumID,
            secondSourceAlbumID
        ])
        XCTAssertEqual(repository.savedPhotoIDBatches, [
            [firstPhotoID, secondPhotoID],
            [thirdPhotoID]
        ])

        let storedAlbums = try await database.read { db in
            try AlbumRecord
                .where { !$0.isFavorite }
                .order { $0.id }
                .fetchAll(db)
        }
        XCTAssertEqual(storedAlbums.map(\.id), createdAlbumIDs)
        XCTAssertEqual(storedAlbums.map(\.name), ["가족", "여행"])

        let expectedIdentifiers = [firstLocalIdentifiers, secondLocalIdentifiers]
        for (albumID, expected) in zip(createdAlbumIDs, expectedIdentifiers) {
            let localIdentifiers = try await database.read { db in
                try PhotoRecord
                    .join(AlbumPhotoRecord.all) { $0.id.eq($1.photoID) }
                    .where { $1.albumID.eq(albumID) }
                    .select { photo, _ in photo.localIdentifier }
                    .fetchAll(db)
            }
            XCTAssertEqual(Set(localIdentifiers), Set(expected))
        }
    }

    func testSelectingShareGroupUpdatesCompletionSelection() {
        let album = AlbumViewItem(
            id: 1,
            name: "가족",
            createdAt: .now,
            count: 1,
            photoIDs: []
        )
        let groupID = UUID()
        let viewModel = AlbumViewModel(albums: [album])

        viewModel.enterSelectionMode()
        viewModel.toggleSelection(for: album)
        viewModel.moveSelectedAlbumsToShare()
        viewModel.selectShareGroup(groupID)

        XCTAssertTrue(viewModel.isShareAlbumSheetPresented)
        XCTAssertEqual(viewModel.selectedShareGroupID, groupID)

        viewModel.dismissShareAlbumSheet()

        XCTAssertFalse(viewModel.isShareAlbumSheetPresented)
        XCTAssertNil(viewModel.selectedShareGroupID)
    }
}

@MainActor
private final class SharedAlbumCopyPhotoRepository: SharedPhotoRepository {
    var photosByAlbumID: [SharedAlbum.ID: [SharedAlbumPhoto]]
    let localIdentifiersByAlbumID: [
        SharedAlbum.ID: [SharedAlbumPhoto.ID: String]
    ]
    private(set) var synchronizedAlbumIDs: [SharedAlbum.ID] = []
    private(set) var savedPhotoIDBatches: [[SharedAlbumPhoto.ID]] = []

    init(
        photosByAlbumID: [SharedAlbum.ID: [SharedAlbumPhoto]],
        localIdentifiersByAlbumID: [
            SharedAlbum.ID: [SharedAlbumPhoto.ID: String]
        ]
    ) {
        self.photosByAlbumID = photosByAlbumID
        self.localIdentifiersByAlbumID = localIdentifiersByAlbumID
    }

    func prepareCache(for userID: UUID) async throws {}
    func invalidateCacheSession() {}

    func cachedPhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        photosByAlbumID[albumID] ?? []
    }

    func synchronizePhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        synchronizedAlbumIDs.append(albumID)
        return photosByAlbumID[albumID] ?? []
    }

    func addLocalPhotos(
        localIdentifiers: [String],
        to albumIDs: [SharedAlbum.ID],
        in groupID: ShareAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw SharedAlbumCopyStubError.unsupported
    }

    func copyPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to destinationAlbumIDs: [SharedAlbum.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw SharedAlbumCopyStubError.unsupported
    }

    func detachPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw SharedAlbumCopyStubError.unsupported
    }

    func savePhotosToLibrary(
        photoIDs: [SharedAlbumPhoto.ID],
        in albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        savedPhotoIDBatches.append(photoIDs)
        let localIdentifiers = photoIDs.compactMap {
            localIdentifiersByAlbumID[albumID]?[$0]
        }
        return SharedAlbumPhotoMutationResult(
            succeededCount: localIdentifiers.count,
            failedCount: photoIDs.count - localIdentifiers.count,
            succeededLocalIdentifiers: localIdentifiers
        )
    }

    func deleteLocalCopies(
        photoIDs: [SharedAlbumPhoto.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw SharedAlbumCopyStubError.unsupported
    }

    func localIdentifiers(inPersonalAlbum albumID: Album.ID) async throws -> [String] {
        throw SharedAlbumCopyStubError.unsupported
    }

    func localIdentifiers(forAlbumPhotoIDs albumPhotoIDs: [Int]) async throws -> [String] {
        throw SharedAlbumCopyStubError.unsupported
    }

    func photo(id: UUID) async throws -> SharedPhotoDetail {
        throw SharedAlbumCopyStubError.unsupported
    }

    func comments(
        photoID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedPhotoCommentPage {
        throw SharedAlbumCopyStubError.unsupported
    }

    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment {
        throw SharedAlbumCopyStubError.unsupported
    }

    func setLike(photoID: UUID, isLiked: Bool) async throws -> SharedPhotoLikeState {
        throw SharedAlbumCopyStubError.unsupported
    }
}

private enum SharedAlbumCopyStubError: Error {
    case unsupported
}
