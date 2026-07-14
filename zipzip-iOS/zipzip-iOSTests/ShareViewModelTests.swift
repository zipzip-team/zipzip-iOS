import XCTest
@testable import zipzip_iOS

final class ShareViewModelTests: XCTestCase {
    @MainActor
    func testCreateGroupUsesResponseForInvitationAndGroup() async throws {
        let response = CreateSharedGroupResponse(
            id: try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111")),
            name: "우리 가족",
            inviteCode: "ZZ7K9P2Q"
        )
        let viewModel = ShareViewModel(groups: [])
        viewModel.presentCreateSheet()
        viewModel.groupNameDraft = "우리 가족"

        await viewModel.createGroup(using: StubShareGroupAPI(response: response))

        XCTAssertFalse(viewModel.isCreateSheetPresented)
        XCTAssertTrue(viewModel.isInviteSheetPresented)
        XCTAssertEqual(viewModel.pendingCreatedGroup?.id, response.id)
        XCTAssertEqual(viewModel.pendingCreatedGroup?.name, response.name)
        XCTAssertEqual(viewModel.inviteCode, response.inviteCode)
    }
}

private struct StubShareGroupAPI: ShareGroupAPI {
    let response: CreateSharedGroupResponse

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse {
        response
    }
}
