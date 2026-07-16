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
    let representativeImageURL: URL?
    let representativeImageURLExpiresAt: Date?
    let members: [ShareGroupMember]
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

struct ShareGroupChatItem: Identifiable, Equatable, CommentSheetMessage {
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
    case invalidPagination
}

@MainActor
protocol ShareGroupRepository {
    func prepareCache(for userID: UUID) async throws
    func invalidateCacheSession()
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
    func createSharedAlbum(
        groupID: ShareAlbum.ID,
        name: String,
        idempotencyKey: UUID
    ) async throws -> SharedAlbum
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
    ) async throws -> ShareGroupChatItem
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
    private struct CacheContext {
        let ownerID: UUID
        let sessionID: UUID
    }

    private struct GroupListReconciliation {
        let sessionID: UUID
        var serverIDs: Set<ShareAlbum.ID>
        var requestedCursors: Set<String>
        var nextCursor: String?
    }

    private let api: ShareGroupAPI
    private let store: SharedGroupStore
    private var cacheOwnerID: UUID?
    private var cacheSessionID = UUID()
    private var groupListReconciliation: GroupListReconciliation?
    private var sharedAlbumThumbnailsByGroupID: [ShareAlbum.ID: [SharedAlbum.ID: [SharedAlbumThumbnail]]] = [:]

    init(api: ShareGroupAPI, store: SharedGroupStore = SharedGroupStore()) {
        self.api = api
        self.store = store
    }

    func prepareCache(for userID: UUID) async throws {
        let sessionID = UUID()
        cacheSessionID = sessionID
        cacheOwnerID = nil
        groupListReconciliation = nil
        sharedAlbumThumbnailsByGroupID = [:]
        try await store.prepareCache(for: userID)
        guard cacheSessionID == sessionID else {
            throw CancellationError()
        }
        cacheOwnerID = userID
    }

    func invalidateCacheSession() {
        cacheSessionID = UUID()
        cacheOwnerID = nil
        groupListReconciliation = nil
        sharedAlbumThumbnailsByGroupID = [:]
    }

    func groups() async throws -> [ShareAlbum] {
        let context = try requiredCacheContext()
        let storedGroups = try await store.fetchGroups()
        try validate(context)
        return storedGroups.map {
            Self.makeGroup(
                from: $0,
                thumbnailsByAlbumID: sharedAlbumThumbnailsByGroupID[$0.id] ?? [:]
            )
        }
    }

    func syncGroups(cursor: String?, size: Int) async throws -> ShareGroupRepositoryPage {
        let context = try requiredCacheContext()
        if cursor == nil {
            groupListReconciliation = nil
        }
        let page = try await api.fetchGroups(cursor: cursor, size: size)
        try validate(context)

        var reconciliation = groupListReconciliation(for: cursor, context: context)
        reconciliation?.serverIDs.formUnion(page.items.map(\.id))
        try await store.upsertGroupSummaries(page.items, cacheOwnerID: context.ownerID)
        try validate(context)

        if !page.hasNext, let reconciliation {
            try await store.reconcileGroups(
                serverIDs: reconciliation.serverIDs,
                cacheOwnerID: context.ownerID
            )
            try validate(context)
            groupListReconciliation = nil
        } else if page.hasNext,
                  let nextCursor = page.nextCursor,
                  var reconciliation,
                  !reconciliation.requestedCursors.contains(nextCursor) {
            reconciliation.nextCursor = nextCursor
            groupListReconciliation = reconciliation
        } else {
            groupListReconciliation = nil
        }

        return ShareGroupRepositoryPage(
            itemIDs: page.items.map(\.id),
            nextCursor: page.nextCursor,
            hasNext: page.hasNext
        )
    }

    func syncGroup(id: ShareAlbum.ID) async throws {
        let context = try requiredCacheContext()
        do {
            let detail = try await api.fetchGroup(id: id)
            try validate(context)
            try await store.upsertGroupDetail(detail, cacheOwnerID: context.ownerID)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func members(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupMemberPage {
        let context = try requiredCacheContext()
        do {
            let page = try await api.fetchMembers(groupID: groupID, cursor: cursor, size: size)
            try validate(context)
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
        let context = try requiredCacheContext()
        do {
            let page = try await api.fetchSharedAlbums(
                groupID: groupID,
                cursor: cursor,
                size: size
            )
            try validate(context)
            try await store.upsertSharedAlbums(
                page.items,
                groupID: groupID,
                cacheOwnerID: context.ownerID
            )
            try validate(context)
            let pageThumbnails = Dictionary(uniqueKeysWithValues: page.items.map {
                ($0.id, Self.makeThumbnails(from: $0.thumbnails ?? []))
            })
            if cursor == nil {
                sharedAlbumThumbnailsByGroupID[groupID] = pageThumbnails
            } else {
                sharedAlbumThumbnailsByGroupID[groupID, default: [:]].merge(pageThumbnails) { _, new in new }
            }
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
        let context = try requiredCacheContext()
        if let storedInviteCode = try await store.fetchInviteCode(groupID: groupID) {
            try validate(context)
            return storedInviteCode
        }

        do {
            let response = try await api.fetchInviteCode(groupID: groupID)
            try validate(context)
            try await store.updateInviteCode(response, cacheOwnerID: context.ownerID)
            let inviteCode = try await store.fetchInviteCode(groupID: groupID)
            try validate(context)
            return inviteCode
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreatedShareGroup {
        let context = try requiredCacheContext()
        let response = try await api.createGroup(name: name, idempotencyKey: idempotencyKey)
        try validate(context)
        try await store.upsertCreatedGroup(response, cacheOwnerID: context.ownerID)
        return CreatedShareGroup(id: response.id, inviteCode: response.inviteCode)
    }

    func createSharedAlbum(
        groupID: ShareAlbum.ID,
        name: String,
        idempotencyKey: UUID
    ) async throws -> SharedAlbum {
        let context = try requiredCacheContext()
        do {
            let response = try await api.createSharedAlbum(
                groupID: groupID,
                name: name,
                idempotencyKey: idempotencyKey
            )
            try validate(context)
            try await store.upsertCreatedSharedAlbum(
                response,
                groupID: groupID,
                cacheOwnerID: context.ownerID
            )
            try validate(context)
            let groups = try await store.fetchGroups()
            try validate(context)
            guard let storedAlbum = groups
                .first(where: { $0.id == groupID })?
                .albums
                .first(where: { $0.id == response.id })
            else {
                throw ShareGroupRepositoryError.sharedAlbumNotFound
            }
            return Self.makeSharedAlbum(from: storedAlbum)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreview {
        let context = try requiredCacheContext()
        do {
            let response = try await api.previewJoin(inviteCode: inviteCode)
            try validate(context)
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
                representativeImageURL: response.representativeImageUrl.flatMap(URL.init(string:)),
                representativeImageURLExpiresAt: Self.date(response.representativeImageUrlExpiresAt),
                members: response.members.map(Self.makeMember),
                alreadyJoined: response.alreadyJoined
            )
        } catch let error as NetworkError where error.serverCode == "INVALID_INVITE_CODE" {
            throw ShareGroupRepositoryError.invalidInviteCode
        }
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareAlbum.ID {
        let context = try requiredCacheContext()
        do {
            let response = try await api.join(
                inviteCode: inviteCode,
                idempotencyKey: idempotencyKey
            )
            try validate(context)
            try await store.upsertJoinedGroup(response, cacheOwnerID: context.ownerID)
            return response.sharedGroupId
        } catch let error as NetworkError where error.serverCode == "ALREADY_JOINED_SHARED_GROUP" {
            throw ShareGroupRepositoryError.alreadyJoined
        } catch let error as NetworkError where error.serverCode == "INVALID_INVITE_CODE" {
            throw ShareGroupRepositoryError.invalidInviteCode
        }
    }

    func updateGroupName(id: ShareAlbum.ID, name: String) async throws {
        let context = try requiredCacheContext()
        guard try await cachedRole(groupID: id) == .admin else {
            throw ShareGroupRepositoryError.hostRequired
        }
        try validate(context)

        do {
            let response = try await api.updateGroupName(groupID: id, name: name)
            try validate(context)
            try await store.updateGroup(response, cacheOwnerID: context.ownerID)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func deleteRemoteGroup(id: ShareAlbum.ID) async throws {
        let context = try requiredCacheContext()
        guard try await cachedRole(groupID: id) == .admin else {
            throw ShareGroupRepositoryError.hostRequired
        }
        try validate(context)

        do {
            try await api.deleteGroup(groupID: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            // 이미 원격 삭제가 끝난 재시도도 로컬 캐시 정리로 수렴시킨다.
        }
        try validate(context)
        try await store.deleteGroup(id: id, cacheOwnerID: context.ownerID)
        try validate(context)
        sharedAlbumThumbnailsByGroupID[id] = nil
    }

    func leaveGroup(id: ShareAlbum.ID) async throws {
        let context = try requiredCacheContext()
        guard try await cachedRole(groupID: id) == .participant else {
            throw ShareGroupRepositoryError.memberRequired
        }
        try validate(context)

        do {
            try await api.leaveGroup(groupID: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            // 이미 탈퇴했거나 멤버십이 만료된 경우에도 로컬 캐시를 제거한다.
        }
        try validate(context)
        try await store.deleteGroup(id: id, cacheOwnerID: context.ownerID)
        try validate(context)
        sharedAlbumThumbnailsByGroupID[id] = nil
    }

    func chatTimeline(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupChatPage {
        let context = try requiredCacheContext()
        do {
            let page = try await api.fetchChatTimeline(groupID: groupID, cursor: cursor, size: size)
            try validate(context)
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
    ) async throws -> ShareGroupChatItem {
        let context = try requiredCacheContext()
        do {
            let response = try await api.createChatMessage(
                groupID: groupID,
                content: content,
                idempotencyKey: idempotencyKey
            )
            try validate(context)
            return Self.makeChatItem(response)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    func renameSharedAlbum(id: SharedAlbum.ID, groupID: ShareAlbum.ID, name: String) async throws {
        let context = try requiredCacheContext()
        do {
            let response = try await api.renameSharedAlbum(id: id, name: name)
            try validate(context)
            try await store.updateSharedAlbum(response, cacheOwnerID: context.ownerID)
        } catch let error as NetworkError where error.serverCode == "SHARED_ALBUM_NOT_FOUND" {
            try await reconcileMissingSharedAlbum(
                id: id,
                groupID: groupID,
                context: context
            )
            throw ShareGroupRepositoryError.sharedAlbumNotFound
        }
    }

    func deleteSharedAlbum(id: SharedAlbum.ID, groupID: ShareAlbum.ID) async throws {
        let context = try requiredCacheContext()
        do {
            try await api.deleteSharedAlbum(id: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_ALBUM_NOT_FOUND" {
            try await reconcileMissingSharedAlbum(
                id: id,
                groupID: groupID,
                context: context
            )
            return
        }
        try validate(context)
        try await store.deleteSharedAlbums(ids: [id], cacheOwnerID: context.ownerID)
        try validate(context)
        sharedAlbumThumbnailsByGroupID[groupID]?[id] = nil
    }

    func deleteSharedAlbums(
        ids: [SharedAlbum.ID],
        groupID: ShareAlbum.ID,
        idempotencyKey: UUID
    ) async throws -> SharedAlbumDeletionResult {
        let context = try requiredCacheContext()
        let uniqueIDs = Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }
        guard 1 ... 100 ~= uniqueIDs.count else {
            throw ShareGroupRepositoryError.invalidSharedAlbumSelection
        }

        do {
            let response = try await api.deleteSharedAlbums(
                ids: uniqueIDs,
                idempotencyKey: idempotencyKey
            )
            try validate(context)
            try await store.deleteSharedAlbums(ids: uniqueIDs, cacheOwnerID: context.ownerID)
            try validate(context)
            for id in uniqueIDs {
                sharedAlbumThumbnailsByGroupID[groupID]?[id] = nil
            }
            return SharedAlbumDeletionResult(
                deletedAlbumCount: response.deletedAlbumCount,
                deletedPhotoCount: response.deletedPhotoCount
            )
        } catch let error as NetworkError where error.serverCode == "SHARED_ALBUM_NOT_FOUND" {
            let missingIDs = try await reconcileMissingSharedAlbums(
                ids: Set(uniqueIDs),
                groupID: groupID,
                context: context
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
        let context = try requiredCacheContext()
        try await store.deleteGroup(id: id, cacheOwnerID: context.ownerID)
        try validate(context)
        sharedAlbumThumbnailsByGroupID[id] = nil
    }

    private func cachedRole(groupID: ShareAlbum.ID) async throws -> ShareGroupRole? {
        try await groups().first { $0.id == groupID }?.currentUserRole
    }

    private func reconcileMissingSharedAlbum(
        id: SharedAlbum.ID,
        groupID: ShareAlbum.ID,
        context: CacheContext
    ) async throws {
        try validate(context)
        try await revalidateMembership(groupID: groupID, context: context)
        try await store.deleteSharedAlbums(ids: [id], cacheOwnerID: context.ownerID)
        try validate(context)
        sharedAlbumThumbnailsByGroupID[groupID]?[id] = nil
    }

    private func reconcileMissingSharedAlbums(
        ids: Set<SharedAlbum.ID>,
        groupID: ShareAlbum.ID,
        context: CacheContext
    ) async throws -> Set<SharedAlbum.ID> {
        try validate(context)
        try await revalidateMembership(groupID: groupID, context: context)

        var existingIDs: Set<SharedAlbum.ID> = []
        var cursor: String?
        var requestedCursors: Set<String> = []
        repeat {
            if let cursor, !requestedCursors.insert(cursor).inserted {
                throw ShareGroupRepositoryError.invalidPagination
            }
            let page: SharedAlbumListPageResponse
            do {
                page = try await api.fetchSharedAlbums(
                    groupID: groupID,
                    cursor: cursor,
                    size: 100
                )
                try validate(context)
            } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
                try validate(context)
                try await store.deleteGroup(id: groupID, cacheOwnerID: context.ownerID)
                throw ShareGroupRepositoryError.groupNotFound
            }
            if page.hasNext, page.nextCursor == nil {
                throw ShareGroupRepositoryError.invalidPagination
            }
            try await store.upsertSharedAlbums(
                page.items,
                groupID: groupID,
                cacheOwnerID: context.ownerID
            )
            existingIDs.formUnion(page.items.map(\.id))
            cursor = page.hasNext ? page.nextCursor : nil
        } while cursor != nil

        let missingIDs = ids.subtracting(existingIDs)
        try await store.deleteSharedAlbums(
            ids: Array(missingIDs),
            cacheOwnerID: context.ownerID
        )
        try validate(context)
        for id in missingIDs {
            sharedAlbumThumbnailsByGroupID[groupID]?[id] = nil
        }
        return missingIDs
    }

    private func revalidateMembership(
        groupID: ShareAlbum.ID,
        context: CacheContext
    ) async throws {
        do {
            let detail = try await api.fetchGroup(id: groupID)
            try validate(context)
            try await store.upsertGroupDetail(detail, cacheOwnerID: context.ownerID)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            try validate(context)
            try await store.deleteGroup(id: groupID, cacheOwnerID: context.ownerID)
            throw ShareGroupRepositoryError.groupNotFound
        }
    }

    private func requiredCacheContext() throws -> CacheContext {
        guard let cacheOwnerID else {
            throw SharedGroupStoreError.cacheOwnerChanged
        }
        return CacheContext(ownerID: cacheOwnerID, sessionID: cacheSessionID)
    }

    private func groupListReconciliation(
        for cursor: String?,
        context: CacheContext
    ) -> GroupListReconciliation? {
        guard let cursor else {
            return GroupListReconciliation(
                sessionID: context.sessionID,
                serverIDs: [],
                requestedCursors: [],
                nextCursor: nil
            )
        }
        guard var reconciliation = groupListReconciliation,
              reconciliation.sessionID == context.sessionID,
              reconciliation.nextCursor == cursor,
              reconciliation.requestedCursors.insert(cursor).inserted
        else {
            return nil
        }
        return reconciliation
    }

    private func validate(_ context: CacheContext) throws {
        guard cacheOwnerID == context.ownerID,
              cacheSessionID == context.sessionID
        else {
            throw CancellationError()
        }
    }

    private static func makeGroup(
        from stored: StoredSharedGroup,
        thumbnailsByAlbumID: [SharedAlbum.ID: [SharedAlbumThumbnail]] = [:]
    ) -> ShareAlbum {
        ShareAlbum(
            id: stored.id,
            name: stored.name,
            date: stored.date,
            memberCount: stored.memberCount,
            currentUserRole: ShareGroupRole(rawValue: stored.role) ?? .participant,
            albums: stored.albums.map {
                makeSharedAlbum(
                    from: $0,
                    thumbnails: thumbnailsByAlbumID[$0.id] ?? []
                )
            },
            sharedAlbumCount: stored.sharedAlbumCount,
            photoCount: stored.photoCount,
            createdBy: makeUser(
                id: stored.createdByUserID,
                displayName: stored.createdByDisplayName
            ),
            updatedAt: stored.updatedAt
        )
    }

    private static func makeSharedAlbum(
        from stored: StoredSharedAlbum,
        thumbnails: [SharedAlbumThumbnail] = []
    ) -> SharedAlbum {
        SharedAlbum(
            id: stored.id,
            sharedGroupID: stored.sharedGroupID,
            name: stored.name,
            count: stored.photoCount,
            thumbnails: thumbnails,
            createdBy: makeUser(
                id: stored.createdByUserID,
                displayName: stored.createdByDisplayName
            ),
            isCreator: stored.isCreator,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt
        )
    }

    private static func makeThumbnails(
        from responses: [SharedAlbumThumbnailResponse]
    ) -> [SharedAlbumThumbnail] {
        responses.prefix(3).compactMap { response in
            guard let url = URL(string: response.url),
                  let expiresAt = date(response.urlExpiresAt)
            else {
                return nil
            }
            return SharedAlbumThumbnail(url: url, urlExpiresAt: expiresAt)
        }
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

    private static func makeChatItem(_ response: ChatMessageResponse) -> ShareGroupChatItem {
        ShareGroupChatItem(
            id: response.id,
            type: .chatMessage,
            photoID: nil,
            content: response.content,
            author: makeUser(id: response.author.userId, displayName: response.author.displayName),
            isAuthor: response.isAuthor,
            createdAt: date(response.createdAt) ?? .distantPast,
            updatedAt: date(response.updatedAt) ?? .distantPast
        )
    }

    private static func makeMember(_ response: ShareGroupMemberResponse) -> ShareGroupMember {
        ShareGroupMember(
            id: response.userId,
            displayName: response.displayName,
            role: ShareGroupRole(rawValue: response.role.rawValue) ?? .participant,
            isMe: response.isMe ?? false,
            joinedAt: date(response.joinedAt) ?? .distantPast
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
