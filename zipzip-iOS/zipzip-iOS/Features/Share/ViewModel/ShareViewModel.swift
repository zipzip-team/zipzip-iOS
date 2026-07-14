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
    let albumID: Album.ID
}

@Observable
@MainActor
final class ShareViewModel {
    var groups: [ShareAlbum]

    var isAddMode = false
    var isJoinSheetPresented = false
    var isJoinConfirmationPresented = false
    var isCreateSheetPresented = false
    var isInviteSheetPresented = false
    var isCommentsPresented = false
    var isAlbumManagementPresented = false
    var isShareManagementPresented = false
    private(set) var isCreatingGroup = false

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

    init() {
        self.groups = ShareAlbum.samples
    }

    init(groups: [ShareAlbum]) {
        self.groups = groups
    }

    func group(withID id: ShareAlbum.ID) -> ShareAlbum? {
        groups.first { $0.id == id }
    }

    func album(groupID: ShareAlbum.ID, albumID: Album.ID) -> Album? {
        group(withID: groupID)?.albums.first { $0.id == albumID }
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
        guard !trimmedCode.isEmpty else {
            return
        }

        pendingJoinGroup = ShareAlbum(
            name: "집집팟",
            date: .now,
            memberCount: 4,
            currentUserRole: .participant,
            albums: Array(Album.sharedSamples.prefix(2))
        )
        isJoinSheetPresented = false
        isJoinConfirmationPresented = true
    }

    func cancelJoinConfirmation() {
        pendingJoinGroup = nil
        isJoinConfirmationPresented = false
    }

    func completeJoin() {
        if let pendingJoinGroup {
            groups.append(pendingJoinGroup)
        }
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
        guard !trimmedName.isEmpty, !isCreatingGroup else {
            return
        }

        let idempotencyKey: UUID
        if groupCreationName == trimmedName, let groupCreationIdempotencyKey {
            idempotencyKey = groupCreationIdempotencyKey
        } else {
            idempotencyKey = UUID()
            groupCreationName = trimmedName
            groupCreationIdempotencyKey = idempotencyKey
        }

        isCreatingGroup = true

        do {
            let response = try await api.createGroup(
                name: trimmedName,
                idempotencyKey: idempotencyKey
            )
            let createdGroup = ShareAlbum(
                id: response.id,
                name: response.name,
                date: .now,
                memberCount: 1,
                currentUserRole: .admin
            )
            groups.append(createdGroup)
            inviteCode = response.inviteCode
            groupCreationName = nil
            groupCreationIdempotencyKey = nil
            isCreateSheetPresented = false
            isInviteSheetPresented = true
        } catch {}

        isCreatingGroup = false
    }

    func completeInvitation() {
        isInviteSheetPresented = false
        isAddMode = false
    }

    @discardableResult
    func addAlbums(_ albums: [Album], to groupID: ShareAlbum.ID) -> Bool {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else {
            return false
        }

        let existingIDs = Set(groups[groupIndex].albums.map(\.id))
        groups[groupIndex].albums.append(contentsOf: albums.filter { !existingIDs.contains($0.id) })
        return true
    }

    func removeAlbums(_ albumIDs: Set<Album.ID>, from groupID: ShareAlbum.ID) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        groups[groupIndex].albums.removeAll { albumIDs.contains($0.id) }
    }

    func presentAlbumManagement(groupID: ShareAlbum.ID, albumID: Album.ID) {
        guard let album = album(groupID: groupID, albumID: albumID) else {
            return
        }
        albumNameDraft = album.name
        albumManagementTarget = .init(groupID: groupID, albumID: albumID)
        isAlbumManagementPresented = true
    }

    func completeAlbumManagement() {
        let trimmedName = albumNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let target = albumManagementTarget,
              let groupIndex = groups.firstIndex(where: { $0.id == target.groupID }),
              let albumIndex = groups[groupIndex].albums.firstIndex(where: { $0.id == target.albumID })
        else {
            return
        }

        let album = groups[groupIndex].albums[albumIndex]
        groups[groupIndex].albums[albumIndex] = Album(
            id: album.id,
            name: trimmedName,
            count: album.count
        )
        dismissAlbumManagement()
    }

    func renameAlbum(groupID: ShareAlbum.ID, albumID: Album.ID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let groupIndex = groups.firstIndex(where: { $0.id == groupID }),
              let albumIndex = groups[groupIndex].albums.firstIndex(where: { $0.id == albumID })
        else {
            return
        }

        let album = groups[groupIndex].albums[albumIndex]
        groups[groupIndex].albums[albumIndex] = Album(
            id: album.id,
            name: trimmedName,
            count: album.count
        )
    }

    func deleteManagedAlbum() {
        guard let target = albumManagementTarget else {
            return
        }
        removeAlbums([target.albumID], from: target.groupID)
        dismissAlbumManagement()
    }

    func dismissAlbumManagement() {
        isAlbumManagementPresented = false
        albumManagementTarget = nil
    }

    func presentShareManagement(groupID: ShareAlbum.ID) {
        guard let group = group(withID: groupID) else {
            return
        }
        shareGroupNameDraft = group.name
        managedShareGroup = group
        isShareManagementPresented = true
    }

    func completeShareManagement() {
        let trimmedName = shareGroupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let managedShareGroup,
              let groupIndex = groups.firstIndex(where: { $0.id == managedShareGroup.id })
        else {
            return
        }
        groups[groupIndex].name = trimmedName
        self.managedShareGroup?.name = trimmedName
        dismissShareManagement()
    }

    @discardableResult
    func leaveManagedShareGroup() -> Bool {
        guard let managedShareGroup else {
            return false
        }
        groups.removeAll { $0.id == managedShareGroup.id }
        dismissShareManagement()
        return true
    }

    func dismissShareManagement() {
        isShareManagementPresented = false
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
}
