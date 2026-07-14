//
//  ShareViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

enum ShareImportSelection: Hashable {
    case photos
    case albums
}

struct ShareAlbumManagementTarget: Equatable {
    let groupID: ShareAlbum.ID
    let albumID: SharedAlbum.ID
}

@Observable
@MainActor
final class ShareViewModel {
    private(set) var groups: [ShareAlbum]
    private let store: SharedGroupStore

    var isAddMode = false
    var isJoinSheetPresented = false
    var isJoinConfirmationPresented = false
    var isCreateSheetPresented = false
    var isInviteSheetPresented = false
    var isCommentsPresented = false
    var isAlbumManagementPresented = false
    var isShareManagementPresented = false
    private(set) var isCreatingGroup = false

    private(set) var hasLoadedGroups = false
    private(set) var isLoadingGroups = false
    private(set) var isLoadingMoreGroups = false

    var joinCode = ""
    var groupNameDraft = ""
    var inviteCode = ""
    var commentDraft = ""
    var albumNameDraft = ""
    var shareGroupNameDraft = ""

    private(set) var pendingJoinGroup: ShareAlbum?
    private(set) var albumManagementTarget: ShareAlbumManagementTarget?
    private(set) var managedShareGroup: ShareAlbum?

    private var groupCreationName: String?
    private var groupCreationIdempotencyKey: UUID?
    private var nextGroupCursor: String?
    private var groupsHaveNextPage = false
    private var loadedGroupDetailIDs: Set<ShareAlbum.ID> = []
    private var loadingGroupDetailIDs: Set<ShareAlbum.ID> = []
    private var loadedSharedAlbumGroupIDs: Set<ShareAlbum.ID> = []
    private var loadingSharedAlbumGroupIDs: Set<ShareAlbum.ID> = []
    private var loadingMoreSharedAlbumGroupIDs: Set<ShareAlbum.ID> = []
    private var sharedAlbumNextCursors: [ShareAlbum.ID: String] = [:]
    private var sharedAlbumHasNextPage: [ShareAlbum.ID: Bool] = [:]
    private var inviteCodes: [ShareAlbum.ID: String] = [:]
    private var loadingInviteCodeGroupIDs: Set<ShareAlbum.ID> = []
    private var visibleGroupIDs: [ShareAlbum.ID]?
    private var visibleSharedAlbumIDs: [ShareAlbum.ID: [SharedAlbum.ID]] = [:]

    init(store: SharedGroupStore = SharedGroupStore()) {
        self.groups = []
        self.store = store
    }

    init(groups: [ShareAlbum], store: SharedGroupStore = SharedGroupStore()) {
        self.groups = groups
        self.store = store
        self.hasLoadedGroups = true
    }

    func group(withID id: ShareAlbum.ID) -> ShareAlbum? {
        groups.first { $0.id == id }
    }

    func album(groupID: ShareAlbum.ID, albumID: SharedAlbum.ID) -> SharedAlbum? {
        group(withID: groupID)?.albums.first { $0.id == albumID }
    }

    func hasLoadedSharedAlbums(groupID: ShareAlbum.ID) -> Bool {
        loadedSharedAlbumGroupIDs.contains(groupID)
    }

    func inviteCode(for groupID: ShareAlbum.ID) -> String? {
        inviteCodes[groupID]
    }

    func isInviteCodeAvailable(for groupID: ShareAlbum.ID) -> Bool {
        inviteCodes[groupID] != nil
    }

    func loadGroups(using api: ShareGroupAPI, refresh: Bool = false) async {
        guard !isLoadingGroups, !isLoadingMoreGroups else { return }
        guard refresh || !hasLoadedGroups else { return }

        isLoadingGroups = true
        defer { isLoadingGroups = false }

        if !refresh, !hasLoadedGroups {
            try? await reloadGroupsFromDatabase()
        }

        do {
            let page = try await api.fetchGroups(cursor: nil, size: 20)
            try await store.upsertGroupSummaries(page.items)
            visibleGroupIDs = page.items.map(\.id)
            try await reloadGroupsFromDatabase()
            nextGroupCursor = page.nextCursor
            groupsHaveNextPage = page.hasNext
            hasLoadedGroups = true
        } catch {
            hasLoadedGroups = !groups.isEmpty
        }
    }

