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
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                let requestID = manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: contentMode,
                    options: options
                ) { image, _ in
                    box.finish { continuation.resume(returning: image) }
                }
                box.store(requestID)
            }
        } onCancel: {
            if let requestID = box.requestID() {
                manager.cancelImageRequest(requestID)
            }
        }
    }
}

private final class ImageRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequestID: PHImageRequestID?
    private var isFinished = false

    func store(_ id: PHImageRequestID) {
        lock.lock()
        defer { lock.unlock() }
        storedRequestID = id
    }

    func requestID() -> PHImageRequestID? {
        lock.lock()
        defer { lock.unlock() }
        return storedRequestID
    }

    func finish(_ resume: () -> Void) {
        lock.lock()
        if isFinished {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()
        resume()
    }
}
