//
//  PlaceLabelingService.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import CoreLocation
import Foundation
import MapKit
import SQLiteData

nonisolated struct PlaceLabelingService {
    @Dependency(\.defaultDatabase) private var database

    private static let coordinatePrecision = 1000.0
    private static let requestInterval: Duration = .milliseconds(150)
    private static let maxRetries = 3
    private static let koreanLocale = Locale(identifier: "ko_KR")

    @concurrent
    func labelPendingPhotos() async throws {
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

        let clusters = Dictionary(grouping: located) { photo in
            ClusterKey(
                latitude: Self.rounded(photo.latitude),
                longitude: Self.rounded(photo.longitude)
            )
        }

        for (key, photos) in clusters {
            try Task.checkCancellation()
            guard let label = try await reverseGeocode(key) else { continue }
            let photoIDs = photos.map(\.id)
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
            try? await Task.sleep(for: Self.requestInterval)
        }
    }

    @MainActor
    private func reverseGeocode(_ key: ClusterKey) async throws -> String? {
        let location = CLLocation(latitude: key.latitude, longitude: key.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        request.preferredLocale = Self.koreanLocale

        var attempt = 0
        while true {
            do {
                guard let mapItem = try await request.mapItems.first else { return nil }
                return PlaceLabelCatalog.label(
                    regionCode: mapItem.addressRepresentations?.__regionCode,
                    regionName: mapItem.addressRepresentations?.regionName,
                    fullAddress: mapItem.address?.fullAddress
                )
            } catch let error as MKError where error.code == .placemarkNotFound {
                return nil
            } catch {
                attempt += 1
                guard attempt <= Self.maxRetries else { throw error }
                try await Task.sleep(for: .seconds(Double(attempt) * 2))
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
        (coordinate * coordinatePrecision).rounded() / coordinatePrecision
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
