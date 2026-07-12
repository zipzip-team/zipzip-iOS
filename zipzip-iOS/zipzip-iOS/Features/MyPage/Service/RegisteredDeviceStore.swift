//
//  RegisteredDeviceStore.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/12/26.
//

import Foundation

protocol RegisteredDeviceStore {
    func loadRegisteredDevices() async throws -> [DetectedDevice]
    func loadAllDevices() async throws -> [DetectedDevice]
    func saveRegistration(deviceIDs: Set<Int>) async throws
}

final class DefaultRegisteredDeviceStore: RegisteredDeviceStore {
    private let provider = DetectedDeviceProvider()

    func loadRegisteredDevices() async throws -> [DetectedDevice] {
        try await provider.loadRegistered()
    }

    func loadAllDevices() async throws -> [DetectedDevice] {
        try await provider.load()
    }

    func saveRegistration(deviceIDs: Set<Int>) async throws {
        try await provider.saveRegistration(deviceIDs: deviceIDs)
    }
}
