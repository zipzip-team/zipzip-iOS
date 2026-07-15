//
//  AlbumDetailViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

struct AlbumDetailActions {
    let onRename: (String) async -> Bool
    let onDelete: () async -> Bool
    let onAddPhotos: ([String]) async -> Bool
    let onDeletePhotos: ([UUID], PhotoDeletionAction) async -> Bool
    let onMovePhotos: ([UUID], [ShareDestination]) async -> Bool

    init(
        onRename: @escaping (String) async -> Bool = { _ in true },
        onDelete: @escaping () async -> Bool = { true },
        onAddPhotos: @escaping ([String]) async -> Bool = { _ in true },
        onDeletePhotos: @escaping ([UUID], PhotoDeletionAction) async -> Bool = { _, _ in true },
        onMovePhotos: @escaping ([UUID], [ShareDestination]) async -> Bool = { _, _ in true }
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
    var isErrorAlertPresented = false
    private(set) var errorAlertMessage = ""
    var albumTitleDraft = ""
    private(set) var isUpdatingAlbum = false
    private(set) var isDeletingAlbum = false

    private(set) var selectedPhotoIDs: [UUID] = []
    private var shouldPresentAlbumDeleteAlertAfterManagementDismissal = false

    private let actions: AlbumDetailActions
    private let onEditPhotoInfo: ([UUID], @escaping () -> Void) -> Void

    init(
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        onEditPhotoInfo: @escaping ([UUID], @escaping () -> Void) -> Void = { _, _ in }
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

    func addPhotos(_ localIdentifiers: [String]) async -> Bool {
        guard await actions.onAddPhotos(localIdentifiers) else {
            presentError("사진을 추가하지 못했어요.")
            return false
        }
        return true
    }

    func presentAlbumManagement(albumTitle: String) {
        exitSelectionMode()
        albumTitleDraft = albumTitle
        shouldPresentAlbumDeleteAlertAfterManagementDismissal = false
        isAlbumManagementPresented = true
    }

    func dismissAlbumManagement() {
        guard !isUpdatingAlbum else { return }
        isAlbumManagementPresented = false
    }

    func completeAlbumManagement() async {
        let trimmedTitle = albumTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !isUpdatingAlbum else {
            return
        }

        isUpdatingAlbum = true
        defer { isUpdatingAlbum = false }
        guard await actions.onRename(trimmedTitle) else {
            presentError("사진집 이름을 변경하지 못했어요.")
            return
        }
        isAlbumManagementPresented = false
    }

    func presentAlbumDeleteAlert() {
        shouldPresentAlbumDeleteAlertAfterManagementDismissal = true
        isAlbumManagementPresented = false
    }

    func dismissAlbumDeleteAlert() {
        isAlbumDeleteAlertPresented = false
    }

    func confirmAlbumDeletion() async {
        guard !isDeletingAlbum else { return }
        isDeletingAlbum = true
        defer { isDeletingAlbum = false }
        guard await actions.onDelete() else {
            presentError("사진집을 삭제하지 못했어요.")
            return
        }
        isAlbumDeleteAlertPresented = false
        isAlbumManagementPresented = false
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

    func completePhotoMove(to destinations: [ShareDestination]) async {
        guard await actions.onMovePhotos(selectedPhotoIDs, destinations) else {
            presentError("사진을 이동하지 못했어요.")
            return
        }
        isMoveSheetPresented = false
        exitSelectionMode()
    }

    func editSelectedPhotoInfo() {
        guard !selectedPhotoIDs.isEmpty else {
            return
        }

        onEditPhotoInfo(selectedPhotoIDs) { [weak self] in
            self?.exitSelectionMode()
        }
    }

    func presentPhotoDeleteAlert() {
        guard hasSelectedPhotos else {
            return
        }

        isDeleteAlertPresented = true
    }

    func deleteSelectedPhotosPermanently() async {
        await completeSelectedPhotoDeletion(.deletePermanently)
    }

    func removeSelectedPhotosFromAlbum() async {
        await completeSelectedPhotoDeletion(.removeFromAlbum)
    }

    func dismissErrorAlert() {
        isErrorAlertPresented = false
        errorAlertMessage = ""
    }

    private func completeSelectedPhotoDeletion(_ action: PhotoDeletionAction) async {
        guard await actions.onDeletePhotos(selectedPhotoIDs, action) else {
            isDeleteAlertPresented = false
            presentError("사진을 삭제하지 못했어요.")
            return
        }
        isDeleteAlertPresented = false
        exitSelectionMode()
    }

    private func presentError(_ message: String) {
        errorAlertMessage = message
        isErrorAlertPresented = true
    }
}
