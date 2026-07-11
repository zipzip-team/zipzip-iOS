//
//  RegisteredDeviceManagementViewModel.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

import Observation
import OSLog
import SQLiteData

@MainActor
@Observable
final class RegisteredDeviceManagementViewModel {
    @ObservationIgnored
    @Dependency(\.detectedDevices) private var provider

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "RegisteredDevice")

    private(set) var mode: RegisteredDeviceManagementMode = .normal
    private(set) var selectedDeviceIDs = Set<DetectedDevice.ID>()
    var showsDeleteAlert = false

    private(set) var registeredDevices: [DetectedDevice]
    private(set) var registerableDevices: [DetectedDevice]

    init(
        registeredDevices: [DetectedDevice] = DetectedDevice.registeredDeviceSamples,
        registerableDevices: [DetectedDevice] = DetectedDevice.registerableDeviceSamples
    ) {
        self.registeredDevices = registeredDevices
        self.registerableDevices = registerableDevices
    }

    /// 로컬 DB(device 테이블)의 탐지된 기기 전체를 등록 기기 목록으로 불러온다.
    func load() async {
        do {
            registeredDevices = try await provider.load()
        } catch {
            Self.logger.error("failed to load registered devices: \(error)")
        }
    }

    var displayedDevices: [DetectedDevice] {
        switch mode {
        case .normal, .removing:
            registeredDevices
        case .registering:
            registerableDevices
        }
    }

    var showsActionBar: Bool {
        mode.showsActionBar
    }

    var isDeleteDisabled: Bool {
        selectedDeviceIDs.isEmpty
    }

    var isRegistrationDisabled: Bool {
        selectedDeviceIDs.isEmpty
    }

    func enterRemovingMode() {
        enterMode(.removing)
    }

    func enterRegisteringMode() {
        enterMode(.registering)
    }

    func cancelSelection() {
        selectedDeviceIDs.removeAll()
        mode = .normal
    }

    func toggleSelection(for device: DetectedDevice) {
        if selectedDeviceIDs.contains(device.id) {
            selectedDeviceIDs.remove(device.id)
        } else {
            selectedDeviceIDs.insert(device.id)
        }
    }

    func isSelected(_ device: DetectedDevice) -> Bool {
        selectedDeviceIDs.contains(device.id)
    }

    func requestDelete() {
        guard !isDeleteDisabled else { return }
        showsDeleteAlert = true
    }

    func dismissDeleteAlert() {
        showsDeleteAlert = false
    }

    func confirmDelete() {
        registeredDevices.removeAll { selectedDeviceIDs.contains($0.id) }
        dismissDeleteAlert()
        cancelSelection()
    }

    func registerSelectedDevices() {
        let selectedDevices = registerableDevices.filter { selectedDeviceIDs.contains($0.id) }
        let registeredIDs = Set(registeredDevices.map(\.id))
        let newDevices = selectedDevices.filter { !registeredIDs.contains($0.id) }

        registeredDevices.append(contentsOf: newDevices)
        cancelSelection()
    }

    private func enterMode(_ mode: RegisteredDeviceManagementMode) {
        selectedDeviceIDs.removeAll()
        self.mode = mode
    }
}

enum RegisteredDeviceManagementMode {
    case normal
    case removing
    case registering

    var showsActionBar: Bool {
        self != .normal
    }
}
