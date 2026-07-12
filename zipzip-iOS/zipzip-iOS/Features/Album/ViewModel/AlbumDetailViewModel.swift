//
//  AlbumDetailViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

struct AlbumDetailActions {
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onAddPhotos: ([String]) -> Void
    let onDeletePhotos: ([UUID], PhotoDeletionAction) -> Void
    let onMovePhotos: ([UUID], [ShareDestination]) -> Void

    init(
        onRename: @escaping (String) -> Void = { _ in },
        onDelete: @escaping () -> Void = {},
        onAddPhotos: @escaping ([String]) -> Void = { _ in },
        onDeletePhotos: @escaping ([UUID], PhotoDeletionAction) -> Void = { _, _ in },
        onMovePhotos: @escaping ([UUID], [ShareDestination]) -> Void = { _, _ in }
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
    private var shouldPresentAlbumDeleteAlertAfterManagementDismissal = false

    private let actions: AlbumDetailActions
    private let onEditPhotoInfo: ([UUID]) -> Void

    init(
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        onEditPhotoInfo: @escaping ([UUID]) -> Void = { _ in }
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

    func addPhotos(_ localIdentifiers: [String]) {
        actions.onAddPhotos(localIdentifiers)
    }

    func presentAlbumManagement(albumTitle: String) {
        exitSelectionMode()
        albumTitleDraft = albumTitle
        shouldPresentAlbumDeleteAlertAfterManagementDismissal = false
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
        shouldPresentAlbumDeleteAlertAfterManagementDismissal = true
        isAlbumManagementPresented = false
    }

    func dismissAlbumDeleteAlert() {
        isAlbumDeleteAlertPresented = false
    }

    func confirmAlbumDeletion() {
        isAlbumDeleteAlertPresented = false
        isAlbumManagementPresented = false
        actions.onDelete()
    }

    func completeAlbumManagementDismissal() {
        guard shouldPresentAlbumDeleteAlertAfterManagementDismissal else {
            return
        }

        shouldPresentAlbumDeleteAlertAfterManagementDismissal = false
        isAlbumDeleteAlertPresented = true
    }

    func presentMoveSheet() {
        guard hasSelectedPhotos else {
            return
        }

        isMoveSheetPresented = true
    }

    func completePhotoMove(to destinations: [ShareDestination]) {
        actions.onMovePhotos(selectedPhotoIDs, destinations)
        isMoveSheetPresented = false
        exitSelectionMode()
    }

    func editSelectedPhotoInfo() {
        guard !selectedPhotoIDs.isEmpty else {
            return
        }

        onEditPhotoInfo(selectedPhotoIDs)
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
