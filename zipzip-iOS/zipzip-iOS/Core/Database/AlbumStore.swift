//
//  AlbumStore.swift
//  zipzip-iOS
//

import Foundation
import SQLiteData

nonisolated struct AlbumStore {
    @Dependency(\.defaultDatabase) private var database

    func fetchAlbums() async throws -> [StoredAlbum] {
        try await database.read { db in
            let records = try AlbumRecord
                .order { ($0.createdAt.desc(), $0.id.desc()) }
                .fetchAll(db)

            return try records.map { record in
                let photoCount = try AlbumPhotoRecord
                    .where { $0.albumID.eq(record.id) }
                    .fetchCount(db)
                let thumbnailLocalIdentifiers = try PhotoRecord
                    .join(AlbumPhotoRecord.all) { $0.id.eq($1.photoID) }
                    .where { $1.albumID.eq(record.id) }
                    .order { photo, _ in (photo.takenAt.desc(), photo.id.desc()) }
                    .limit(3)
                    .select { photo, _ in photo.localIdentifier }
                    .fetchAll(db)

                return StoredAlbum(
                    id: record.id,
                    name: record.name,
                    createdAt: record.createdAt,
                    photoCount: photoCount,
                    thumbnailLocalIdentifiers: thumbnailLocalIdentifiers
                )
            }
        }
    }

    func createAlbum(name: String, createdAt: Date = .now) async throws -> StoredAlbum {
        try await database.write { db in
            try AlbumRecord.insert {
                AlbumRecord.Draft(name: name, createdAt: createdAt)
            }
            .execute(db)

            return StoredAlbum(
                id: Int(db.lastInsertedRowID),
                name: name,
                createdAt: createdAt,
                photoCount: 0,
                thumbnailLocalIdentifiers: []
            )
        }
    }

    func deleteAlbums(ids: [Int]) async throws {
        let uniqueIDs = Array(Set(ids))
        guard !uniqueIDs.isEmpty else {
            return
        }

        try await database.write { db in
            for id in uniqueIDs {
                try AlbumRecord
                    .where { $0.id.eq(id) }
                    .delete()
                    .execute(db)
            }
        }
    }

    func renameAlbum(id: Int, name: String) async throws {
        try await database.write { db in
            try AlbumRecord
                .update { $0.name = name }
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }

    func addPhotos(
        localIdentifiers: [String],
        to albumIDs: [Int],
        addedAt: Date = .now
    ) async throws {
        let uniqueLocalIdentifiers = Array(Set(localIdentifiers.filter { !$0.isEmpty }))
        let uniqueAlbumIDs = Array(Set(albumIDs))
        guard !uniqueLocalIdentifiers.isEmpty, !uniqueAlbumIDs.isEmpty else {
            return
        }

        try await database.write { db in
            for localIdentifier in uniqueLocalIdentifiers {
                let storedPhotoID = try PhotoRecord
                    .where { $0.localIdentifier.eq(localIdentifier) }
                    .select(\.id)
                    .fetchOne(db)
                guard let storedPhotoID else {
                    continue
                }

                for albumID in uniqueAlbumIDs {
                    try AlbumPhotoRecord.insert {
                        ($0.albumID, $0.photoID, $0.addedAt)
                    }
                    values: {
                        (albumID, storedPhotoID, addedAt)
                    }
                    .execute(db)
                }
            }
        }
    }

    func moveAlbumPhotos(
        ids: [Int],
        from sourceAlbumID: Int,
        to destinationAlbumIDs: [Int],
        addedAt: Date = .now
    ) async throws {
        let uniqueIDs = Array(Set(ids))
        let destinationIDs = Array(Set(destinationAlbumIDs.filter { $0 != sourceAlbumID }))
        guard !uniqueIDs.isEmpty, !destinationIDs.isEmpty else {
            return
        }

        try await database.write { db in
            for id in uniqueIDs {
                let sourceRecord = try AlbumPhotoRecord
                    .where { $0.id.eq(id) && $0.albumID.eq(sourceAlbumID) }
                    .fetchOne(db)
                guard let sourceRecord else {
                    continue
                }

                for destinationAlbumID in destinationIDs {
                    try AlbumPhotoRecord.insert {
                        ($0.albumID, $0.photoID, $0.addedAt)
                    }
                    values: {
                        (destinationAlbumID, sourceRecord.photoID, addedAt)
                    }
                    .execute(db)
                }

                try AlbumPhotoRecord
                    .where { $0.id.eq(id) }
                    .delete()
                    .execute(db)
            }
        }
    }

    func removeAlbumPhotos(ids: [Int]) async throws {
        let uniqueIDs = Array(Set(ids))
        guard !uniqueIDs.isEmpty else {
            return
        }

        try await database.write { db in
            for id in uniqueIDs {
                try AlbumPhotoRecord
                    .where { $0.id.eq(id) }
                    .delete()
                    .execute(db)
            }
        }
    }
}

nonisolated struct StoredAlbum {
    let id: Int
    let name: String
    let createdAt: Date
    let photoCount: Int
    let thumbnailLocalIdentifiers: [String]
}
