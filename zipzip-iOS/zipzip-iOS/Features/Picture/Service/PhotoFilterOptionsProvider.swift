//
//  PhotoFilterOptionsProvider.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import SQLiteData

nonisolated struct PhotoFilterOptionsProvider {
    @Dependency(\.defaultDatabase) private var database

    func load() async throws -> PhotoFilterOptions {
        try await database.read { db in
            let registeredDeviceIDs = try DeviceRecord
                .where { $0.isRegistered.eq(true) }
                .select(\.id)
                .fetchAll(db)
            let registeredIDs = Set(registeredDeviceIDs)

            let deviceRows = try DeviceRecord
                .where { $0.isRegistered.eq(true) }
                .group(by: \.id)
                .join(PhotoRecord.all) { $1.deviceID.eq($0.id) }
                .select { ($0.make, $0.model, $1.id.count()) }
                .fetchAll(db)

            let placeRows = try PlaceRecord
                .join(PhotoRecord.all) { $1.placeID.eq($0.id) }
                .select { ($0.name, $1.deviceID) }
                .fetchAll(db)

            let devices = deviceRows
                .sorted { $0.2 > $1.2 }
                .map { DeviceModelCatalog.filterDevice(make: $0.0, model: $0.1) }

            var placeCounts: [String: Int] = [:]
            for row in placeRows {
                guard let deviceID = row.1, registeredIDs.contains(deviceID) else { continue }
                placeCounts[row.0, default: 0] += 1
            }
            let locations = placeCounts
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map(\.key)

            return PhotoFilterOptions(
                devices: devices,
                locations: locations,
                etcItems: PhotoFilterOptions.defaultEtcItems
            )
        }
    }
}

private enum PhotoFilterOptionsProviderKey: DependencyKey {
    static let liveValue = PhotoFilterOptionsProvider()
}

extension DependencyValues {
    var photoFilterOptions: PhotoFilterOptionsProvider {
        get { self[PhotoFilterOptionsProviderKey.self] }
        set { self[PhotoFilterOptionsProviderKey.self] = newValue }
    }
}
