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

    private static let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PhotoInfoEdit")

    private(set) var devices: [FilterDevice]

    init(devices: [FilterDevice] = []) {
        self.devices = devices
    }

    func load() async {
        guard devices.isEmpty else { return }
        do {
            devices = try await filterOptions.load().devices
        } catch {
            Self.logger.error("failed to load device options: \(error)")
        }
    }
}
