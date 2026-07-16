import SQLiteData
import XCTest
@testable import zipzip_iOS

final class SharedPhotoStoreTests: XCTestCase {
    func testPhotoCanBelongToMultipleAlbumsAndReconciliationOnlyRemovesMembership() async throws {
        let context = try await makeContext()
        let photoID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let input = makePhotoInput(id: photoID, groupID: context.groupID, localPhotoID: context.localPhotoID)

        try await context.store.upsertPhoto(
            input,
            albumIDs: [context.firstAlbumID, context.secondAlbumID],
            cacheOwnerID: context.ownerID
        )

        let initialFirstAlbumPhotos = try await context.store.fetchPhotos(albumID: context.firstAlbumID)
        let initialSecondAlbumPhotos = try await context.store.fetchPhotos(albumID: context.secondAlbumID)
        XCTAssertEqual(initialFirstAlbumPhotos.map(\.id), [photoID])
        XCTAssertEqual(initialSecondAlbumPhotos.map(\.id), [photoID])

        try await context.store.reconcileAlbum(
            albumID: context.firstAlbumID,
            serverPhotoIDs: [],
            cacheOwnerID: context.ownerID
        )
        try await context.store.removeMemberships(
            photoIDs: [photoID],
            from: context.secondAlbumID,
            cacheOwnerID: context.ownerID
        )

        let reconciledFirstAlbumPhotos = try await context.store.fetchPhotos(albumID: context.firstAlbumID)
        let reconciledSecondAlbumPhotos = try await context.store.fetchPhotos(albumID: context.secondAlbumID)
        let retainedPhoto = try await context.store.fetchPhoto(id: photoID)
        XCTAssertTrue(reconciledFirstAlbumPhotos.isEmpty)
        XCTAssertTrue(reconciledSecondAlbumPhotos.isEmpty)
        XCTAssertNotNil(retainedPhoto)

        try await context.store.deletePhotos(ids: [photoID], cacheOwnerID: context.ownerID)

        let deletedPhoto = try await context.store.fetchPhoto(id: photoID)
        XCTAssertNil(deletedPhoto)
    }

    func testDeletingLocalPhotoClearsLinkWithoutDeletingSharedPhoto() async throws {
        let context = try await makeContext()
        let photoID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        try await context.store.upsertPhotos(
            [makePhotoInput(id: photoID, groupID: context.groupID, localPhotoID: context.localPhotoID)],
            albumID: context.firstAlbumID,
            cacheOwnerID: context.ownerID
        )

        try await context.database.write { db in
            try PhotoRecord
                .where { $0.id.eq(context.localPhotoID) }
                .delete()
                .execute(db)
        }

        let fetched = try await context.store.fetchPhoto(id: photoID)
        let stored = try XCTUnwrap(fetched)
        XCTAssertNil(stored.localPhotoID)
        XCTAssertNil(stored.localIdentifier)
        XCTAssertEqual(stored.sharedAlbumIDs, [context.firstAlbumID])
    }

