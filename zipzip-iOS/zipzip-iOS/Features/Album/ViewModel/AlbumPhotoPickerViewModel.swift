//
//  AlbumPhotoPickerViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation
import SQLiteData

@Observable
final class AlbumPhotoPickerViewModel {
    @ObservationIgnored
    @Dependency(\.photoSections) private var photoSectionsProvider

    private(set) var sections: [PhotoSection]
    private(set) var selectedPhotoIDs: [UUID]

    private let onComplete: ([String]) -> Void

    init(
        sections: [PhotoSection] = [],
        selectedPhotoIDs: [UUID] = [],
        onComplete: @escaping ([String]) -> Void
    ) {
        self.sections = sections
        self.selectedPhotoIDs = selectedPhotoIDs
        self.onComplete = onComplete
    }

    func loadPhotos() async {
        do {
            let library = try await photoSectionsProvider.loadLibrary()
            sections = await photoSectionsProvider.sections(from: library, filters: [])
        } catch {
            sections = []
        }
    }

    var isCompletionDisabled: Bool {
        selectedPhotoIDs.isEmpty
    }

    private var selectedPhotoLocalIdentifiers: [String] {
        sections.localIdentifiers(for: selectedPhotoIDs)
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

        onComplete(selectedPhotoLocalIdentifiers)
    }
}
