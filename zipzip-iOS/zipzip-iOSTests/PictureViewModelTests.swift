import SQLiteData
import XCTest
@testable import zipzip_iOS

final class PictureViewModelTests: XCTestCase {
    func testDeleteFailureKeepsSelectionAndPresentsNativeError() async throws {
        let photo = Photo(localIdentifier: "photo-1", metadata: PhotoMetadata.samples[0])
        let viewModel = try makeViewModel(
            deleteOperation: { _ in throw PictureTestError.failed }
        )
        viewModel.handleLongPress(photo.id)

        await viewModel.deleteSelectedPhotos(localIdentifiers: [photo.localIdentifier])

        XCTAssertTrue(viewModel.isSelectionMode)
        XCTAssertEqual(viewModel.selectedPhotoIDs, [photo.id])
        XCTAssertTrue(viewModel.isErrorAlertPresented)
        XCTAssertEqual(viewModel.errorAlertMessage, "사진을 삭제하지 못했어요.")
    }

    func testDeleteSuccessClearsSelection() async throws {
        let photo = Photo(localIdentifier: "photo-1", metadata: PhotoMetadata.samples[0])
        var deletedIdentifiers: [String] = []
        let viewModel = try makeViewModel(
            deleteOperation: { deletedIdentifiers = $0 }
        )
        viewModel.handleLongPress(photo.id)

        await viewModel.deleteSelectedPhotos(localIdentifiers: [photo.localIdentifier])

        XCTAssertEqual(deletedIdentifiers, [photo.localIdentifier])
        XCTAssertFalse(viewModel.isSelectionMode)
        XCTAssertTrue(viewModel.selectedPhotoIDs.isEmpty)
        XCTAssertFalse(viewModel.isErrorAlertPresented)
    }

    private func makeViewModel(
        deleteOperation: @escaping ([String]) async throws -> Void
    ) throws -> PictureViewModel {
        let database = try appDatabase()
        return withDependencies {
            $0.defaultDatabase = database
        } operation: {
            PictureViewModel(
                deleteOperation: deleteOperation
            )
        }
    }
}

private enum PictureTestError: Error {
    case failed
}
