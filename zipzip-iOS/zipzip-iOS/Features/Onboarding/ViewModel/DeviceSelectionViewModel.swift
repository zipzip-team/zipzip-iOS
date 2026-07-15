//
//  DeviceSelectionViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import OSLog
import SQLiteData

@Observable
final class DeviceSelectionViewModel {
    @ObservationIgnored
    @Fetch private var fetchedDevices: [DetectedDevice]

    @ObservationIgnored
    private let store: RegisteredDeviceStore

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "DeviceSelection")

    var devices: [DetectedDevice] {
        fetchedDevices
    }

    var selectedDeviceIDs = Set<DetectedDevice.ID>()

    init(store: RegisteredDeviceStore) {
        self.store = store
        _fetchedDevices = Fetch(wrappedValue: [], DetectedDevicesRequest())
    }

    func toggleSelection(for device: DetectedDevice) {
        if selectedDeviceIDs.contains(device.id) {
            selectedDeviceIDs.remove(device.id)
        } else {
            selectedDeviceIDs.insert(device.id)
        }
    }

    /// 선택한 기기를 등록 세트로 저장한다.
    func saveSelection() async {
        let ids = Set(selectedDeviceIDs.compactMap(Int.init))
        do {
            try await store.saveRegistration(deviceIDs: ids)
        } catch {
            Self.logger.error("failed to save selected devices: \(error)")
        }
    }
}
