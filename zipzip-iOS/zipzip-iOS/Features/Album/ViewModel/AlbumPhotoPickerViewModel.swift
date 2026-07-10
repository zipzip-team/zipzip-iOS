//
//  AlbumPhotoPickerViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

@Observable
final class AlbumPhotoPickerViewModel {
    let sections: [PhotoSection]
    private(set) var selectedPhotoIDs: [UUID]

    private let onComplete: ([UUID]) -> Void

    init(
        sections: [PhotoSection],
        selectedPhotoIDs: [UUID] = [],
        onComplete: @escaping ([UUID]) -> Void
    ) {
        self.sections = sections
        self.selectedPhotoIDs = selectedPhotoIDs
        self.onComplete = onComplete
    }

    var isCompletionDisabled: Bool {
        selectedPhotoIDs.isEmpty
    }

    func toggleSelection(_ id: UUID) {
        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }

    func completeSelection() {
        guard !isCompletionDisabled else {
            return
        }

        onComplete(selectedPhotoIDs)
    }
}
