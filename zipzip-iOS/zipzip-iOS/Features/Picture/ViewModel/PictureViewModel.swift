//
//  PictureViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import Foundation
import OSLog
import SQLiteData
import SwiftUI

@Observable
final class PictureViewModel {
    @ObservationIgnored
    @Fetch private var response: [PhotoSection]

    @ObservationIgnored
    private let deleteOperation: ([String]) async throws -> Void

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "PictureSections"
    )

    var isSelectionMode = false
    private(set) var selectedPhotoIDs: [UUID] = []
    var showDeleteAlert = false

    var sections: [PhotoSection] {
        response
    }

    init(
        filters: [AppliedFilter] = [],
        deleteOperation: @escaping ([String]) async throws -> Void = {
            try await PhotoDeletionService().delete(localIdentifiers: $0)
        }
    ) {
        _response = Fetch(wrappedValue: [], PhotoSectionsRequest(filters: filters))
        self.deleteOperation = deleteOperation
    }

    var firstSelectedMetadata: PhotoMetadata? {
        guard let firstID = selectedPhotoIDs.first else { return nil }
        return sections
            .flatMap(\.photos)
            .first { $0.id == firstID }?
            .metadata
    }

    var selectedPhotoLocalIdentifiers: [String] {
        sections.localIdentifiers(for: selectedPhotoIDs)
    }

    func enterSelectionMode() {
        isSelectionMode = true
    }

    func requestDelete() {
        showDeleteAlert = true
    }

    func deleteSelectedPhotos() async {
        await deleteSelectedPhotos(localIdentifiers: selectedPhotoLocalIdentifiers)
    }

    func deleteSelectedPhotos(localIdentifiers: [String]) async {
        guard await deletePhotos(localIdentifiers: localIdentifiers) else { return }
        cancelSelection()
    }

    @discardableResult
    func deletePhotos(localIdentifiers: [String]) async -> Bool {
        guard !localIdentifiers.isEmpty else { return false }
        do {
            try await deleteOperation(localIdentifiers)
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

    func applyFilters(_ filters: [AppliedFilter]) async {
        do {
            try await $response.load(PhotoSectionsRequest(filters: filters))
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
