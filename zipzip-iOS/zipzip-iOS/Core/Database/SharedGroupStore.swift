//
//  SharedGroupStore.swift
//  zipzip-iOS
//

import Foundation
import SQLiteData

enum SharedGroupStoreError: Error {
    case cacheOwnerChanged
}

nonisolated struct SharedGroupStore {
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

            try #sql(#"DELETE FROM "shared_photo""#).execute(db)
            try #sql(#"DELETE FROM "shared_album""#).execute(db)
            try #sql(#"DELETE FROM "shared_group""#).execute(db)
            try SharedCacheOwnerRecord.upsert {
                SharedCacheOwnerRecord.Draft(id: 1, userID: userID)
            }
            .execute(db)
        }
    }

    func fetchGroups() async throws -> [StoredSharedGroup] {
        try await database.read { db in
            let groupRecords = try SharedGroupRecord
                .order { ($0.updatedAt.desc(), $0.id.asc()) }
                .fetchAll(db)
            let albumRecords = try SharedAlbumRecord
                .order { ($0.updatedAt.desc(), $0.id.asc()) }
                .fetchAll(db)
            let albumsByGroupID = Dictionary(grouping: albumRecords, by: \.sharedGroupID)

            return groupRecords.compactMap { groupRecord in
                let albums = (albumsByGroupID[groupRecord.id] ?? []).compactMap(Self.makeStoredAlbum)
                return Self.makeStoredGroup(groupRecord, albums: albums)
            }
        }
    }

    private static func makeStoredAlbum(_ record: SharedAlbumRecord) -> StoredSharedAlbum? {
        guard let albumID = UUID(uuidString: record.id),
              let groupID = UUID(uuidString: record.sharedGroupID)
        else {
            return nil
        }
        return StoredSharedAlbum(
            id: albumID,
            sharedGroupID: groupID,
            name: record.name,
            photoCount: record.photoCount,
            createdByUserID: record.createdByUserID.flatMap(UUID.init(uuidString:)),
            createdByDisplayName: record.createdByDisplayName,
            isCreator: record.isCreator,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func makeStoredGroup(
        _ record: SharedGroupRecord,
        albums: [StoredSharedAlbum]
    ) -> StoredSharedGroup? {
        guard let id = UUID(uuidString: record.id) else {
            return nil
        }
        return StoredSharedGroup(
            id: id,
            name: record.name,
            date: record.joinedAt ?? record.createdAt ?? record.updatedAt,
            memberCount: record.memberCount,
            role: record.myRole,
            albums: albums,
            sharedAlbumCount: record.sharedAlbumCount,
            photoCount: record.photoCount,
            createdByUserID: record.createdByUserID.flatMap(UUID.init(uuidString:)),
            createdByDisplayName: record.createdByDisplayName,
            updatedAt: record.updatedAt
        )
    }

    func upsertGroupSummaries(
        _ summaries: [ShareGroupSummaryResponse],
        cacheOwnerID: UUID
    ) async throws {
        try await database.write { db in
            let owner = try SharedCacheOwnerRecord
                .where { $0.id.eq(1) }
                .fetchOne(db)
            guard owner?.userID == cacheOwnerID.uuidString else {
                throw SharedGroupStoreError.cacheOwnerChanged
            }

            for summary in summaries {
                let id = summary.id.uuidString
                let existing = try SharedGroupRecord
                    .where { $0.id.eq(id) }
                    .fetchOne(db)
                let updatedAt = Self.date(summary.updatedAt)

                try SharedGroupRecord.upsert {
                    SharedGroupRecord.Draft(
                        id: id,
                        createdByUserID: existing?.createdByUserID,
                        createdByDisplayName: existing?.createdByDisplayName,
                        name: summary.name,
                        inviteCode: existing?.inviteCode,
                        createdAt: existing?.createdAt,
                        joinedAt: Self.date(summary.joinedAt),
                        updatedAt: updatedAt,
                        memberCount: summary.memberCount,
                        sharedAlbumCount: summary.sharedAlbumCount,
                        photoCount: summary.photoCount,
                        myRole: summary.myRole.rawValue
                    )
                }
                .execute(db)
            }
        }
    }

    func upsertGroupDetail(_ detail: ShareGroupDetailResponse) async throws {
        try await database.write { db in
            let id = detail.id.uuidString
            let existing = try SharedGroupRecord
                .where { $0.id.eq(id) }
                .fetchOne(db)

            try SharedGroupRecord.upsert {
                SharedGroupRecord.Draft(
                    id: id,
                    createdByUserID: detail.createdBy.userId?.uuidString,
                    createdByDisplayName: detail.createdBy.displayName,
                    name: detail.name,
                    inviteCode: existing?.inviteCode,
                    createdAt: Self.date(detail.createdAt),
                    joinedAt: existing?.joinedAt,
                    updatedAt: Self.date(detail.updatedAt),
                    memberCount: detail.memberCount,
                    sharedAlbumCount: detail.sharedAlbumCount,
                    photoCount: detail.photoCount,
                    myRole: detail.myRole.rawValue
                )
            }
            .execute(db)
        }
    }

    func upsertSharedAlbums(
        _ albums: [SharedAlbumResponse],
        groupID: UUID
    ) async throws {
        try await database.write { db in
            for album in albums {
                try SharedAlbumRecord.upsert {
                    SharedAlbumRecord.Draft(
                        id: album.id.uuidString,
                        sharedGroupID: groupID.uuidString,
                        name: album.name,
                        photoCount: album.photoCount,
                        createdByUserID: album.createdBy?.userId?.uuidString,
                        createdByDisplayName: album.createdBy?.displayName,
                        isCreator: album.isCreator,
                        createdAt: Self.date(album.createdAt),
                        updatedAt: Self.date(album.updatedAt)
                    )
                }
                .execute(db)
            }
        }
    }

    func upsertCreatedGroup(_ response: CreateSharedGroupResponse) async throws {
        try await database.write { db in
            let createdAt = Self.date(response.createdAt)
            try SharedGroupRecord.upsert {
                SharedGroupRecord.Draft(
                    id: response.id.uuidString,
                    createdByUserID: response.createdBy.userId?.uuidString,
                    createdByDisplayName: response.createdBy.displayName,
                    name: response.name,
                    inviteCode: response.inviteCode,
                    createdAt: createdAt,
                    joinedAt: createdAt,
                    updatedAt: createdAt,
                    memberCount: 1,
                    sharedAlbumCount: 0,
                    photoCount: 0,
                    myRole: response.myRole.rawValue
                )
            }
            .execute(db)
        }
    }

    func upsertJoinedGroup(_ response: ShareGroupJoinResponse) async throws {
        try await database.write { db in
            let joinedAt = Self.date(response.joinedAt)
            let existing = try SharedGroupRecord
                .where { $0.id.eq(response.sharedGroupId.uuidString) }
                .fetchOne(db)

            try SharedGroupRecord.upsert {
                SharedGroupRecord.Draft(
                    id: response.sharedGroupId.uuidString,
                    createdByUserID: existing?.createdByUserID,
                    createdByDisplayName: existing?.createdByDisplayName,
                    name: response.name,
                    inviteCode: existing?.inviteCode,
                    createdAt: existing?.createdAt,
                    joinedAt: joinedAt,
                    updatedAt: joinedAt,
                    memberCount: max(existing?.memberCount ?? 0, 1),
                    sharedAlbumCount: existing?.sharedAlbumCount ?? 0,
                    photoCount: existing?.photoCount ?? 0,
                    myRole: response.myRole.rawValue
                )
            }
            .execute(db)
        }
    }

    func updateInviteCode(_ response: InviteCodeResponse) async throws {
        try await database.write { db in
            try SharedGroupRecord
                .update { $0.inviteCode = #bind(response.inviteCode) }
                .where { $0.id.eq(response.sharedGroupId.uuidString) }
                .execute(db)
        }
    }

    func updateGroup(_ response: ShareGroupUpdateResponse) async throws {
        try await database.write { db in
            try SharedGroupRecord
                .update {
                    $0.name = #bind(response.name)
                    $0.updatedAt = #bind(Self.date(response.updatedAt))
                }
                .where { $0.id.eq(response.id.uuidString) }
                .execute(db)
        }
    }

    func updateSharedAlbum(_ response: SharedAlbumRenameResponse) async throws {
        try await database.write { db in
            try SharedAlbumRecord
                .update {
                    $0.name = #bind(response.name)
                    $0.updatedAt = #bind(Self.date(response.updatedAt))
                }
                .where { $0.id.eq(response.id.uuidString) }
                .execute(db)
        }
    }

    func deleteSharedAlbums(ids: [UUID]) async throws {
        let uniqueIDs = Set(ids.map(\.uuidString))
        guard !uniqueIDs.isEmpty else { return }

        try await database.write { db in
            for id in uniqueIDs {
                try SharedAlbumRecord
                    .where { $0.id.eq(id) }
                    .delete()
                    .execute(db)
            }
        }
    }

    func fetchInviteCode(groupID: UUID) async throws -> String? {
        try await database.read { db in
            try SharedGroupRecord
                .where { $0.id.eq(groupID.uuidString) }
                .select(\.inviteCode)
                .fetchOne(db) ?? nil
        }
    }

    func deleteGroup(id: UUID) async throws {
        try await database.write { db in
            try SharedGroupRecord
                .where { $0.id.eq(id.uuidString) }
                .delete()
                .execute(db)
        }
    }

    private static func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? .now
    }
}

nonisolated struct StoredSharedGroup {
    let id: UUID
    let name: String
    let date: Date
    let memberCount: Int
    let role: String
    let albums: [StoredSharedAlbum]
    let sharedAlbumCount: Int
    let photoCount: Int
    let createdByUserID: UUID?
    let createdByDisplayName: String?
    let updatedAt: Date
}

nonisolated struct StoredSharedAlbum {
    let id: UUID
    let sharedGroupID: UUID
    let name: String
    let photoCount: Int
    let createdByUserID: UUID?
    let createdByDisplayName: String?
    let isCreator: Bool
    let createdAt: Date
    let updatedAt: Date
}
