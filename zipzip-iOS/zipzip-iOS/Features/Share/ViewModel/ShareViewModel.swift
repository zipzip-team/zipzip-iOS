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

@Observable
@MainActor
final class ShareViewModel {
    private(set) var groups: [ShareAlbum]
    private let repository: ShareGroupRepository

    var isAddMode = false
    var isJoinSheetPresented = false
    var isJoinConfirmationPresented = false
    var isCreateSheetPresented = false
    var isInviteSheetPresented = false
    var isCommentsPresented = false
    var isShareManagementPresented = false
    private(set) var isCreatingGroup = false
    private(set) var isPreviewingJoin = false
    private(set) var isJoiningGroup = false
    private(set) var isUpdatingGroup = false
    private(set) var isLeavingGroup = false
    private(set) var joinErrorCode: String?
    private(set) var groupManagementErrorCode: String?
    private(set) var membersByGroupID: [ShareAlbum.ID: [ShareGroupMember]] = [:]
    private(set) var activeChatGroupID: ShareAlbum.ID?
    private(set) var chatItems: [ShareGroupChatItem] = []
    private(set) var isLoadingChat = false
    private(set) var isSendingChatMessage = false
    private(set) var chatErrorCode: String?
    private(set) var isUpdatingSharedAlbum = false
    private(set) var isDeletingSharedAlbums = false
    private(set) var sharedAlbumErrorCode: String?
    var isErrorAlertPresented = false
    private(set) var errorAlertMessage = ""

    private(set) var hasLoadedGroups = false
    private(set) var isLoadingGroups = false
    private(set) var isLoadingMoreGroups = false

    var joinCode = ""
    var groupNameDraft = ""
    var inviteCode = ""
    var commentDraft = ""
    var shareGroupNameDraft = ""

    private(set) var pendingJoinGroup: ShareAlbum?
    private(set) var managedShareGroup: ShareAlbum?

    private var groupCreationName: String?
    private var groupCreationIdempotencyKey: UUID?
    private var joinRequestInviteCode: String?
    private var joinIdempotencyKey: UUID?
    private var pendingJoinAlreadyJoined = false
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
    private var loadingMemberGroupIDs: Set<ShareAlbum.ID> = []
    private var visibleGroupIDs: [ShareAlbum.ID]?
    private var visibleSharedAlbumIDs: [ShareAlbum.ID: [SharedAlbum.ID]] = [:]
    private var chatMessageContent: String?
    private var chatMessageIdempotencyKey: UUID?
    private var chatSessionID: UUID?
    private var bulkDeleteAlbumIDs: Set<SharedAlbum.ID>?
    private var bulkDeleteIdempotencyKey: UUID?
    private var cacheOwnerID: UUID?

    init(repository: ShareGroupRepository) {
        self.groups = []
        self.repository = repository
    }

