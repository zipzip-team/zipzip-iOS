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

struct ShareGroupMember: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let role: ShareGroupRole
    let isMe: Bool
    let joinedAt: Date
}

struct ShareGroupMemberPage {
    let items: [ShareGroupMember]
    let nextCursor: String?
    let hasNext: Bool
}

struct ShareGroupChatItem: Identifiable, Equatable {
    let id: UUID
    let type: ChatTimelineItemTypeResponse
    let photoID: UUID?
    let content: String
    let author: ShareGroupUser?
    let isAuthor: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct ShareGroupChatPage {
    let items: [ShareGroupChatItem]
    let nextCursor: String?
    let hasNext: Bool
}

struct SharedAlbumDeletionResult: Equatable {
    let deletedAlbumCount: Int
    let deletedPhotoCount: Int
}

enum ShareGroupRepositoryError: Error, Equatable {
    case groupNotFound
    case invalidInviteCode
    case alreadyJoined
    case hostRequired
    case memberRequired
    case sharedAlbumNotFound
    case invalidSharedAlbumSelection
}

@MainActor
protocol ShareGroupRepository {
    func prepareCache(for userID: UUID) async throws
    func groups() async throws -> [ShareAlbum]
    func syncGroups(cursor: String?, size: Int) async throws -> ShareGroupRepositoryPage
    func syncGroup(id: ShareAlbum.ID) async throws
    func members(groupID: ShareAlbum.ID, cursor: String?, size: Int) async throws -> ShareGroupMemberPage
    func syncSharedAlbums(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupRepositoryPage
    func inviteCode(groupID: ShareAlbum.ID) async throws -> String?
    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreatedShareGroup
    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreview
    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareAlbum.ID
    func updateGroupName(id: ShareAlbum.ID, name: String) async throws
    func deleteRemoteGroup(id: ShareAlbum.ID) async throws
    func leaveGroup(id: ShareAlbum.ID) async throws
    func chatTimeline(groupID: ShareAlbum.ID, cursor: String?, size: Int) async throws -> ShareGroupChatPage
    func createChatMessage(
        groupID: ShareAlbum.ID,
        content: String,
        idempotencyKey: UUID
    ) async throws
    func renameSharedAlbum(id: SharedAlbum.ID, groupID: ShareAlbum.ID, name: String) async throws
    func deleteSharedAlbum(id: SharedAlbum.ID, groupID: ShareAlbum.ID) async throws
    func deleteSharedAlbums(
        ids: [SharedAlbum.ID],
        groupID: ShareAlbum.ID,
        idempotencyKey: UUID
    ) async throws -> SharedAlbumDeletionResult
    func removeCachedGroup(id: ShareAlbum.ID) async throws
}

@MainActor
final class DefaultShareGroupRepository: ShareGroupRepository {
    private let api: ShareGroupAPI
    private let store: SharedGroupStore

    init(api: ShareGroupAPI, store: SharedGroupStore = SharedGroupStore()) {
        self.api = api
        self.store = store
    }

