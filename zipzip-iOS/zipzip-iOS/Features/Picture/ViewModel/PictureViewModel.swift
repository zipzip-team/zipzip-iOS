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

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PictureSections")

    @ObservationIgnored private var library: [FilterablePhoto]?
    @ObservationIgnored private var registeredDeviceIDs: Set<Int>?

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

    var selectedPhotoLocalIdentifiers: [String] {
        let photosByID = Dictionary(uniqueKeysWithValues: sections.flatMap(\.photos).map { ($0.id, $0) })
        return selectedPhotoIDs.compactMap { photoID in
            guard let localIdentifier = photosByID[photoID]?.localIdentifier,
                  !localIdentifier.isEmpty
            else {
                return nil
            }
            return localIdentifier
        }
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

    func loadPhotos(filters: [AppliedFilter] = []) async {
        do {
            let library: [FilterablePhoto]
            let registeredIDs: Set<Int>
            if let cachedLibrary = self.library, let cachedIDs = registeredDeviceIDs {
                library = cachedLibrary
                registeredIDs = cachedIDs
            } else {
                library = try await provider.loadLibrary()
                registeredIDs = try await provider.loadRegisteredDeviceIDs()
                self.library = library
                registeredDeviceIDs = registeredIDs
            }
            sections = await provider.sections(
                from: library,
                filters: filters,
                registeredDeviceIDs: registeredIDs
            )
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
