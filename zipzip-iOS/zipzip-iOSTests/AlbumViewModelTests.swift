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
