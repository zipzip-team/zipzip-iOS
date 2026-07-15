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

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        return cache
    }()

    func thumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        await requestImage(for: localIdentifier, targetSize: targetSize, contentMode: .aspectFill)
    }

    func fastFullImage(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        await requestImage(
            for: localIdentifier,
            targetSize: targetSize,
            contentMode: .aspectFit,
            deliveryMode: .fastFormat
        )
    }

    func fullImage(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        await requestImage(for: localIdentifier, targetSize: targetSize, contentMode: .aspectFit)
    }

    private func requestImage(
        for localIdentifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat
    ) async -> UIImage? {
        let cacheKey =
            "\(localIdentifier)|\(Int(targetSize.width))x\(Int(targetSize.height))|\(contentMode.rawValue)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let box = ImageRequestBox()
        let image = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                let requestID = manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: contentMode,
                    options: options
                ) { image, _ in
                    box.finish { shouldReturnImage in
                        continuation.resume(returning: shouldReturnImage ? image : nil)
                    }
                }
                if box.store(requestID) {
                    manager.cancelImageRequest(requestID)
                }
            }
        } onCancel: {
            if let requestID = box.cancel() {
                manager.cancelImageRequest(requestID)
            }
        }
        guard !Task.isCancelled else { return nil }
        if let image {
            cache.setObject(image, forKey: cacheKey)
        }
        return image
    }
}

private final class ImageRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequestID: PHImageRequestID?
    private var isFinished = false
    private var isCancelled = false

    func store(_ id: PHImageRequestID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storedRequestID = id
        return isCancelled
    }

    func cancel() -> PHImageRequestID? {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        return storedRequestID
    }

    func finish(_ resume: (Bool) -> Void) {
        lock.lock()
        if isFinished {
            lock.unlock()
            return
        }
        isFinished = true
        let shouldReturnImage = !isCancelled
        lock.unlock()
        resume(shouldReturnImage)
    }
}