    func loadMoreGroupsIfNeeded(currentGroupID: ShareAlbum.ID, using api: ShareGroupAPI) async {
        guard groups.last?.id == currentGroupID,
              groupsHaveNextPage,
              let nextGroupCursor,
              !isLoadingGroups,
              !isLoadingMoreGroups
        else {
            return
        }

        isLoadingMoreGroups = true
        defer { isLoadingMoreGroups = false }

        do {
            let page = try await api.fetchGroups(cursor: nextGroupCursor, size: 20)
            try await store.upsertGroupSummaries(page.items)
            var groupIDs = visibleGroupIDs ?? groups.map(\.id)
            for id in page.items.map(\.id) where !groupIDs.contains(id) {
                groupIDs.append(id)
            }
            visibleGroupIDs = groupIDs
            try await reloadGroupsFromDatabase()
            self.nextGroupCursor = page.nextCursor
            groupsHaveNextPage = page.hasNext
        } catch {}
    }

    func loadGroup(id: ShareAlbum.ID, using api: ShareGroupAPI, refresh: Bool = false) async {
        guard !loadingGroupDetailIDs.contains(id) else { return }
        guard refresh || !loadedGroupDetailIDs.contains(id) else { return }

        loadingGroupDetailIDs.insert(id)
        defer { loadingGroupDetailIDs.remove(id) }

        do {
            let detail = try await api.fetchGroup(id: id)
            try await store.upsertGroupDetail(detail)
            if var groupIDs = visibleGroupIDs, !groupIDs.contains(id) {
                groupIDs.append(id)
                visibleGroupIDs = groupIDs
            }
            try await reloadGroupsFromDatabase()
            loadedGroupDetailIDs.insert(id)
            refreshManagedGroupIfNeeded(id: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            await removeRemoteGroup(id: id)
        } catch {}
    }

    func loadSharedAlbums(
        groupID: ShareAlbum.ID,
        using api: ShareGroupAPI,
        refresh: Bool = false
    ) async {
        guard !loadingSharedAlbumGroupIDs.contains(groupID),
              !loadingMoreSharedAlbumGroupIDs.contains(groupID)
        else {
            return
        }
        guard refresh || !loadedSharedAlbumGroupIDs.contains(groupID) else { return }

        loadingSharedAlbumGroupIDs.insert(groupID)
        defer { loadingSharedAlbumGroupIDs.remove(groupID) }

        do {
            let page = try await api.fetchSharedAlbums(groupID: groupID, cursor: nil, size: 20)
            try await store.upsertSharedAlbums(page.items, groupID: groupID)
            visibleSharedAlbumIDs[groupID] = page.items.map(\.id)
            try await reloadGroupsFromDatabase()
            updateSharedAlbumPageState(page, groupID: groupID)
            loadedSharedAlbumGroupIDs.insert(groupID)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            await removeRemoteGroup(id: groupID)
        } catch {}
    }

    func loadMoreSharedAlbumsIfNeeded(
        groupID: ShareAlbum.ID,
        currentAlbumID: SharedAlbum.ID,
        using api: ShareGroupAPI
    ) async {
        guard group(withID: groupID)?.albums.last?.id == currentAlbumID,
              sharedAlbumHasNextPage[groupID] == true,
              let cursor = sharedAlbumNextCursors[groupID],
              !loadingSharedAlbumGroupIDs.contains(groupID),
              !loadingMoreSharedAlbumGroupIDs.contains(groupID)
        else {
            return
        }

        loadingMoreSharedAlbumGroupIDs.insert(groupID)
        defer { loadingMoreSharedAlbumGroupIDs.remove(groupID) }

        do {
            let page = try await api.fetchSharedAlbums(groupID: groupID, cursor: cursor, size: 20)
            try await store.upsertSharedAlbums(page.items, groupID: groupID)
            var albumIDs = visibleSharedAlbumIDs[groupID] ?? group(withID: groupID)?.albums.map(\.id) ?? []
            for id in page.items.map(\.id) where !albumIDs.contains(id) {
                albumIDs.append(id)
            }
            visibleSharedAlbumIDs[groupID] = albumIDs
            try await reloadGroupsFromDatabase()
            updateSharedAlbumPageState(page, groupID: groupID)
        } catch {}
    }

    func loadInviteCode(groupID: ShareAlbum.ID, using api: ShareGroupAPI) async {
        guard inviteCodes[groupID] == nil,
              !loadingInviteCodeGroupIDs.contains(groupID)
        else {
            return
        }

        loadingInviteCodeGroupIDs.insert(groupID)
        defer { loadingInviteCodeGroupIDs.remove(groupID) }

        do {
            if let storedInviteCode = try await store.fetchInviteCode(groupID: groupID) {
                inviteCodes[groupID] = storedInviteCode
                return
            }

            let response = try await api.fetchInviteCode(groupID: groupID)
            try await store.updateInviteCode(response)
            inviteCodes[groupID] = try await store.fetchInviteCode(groupID: groupID)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            await removeRemoteGroup(id: groupID)
        } catch {}
    }

    func resetRemoteData() {
        groups = []
        hasLoadedGroups = false
        isLoadingGroups = false
        isLoadingMoreGroups = false
        nextGroupCursor = nil
        groupsHaveNextPage = false
        loadedGroupDetailIDs = []
        loadingGroupDetailIDs = []
        loadedSharedAlbumGroupIDs = []
        loadingSharedAlbumGroupIDs = []
        loadingMoreSharedAlbumGroupIDs = []
        sharedAlbumNextCursors = [:]
        sharedAlbumHasNextPage = [:]
        inviteCodes = [:]
        loadingInviteCodeGroupIDs = []
        visibleGroupIDs = nil
        visibleSharedAlbumIDs = [:]
        inviteCode = ""
    }

    func enterAddMode() {
        isAddMode = true
    }

    func exitAddMode() {
        isAddMode = false
    }

    func presentJoinSheet() {
        joinCode = ""
        isJoinSheetPresented = true
    }

    func confirmJoinCode() {
        let trimmedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return }
    }

