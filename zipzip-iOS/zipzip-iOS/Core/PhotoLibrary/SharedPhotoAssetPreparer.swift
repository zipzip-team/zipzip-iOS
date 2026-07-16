//
//  SharedPhotoAssetPreparer.swift
//  zipzip-iOS
//

import CoreLocation
import Foundation
import ImageIO
@preconcurrency import Photos
import UniformTypeIdentifiers

nonisolated struct PreparedSharedPhotoAsset {
    let localIdentifier: String
    let fileURL: URL
    let contentType: String
    let sizeBytes: Int
    let deviceModel: String?
    let takenAt: Date?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isInferred: Bool
    let width: Int
    let height: Int

    func withLocationName(_ locationName: String) -> Self {
        Self(
            localIdentifier: localIdentifier,
            fileURL: fileURL,
            contentType: contentType,
            sizeBytes: sizeBytes,
            deviceModel: deviceModel,
            takenAt: takenAt,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            isInferred: isInferred,
            width: width,
            height: height
        )
    }
}

nonisolated enum SharedPhotoAssetPreparationError: LocalizedError {
    case assetNotFound
    case photoResourceNotFound
    case sourceReadFailed
    case jpegEncodingFailed
    case exceedsUploadLimit

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            "사진 앱에서 원본 사진을 찾지 못했어요."
        case .photoResourceNotFound, .sourceReadFailed:
            "사진 원본을 불러오지 못했어요."
        case .jpegEncodingFailed:
            "사진을 업로드 형식으로 변환하지 못했어요."
        case .exceedsUploadLimit:
            "압축 후에도 사진 크기가 20MB를 초과해요."
        }
    }
}

/// 공유 사진 업로드 전용 변환기다. Live Photo의 동영상 리소스는 사용하지 않는다.
nonisolated struct SharedPhotoAssetPreparer {
    static let maximumUploadBytes = 20 * 1024 * 1024
    static let minimumJPEGQuality = 0.7

    /// PhotoKit 원본 조회와 JPEG 인코딩이 호출자의 actor(MainActor)를 점유하지 않도록 한다.
    @concurrent
    func prepare(localIdentifier: String) async throws -> PreparedSharedPhotoAsset {
        try Task.checkCancellation()
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject, asset.mediaType == .image else {
            throw SharedPhotoAssetPreparationError.assetNotFound
        }
        guard let resource = Self.preferredPhotoResource(for: asset) else {
            throw SharedPhotoAssetPreparationError.photoResourceNotFound
        }

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("shared-photo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        do {
            let sourceURL = workDirectory.appendingPathComponent("source")
            try await Self.write(resource: resource, to: sourceURL)
            try Task.checkCancellation()

            let jpegURL = try Self.encodeJPEG(
                sourceURL: sourceURL,
                directory: workDirectory,
                maximumBytes: Self.maximumUploadBytes,
                minimumQuality: Self.minimumJPEGQuality
            )
            try? FileManager.default.removeItem(at: sourceURL)
            let size = try Self.fileSize(at: jpegURL)
            let deviceModel: String?
            switch await AssetEXIFReader.deviceInfo(for: asset, allowsNetwork: true) {
            case let .resolved(_, model):
                deviceModel = model
            case .pending:
                deviceModel = nil
            }

            return PreparedSharedPhotoAsset(
                localIdentifier: localIdentifier,
                fileURL: jpegURL,
                contentType: UTType.jpeg.preferredMIMEType ?? "image/jpeg",
                sizeBytes: size,
                deviceModel: deviceModel,
                takenAt: asset.creationDate,
                latitude: asset.location?.coordinate.latitude,
                longitude: asset.location?.coordinate.longitude,
                locationName: nil,
                isInferred: false,
                width: asset.pixelWidth,
                height: asset.pixelHeight
            )
        } catch {
            try? FileManager.default.removeItem(at: workDirectory)
            throw error
        }
    }

    func removePreparedFile(_ asset: PreparedSharedPhotoAsset) {
        try? FileManager.default.removeItem(at: asset.fileURL.deletingLastPathComponent())
    }

    private static func preferredPhotoResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        for type in [PHAssetResourceType.fullSizePhoto, .photo, .alternatePhoto] {
            if let resource = resources.first(where: { $0.type == type }) {
                return resource
            }
        }
        return nil
    }

    private static func write(resource: PHAssetResource, to url: URL) async throws {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let manager = PHAssetResourceManager.default()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            manager.writeData(for: resource, toFile: url, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func encodeJPEG(
        sourceURL: URL,
        directory: URL,
        maximumBytes: Int,
        minimumQuality: Double
    ) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary),
            let image = CGImageSourceCreateImageAtIndex(source, 0, [
                kCGImageSourceShouldCacheImmediately: false
            ] as CFDictionary)
        else {
            throw SharedPhotoAssetPreparationError.sourceReadFailed
        }

        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        func encoded(quality: Double, name: String) throws -> URL {
            let url = directory.appendingPathComponent(name).appendingPathExtension("jpg")
            try? FileManager.default.removeItem(at: url)
            guard let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                throw SharedPhotoAssetPreparationError.jpegEncodingFailed
            }
            var properties = sourceProperties
            properties[kCGImageDestinationLossyCompressionQuality] = quality
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw SharedPhotoAssetPreparationError.jpegEncodingFailed
            }
            return url
        }

        let fullQualityURL = try encoded(quality: 1, name: "upload-1")
        if try fileSize(at: fullQualityURL) <= maximumBytes {
            return fullQualityURL
        }
        try? FileManager.default.removeItem(at: fullQualityURL)

        var bestURL = try encoded(quality: minimumQuality, name: "upload-min")
        guard try fileSize(at: bestURL) <= maximumBytes else {
            try? FileManager.default.removeItem(at: bestURL)
            throw SharedPhotoAssetPreparationError.exceedsUploadLimit
        }

        var lower = minimumQuality
        var upper = 1.0
        for index in 0 ..< 7 {
            let quality = (lower + upper) / 2
            let candidate = try encoded(quality: quality, name: "upload-\(index)")
            if try fileSize(at: candidate) <= maximumBytes {
                try? FileManager.default.removeItem(at: bestURL)
                bestURL = candidate
                lower = quality
            } else {
                try? FileManager.default.removeItem(at: candidate)
                upper = quality
            }
        }
        return bestURL
    }

    private static func fileSize(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw SharedPhotoAssetPreparationError.sourceReadFailed
        }
        return size.intValue
    }
}
