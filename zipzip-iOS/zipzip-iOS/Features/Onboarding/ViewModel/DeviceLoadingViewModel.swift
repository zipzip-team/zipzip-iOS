//
//  DeviceLoadingViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "PhotoLibrarySync")

@MainActor
@Observable
final class DeviceLoadingViewModel {
    @ObservationIgnored
    @Dependency(\.photoLibrarySync) private var photoLibrarySync

    var progress: SyncProgress?
    var isFinished = false

    func startSync() async {
        defer { isFinished = true }
        do {
            for try await progress in photoLibrarySync.syncIfNeeded() {
                self.progress = progress
            }
        } catch {
            logger.error("photo library sync failed: \(error)")
        }
    }
}
