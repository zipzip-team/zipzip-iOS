//
//  DeviceSelectionViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation
import OSLog
import SQLiteData

@Observable
final class DeviceSelectionViewModel {
    @ObservationIgnored
    @Fetch private var fetchedDevices: [DetectedDevice]

    @ObservationIgnored
    private let store: RegisteredDeviceStore

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "DeviceSelection"
    )

    var devices: [DetectedDevice] {
        fetchedDevices
    }

    var selectedDeviceIDs = Set<DetectedDevice.ID>()
    private(set) var isSavingSelection = false

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
    func saveSelection() async -> Bool {
        guard !isSavingSelection else { return false }

        isSavingSelection = true
        defer { isSavingSelection = false }

        let ids = Set(selectedDeviceIDs.compactMap(Int.init))
        do {
            try await store.saveRegistration(deviceIDs: ids)
            try Task.checkCancellation()
            return true
        } catch is CancellationError {
            return false
        } catch {
            Self.logger.error("failed to save selected devices: \(error)")
            return false
        }
    }
}
