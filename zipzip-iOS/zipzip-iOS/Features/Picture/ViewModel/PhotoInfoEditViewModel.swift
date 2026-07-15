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
    private(set) var hasSuccessfulChanges = false
    private(set) var hasSaveFailure = false
    var isErrorAlertPresented = false
    private(set) var errorAlertMessage = ""

    @ObservationIgnored private var deviceRecords: [DeviceRecord] = []
    @ObservationIgnored private var localIdentifiers: [String]
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let onIdentifiersChanged: ([String]) -> Void

    init(
        devices: [FilterDevice] = [],
        localIdentifiers: [String] = [],
        onIdentifiersChanged: @escaping ([String]) -> Void = { _ in }
    ) {
        self.devices = devices
        self.localIdentifiers = localIdentifiers
        self.onIdentifiersChanged = onIdentifiersChanged
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
            recordFailure("사진 정보를 불러오지 못했어요.")
        }
    }

    func saveDevice(name: String) {
        let previous = saveTask
        saveTask = Task { [weak self] in
            await previous?.value
            await self?.runSaveDevice(name: name)
        }
    }

    func saveLocation(name: String, latitude: Double?, longitude: Double?) {
        let previous = saveTask
        saveTask = Task { [weak self] in
            await previous?.value
            await self?.runSaveLocation(name: name, latitude: latitude, longitude: longitude)
        }
    }

    func saveDate(_ date: Date) {
        let previous = saveTask
        saveTask = Task { [weak self] in
            await previous?.value
            await self?.runSaveDate(date)
        }
    }

    func waitForPendingSaves() async -> Bool {
        await saveTask?.value
        return hasSuccessfulChanges
    }

    func dismissErrorAlert() {
        isErrorAlertPresented = false
        errorAlertMessage = ""
    }

    private func runSaveDevice(name: String) async {
        guard !localIdentifiers.isEmpty else { return }
        guard let record = deviceRecords.first(where: {
            DeviceModelCatalog.filterDevice(make: $0.make, model: $0.model).name == name
        }) else {
            recordFailure("기기 정보를 저장하지 못했어요.")
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
                onIdentifiersChanged(localIdentifiers)
                hasSuccessfulChanges = true
                hasSaveFailure = false
            } else {
                recordFailure("기기 정보를 저장하지 못했어요.")
            }
        } catch {
            Self.logger.error("failed to update device: \(error)")
            recordFailure("기기 정보를 저장하지 못했어요.")
        }
    }

    private func runSaveLocation(name: String, latitude: Double?, longitude: Double?) async {
        guard !localIdentifiers.isEmpty else { return }
        do {
            let didUpdate = try await metadataEdit.updateLocation(
                localIdentifiers: localIdentifiers,
                name: name,
                latitude: latitude,
                longitude: longitude
            )
            if didUpdate {
                hasSuccessfulChanges = true
                hasSaveFailure = false
            } else {
                recordFailure("장소 정보를 저장하지 못했어요.")
            }
        } catch {
            Self.logger.error("failed to update location: \(error)")
            recordFailure("장소 정보를 저장하지 못했어요.")
        }
    }

    private func runSaveDate(_ date: Date) async {
        guard !localIdentifiers.isEmpty else { return }
        do {
            let didUpdate = try await metadataEdit.updateDate(
                localIdentifiers: localIdentifiers,
                date: date
            )
            if didUpdate {
                hasSuccessfulChanges = true
                hasSaveFailure = false
            } else {
                recordFailure("날짜 정보를 저장하지 못했어요.")
            }
        } catch {
            Self.logger.error("failed to update date: \(error)")
            recordFailure("날짜 정보를 저장하지 못했어요.")
        }
    }

    private func recordFailure(_ message: String) {
        hasSaveFailure = true
        errorAlertMessage = message
        isErrorAlertPresented = true
    }
}
