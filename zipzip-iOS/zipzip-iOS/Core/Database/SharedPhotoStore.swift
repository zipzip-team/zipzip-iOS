//
//  SharedPhotoStore.swift
//  zipzip-iOS
//

import Foundation
import SQLiteData

enum SharedPhotoStoreError: Error, Equatable {
    case cacheOwnerChanged
    case localPhotoNotFound
    case sharedAlbumNotFound
    case sharedGroupMismatch
}

nonisolated struct SharedPhotoStore {
    private let database: any DatabaseWriter

    init(database: (any DatabaseWriter)? = nil) {
        if let database {
            self.database = database
        } else {
            @Dependency(\.defaultDatabase) var defaultDatabase
            self.database = defaultDatabase
        }
    }

    func prepareCache(for userID: UUID) async throws {
        try await database.write { db in
            let userID = userID.uuidString
            let owner = try SharedCacheOwnerRecord
                .where { $0.id.eq(1) }
                .fetchOne(db)
            guard owner?.userID != userID else { return }

            try #sql(#"DELETE FROM "shared_photo_upload_task""#).execute(db)
            try #sql(#"DELETE FROM "shared_album_photo""#).execute(db)
            try #sql(#"DELETE FROM "shared_photo""#).execute(db)
            try #sql(#"DELETE FROM "shared_album""#).execute(db)
            try #sql(#"DELETE FROM "shared_group""#).execute(db)
            try SharedCacheOwnerRecord.upsert {
                SharedCacheOwnerRecord.Draft(id: 1, userID: userID)
            }
            .execute(db)
        }
    }

    func fetchPhotos(albumID: UUID) async throws -> [StoredSharedPhoto] {
        try await database.read { db in
            let memberships = try SharedAlbumPhotoRecord
                .where { $0.sharedAlbumID.eq(albumID.uuidString) }
                .order { ($0.displayAt.desc(), $0.sharedPhotoID.desc()) }
                .fetchAll(db)
            return try Self.makeStoredPhotos(memberships: memberships, in: db)
        }
    }

    func fetchGroupID(albumID: UUID) async throws -> UUID? {
        try await database.read { db in
            let groupID = try SharedAlbumRecord
                .where { $0.id.eq(albumID.uuidString) }
                .select(\.sharedGroupID)
                .fetchOne(db)
            return groupID.flatMap(UUID.init(uuidString:))
        }
    }

    func fetchPhoto(id: UUID) async throws -> StoredSharedPhoto? {
        try await database.read { db in
            let record = try SharedPhotoRecord
                .where { $0.id.eq(id.uuidString) }
                .fetchOne(db)
            guard let record else {
                return nil
            }
            return try Self.makeStoredPhoto(record, in: db)
        }
    }

    func fetchPhoto(groupID: UUID, localIdentifier: String) async throws -> StoredSharedPhoto? {
        guard !localIdentifier.isEmpty else { return nil }

        return try await database.read { db in
            let localPhotoID = try PhotoRecord
                .where { $0.localIdentifier.eq(localIdentifier) }
                .select(\.id)
                .fetchOne(db)
            guard let localPhotoID else { return nil }
            let record = try SharedPhotoRecord
                .where {
                    $0.sharedGroupID.eq(groupID.uuidString) && $0.localPhotoID.eq(localPhotoID)
                }
                .fetchOne(db)
            guard let record else {
                return nil
            }
            return try Self.makeStoredPhoto(record, in: db)
        }
    }

    func fetchLocalPhotoID(localIdentifier: String) async throws -> Int? {
        guard !localIdentifier.isEmpty else { return nil }
        return try await database.read { db in
            try PhotoRecord
                .where { $0.localIdentifier.eq(localIdentifier) }
                .select(\.id)
                .fetchOne(db)
        }
    }

    func fetchPlaceName(localIdentifier: String) async throws -> String? {
        guard !localIdentifier.isEmpty else { return nil }
        return try await database.read { db in
            let photo = try PhotoRecord
                .where { $0.localIdentifier.eq(localIdentifier) }
                .fetchOne(db)
            guard let placeID = photo?.placeID else { return nil }
            return try PlaceRecord
                .where { $0.id.eq(placeID) }
                .select(\.name)
                .fetchOne(db)
        }
    }

    func fetchLocalIdentifiers(personalAlbumID: Int) async throws -> [String] {
        try await database.read { db in
            let memberships = try AlbumPhotoRecord
                .where { $0.albumID.eq(personalAlbumID) }
                .order { ($0.addedAt.desc(), $0.id.desc()) }
                .fetchAll(db)
            let photoIDs = Set(memberships.map(\.photoID))
            let photos = try PhotoRecord
                .where { $0.id.in(photoIDs) }
                .fetchAll(db)
            let identifiersByPhotoID = Dictionary(
                uniqueKeysWithValues: photos.map { ($0.id, $0.localIdentifier) }
            )
            return memberships.compactMap { identifiersByPhotoID[$0.photoID] }
        }
    }

    func fetchLocalIdentifiers(albumPhotoIDs: [Int]) async throws -> [String] {
        guard !albumPhotoIDs.isEmpty else { return [] }
        return try await database.read { db in
            let memberships = try AlbumPhotoRecord
                .where { $0.id.in(Set(albumPhotoIDs)) }
                .fetchAll(db)
            let photoIDByMembershipID = Dictionary(
                uniqueKeysWithValues: memberships.map { ($0.id, $0.photoID) }
            )
            let photos = try PhotoRecord
                .where { $0.id.in(Set(memberships.map(\.photoID))) }
                .fetchAll(db)
            let identifiersByPhotoID = Dictionary(
                uniqueKeysWithValues: photos.map { ($0.id, $0.localIdentifier) }
            )
            return albumPhotoIDs.compactMap { membershipID in
                photoIDByMembershipID[membershipID].flatMap { identifiersByPhotoID[$0] }
            }
        }
    }

    func upsertPhotos(
        _ photos: [SharedPhotoStoreInput],
        albumID: UUID,
        cacheOwnerID: UUID
    ) async throws {
        guard !photos.isEmpty else { return }

        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            let album = try SharedAlbumRecord
                .where { $0.id.eq(albumID.uuidString) }
                .fetchOne(db)
            guard let album else {
                throw SharedPhotoStoreError.sharedAlbumNotFound
            }

            for photo in photos {
                guard photo.sharedGroupID.uuidString == album.sharedGroupID else {
                    throw SharedPhotoStoreError.sharedGroupMismatch
                }
                try Self.upsert(photo, in: db)
                try Self.upsertMembership(
                    albumID: albumID.uuidString,
                    photoID: photo.id.uuidString,
                    displayAt: photo.displayAt,
                    in: db
                )
            }
        }
    }

    func upsertPhoto(
        _ photo: SharedPhotoStoreInput,
        albumIDs: [UUID],
        cacheOwnerID: UUID
    ) async throws {
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            try Self.upsert(photo, in: db)

            for albumID in Set(albumIDs) {
                let album = try SharedAlbumRecord
                    .where { $0.id.eq(albumID.uuidString) }
                    .fetchOne(db)
                guard let album else {
                    throw SharedPhotoStoreError.sharedAlbumNotFound
                }
                guard album.sharedGroupID == photo.sharedGroupID.uuidString else {
                    throw SharedPhotoStoreError.sharedGroupMismatch
                }

                try Self.upsertMembership(
                    albumID: albumID.uuidString,
                    photoID: photo.id.uuidString,
                    displayAt: photo.displayAt,
                    in: db
                )
            }
        }
    }

    func reconcileAlbum(
        albumID: UUID,
        serverPhotoIDs: Set<UUID>,
        cacheOwnerID: UUID
    ) async throws {
        let serverIDs = Set(serverPhotoIDs.map(\.uuidString))
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            let cachedMemberships = try SharedAlbumPhotoRecord
                .where { $0.sharedAlbumID.eq(albumID.uuidString) }
                .fetchAll(db)
            let removedPhotoIDs = cachedMemberships
                .filter { !serverIDs.contains($0.sharedPhotoID) }
                .map(\.sharedPhotoID)

            for photoID in removedPhotoIDs {
                try SharedAlbumPhotoRecord
                    .where {
                        $0.sharedAlbumID.eq(albumID.uuidString) && $0.sharedPhotoID.eq(photoID)
                    }
                    .delete()
                    .execute(db)
            }
        }
    }

    func addMemberships(
        photoIDs: [UUID],
        to albumID: UUID,
        cacheOwnerID: UUID
    ) async throws {
        let photoIDs = Set(photoIDs.map(\.uuidString))
        guard !photoIDs.isEmpty else { return }

        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            let album = try SharedAlbumRecord
                .where { $0.id.eq(albumID.uuidString) }
                .fetchOne(db)
            guard let album else {
                throw SharedPhotoStoreError.sharedAlbumNotFound
            }

            let photos = try SharedPhotoRecord
                .where { $0.id.in(photoIDs) }
                .fetchAll(db)
            guard photos.allSatisfy({ $0.sharedGroupID == album.sharedGroupID }) else {
                throw SharedPhotoStoreError.sharedGroupMismatch
            }

            for photo in photos {
                try Self.upsertMembership(
                    albumID: albumID.uuidString,
                    photoID: photo.id,
                    displayAt: photo.displayAt,
                    in: db
                )
            }
        }
    }

    func removeMemberships(
        photoIDs: [UUID],
        from albumID: UUID,
        cacheOwnerID: UUID
    ) async throws {
        let photoIDs = Set(photoIDs.map(\.uuidString))
        guard !photoIDs.isEmpty else { return }

        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            for photoID in photoIDs {
                try SharedAlbumPhotoRecord
                    .where {
                        $0.sharedAlbumID.eq(albumID.uuidString) && $0.sharedPhotoID.eq(photoID)
                    }
                    .delete()
                    .execute(db)
            }
        }
    }

    func deletePhotos(ids: [UUID], cacheOwnerID: UUID) async throws {
        let photoIDs = Set(ids.map(\.uuidString))
        guard !photoIDs.isEmpty else { return }

        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            try SharedPhotoRecord
                .where { $0.id.in(photoIDs) }
                .delete()
                .execute(db)
        }
    }

    func linkLocalPhoto(
        sharedPhotoID: UUID,
        localIdentifier: String,
        cacheOwnerID: UUID
    ) async throws {
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            let localPhotoID = try PhotoRecord
                .where { $0.localIdentifier.eq(localIdentifier) }
                .select(\.id)
                .fetchOne(db)
            guard let localPhotoID else {
                throw SharedPhotoStoreError.localPhotoNotFound
            }
            try SharedPhotoRecord
                .update { $0.localPhotoID = #bind(localPhotoID) }
                .where { $0.id.eq(sharedPhotoID.uuidString) }
                .execute(db)
        }
    }

    func replaceUploadTasks(
        batchID: UUID,
        with tasks: [SharedPhotoUploadTaskInput],
        cacheOwnerID: UUID
    ) async throws {
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            try SharedPhotoUploadTaskRecord
                .where { $0.batchID.eq(batchID.uuidString) }
                .delete()
                .execute(db)

            for task in tasks {
                try SharedPhotoUploadTaskRecord
                    .where {
                        $0.sharedGroupID.eq(task.sharedGroupID.uuidString)
                            && $0.localPhotoID.eq(task.localPhotoID)
                    }
                    .delete()
                    .execute(db)
                try SharedPhotoUploadTaskRecord.insert {
                    SharedPhotoUploadTaskRecord.Draft(
                        id: task.id.uuidString,
                        batchID: batchID.uuidString,
                        sharedGroupID: task.sharedGroupID.uuidString,
                        sharedAlbumID: task.sharedAlbumID.uuidString,
                        localPhotoID: task.localPhotoID,
                        objectKey: task.objectKey,
                        uploadURL: task.uploadURL,
                        uploadURLExpiresAt: task.uploadURLExpiresAt,
                        contentType: task.contentType,
                        sizeBytes: task.sizeBytes,
                        idempotencyKey: task.idempotencyKey.uuidString,
                        status: task.status.rawValue,
                        createdAt: task.createdAt
                    )
                }
                .execute(db)
            }
        }
    }

    func fetchUploadTasks(batchID: UUID, now: Date = .now) async throws -> [StoredSharedPhotoUploadTask] {
        try await database.read { db in
            try SharedPhotoUploadTaskRecord
                .where { $0.batchID.eq(batchID.uuidString) }
                .order { ($0.createdAt.asc(), $0.id.asc()) }
                .fetchAll(db)
                .compactMap(Self.makeStoredUploadTask)
                .filter { $0.uploadURLExpiresAt > now }
        }
    }

    func updateUploadTaskStatus(
        id: UUID,
        status: SharedPhotoUploadTaskStatus,
        cacheOwnerID: UUID
    ) async throws {
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            try SharedPhotoUploadTaskRecord
                .update { $0.status = #bind(status.rawValue) }
                .where { $0.id.eq(id.uuidString) }
                .execute(db)
        }
    }

    func deleteUploadTasks(batchID: UUID, cacheOwnerID: UUID) async throws {
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            try SharedPhotoUploadTaskRecord
                .where { $0.batchID.eq(batchID.uuidString) }
                .delete()
                .execute(db)
        }
    }

    func deleteAllUploadTasks(cacheOwnerID: UUID) async throws {
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            try #sql(#"DELETE FROM "shared_photo_upload_task""#).execute(db)
        }
    }

    func deleteExpiredUploadTasks(now: Date = .now, cacheOwnerID: UUID) async throws {
        try await database.write { db in
            try Self.requireCacheOwner(cacheOwnerID, in: db)
            let expiredTaskIDs = try SharedPhotoUploadTaskRecord
                .fetchAll(db)
                .filter { $0.uploadURLExpiresAt <= now }
                .map(\.id)
            for taskID in expiredTaskIDs {
                try SharedPhotoUploadTaskRecord
                    .where { $0.id.eq(taskID) }
                    .delete()
                    .execute(db)
            }
        }
    }

    private static func upsertMembership(
        albumID: String,
        photoID: String,
        displayAt: Date,
        in db: Database
    ) throws {
        try SharedAlbumPhotoRecord
            .where { $0.sharedAlbumID.eq(albumID) && $0.sharedPhotoID.eq(photoID) }
            .delete()
            .execute(db)
        try SharedAlbumPhotoRecord.insert {
            ($0.sharedAlbumID, $0.sharedPhotoID, $0.displayAt)
        } values: {
            (albumID, photoID, displayAt)
        }
        .execute(db)
    }

    private static func upsert(_ photo: SharedPhotoStoreInput, in db: Database) throws {
        let existing = try SharedPhotoRecord
            .where { $0.id.eq(photo.id.uuidString) }
            .fetchOne(db)
        try SharedPhotoRecord.upsert {
            SharedPhotoRecord.Draft(
                id: photo.id.uuidString,
                sharedGroupID: photo.sharedGroupID.uuidString,
                localPhotoID: photo.localPhotoID ?? existing?.localPhotoID,
                originalURL: photo.originalURL,
                originalURLExpiresAt: photo.originalURLExpiresAt,
                thumbnailURL: photo.thumbnailURL,
                thumbnailURLExpiresAt: photo.thumbnailURLExpiresAt,
                thumbnailStatus: photo.thumbnailStatus,
                deviceModel: photo.deviceModel,
                takenAt: photo.takenAt,
                displayAt: photo.displayAt,
                latitude: photo.latitude,
                longitude: photo.longitude,
                locationName: photo.locationName,
                isInferred: photo.isInferred,
                width: photo.width,
                height: photo.height,
                uploadedByUserID: photo.uploadedByUserID?.uuidString,
                uploadedByDisplayName: photo.uploadedByDisplayName,
                isUploader: photo.isUploader,
                likeCount: photo.likeCount,
                commentCount: photo.commentCount,
                isLikedByMe: photo.isLikedByMe,
                createdAt: photo.createdAt,
                updatedAt: photo.updatedAt
            )
        }
        .execute(db)
    }

    private static func makeStoredPhotos(
        memberships: [SharedAlbumPhotoRecord],
        in db: Database
    ) throws -> [StoredSharedPhoto] {
        let photoIDs = Set(memberships.map(\.sharedPhotoID))
        let records = try SharedPhotoRecord
            .where { $0.id.in(photoIDs) }
            .fetchAll(db)
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return try memberships.compactMap { membership in
            guard let record = recordsByID[membership.sharedPhotoID] else { return nil }
            return try makeStoredPhoto(record, in: db)
        }
    }

    private static func makeStoredPhoto(_ record: SharedPhotoRecord, in db: Database) throws -> StoredSharedPhoto? {
        guard let id = UUID(uuidString: record.id),
              let sharedGroupID = UUID(uuidString: record.sharedGroupID)
        else {
            return nil
        }
        let memberships = try SharedAlbumPhotoRecord
            .where { $0.sharedPhotoID.eq(record.id) }
            .fetchAll(db)
        let sharedAlbumIDs = memberships.compactMap { UUID(uuidString: $0.sharedAlbumID) }
        let localIdentifier: String?
        if let localPhotoID = record.localPhotoID {
            localIdentifier = try PhotoRecord
                .where { $0.id.eq(localPhotoID) }
                .select(\.localIdentifier)
                .fetchOne(db)
        } else {
            localIdentifier = nil
        }

        return StoredSharedPhoto(
            id: id,
            sharedGroupID: sharedGroupID,
            sharedAlbumIDs: sharedAlbumIDs,
            localPhotoID: record.localPhotoID,
            localIdentifier: localIdentifier,
            originalURL: record.originalURL,
            originalURLExpiresAt: record.originalURLExpiresAt,
            thumbnailURL: record.thumbnailURL,
            thumbnailURLExpiresAt: record.thumbnailURLExpiresAt,
            thumbnailStatus: record.thumbnailStatus,
            deviceModel: record.deviceModel,
            takenAt: record.takenAt,
            displayAt: record.displayAt,
            latitude: record.latitude,
            longitude: record.longitude,
            locationName: record.locationName,
            isInferred: record.isInferred,
            width: record.width,
            height: record.height,
            uploadedByUserID: record.uploadedByUserID.flatMap(UUID.init(uuidString:)),
            uploadedByDisplayName: record.uploadedByDisplayName,
            isUploader: record.isUploader,
            likeCount: record.likeCount,
            commentCount: record.commentCount,
            isLikedByMe: record.isLikedByMe,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func makeStoredUploadTask(
        _ record: SharedPhotoUploadTaskRecord
    ) -> StoredSharedPhotoUploadTask? {
        guard let id = UUID(uuidString: record.id),
              let batchID = UUID(uuidString: record.batchID),
              let sharedGroupID = UUID(uuidString: record.sharedGroupID),
              let sharedAlbumID = UUID(uuidString: record.sharedAlbumID),
              let idempotencyKey = UUID(uuidString: record.idempotencyKey),
              let status = SharedPhotoUploadTaskStatus(rawValue: record.status)
        else {
            return nil
        }
        return StoredSharedPhotoUploadTask(
            id: id,
            batchID: batchID,
            sharedGroupID: sharedGroupID,
            sharedAlbumID: sharedAlbumID,
            localPhotoID: record.localPhotoID,
            objectKey: record.objectKey,
            uploadURL: record.uploadURL,
            uploadURLExpiresAt: record.uploadURLExpiresAt,
            contentType: record.contentType,
            sizeBytes: record.sizeBytes,
            idempotencyKey: idempotencyKey,
            status: status,
            createdAt: record.createdAt
        )
    }

    private static func requireCacheOwner(_ cacheOwnerID: UUID, in db: Database) throws {
        let owner = try SharedCacheOwnerRecord
            .where { $0.id.eq(1) }
            .fetchOne(db)
        guard owner?.userID == cacheOwnerID.uuidString else {
            throw SharedPhotoStoreError.cacheOwnerChanged
        }
    }
}

nonisolated struct SharedPhotoStoreInput {
    let id: UUID
    let sharedGroupID: UUID
    let localPhotoID: Int?
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
    let uploadedByUserID: UUID?
    let uploadedByDisplayName: String?
    let isUploader: Bool
    let likeCount: Int
    let commentCount: Int
    let isLikedByMe: Bool
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct StoredSharedPhoto {
    let id: UUID
    let sharedGroupID: UUID
    let sharedAlbumIDs: [UUID]
    let localPhotoID: Int?
    let localIdentifier: String?
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
    let uploadedByUserID: UUID?
    let uploadedByDisplayName: String?
    let isUploader: Bool
    let likeCount: Int
    let commentCount: Int
    let isLikedByMe: Bool
    let createdAt: Date
    let updatedAt: Date
}

enum SharedPhotoUploadTaskStatus: String {
    case reserved
    case uploading
    case uploaded
    case completing
    case failed
}

nonisolated struct SharedPhotoUploadTaskInput {
    let id: UUID
    let sharedGroupID: UUID
    let sharedAlbumID: UUID
    let localPhotoID: Int
    let objectKey: String
    let uploadURL: String
    let uploadURLExpiresAt: Date
    let contentType: String
    let sizeBytes: Int
    let idempotencyKey: UUID
    let status: SharedPhotoUploadTaskStatus
    let createdAt: Date
}

nonisolated struct StoredSharedPhotoUploadTask {
    let id: UUID
    let batchID: UUID
    let sharedGroupID: UUID
    let sharedAlbumID: UUID
    let localPhotoID: Int
    let objectKey: String
    let uploadURL: String
    let uploadURLExpiresAt: Date
    let contentType: String
    let sizeBytes: Int
    let idempotencyKey: UUID
    let status: SharedPhotoUploadTaskStatus
    let createdAt: Date
}
