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

    func loadSections() async throws -> [PhotoSection] {
        try await database.read { db in
            let records = try PhotoRecord.all.fetchAll(db)
            let devices = try DeviceRecord.all.fetchAll(db)
            let places = try PlaceRecord.all.fetchAll(db)

            let deviceByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
            let placeByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

            let sorted = records.sorted { lhs, rhs in
                switch (lhs.takenAt, rhs.takenAt) {
                case let (l?, r?): return l > r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.addedAt > rhs.addedAt
                }
            }

            let items = sorted.map { record -> (date: Date?, photo: Photo) in
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
                return (record.takenAt, Photo(localIdentifier: record.localIdentifier, metadata: metadata))
            }

            return PhotoSectionGrouping.sections(from: items)
        }
    }
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
