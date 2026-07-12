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
    @Fetch private var response: [PhotoSection]

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PictureSections")

    var isSelectionMode = false
    private(set) var selectedPhotoIDs: [UUID] = []
    var showDeleteAlert = false

    var sections: [PhotoSection] {
        response
    }

    init(filters: [AppliedFilter] = []) {
        _response = Fetch(wrappedValue: [], PhotoSectionsRequest(filters: filters))
    }

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
