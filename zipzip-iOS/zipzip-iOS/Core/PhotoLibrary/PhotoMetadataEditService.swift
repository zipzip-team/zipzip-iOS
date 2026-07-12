//
//  PhotoMetadataEditService.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/13/26.
//

import CoreLocation
import ImageIO
import OSLog
@preconcurrency import Photos
import SQLiteData

private let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PhotoMetadataEdit")

nonisolated struct PhotoMetadataEditService {
    @Dependency(\.defaultDatabase) private var database

    func updateDate(localIdentifiers: [String], date: Date) async throws {
        guard !localIdentifiers.isEmpty else { return }

        let assets = Self.fetchAssets(localIdentifiers)
        if !assets.isEmpty {
            try await PHPhotoLibrary.shared().performChanges {
                for asset in assets {
                    PHAssetChangeRequest(for: asset).creationDate = date
                }
            }
        }

        try await database.write { db in
            try PhotoRecord
                .update { $0.takenAt = #bind(date) }
                .where { $0.localIdentifier.in(localIdentifiers) }
                .execute(db)
        }
    }

    func updateLocation(
        localIdentifiers: [String],
        name: String,
        latitude: Double?,
        longitude: Double?
    ) async throws {
        guard !localIdentifiers.isEmpty else { return }

        guard let coordinate = try await resolveCoordinate(name: name, latitude: latitude, longitude: longitude) else {
            logger.error("location edit: coordinate unresolved, skipping \(name)")
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let assets = Self.fetchAssets(localIdentifiers)
        if !assets.isEmpty {
            try await PHPhotoLibrary.shared().performChanges {
                for asset in assets {
                    PHAssetChangeRequest(for: asset).location = location
                }
            }
        }

        try await database.write { db in
            let placeID = try Self.findOrCreatePlace(
                name: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                db: db
            )
            try PhotoRecord
                .update {
                    $0.placeID = #bind(placeID)
                    $0.latitude = #bind(coordinate.latitude)
                    $0.longitude = #bind(coordinate.longitude)
                }
                .where { $0.localIdentifier.in(localIdentifiers) }
                .execute(db)
        }
    }

    @discardableResult
    func updateDevice(
        localIdentifiers: [String],
        deviceID: Int,
        make: String?,
        model: String?
    ) async throws -> [String: String] {
        guard !localIdentifiers.isEmpty else { return [:] }

        var replacements: [AssetReplacement] = []
        for localIdentifier in localIdentifiers {
            guard let asset = Self.fetchAssets([localIdentifier]).first else { continue }
            guard let (data, uti) = await Self.requestCurrentImageData(asset) else {
                logger.error("device edit: current image data unavailable")
                continue
            }
            guard let modified = Self.rewriteDeviceMetadata(data, uti: uti, make: make, model: model) else {
                logger.error("device edit: metadata rewrite failed")
                continue
            }
            replacements.append(AssetReplacement(
                localIdentifier: localIdentifier,
                asset: asset,
                data: modified,
                uti: uti
            ))
        }
        guard !replacements.isEmpty else { return [:] }

        try await PHPhotoLibrary.shared().performChanges {
            for replacement in replacements {
                let creation = PHAssetCreationRequest.forAsset()
                let resourceOptions = PHAssetResourceCreationOptions()
                resourceOptions.uniformTypeIdentifier = replacement.uti
                creation.addResource(with: .photo, data: replacement.data, options: resourceOptions)
                creation.creationDate = replacement.asset.creationDate
                creation.location = replacement.asset.location
                creation.isFavorite = replacement.asset.isFavorite
                replacement.placeholder.identifier = creation.placeholderForCreatedAsset?.localIdentifier
            }
            PHAssetChangeRequest.deleteAssets(replacements.map(\.asset) as NSArray)
        }

        return try await database.write { db in
            var mapping: [String: String] = [:]
            for replacement in replacements {
                guard let newLocalIdentifier = replacement.placeholder.identifier else { continue }
                try PhotoRecord
                    .update {
                        $0.localIdentifier = #bind(newLocalIdentifier)
                        $0.deviceID = #bind(deviceID)
                    }
                    .where { $0.localIdentifier.eq(replacement.localIdentifier) }
                    .execute(db)
                mapping[replacement.localIdentifier] = newLocalIdentifier
            }
            return mapping
        }
    }

    private func resolveCoordinate(
        name: String,
        latitude: Double?,
        longitude: Double?
    ) async throws -> CLLocationCoordinate2D? {
        if let latitude, let longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return try await database.read { db in
            try PlaceRecord
                .where { $0.name.eq(name) }
                .fetchOne(db)
                .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
    }

    private static func fetchAssets(_ localIdentifiers: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    private static func findOrCreatePlace(
        name: String,
        latitude: Double,
        longitude: Double,
        db: Database
    ) throws -> Int {
        if let existing = try PlaceRecord.where({ $0.name.eq(name) }).fetchOne(db) {
            return existing.id
        }
        try PlaceRecord.insert {
            PlaceRecord.Draft(name: name, latitude: latitude, longitude: longitude)
        }
        .execute(db)
        return Int(db.lastInsertedRowID)
    }

    private static func requestCurrentImageData(_ asset: PHAsset) async -> (Data, String)? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .highQualityFormat

        return await withCheckedContinuation { (continuation: CheckedContinuation<(Data, String)?, Never>) in
            let box = ResumeOnceBox()
            PHImageManager.default()
                .requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                    box.run {
                        if let data, let uti {
                            continuation.resume(returning: (data, uti))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
        }
    }

    private static func rewriteDeviceMetadata(_ data: Data, uti: String, make: String?, model: String?) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let mutableMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil)
            .flatMap { CGImageMetadataCreateMutableCopy($0) }
            ?? CGImageMetadataCreateMutable()
        CGImageMetadataSetValueMatchingImageProperty(
            mutableMetadata,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyTIFFMake,
            (make ?? "") as CFString
        )
        CGImageMetadataSetValueMatchingImageProperty(
            mutableMetadata,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyTIFFModel,
            (model ?? "") as CFString
        )

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, uti as CFString, 1, nil)
        else {
            return nil
        }
        let copyOptions = [
            kCGImageDestinationMetadata: mutableMetadata,
            kCGImageDestinationMergeMetadata: kCFBooleanTrue as Any
        ] as CFDictionary
        guard CGImageDestinationCopyImageSource(destination, source, copyOptions, nil) else { return nil }
        return output as Data
    }
}

private struct AssetReplacement: @unchecked Sendable {
    let localIdentifier: String
    let asset: PHAsset
    let data: Data
    let uti: String
    let placeholder = PlaceholderBox()
}

private final class ResumeOnceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var isDone = false

    func run(_ block: () -> Void) {
        lock.lock()
        if isDone {
            lock.unlock()
            return
        }
        isDone = true
        lock.unlock()
        block()
    }
}

private final class PlaceholderBox: @unchecked Sendable {
    var identifier: String?
}

private enum PhotoMetadataEditServiceKey: DependencyKey {
    static let liveValue = PhotoMetadataEditService()
}

extension DependencyValues {
    var photoMetadataEdit: PhotoMetadataEditService {
        get { self[PhotoMetadataEditServiceKey.self] }
        set { self[PhotoMetadataEditServiceKey.self] = newValue }
    }
}