    func testUploadTasksExcludeExpiredRowsAndAreClearedWhenOwnerChanges() async throws {
        let context = try await makeContext()
        let batchID = UUID()
        let taskID = UUID()
        let expiration = Date(timeIntervalSince1970: 2_000_000_000)
        let task = SharedPhotoUploadTaskInput(
            id: taskID,
            sharedGroupID: context.groupID,
            sharedAlbumID: context.firstAlbumID,
            localPhotoID: context.localPhotoID,
            objectKey: "shared/test.jpg",
            uploadURL: "https://object.example/signed",
            uploadURLExpiresAt: expiration,
            contentType: "image/jpeg",
            sizeBytes: 1024,
            idempotencyKey: UUID(),
            status: .reserved,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        try await context.store.replaceUploadTasks(
            batchID: batchID,
            with: [task],
            cacheOwnerID: context.ownerID
        )

        let activeTasks = try await context.store.fetchUploadTasks(
            batchID: batchID,
            now: expiration.addingTimeInterval(-1)
        )
        let expiredTasks = try await context.store.fetchUploadTasks(
            batchID: batchID,
            now: expiration
        )
        XCTAssertEqual(activeTasks.map(\.id), [taskID])
        XCTAssertTrue(expiredTasks.isEmpty)

        try await context.store.prepareCache(for: UUID())

        let clearedTasks = try await context.store.fetchUploadTasks(
            batchID: batchID,
            now: expiration.addingTimeInterval(-1)
        )
        XCTAssertTrue(clearedTasks.isEmpty)
    }

    func testCreatedSharedAlbumIncrementsGroupCountOnlyOnce() async throws {
        let context = try await makeContext()
        let store = SharedGroupStore(database: context.database)
        let createdAlbumID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let response = SharedAlbumResponse(
            id: createdAlbumID,
            name: "새 공유집",
            photoCount: 0,
            createdBy: nil,
            isCreator: true,
            createdAt: "2026-07-16T12:00:00Z",
            updatedAt: "2026-07-16T12:00:00Z"
        )

        try await store.upsertCreatedSharedAlbum(
            response,
            groupID: context.groupID,
            cacheOwnerID: context.ownerID
        )
        try await store.upsertCreatedSharedAlbum(
            response,
            groupID: context.groupID,
            cacheOwnerID: context.ownerID
        )

        let groups = try await store.fetchGroups()
        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(group.sharedAlbumCount, 3)
        XCTAssertEqual(group.albums.filter { $0.id == createdAlbumID }.count, 1)
    }

    @MainActor
    func testRepositoryLogoutClearsUploadTasksBeforeSameUserPreparesAgain() async throws {
        let context = try await makeContext()
        let batchID = UUID()
        let task = SharedPhotoUploadTaskInput(
            id: UUID(),
            sharedGroupID: context.groupID,
            sharedAlbumID: context.firstAlbumID,
            localPhotoID: context.localPhotoID,
            objectKey: "shared/logout.jpg",
            uploadURL: "https://object.example/logout-signed",
            uploadURLExpiresAt: .now.addingTimeInterval(600),
            contentType: "image/jpeg",
            sizeBytes: 1024,
            idempotencyKey: UUID(),
            status: .reserved,
            createdAt: .now
        )
        let repository = DefaultSharedPhotoRepository(
            api: DefaultSharedPhotoAPI(networkProvider: DefaultNetworkProvider()),
            store: context.store
        )
        try await repository.prepareCache(for: context.ownerID)
        try await context.store.replaceUploadTasks(
            batchID: batchID,
            with: [task],
            cacheOwnerID: context.ownerID
        )

        repository.invalidateCacheSession()
        try await repository.prepareCache(for: context.ownerID)

        let remainingTasks = try await context.store.fetchUploadTasks(batchID: batchID)
        XCTAssertTrue(remainingTasks.isEmpty)
    }

    private func makeContext() async throws -> StoreContext {
        let database = try appDatabase()
        let store = SharedPhotoStore(database: database)
        let ownerID = UUID()
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstAlbumID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222221"))
        let secondAlbumID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        try await store.prepareCache(for: ownerID)

        let localPhotoID = try await database.write { db in
            let date = Date(timeIntervalSince1970: 1_900_000_000)
            try SharedGroupRecord.insert {
                SharedGroupRecord.Draft(
                    id: groupID.uuidString,
                    name: "테스트 그룹",
                    updatedAt: date,
                    memberCount: 1,
                    sharedAlbumCount: 2,
                    photoCount: 0,
                    myRole: "HOST"
                )
            }
            .execute(db)
            for albumID in [firstAlbumID, secondAlbumID] {
                try SharedAlbumRecord.insert {
                    SharedAlbumRecord.Draft(
                        id: albumID.uuidString,
                        sharedGroupID: groupID.uuidString,
                        name: "테스트 공유집",
                        photoCount: 0,
                        isCreator: true,
                        createdAt: date,
                        updatedAt: date
                    )
                }
                .execute(db)
            }
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
            return Int(db.lastInsertedRowID)
        }

        return StoreContext(
            database: database,
            store: store,
            ownerID: ownerID,
            groupID: groupID,
            firstAlbumID: firstAlbumID,
            secondAlbumID: secondAlbumID,
            localPhotoID: localPhotoID
        )
    }

    private func makePhotoInput(id: UUID, groupID: UUID, localPhotoID: Int?) -> SharedPhotoStoreInput {
        let createdAt = Date(timeIntervalSince1970: 1_900_000_000)
        return SharedPhotoStoreInput(
            id: id,
            sharedGroupID: groupID,
            localPhotoID: localPhotoID,
            originalURL: "https://object.example/original",
            originalURLExpiresAt: createdAt.addingTimeInterval(600),
            thumbnailURL: "https://object.example/thumbnail",
            thumbnailURLExpiresAt: createdAt.addingTimeInterval(600),
            thumbnailStatus: "READY",
            deviceModel: "iPhone",
            takenAt: createdAt,
            displayAt: createdAt,
            latitude: 37.5,
            longitude: 127.0,
            locationName: "서울",
            isInferred: false,
            width: 4032,
            height: 3024,
            uploadedByUserID: nil,
            uploadedByDisplayName: "집집이",
            isUploader: true,
            likeCount: 0,
            commentCount: 0,
            isLikedByMe: false,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

private struct StoreContext {
    let database: any DatabaseWriter
    let store: SharedPhotoStore
    let ownerID: UUID
    let groupID: UUID
    let firstAlbumID: UUID
    let secondAlbumID: UUID
    let localPhotoID: Int
}
