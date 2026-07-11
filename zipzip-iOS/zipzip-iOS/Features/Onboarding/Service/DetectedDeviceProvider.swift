//
//  DetectedDeviceProvider.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import SQLiteData

nonisolated struct DetectedDeviceProvider {
    @Dependency(\.defaultDatabase) private var database

    /// device 테이블의 전체 기기(갤럭시 제외).
    func load() async throws -> [DetectedDevice] {
        try await database.read { db in
            try DeviceRecord.all
                .fetchAll(db)
                .sorted { $0.id < $1.id }
                .compactMap(Self.detectedDevice)
        }
    }

    /// 등록(is_registered)된 기기(갤럭시 제외).
    func loadRegistered() async throws -> [DetectedDevice] {
        try await database.read { db in
            try DeviceRecord
                .where { $0.isRegistered.eq(true) }
                .fetchAll(db)
                .sorted { $0.id < $1.id }
                .compactMap(Self.detectedDevice)
        }
    }

    /// 등록된 기기 id 집합(사진 필터·사전 선택용).
    func loadRegisteredIDs() async throws -> Set<Int> {
        try await database.read { db in
            let ids = try DeviceRecord
                .where { $0.isRegistered.eq(true) }
                .select(\.id)
                .fetchAll(db)
            return Set(ids)
        }
    }

    /// 등록 세트를 주어진 id 집합으로 교체한다.
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

    private static func detectedDevice(from record: DeviceRecord) -> DetectedDevice? {
        let category = DeviceModelCatalog.category(make: record.make, model: record.model)
        // 갤럭시(안드로이드 폰)는 온보딩 기기 목록에서 제외한다.
        guard category != .galaxy else { return nil }

        let modelName = DeviceModelCatalog.filterDevice(make: record.make, model: record.model).name
        let type: DeviceType = switch category {
        case .camera, .unknown: .camera
        case .iPhone, .iPad, .galaxy: .phone
        }
        return DetectedDevice(
            id: "\(record.id)",
            name: category.typeLabel,
            modelName: modelName,
            type: type
        )
    }
}

private enum DetectedDeviceProviderKey: DependencyKey {
    static let liveValue = DetectedDeviceProvider()
}

extension DependencyValues {
    var detectedDevices: DetectedDeviceProvider {
        get { self[DetectedDeviceProviderKey.self] }
        set { self[DetectedDeviceProviderKey.self] = newValue }
    }
}
