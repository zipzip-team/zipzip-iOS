//
//  SharedPhotoLibraryService.swift
//  zipzip-iOS
//

import CoreLocation
import Foundation
@preconcurrency import Photos

nonisolated enum SharedPhotoLibraryError: Error {
    case creationPlaceholderMissing
    case createdAssetNotFound
}

nonisolated struct SharedPhotoLibraryService {
    func savePhoto(
        from fileURL: URL,
        creationDate: Date?,
        latitude: Double?,
        longitude: Double?
    ) async throws -> String {
        var createdLocalIdentifier: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: fileURL, options: nil)
            request.creationDate = creationDate
            if let latitude, let longitude {
                request.location = CLLocation(latitude: latitude, longitude: longitude)
            }
            createdLocalIdentifier = request.placeholderForCreatedAsset?.localIdentifier
        }

        guard let createdLocalIdentifier else {
            throw SharedPhotoLibraryError.creationPlaceholderMissing
        }
        try await PhotoLibrarySyncService().sync(localIdentifiers: [createdLocalIdentifier])
        let createdAsset = PHAsset.fetchAssets(withLocalIdentifiers: [createdLocalIdentifier], options: nil)
        guard createdAsset.firstObject != nil else {
            throw SharedPhotoLibraryError.createdAssetNotFound
        }
        return createdLocalIdentifier
    }

    func deletePhotos(localIdentifiers: [String]) async throws {
        try await PhotoDeletionService().delete(localIdentifiers: localIdentifiers)
    }
}
