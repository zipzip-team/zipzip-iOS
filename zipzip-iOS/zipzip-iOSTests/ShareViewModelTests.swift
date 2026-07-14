import XCTest
@testable import zipzip_iOS

final class ShareViewModelTests: XCTestCase {
    @MainActor
    func testCreateGroupImmediatelyAddsResponseToGroups() async throws {
        let response = CreateSharedGroupResponse(
            id: try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111")),
            name: "우리 가족",
            inviteCode: "ZZ7K9P2Q"
        )
        let store = try makeStore()
        let viewModel = ShareViewModel(groups: [], store: store)
        viewModel.presentCreateSheet()
        viewModel.groupNameDraft = "우리 가족"

        await viewModel.createGroup(using: StubShareGroupAPI(createResponse: response))

        XCTAssertFalse(viewModel.isCreateSheetPresented)
        XCTAssertTrue(viewModel.isInviteSheetPresented)
        XCTAssertEqual(viewModel.groups.map(\.id), [response.id])
        XCTAssertEqual(viewModel.groups.map(\.name), [response.name])
        XCTAssertEqual(viewModel.inviteCode, response.inviteCode)
        let storedGroups = try await store.fetchGroups()
        XCTAssertEqual(storedGroups.map(\.id), [response.id])

        let restoredViewModel = ShareViewModel(store: store)
        await restoredViewModel.loadInviteCode(
            groupID: response.id,
            using: UnavailableShareGroupAPI()
        )
        XCTAssertEqual(restoredViewModel.inviteCode(for: response.id), response.inviteCode)

        viewModel.completeInvitation()
        XCTAssertEqual(viewModel.groups.count, 1)
    }

    @MainActor
    func testLoadsGroupDetailInviteCodeAndSharedAlbums() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = StubShareGroupAPI(
            groupListResponse: ShareGroupListPageResponse(
                items: [ShareGroupSummaryResponse(
                    id: groupID,
                    name: "우리 가족",
                    myRole: .host,
                    memberCount: 4,
                    sharedAlbumCount: 1,
                    photoCount: 42,
                    joinedAt: "2026-07-03T10:15:30Z",
                    updatedAt: "2026-07-03T10:15:30Z"
                )],
                nextCursor: nil,
                hasNext: false
            ),
            groupDetailResponse: ShareGroupDetailResponse(
                id: groupID,
                name: "우리 가족",
                myRole: .member,
                createdBy: ShareGroupUserResponse(userId: nil, displayName: "집집이"),
                memberCount: 4,
                sharedAlbumCount: 1,
                photoCount: 42,
                createdAt: "2026-07-01T10:15:30Z",
                updatedAt: "2026-07-03T10:15:30Z"
            ),
            inviteCodeResponse: InviteCodeResponse(sharedGroupId: groupID, inviteCode: "ZZ7K9P2Q"),
            sharedAlbumListResponse: SharedAlbumListPageResponse(
                items: [SharedAlbumResponse(
                    id: albumID,
                    name: "제주도",
                    photoCount: 42,
                    createdBy: nil,
                    isCreator: true,
                    createdAt: "2026-07-02T10:15:30Z",
                    updatedAt: "2026-07-03T10:15:30Z"
                )],
                nextCursor: nil,
                hasNext: false
            )
        )
        let viewModel = ShareViewModel(store: try makeStore())

        await viewModel.loadGroups(using: api)
        await viewModel.loadGroup(id: groupID, using: api)
        await viewModel.loadSharedAlbums(groupID: groupID, using: api)
        await viewModel.loadInviteCode(groupID: groupID, using: api)

