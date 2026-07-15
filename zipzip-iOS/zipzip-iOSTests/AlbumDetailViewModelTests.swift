import XCTest
@testable import zipzip_iOS

final class AlbumDetailViewModelTests: XCTestCase {
    func testMoveFailureKeepsSelectionAndSheetOpen() async {
        let photoID = UUID()
        let viewModel = AlbumDetailViewModel(
            initialSelectionMode: true,
            actions: AlbumDetailActions(onMovePhotos: { _, _ in false })
        )
        viewModel.togglePhotoSelection(photoID)
        viewModel.presentMoveSheet()

        await viewModel.completePhotoMove(to: [])

        XCTAssertTrue(viewModel.isSelectionMode)
        XCTAssertEqual(viewModel.selectedPhotoIDs, [photoID])
        XCTAssertTrue(viewModel.isMoveSheetPresented)
        XCTAssertTrue(viewModel.isErrorAlertPresented)
    }

    func testDeleteFailureKeepsSelectionAndPresentsNativeError() async {
        let photoID = UUID()
        let viewModel = AlbumDetailViewModel(
            initialSelectionMode: true,
            actions: AlbumDetailActions(onDeletePhotos: { _, _ in false })
        )
        viewModel.togglePhotoSelection(photoID)
        viewModel.presentPhotoDeleteAlert()

        await viewModel.removeSelectedPhotosFromAlbum()

        XCTAssertTrue(viewModel.isSelectionMode)
        XCTAssertEqual(viewModel.selectedPhotoIDs, [photoID])
        XCTAssertFalse(viewModel.isDeleteAlertPresented)
        XCTAssertTrue(viewModel.isErrorAlertPresented)
    }

    func testSuccessfulDeleteExitsSelectionMode() async {
        let photoID = UUID()
        let viewModel = AlbumDetailViewModel(
            initialSelectionMode: true,
            actions: AlbumDetailActions(onDeletePhotos: { _, _ in true })
        )
        viewModel.togglePhotoSelection(photoID)

        await viewModel.deleteSelectedPhotosPermanently()

        XCTAssertFalse(viewModel.isSelectionMode)
        XCTAssertTrue(viewModel.selectedPhotoIDs.isEmpty)
        XCTAssertFalse(viewModel.isErrorAlertPresented)
    }

    func testPhotoAddFailureIsReturnedAndPresented() async {
        let viewModel = AlbumDetailViewModel(
            actions: AlbumDetailActions(onAddPhotos: { _ in false })
        )

        let didAdd = await viewModel.addPhotos(["photo-1"])

        XCTAssertFalse(didAdd)
        XCTAssertTrue(viewModel.isErrorAlertPresented)
    }
}