    func cancelJoinConfirmation() {
        pendingJoinGroup = nil
        isJoinConfirmationPresented = false
    }

    func completeJoin() {
        pendingJoinGroup = nil
        isJoinConfirmationPresented = false
        isAddMode = false
    }

    func presentCreateSheet() {
        groupNameDraft = ""
        groupCreationName = nil
        groupCreationIdempotencyKey = nil
        isCreateSheetPresented = true
    }

    func createGroup(using api: ShareGroupAPI) async {
        let trimmedName = groupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isCreatingGroup else { return }

        let idempotencyKey: UUID
        if groupCreationName == trimmedName, let groupCreationIdempotencyKey {
            idempotencyKey = groupCreationIdempotencyKey
        } else {
            idempotencyKey = UUID()
            groupCreationName = trimmedName
            groupCreationIdempotencyKey = idempotencyKey
        }

        isCreatingGroup = true
        defer { isCreatingGroup = false }

        do {
            let response = try await api.createGroup(name: trimmedName, idempotencyKey: idempotencyKey)
            try await store.upsertCreatedGroup(response)
            if var groupIDs = visibleGroupIDs {
                groupIDs.removeAll { $0 == response.id }
                groupIDs.insert(response.id, at: 0)
                visibleGroupIDs = groupIDs
            }
            try await reloadGroupsFromDatabase()
            hasLoadedGroups = true
            inviteCode = try await store.fetchInviteCode(groupID: response.id) ?? ""
            inviteCodes[response.id] = inviteCode
            groupCreationName = nil
            groupCreationIdempotencyKey = nil
            isCreateSheetPresented = false
            isInviteSheetPresented = true
        } catch {}
    }

    func completeInvitation() {
        isInviteSheetPresented = false
        isAddMode = false
    }

    @discardableResult
    func addAlbums(_ albums: [SharedAlbum], to groupID: ShareAlbum.ID) -> Bool {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else { return false }
        let existingIDs = Set(groups[groupIndex].albums.map(\.id))
        groups[groupIndex].albums.append(contentsOf: albums.filter { !existingIDs.contains($0.id) })
        return true
    }

