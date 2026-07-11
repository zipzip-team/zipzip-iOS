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
            try DeviceRecord.all
                .fetchAll(db)
                .sorted { $0.id < $1.id }
                .compactMap(Self.detectedDevice)
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
