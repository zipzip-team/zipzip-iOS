//
//  PhotoSectionsProvider.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation
import SQLiteData

struct FilterablePhoto {
    let photo: Photo
    let deviceID: Int?
    let takenAt: Date?
    let addedAt: Date
    let addedDate: Date
    let hasLocation: Bool
}

nonisolated struct PhotoSectionsRequest: FetchKeyRequest {
    let filters: [AppliedFilter]

    init(filters: [AppliedFilter] = []) {
        self.filters = filters
    }

    func fetch(_ db: Database) throws -> [PhotoSection] {
        let records = try PhotoRecord.all.fetchAll(db)
        let devices = try DeviceRecord.all.fetchAll(db)
        let places = try PlaceRecord.all.fetchAll(db)

        let deviceByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        let placeByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        let registeredDeviceIDs = Set(devices.filter(\.isRegistered).map(\.id))

        let library = records.map { record in
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
            return FilterablePhoto(
                photo: Photo(localIdentifier: record.localIdentifier, metadata: metadata),
                deviceID: record.deviceID,
                takenAt: record.takenAt,
                addedAt: record.addedAt,
                addedDate: record.addedDate,
                hasLocation: record.placeID != nil
            )
        }

        return Self.sections(from: library, filters: filters, registeredDeviceIDs: registeredDeviceIDs)
    }

    private static func sections(
        from library: [FilterablePhoto],
        filters: [AppliedFilter],
        registeredDeviceIDs: Set<Int>
    ) -> [PhotoSection] {
        // 등록된 기기의 사진만 노출한다.
        var filtered = library.filter { photo in
            guard let deviceID = photo.deviceID else { return false }
            return registeredDeviceIDs.contains(deviceID)
        }
        for filter in filters {
            filtered = apply(filter, to: filtered)
        }

        let sorted = filtered.sorted { lhs, rhs in
            switch (lhs.takenAt, rhs.takenAt) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.addedAt > rhs.addedAt
            }
        }

        let items = sorted.map { (date: $0.takenAt, photo: $0.photo) }
        return PhotoSectionGrouping.sections(from: items)
    }

    private static let recentPhotoLimit = 50

    private static func apply(_ filter: AppliedFilter, to photos: [FilterablePhoto]) -> [FilterablePhoto] {
        switch filter.kind {
        case .device:
            return photos.filter { $0.photo.metadata.deviceName == filter.value }
        case .date:
            guard let target = AppliedFilter.date(from: filter.value) else { return photos }
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: target)
            return photos.filter { photo in
                guard let taken = photo.takenAt else { return false }
                return calendar.startOfDay(for: taken) == day
            }
        case .location:
            return photos.filter { $0.photo.metadata.location == filter.value }
        case .etc:
            switch filter.value {
            case PhotoFilterOptions.EtcItem.noLocation:
                return photos.filter { !$0.hasLocation }
            case PhotoFilterOptions.EtcItem.noDate:
                return photos.filter { $0.takenAt == nil }
            case PhotoFilterOptions.EtcItem.recentlyAdded:
                return photos
                    .sorted { $0.addedDate > $1.addedDate }
                    .prefix(recentPhotoLimit)
                    .map { $0 }
            default:
                return photos
            }
        }
    }
}
