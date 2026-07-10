//
//  AlbumDetailViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

struct AlbumDetailActions {
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onAddPhotos: ([UUID]) -> Void
    let onDeletePhotos: ([UUID], PhotoDeletionAction) -> Void
    let onMovePhotos: ([UUID], ShareDestination) -> Void

    init(
        onRename: @escaping (String) -> Void = { _ in },
        onDelete: @escaping () -> Void = {},
        onAddPhotos: @escaping ([UUID]) -> Void = { _ in },
        onDeletePhotos: @escaping ([UUID], PhotoDeletionAction) -> Void = { _, _ in },
        onMovePhotos: @escaping ([UUID], ShareDestination) -> Void = { _, _ in }
    ) {
        self.onRename = onRename
        self.onDelete = onDelete
        self.onAddPhotos = onAddPhotos
        self.onDeletePhotos = onDeletePhotos
        self.onMovePhotos = onMovePhotos
    }
}

@Observable
final class AlbumDetailViewModel {
    var isSelectionMode: Bool
    var isPhotoPickerPresented = false
    var isAlbumManagementPresented = false
    var isAlbumDeleteAlertPresented = false
    var isMoveSheetPresented = false
    var isDeleteAlertPresented = false
    var albumTitleDraft = ""

    private(set) var selectedPhotoIDs: [UUID] = []

    private let actions: AlbumDetailActions
    private let onEditPhotoInfo: (UUID) -> Void

    init(
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        onEditPhotoInfo: @escaping (UUID) -> Void = { _ in }
    ) {
        self.isSelectionMode = initialSelectionMode
        self.actions = actions
        self.onEditPhotoInfo = onEditPhotoInfo
    }

    var hasSelectedPhotos: Bool {
        !selectedPhotoIDs.isEmpty
    }

    func enterSelectionMode(photoCount: Int) {
        guard photoCount > 0 else {
            return
        }

        isSelectionMode = true
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotoIDs.removeAll()
    }

    func togglePhotoSelection(_ id: UUID) {
        guard isSelectionMode else {
            return
        }

        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }

    func presentPhotoPicker() {
        isPhotoPickerPresented = true
    }

    func addPhotos(_ photoIDs: [UUID]) {
        actions.onAddPhotos(photoIDs)
    }

    func presentAlbumManagement(albumTitle: String) {
        exitSelectionMode()
        albumTitleDraft = albumTitle
        isAlbumManagementPresented = true
    }

    func dismissAlbumManagement() {
        isAlbumManagementPresented = false
    }

    func completeAlbumManagement() {
        let trimmedTitle = albumTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return
        }

        actions.onRename(trimmedTitle)
        isAlbumManagementPresented = false
    }

    func presentAlbumDeleteAlert() {
        isAlbumDeleteAlertPresented = true
    }

    func dismissAlbumDeleteAlert() {
        isAlbumDeleteAlertPresented = false
    }

    func confirmAlbumDeletion() {
        isAlbumDeleteAlertPresented = false
        isAlbumManagementPresented = false
        actions.onDelete()
    }

    func presentMoveSheet() {
        guard hasSelectedPhotos else {
            return
        }

        isMoveSheetPresented = true
    }

    func completePhotoMove(to destination: ShareDestination) {
        actions.onMovePhotos(selectedPhotoIDs, destination)
        isMoveSheetPresented = false
        exitSelectionMode()
    }

    func editSelectedPhotoInfo() {
        guard let firstPhotoID = selectedPhotoIDs.first else {
            return
        }

        onEditPhotoInfo(firstPhotoID)
    }

    func presentPhotoDeleteAlert() {
        guard hasSelectedPhotos else {
            return
        }

        isDeleteAlertPresented = true
    }

    func deleteSelectedPhotosPermanently() {
        completeSelectedPhotoDeletion(.deletePermanently)
    }

    func removeSelectedPhotosFromAlbum() {
        completeSelectedPhotoDeletion(.removeFromAlbum)
    }

    private func completeSelectedPhotoDeletion(_ action: PhotoDeletionAction) {
        actions.onDeletePhotos(selectedPhotoIDs, action)
        isDeleteAlertPresented = false
        exitSelectionMode()
    }
}
