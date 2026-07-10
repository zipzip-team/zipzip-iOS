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
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
