//
//  PhotoLibrarySyncService.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import Photos
import SQLiteData

nonisolated struct SyncProgress {
    let processed: Int
    let total: Int
}

nonisolated struct PhotoLibrarySyncService {
    @Dependency(\.defaultDatabase) private var database

    private static let chunkSize = 500

    func syncIfNeeded() -> AsyncThrowingStream<SyncProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await importAll(continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @concurrent
    private func importAll(
        _ continuation: AsyncThrowingStream<SyncProgress, Error>.Continuation
    ) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let hasImported = try await database.read { db in
            try Self.hasCompletedInitialImport(db)
        }
        guard !hasImported else { return }

        let baselineToken = PHPhotoLibrary.shared().currentChangeToken

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        let total = fetchResult.count
        let scanDate = Date()

        let deviceID = try await database.write { db in
            try Self.currentDeviceID(db)
        }

        var processed = 0
        while processed < total {
            try Task.checkCancellation()
            let upperBound = min(processed + Self.chunkSize, total)
            let chunk = autoreleasepool {
                fetchResult
                    .objects(at: IndexSet(integersIn: processed ..< upperBound))
                    .map(AssetMetadata.init)
            }
            try await database.write { db in
                for metadata in chunk {
                    try Self.upsert(metadata, deviceID: deviceID, addedAt: scanDate, db: db)
                }
            }
            processed = upperBound
            continuation.yield(SyncProgress(processed: processed, total: total))
        }

        try await database.write { db in
            try Self.saveChangeToken(baselineToken, db)
        }
    }

    private static func upsert(
        _ metadata: AssetMetadata,
        deviceID: Int,
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
        }
        .execute(db)
    }

    private static func currentDeviceID(_ db: Database) throws -> Int {
        let model = deviceModelIdentifier()
        let existing = try DeviceRecord
            .where { $0.make.eq("Apple") && $0.model.eq(model) }
            .fetchOne(db)
        if let existing {
            return existing.id
        }
        try DeviceRecord.insert {
            DeviceRecord.Draft(make: "Apple", model: model)
        }
        .execute(db)
        return Int(db.lastInsertedRowID)
    }

    private static func hasCompletedInitialImport(_ db: Database) throws -> Bool {
        let token = try SyncStateRecord
            .where { $0.id.eq(1) }
            .select(\.changeToken)
            .fetchOne(db)
        return (token ?? nil) != nil
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

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
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