        let group = try XCTUnwrap(viewModel.group(withID: groupID))
        XCTAssertEqual(group.currentUserRole, .participant)
        XCTAssertEqual(group.createdBy?.displayName, "집집이")
        XCTAssertEqual(group.albums.map(\.id), [albumID])
        XCTAssertEqual(group.albums.map(\.count), [42])
        XCTAssertEqual(viewModel.inviteCode(for: groupID), "ZZ7K9P2Q")
        XCTAssertTrue(viewModel.hasLoadedSharedAlbums(groupID: groupID))
    }

    @MainActor
    func testResetRemoteDataClearsLoadedGroups() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = StubShareGroupAPI(
            groupListResponse: ShareGroupListPageResponse(
                items: [ShareGroupSummaryResponse(
                    id: groupID,
                    name: "우리 가족",
                    myRole: .host,
                    memberCount: 1,
                    sharedAlbumCount: 0,
                    photoCount: 0,
                    joinedAt: "2026-07-03T10:15:30Z",
                    updatedAt: "2026-07-03T10:15:30Z"
                )],
                nextCursor: nil,
                hasNext: false
            )
        )
        let viewModel = ShareViewModel(store: try makeStore())

        await viewModel.loadGroups(using: api)
        viewModel.resetRemoteData()

        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertFalse(viewModel.hasLoadedGroups)
    }

    @MainActor
    func testLoadsNextGroupPageWithoutDuplicates() async throws {
        let firstID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let secondID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let first = ShareGroupSummaryResponse(
            id: firstID,
            name: "첫 번째",
            myRole: .host,
            memberCount: 1,
            sharedAlbumCount: 0,
            photoCount: 0,
            joinedAt: "2026-07-03T10:15:30Z",
            updatedAt: "2026-07-03T10:15:30Z"
        )
        let second = ShareGroupSummaryResponse(
            id: secondID,
            name: "두 번째",
            myRole: .member,
            memberCount: 2,
            sharedAlbumCount: 0,
            photoCount: 0,
            joinedAt: "2026-07-02T10:15:30Z",
            updatedAt: "2026-07-02T10:15:30Z"
        )
        let api = StubShareGroupAPI(
            groupListResponse: ShareGroupListPageResponse(
                items: [first],
                nextCursor: "opaque-cursor",
                hasNext: true
            ),
            nextGroupListResponse: ShareGroupListPageResponse(
                items: [first, second],
                nextCursor: nil,
                hasNext: false
            )
        )
        let viewModel = ShareViewModel(store: try makeStore())

        await viewModel.loadGroups(using: api)
        await viewModel.loadMoreGroupsIfNeeded(currentGroupID: firstID, using: api)

        XCTAssertEqual(viewModel.groups.map(\.id), [firstID, secondID])
    }

    @MainActor
    func testLoadsGroupsAndAlbumsFromDatabaseWhenNetworkIsUnavailable() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let store = try makeStore()
        let onlineViewModel = ShareViewModel(store: store)
        let api = StubShareGroupAPI(
            groupListResponse: ShareGroupListPageResponse(
                items: [ShareGroupSummaryResponse(
                    id: groupID,
                    name: "우리 가족",
                    myRole: .host,
                    memberCount: 4,
                    sharedAlbumCount: 1,
                    photoCount: 42,
                    joinedAt: "2026-07-03T10:15:30Z",
                    updatedAt: "2026-07-03T10:15:30Z"
                )],
                nextCursor: nil,
                hasNext: false
            ),
            sharedAlbumListResponse: SharedAlbumListPageResponse(
                items: [SharedAlbumResponse(
                    id: albumID,
                    name: "제주도",
                    photoCount: 42,
                    createdBy: nil,
                    isCreator: true,
                    createdAt: "2026-07-02T10:15:30Z",
                    updatedAt: "2026-07-03T10:15:30Z"
                )],
                nextCursor: nil,
                hasNext: false
            )
        )

        await onlineViewModel.loadGroups(using: api)
        await onlineViewModel.loadSharedAlbums(groupID: groupID, using: api)

        let offlineViewModel = ShareViewModel(store: store)
        await offlineViewModel.loadGroups(using: UnavailableShareGroupAPI())

        XCTAssertEqual(offlineViewModel.groups.map(\.id), [groupID])
        XCTAssertEqual(offlineViewModel.group(withID: groupID)?.albums.map(\.id), [albumID])
        XCTAssertEqual(offlineViewModel.group(withID: groupID)?.albums.map(\.count), [42])
    }

    private func makeStore() throws -> SharedGroupStore {
        SharedGroupStore(database: try appDatabase())
    }
}

private struct StubShareGroupAPI: ShareGroupAPI {
    var groupListResponse = ShareGroupListPageResponse(items: [], nextCursor: nil, hasNext: false)
    var nextGroupListResponse: ShareGroupListPageResponse?
    var groupDetailResponse: ShareGroupDetailResponse?
    var inviteCodeResponse: InviteCodeResponse?
    var sharedAlbumListResponse = SharedAlbumListPageResponse(items: [], nextCursor: nil, hasNext: false)
    var createResponse: CreateSharedGroupResponse?

    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        cursor == nil ? groupListResponse : nextGroupListResponse ?? groupListResponse
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        try XCTUnwrap(groupDetailResponse)
    }

    func fetchInviteCode(groupID: UUID) async throws -> InviteCodeResponse {
        try XCTUnwrap(inviteCodeResponse)
    }

    func fetchSharedAlbums(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedAlbumListPageResponse {
        sharedAlbumListResponse
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse {
        try XCTUnwrap(createResponse)
    }
}

private struct UnavailableShareGroupAPI: ShareGroupAPI {
    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        throw URLError(.notConnectedToInternet)
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        throw URLError(.notConnectedToInternet)
    }

    func fetchInviteCode(groupID: UUID) async throws -> InviteCodeResponse {
        throw URLError(.notConnectedToInternet)
    }

    func fetchSharedAlbums(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedAlbumListPageResponse {
        throw URLError(.notConnectedToInternet)
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse {
        throw URLError(.notConnectedToInternet)
    }
}