    init(groups: [ShareAlbum], repository: ShareGroupRepository) {
        self.groups = groups
        self.repository = repository
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

    func members(for groupID: ShareAlbum.ID) -> [ShareGroupMember] {
        membersByGroupID[groupID] ?? []
    }

    func isInviteCodeAvailable(for groupID: ShareAlbum.ID) -> Bool {
        inviteCodes[groupID] != nil
    }

    func makeSharedAlbumDetailViewModel(
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        onDelete: @escaping () -> Void
    ) -> AlbumDetailViewModel {
        AlbumDetailViewModel(
            actions: AlbumDetailActions(
                onRename: { [weak self] name in
                    Task {
                        await self?.renameSharedAlbum(
                            id: albumID,
                            in: groupID,
                            name: name
                        )
                    }
                },
                onDelete: { [weak self] in
                    Task {
                        guard await self?.deleteSharedAlbum(id: albumID, from: groupID) == true else {
                            return
                        }
                        onDelete()
                    }
                },
                onAddPhotos: { _ in
                    // TODO: 정교은 담당 API가 합쳐지면 upload-urls 요청, object storage PUT,
                    // photos/complete 호출 순서로 업로드한 뒤 공유집 사진 목록을 다시 조회합니다.
                },
                onDeletePhotos: { _, _ in
                    // TODO: 정교은 담당 detach API가 합쳐지면 선택한 server photo id를
                    // POST /api/v1/shared-albums/{sharedAlbumId}/photos/detach로 제거하고 목록을 갱신합니다.
                },
                onMovePhotos: { _, _ in
                    // TODO: 정교은 담당 attach/detach API가 합쳐지면 대상 공유집에 먼저 attach하고,
                    // 이동인 경우 원본 공유집에서 detach한 뒤 양쪽 사진 목록을 갱신합니다.
                }
            )
        )
    }

    func loadGroups(for userID: UUID, refresh: Bool = false) async {
        guard !isLoadingGroups, !isLoadingMoreGroups else { return }
        if cacheOwnerID != userID {
            resetRemoteData()
        }
        guard refresh || !hasLoadedGroups else { return }

        isLoadingGroups = true
        defer { isLoadingGroups = false }

        if cacheOwnerID != userID {
            do {
                try await repository.prepareCache(for: userID)
                cacheOwnerID = userID
            } catch {
                presentError(error, fallback: "공유 데이터를 준비하지 못했어요.")
                return
            }
        }

        if !refresh, !hasLoadedGroups {
            try? await reloadGroups()
        }

        do {
            let page = try await repository.syncGroups(cursor: nil, size: 20)
            visibleGroupIDs = page.itemIDs
            try await reloadGroups()
            nextGroupCursor = page.nextCursor
            groupsHaveNextPage = page.hasNext
            hasLoadedGroups = true
        } catch {
            hasLoadedGroups = true
            presentError(error, fallback: "공유 그룹을 불러오지 못했어요.")
        }
    }

    func loadMoreGroupsIfNeeded(currentGroupID: ShareAlbum.ID) async {
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
            let page = try await repository.syncGroups(cursor: nextGroupCursor, size: 20)
            var groupIDs = visibleGroupIDs ?? groups.map(\.id)
            for id in page.itemIDs where !groupIDs.contains(id) {
                groupIDs.append(id)
            }
            visibleGroupIDs = groupIDs
            try await reloadGroups()
            self.nextGroupCursor = page.nextCursor
            groupsHaveNextPage = page.hasNext
        } catch {
            presentError(error, fallback: "다음 공유 그룹을 불러오지 못했어요.")
        }
    }