    func removeAlbums(_ albumIDs: Set<SharedAlbum.ID>, from groupID: ShareAlbum.ID) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[groupIndex].albums.removeAll { albumIDs.contains($0.id) }
    }

    func presentAlbumManagement(groupID: ShareAlbum.ID, albumID: SharedAlbum.ID) {
        guard let album = album(groupID: groupID, albumID: albumID) else { return }
        albumNameDraft = album.name
        albumManagementTarget = .init(groupID: groupID, albumID: albumID)
        isAlbumManagementPresented = true
    }

    func completeAlbumManagement() {
        dismissAlbumManagement()
    }

    func renameAlbum(groupID: ShareAlbum.ID, albumID: SharedAlbum.ID, to name: String) {}

    func deleteManagedAlbum() {
        dismissAlbumManagement()
    }

    func dismissAlbumManagement() {
        isAlbumManagementPresented = false
        albumManagementTarget = nil
    }

    func presentShareManagement(groupID: ShareAlbum.ID) {
        guard let group = group(withID: groupID) else { return }
        shareGroupNameDraft = group.name
        managedShareGroup = group
        isShareManagementPresented = true
    }

    func completeShareManagement() {
        dismissShareManagement()
    }

    @discardableResult
    func leaveManagedShareGroup() -> Bool {
        false
    }

    func dismissShareManagement() {
        isShareManagementPresented = false
        managedShareGroup = nil
    }

    func resetTransientUI() {
        isAddMode = false
        isJoinSheetPresented = false
        isJoinConfirmationPresented = false
        isCreateSheetPresented = false
        isInviteSheetPresented = false
        isCommentsPresented = false
        isShareManagementPresented = false
        pendingJoinGroup = nil
        managedShareGroup = nil
        dismissAlbumManagement()
    }

    private func makeGroup(from stored: StoredSharedGroup) -> ShareAlbum {
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

    private func makeSharedAlbum(from stored: StoredSharedAlbum) -> SharedAlbum {
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

    private func makeUser(id: UUID?, displayName: String?) -> ShareGroupUser? {
        guard id != nil || displayName != nil else { return nil }
        return ShareGroupUser(id: id, displayName: displayName)
    }

    private func reloadGroupsFromDatabase() async throws {
        let storedGroups = try await store.fetchGroups()
        let storedByID = Dictionary(uniqueKeysWithValues: storedGroups.map { ($0.id, $0) })
        let orderedGroups: [StoredSharedGroup]
        if let visibleGroupIDs {
            orderedGroups = visibleGroupIDs.compactMap { storedByID[$0] }
        } else {
            orderedGroups = storedGroups
        }

        groups = orderedGroups.map { stored in
            var group = makeGroup(from: stored)
            if let albumIDs = visibleSharedAlbumIDs[group.id] {
                let albumsByID = Dictionary(uniqueKeysWithValues: group.albums.map { ($0.id, $0) })
                group.albums = albumIDs.compactMap { albumsByID[$0] }
            }
            return group
        }

        if let managedGroupID = managedShareGroup?.id {
            refreshManagedGroupIfNeeded(id: managedGroupID)
        }
    }

    private func updateSharedAlbumPageState(
        _ page: SharedAlbumListPageResponse,
        groupID: ShareAlbum.ID
    ) {
        if let nextCursor = page.nextCursor {
            sharedAlbumNextCursors[groupID] = nextCursor
        } else {
            sharedAlbumNextCursors.removeValue(forKey: groupID)
        }
        sharedAlbumHasNextPage[groupID] = page.hasNext
    }

    private func refreshManagedGroupIfNeeded(id: ShareAlbum.ID) {
        guard managedShareGroup?.id == id else { return }
        managedShareGroup = group(withID: id)
    }

    private func removeRemoteGroup(id: ShareAlbum.ID) async {
        try? await store.deleteGroup(id: id)
        visibleGroupIDs?.removeAll { $0 == id }
        visibleSharedAlbumIDs.removeValue(forKey: id)
        try? await reloadGroupsFromDatabase()
        loadedGroupDetailIDs.remove(id)
        loadedSharedAlbumGroupIDs.remove(id)
        sharedAlbumNextCursors.removeValue(forKey: id)
        sharedAlbumHasNextPage.removeValue(forKey: id)
        inviteCodes.removeValue(forKey: id)
        if managedShareGroup?.id == id {
            dismissShareManagement()
        }
    }
}
