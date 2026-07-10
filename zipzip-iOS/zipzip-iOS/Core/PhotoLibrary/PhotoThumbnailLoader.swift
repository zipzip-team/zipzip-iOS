//
//  PhotoThumbnailLoader.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

@preconcurrency import Photos
import UIKit

final class PhotoThumbnailLoader: @unchecked Sendable {
    static let shared = PhotoThumbnailLoader()

    private let manager = PHCachingImageManager()

    func thumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        await requestImage(for: localIdentifier, targetSize: targetSize, contentMode: .aspectFill)
    }

    func fullImage(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        await requestImage(for: localIdentifier, targetSize: targetSize, contentMode: .aspectFit)
    }

    private func requestImage(
        for localIdentifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode
    ) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
