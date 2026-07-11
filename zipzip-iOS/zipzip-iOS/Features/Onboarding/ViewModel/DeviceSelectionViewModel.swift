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
    @Dependency(\.detectedDevices) private var provider

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "DeviceSelection")

    private(set) var devices: [DetectedDevice] = []
    var selectedDeviceIDs = Set<DetectedDevice.ID>()

    func load() async {
        do {
            devices = try await provider.load()
        } catch {
            Self.logger.error("failed to load detected devices: \(error)")
        }
    }

    func toggleSelection(for device: DetectedDevice) {
        if selectedDeviceIDs.contains(device.id) {
            selectedDeviceIDs.remove(device.id)
        } else {
            selectedDeviceIDs.insert(device.id)
        }
    }
}