    func loadGroup(id: ShareAlbum.ID, refresh: Bool = false) async {
        guard !loadingGroupDetailIDs.contains(id) else { return }
        guard refresh || !loadedGroupDetailIDs.contains(id) else { return }

        loadingGroupDetailIDs.insert(id)
        defer { loadingGroupDetailIDs.remove(id) }

        do {
            try await repository.syncGroup(id: id)
            if var groupIDs = visibleGroupIDs, !groupIDs.contains(id) {
                groupIDs.append(id)
                visibleGroupIDs = groupIDs
            }
            try await reloadGroups()
            loadedGroupDetailIDs.insert(id)
            refreshManagedGroupIfNeeded(id: id)
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: id)
        } catch {
            presentError(error, fallback: "공유 그룹 정보를 불러오지 못했어요.")
        }
    }

    func loadSharedAlbums(
        groupID: ShareAlbum.ID,
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
            let page = try await repository.syncSharedAlbums(
                groupID: groupID,
                cursor: nil,
                size: 20
            )
            visibleSharedAlbumIDs[groupID] = page.itemIDs
            try await reloadGroups()
            updateSharedAlbumPageState(page, groupID: groupID)
            loadedSharedAlbumGroupIDs.insert(groupID)
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: groupID)
        } catch {
            presentError(error, fallback: "공유집 목록을 불러오지 못했어요.")
        }
    }

    func loadMoreSharedAlbumsIfNeeded(
        groupID: ShareAlbum.ID,
        currentAlbumID: SharedAlbum.ID
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
            let page = try await repository.syncSharedAlbums(
                groupID: groupID,
                cursor: cursor,
                size: 20
            )
            var albumIDs = visibleSharedAlbumIDs[groupID] ?? group(withID: groupID)?.albums.map(\.id) ?? []
            for id in page.itemIDs where !albumIDs.contains(id) {
                albumIDs.append(id)
            }
            visibleSharedAlbumIDs[groupID] = albumIDs
            try await reloadGroups()
            updateSharedAlbumPageState(page, groupID: groupID)
        } catch {
            presentError(error, fallback: "다음 공유집을 불러오지 못했어요.")
        }
    }

    func loadInviteCode(groupID: ShareAlbum.ID) async {
        guard inviteCodes[groupID] == nil,
              !loadingInviteCodeGroupIDs.contains(groupID)
        else {
            return
        }

        loadingInviteCodeGroupIDs.insert(groupID)
        defer { loadingInviteCodeGroupIDs.remove(groupID) }

        do {
            inviteCodes[groupID] = try await repository.inviteCode(groupID: groupID)
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: groupID)
        } catch {
            presentError(error, fallback: "초대 코드를 불러오지 못했어요.")
        }
    }

    func loadMembers(groupID: ShareAlbum.ID, refresh: Bool = false) async {
        guard !loadingMemberGroupIDs.contains(groupID) else { return }
        guard refresh || membersByGroupID[groupID] == nil else { return }

        loadingMemberGroupIDs.insert(groupID)
        defer { loadingMemberGroupIDs.remove(groupID) }

        do {
            var members: [ShareGroupMember] = []
            var cursor: String?
            repeat {
                let page = try await repository.members(groupID: groupID, cursor: cursor, size: 100)
                for member in page.items where !members.contains(where: { $0.id == member.id }) {
                    members.append(member)
                }
                cursor = page.hasNext ? page.nextCursor : nil
            } while cursor != nil
            membersByGroupID[groupID] = members
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: groupID)
        } catch {
            presentError(error, fallback: "참여자 정보를 불러오지 못했어요.")
        }
    }

    func presentComments(groupID: ShareAlbum.ID) {
        chatSessionID = UUID()
        activeChatGroupID = groupID
        chatItems = []
        commentDraft = ""
        chatErrorCode = nil
        chatMessageContent = nil
        chatMessageIdempotencyKey = nil
        isLoadingChat = false
        isSendingChatMessage = false
        isCommentsPresented = true
    }

    func dismissComments() {
        isCommentsPresented = false
        activeChatGroupID = nil
        chatItems = []
        commentDraft = ""
        chatErrorCode = nil
        chatMessageContent = nil
        chatMessageIdempotencyKey = nil
        chatSessionID = nil
        isLoadingChat = false
        isSendingChatMessage = false
    }

    func loadChatTimeline(refresh: Bool = false) async {
        guard let activeChatGroupID, let chatSessionID, !isLoadingChat else { return }
        guard refresh || chatItems.isEmpty else { return }

        isLoadingChat = true
        chatErrorCode = nil
        defer {
            if self.chatSessionID == chatSessionID {
                isLoadingChat = false
            }
        }

        do {
            var items: [ShareGroupChatItem] = []
            var cursor: String?
            repeat {
                let page = try await repository.chatTimeline(
                    groupID: activeChatGroupID,
                    cursor: cursor,
                    size: 100
                )
                for item in page.items where !items.contains(where: { $0.id == item.id }) {
                    items.append(item)
                }
                cursor = page.hasNext ? page.nextCursor : nil
            } while cursor != nil
            guard self.chatSessionID == chatSessionID else {
                return
            }
            chatItems = Array(items.reversed())
        } catch ShareGroupRepositoryError.groupNotFound {
            guard self.chatSessionID == chatSessionID else { return }
            await removeMissingGroup(id: activeChatGroupID)
            dismissComments()
        } catch let error as NetworkError {
            guard self.chatSessionID == chatSessionID else { return }
            chatErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "대화를 불러오지 못했어요.")
        } catch {
            guard self.chatSessionID == chatSessionID else { return }
            chatErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "대화를 불러오지 못했어요.")
        }
    }

    func sendChatMessage() async {
        guard let activeChatGroupID,
              let chatSessionID,
              !isSendingChatMessage,
              !isLoadingChat
        else {
            return
        }
        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let idempotencyKey: UUID
        if chatMessageContent == content, let chatMessageIdempotencyKey {
            idempotencyKey = chatMessageIdempotencyKey
        } else {
            idempotencyKey = UUID()
            chatMessageContent = content
            chatMessageIdempotencyKey = idempotencyKey
        }

        isSendingChatMessage = true
        chatErrorCode = nil
        defer {
            if self.chatSessionID == chatSessionID {
                isSendingChatMessage = false
            }
        }

        do {
            try await repository.createChatMessage(
                groupID: activeChatGroupID,
                content: content,
                idempotencyKey: idempotencyKey
            )
            guard self.chatSessionID == chatSessionID else { return }
            commentDraft = ""
            chatMessageContent = nil
            chatMessageIdempotencyKey = nil
            await loadChatTimeline(refresh: true)
        } catch ShareGroupRepositoryError.groupNotFound {
            guard self.chatSessionID == chatSessionID else { return }
            await removeMissingGroup(id: activeChatGroupID)
            dismissComments()
        } catch let error as NetworkError {
            guard self.chatSessionID == chatSessionID else { return }
            chatErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "메시지를 보내지 못했어요.")
        } catch {
            guard self.chatSessionID == chatSessionID else { return }
            chatErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "메시지를 보내지 못했어요.")
        }
    }

    func resetRemoteData() {
        groups = []
        cacheOwnerID = nil
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
        membersByGroupID = [:]
        loadingMemberGroupIDs = []
        visibleGroupIDs = nil
        visibleSharedAlbumIDs = [:]
        inviteCode = ""
        dismissComments()
        resetJoinState()
        dismissErrorAlert()
    }

    func enterAddMode() {
        isAddMode = true
    }

    func exitAddMode() {
        isAddMode = false
    }

    func presentJoinSheet() {
        resetJoinState()
        joinCode = ""
        isJoinSheetPresented = true
    }

    func confirmJoinCode() async {
        let trimmedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, !isPreviewingJoin else { return }

        isPreviewingJoin = true
        joinErrorCode = nil
        defer { isPreviewingJoin = false }

        do {
            let preview = try await repository.previewJoin(inviteCode: trimmedCode)
            joinCode = trimmedCode
            joinRequestInviteCode = trimmedCode
            joinIdempotencyKey = preview.alreadyJoined ? nil : UUID()
            pendingJoinGroup = preview.group
            pendingJoinAlreadyJoined = preview.alreadyJoined
            isJoinSheetPresented = false
            isJoinConfirmationPresented = true
        } catch let error as ShareGroupRepositoryError {
            joinErrorCode = String(describing: error)
            presentError(error, fallback: "공유 그룹 입장 정보를 확인하지 못했어요.")
        } catch let error as NetworkError {
            joinErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유 그룹 입장 정보를 확인하지 못했어요.")
        } catch {
            joinErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유 그룹 입장 정보를 확인하지 못했어요.")
        }
    }

    func cancelJoinConfirmation() {
        isJoinConfirmationPresented = false
        pendingJoinGroup = nil
        pendingJoinAlreadyJoined = false
        joinRequestInviteCode = nil
        joinIdempotencyKey = nil
    }

    func completeJoin() async -> ShareAlbum.ID? {
        guard let pendingJoinGroup,
              let joinRequestInviteCode,
              !isJoiningGroup
        else {
            return nil
        }

        if pendingJoinAlreadyJoined {
            await prepareJoinedGroup(id: pendingJoinGroup.id)
            finishJoin()
            return pendingJoinGroup.id
        }

        let idempotencyKey = joinIdempotencyKey ?? UUID()
        joinIdempotencyKey = idempotencyKey
        isJoiningGroup = true
        joinErrorCode = nil
        defer { isJoiningGroup = false }

        do {
            let groupID = try await repository.join(
                inviteCode: joinRequestInviteCode,
                idempotencyKey: idempotencyKey
            )
            await prepareJoinedGroup(id: groupID)
            finishJoin()
            return groupID
        } catch ShareGroupRepositoryError.alreadyJoined {
            await prepareJoinedGroup(id: pendingJoinGroup.id)
            finishJoin()
            return pendingJoinGroup.id
        } catch let error as ShareGroupRepositoryError {
            joinErrorCode = String(describing: error)
            presentError(error, fallback: "공유 그룹에 입장하지 못했어요.")
            return nil
        } catch let error as NetworkError {
            joinErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유 그룹에 입장하지 못했어요.")
            return nil
        } catch {
            joinErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유 그룹에 입장하지 못했어요.")
            return nil
        }
    }

    func presentCreateSheet() {
        groupNameDraft = ""
        groupCreationName = nil
        groupCreationIdempotencyKey = nil
        isCreateSheetPresented = true
    }

    func createGroup() async {
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
            let createdGroup = try await repository.createGroup(
                name: trimmedName,
                idempotencyKey: idempotencyKey
            )
            if var groupIDs = visibleGroupIDs {
                groupIDs.removeAll { $0 == createdGroup.id }
                groupIDs.insert(createdGroup.id, at: 0)
                visibleGroupIDs = groupIDs
            }
            try await reloadGroups()
            hasLoadedGroups = true
            inviteCode = createdGroup.inviteCode
            inviteCodes[createdGroup.id] = inviteCode
            groupCreationName = nil
            groupCreationIdempotencyKey = nil
            isCreateSheetPresented = false
            isInviteSheetPresented = true
        } catch {
            presentError(error, fallback: "공유 그룹을 만들지 못했어요.")
        }
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

    @discardableResult
    func renameSharedAlbum(
        id albumID: SharedAlbum.ID,
        in groupID: ShareAlbum.ID,
        name draftName: String
    ) async -> Bool {
        guard let album = album(groupID: groupID, albumID: albumID),
              !isUpdatingSharedAlbum
        else {
            return false
        }

        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        guard name != album.name else { return true }

        isUpdatingSharedAlbum = true
        sharedAlbumErrorCode = nil
        defer { isUpdatingSharedAlbum = false }

        do {
            try await repository.renameSharedAlbum(id: albumID, groupID: groupID, name: name)
            try await reloadGroups()
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: groupID)
            return false
        } catch ShareGroupRepositoryError.sharedAlbumNotFound {
            removeSharedAlbumState(id: albumID, groupID: groupID)
            try? await reloadGroups()
            return false
        } catch let error as ShareGroupRepositoryError {
            sharedAlbumErrorCode = String(describing: error)
            presentError(error, fallback: "공유집 이름을 변경하지 못했어요.")
            return false
        } catch let error as NetworkError {
            sharedAlbumErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유집 이름을 변경하지 못했어요.")
            return false
        } catch {
            sharedAlbumErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유집 이름을 변경하지 못했어요.")
            return false
        }
    }

    @discardableResult
    func deleteSharedAlbum(
        id albumID: SharedAlbum.ID,
        from groupID: ShareAlbum.ID
    ) async -> Bool {
        guard album(groupID: groupID, albumID: albumID) != nil,
              !isDeletingSharedAlbums
        else {
            return false
        }

        isDeletingSharedAlbums = true
        sharedAlbumErrorCode = nil
        defer { isDeletingSharedAlbums = false }

        do {
            try await repository.deleteSharedAlbum(id: albumID, groupID: groupID)
            removeSharedAlbumState(id: albumID, groupID: groupID)
            await refreshGroupAfterAlbumMutation(groupID: groupID)
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: groupID)
            return true
        } catch let error as ShareGroupRepositoryError {
            sharedAlbumErrorCode = String(describing: error)
            presentError(error, fallback: "공유집을 삭제하지 못했어요.")
            return false
        } catch let error as NetworkError {
            sharedAlbumErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유집을 삭제하지 못했어요.")
            return false
        } catch {
            sharedAlbumErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유집을 삭제하지 못했어요.")
            return false
        }
    }

    @discardableResult
    func deleteSharedAlbums(
        _ albumIDs: Set<SharedAlbum.ID>,
        from groupID: ShareAlbum.ID
    ) async -> Bool {
        guard !albumIDs.isEmpty, !isDeletingSharedAlbums else { return false }

        let idempotencyKey: UUID
        if bulkDeleteAlbumIDs == albumIDs, let bulkDeleteIdempotencyKey {
            idempotencyKey = bulkDeleteIdempotencyKey
        } else {
            idempotencyKey = UUID()
            bulkDeleteAlbumIDs = albumIDs
            bulkDeleteIdempotencyKey = idempotencyKey
        }

        isDeletingSharedAlbums = true
        sharedAlbumErrorCode = nil
        defer { isDeletingSharedAlbums = false }

        do {
            _ = try await repository.deleteSharedAlbums(
                ids: Array(albumIDs),
                groupID: groupID,
                idempotencyKey: idempotencyKey
            )
            for albumID in albumIDs {
                removeSharedAlbumState(id: albumID, groupID: groupID)
            }
            bulkDeleteAlbumIDs = nil
            bulkDeleteIdempotencyKey = nil
            await refreshGroupAfterAlbumMutation(groupID: groupID)
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            bulkDeleteAlbumIDs = nil
            bulkDeleteIdempotencyKey = nil
            await removeMissingGroup(id: groupID)
            return true
        } catch ShareGroupRepositoryError.sharedAlbumNotFound {
            try? await reloadGroups()
            sharedAlbumErrorCode = String(describing: ShareGroupRepositoryError.sharedAlbumNotFound)
            presentError(
                ShareGroupRepositoryError.sharedAlbumNotFound,
                fallback: "선택한 공유집을 삭제하지 못했어요."
            )
            return false
        } catch let error as ShareGroupRepositoryError {
            sharedAlbumErrorCode = String(describing: error)
            presentError(error, fallback: "선택한 공유집을 삭제하지 못했어요.")
            return false
        } catch let error as NetworkError {
            sharedAlbumErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "선택한 공유집을 삭제하지 못했어요.")
            return false
        } catch {
            sharedAlbumErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "선택한 공유집을 삭제하지 못했어요.")
            return false
        }
    }

    func presentShareManagement(groupID: ShareAlbum.ID) {
        guard let group = group(withID: groupID) else { return }
        shareGroupNameDraft = group.name
        managedShareGroup = group
        groupManagementErrorCode = nil
        isShareManagementPresented = true
    }

    func completeShareManagement() async {
        guard let group = managedShareGroup, !isUpdatingGroup else { return }
        guard group.currentUserRole == .admin else {
            dismissShareManagement()
            return
        }

        let trimmedName = shareGroupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard trimmedName != group.name else {
            dismissShareManagement()
            return
        }

        groupManagementErrorCode = nil
        isUpdatingGroup = true
        defer { isUpdatingGroup = false }
        do {
            try await repository.updateGroupName(id: group.id, name: trimmedName)
            try await reloadGroups()
            dismissShareManagement()
        } catch let error as ShareGroupRepositoryError {
            groupManagementErrorCode = String(describing: error)
            presentError(error, fallback: "공유 그룹 이름을 변경하지 못했어요.")
        } catch let error as NetworkError {
            groupManagementErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유 그룹 이름을 변경하지 못했어요.")
        } catch {
            groupManagementErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유 그룹 이름을 변경하지 못했어요.")
        }
    }

    @discardableResult
    func leaveManagedShareGroup() async -> Bool {
        guard let group = managedShareGroup, !isLeavingGroup else { return false }

        groupManagementErrorCode = nil
        isLeavingGroup = true
        defer { isLeavingGroup = false }
        do {
            switch group.currentUserRole {
            case .admin:
                try await repository.deleteRemoteGroup(id: group.id)
            case .participant:
                try await repository.leaveGroup(id: group.id)
            }
            removeGroupState(id: group.id)
            do {
                try await reloadGroups()
            } catch {
                presentError(error, fallback: "그룹 정리는 완료됐지만 목록을 갱신하지 못했어요.")
            }
            dismissShareManagement()
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: group.id)
            dismissShareManagement()
            return true
        } catch let error as ShareGroupRepositoryError {
            groupManagementErrorCode = String(describing: error)
            presentError(error, fallback: "공유 그룹에서 나가지 못했어요.")
            return false
        } catch let error as NetworkError {
            groupManagementErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유 그룹에서 나가지 못했어요.")
            return false
        } catch {
            groupManagementErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유 그룹에서 나가지 못했어요.")
            return false
        }
    }

    func dismissShareManagement() {
        isShareManagementPresented = false
        managedShareGroup = nil
        groupManagementErrorCode = nil
        isUpdatingGroup = false
        isLeavingGroup = false
    }

    func dismissErrorAlert() {
        isErrorAlertPresented = false
    }

    func resetTransientUI() {
        isAddMode = false
        isJoinSheetPresented = false
        isJoinConfirmationPresented = false
        isCreateSheetPresented = false
        isInviteSheetPresented = false
        dismissComments()
        isShareManagementPresented = false
        pendingJoinGroup = nil
        managedShareGroup = nil
        resetJoinState()
        sharedAlbumErrorCode = nil
    }

    private func reloadGroups() async throws {
        let storedGroups = try await repository.groups()
        let storedByID = Dictionary(uniqueKeysWithValues: storedGroups.map { ($0.id, $0) })
        let orderedGroups: [ShareAlbum]
        if let visibleGroupIDs {
            orderedGroups = visibleGroupIDs.compactMap { storedByID[$0] }
        } else {
            orderedGroups = storedGroups
        }

        groups = orderedGroups.map { storedGroup in
            var group = storedGroup
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
        _ page: ShareGroupRepositoryPage,
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

    private func removeMissingGroup(id: ShareAlbum.ID) async {
        try? await repository.removeCachedGroup(id: id)
        removeGroupState(id: id)
        try? await reloadGroups()
        if managedShareGroup?.id == id {
            dismissShareManagement()
        }
    }

    private func removeGroupState(id: ShareAlbum.ID) {
        visibleGroupIDs?.removeAll { $0 == id }
        visibleSharedAlbumIDs.removeValue(forKey: id)
        loadedGroupDetailIDs.remove(id)
        loadedSharedAlbumGroupIDs.remove(id)
        sharedAlbumNextCursors.removeValue(forKey: id)
        sharedAlbumHasNextPage.removeValue(forKey: id)
        inviteCodes.removeValue(forKey: id)
        membersByGroupID.removeValue(forKey: id)
        if activeChatGroupID == id {
            dismissComments()
        }
    }

    private func removeSharedAlbumState(id: SharedAlbum.ID, groupID: ShareAlbum.ID) {
        visibleSharedAlbumIDs[groupID]?.removeAll { $0 == id }
    }

    private func refreshGroupAfterAlbumMutation(groupID: ShareAlbum.ID) async {
        do {
            try await repository.syncGroup(id: groupID)
            try await reloadGroups()
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: groupID)
        } catch {
            presentError(error, fallback: "삭제는 완료됐지만 최신 정보를 불러오지 못했어요.")
        }
    }

    private func prepareJoinedGroup(id: ShareAlbum.ID) async {
        if var groupIDs = visibleGroupIDs {
            groupIDs.removeAll { $0 == id }
            groupIDs.insert(id, at: 0)
            visibleGroupIDs = groupIDs
        } else {
            visibleGroupIDs = [id] + groups.map(\.id).filter { $0 != id }
        }

        try? await repository.syncGroup(id: id)
        try? await reloadGroups()
        hasLoadedGroups = true
        loadedGroupDetailIDs.insert(id)
    }

    private func finishJoin() {
        isJoinSheetPresented = false
        isJoinConfirmationPresented = false
        isAddMode = false
        pendingJoinGroup = nil
        pendingJoinAlreadyJoined = false
        joinRequestInviteCode = nil
        joinIdempotencyKey = nil
        joinErrorCode = nil
    }

    private func resetJoinState() {
        isPreviewingJoin = false
        isJoiningGroup = false
        joinErrorCode = nil
        joinRequestInviteCode = nil
        joinIdempotencyKey = nil
        pendingJoinAlreadyJoined = false
        pendingJoinGroup = nil
        isJoinConfirmationPresented = false
    }

    private func presentError(_ error: Error, fallback: String) {
        errorAlertMessage = userFacingMessage(for: error, fallback: fallback)
        isErrorAlertPresented = true
    }

    private func userFacingMessage(for error: Error, fallback: String) -> String {
        if let repositoryError = error as? ShareGroupRepositoryError {
            return switch repositoryError {
            case .groupNotFound:
                "공유 그룹을 찾을 수 없어요."
            case .invalidInviteCode:
                "초대 코드를 다시 확인해 주세요."
            case .alreadyJoined:
                "이미 참여 중인 공유 그룹이에요."
            case .hostRequired:
                "방장만 변경할 수 있어요."
            case .memberRequired:
                "참여자만 이 작업을 할 수 있어요."
            case .sharedAlbumNotFound:
                "공유집을 찾을 수 없어요."
            case .invalidSharedAlbumSelection:
                "삭제할 공유집을 다시 선택해 주세요."
            }
        }

        if let networkError = error as? NetworkError {
            return networkError.errorDescription ?? fallback
        }

        if error is URLError {
            return "네트워크 연결을 확인한 후 다시 시도해 주세요."
        }

        return fallback
    }
}
