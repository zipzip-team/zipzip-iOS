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
    private(set) var isCompleting = false

    private let onComplete: ([String]) async -> Bool

    init(
        sections: [PhotoSection] = [],
        selectedPhotoIDs: [UUID] = [],
        onComplete: @escaping ([String]) async -> Bool
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
        selectedPhotoIDs.isEmpty || isCompleting
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

    func completeSelection() async -> Bool {
        guard !isCompletionDisabled else {
            return false
        }

        isCompleting = true
        defer { isCompleting = false }
        return await onComplete(selectedPhotoLocalIdentifiers)
    }
}
