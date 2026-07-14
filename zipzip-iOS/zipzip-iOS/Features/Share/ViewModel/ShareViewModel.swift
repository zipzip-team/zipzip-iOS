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

    init() {
        self.groups = []
    }

    init(groups: [ShareAlbum]) {
        self.groups = groups
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

        do {
            let page = try await api.fetchGroups(cursor: nil, size: 20)
            let existingGroups = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
            groups = page.items.map { makeGroup(from: $0, preserving: existingGroups[$0.id]) }
            nextGroupCursor = page.nextCursor
            groupsHaveNextPage = page.hasNext
            hasLoadedGroups = true
        } catch {}
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
            for summary in page.items {
                if let index = groups.firstIndex(where: { $0.id == summary.id }) {
                    groups[index] = makeGroup(from: summary, preserving: groups[index])
                } else {
                    groups.append(makeGroup(from: summary))
                }
            }
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
            let existing = group(withID: id)
            let group = makeGroup(from: detail, preserving: existing)
            if let index = groups.firstIndex(where: { $0.id == id }) {
                groups[index] = group
            } else {
                groups.append(group)
            }
            loadedGroupDetailIDs.insert(id)
            refreshManagedGroupIfNeeded(id: id)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            removeRemoteGroup(id: id)
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
            updateSharedAlbums(
                page.items.map { makeSharedAlbum(from: $0, groupID: groupID) },
                groupID: groupID,
                replacing: true
            )
            updateSharedAlbumPageState(page, groupID: groupID)
            loadedSharedAlbumGroupIDs.insert(groupID)
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            removeRemoteGroup(id: groupID)
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
            updateSharedAlbums(
                page.items.map { makeSharedAlbum(from: $0, groupID: groupID) },
                groupID: groupID,
                replacing: false
            )
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
            let response = try await api.fetchInviteCode(groupID: groupID)
            inviteCodes[response.sharedGroupId] = response.inviteCode
        } catch let error as NetworkError where error.serverCode == "SHARED_GROUP_NOT_FOUND" {
            removeRemoteGroup(id: groupID)
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
            let createdGroup = ShareAlbum(
                id: response.id,
                name: response.name,
                date: .now,
                memberCount: 1,
                currentUserRole: .admin
            )
            if !groups.contains(where: { $0.id == response.id }) {
                groups.insert(createdGroup, at: 0)
            }
            hasLoadedGroups = true
            inviteCode = response.inviteCode
            inviteCodes[response.id] = response.inviteCode
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

    private func makeGroup(
        from response: ShareGroupSummaryResponse,
        preserving existing: ShareAlbum? = nil
    ) -> ShareAlbum {
        ShareAlbum(
            id: response.id,
            name: response.name,
            date: apiDate(response.joinedAt),
            memberCount: response.memberCount,
            currentUserRole: response.myRole.model,
            albums: existing?.albums ?? [],
            sharedAlbumCount: response.sharedAlbumCount,
            photoCount: response.photoCount,
            createdBy: existing?.createdBy,
            updatedAt: apiDate(response.updatedAt)
        )
    }

    private func makeGroup(
        from response: ShareGroupDetailResponse,
        preserving existing: ShareAlbum? = nil
    ) -> ShareAlbum {
        ShareAlbum(
            id: response.id,
            name: response.name,
            date: apiDate(response.createdAt),
            memberCount: response.memberCount,
            currentUserRole: response.myRole.model,
            albums: existing?.albums ?? [],
            sharedAlbumCount: response.sharedAlbumCount,
            photoCount: response.photoCount,
            createdBy: response.createdBy.model,
            updatedAt: apiDate(response.updatedAt)
        )
    }

    private func makeSharedAlbum(from response: SharedAlbumResponse, groupID: ShareAlbum.ID) -> SharedAlbum {
        SharedAlbum(
            id: response.id,
            sharedGroupID: groupID,
            name: response.name,
            count: response.photoCount,
            createdBy: response.createdBy?.model,
            isCreator: response.isCreator,
            createdAt: apiDate(response.createdAt),
            updatedAt: apiDate(response.updatedAt)
        )
    }

    private func updateSharedAlbums(
        _ albums: [SharedAlbum],
        groupID: ShareAlbum.ID,
        replacing: Bool
    ) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else { return }
        if replacing {
            groups[groupIndex].albums = albums
        } else {
            let existingIDs = Set(groups[groupIndex].albums.map(\.id))
            groups[groupIndex].albums.append(contentsOf: albums.filter { !existingIDs.contains($0.id) })
        }
        refreshManagedGroupIfNeeded(id: groupID)
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

    private func removeRemoteGroup(id: ShareAlbum.ID) {
        groups.removeAll { $0.id == id }
        loadedGroupDetailIDs.remove(id)
        loadedSharedAlbumGroupIDs.remove(id)
        sharedAlbumNextCursors.removeValue(forKey: id)
        sharedAlbumHasNextPage.removeValue(forKey: id)
        inviteCodes.removeValue(forKey: id)
        if managedShareGroup?.id == id {
            dismissShareManagement()
        }
    }

    private func apiDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? .now
    }
}

extension ShareGroupRoleResponse {
    fileprivate var model: ShareGroupRole {
        switch self {
        case .host: .admin
        case .member: .participant
        }
    }
}

extension ShareGroupUserResponse {
    fileprivate var model: ShareGroupUser {
        ShareGroupUser(id: userId, displayName: displayName)
    }
}
