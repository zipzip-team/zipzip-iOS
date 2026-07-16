//
//  ShareViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation
import OSLog
import SwiftUI

enum ShareImportSelection: Hashable {
    case photos
    case albums
}

enum ShareSheetPresentation: Equatable {
    case joinEntry
    case joinConfirmation
    case createGroup
    case createSharedAlbum
    case invitation
    case comments
    case management
}

struct ShareImportOutcome: Equatable {
    let createdAlbumCount: Int
    let failedAlbumCount: Int
    let uploadedPhotoCount: Int
    let failedPhotoCount: Int

    var completedAnyWork: Bool {
        createdAlbumCount > 0 || uploadedPhotoCount > 0
    }

    var hasFailures: Bool {
        failedAlbumCount > 0 || failedPhotoCount > 0
    }
}

@Observable
@MainActor
final class ShareViewModel {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "Share"
    )

    private(set) var groups: [ShareAlbum]
    private let repository: ShareGroupRepository
    private let sharedPhotoRepository: (any SharedPhotoRepository)?

    var isAddMode = false
    private(set) var presentedSheet: ShareSheetPresentation?
    private var dismissingSheet: ShareSheetPresentation?
    private var pendingSheet: ShareSheetPresentation?
    private(set) var isCreatingGroup = false
    private(set) var isCreatingSharedAlbum = false
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
    private(set) var isLoadingOlderChat = false
    private(set) var isSendingChatMessage = false
    private(set) var chatErrorCode: String?
    private(set) var isUpdatingSharedAlbum = false
    private(set) var isDeletingSharedAlbums = false
    private(set) var sharedAlbumErrorCode: String?

    private(set) var hasLoadedGroups = false
    private(set) var isLoadingGroups = false
    private(set) var isLoadingMoreGroups = false

    var joinCode = ""
    var groupNameDraft = ""
    var sharedAlbumNameDraft = ""
    var inviteCode = ""
    var commentDraft = ""
    var shareGroupNameDraft = ""

    private(set) var pendingJoinPreview: ShareGroupJoinPreview?
    private(set) var completedJoinNavigationGroupID: ShareAlbum.ID?
    private(set) var managedShareGroup: ShareAlbum?

    var pendingJoinGroup: ShareAlbum? {
        pendingJoinPreview?.group
    }

    private var groupCreationName: String?
    private var groupCreationIdempotencyKey: UUID?
    private var sharedAlbumCreationGroupID: ShareAlbum.ID?
    private var sharedAlbumCreationName: String?
    private var sharedAlbumCreationIdempotencyKey: UUID?
    private var joinRequestInviteCode: String?
    private var joinIdempotencyKey: UUID?
    private var joinedGroupIDAwaitingSync: ShareAlbum.ID?
    private var pendingJoinAlreadyJoined = false
    private var nextGroupCursor: String?
    private var groupsHaveNextPage = false
    private var requestedGroupCursors: Set<String> = []
    private var loadedGroupDetailIDs: Set<ShareAlbum.ID> = []
    private var loadingGroupDetailIDs: Set<ShareAlbum.ID> = []
    private var loadedSharedAlbumGroupIDs: Set<ShareAlbum.ID> = []
    private var loadingSharedAlbumGroupIDs: Set<ShareAlbum.ID> = []
    private var loadingMoreSharedAlbumGroupIDs: Set<ShareAlbum.ID> = []
    private var sharedAlbumNextCursors: [ShareAlbum.ID: String] = [:]
    private var sharedAlbumHasNextPage: [ShareAlbum.ID: Bool] = [:]
    private var requestedSharedAlbumCursors: [ShareAlbum.ID: Set<String>] = [:]
    private var inviteCodes: [ShareAlbum.ID: String] = [:]
    private var loadingInviteCodeGroupIDs: Set<ShareAlbum.ID> = []
    private var loadingMemberGroupIDs: Set<ShareAlbum.ID> = []
    private var visibleGroupIDs: [ShareAlbum.ID]?
    private var visibleSharedAlbumIDs: [ShareAlbum.ID: [SharedAlbum.ID]] = [:]
    private var chatMessageContent: String?
    private var chatMessageIdempotencyKey: UUID?
    private var chatSessionID: UUID?
    private var chatNextCursor: String?
    private var chatHasNextPage = false
    private var requestedChatCursors: Set<String> = []
    private var bulkDeleteAlbumIDs: Set<SharedAlbum.ID>?
    private var bulkDeleteIdempotencyKey: UUID?
    private var personalAlbumImportIdempotencyKeys: [String: UUID] = [:]
    private var personalAlbumImportCreatedAlbums: [String: SharedAlbum] = [:]
    private var cacheOwnerID: UUID?
    private var remoteDataSessionID = UUID()

    var displayedSheet: ShareSheetPresentation? {
        presentedSheet ?? dismissingSheet
    }

    var isPresentedSheetBusy: Bool {
        switch displayedSheet {
        case .joinEntry:
            isPreviewingJoin
        case .joinConfirmation:
            isJoiningGroup
        case .createGroup:
            isCreatingGroup
        case .createSharedAlbum:
            isCreatingSharedAlbum
        case .comments:
            isSendingChatMessage
        case .management:
            isUpdatingGroup || isLeavingGroup
        case .invitation, nil:
            false
        }
    }

    var isJoinSheetPresented: Bool {
        presentedSheet == .joinEntry
    }

    var isJoinConfirmationPresented: Bool {
        presentedSheet == .joinConfirmation
    }

    var isCreateSheetPresented: Bool {
        presentedSheet == .createGroup
    }

    var isCreateSharedAlbumSheetPresented: Bool {
        presentedSheet == .createSharedAlbum
    }

    var isCreateSharedAlbumDisabled: Bool {
        let name = sharedAlbumNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name.count > 100 || isCreatingSharedAlbum
    }

    var isInviteSheetPresented: Bool {
        presentedSheet == .invitation
    }

    var isCommentsPresented: Bool {
        presentedSheet == .comments
    }

    var isShareManagementPresented: Bool {
        presentedSheet == .management
    }

    init(
        repository: ShareGroupRepository,
        sharedPhotoRepository: (any SharedPhotoRepository)? = nil
    ) {
        self.groups = []
        self.repository = repository
        self.sharedPhotoRepository = sharedPhotoRepository
    }

    init(
        groups: [ShareAlbum],
        repository: ShareGroupRepository,
        sharedPhotoRepository: (any SharedPhotoRepository)? = nil
    ) {
        self.groups = groups
        self.repository = repository
        self.sharedPhotoRepository = sharedPhotoRepository
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
    ) -> SharedAlbumDetailViewModel {
        let adapter = SharedAlbumDetailRepositoryAdapter(
            onCachedPhotos: { [weak self] albumID in
                guard let repository = self?.sharedPhotoRepository else {
                    throw SharedPhotoRepositoryError.cacheNotPrepared
                }
                return try await repository.cachedPhotos(in: albumID)
            },
            onSynchronizePhotos: { [weak self] albumID in
                guard let repository = self?.sharedPhotoRepository else {
                    throw SharedPhotoRepositoryError.cacheNotPrepared
                }
                return try await repository.synchronizePhotos(in: albumID)
            },
            onRenameAlbum: { [weak self] groupID, albumID, name in
                guard let self else { return false }
                return await self.renameSharedAlbum(id: albumID, in: groupID, name: name)
            },
            onDeleteAlbum: { [weak self] groupID, albumID in
                guard let self else { return false }
                return await self.deleteSharedAlbum(id: albumID, from: groupID)
            },
            onUploadPhotos: { [weak self] localIdentifiers, albumID in
                guard let self, let repository = self.sharedPhotoRepository else {
                    throw SharedPhotoRepositoryError.cacheNotPrepared
                }
                let result = try await repository.addLocalPhotos(
                    localIdentifiers: localIdentifiers,
                    to: [albumID],
                    in: groupID
                )
                await self.refreshSharedAlbumsAfterPhotoMutation(groupID: groupID)
                return result
            },
            onSavePhotosToLibrary: { [weak self] photoIDs, albumID in
                guard let repository = self?.sharedPhotoRepository else {
                    throw SharedPhotoRepositoryError.cacheNotPrepared
                }
                return try await repository.savePhotosToLibrary(photoIDs: photoIDs, in: albumID)
            },
            onCopyPhotos: { [weak self] photoIDs, sourceAlbumID, destinationAlbumIDs in
                guard let self, let repository = self.sharedPhotoRepository else {
                    throw SharedPhotoRepositoryError.cacheNotPrepared
                }
                let result = try await repository.copyPhotos(
                    photoIDs: photoIDs,
                    from: sourceAlbumID,
                    to: destinationAlbumIDs
                )
                await self.refreshSharedAlbumsAfterPhotoMutation(groupID: groupID)
                return result
            },
            onDeleteLocalCopies: { [weak self] photoIDs in
                guard let repository = self?.sharedPhotoRepository else {
                    throw SharedPhotoRepositoryError.cacheNotPrepared
                }
                return try await repository.deleteLocalCopies(photoIDs: photoIDs)
            },
            onDetachPhotos: { [weak self] photoIDs, albumID in
                guard let self, let repository = self.sharedPhotoRepository else {
                    throw SharedPhotoRepositoryError.cacheNotPrepared
                }
                let result = try await repository.detachPhotos(photoIDs: photoIDs, from: albumID)
                await self.refreshSharedAlbumsAfterPhotoMutation(groupID: groupID)
                return result
            }
        )
        return SharedAlbumDetailViewModel(
            groupID: groupID,
            albumID: albumID,
            repository: adapter,
            onAlbumDeleted: onDelete
        )
    }

    func loadGroups(for userID: UUID, refresh: Bool = false) async {
        if cacheOwnerID != userID {
            resetRemoteData()
        }
        guard !isLoadingGroups, !isLoadingMoreGroups else { return }
        guard refresh || !hasLoadedGroups else { return }

        let sessionID = remoteDataSessionID
        isLoadingGroups = true
        defer {
            if remoteDataSessionID == sessionID {
                isLoadingGroups = false
            }
        }

        if cacheOwnerID != userID {
            do {
                try await repository.prepareCache(for: userID)
                try await sharedPhotoRepository?.prepareCache(for: userID)
                guard remoteDataSessionID == sessionID else { return }
                cacheOwnerID = userID
            } catch {
                guard remoteDataSessionID == sessionID else { return }
                presentError(error, fallback: "공유 데이터를 준비하지 못했어요.")
                return
            }
        }

        if !refresh, !hasLoadedGroups {
            try? await reloadGroups()
        }

        do {
            requestedGroupCursors = []
            let page = try await repository.syncGroups(cursor: nil, size: 20)
            guard remoteDataSessionID == sessionID else { return }
            visibleGroupIDs = page.itemIDs
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return }
            updateGroupPageState(page)
            hasLoadedGroups = true
        } catch {
            guard remoteDataSessionID == sessionID else { return }
            guard !(error is CancellationError) else { return }
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

        let sessionID = remoteDataSessionID
        guard requestedGroupCursors.insert(nextGroupCursor).inserted else {
            self.nextGroupCursor = nil
            groupsHaveNextPage = false
            return
        }
        isLoadingMoreGroups = true
        defer {
            if remoteDataSessionID == sessionID {
                isLoadingMoreGroups = false
            }
        }

        do {
            let page = try await repository.syncGroups(cursor: nextGroupCursor, size: 20)
            guard remoteDataSessionID == sessionID else { return }
            var groupIDs = visibleGroupIDs ?? groups.map(\.id)
            for id in page.itemIDs where !groupIDs.contains(id) {
                groupIDs.append(id)
            }
            visibleGroupIDs = groupIDs
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return }
            updateGroupPageState(page)
        } catch {
            guard remoteDataSessionID == sessionID else { return }
            requestedGroupCursors.remove(nextGroupCursor)
            presentError(error, fallback: "다음 공유 그룹을 불러오지 못했어요.")
        }
    }

    func loadGroup(id: ShareAlbum.ID, refresh: Bool = false) async {
        guard !loadingGroupDetailIDs.contains(id) else { return }
        guard refresh || !loadedGroupDetailIDs.contains(id) else { return }

        let sessionID = remoteDataSessionID
        loadingGroupDetailIDs.insert(id)
        defer {
            if remoteDataSessionID == sessionID {
                loadingGroupDetailIDs.remove(id)
            }
        }

        do {
            try await repository.syncGroup(id: id)
            guard remoteDataSessionID == sessionID else { return }
            if var groupIDs = visibleGroupIDs, !groupIDs.contains(id) {
                groupIDs.append(id)
                visibleGroupIDs = groupIDs
            }
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return }
            loadedGroupDetailIDs.insert(id)
            refreshManagedGroupIfNeeded(id: id)
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return }
            await removeMissingGroup(id: id)
        } catch {
            guard remoteDataSessionID == sessionID else { return }
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

        let sessionID = remoteDataSessionID
        loadingSharedAlbumGroupIDs.insert(groupID)
        defer {
            if remoteDataSessionID == sessionID {
                loadingSharedAlbumGroupIDs.remove(groupID)
            }
        }

        do {
            requestedSharedAlbumCursors[groupID] = []
            let page = try await repository.syncSharedAlbums(
                groupID: groupID,
                cursor: nil,
                size: 20
            )
            guard remoteDataSessionID == sessionID else { return }
            visibleSharedAlbumIDs[groupID] = page.itemIDs
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return }
            updateSharedAlbumPageState(page, groupID: groupID)
            loadedSharedAlbumGroupIDs.insert(groupID)
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return }
            await removeMissingGroup(id: groupID)
        } catch {
            guard remoteDataSessionID == sessionID else { return }
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

        let sessionID = remoteDataSessionID
        guard requestedSharedAlbumCursors[groupID, default: []].insert(cursor).inserted else {
            sharedAlbumNextCursors.removeValue(forKey: groupID)
            sharedAlbumHasNextPage[groupID] = false
            return
        }
        loadingMoreSharedAlbumGroupIDs.insert(groupID)
        defer {
            if remoteDataSessionID == sessionID {
                loadingMoreSharedAlbumGroupIDs.remove(groupID)
            }
        }

        do {
            let page = try await repository.syncSharedAlbums(
                groupID: groupID,
                cursor: cursor,
                size: 20
            )
            guard remoteDataSessionID == sessionID else { return }
            var albumIDs = visibleSharedAlbumIDs[groupID] ?? group(withID: groupID)?.albums.map(\.id) ?? []
            for id in page.itemIDs where !albumIDs.contains(id) {
                albumIDs.append(id)
            }
            visibleSharedAlbumIDs[groupID] = albumIDs
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return }
            updateSharedAlbumPageState(page, groupID: groupID)
        } catch {
            guard remoteDataSessionID == sessionID else { return }
            requestedSharedAlbumCursors[groupID]?.remove(cursor)
            presentError(error, fallback: "다음 공유집을 불러오지 못했어요.")
        }
    }

    func loadInviteCode(groupID: ShareAlbum.ID) async {
        guard inviteCodes[groupID] == nil,
              !loadingInviteCodeGroupIDs.contains(groupID)
        else {
            return
        }

        let sessionID = remoteDataSessionID
        loadingInviteCodeGroupIDs.insert(groupID)
        defer {
            if remoteDataSessionID == sessionID {
                loadingInviteCodeGroupIDs.remove(groupID)
            }
        }

        do {
            let inviteCode = try await repository.inviteCode(groupID: groupID)
            guard remoteDataSessionID == sessionID else { return }
            inviteCodes[groupID] = inviteCode
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return }
            await removeMissingGroup(id: groupID)
        } catch {
            guard remoteDataSessionID == sessionID else { return }
            presentError(error, fallback: "초대 코드를 불러오지 못했어요.")
        }
    }

    func loadMembers(groupID: ShareAlbum.ID, refresh: Bool = false) async {
        guard !loadingMemberGroupIDs.contains(groupID) else { return }
        guard refresh || membersByGroupID[groupID] == nil else { return }

        let sessionID = remoteDataSessionID
        loadingMemberGroupIDs.insert(groupID)
        defer {
            if remoteDataSessionID == sessionID {
                loadingMemberGroupIDs.remove(groupID)
            }
        }

        do {
            var members: [ShareGroupMember] = []
            var cursor: String?
            var requestedCursors: Set<String> = []
            repeat {
                if let cursor, !requestedCursors.insert(cursor).inserted {
                    break
                }
                let page = try await repository.members(groupID: groupID, cursor: cursor, size: 100)
                guard remoteDataSessionID == sessionID else { return }
                for member in page.items where !members.contains(where: { $0.id == member.id }) {
                    members.append(member)
                }
                cursor = page.hasNext && page.nextCursor != cursor ? page.nextCursor : nil
            } while cursor != nil
            membersByGroupID[groupID] = members
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return }
            await removeMissingGroup(id: groupID)
        } catch {
            guard remoteDataSessionID == sessionID else { return }
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
        chatNextCursor = nil
        chatHasNextPage = false
        requestedChatCursors = []
        isLoadingChat = false
        isLoadingOlderChat = false
        isSendingChatMessage = false
        presentSheet(.comments)
    }

    func dismissComments() {
        guard !isSendingChatMessage else { return }
        dismissSheet(if: .comments)
    }

    private func clearCommentsState() {
        activeChatGroupID = nil
        chatItems = []
        commentDraft = ""
        chatErrorCode = nil
        chatMessageContent = nil
        chatMessageIdempotencyKey = nil
        chatSessionID = nil
        chatNextCursor = nil
        chatHasNextPage = false
        requestedChatCursors = []
        isLoadingChat = false
        isLoadingOlderChat = false
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
            let page = try await repository.chatTimeline(
                groupID: activeChatGroupID,
                cursor: nil,
                size: 100
            )
            guard self.chatSessionID == chatSessionID else {
                return
            }
            chatItems = deduplicatedChatItems(page.items.reversed())
            requestedChatCursors = []
            updateChatPageState(page)
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

    func loadOlderChat() async {
        guard let activeChatGroupID,
              let chatSessionID,
              let cursor = chatNextCursor,
              chatHasNextPage,
              !isLoadingChat,
              !isLoadingOlderChat,
              requestedChatCursors.insert(cursor).inserted
        else {
            return
        }

        isLoadingOlderChat = true
        chatErrorCode = nil
        defer {
            if self.chatSessionID == chatSessionID {
                isLoadingOlderChat = false
            }
        }

        do {
            let page = try await repository.chatTimeline(
                groupID: activeChatGroupID,
                cursor: cursor,
                size: 100
            )
            guard self.chatSessionID == chatSessionID else { return }
            chatItems = deduplicatedChatItems(Array(page.items.reversed()) + chatItems)
            updateChatPageState(page)
        } catch ShareGroupRepositoryError.groupNotFound {
            guard self.chatSessionID == chatSessionID else { return }
            await removeMissingGroup(id: activeChatGroupID)
            dismissComments()
        } catch let error as NetworkError {
            guard self.chatSessionID == chatSessionID else { return }
            requestedChatCursors.remove(cursor)
            chatErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "이전 대화를 불러오지 못했어요.")
        } catch {
            guard self.chatSessionID == chatSessionID else { return }
            requestedChatCursors.remove(cursor)
            chatErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "이전 대화를 불러오지 못했어요.")
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
            let sentItem = try await repository.createChatMessage(
                groupID: activeChatGroupID,
                content: content,
                idempotencyKey: idempotencyKey
            )
            guard self.chatSessionID == chatSessionID else { return }
            chatItems = deduplicatedChatItems(chatItems + [sentItem])
            commentDraft = ""
            chatMessageContent = nil
            chatMessageIdempotencyKey = nil
        } catch ShareGroupRepositoryError.groupNotFound {
            guard self.chatSessionID == chatSessionID else { return }
            isSendingChatMessage = false
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

    private func updateChatPageState(_ page: ShareGroupChatPage) {
        guard page.hasNext,
              let nextCursor = page.nextCursor,
              !requestedChatCursors.contains(nextCursor)
        else {
            chatNextCursor = nil
            chatHasNextPage = false
            return
        }
        chatNextCursor = nextCursor
        chatHasNextPage = true
    }

    private func deduplicatedChatItems<S: Sequence>(_ items: S) -> [ShareGroupChatItem]
        where S.Element == ShareGroupChatItem {
        var seenIDs: Set<ShareGroupChatItem.ID> = []
        return items.filter { seenIDs.insert($0.id).inserted }
    }

    func resetRemoteData() {
        repository.invalidateCacheSession()
        sharedPhotoRepository?.invalidateCacheSession()
        remoteDataSessionID = UUID()
        groups = []
        cacheOwnerID = nil
        hasLoadedGroups = false
        isLoadingGroups = false
        isLoadingMoreGroups = false
        nextGroupCursor = nil
        groupsHaveNextPage = false
        requestedGroupCursors = []
        loadedGroupDetailIDs = []
        loadingGroupDetailIDs = []
        loadedSharedAlbumGroupIDs = []
        loadingSharedAlbumGroupIDs = []
        loadingMoreSharedAlbumGroupIDs = []
        sharedAlbumNextCursors = [:]
        sharedAlbumHasNextPage = [:]
        requestedSharedAlbumCursors = [:]
        inviteCodes = [:]
        loadingInviteCodeGroupIDs = []
        membersByGroupID = [:]
        loadingMemberGroupIDs = []
        visibleGroupIDs = nil
        visibleSharedAlbumIDs = [:]
        personalAlbumImportIdempotencyKeys = [:]
        personalAlbumImportCreatedAlbums = [:]
        inviteCode = ""
        resetTransientUI()
    }

    func enterAddMode() {
        isAddMode = true
    }

    func exitAddMode() {
        isAddMode = false
    }

    func dismissPresentedSheet() {
        guard !isPresentedSheetBusy else { return }
        dismissSheet()
    }

    func shareSheetDidDismiss() {
        let dismissed = dismissingSheet
        dismissingSheet = nil
        if let pendingSheet {
            self.pendingSheet = nil
            Task { @MainActor [weak self] in
                self?.presentedSheet = pendingSheet
            }
            return
        }

        switch dismissed {
        case .invitation:
            isAddMode = false
            groupNameDraft = ""
        case .comments:
            clearCommentsState()
        case .management:
            clearManagementState()
        case .joinEntry, .joinConfirmation:
            resetJoinState()
        case .createGroup:
            groupCreationName = nil
            groupCreationIdempotencyKey = nil
        case .createSharedAlbum:
            clearSharedAlbumCreationState()
        case nil:
            break
        }
    }

    func presentJoinSheet() {
        resetJoinState()
        completedJoinNavigationGroupID = nil
        joinCode = ""
        presentSheet(.joinEntry)
    }

    func confirmJoinCode() async {
        let trimmedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, !isPreviewingJoin else { return }

        let sessionID = remoteDataSessionID
        isPreviewingJoin = true
        joinErrorCode = nil
        defer {
            if remoteDataSessionID == sessionID {
                isPreviewingJoin = false
            }
        }

        do {
            let preview = try await repository.previewJoin(inviteCode: trimmedCode)
            guard remoteDataSessionID == sessionID else { return }
            joinCode = trimmedCode
            joinRequestInviteCode = trimmedCode
            joinIdempotencyKey = preview.alreadyJoined ? nil : UUID()
            pendingJoinPreview = preview
            pendingJoinAlreadyJoined = preview.alreadyJoined
            transitionSheet(to: .joinConfirmation)
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return }
            joinErrorCode = String(describing: error)
            presentError(error, fallback: "공유 그룹 입장 정보를 확인하지 못했어요.")
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return }
            joinErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유 그룹 입장 정보를 확인하지 못했어요.")
        } catch {
            guard remoteDataSessionID == sessionID else { return }
            joinErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유 그룹 입장 정보를 확인하지 못했어요.")
        }
    }

    func cancelJoinConfirmation() {
        guard !isJoiningGroup else { return }
        dismissSheet(if: .joinConfirmation)
    }

    func completeJoin() async -> ShareAlbum.ID? {
        guard let pendingJoinPreview,
              let joinRequestInviteCode,
              !isJoiningGroup
        else {
            return nil
        }

        let sessionID = remoteDataSessionID
        let idempotencyKey = joinIdempotencyKey ?? UUID()
        joinIdempotencyKey = idempotencyKey
        isJoiningGroup = true
        joinErrorCode = nil
        defer {
            if remoteDataSessionID == sessionID {
                isJoiningGroup = false
            }
        }

        do {
            let groupID: ShareAlbum.ID
            if let joinedGroupIDAwaitingSync {
                groupID = joinedGroupIDAwaitingSync
            } else if pendingJoinAlreadyJoined {
                groupID = pendingJoinPreview.group.id
            } else {
                groupID = try await repository.join(
                    inviteCode: joinRequestInviteCode,
                    idempotencyKey: idempotencyKey
                )
                guard remoteDataSessionID == sessionID else { return nil }
                joinedGroupIDAwaitingSync = groupID
            }
            try await prepareJoinedGroup(id: groupID)
            guard remoteDataSessionID == sessionID else { return nil }
            joinedGroupIDAwaitingSync = nil
            completedJoinNavigationGroupID = groupID
            finishJoin()
            return groupID
        } catch ShareGroupRepositoryError.alreadyJoined {
            guard remoteDataSessionID == sessionID else { return nil }
            do {
                joinedGroupIDAwaitingSync = pendingJoinPreview.group.id
                try await prepareJoinedGroup(id: pendingJoinPreview.group.id)
                guard remoteDataSessionID == sessionID else { return nil }
                joinedGroupIDAwaitingSync = nil
                completedJoinNavigationGroupID = pendingJoinPreview.group.id
                finishJoin()
                return pendingJoinPreview.group.id
            } catch {
                guard remoteDataSessionID == sessionID else { return nil }
                presentJoinError(error)
                return nil
            }
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return nil }
            joinErrorCode = String(describing: error)
            presentJoinError(error)
            return nil
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return nil }
            joinErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentJoinError(error)
            return nil
        } catch {
            guard remoteDataSessionID == sessionID else { return nil }
            joinErrorCode = "UNKNOWN_ERROR"
            presentJoinError(error)
            return nil
        }
    }

    func consumeCompletedJoinNavigation() {
        completedJoinNavigationGroupID = nil
    }

    func presentCreateSheet() {
        groupNameDraft = ""
        groupCreationName = nil
        groupCreationIdempotencyKey = nil
        presentSheet(.createGroup)
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

        let sessionID = remoteDataSessionID
        isCreatingGroup = true
        defer {
            if remoteDataSessionID == sessionID {
                isCreatingGroup = false
            }
        }

        do {
            let createdGroup = try await repository.createGroup(
                name: trimmedName,
                idempotencyKey: idempotencyKey
            )
            guard remoteDataSessionID == sessionID else { return }
            if var groupIDs = visibleGroupIDs {
                groupIDs.removeAll { $0 == createdGroup.id }
                groupIDs.insert(createdGroup.id, at: 0)
                visibleGroupIDs = groupIDs
            }
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return }
            hasLoadedGroups = true
            inviteCode = createdGroup.inviteCode
            inviteCodes[createdGroup.id] = inviteCode
            groupCreationName = nil
            groupCreationIdempotencyKey = nil
            transitionSheet(to: .invitation)
        } catch {
            guard remoteDataSessionID == sessionID else { return }
            presentError(error, fallback: "공유 그룹을 만들지 못했어요.")
        }
    }

    func presentCreateSharedAlbumSheet(groupID: ShareAlbum.ID) {
        guard group(withID: groupID) != nil else { return }
        clearSharedAlbumCreationState()
        sharedAlbumCreationGroupID = groupID
        presentSheet(.createSharedAlbum)
    }

    func dismissCreateSharedAlbumSheet() {
        guard !isCreatingSharedAlbum else { return }
        dismissSheet(if: .createSharedAlbum)
    }

    func resetSharedAlbumCreationDraft() {
        sharedAlbumNameDraft = ""
        sharedAlbumCreationName = nil
        sharedAlbumCreationIdempotencyKey = nil
    }

    @discardableResult
    func createSharedAlbum() async -> SharedAlbum? {
        guard let groupID = sharedAlbumCreationGroupID,
              group(withID: groupID) != nil,
              !isCreatingSharedAlbum
        else {
            return nil
        }

        let name = sharedAlbumNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else { return nil }

        let idempotencyKey: UUID
        if sharedAlbumCreationName == name, let sharedAlbumCreationIdempotencyKey {
            idempotencyKey = sharedAlbumCreationIdempotencyKey
        } else {
            idempotencyKey = UUID()
            sharedAlbumCreationName = name
            sharedAlbumCreationIdempotencyKey = idempotencyKey
        }

        let sessionID = remoteDataSessionID
        isCreatingSharedAlbum = true
        sharedAlbumErrorCode = nil
        defer {
            if remoteDataSessionID == sessionID {
                isCreatingSharedAlbum = false
            }
        }

        do {
            let album = try await repository.createSharedAlbum(
                groupID: groupID,
                name: name,
                idempotencyKey: idempotencyKey
            )
            guard remoteDataSessionID == sessionID else { return nil }

            var albumIDs = visibleSharedAlbumIDs[groupID]
                ?? group(withID: groupID)?.albums.map(\.id)
                ?? []
            albumIDs.removeAll { $0 == album.id }
            albumIDs.insert(album.id, at: 0)
            visibleSharedAlbumIDs[groupID] = albumIDs
            loadedSharedAlbumGroupIDs.insert(groupID)

            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return nil }
            sharedAlbumCreationName = nil
            sharedAlbumCreationIdempotencyKey = nil
            dismissSheet(if: .createSharedAlbum)
            return album
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return nil }
            await removeMissingGroup(id: groupID)
            dismissSheet(if: .createSharedAlbum)
            return nil
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return nil }
            sharedAlbumErrorCode = String(describing: error)
            presentError(error, fallback: "공유집을 만들지 못했어요.")
            return nil
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return nil }
            sharedAlbumErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유집을 만들지 못했어요.")
            return nil
        } catch {
            guard remoteDataSessionID == sessionID else { return nil }
            sharedAlbumErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유집을 만들지 못했어요.")
            return nil
        }
    }

    func completeInvitation() {
        dismissSheet(if: .invitation)
    }

    @discardableResult
    func addAlbums(_ albums: [SharedAlbum], to groupID: ShareAlbum.ID) -> Bool {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else { return false }
        let existingIDs = Set(groups[groupIndex].albums.map(\.id))
        groups[groupIndex].albums.append(contentsOf: albums.filter { !existingIDs.contains($0.id) })
        return true
    }

    func importPhotos(
        localIdentifiers: [String],
        into albumID: SharedAlbum.ID,
        groupID: ShareAlbum.ID
    ) async -> SharedAlbumPhotoMutationResult? {
        guard let sharedPhotoRepository, !localIdentifiers.isEmpty else { return nil }
        do {
            let result = try await sharedPhotoRepository.addLocalPhotos(
                localIdentifiers: localIdentifiers,
                to: [albumID],
                in: groupID
            )
            await refreshSharedAlbumsAfterPhotoMutation(groupID: groupID)
            if result.failedCount > 0 {
                logMutationFailure(
                    operation: "import photos to shared album",
                    succeededCount: result.succeededCount,
                    failedCount: result.failedCount
                )
            }
            return result
        } catch {
            presentError(error, fallback: "사진을 공유집으로 가져오지 못했어요.")
            return nil
        }
    }

    func importPersonalAlbums(
        _ personalAlbums: [Album],
        into groupID: ShareAlbum.ID
    ) async -> ShareImportOutcome? {
        guard let sharedPhotoRepository, !personalAlbums.isEmpty else { return nil }

        var createdAlbumCount = 0
        var failedAlbumCount = 0
        var uploadedPhotoCount = 0
        var failedPhotoCount = 0

        for personalAlbum in personalAlbums {
            let createdAlbum: SharedAlbum
            let requestIdentity = "\(groupID.uuidString):\(personalAlbum.id):\(personalAlbum.name)"
            let idempotencyKey = personalAlbumImportIdempotencyKeys[requestIdentity] ?? UUID()
            personalAlbumImportIdempotencyKeys[requestIdentity] = idempotencyKey
            if let existingAlbum = personalAlbumImportCreatedAlbums[requestIdentity] {
                createdAlbum = existingAlbum
            } else {
                do {
                    createdAlbum = try await repository.createSharedAlbum(
                        groupID: groupID,
                        name: personalAlbum.name,
                        idempotencyKey: idempotencyKey
                    )
                    personalAlbumImportCreatedAlbums[requestIdentity] = createdAlbum
                    createdAlbumCount += 1
                } catch is CancellationError {
                    return nil
                } catch {
                    presentError(error, fallback: "개인 사진집에 대응하는 공유집을 만들지 못했어요.")
                    failedAlbumCount += 1
                    failedPhotoCount += personalAlbum.count
                    continue
                }
            }

            do {
                let identifiers = try await sharedPhotoRepository.localIdentifiers(
                    inPersonalAlbum: personalAlbum.id
                )
                guard !identifiers.isEmpty else {
                    personalAlbumImportIdempotencyKeys.removeValue(forKey: requestIdentity)
                    personalAlbumImportCreatedAlbums.removeValue(forKey: requestIdentity)
                    continue
                }
                let result = try await sharedPhotoRepository.addLocalPhotos(
                    localIdentifiers: identifiers,
                    to: [createdAlbum.id],
                    in: groupID
                )
                uploadedPhotoCount += result.succeededCount
                failedPhotoCount += result.failedCount
                if result.failedCount == 0,
                   Set(result.succeededLocalIdentifiers) == Set(identifiers) {
                    personalAlbumImportIdempotencyKeys.removeValue(forKey: requestIdentity)
                    personalAlbumImportCreatedAlbums.removeValue(forKey: requestIdentity)
                }
            } catch is CancellationError {
                return nil
            } catch {
                // 생성된 공유집은 유지하고 이 사진들만 다음 가져오기에서 재시도한다.
                presentError(error, fallback: "개인 사진집의 사진을 공유집으로 가져오지 못했어요.")
                failedPhotoCount += personalAlbum.count
            }
        }

        await refreshSharedAlbumsAfterPhotoMutation(groupID: groupID)
        let outcome = ShareImportOutcome(
            createdAlbumCount: createdAlbumCount,
            failedAlbumCount: failedAlbumCount,
            uploadedPhotoCount: uploadedPhotoCount,
            failedPhotoCount: failedPhotoCount
        )
        if !outcome.completedAnyWork, outcome.hasFailures {
            presentError(
                URLError(.cannotLoadFromNetwork),
                fallback: "선택한 사진집을 가져오지 못했어요."
            )
        } else if outcome.hasFailures {
            logMutationFailure(
                operation: "import personal albums",
                succeededCount: outcome.uploadedPhotoCount,
                failedCount: outcome.failedPhotoCount
            )
        }
        return outcome
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

        let sessionID = remoteDataSessionID
        isUpdatingSharedAlbum = true
        sharedAlbumErrorCode = nil
        defer {
            if remoteDataSessionID == sessionID {
                isUpdatingSharedAlbum = false
            }
        }

        do {
            try await repository.renameSharedAlbum(id: albumID, groupID: groupID, name: name)
            guard remoteDataSessionID == sessionID else { return false }
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return false }
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return false }
            await removeMissingGroup(id: groupID)
            return false
        } catch ShareGroupRepositoryError.sharedAlbumNotFound {
            guard remoteDataSessionID == sessionID else { return false }
            removeSharedAlbumState(id: albumID, groupID: groupID)
            try? await reloadGroups()
            return false
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return false }
            sharedAlbumErrorCode = String(describing: error)
            presentError(error, fallback: "공유집 이름을 변경하지 못했어요.")
            return false
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return false }
            sharedAlbumErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유집 이름을 변경하지 못했어요.")
            return false
        } catch {
            guard remoteDataSessionID == sessionID else { return false }
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

        let sessionID = remoteDataSessionID
        isDeletingSharedAlbums = true
        sharedAlbumErrorCode = nil
        defer {
            if remoteDataSessionID == sessionID {
                isDeletingSharedAlbums = false
            }
        }

        do {
            try await repository.deleteSharedAlbum(id: albumID, groupID: groupID)
            guard remoteDataSessionID == sessionID else { return false }
            removeSharedAlbumState(id: albumID, groupID: groupID)
            await refreshGroupAfterAlbumMutation(groupID: groupID)
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return false }
            await removeMissingGroup(id: groupID)
            return true
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return false }
            sharedAlbumErrorCode = String(describing: error)
            presentError(error, fallback: "공유집을 삭제하지 못했어요.")
            return false
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return false }
            sharedAlbumErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유집을 삭제하지 못했어요.")
            return false
        } catch {
            guard remoteDataSessionID == sessionID else { return false }
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

        let sessionID = remoteDataSessionID
        isDeletingSharedAlbums = true
        sharedAlbumErrorCode = nil
        defer {
            if remoteDataSessionID == sessionID {
                isDeletingSharedAlbums = false
            }
        }

        do {
            _ = try await repository.deleteSharedAlbums(
                ids: Array(albumIDs),
                groupID: groupID,
                idempotencyKey: idempotencyKey
            )
            guard remoteDataSessionID == sessionID else { return false }
            for albumID in albumIDs {
                removeSharedAlbumState(id: albumID, groupID: groupID)
            }
            bulkDeleteAlbumIDs = nil
            bulkDeleteIdempotencyKey = nil
            await refreshGroupAfterAlbumMutation(groupID: groupID)
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return false }
            bulkDeleteAlbumIDs = nil
            bulkDeleteIdempotencyKey = nil
            await removeMissingGroup(id: groupID)
            return true
        } catch ShareGroupRepositoryError.sharedAlbumNotFound {
            guard remoteDataSessionID == sessionID else { return false }
            try? await reloadGroups()
            sharedAlbumErrorCode = String(describing: ShareGroupRepositoryError.sharedAlbumNotFound)
            presentError(
                ShareGroupRepositoryError.sharedAlbumNotFound,
                fallback: "선택한 공유집을 삭제하지 못했어요."
            )
            return false
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return false }
            sharedAlbumErrorCode = String(describing: error)
            presentError(error, fallback: "선택한 공유집을 삭제하지 못했어요.")
            return false
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return false }
            sharedAlbumErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "선택한 공유집을 삭제하지 못했어요.")
            return false
        } catch {
            guard remoteDataSessionID == sessionID else { return false }
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
        presentSheet(.management)
    }

    func completeShareManagement() async {
        guard let group = managedShareGroup, !isUpdatingGroup else { return }
        guard group.currentUserRole == .admin else {
            presentError(
                ShareGroupRepositoryError.hostRequired,
                fallback: "공유 그룹 이름은 방장만 변경할 수 있어요."
            )
            return
        }

        let trimmedName = shareGroupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard trimmedName != group.name else {
            dismissShareManagement()
            return
        }

        let sessionID = remoteDataSessionID
        groupManagementErrorCode = nil
        isUpdatingGroup = true
        defer {
            if remoteDataSessionID == sessionID {
                isUpdatingGroup = false
            }
        }
        do {
            try await repository.updateGroupName(id: group.id, name: trimmedName)
            guard remoteDataSessionID == sessionID else { return }
            try await reloadGroups()
            guard remoteDataSessionID == sessionID else { return }
            isUpdatingGroup = false
            dismissShareManagement()
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return }
            groupManagementErrorCode = String(describing: error)
            presentError(error, fallback: "공유 그룹 이름을 변경하지 못했어요.")
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return }
            groupManagementErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유 그룹 이름을 변경하지 못했어요.")
        } catch {
            guard remoteDataSessionID == sessionID else { return }
            groupManagementErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유 그룹 이름을 변경하지 못했어요.")
        }
    }

    @discardableResult
    func leaveManagedShareGroup() async -> Bool {
        guard let group = managedShareGroup, !isLeavingGroup else { return false }

        let sessionID = remoteDataSessionID
        groupManagementErrorCode = nil
        isLeavingGroup = true
        defer {
            if remoteDataSessionID == sessionID {
                isLeavingGroup = false
            }
        }
        do {
            switch group.currentUserRole {
            case .admin:
                try await repository.deleteRemoteGroup(id: group.id)
            case .participant:
                try await repository.leaveGroup(id: group.id)
            }
            guard remoteDataSessionID == sessionID else { return false }
            removeGroupState(id: group.id)
            do {
                try await reloadGroups()
            } catch {
                presentError(error, fallback: "그룹 정리는 완료됐지만 목록을 갱신하지 못했어요.")
            }
            isLeavingGroup = false
            dismissShareManagement()
            return true
        } catch ShareGroupRepositoryError.groupNotFound {
            guard remoteDataSessionID == sessionID else { return false }
            isLeavingGroup = false
            await removeMissingGroup(id: group.id)
            dismissShareManagement()
            return true
        } catch let error as ShareGroupRepositoryError {
            guard remoteDataSessionID == sessionID else { return false }
            groupManagementErrorCode = String(describing: error)
            presentError(error, fallback: "공유 그룹에서 나가지 못했어요.")
            return false
        } catch let error as NetworkError {
            guard remoteDataSessionID == sessionID else { return false }
            groupManagementErrorCode = error.serverCode ?? "NETWORK_ERROR"
            presentError(error, fallback: "공유 그룹에서 나가지 못했어요.")
            return false
        } catch {
            guard remoteDataSessionID == sessionID else { return false }
            groupManagementErrorCode = "UNKNOWN_ERROR"
            presentError(error, fallback: "공유 그룹에서 나가지 못했어요.")
            return false
        }
    }

    func dismissShareManagement() {
        guard !isUpdatingGroup, !isLeavingGroup else { return }
        dismissSheet(if: .management)
    }

    private func clearManagementState() {
        managedShareGroup = nil
        groupManagementErrorCode = nil
        isUpdatingGroup = false
        isLeavingGroup = false
    }

    func resetTransientUI() {
        isAddMode = false
        presentedSheet = nil
        dismissingSheet = nil
        pendingSheet = nil
        completedJoinNavigationGroupID = nil
        clearCommentsState()
        clearManagementState()
        resetJoinState()
        clearSharedAlbumCreationState()
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
        guard page.hasNext,
              let nextCursor = page.nextCursor,
              !requestedSharedAlbumCursors[groupID, default: []].contains(nextCursor)
        else {
            sharedAlbumNextCursors.removeValue(forKey: groupID)
            sharedAlbumHasNextPage[groupID] = false
            return
        }
        sharedAlbumNextCursors[groupID] = nextCursor
        sharedAlbumHasNextPage[groupID] = true
    }

    private func updateGroupPageState(_ page: ShareGroupRepositoryPage) {
        guard page.hasNext,
              let nextCursor = page.nextCursor,
              !requestedGroupCursors.contains(nextCursor)
        else {
            nextGroupCursor = nil
            groupsHaveNextPage = false
            return
        }
        nextGroupCursor = nextCursor
        groupsHaveNextPage = true
    }

    private func refreshManagedGroupIfNeeded(id: ShareAlbum.ID) {
        guard managedShareGroup?.id == id else { return }
        managedShareGroup = group(withID: id)
    }

    private func removeMissingGroup(id: ShareAlbum.ID) async {
        let sessionID = remoteDataSessionID
        do {
            try await repository.removeCachedGroup(id: id)
        } catch is CancellationError {
            return
        } catch {
            // 원격에서 사라진 그룹은 로컬 캐시 정리에 실패해도 현재 화면에서는 제거한다.
        }
        guard remoteDataSessionID == sessionID else { return }
        removeGroupState(id: id)
        try? await reloadGroups()
        guard remoteDataSessionID == sessionID else { return }
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
        requestedSharedAlbumCursors.removeValue(forKey: id)
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

    private func refreshSharedAlbumsAfterPhotoMutation(groupID: ShareAlbum.ID) async {
        do {
            var cursor: String?
            var requestedCursors: Set<String> = []
            var visibleIDs: [SharedAlbum.ID] = []
            repeat {
                if let cursor, !requestedCursors.insert(cursor).inserted {
                    throw ShareGroupRepositoryError.invalidPagination
                }
                let page = try await repository.syncSharedAlbums(
                    groupID: groupID,
                    cursor: cursor,
                    size: 100
                )
                visibleIDs.append(contentsOf: page.itemIDs.filter { !visibleIDs.contains($0) })
                if page.hasNext {
                    guard let nextCursor = page.nextCursor, nextCursor != cursor else {
                        throw ShareGroupRepositoryError.invalidPagination
                    }
                    cursor = nextCursor
                } else {
                    cursor = nil
                }
            } while cursor != nil

            visibleSharedAlbumIDs[groupID] = visibleIDs
            loadedSharedAlbumGroupIDs.insert(groupID)
            try await repository.syncGroup(id: groupID)
            try await reloadGroups()
        } catch ShareGroupRepositoryError.groupNotFound {
            await removeMissingGroup(id: groupID)
        } catch {
            // 서버 작업은 완료됐다. 다음 화면 진입/새로고침에서 캐시를 서버 상태로 복구한다.
        }
    }

    private func prepareJoinedGroup(id: ShareAlbum.ID) async throws {
        try await repository.syncGroup(id: id)

        if var groupIDs = visibleGroupIDs {
            groupIDs.removeAll { $0 == id }
            groupIDs.insert(id, at: 0)
            visibleGroupIDs = groupIDs
        } else {
            visibleGroupIDs = [id] + groups.map(\.id).filter { $0 != id }
        }

        try await reloadGroups()
        hasLoadedGroups = true
        loadedGroupDetailIDs.insert(id)
    }

    private func presentJoinError(_ error: Error) {
        if let repositoryError = error as? ShareGroupRepositoryError {
            joinErrorCode = String(describing: repositoryError)
        } else if let networkError = error as? NetworkError {
            joinErrorCode = networkError.serverCode ?? "NETWORK_ERROR"
        } else {
            joinErrorCode = "UNKNOWN_ERROR"
        }
        presentError(
            error,
            fallback: "공유 그룹 정보를 불러오지 못했어요."
        )
    }

    private func finishJoin() {
        dismissSheet()
        isAddMode = false
    }

    private func presentSheet(_ sheet: ShareSheetPresentation) {
        guard presentedSheet != sheet else { return }
        if presentedSheet != nil || dismissingSheet != nil {
            transitionSheet(to: sheet)
        } else {
            presentedSheet = sheet
        }
    }

    private func transitionSheet(to sheet: ShareSheetPresentation) {
        if presentedSheet != nil {
            withAnimation(.easeInOut(duration: 0.25)) {
                presentedSheet = sheet
            }
        } else {
            pendingSheet = sheet
        }
    }

    private func dismissSheet(if expectedSheet: ShareSheetPresentation? = nil) {
        if let expectedSheet, presentedSheet != expectedSheet, dismissingSheet != expectedSheet {
            return
        }
        pendingSheet = nil
        if let presentedSheet {
            dismissingSheet = presentedSheet
            self.presentedSheet = nil
        }
    }

    private func resetJoinState() {
        isPreviewingJoin = false
        isJoiningGroup = false
        joinErrorCode = nil
        joinRequestInviteCode = nil
        joinIdempotencyKey = nil
        joinedGroupIDAwaitingSync = nil
        pendingJoinAlreadyJoined = false
        pendingJoinPreview = nil
    }

    private func clearSharedAlbumCreationState() {
        isCreatingSharedAlbum = false
        sharedAlbumNameDraft = ""
        sharedAlbumCreationGroupID = nil
        sharedAlbumCreationName = nil
        sharedAlbumCreationIdempotencyKey = nil
    }

    private func presentError(
        _ error: Error,
        fallback: String
    ) {
        guard !(error is CancellationError) else { return }
        Self.logger.error(
            """
            ❌ [Share] \(fallback, privacy: .public)
            Error: \(String(describing: error), privacy: .public)
            """
        )
    }

    private func logMutationFailure(
        operation: String,
        succeededCount: Int,
        failedCount: Int
    ) {
        Self.logger.error(
            """
            ❌ [Share] \(operation, privacy: .public)
            Succeeded: \(succeededCount, privacy: .public)
            Failed: \(failedCount, privacy: .public)
            """
        )
    }
}
