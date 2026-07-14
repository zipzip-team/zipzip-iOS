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

enum SyncPhase: Equatable {
    case idle
    case reading(SyncProgress)
    case labeling(SyncProgress)
    case backfilling(SyncProgress)
    case finished

    fileprivate var kind: Int {
        switch self {
        case .idle: 0
        case .reading: 1
        case .labeling: 2
        case .backfilling: 3
        case .finished: 4
        }
    }

    fileprivate var progress: SyncProgress? {
        switch self {
        case let .reading(progress), let .labeling(progress), let .backfilling(progress):
            progress
        case .idle, .finished:
            nil
        }
    }
}

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

    @ObservationIgnored
    private var phaseStartedAt: Date?

    @ObservationIgnored
    private var phaseStartProcessed = 0

    @ObservationIgnored
    private var pipelineGeneration = 0

    var progress: SyncProgress?
    var isFinished = false
    private(set) var phase: SyncPhase = .idle
    private(set) var estimatedSecondsRemaining: Double?

    var isProcessing: Bool {
        phase != .idle && phase != .finished
    }

    var remainingMinutes: Int? {
        guard let estimatedSecondsRemaining else { return nil }
        return max(1, Int((estimatedSecondsRemaining / 60).rounded(.up)))
    }

    func startIfNeeded() {
        runSync()
    }

    func refresh() {
        runSync()
    }

    private func runSync() {
        guard task == nil else { return }
        pipelineGeneration += 1
        let generation = pipelineGeneration
        phase = .idle
        estimatedSecondsRemaining = nil
        task = Task {
            defer {
                task = nil
                isFinished = true
            }
            do {
                for try await progress in photoLibrarySync.syncIfNeeded() {
                    self.progress = progress
                    updatePhase(.reading(progress), generation: generation)
                }
                try await placeLabeling.labelPendingPhotos { progress in
                    Task { @MainActor in self.updatePhase(.labeling(progress), generation: generation) }
                }
            } catch {
                logger.error("photo library sync failed: \(error)")
            }
            startBackfill(generation: generation)
        }
    }

    private func startBackfill(generation: Int) {
        guard backfillTask == nil else {
            updatePhase(.finished, generation: generation)
            return
        }
        updatePhase(.backfilling(SyncProgress(processed: 0, total: 0)), generation: generation)
        backfillTask = Task(priority: .utility) {
            defer {
                backfillTask = nil
                updatePhase(.finished, generation: generation)
            }
            do {
                try await deviceBackfill.backfillPendingDevices { progress in
                    Task { @MainActor in self.updatePhase(.backfilling(progress), generation: generation) }
                }
            } catch is CancellationError {
            } catch {
                logger.error("device backfill failed: \(error)")
            }
        }
    }

    private func updatePhase(_ newPhase: SyncPhase, generation: Int) {
        guard generation == pipelineGeneration else { return }
        guard newPhase.kind >= phase.kind else { return }
        if newPhase.kind != phase.kind {
            phaseStartedAt = Date()
            phaseStartProcessed = newPhase.progress?.processed ?? 0
        }
        phase = newPhase
        recomputeRemaining(for: newPhase)
    }

    private func recomputeRemaining(for phase: SyncPhase) {
        guard let progress = phase.progress else {
            estimatedSecondsRemaining = nil
            return
        }
        guard let phaseStartedAt,
              progress.total > progress.processed
        else {
            return
        }

        let elapsed = Date().timeIntervalSince(phaseStartedAt)
        let processedSinceStart = progress.processed - phaseStartProcessed
        guard elapsed >= 0.75, processedSinceStart > 0 else { return }

        let rate = Double(processedSinceStart) / elapsed
        guard rate > 0 else { return }

        estimatedSecondsRemaining = Double(progress.total - progress.processed) / rate
    }
}
