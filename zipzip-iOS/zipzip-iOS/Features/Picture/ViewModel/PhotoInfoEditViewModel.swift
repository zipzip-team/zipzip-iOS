//
//  PhotoInfoEditViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/12/26.
//

import OSLog
import SQLiteData

@Observable
final class PhotoInfoEditViewModel {
    @ObservationIgnored
    @Dependency(\.photoFilterOptions) private var filterOptions

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @Dependency(\.photoMetadataEdit) private var metadataEdit

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PhotoInfoEdit")

    private(set) var devices: [FilterDevice]

    @ObservationIgnored private var deviceRecords: [DeviceRecord] = []
    @ObservationIgnored private var localIdentifiers: [String]

    init(devices: [FilterDevice] = [], localIdentifiers: [String] = []) {
        self.devices = devices
        self.localIdentifiers = localIdentifiers
    }

    func load() async {
        guard deviceRecords.isEmpty else { return }
        do {
            deviceRecords = try await database.read { db in
                try DeviceRecord.where { $0.isRegistered.eq(true) }.fetchAll(db)
            }
            if devices.isEmpty {
                devices = try await filterOptions.load().devices
            }
        } catch {
            Self.logger.error("failed to load device options: \(error)")
        }
    }

    func saveDevice(name: String) async {
        guard !localIdentifiers.isEmpty else { return }
        guard let record = deviceRecords.first(where: {
            DeviceModelCatalog.filterDevice(make: $0.make, model: $0.model).name == name
        }) else {
            return
        }

        do {
            let mapping = try await metadataEdit.updateDevice(
                localIdentifiers: localIdentifiers,
                deviceID: record.id,
                make: record.make,
                model: record.model
            )
            if !mapping.isEmpty {
                localIdentifiers = localIdentifiers.map { mapping[$0] ?? $0 }
            }
        } catch {
            Self.logger.error("failed to update device: \(error)")
        }
    }

    func saveLocation(name: String, latitude: Double?, longitude: Double?) async {
        guard !localIdentifiers.isEmpty else { return }
        do {
            try await metadataEdit.updateLocation(
                localIdentifiers: localIdentifiers,
                name: name,
                latitude: latitude,
                longitude: longitude
            )
        } catch {
            Self.logger.error("failed to update location: \(error)")
        }
    }

    func saveDate(_ date: Date) async {
        guard !localIdentifiers.isEmpty else { return }
        do {
            try await metadataEdit.updateDate(localIdentifiers: localIdentifiers, date: date)
        } catch {
            Self.logger.error("failed to update date: \(error)")
        }
    }
}
