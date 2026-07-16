//
//  SharedPhotoLibraryService.swift
//  zipzip-iOS
//

import CoreLocation
import Foundation
import ImageIO
@preconcurrency import Photos
import UniformTypeIdentifiers

nonisolated enum SharedPhotoLibraryError: Error {
    case creationPlaceholderMissing
    case createdAssetNotFound
}

nonisolated struct SharedPhotoLibraryService {
    func containsPhoto(localIdentifier: String) -> Bool {
        guard !localIdentifier.isEmpty else { return false }
        return PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject != nil
    }

    func savePhoto(
        from fileURL: URL,
        creationDate: Date?,
        latitude: Double?,
        longitude: Double?
    ) async throws -> String {
        var createdLocalIdentifier: String?
        let resourceOptions = resourceCreationOptions(for: fileURL)
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(
                with: .photo,
                fileURL: fileURL,
                options: resourceOptions
            )
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

    private func resourceCreationOptions(
        for fileURL: URL
    ) -> PHAssetResourceCreationOptions {
        let options = PHAssetResourceCreationOptions()
        var filename = fileURL.lastPathComponent

        if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
           let typeIdentifier = CGImageSourceGetType(imageSource) {
            let identifier = typeIdentifier as String
            options.uniformTypeIdentifier = identifier

            if fileURL.pathExtension.isEmpty,
               let pathExtension = UTType(identifier)?.preferredFilenameExtension {
                filename += ".\(pathExtension)"
            }
        }

        options.originalFilename = filename
        return options
    }

    func deletePhotos(localIdentifiers: [String]) async throws {
        try await PhotoDeletionService().delete(localIdentifiers: localIdentifiers)
    }
}
