//
//  ShareGroupRepository.swift
//  zipzip-iOS
//

import Foundation

struct ShareGroupRepositoryPage {
    let itemIDs: [UUID]
    let nextCursor: String?
    let hasNext: Bool
}

struct CreatedShareGroup {
    let id: UUID
    let inviteCode: String
}

struct ShareGroupJoinPreview {
    let group: ShareAlbum
    let alreadyJoined: Bool
}

enum ShareGroupRepositoryError: Error, Equatable {
    case groupNotFound
    case invalidInviteCode
    case alreadyJoined
}

@MainActor
protocol ShareGroupRepository {
    func groups() async throws -> [ShareAlbum]
    func syncGroups(cursor: String?, size: Int) async throws -> ShareGroupRepositoryPage
    func syncGroup(id: ShareAlbum.ID) async throws
    func syncSharedAlbums(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupRepositoryPage
    func inviteCode(groupID: ShareAlbum.ID) async throws -> String?
    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreatedShareGroup
    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreview
    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareAlbum.ID
    func deleteGroup(id: ShareAlbum.ID) async throws
}

@MainActor
final class DefaultShareGroupRepository: ShareGroupRepository {
    private let api: ShareGroupAPI
    private let store: SharedGroupStore

    init(api: ShareGroupAPI, store: SharedGroupStore = SharedGroupStore()) {
        self.api = api
        self.store = store
    }

    func groups() async throws -> [ShareAlbum] {
        try await store.fetchGroups().map(Self.makeGroup)
    }

    func syncGroups(cursor: String?, size: Int) async throws -> ShareGroupRepositoryPage {
        let page = try await api.fetchGroups(cursor: cursor, size: size)
        try await store.upsertGroupSummaries(page.items)
        return ShareGroupRepositoryPage(
            itemIDs: page.items.map(\.id),
            nextCursor: page.nextCursor,
            hasNext: page.hasNext
        )
    }

    func syncGroup(id: ShareAlbum.ID) async throws {
        do {
            let detail = try await api.fetchGroup(id: id)
            try await store.upsertGroupDetail(detail)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func syncSharedAlbums(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupRepositoryPage {
        do {
            let page = try await api.fetchSharedAlbums(
                groupID: groupID,
                cursor: cursor,
                size: size
            )
            try await store.upsertSharedAlbums(page.items, groupID: groupID)
            return ShareGroupRepositoryPage(
                itemIDs: page.items.map(\.id),
                nextCursor: page.nextCursor,
                hasNext: page.hasNext
            )
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func inviteCode(groupID: ShareAlbum.ID) async throws -> String? {
        if let storedInviteCode = try await store.fetchInviteCode(groupID: groupID) {
            return storedInviteCode
        }

        do {
            let response = try await api.fetchInviteCode(groupID: groupID)
            try await store.updateInviteCode(response)
            return try await store.fetchInviteCode(groupID: groupID)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreatedShareGroup {
        let response = try await api.createGroup(name: name, idempotencyKey: idempotencyKey)
        try await store.upsertCreatedGroup(response)
        return CreatedShareGroup(id: response.id, inviteCode: response.inviteCode)
    }

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreview {
        do {
            let response = try await api.previewJoin(inviteCode: inviteCode)
            return ShareGroupJoinPreview(
                group: ShareAlbum(
                    id: response.sharedGroupId,
                    name: response.name,
                    date: .now,
                    memberCount: response.memberCount,
                    currentUserRole: .participant,
                    createdBy: Self.makeUser(
                        id: response.createdBy.userId,
                        displayName: response.createdBy.displayName
                    )
                ),
                alreadyJoined: response.alreadyJoined
            )
        } catch let error as NetworkError where error.serverCode == "INVALID_INVITE_CODE" {
            throw ShareGroupRepositoryError.invalidInviteCode
        }
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareAlbum.ID {
        do {
            let response = try await api.join(
                inviteCode: inviteCode,
                idempotencyKey: idempotencyKey
            )
            try await store.upsertJoinedGroup(response)
            return response.sharedGroupId
        } catch let error as NetworkError where error.serverCode == "ALREADY_JOINED_SHARED_GROUP" {
            throw ShareGroupRepositoryError.alreadyJoined
        } catch let error as NetworkError where error.serverCode == "INVALID_INVITE_CODE" {
            throw ShareGroupRepositoryError.invalidInviteCode
        }
    }

    func deleteGroup(id: ShareAlbum.ID) async throws {
        try await store.deleteGroup(id: id)
    }

    private static func makeGroup(from stored: StoredSharedGroup) -> ShareAlbum {
        ShareAlbum(
            id: stored.id,
            name: stored.name,
            date: stored.date,
            memberCount: stored.memberCount,
            currentUserRole: ShareGroupRole(rawValue: stored.role) ?? .participant,
            albums: stored.albums.map(makeSharedAlbum),
            sharedAlbumCount: stored.sharedAlbumCount,
            photoCount: stored.photoCount,
            createdBy: makeUser(
                id: stored.createdByUserID,
                displayName: stored.createdByDisplayName
            ),
            updatedAt: stored.updatedAt
        )
    }

    private static func makeSharedAlbum(from stored: StoredSharedAlbum) -> SharedAlbum {
        SharedAlbum(
            id: stored.id,
            sharedGroupID: stored.sharedGroupID,
            name: stored.name,
            count: stored.photoCount,
            createdBy: makeUser(
                id: stored.createdByUserID,
                displayName: stored.createdByDisplayName
            ),
            isCreator: stored.isCreator,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt
        )
    }

    private static func makeUser(id: UUID?, displayName: String?) -> ShareGroupUser? {
        guard id != nil || displayName != nil else { return nil }
        return ShareGroupUser(id: id, displayName: displayName)
    }
}
