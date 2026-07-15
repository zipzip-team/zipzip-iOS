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
    case reading
    case organizing
    case finished

    fileprivate var kind: Int {
        switch self {
        case .idle: 0
        case .reading: 1
        case .organizing: 2
        case .finished: 3
        }
    }
}

@MainActor
@Observable
final class PhotoSyncCoordinator {
    typealias SyncOperation = @MainActor () -> AsyncThrowingStream<SyncProgress, Error>
    typealias PostProcessingOperation = @MainActor (
        @escaping @Sendable (SyncProgress) -> Void
    ) async -> Void

    @ObservationIgnored
    @Dependency(\.photoLibrarySync) private var photoLibrarySync

    @ObservationIgnored
    @Dependency(\.placeLabeling) private var placeLabeling

    @ObservationIgnored
    @Dependency(\.deviceBackfill) private var deviceBackfill

    @ObservationIgnored
    private var task: Task<Void, Never>?

    @ObservationIgnored
    private var etaStartedAt: Date?

    @ObservationIgnored
    private var etaStartProcessed = 0

    @ObservationIgnored
    private var pipelineGeneration = 0

    @ObservationIgnored
    private let syncOperation: SyncOperation?

    @ObservationIgnored
    private let postProcessingOperation: PostProcessingOperation?

    var progress: SyncProgress?
    var isFinished = false
    var isErrorAlertPresented = false
    private(set) var phase: SyncPhase = .idle
    private(set) var estimatedSecondsRemaining: Double?

    init(
        syncOperation: SyncOperation? = nil,
        postProcessingOperation: PostProcessingOperation? = nil
    ) {
        self.syncOperation = syncOperation
        self.postProcessingOperation = postProcessingOperation
    }

    var isProcessing: Bool {
        phase != .idle && phase != .finished
    }

    var remainingMinutes: Int? {
        guard let estimatedSecondsRemaining else { return nil }
        return max(1, Int((estimatedSecondsRemaining / 60).rounded(.up)))
    }

    func startIfNeeded() {
        guard !isErrorAlertPresented else { return }
        runSync()
    }

    func refresh() {
        runSync()
    }

    func dismissSyncError() {
        isErrorAlertPresented = false
    }

    func retrySync() {
        isErrorAlertPresented = false
        runSync()
    }

    private func runSync() {
        guard task == nil else { return }
        pipelineGeneration += 1
        let generation = pipelineGeneration
        isFinished = false
        isErrorAlertPresented = false
        phase = .idle
        estimatedSecondsRemaining = nil
        task = Task {
            defer { task = nil }

            // 1단계: sync — 기기 저장 사진의 기기 정보까지 해석 완료
            do {
                let stream = syncOperation?() ?? photoLibrarySync.syncIfNeeded()
                for try await progress in stream {
                    self.progress = progress
                    advance(to: .reading, generation: generation)
                    reportProgress(processed: progress.processed, total: progress.total, generation: generation)
                }
                try Task.checkCancellation()
            } catch is CancellationError {
                resetAfterInterruptedSync(generation: generation)
                return
            } catch {
                logger.error("photo library sync failed: \(error)")
                resetAfterInterruptedSync(generation: generation)
                isErrorAlertPresented = true
                return
            }

            // sync 완료 시점에 확인 버튼 활성화
            isFinished = true

            // 2단계: 장소 라벨링 + iCloud 기기 백필을 백그라운드 병렬 수행
            advance(to: .organizing, generation: generation)
            if let postProcessingOperation {
                await postProcessingOperation { progress in
                    Task { @MainActor in
                        self.reportProgress(
                            processed: progress.processed,
                            total: progress.total,
                            generation: generation
                        )
                    }
                }
                advance(to: .finished, generation: generation)
                return
            }

            let labeling = placeLabeling
            let backfill = deviceBackfill
            await withTaskGroup(of: Void.self) { group in
                group.addTask(priority: .utility) {
                    do {
                        try await labeling.labelPendingPhotos()
                    } catch {
                        logger.error("place labeling failed: \(error)")
                    }
                }
                group.addTask(priority: .utility) {
                    do {
                        try await backfill.backfillPendingDevices { progress in
                            Task { @MainActor in
                                self.reportProgress(
                                    processed: progress.processed,
                                    total: progress.total,
                                    generation: generation
                                )
                            }
                        }
                    } catch is CancellationError {
                    } catch {
                        logger.error("device backfill failed: \(error)")
                    }
                }
            }

            advance(to: .finished, generation: generation)
        }
    }

    private func advance(to newPhase: SyncPhase, generation: Int) {
        guard generation == pipelineGeneration else { return }
        guard newPhase.kind >= phase.kind else { return }
        if newPhase.kind != phase.kind {
            etaStartedAt = nil
            etaStartProcessed = 0
            estimatedSecondsRemaining = nil
        }
        phase = newPhase
    }

    private func resetAfterInterruptedSync(generation: Int) {
        guard generation == pipelineGeneration else { return }
        phase = .idle
        etaStartedAt = nil
        etaStartProcessed = 0
        estimatedSecondsRemaining = nil
    }

    private func reportProgress(processed: Int, total: Int, generation: Int) {
        guard generation == pipelineGeneration, isProcessing else { return }
        guard total > processed else { return }

        // 첫 샘플에서 시각·처리량 기준을 함께 시드해, 이후 rate를 동일 구간으로 계산한다.
        guard let etaStartedAt else {
            etaStartedAt = Date()
            etaStartProcessed = processed
            return
        }

        let elapsed = Date().timeIntervalSince(etaStartedAt)
        let processedSinceStart = processed - etaStartProcessed
        guard elapsed >= 0.75, processedSinceStart > 0 else { return }

        let rate = Double(processedSinceStart) / elapsed
        guard rate > 0 else { return }

        estimatedSecondsRemaining = Double(total - processed) / rate
    }
}
