//
//  DeviceBackfillService.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/12/26.
//

import Foundation
import OSLog
@preconcurrency import Photos
import SQLiteData

private let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "DeviceBackfill")

nonisolated struct DeviceBackfillService {
    @Dependency(\.defaultDatabase) private var database

    private static let batchSize = 100
    private static let maxConcurrent = 4
    private static let maxConsecutiveEmptyBatches = 3

    @concurrent
    func backfillPendingDevices(onProgress: @Sendable (SyncProgress) -> Void = { _ in }) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let pending = try await database.read { db in
            try PhotoRecord
                .where { $0.devicePending.eq(true) }
                .select { ($0.id, $0.localIdentifier) }
                .fetchAll(db)
        }
        guard !pending.isEmpty else { return }

        let total = pending.count
        onProgress(SyncProgress(processed: 0, total: total))

        var deviceCache: [DeviceKey: Int] = [:]
        var emptyBatches = 0

        for start in stride(from: 0, to: pending.count, by: Self.batchSize) {
            try Task.checkCancellation()
            let batchEnd = min(start + Self.batchSize, pending.count)
            let batch = Array(pending[start ..< batchEnd])
            let results = await Self.resolve(batch)

            let neededKeys = Set(results.compactMap(Self.deviceKey)).subtracting(deviceCache.keys)
            if !neededKeys.isEmpty {
                let resolved = try await database.write { db in
                    var map: [DeviceKey: Int] = [:]
                    for key in neededKeys {
                        map[key] = try Self.deviceID(for: key, db: db)
                    }
                    return map
                }
                deviceCache.merge(resolved) { current, _ in current }
            }

            let cache = deviceCache
            let resolvedCount = try await database.write { db in
                var count = 0
                for (photoID, info) in results {
                    // .pending(원본 다운로드 실패)은 device_pending을 유지해 다음 실행에 재시도한다.
                    guard case let .resolved(make, model) = info else { continue }
                    let deviceID: Int? = (make != nil || model != nil)
                        ? cache[DeviceKey(make: make, model: model)]
                        : nil
                    try PhotoRecord
                        .update {
                            $0.deviceID = #bind(deviceID)
                            $0.devicePending = false
                        }
                        .where { $0.id.eq(photoID) }
                        .execute(db)
                    count += 1
                }
                return count
            }

            onProgress(SyncProgress(processed: batchEnd, total: total))

            if resolvedCount == 0 {
                emptyBatches += 1
                if emptyBatches >= Self.maxConsecutiveEmptyBatches {
                    logger.info("device backfill backing off after repeated failures")
                    return
                }
            } else {
                emptyBatches = 0
            }
        }
    }

    private static func resolve(_ batch: [(Int, String)]) async -> [(Int, AssetDeviceInfo)] {
        let assetsByID = fetchAssets(for: batch.map(\.1))
        var results: [(Int, AssetDeviceInfo)] = []
        results.reserveCapacity(batch.count)

        for start in stride(from: 0, to: batch.count, by: maxConcurrent) {
            let group = batch[start ..< min(start + maxConcurrent, batch.count)]
            let resolved = await withTaskGroup(of: (Int, AssetDeviceInfo).self) { taskGroup in
                for (photoID, localID) in group {
                    guard let asset = assetsByID[localID] else { continue }
                    taskGroup.addTask {
                        (photoID, await AssetEXIFReader.deviceInfo(for: asset, allowsNetwork: true))
                    }
                }
                var partial: [(Int, AssetDeviceInfo)] = []
                for await result in taskGroup {
                    partial.append(result)
                }
                return partial
            }
            results.append(contentsOf: resolved)
            for (photoID, localID) in group where assetsByID[localID] == nil {
                results.append((photoID, .pending))
            }
        }
        return results
    }

    private static func fetchAssets(for identifiers: [String]) -> [String: PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var map: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in map[asset.localIdentifier] = asset }
        return map
    }

    private struct DeviceKey: Hashable {
        let make: String?
        let model: String?
    }

    private static func deviceKey(for result: (Int, AssetDeviceInfo)) -> DeviceKey? {
        guard case let .resolved(make, model) = result.1 else { return nil }
        return DeviceKey(make: make, model: model)
    }

    private static func deviceID(for key: DeviceKey, db: Database) throws -> Int {
        let existing = try DeviceRecord
            .where { $0.make.is(key.make) && $0.model.is(key.model) }
            .fetchOne(db)
        if let existing {
            return existing.id
        }
        try DeviceRecord.insert {
            DeviceRecord.Draft(make: key.make, model: key.model)
        }
        .execute(db)
        return Int(db.lastInsertedRowID)
    }
}

private enum DeviceBackfillServiceKey: DependencyKey {
    static let liveValue = DeviceBackfillService()
}

extension DependencyValues {
    var deviceBackfill: DeviceBackfillService {
        get { self[DeviceBackfillServiceKey.self] }
        set { self[DeviceBackfillServiceKey.self] = newValue }
    }
}
