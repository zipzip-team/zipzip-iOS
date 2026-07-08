//
//  PictureViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

@Observable
final class PictureViewModel {
    var isSelectionMode = false
    private(set) var selectedPhotoIDs: [UUID] = []
    var showDeleteAlert = false

    let sections: [PhotoSection] = PhotoSection.sample

    var firstSelectedMetadata: PhotoMetadata? {
        guard let firstID = selectedPhotoIDs.first else { return nil }
        return sections
            .flatMap(\.photos)
            .first { $0.id == firstID }?
            .metadata
    }

    func enterSelectionMode() {
        isSelectionMode = true
    }

    func requestDelete() {
        showDeleteAlert = true
    }

    func cancelSelection() {
        isSelectionMode = false
        selectedPhotoIDs = []
    }

    func handleLongPress(_ id: UUID) {
        isSelectionMode = true
        if !selectedPhotoIDs.contains(id) {
            selectedPhotoIDs.append(id)
        }
    }

    func toggleSelection(_ id: UUID) {
        guard isSelectionMode else { return }
        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }
}
