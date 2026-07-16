import XCTest
@testable import zipzip_iOS

final class RegisteredDeviceManagementViewModelTests: XCTestCase {
    @MainActor
    func testProductionStateStartsEmptyAndLoadFailureOffersRetry() async {
        let device = makeDevice(id: "1")
        let store = RegisteredDeviceStoreStub(registeredDevices: [device])
        store.loadRegisteredError = TestError.failed
        let viewModel = RegisteredDeviceManagementViewModel(store: store)

        XCTAssertTrue(viewModel.registeredDevices.isEmpty)

        await viewModel.load()

        XCTAssertTrue(viewModel.registeredDevices.isEmpty)

        store.loadRegisteredError = nil
        await viewModel.load()

        XCTAssertEqual(viewModel.registeredDevices, [device])
    }

    @MainActor
    func testRegisterLoadFailureDoesNotOpenSelectionMode() async {
        let store = RegisteredDeviceStoreStub()
        store.loadAllError = TestError.failed
        let viewModel = RegisteredDeviceManagementViewModel(store: store)

        await viewModel.enterRegisteringMode()

        XCTAssertEqual(viewModel.mode, .normal)

        store.loadAllError = nil
        store.allDevices = [makeDevice(id: "1")]
        await viewModel.enterRegisteringMode()

        XCTAssertEqual(viewModel.mode, .registering)
        XCTAssertEqual(viewModel.registerableDevices, store.allDevices)
    }

    @MainActor
    func testRegistrationFailureKeepsSelectionAndRetryCompletesSave() async {
        let device = makeDevice(id: "1")
        let store = RegisteredDeviceStoreStub(allDevices: [device])
        store.saveErrors = [TestError.failed, nil]
        let viewModel = RegisteredDeviceManagementViewModel(store: store)
        await viewModel.enterRegisteringMode()
        viewModel.toggleSelection(for: device)

        await viewModel.registerSelectedDevices()

        XCTAssertEqual(viewModel.mode, .registering)
        XCTAssertEqual(viewModel.selectedDeviceIDs, [device.id])

        await viewModel.registerSelectedDevices()

        XCTAssertEqual(store.savedDeviceIDs, [[1], [1]])
        XCTAssertEqual(viewModel.registeredDevices, [device])
        XCTAssertEqual(viewModel.mode, .normal)
        XCTAssertTrue(viewModel.selectedDeviceIDs.isEmpty)
    }

    @MainActor
    func testInvalidDeviceIdentifierCannotClearRegistration() async {
        let sample = DetectedDevice(name: "아이폰", modelName: "iphone", type: .phone)
        let store = RegisteredDeviceStoreStub(registeredDevices: [sample])
        let viewModel = RegisteredDeviceManagementViewModel(
            store: store,
            registeredDevices: [sample]
        )
        viewModel.enterRemovingMode()
        viewModel.toggleSelection(for: sample)
        viewModel.requestDelete()

        await viewModel.confirmDelete()

        XCTAssertTrue(store.savedDeviceIDs.isEmpty)
        XCTAssertEqual(viewModel.mode, .removing)
        XCTAssertEqual(viewModel.selectedDeviceIDs, [sample.id])
    }

    @MainActor
    private func makeDevice(id: String) -> DetectedDevice {
        DetectedDevice(id: id, name: "아이폰", modelName: "iphone", type: .phone)
    }
}

@MainActor
private final class RegisteredDeviceStoreStub: RegisteredDeviceStore {
    var registeredDevices: [DetectedDevice]
    var allDevices: [DetectedDevice]
    var loadRegisteredError: Error?
    var loadAllError: Error?
    var saveErrors: [Error?] = []
    private(set) var savedDeviceIDs: [Set<Int>] = []

    init(
        registeredDevices: [DetectedDevice] = [],
        allDevices: [DetectedDevice] = []
    ) {
        self.registeredDevices = registeredDevices
        self.allDevices = allDevices
    }

    func loadRegisteredDevices() async throws -> [DetectedDevice] {
        if let loadRegisteredError {
            throw loadRegisteredError
        }
        return registeredDevices
    }

    func loadAllDevices() async throws -> [DetectedDevice] {
        if let loadAllError {
            throw loadAllError
        }
        return allDevices
    }

    func saveRegistration(deviceIDs: Set<Int>) async throws {
        savedDeviceIDs.append(deviceIDs)
        if !saveErrors.isEmpty, let error = saveErrors.removeFirst() {
            throw error
        }
        registeredDevices = allDevices.filter { deviceIDs.contains(Int($0.id) ?? -1) }
    }
}

private enum TestError: Error {
    case failed
}
