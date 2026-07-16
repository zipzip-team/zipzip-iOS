//
//  RegisteredDeviceManagementViewModel.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RegisteredDeviceManagementViewModel {
    @ObservationIgnored
    private let store: RegisteredDeviceStore

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "RegisteredDevice"
    )

    private(set) var mode: RegisteredDeviceManagementMode = .normal
    private(set) var selectedDeviceIDs = Set<DetectedDevice.ID>()
    var showsDeleteAlert = false

    private(set) var registeredDevices: [DetectedDevice]
    private(set) var registerableDevices: [DetectedDevice]

    init(
        store: RegisteredDeviceStore,
        registeredDevices: [DetectedDevice] = [],
        registerableDevices: [DetectedDevice] = []
    ) {
        self.store = store
        self.registeredDevices = registeredDevices
        self.registerableDevices = registerableDevices
    }

    /// 등록(is_registered)된 기기 목록을 불러온다.
    func load() async {
        do {
            registeredDevices = try await store.loadRegisteredDevices()
        } catch {
            registeredDevices = []
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

    /// device 테이블 전체 기기를 열고, 현재 등록된 기기를 미리 선택한 상태로 등록 모드에 진입한다.
    func enterRegisteringMode() async {
        do {
            registerableDevices = try await store.loadAllDevices()
        } catch {
            Self.logger.error("failed to load devices: \(error)")
            return
        }
        selectedDeviceIDs = Set(registeredDevices.map(\.id))
        mode = .registering
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

    /// 선택된 기기를 등록 세트에서 제거한다.
    func confirmDelete() async {
        do {
            let registeredIDs = Set(registeredDevices.map(\.id))
            _ = try numericDeviceIDs(registeredIDs)
            let remaining = registeredIDs.subtracting(selectedDeviceIDs)
            try await save(registeredIDs: remaining)
            dismissDeleteAlert()
            cancelSelection()
        } catch {
            dismissDeleteAlert()
            Self.logger.error("failed to save registration: \(error)")
        }
    }

    /// 등록 모드에서 선택한 기기로 등록 세트를 교체한다.
    func registerSelectedDevices() async {
        do {
            try await save(registeredIDs: selectedDeviceIDs)
            cancelSelection()
        } catch {
            Self.logger.error("failed to save registration: \(error)")
        }
    }

    private func save(registeredIDs: Set<DetectedDevice.ID>) async throws {
        let ids = try numericDeviceIDs(registeredIDs)
        try await store.saveRegistration(deviceIDs: ids)
        registeredDevices = try await store.loadRegisteredDevices()
    }

    private func numericDeviceIDs(_ ids: Set<DetectedDevice.ID>) throws -> Set<Int> {
        let numericIDs = Set(ids.compactMap(Int.init))
        guard numericIDs.count == ids.count else {
            throw RegisteredDeviceManagementError.invalidDeviceIdentifier
        }
        return numericIDs
    }

    private func enterMode(_ mode: RegisteredDeviceManagementMode) {
        selectedDeviceIDs.removeAll()
        self.mode = mode
    }
}

private enum RegisteredDeviceManagementError: Error {
    case invalidDeviceIdentifier
}

enum RegisteredDeviceManagementMode {
    case normal
    case removing
    case registering

    var showsActionBar: Bool {
        self != .normal
    }
}
