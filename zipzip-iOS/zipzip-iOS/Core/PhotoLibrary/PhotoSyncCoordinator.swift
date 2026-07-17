//
//  PhotoSyncCoordinator.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import OSLog
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
    category: "PhotoLibrarySync"
)

enum SyncPhase: Equatable {
    case idle
    case reading
    case organizing
    case uploading
    case finished

    fileprivate var kind: Int {
        switch self {
        case .idle: 0
        case .reading: 1
        case .organizing: 2
        case .uploading: 3
        case .finished: 4
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
    private var uploadTasks: [UUID: Task<Void, Never>] = [:]

    @ObservationIgnored
    private var etaStartedAt: Date?

    @ObservationIgnored
    private var etaStartProcessed = 0

    @ObservationIgnored
    private var uploadTotalUnits = 0

    @ObservationIgnored
    private var uploadCompletedUnits = 0

    @ObservationIgnored
    private var uploadEtaStartedAt: Date?

    @ObservationIgnored
    private var uploadEtaStartUnits = 0

    @ObservationIgnored
    private var pipelineGeneration = 0

    @ObservationIgnored
    private let syncOperation: SyncOperation?

    @ObservationIgnored
    private let postProcessingOperation: PostProcessingOperation?

    var progress: SyncProgress?
    var isFinished = false
    private(set) var phase: SyncPhase = .idle
    private(set) var estimatedSecondsRemaining: Double?
    private var activeUploadCount = 0

    var isUploading: Bool {
        activeUploadCount > 0
    }

    init(
        syncOperation: SyncOperation? = nil,
        postProcessingOperation: PostProcessingOperation? = nil
    ) {
        self.syncOperation = syncOperation
        self.postProcessingOperation = postProcessingOperation
    }

    var isProcessing: Bool {
        isUploading || (phase != .idle && phase != .finished)
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

    func cancelSync() {
        task?.cancel()
        let tasks = uploadTasks
        uploadTasks.removeAll()
        tasks.values.forEach { $0.cancel() }
    }

    func beginUpload() {
        if activeUploadCount == 0 {
            resetUploadEstimate()
        }
        activeUploadCount += 1
    }

    func endUpload() {
        activeUploadCount = max(0, activeUploadCount - 1)
        if activeUploadCount == 0 {
            resetUploadEstimate()
        }
    }

    /// 업로드할 전체 사진 수를 누적 등록한다(여러 업로드가 동시에 진행될 수 있어 누적).
    func registerUploadUnits(_ count: Int) {
        guard count > 0 else { return }
        uploadTotalUnits += count
    }

    /// 업로드가 완료된 사진 수를 보고하고 남은 시간을 갱신한다.
    func reportUploadCompleted(_ count: Int) {
        guard count > 0 else { return }
        uploadCompletedUnits += count
        updateUploadEstimate()
    }

    private func resetUploadEstimate() {
        estimatedSecondsRemaining = nil
        uploadTotalUnits = 0
        uploadCompletedUnits = 0
        uploadEtaStartedAt = nil
        uploadEtaStartUnits = 0
    }

    private func updateUploadEstimate() {
        guard uploadTotalUnits > 0 else { return }
        let processed = min(uploadCompletedUnits, uploadTotalUnits)
        guard uploadTotalUnits > processed else {
            estimatedSecondsRemaining = nil
            return
        }

        // 첫 완료 보고에서 시각·처리량 기준을 시드해, 이후 rate를 동일 구간으로 계산한다.
        guard let uploadEtaStartedAt else {
            uploadEtaStartedAt = Date()
            uploadEtaStartUnits = processed
            return
        }

        let elapsed = Date().timeIntervalSince(uploadEtaStartedAt)
        let processedSinceStart = processed - uploadEtaStartUnits
        guard elapsed >= 0.75, processedSinceStart > 0 else { return }

        let rate = Double(processedSinceStart) / elapsed
        guard rate > 0 else { return }

        estimatedSecondsRemaining = Double(uploadTotalUnits - processed) / rate
    }

    /// 인디케이터 상태를 스스로 관리하지 않는 업로드를 실행하며 인디케이터를 켜고, 취소 가능하도록 추적한다.
    func runUpload(_ operation: @escaping @MainActor () async -> Void) {
        beginUpload()
        let id = UUID()
        uploadTasks[id] = Task {
            defer {
                endUpload()
                uploadTasks[id] = nil
            }
            await operation()
        }
    }

    /// 업로드를 자체 관리(begin/end)하는 작업을, `cancelSync()`로 취소 가능하도록 추적만 한다. `Task {}`의 드롭인 대체.
    func track(_ operation: @escaping @MainActor () async -> Void) {
        let id = UUID()
        uploadTasks[id] = Task {
            defer { uploadTasks[id] = nil }
            await operation()
        }
    }

    private func runSync() {
        guard task == nil else { return }
        pipelineGeneration += 1
        let generation = pipelineGeneration
        isFinished = false
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
                if Task.isCancelled {
                    resetAfterInterruptedSync(generation: generation)
                    return
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

            if Task.isCancelled {
                resetAfterInterruptedSync(generation: generation)
                return
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