    func prepareCache(for userID: UUID) async throws {
        try await store.prepareCache(for: userID)
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

    func members(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupMemberPage {
        do {
            let page = try await api.fetchMembers(groupID: groupID, cursor: cursor, size: size)
            return ShareGroupMemberPage(
                items: page.items.map {
                    ShareGroupMember(
                        id: $0.userId,
                        displayName: $0.displayName,
                        role: ShareGroupRole(rawValue: $0.role.rawValue) ?? .participant,
                        isMe: $0.isMe ?? false,
                        joinedAt: Self.date($0.joinedAt) ?? .distantPast
                    )
                },
                nextCursor: page.nextCursor,
                hasNext: page.hasNext
            )
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

    func updateGroupName(id: ShareAlbum.ID, name: String) async throws {
        guard try await cachedRole(groupID: id) == .admin else {
            throw ShareGroupRepositoryError.hostRequired
        }

        do {
            let response = try await api.updateGroupName(groupID: id, name: name)
            try await store.updateGroup(response)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func deleteRemoteGroup(id: ShareAlbum.ID) async throws {
        guard try await cachedRole(groupID: id) == .admin else {
            throw ShareGroupRepositoryError.hostRequired
        }

        do {
            try await api.deleteGroup(groupID: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            // 이미 원격 삭제가 끝난 재시도도 로컬 캐시 정리로 수렴시킨다.
        }
        try await store.deleteGroup(id: id)
    }

    func leaveGroup(id: ShareAlbum.ID) async throws {
        guard try await cachedRole(groupID: id) == .participant else {
            throw ShareGroupRepositoryError.memberRequired
        }

        do {
            try await api.leaveGroup(groupID: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            // 이미 탈퇴했거나 멤버십이 만료된 경우에도 로컬 캐시를 제거한다.
        }
        try await store.deleteGroup(id: id)
    }

    func chatTimeline(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupChatPage {
        do {
            let page = try await api.fetchChatTimeline(groupID: groupID, cursor: cursor, size: size)
            return ShareGroupChatPage(
                items: page.items.map(Self.makeChatItem),
                nextCursor: page.nextCursor,
                hasNext: page.hasNext
            )
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func createChatMessage(
        groupID: ShareAlbum.ID,
        content: String,
        idempotencyKey: UUID
    ) async throws {
        do {
            _ = try await api.createChatMessage(
                groupID: groupID,
                content: content,
                idempotencyKey: idempotencyKey
            )
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func renameSharedAlbum(id: SharedAlbum.ID, groupID: ShareAlbum.ID, name: String) async throws {
        do {
            let response = try await api.renameSharedAlbum(id: id, name: name)
            try await store.updateSharedAlbum(response)
        } catch let error as NetworkError where error.serverCode == "SHARED_ALBUM_NOT_FOUND" {
            try await reconcileMissingSharedAlbum(id: id, groupID: groupID)
            throw ShareGroupRepositoryError.sharedAlbumNotFound
        }
    }

    func deleteSharedAlbum(id: SharedAlbum.ID, groupID: ShareAlbum.ID) async throws {
        do {
            try await api.deleteSharedAlbum(id: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_ALBUM_NOT_FOUND" {
            try await reconcileMissingSharedAlbum(id: id, groupID: groupID)
            return
        }
        try await store.deleteSharedAlbums(ids: [id])
    }

    func deleteSharedAlbums(
        ids: [SharedAlbum.ID],
        groupID: ShareAlbum.ID,
        idempotencyKey: UUID
    ) async throws -> SharedAlbumDeletionResult {
        let uniqueIDs = Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }
        guard 1 ... 100 ~= uniqueIDs.count else {
            throw ShareGroupRepositoryError.invalidSharedAlbumSelection
        }

        do {
            let response = try await api.deleteSharedAlbums(
                ids: uniqueIDs,
                idempotencyKey: idempotencyKey
            )
            try await store.deleteSharedAlbums(ids: uniqueIDs)
            return SharedAlbumDeletionResult(
                deletedAlbumCount: response.deletedAlbumCount,
                deletedPhotoCount: response.deletedPhotoCount
            )
        } catch let error as NetworkError where error.serverCode == "SHARED_ALBUM_NOT_FOUND" {
            let missingIDs = try await reconcileMissingSharedAlbums(
                ids: Set(uniqueIDs),
                groupID: groupID
            )
            if missingIDs.count == uniqueIDs.count {
                return SharedAlbumDeletionResult(
                    deletedAlbumCount: uniqueIDs.count,
                    deletedPhotoCount: 0
                )
            }
            throw ShareGroupRepositoryError.sharedAlbumNotFound
        }
    }

    func removeCachedGroup(id: ShareAlbum.ID) async throws {
        try await store.deleteGroup(id: id)
    }

    private func cachedRole(groupID: ShareAlbum.ID) async throws -> ShareGroupRole? {
        try await groups().first { $0.id == groupID }?.currentUserRole
    }

    private func reconcileMissingSharedAlbum(
        id: SharedAlbum.ID,
        groupID: ShareAlbum.ID
    ) async throws {
        try await revalidateMembership(groupID: groupID)
        try await store.deleteSharedAlbums(ids: [id])
    }

    private func reconcileMissingSharedAlbums(
        ids: Set<SharedAlbum.ID>,
        groupID: ShareAlbum.ID
    ) async throws -> Set<SharedAlbum.ID> {
        try await revalidateMembership(groupID: groupID)

        var existingIDs: Set<SharedAlbum.ID> = []
        var cursor: String?
        repeat {
            let page: SharedAlbumListPageResponse
            do {
                page = try await api.fetchSharedAlbums(
                    groupID: groupID,
                    cursor: cursor,
                    size: 100
                )
            } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
                try await store.deleteGroup(id: groupID)
                throw ShareGroupRepositoryError.groupNotFound
            }
            try await store.upsertSharedAlbums(page.items, groupID: groupID)
            existingIDs.formUnion(page.items.map(\.id))
            cursor = page.hasNext ? page.nextCursor : nil
        } while cursor != nil

        let missingIDs = ids.subtracting(existingIDs)
        try await store.deleteSharedAlbums(ids: Array(missingIDs))
        return missingIDs
    }

    private func revalidateMembership(groupID: ShareAlbum.ID) async throws {
        do {
            let detail = try await api.fetchGroup(id: groupID)
            try await store.upsertGroupDetail(detail)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            try await store.deleteGroup(id: groupID)
            throw ShareGroupRepositoryError.groupNotFound
        }
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

    private static func makeChatItem(_ response: ChatTimelineItemResponse) -> ShareGroupChatItem {
        ShareGroupChatItem(
            id: response.id,
            type: response.type,
            photoID: response.photoId,
            content: response.content,
            author: makeUser(id: response.author.userId, displayName: response.author.displayName),
            isAuthor: response.isAuthor,
            createdAt: date(response.createdAt) ?? .distantPast,
            updatedAt: date(response.updatedAt) ?? .distantPast
        )
    }

    private static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
