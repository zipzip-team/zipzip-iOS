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

    @concurrent
    func labelPendingPhotos(onProgress: @Sendable (SyncProgress) -> Void = { _ in }) async throws {
        let records = try await database.read { db in
            try PhotoRecord.all.fetchAll(db)
        }
        let located = records.compactMap { record -> LocatedPhoto? in
            guard record.placeID == nil,
                  let latitude = record.latitude,
                  let longitude = record.longitude
            else { return nil }
            return LocatedPhoto(id: record.id, latitude: latitude, longitude: longitude)
        }
        guard !located.isEmpty else { return }

        let geocoder = LocalReverseGeocoder()
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

        var processedPhotos = 0
        for (key, photos) in clusters {
            try Task.checkCancellation()
            if let label = geocoder.label(latitude: key.latitude, longitude: key.longitude) {
                do {
                    try await persist(label: label, key: key, photoIDs: photos.map(\.id))
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    logger.error("place labeling skipped a cluster: \(error)")
                }
            }
            processedPhotos += photos.count
            onProgress(SyncProgress(processed: processedPhotos, total: totalPhotos))
            logger.info("place labeling progress: \(processedPhotos)/\(totalPhotos)")
        }
        logger.info("place labeling finished: \(processedPhotos)/\(totalPhotos)")
    }

    private func persist(label: String, key: ClusterKey, photoIDs: [Int]) async throws {
        try await database.write { db in
            let placeID = try Self.findOrCreatePlace(
                name: label,
                latitude: key.latitude,
                longitude: key.longitude,
                db: db
            )
            try PhotoRecord
                .update { $0.placeID = #bind(placeID) }
                .where { $0.id.in(photoIDs) }
                .execute(db)
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
