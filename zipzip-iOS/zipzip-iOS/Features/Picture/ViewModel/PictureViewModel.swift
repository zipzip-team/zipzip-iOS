//
//  PictureViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import OSLog
import SQLiteData
import SwiftUI
import UIKit

@Observable
final class PictureViewModel {
    @ObservationIgnored
    @Fetch private var response: [PhotoSection]

    @ObservationIgnored
    @Dependency(\.photoDeletion) private var deletion

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PictureSections")

    @ObservationIgnored private var loadingThumbnailIdentifiers: Set<String> = []

    var isSelectionMode = false
    private(set) var selectedPhotoIDs: [UUID] = []
    var showDeleteAlert = false

    private(set) var thumbnailImages: [String: UIImage] = [:]

    private static let thumbnailSize = CGSize(width: 300, height: 300)

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
        await deletePhotos(localIdentifiers: selectedPhotoLocalIdentifiers)
        cancelSelection()
    }

    @discardableResult
    func deletePhotos(localIdentifiers: [String]) async -> Bool {
        guard !localIdentifiers.isEmpty else { return false }
        do {
            try await deletion.delete(localIdentifiers: localIdentifiers)
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

    func loadThumbnail(for localIdentifier: String) async {
        guard !localIdentifier.isEmpty,
              thumbnailImages[localIdentifier] == nil,
              !loadingThumbnailIdentifiers.contains(localIdentifier)
        else {
            return
        }

        loadingThumbnailIdentifiers.insert(localIdentifier)
        defer { loadingThumbnailIdentifiers.remove(localIdentifier) }

        let image = await PhotoThumbnailLoader.shared.thumbnail(
            for: localIdentifier,
            targetSize: Self.thumbnailSize
        )
        guard !Task.isCancelled, let image else { return }
        thumbnailImages[localIdentifier] = image
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
