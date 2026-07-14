//
//  PhotoLibrarySyncService.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
@preconcurrency import Photos
import SQLiteData

nonisolated struct SyncProgress: Equatable {
    let processed: Int
    let total: Int
}

nonisolated struct PhotoLibrarySyncService {
    @Dependency(\.defaultDatabase) private var database

    private static let chunkSize = 500
    private static let maxConcurrentMetadataReads = 8

    func syncIfNeeded() -> AsyncThrowingStream<SyncProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @concurrent
    private func run(
        _ continuation: AsyncThrowingStream<SyncProgress, Error>.Continuation
    ) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let savedToken = try await database.read { db in
            try Self.loadChangeToken(db)
        }
        if let savedToken {
            try await syncIncremental(since: savedToken, continuation)
        } else {
            try await importAll(continuation)
        }
    }

    @concurrent
    private func importAll(
        _ continuation: AsyncThrowingStream<SyncProgress, Error>.Continuation
    ) async throws {
        let baselineToken = PHPhotoLibrary.shared().currentChangeToken

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        let total = fetchResult.count
        let scanDate = Date()

        var deviceCache: [DeviceKey: Int] = [:]
        var fetchedIdentifiers: Set<String> = []
        var processed = 0
        while processed < total {
            try Task.checkCancellation()
            let upperBound = min(processed + Self.chunkSize, total)
            let assets = autoreleasepool {
                fetchResult.objects(at: IndexSet(integersIn: processed ..< upperBound))
            }
            fetchedIdentifiers.formUnion(assets.map(\.localIdentifier))
            let chunk = await Self.loadMetadata(for: assets)
            try await persist(chunk, scanDate: scanDate, deviceCache: &deviceCache)
            processed = upperBound
            continuation.yield(SyncProgress(processed: processed, total: total))
        }

        // 전체 접근일 때만 fetch 결과가 라이브러리 전체를 대표한다.
        // 제한된 접근(.limited)에서는 fetch가 허용된 일부만 반환하므로 prune하면 안 된다.
        // 재임포트가 오래 걸리는 동안 권한이 축소될 수 있어, 삭제 직전 상태를 다시 확인한다.
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
            let existingIdentifiers = try await database.read { db in
                try PhotoRecord.select(\.localIdentifier).fetchAll(db)
            }
            try await deleteRecords(Array(Set(existingIdentifiers).subtracting(fetchedIdentifiers)))
        }

        try await database.write { db in
            try Self.saveChangeToken(baselineToken, db)
        }
    }

    @concurrent
    private func syncIncremental(
        since token: PHPersistentChangeToken,
        _ continuation: AsyncThrowingStream<SyncProgress, Error>.Continuation
    ) async throws {
        let library = PHPhotoLibrary.shared()
        let changes: PHPersistentChangeFetchResult
        do {
            changes = try library.fetchPersistentChanges(since: token)
        } catch let error as PHPhotosError where error.code == .persistentChangeTokenExpired {
            try await importAll(continuation)
            return
        }

        var changedIdentifiers: Set<String> = []
        var deletedIdentifiers: Set<String> = []
        var latestToken: PHPersistentChangeToken?
        do {
            for change in changes {
                try Task.checkCancellation()
                let details = try change.changeDetails(for: .asset)
                let changed = Set(details.insertedLocalIdentifiers)
                    .union(details.updatedLocalIdentifiers)
                changedIdentifiers.formUnion(changed)
                deletedIdentifiers.subtract(changed)
                changedIdentifiers.subtract(details.deletedLocalIdentifiers)
                deletedIdentifiers.formUnion(details.deletedLocalIdentifiers)
                latestToken = change.changeToken
            }
        } catch let error as PHPhotosError where error.code == .persistentChangeDetailsUnavailable {
            try await importAll(continuation)
            return
        }

        if !deletedIdentifiers.isEmpty {
            try await deleteRecords(Array(deletedIdentifiers))
        }

        if !changedIdentifiers.isEmpty {
            try await applyChanges(Array(changedIdentifiers), continuation)
        }

        if let latestToken {
            try await database.write { db in
                try Self.saveChangeToken(latestToken, db)
            }
        }
    }

    private func applyChanges(
        _ identifiers: [String],
        _ continuation: AsyncThrowingStream<SyncProgress, Error>.Continuation
    ) async throws {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image else { return }
            assets.append(asset)
        }
        guard !assets.isEmpty else { return }

        let scanDate = Date()
        let total = assets.count
        var deviceCache: [DeviceKey: Int] = [:]
        var processed = 0
        while processed < total {
            try Task.checkCancellation()
            let upperBound = min(processed + Self.chunkSize, total)
            let slice = Array(assets[processed ..< upperBound])
            let chunk = await Self.loadMetadata(for: slice)
            try await persist(chunk, scanDate: scanDate, deviceCache: &deviceCache)
            processed = upperBound
            continuation.yield(SyncProgress(processed: processed, total: total))
        }
    }

    private func deleteRecords(_ identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        try await database.write { db in
            var index = 0
            while index < identifiers.count {
                let upperBound = min(index + Self.chunkSize, identifiers.count)
                let slice = Array(identifiers[index ..< upperBound])
                try PhotoRecord
                    .delete()
                    .where { $0.localIdentifier.in(slice) }
                    .execute(db)
                index = upperBound
            }
        }
    }

    private func persist(
        _ chunk: [AssetMetadata],
        scanDate: Date,
        deviceCache: inout [DeviceKey: Int]
    ) async throws {
        let neededKeys = Set(chunk.compactMap(Self.deviceKey)).subtracting(deviceCache.keys)
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

        let entries: [(AssetMetadata, Int?)] = chunk.compactMap { metadata in
            if metadata.devicePending { return (metadata, nil) }
            guard let key = Self.deviceKey(for: metadata),
                  let deviceID = deviceCache[key]
            else { return nil }
            return (metadata, deviceID)
        }

        try await database.write { db in
            for (metadata, deviceID) in entries {
                try Self.upsert(metadata, deviceID: deviceID, addedAt: scanDate, db: db)
            }
        }
    }

    private static func loadMetadata(for assets: [PHAsset]) async -> [AssetMetadata] {
        await withTaskGroup(of: (Int, AssetMetadata).self) { group in
            var results = [AssetMetadata?](repeating: nil, count: assets.count)
            var next = 0

            func addTask(at index: Int) {
                let asset = assets[index]
                group.addTask { (index, await AssetMetadata.load(from: asset)) }
            }

            while next < min(maxConcurrentMetadataReads, assets.count) {
                addTask(at: next)
                next += 1
            }
            while let (index, metadata) = await group.next() {
                results[index] = metadata
                if next < assets.count {
                    addTask(at: next)
                    next += 1
                }
            }
            return results.compactMap { $0 }
        }
    }

    private static func upsert(
        _ metadata: AssetMetadata,
        deviceID: Int?,
        addedAt: Date,
        db: Database
    ) throws {
        try PhotoRecord.insert {
            PhotoRecord.Draft(
                localIdentifier: metadata.localIdentifier,
                takenAt: metadata.creationDate,
                addedAt: addedAt,
                addedDate: metadata.addedDate,
                isFavorite: metadata.isFavorite,
                latitude: metadata.latitude,
                longitude: metadata.longitude,
                width: metadata.width,
                height: metadata.height,
                deviceID: deviceID
            )
        } onConflict: {
            $0.localIdentifier
        } doUpdate: { updates, excluded in
            updates.takenAt = excluded.takenAt
            updates.addedDate = excluded.addedDate
            updates.isFavorite = excluded.isFavorite
            updates.latitude = excluded.latitude
            updates.longitude = excluded.longitude
            updates.width = excluded.width
            updates.height = excluded.height
            updates.deviceID = excluded.deviceID
        }
        .execute(db)
    }

    // MARK: - Device Resolution

    private struct DeviceKey: Hashable {
        let make: String?
        let model: String?
    }

    private static func deviceKey(for metadata: AssetMetadata) -> DeviceKey? {
        if metadata.make == nil, metadata.model == nil { return nil }
        return DeviceKey(make: metadata.make, model: metadata.model)
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

    private static func loadChangeToken(_ db: Database) throws -> PHPersistentChangeToken? {
        let stored = try SyncStateRecord
            .where { $0.id.eq(1) }
            .select(\.changeToken)
            .fetchOne(db)
        guard let base64 = stored ?? nil,
              let data = Data(base64Encoded: base64)
        else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: PHPersistentChangeToken.self,
            from: data
        )
    }

    private static func saveChangeToken(_ token: PHPersistentChangeToken, _ db: Database) throws {
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        )
        try SyncStateRecord.upsert {
            SyncStateRecord.Draft(id: 1, changeToken: data.base64EncodedString())
        }
        .execute(db)
    }
}

private enum PhotoLibrarySyncServiceKey: DependencyKey {
    static let liveValue = PhotoLibrarySyncService()
}

extension DependencyValues {
    var photoLibrarySync: PhotoLibrarySyncService {
        get { self[PhotoLibrarySyncServiceKey.self] }
        set { self[PhotoLibrarySyncServiceKey.self] = newValue }
    }
}
