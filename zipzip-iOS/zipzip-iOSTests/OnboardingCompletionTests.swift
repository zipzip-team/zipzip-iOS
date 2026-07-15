import SQLiteData
import XCTest
@testable import zipzip_iOS

final class OnboardingCompletionTests: XCTestCase {
    @MainActor
    func testPhotoSyncFailureDoesNotFinishAndRetryCanComplete() async {
        var attempt = 0
        let coordinator = PhotoSyncCoordinator(
            syncOperation: {
                attempt += 1
                return AsyncThrowingStream { continuation in
                    if attempt == 1 {
                        continuation.yield(SyncProgress(processed: 1, total: 2))
                        continuation.finish(throwing: TestError.failed)
                    } else {
                        continuation.finish()
                    }
                }
            },
            postProcessingOperation: { _ in }
        )

        coordinator.startIfNeeded()
        await waitUntil { coordinator.isErrorAlertPresented }

        XCTAssertFalse(coordinator.isFinished)
        XCTAssertEqual(coordinator.phase, .idle)

        coordinator.startIfNeeded()
        await waitForAsyncWork()
        XCTAssertEqual(attempt, 1)

        coordinator.retrySync()
        await waitUntil { coordinator.phase == .finished }

        XCTAssertEqual(attempt, 2)
        XCTAssertTrue(coordinator.isFinished)
        XCTAssertFalse(coordinator.isErrorAlertPresented)
    }

    @MainActor
    func testPhotoSyncCancellationDoesNotFinishOrPresentError() async {
        let coordinator = PhotoSyncCoordinator(
            syncOperation: {
                AsyncThrowingStream { continuation in
                    continuation.finish(throwing: CancellationError())
                }
            },
            postProcessingOperation: { _ in }
        )

        coordinator.startIfNeeded()
        await waitForAsyncWork()

        XCTAssertFalse(coordinator.isFinished)
        XCTAssertFalse(coordinator.isErrorAlertPresented)
        XCTAssertEqual(coordinator.phase, .idle)
    }

    @MainActor
    func testDeviceSelectionFailureReturnsFalseAndPresentsError() async throws {
        let store = DeviceSelectionStoreStub(saveError: TestError.failed)
        let viewModel = try makeDeviceSelectionViewModel(store: store)
        viewModel.selectedDeviceIDs = ["7"]

        let didSave = await viewModel.saveSelection()

        XCTAssertFalse(didSave)
        XCTAssertTrue(viewModel.isErrorAlertPresented)
        XCTAssertFalse(viewModel.isSavingSelection)
        XCTAssertEqual(store.savedDeviceIDs, [[7]])
    }

    @MainActor
    func testDeviceSelectionSuccessReturnsTrueWithoutError() async throws {
        let store = DeviceSelectionStoreStub()
        let viewModel = try makeDeviceSelectionViewModel(store: store)
        viewModel.selectedDeviceIDs = ["7", "11"]

        let didSave = await viewModel.saveSelection()

        XCTAssertTrue(didSave)
        XCTAssertFalse(viewModel.isErrorAlertPresented)
        XCTAssertFalse(viewModel.isSavingSelection)
        XCTAssertEqual(store.savedDeviceIDs, [[7, 11]])
    }

    @MainActor
    func testDeviceSelectionCancellationReturnsFalseWithoutError() async throws {
        let store = DeviceSelectionStoreStub(saveError: CancellationError())
        let viewModel = try makeDeviceSelectionViewModel(store: store)

        let didSave = await viewModel.saveSelection()

        XCTAssertFalse(didSave)
        XCTAssertFalse(viewModel.isErrorAlertPresented)
        XCTAssertFalse(viewModel.isSavingSelection)
    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        XCTAssertTrue(condition())
    }

    private func waitForAsyncWork() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    @MainActor
    private func makeDeviceSelectionViewModel(
        store: RegisteredDeviceStore
    ) throws -> DeviceSelectionViewModel {
        let database = try appDatabase()
        return withDependencies {
            $0.defaultDatabase = database
        } operation: {
            DeviceSelectionViewModel(store: store)
        }
    }
}

@MainActor
private final class DeviceSelectionStoreStub: RegisteredDeviceStore {
    private let saveError: Error?
    private(set) var savedDeviceIDs: [Set<Int>] = []

    init(saveError: Error? = nil) {
        self.saveError = saveError
    }

    func loadRegisteredDevices() async throws -> [DetectedDevice] {
        []
    }

    func loadAllDevices() async throws -> [DetectedDevice] {
        []
    }

    func saveRegistration(deviceIDs: Set<Int>) async throws {
        savedDeviceIDs.append(deviceIDs)
        if let saveError {
            throw saveError
        }
    }
}

private enum TestError: Error {
    case failed
}
