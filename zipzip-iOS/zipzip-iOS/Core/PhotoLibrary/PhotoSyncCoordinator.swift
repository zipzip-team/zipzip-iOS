//
//  PhotoSyncCoordinator.swift
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
final class PhotoSyncCoordinator {
    @ObservationIgnored
    @Dependency(\.photoLibrarySync) private var photoLibrarySync

    @ObservationIgnored
    @Dependency(\.placeLabeling) private var placeLabeling

    @ObservationIgnored
    @Dependency(\.deviceBackfill) private var deviceBackfill

    @ObservationIgnored
    private var task: Task<Void, Never>?

    @ObservationIgnored
    private var backfillTask: Task<Void, Never>?

    var progress: SyncProgress?
    var isFinished = false

    func startIfNeeded() {
        guard task == nil else { return }
        task = Task {
            defer { isFinished = true }
            do {
                for try await progress in photoLibrarySync.syncIfNeeded() {
                    self.progress = progress
                }
                try await placeLabeling.labelPendingPhotos()
            } catch {
                logger.error("photo library sync failed: \(error)")
            }
            startBackfill()
        }
    }

    private func startBackfill() {
        guard backfillTask == nil else { return }
        backfillTask = Task(priority: .utility) {
            do {
                try await deviceBackfill.backfillPendingDevices()
            } catch is CancellationError {
            } catch {
                logger.error("device backfill failed: \(error)")
            }
        }
    }
}
