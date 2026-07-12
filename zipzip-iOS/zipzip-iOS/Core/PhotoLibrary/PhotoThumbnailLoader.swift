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
        return Task.isCancelled ? nil : image
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
