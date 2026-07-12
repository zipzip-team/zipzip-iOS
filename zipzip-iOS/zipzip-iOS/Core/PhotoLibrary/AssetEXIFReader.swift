//
//  AssetEXIFReader.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import ImageIO
@preconcurrency import Photos

nonisolated enum AssetDeviceInfo: Equatable {
    case resolved(make: String?, model: String?)
    case pending
}

nonisolated enum AssetEXIFReader {
    private static let maxStreamedBytes = 2 * 1024 * 1024
    private static let minParseBytes = 128 * 1024

    static func deviceInfo(for asset: PHAsset, allowsNetwork: Bool) async -> AssetDeviceInfo {
        guard !asset.mediaSubtypes.contains(.photoScreenshot) else { return .resolved(make: nil, model: nil) }
        guard let resource = photoResource(for: asset) else { return .resolved(make: nil, model: nil) }
        return await streamDeviceInfo(from: resource, allowsNetwork: allowsNetwork)
    }

    private static func photoResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        let preferredTypes: [PHAssetResourceType] = [.photo, .fullSizePhoto, .alternatePhoto]
        for type in preferredTypes {
            if let match = resources.first(where: { $0.type == type }) { return match }
        }
        return nil
    }

    private static func streamDeviceInfo(
        from resource: PHAssetResource,
        allowsNetwork: Bool
    ) async -> AssetDeviceInfo {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = allowsNetwork

        let manager = PHAssetResourceManager.default()
        let box = ResourceStreamBox()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<AssetDeviceInfo, Never>) in
                let requestID = manager.requestData(
                    for: resource,
                    options: options,
                    dataReceivedHandler: { data in
                        guard !box.isDone() else { return }
                        box.append(data)
                        guard box.byteCount >= minParseBytes else { return }

                        if let info = parseDeviceInfo(from: box.buffer) {
                            box.finish {
                                if let id = box.requestID() { manager.cancelDataRequest(id) }
                                continuation.resume(returning: .resolved(make: info.make, model: info.model))
                            }
                        } else if box.byteCount >= maxStreamedBytes {
                            box.finish {
                                if let id = box.requestID() { manager.cancelDataRequest(id) }
                                continuation.resume(returning: .resolved(make: nil, model: nil))
                            }
                        }
                    },
                    completionHandler: { error in
                        box.finish {
                            if error != nil {
                                continuation.resume(returning: .pending)
                            } else {
                                let info = parseDeviceInfo(from: box.buffer)
                                continuation.resume(returning: .resolved(make: info?.make, model: info?.model))
                            }
                        }
                    }
                )
                box.store(requestID)
            }
        } onCancel: {
            if let id = box.requestID() { manager.cancelDataRequest(id) }
        }
    }

    private static func parseDeviceInfo(from data: Data) -> (make: String?, model: String?)? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        else { return nil }

        let make = cleaned(tiff[kCGImagePropertyTIFFMake] as? String)
        let model = cleaned(tiff[kCGImagePropertyTIFFModel] as? String)
        guard make != nil || model != nil else { return nil }
        return (make, model)
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}

private final class ResourceStreamBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var storedRequestID: PHAssetResourceDataRequestID?
    private var isFinished = false

    var buffer: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    var byteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return data.count
    }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
    }

    func store(_ id: PHAssetResourceDataRequestID) {
        lock.lock()
        defer { lock.unlock() }
        storedRequestID = id
    }

    func requestID() -> PHAssetResourceDataRequestID? {
        lock.lock()
        defer { lock.unlock() }
        return storedRequestID
    }

    func isDone() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isFinished
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
