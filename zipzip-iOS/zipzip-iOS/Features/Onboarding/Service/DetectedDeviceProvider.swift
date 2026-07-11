//
//  DetectedDeviceProvider.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import SQLiteData

nonisolated struct DetectedDeviceProvider {
    @Dependency(\.defaultDatabase) private var database

    func load() async throws -> [DetectedDevice] {
        try await database.read { db in
            let rows = try DeviceRecord
                .group(by: \.id)
                .join(PhotoRecord.all) { $1.deviceID.eq($0.id) }
                .select { ($0.id, $0.make, $0.model, $1.id.count()) }
                .fetchAll(db)
            return Self.mapped(rows)
        }
    }

    func loadRegistered() async throws -> [DetectedDevice] {
        try await database.read { db in
            let rows = try DeviceRecord
                .where { $0.isRegistered.eq(true) }
                .group(by: \.id)
                .join(PhotoRecord.all) { $1.deviceID.eq($0.id) }
                .select { ($0.id, $0.make, $0.model, $1.id.count()) }
                .fetchAll(db)
            return Self.mapped(rows)
        }
    }

    func saveRegistration(deviceIDs: Set<Int>) async throws {
        try await database.write { db in
            try DeviceRecord
                .where { $0.isRegistered.eq(true) }
                .update { $0.isRegistered = false }
                .execute(db)
            if !deviceIDs.isEmpty {
                try DeviceRecord
                    .where { $0.id.in(deviceIDs) }
                    .update { $0.isRegistered = true }
                    .execute(db)
            }
        }
    }

    private static func mapped(_ rows: [(Int, String?, String?, Int)]) -> [DetectedDevice] {
        rows
            .sorted { $0.3 > $1.3 }
            .compactMap { detectedDevice(id: $0.0, make: $0.1, model: $0.2) }
    }

    private static func detectedDevice(id: Int, make: String?, model: String?) -> DetectedDevice? {
        let category = DeviceModelCatalog.category(make: make, model: model)

        guard category != .galaxy else { return nil }

        let modelName = DeviceModelCatalog.filterDevice(make: make, model: model).name
        let type: DeviceType = switch category {
        case .camera, .unknown: .camera
        case .iPhone, .iPad, .galaxy: .phone
        }
        return DetectedDevice(
            id: "\(id)",
            name: category.typeLabel,
            modelName: modelName,
            type: type
        )
    }
}
