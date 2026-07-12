//
//  ShareViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

enum ShareRoute: Hashable {
    case login
    case group(ShareAlbum.ID)
    case album(groupID: ShareAlbum.ID, albumID: Album.ID)
    case importContent(ShareAlbum.ID)
}

enum ShareImportSelection: Hashable {
    case photos
    case albums
}

struct ShareAlbumManagementTarget: Equatable {
    let groupID: ShareAlbum.ID
    let albumID: Album.ID
}

@Observable
final class ShareViewModel {
    var groups: [ShareAlbum]
    var navigationPath: [ShareRoute] = []

    var isAddMode = false
    var isJoinSheetPresented = false
    var isJoinConfirmationPresented = false
    var isCreateSheetPresented = false
    var isInviteSheetPresented = false
    var isCommentsPresented = false
    var isAlbumManagementPresented = false

    var joinCode = ""
    var groupNameDraft = ""
    let inviteCode = "# 3d2dsd322d32d23"
    var commentDraft = ""
    var albumNameDraft = ""

    private(set) var pendingJoinGroup: ShareAlbum?
    private(set) var pendingCreatedGroup: ShareAlbum?
    private(set) var albumManagementTarget: ShareAlbumManagementTarget?

    init(groups: [ShareAlbum] = ShareAlbum.samples) {
        self.groups = groups
    }

    var hidesRootNavbar: Bool {
        isAddMode || !navigationPath.isEmpty
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

    func showGroup(_ group: ShareAlbum) {
        navigationPath.append(.group(group.id))
    }

    func showLogin() {
        navigationPath.append(.login)
    }

    func completeLogin() {
        navigationPath.removeAll()
    }

    func showAlbum(_ album: Album, in groupID: ShareAlbum.ID) {
        navigationPath.append(.album(groupID: groupID, albumID: album.id))
    }

    func showImport(for groupID: ShareAlbum.ID) {
        navigationPath.append(.importContent(groupID))
    }

    func goBack() {
        guard !navigationPath.isEmpty else {
            return
        }
        navigationPath.removeLast()
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
        isCreateSheetPresented = true
    }

    func createGroup() {
        let trimmedName = groupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        pendingCreatedGroup = ShareAlbum(
            name: trimmedName,
            date: .now,
            memberCount: 1
        )
        isCreateSheetPresented = false
        isInviteSheetPresented = true
    }

    func completeInvitation() {
        if let pendingCreatedGroup {
            groups.append(pendingCreatedGroup)
        }
        pendingCreatedGroup = nil
        isInviteSheetPresented = false
        isAddMode = false
    }

    func addAlbums(_ albums: [Album], to groupID: ShareAlbum.ID) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        let existingIDs = Set(groups[groupIndex].albums.map(\.id))
        groups[groupIndex].albums.append(contentsOf: albums.filter { !existingIDs.contains($0.id) })
        goBack()
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

    func resetTransientUI() {
        isAddMode = false
        navigationPath.removeAll()
        isJoinSheetPresented = false
        isJoinConfirmationPresented = false
        isCreateSheetPresented = false
        isInviteSheetPresented = false
        isCommentsPresented = false
        pendingJoinGroup = nil
        pendingCreatedGroup = nil
        dismissAlbumManagement()
    }
}
