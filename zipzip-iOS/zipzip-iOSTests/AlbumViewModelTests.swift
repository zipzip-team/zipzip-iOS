import XCTest
@testable import zipzip_iOS

@MainActor
final class AlbumViewModelTests: XCTestCase {
    func testSelectingShareGroupUpdatesCompletionSelection() {
        let album = AlbumViewItem(
            id: 1,
            name: "가족",
            createdAt: .now,
            count: 1,
            photoIDs: []
        )
        let groupID = UUID()
        let viewModel = AlbumViewModel(albums: [album])

        viewModel.enterSelectionMode()
        viewModel.toggleSelection(for: album)
        viewModel.moveSelectedAlbumsToShare()
        viewModel.selectShareGroup(groupID)

        XCTAssertTrue(viewModel.isShareAlbumSheetPresented)
        XCTAssertEqual(viewModel.selectedShareGroupID, groupID)

        viewModel.dismissShareAlbumSheet()

        XCTAssertFalse(viewModel.isShareAlbumSheetPresented)
        XCTAssertNil(viewModel.selectedShareGroupID)
    }
}
