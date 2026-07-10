//
//  PhotoSectionsProvider.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation
import SQLiteData

nonisolated struct PhotoSectionsProvider {
    @Dependency(\.defaultDatabase) private var database

    func loadSections(filters: [AppliedFilter] = []) async throws -> [PhotoSection] {
        try await database.read { db in
            let records = try PhotoRecord.all.fetchAll(db)
            let devices = try DeviceRecord.all.fetchAll(db)
            let places = try PlaceRecord.all.fetchAll(db)

            let deviceByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
            let placeByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

            var enriched = records.map { record -> EnrichedPhoto in
                let device = record.deviceID.flatMap { deviceByID[$0] }
                let filterDevice = DeviceModelCatalog.filterDevice(make: device?.make, model: device?.model)
                let place = record.placeID.flatMap { placeByID[$0] }
                let dateText = record.takenAt.map(AppliedFilter.dateText) ?? ""
                let metadata = PhotoMetadata(
                    deviceName: filterDevice.name,
                    deviceType: filterDevice.type,
                    location: place?.name ?? "",
                    dateText: dateText
                )
                return EnrichedPhoto(
                    record: record,
                    photo: Photo(localIdentifier: record.localIdentifier, metadata: metadata)
                )
            }

            for filter in filters {
                enriched = Self.apply(filter, to: enriched)
            }

            let sorted = enriched.sorted { lhs, rhs in
                switch (lhs.record.takenAt, rhs.record.takenAt) {
                case let (l?, r?): return l > r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.record.addedAt > rhs.record.addedAt
                }
            }

            let items = sorted.map { (date: $0.record.takenAt, photo: $0.photo) }
            return PhotoSectionGrouping.sections(from: items)
        }
    }

    private static let recentPhotoLimit = 50

    private static func apply(_ filter: AppliedFilter, to photos: [EnrichedPhoto]) -> [EnrichedPhoto] {
        switch filter.kind {
        case .device:
            return photos.filter { $0.photo.metadata.deviceName == filter.value }
        case .date:
            guard let target = AppliedFilter.date(from: filter.value) else { return photos }
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: target)
            return photos.filter { photo in
                guard let taken = photo.record.takenAt else { return false }
                return calendar.startOfDay(for: taken) == day
            }
        case .location:
            return photos
        case .etc:
            switch filter.value {
            case PhotoFilterOptions.EtcItem.noLocation:
                return photos.filter { $0.record.placeID == nil }
            case PhotoFilterOptions.EtcItem.noDate:
                return photos.filter { $0.record.takenAt == nil }
            case PhotoFilterOptions.EtcItem.recentlyAdded:
                return photos
                    .sorted { $0.record.addedDate > $1.record.addedDate }
                    .prefix(recentPhotoLimit)
                    .map { $0 }
            default:
                return photos
            }
        }
    }
}

private struct EnrichedPhoto {
    let record: PhotoRecord
    let photo: Photo
}

private enum PhotoSectionsProviderKey: DependencyKey {
    static let liveValue = PhotoSectionsProvider()
}

extension DependencyValues {
    var photoSections: PhotoSectionsProvider {
        get { self[PhotoSectionsProviderKey.self] }
        set { self[PhotoSectionsProviderKey.self] = newValue }
    }
}
