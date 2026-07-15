//
//  PlaceLabelingService.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PlaceLabeling")

nonisolated struct PlaceLabelingService {
    @Dependency(\.defaultDatabase) private var database

    private static let coordinateStep = 0.005
    private static let persistBatchSize = 100

    @concurrent
    func labelPendingPhotos(onProgress: @Sendable (SyncProgress) -> Void = { _ in }) async throws {
        let located = try await database.read { db in
            try PhotoRecord
                .where { $0.placeID.is(nil) && !$0.latitude.is(nil) && !$0.longitude.is(nil) }
                .select { ($0.id, $0.latitude, $0.longitude) }
                .fetchAll(db)
        }
        .compactMap { row -> LocatedPhoto? in
            guard let latitude = row.1, let longitude = row.2 else { return nil }
            return LocatedPhoto(id: row.0, latitude: latitude, longitude: longitude)
        }
        guard !located.isEmpty else { return }

        let geocoder = LocalReverseGeocoder.shared
        guard !geocoder.isEmpty else {
            logger.error("place labeling skipped: geocoding data unavailable")
            return
        }

        let clusters = Dictionary(grouping: located) { photo in
            ClusterKey(
                latitude: Self.rounded(photo.latitude),
                longitude: Self.rounded(photo.longitude)
            )
        }

        let totalPhotos = located.count
        logger.info("place labeling started: \(totalPhotos) photos, \(clusters.count) clusters")
        onProgress(SyncProgress(processed: 0, total: totalPhotos))

        var labeled: [(label: String, key: ClusterKey, photoIDs: [Int])] = []
        for (key, photos) in clusters {
            try Task.checkCancellation()
            guard let sample = photos.first else { continue }
            if let label = geocoder.label(latitude: sample.latitude, longitude: sample.longitude) {
                labeled.append((label, key, photos.map(\.id)))
            }
        }

        var processedPhotos = 0
        for start in stride(from: 0, to: labeled.count, by: Self.persistBatchSize) {
            try Task.checkCancellation()
            let batch = Array(labeled[start ..< min(start + Self.persistBatchSize, labeled.count)])
            do {
                try await persist(batch)
                processedPhotos += batch.reduce(0) { $0 + $1.photoIDs.count }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("place labeling skipped a batch: \(error)")
            }
            onProgress(SyncProgress(processed: processedPhotos, total: totalPhotos))
            logger.info("place labeling progress: \(processedPhotos)/\(totalPhotos)")
        }
        logger.info("place labeling finished: \(processedPhotos)/\(totalPhotos)")
    }

    private func persist(_ batch: [(label: String, key: ClusterKey, photoIDs: [Int])]) async throws {
        try await database.write { db in
            for entry in batch {
                let placeID = try Self.findOrCreatePlace(
                    name: entry.label,
                    latitude: entry.key.latitude,
                    longitude: entry.key.longitude,
                    db: db
                )
                try PhotoRecord
                    .update { $0.placeID = #bind(placeID) }
                    .where { $0.id.in(entry.photoIDs) }
                    .execute(db)
            }
        }
    }

    private static func findOrCreatePlace(
        name: String,
        latitude: Double,
        longitude: Double,
        db: Database
    ) throws -> Int {
        if let existing = try PlaceRecord.where({ $0.name.eq(name) }).fetchOne(db) {
            return existing.id
        }
        try PlaceRecord.insert {
            PlaceRecord.Draft(name: name, latitude: latitude, longitude: longitude)
        }
        .execute(db)
        return Int(db.lastInsertedRowID)
    }

    private static func rounded(_ coordinate: Double) -> Double {
        (coordinate / coordinateStep).rounded() * coordinateStep
    }
}

private struct LocatedPhoto {
    let id: Int
    let latitude: Double
    let longitude: Double
}

private struct ClusterKey: Hashable {
    let latitude: Double
    let longitude: Double
}

private enum PlaceLabelingServiceKey: DependencyKey {
    static let liveValue = PlaceLabelingService()
}

extension DependencyValues {
    var placeLabeling: PlaceLabelingService {
        get { self[PlaceLabelingServiceKey.self] }
        set { self[PlaceLabelingServiceKey.self] = newValue }
    }
}
