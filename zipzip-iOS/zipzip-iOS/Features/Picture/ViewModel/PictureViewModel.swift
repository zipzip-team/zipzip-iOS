//
//  PictureViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import OSLog
import SQLiteData
import SwiftUI

@Observable
final class PictureViewModel {
    @ObservationIgnored
    @Dependency(\.photoSections) private var provider

    @ObservationIgnored
    @Dependency(\.photoDeletion) private var deletion

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PictureSections")

    @ObservationIgnored private var library: [FilterablePhoto]?

    var isSelectionMode = false
    private(set) var selectedPhotoIDs: [UUID] = []
    var showDeleteAlert = false

    private(set) var sections: [PhotoSection] = []

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

    private var selectedLocalIdentifiers: [String] {
        let ids = Set(selectedPhotoIDs)
        return sections
            .flatMap(\.photos)
            .filter { ids.contains($0.id) }
            .map(\.localIdentifier)
    }

    func deleteSelectedPhotos() async {
        await deletePhotos(localIdentifiers: selectedLocalIdentifiers)
        cancelSelection()
    }

    @discardableResult
    func deletePhotos(localIdentifiers: [String]) async -> Bool {
        guard !localIdentifiers.isEmpty else { return false }
        do {
            try await deletion.delete(localIdentifiers: localIdentifiers)
            library?.removeAll { localIdentifiers.contains($0.photo.localIdentifier) }
            sections = await provider.sections(from: library ?? [], filters: [])
            return true
        } catch {
            Self.logger.error("failed to delete photos: \(error)")
            return false
        }
    }

    func cancelSelection() {
        isSelectionMode = false
        selectedPhotoIDs = []
    }

    func loadPhotos(filters: [AppliedFilter] = []) async {
        do {
            let library: [FilterablePhoto]
            if let cached = self.library {
                library = cached
            } else {
                library = try await provider.loadLibrary()
                self.library = library
            }
            sections = await provider.sections(from: library, filters: filters)
        } catch {
            Self.logger.error("failed to load photo sections: \(error)")
        }
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
