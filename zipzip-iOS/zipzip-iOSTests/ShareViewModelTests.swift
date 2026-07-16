import SQLiteData
import XCTest
@testable import zipzip_iOS

private let testCacheOwnerID = UUID()

extension ShareGroupAPI {
    func createSharedAlbum(
        groupID: UUID,
        name: String,
        idempotencyKey: UUID
    ) async throws -> SharedAlbumResponse {
        throw URLError(.unsupportedURL)
    }

    func renameSharedAlbum(id: UUID, name: String) async throws -> SharedAlbumRenameResponse {
        throw URLError(.unsupportedURL)
    }

    func deleteSharedAlbum(id: UUID) async throws {
        throw URLError(.unsupportedURL)
    }

    func deleteSharedAlbums(
        ids: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedAlbumBulkDeleteResponse {
        throw URLError(.unsupportedURL)
    }
}

final class ShareViewModelTests: XCTestCase {
    @MainActor
    func testCreateGroupImmediatelyAddsResponseToGroups() async throws {
        let response = CreateSharedGroupResponse(
            id: try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111")),
            name: "우리 가족",
            inviteCode: "ZZ7K9P2Q",
            myRole: .host,
            createdBy: ShareGroupUserResponse(
                userId: try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222")),
                displayName: "집집이"
            ),
            createdAt: "2026-07-03T10:15:30Z"
        )
        let store = try makeStore()
        let viewModel = ShareViewModel(
            groups: [],
            repository: try await makePreparedRepository(
                api: StubShareGroupAPI(createResponse: response),
                store: store
            )
        )
        viewModel.enterAddMode()
        viewModel.presentCreateSheet()
        viewModel.groupNameDraft = "우리 가족"

        await viewModel.createGroup()

        XCTAssertFalse(viewModel.isCreateSheetPresented)
        XCTAssertFalse(viewModel.isInviteSheetPresented)
        XCTAssertEqual(viewModel.displayedSheet, .createGroup)
        viewModel.shareSheetDidDismiss()

        XCTAssertFalse(viewModel.isCreateSheetPresented)
        XCTAssertTrue(viewModel.isInviteSheetPresented)
        XCTAssertEqual(viewModel.groups.map(\.id), [response.id])
        XCTAssertEqual(viewModel.groups.map(\.name), [response.name])
        XCTAssertEqual(viewModel.inviteCode, response.inviteCode)
        let storedGroups = try await store.fetchGroups()
        XCTAssertEqual(storedGroups.map(\.id), [response.id])
        let storedGroup = try XCTUnwrap(storedGroups.first)
        XCTAssertEqual(storedGroup.role, ShareGroupRoleResponse.host.rawValue)
        XCTAssertEqual(storedGroup.createdByUserID, response.createdBy.userId)
        XCTAssertEqual(storedGroup.createdByDisplayName, response.createdBy.displayName)
        XCTAssertEqual(storedGroup.date.timeIntervalSince1970, 1_783_073_730, accuracy: 0.001)

        let restoredViewModel = ShareViewModel(
            repository: try await makePreparedRepository(
                api: UnavailableShareGroupAPI(),
                store: store
            )
        )
        await restoredViewModel.loadInviteCode(groupID: response.id)
        XCTAssertEqual(restoredViewModel.inviteCode(for: response.id), response.inviteCode)

        viewModel.dismissPresentedSheet()
        viewModel.shareSheetDidDismiss()
        XCTAssertFalse(viewModel.isAddMode)
        XCTAssertTrue(viewModel.groupNameDraft.isEmpty)
        XCTAssertEqual(viewModel.groups.count, 1)
    }

    @MainActor
    func testCreateGroupFailureKeepsSheetOpen() async throws {
        let viewModel = ShareViewModel(
            groups: [],
            repository: try await makePreparedRepository(
                api: UnavailableShareGroupAPI(),
                store: try makeStore()
            )
        )
        viewModel.presentCreateSheet()
        viewModel.groupNameDraft = "우리 가족"

        await viewModel.createGroup()

        XCTAssertTrue(viewModel.isCreateSheetPresented)
        XCTAssertFalse(viewModel.isInviteSheetPresented)
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    @MainActor
    func testGroupListCanBeLoadedAfterFailure() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .host,
            groupListErrors: [.noResponse, nil]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)

        XCTAssertTrue(viewModel.groups.isEmpty)

        await viewModel.loadGroups(for: testCacheOwnerID, refresh: true)

        XCTAssertEqual(viewModel.groups.map(\.id), [groupID])
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
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadGroup(id: groupID)
        await viewModel.loadSharedAlbums(groupID: groupID)
        await viewModel.loadInviteCode(groupID: groupID)

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
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.resetRemoteData()

        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertFalse(viewModel.hasLoadedGroups)
    }

    @MainActor
    func testCancelledGroupLoadDoesNotPresentErrorAlert() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .host,
            cancelsGroupListRequest: true
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)

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
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadMoreGroupsIfNeeded(currentGroupID: firstID)

        XCTAssertEqual(viewModel.groups.map(\.id), [firstID, secondID])
    }

    @MainActor
    func testCompletedGroupRefreshRemovesGroupsMissingFromServer() async throws {
        let staleID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let currentID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: staleID,
            role: .host,
            groupListResponses: [
                makeGroupListResponse(id: staleID, name: "탈퇴 전 그룹"),
                makeGroupListResponse(id: currentID, name: "현재 그룹")
            ]
        )
        let store = try makeStore()
        let repository = try await makePreparedRepository(api: api, store: store)

        _ = try await repository.syncGroups(cursor: nil, size: 20)
        _ = try await repository.syncGroups(cursor: nil, size: 20)

        let storedGroupIDs = try await repository.groups().map(\.id)
        XCTAssertEqual(storedGroupIDs, [currentID])
    }

    @MainActor
    func testGroupRefreshReconcilesOnlyAfterLastPageCompletes() async throws {
        let staleID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstPageID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let lastPageID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: staleID,
            role: .host,
            groupListResponses: [
                makeGroupListResponse(id: staleID, name: "탈퇴 전 그룹"),
                ShareGroupListPageResponse(
                    items: makeGroupListResponse(id: firstPageID, name: "첫 페이지").items,
                    nextCursor: "next-page",
                    hasNext: true
                ),
                makeGroupListResponse(id: lastPageID, name: "마지막 페이지")
            ]
        )
        let store = try makeStore()
        let repository = try await makePreparedRepository(api: api, store: store)

        _ = try await repository.syncGroups(cursor: nil, size: 20)
        _ = try await repository.syncGroups(cursor: nil, size: 20)

        let groupIDsBeforeCompletion = try await repository.groups().map(\.id)
        XCTAssertEqual(
            Set(groupIDsBeforeCompletion),
            Set([staleID, firstPageID])
        )

        _ = try await repository.syncGroups(cursor: "next-page", size: 20)

        let groupIDsAfterCompletion = try await repository.groups().map(\.id)
        XCTAssertEqual(
            Set(groupIDsAfterCompletion),
            Set([firstPageID, lastPageID])
        )
    }

    @MainActor
    func testGroupPaginationStopsWhenServerRepeatsCursor() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let page = ShareGroupListPageResponse(
            items: [makeGroupListResponse(id: groupID, name: "우리 가족").items[0]],
            nextCursor: "same-group-cursor",
            hasNext: true
        )
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .host,
            groupListResponses: [page, page]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadMoreGroupsIfNeeded(currentGroupID: groupID)
        await viewModel.loadMoreGroupsIfNeeded(currentGroupID: groupID)

        XCTAssertEqual(api.groupListRequestCount, 2)
    }

    @MainActor
    func testSharedAlbumPaginationStopsWhenServerRepeatsCursor() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstAlbumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let secondAlbumID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .host,
            sharedAlbumPages: [
                SharedAlbumListPageResponse(
                    items: [makeSharedAlbum(id: firstAlbumID, name: "첫 번째")],
                    nextCursor: "same-album-cursor",
                    hasNext: true
                ),
                SharedAlbumListPageResponse(
                    items: [makeSharedAlbum(id: secondAlbumID, name: "두 번째")],
                    nextCursor: "same-album-cursor",
                    hasNext: true
                )
            ]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)
        await viewModel.loadMoreSharedAlbumsIfNeeded(
            groupID: groupID,
            currentAlbumID: firstAlbumID
        )
        await viewModel.loadMoreSharedAlbumsIfNeeded(
            groupID: groupID,
            currentAlbumID: secondAlbumID
        )

        XCTAssertEqual(api.sharedAlbumCursors.count, 2)
        XCTAssertEqual(viewModel.group(withID: groupID)?.albums.map(\.id), [firstAlbumID, secondAlbumID])
    }

    @MainActor
    func testLoadsGroupsAndAlbumsFromDatabaseWhenNetworkIsUnavailable() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let store = try makeStore()
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
        let onlineViewModel = ShareViewModel(
            repository: makeRepository(api: api, store: store)
        )

        await onlineViewModel.loadGroups(for: testCacheOwnerID)
        await onlineViewModel.loadSharedAlbums(groupID: groupID)

        let offlineViewModel = ShareViewModel(
            repository: makeRepository(api: UnavailableShareGroupAPI(), store: store)
        )
        await offlineViewModel.loadGroups(for: testCacheOwnerID)

        XCTAssertEqual(offlineViewModel.groups.map(\.id), [groupID])
        XCTAssertEqual(offlineViewModel.group(withID: groupID)?.albums.map(\.id), [albumID])
        XCTAssertEqual(offlineViewModel.group(withID: groupID)?.albums.map(\.count), [42])
    }

    @MainActor
    func testChangingAuthenticatedUserClearsPreviousSharedCache() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstUserID = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
        let secondUserID = try XCTUnwrap(UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        let store = try makeStore()
        let onlineViewModel = ShareViewModel(
            repository: makeRepository(
                api: StubShareGroupAPI(
                    groupListResponse: ShareGroupListPageResponse(
                        items: [ShareGroupSummaryResponse(
                            id: groupID,
                            name: "첫 번째 계정의 공유 그룹",
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
                ),
                store: store
            )
        )
        await onlineViewModel.loadGroups(for: firstUserID)
        XCTAssertEqual(onlineViewModel.groups.map(\.id), [groupID])

        let switchedViewModel = ShareViewModel(
            repository: makeRepository(api: UnavailableShareGroupAPI(), store: store)
        )
        await switchedViewModel.loadGroups(for: secondUserID)

        XCTAssertTrue(switchedViewModel.groups.isEmpty)
        let storedGroups = try await store.fetchGroups()
        XCTAssertTrue(storedGroups.isEmpty)
    }

    @MainActor
    func testAccountSwitchSupersedesInFlightGroupLoad() async throws {
        let firstGroupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let secondGroupID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let firstUserID = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
        let secondUserID = try XCTUnwrap(UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: firstGroupID,
            role: .host,
            groupListResponses: [
                makeGroupListResponse(id: firstGroupID, name: "첫 번째 계정"),
                makeGroupListResponse(id: secondGroupID, name: "두 번째 계정")
            ],
            groupListDelays: [.milliseconds(100), .zero]
        )
        let store = try makeStore()
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))

        let firstLoad = Task {
            await viewModel.loadGroups(for: firstUserID)
        }
        while api.groupListRequestCount < 1 {
            await Task.yield()
        }
        await viewModel.loadGroups(for: secondUserID)
        await firstLoad.value

        XCTAssertEqual(api.groupListRequestCount, 2)
        XCTAssertEqual(viewModel.groups.map(\.id), [secondGroupID])
        let storedGroups = try await store.fetchGroups()
        XCTAssertEqual(storedGroups.map(\.id), [secondGroupID])
    }

    @MainActor
    func testAccountSwitchRejectsInFlightGroupDetailCacheWrite() async throws {
        let firstGroupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let secondGroupID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let firstUserID = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
        let secondUserID = try XCTUnwrap(UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: firstGroupID,
            role: .host,
            groupListResponses: [
                makeGroupListResponse(id: firstGroupID, name: "첫 번째 계정"),
                makeGroupListResponse(id: secondGroupID, name: "두 번째 계정")
            ],
            groupDetailDelay: .milliseconds(100)
        )
        let store = try makeStore()
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))
        await viewModel.loadGroups(for: firstUserID)

        let detailLoad = Task {
            await viewModel.loadGroup(id: firstGroupID, refresh: true)
        }
        while api.groupDetailRequestCount < 1 {
            await Task.yield()
        }
        await viewModel.loadGroups(for: secondUserID)
        await detailLoad.value

        XCTAssertEqual(viewModel.groups.map(\.id), [secondGroupID])
        let storedGroups = try await store.fetchGroups()
        XCTAssertEqual(storedGroups.map(\.id), [secondGroupID])
        XCTAssertEqual(storedGroups.map(\.name), ["두 번째 계정"])
    }

    @MainActor
    func testPreviewsAndJoinsGroupWithSameLogicalRequest() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = JoinTrackingShareGroupAPI(
            previewResponse: makeJoinPreview(groupID: groupID, alreadyJoined: false),
            joinResponse: ShareGroupJoinResponse(
                sharedGroupId: groupID,
                name: "여행 친구",
                myRole: .member,
                joinedAt: "2026-07-15T10:15:30Z"
            )
        )
        let viewModel = ShareViewModel(
            groups: [],
            repository: try await makePreparedRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "  ZZ7K9P2Q  "

        await viewModel.confirmJoinCode()

        XCTAssertFalse(viewModel.isJoinSheetPresented)
        XCTAssertFalse(viewModel.isJoinConfirmationPresented)
        XCTAssertEqual(viewModel.displayedSheet, .joinEntry)
        viewModel.shareSheetDidDismiss()

        XCTAssertFalse(viewModel.isJoinSheetPresented)
        XCTAssertTrue(viewModel.isJoinConfirmationPresented)
        XCTAssertEqual(viewModel.pendingJoinGroup?.id, groupID)
        XCTAssertEqual(
            viewModel.pendingJoinPreview?.representativeImageURL?.absoluteString,
            "https://cdn.example.com/group.jpg"
        )
        XCTAssertEqual(viewModel.pendingJoinPreview?.group.createdBy?.displayName, "집집이")
        XCTAssertEqual(viewModel.pendingJoinPreview?.members.map(\.displayName), ["집집이"])
        XCTAssertEqual(api.previewInviteCodes, ["ZZ7K9P2Q"])

        let joinedGroupID = await viewModel.completeJoin()

        XCTAssertEqual(joinedGroupID, groupID)
        XCTAssertEqual(viewModel.groups.map(\.id), [groupID])
        XCTAssertEqual(viewModel.completedJoinNavigationGroupID, groupID)
        XCTAssertFalse(viewModel.isJoinConfirmationPresented)
        XCTAssertEqual(api.joinInviteCodes, ["ZZ7K9P2Q"])
        XCTAssertEqual(api.joinIdempotencyKeys.count, 1)
    }

    @MainActor
    func testAlreadyJoinedPreviewSkipsJoinRequest() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = JoinTrackingShareGroupAPI(
            previewResponse: makeJoinPreview(groupID: groupID, alreadyJoined: true),
            joinResponse: nil
        )
        let viewModel = ShareViewModel(
            groups: [],
            repository: try await makePreparedRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "ZZ7K9P2Q"

        await viewModel.confirmJoinCode()
        viewModel.shareSheetDidDismiss()
        let joinedGroupID = await viewModel.completeJoin()

        XCTAssertEqual(joinedGroupID, groupID)
        XCTAssertTrue(api.joinInviteCodes.isEmpty)
        XCTAssertEqual(api.fetchedGroupIDs, [groupID])
    }

    @MainActor
    func testJoinConflictSyncsExistingGroupWithoutSecondPost() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = JoinTrackingShareGroupAPI(
            previewResponse: makeJoinPreview(groupID: groupID, alreadyJoined: false),
            joinResponse: nil,
            joinErrors: [.server(
                statusCode: 409,
                code: "ALREADY_JOINED_SHARED_GROUP",
                message: nil,
                body: nil
            )]
        )
        let viewModel = ShareViewModel(
            groups: [],
            repository: try await makePreparedRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "ZZ7K9P2Q"
        await viewModel.confirmJoinCode()
        viewModel.shareSheetDidDismiss()

        let joinedGroupID = await viewModel.completeJoin()

        XCTAssertEqual(joinedGroupID, groupID)
        XCTAssertEqual(api.joinInviteCodes.count, 1)
        XCTAssertEqual(api.fetchedGroupIDs, [groupID])
        XCTAssertEqual(viewModel.groups.map(\.id), [groupID])
    }

    @MainActor
    func testJoinSyncFailureKeepsConfirmationAndRetryDoesNotRepeatPost() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = JoinTrackingShareGroupAPI(
            previewResponse: makeJoinPreview(groupID: groupID, alreadyJoined: false),
            joinResponse: ShareGroupJoinResponse(
                sharedGroupId: groupID,
                name: "여행 친구",
                myRole: .member,
                joinedAt: "2026-07-15T10:15:30Z"
            ),
            groupDetailErrors: [.noResponse, nil]
        )
        let viewModel = ShareViewModel(
            groups: [],
            repository: try await makePreparedRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "ZZ7K9P2Q"
        await viewModel.confirmJoinCode()
        viewModel.shareSheetDidDismiss()

        let firstResult = await viewModel.completeJoin()

        XCTAssertNil(firstResult)
        XCTAssertTrue(viewModel.isJoinConfirmationPresented)
        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertEqual(api.joinInviteCodes.count, 1)

        _ = await viewModel.completeJoin()

        XCTAssertEqual(api.joinInviteCodes.count, 1)
        XCTAssertEqual(viewModel.groups.map(\.id), [groupID])
        XCTAssertEqual(viewModel.completedJoinNavigationGroupID, groupID)
        XCTAssertFalse(viewModel.isJoinConfirmationPresented)
    }

    @MainActor
    func testAlreadyJoinedSyncFailureRetriesWithoutJoinRequest() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = JoinTrackingShareGroupAPI(
            previewResponse: makeJoinPreview(groupID: groupID, alreadyJoined: true),
            joinResponse: nil,
            groupDetailErrors: [.noResponse, nil]
        )
        let viewModel = ShareViewModel(
            groups: [],
            repository: try await makePreparedRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "ZZ7K9P2Q"
        await viewModel.confirmJoinCode()
        viewModel.shareSheetDidDismiss()

        let firstResult = await viewModel.completeJoin()

        XCTAssertNil(firstResult)
        XCTAssertTrue(viewModel.isJoinConfirmationPresented)
        XCTAssertTrue(api.joinInviteCodes.isEmpty)
        XCTAssertEqual(api.fetchedGroupIDs, [groupID])

        _ = await viewModel.completeJoin()

        XCTAssertTrue(api.joinInviteCodes.isEmpty)
        XCTAssertEqual(api.fetchedGroupIDs, [groupID, groupID])
        XCTAssertEqual(viewModel.groups.map(\.id), [groupID])
        XCTAssertEqual(viewModel.completedJoinNavigationGroupID, groupID)
        XCTAssertFalse(viewModel.isJoinConfirmationPresented)
    }

    @MainActor
    func testDismissingJoinConfirmationClearsPendingJoinRequest() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = JoinTrackingShareGroupAPI(
            previewResponse: makeJoinPreview(groupID: groupID, alreadyJoined: false),
            joinResponse: ShareGroupJoinResponse(
                sharedGroupId: groupID,
                name: "여행 친구",
                myRole: .member,
                joinedAt: "2026-07-15T10:15:30Z"
            )
        )
        let viewModel = ShareViewModel(
            groups: [],
            repository: makeRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "ZZ7K9P2Q"
        await viewModel.confirmJoinCode()
        viewModel.shareSheetDidDismiss()

        viewModel.dismissPresentedSheet()
        viewModel.shareSheetDidDismiss()
        let joinResult = await viewModel.completeJoin()

        XCTAssertFalse(viewModel.isJoinConfirmationPresented)
        XCTAssertNil(viewModel.pendingJoinPreview)
        XCTAssertNil(joinResult)
        XCTAssertTrue(api.joinInviteCodes.isEmpty)
    }

    @MainActor
    func testLoadsAllMemberPagesWithoutDuplicates() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstMemberID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let secondMemberID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .host,
            memberPages: [
                ShareGroupMemberListPageResponse(
                    items: [makeMember(id: firstMemberID, role: .host, isMe: true)],
                    nextCursor: "next-member",
                    hasNext: true
                ),
                ShareGroupMemberListPageResponse(
                    items: [
                        makeMember(id: firstMemberID, role: .host, isMe: true),
                        makeMember(id: secondMemberID, role: .member, isMe: false)
                    ],
                    nextCursor: nil,
                    hasNext: false
                )
            ]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )

        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadMembers(groupID: groupID)

        XCTAssertEqual(viewModel.members(for: groupID).map(\.id), [firstMemberID, secondMemberID])
        XCTAssertEqual(api.memberCursors.count, 2)
        XCTAssertNil(api.memberCursors[0])
        XCTAssertEqual(api.memberCursors[1], "next-member")
    }

    @MainActor
    func testMemberPaginationStopsWhenServerRepeatsCursor() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstMemberID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let secondMemberID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .host,
            memberPages: [
                ShareGroupMemberListPageResponse(
                    items: [makeMember(id: firstMemberID, role: .host, isMe: true)],
                    nextCursor: "same-member-cursor",
                    hasNext: true
                ),
                ShareGroupMemberListPageResponse(
                    items: [makeMember(id: secondMemberID, role: .member, isMe: false)],
                    nextCursor: "same-member-cursor",
                    hasNext: true
                )
            ]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)

        await viewModel.loadMembers(groupID: groupID)

        XCTAssertEqual(api.memberCursors.count, 2)
        XCTAssertEqual(viewModel.members(for: groupID).map(\.id), [firstMemberID, secondMemberID])
    }

    @MainActor
    func testHostCanRenameAndDeleteManagedGroup() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(groupID: groupID, role: .host)
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentShareManagement(groupID: groupID)
        viewModel.shareGroupNameDraft = "  여름 여행  "

        await viewModel.completeShareManagement()

        XCTAssertEqual(api.updatedNames, ["여름 여행"])
        XCTAssertEqual(viewModel.group(withID: groupID)?.name, "여름 여행")
        XCTAssertFalse(viewModel.isShareManagementPresented)

        viewModel.shareSheetDidDismiss()
        viewModel.presentShareManagement(groupID: groupID)
        let didLeave = await viewModel.leaveManagedShareGroup()

        XCTAssertTrue(didLeave)
        XCTAssertEqual(api.deletedGroupIDs, [groupID])
        XCTAssertTrue(api.leftGroupIDs.isEmpty)
        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertFalse(viewModel.isShareManagementPresented)
    }

    @MainActor
    func testRemoteGroupDeleteThenLocalFailureReconcilesOnNotFoundRetry() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .host,
            deleteGroupErrors: [
                nil,
                .server(
                    statusCode: 404,
                    code: "SHARED_GROUP_NOT_FOUND",
                    message: "not found",
                    body: nil
                )
            ]
        )
        let database = try appDatabase()
        let store = SharedGroupStore(database: database)
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentShareManagement(groupID: groupID)
        try await database.write { db in
            try #sql(
                """
                CREATE TRIGGER "fail_shared_group_delete"
                BEFORE DELETE ON "shared_group"
                BEGIN
                  SELECT RAISE(ABORT, 'forced local delete failure');
                END
                """
            )
            .execute(db)
        }

        let firstAttempt = await viewModel.leaveManagedShareGroup()

        XCTAssertFalse(firstAttempt)
        let groupsAfterLocalFailure = try await store.fetchGroups()
        XCTAssertEqual(groupsAfterLocalFailure.map(\.id), [groupID])
        try await database.write { db in
            try #sql(#"DROP TRIGGER "fail_shared_group_delete""#).execute(db)
        }

        let retry = await viewModel.leaveManagedShareGroup()

        XCTAssertTrue(retry)
        XCTAssertEqual(api.deletedGroupIDs, [groupID, groupID])
        let groupsAfterRetry = try await store.fetchGroups()
        XCTAssertTrue(groupsAfterRetry.isEmpty)
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    @MainActor
    func testRemoteMemberLeaveThenLocalFailureReconcilesOnNotFoundRetry() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            leaveGroupErrors: [
                nil,
                .server(
                    statusCode: 404,
                    code: "SHARED_GROUP_NOT_FOUND",
                    message: "not found",
                    body: nil
                )
            ]
        )
        let database = try appDatabase()
        let store = SharedGroupStore(database: database)
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentShareManagement(groupID: groupID)
        try await database.write { db in
            try #sql(
                """
                CREATE TRIGGER "fail_shared_group_delete"
                BEFORE DELETE ON "shared_group"
                BEGIN
                  SELECT RAISE(ABORT, 'forced local delete failure');
                END
                """
            )
            .execute(db)
        }

        let firstAttempt = await viewModel.leaveManagedShareGroup()

        XCTAssertFalse(firstAttempt)
        let groupsAfterLocalFailure = try await store.fetchGroups()
        XCTAssertEqual(groupsAfterLocalFailure.map(\.id), [groupID])
        try await database.write { db in
            try #sql(#"DROP TRIGGER "fail_shared_group_delete""#).execute(db)
        }

        let retry = await viewModel.leaveManagedShareGroup()

        XCTAssertTrue(retry)
        XCTAssertEqual(api.leftGroupIDs, [groupID, groupID])
        XCTAssertTrue(api.deletedGroupIDs.isEmpty)
        let groupsAfterRetry = try await store.fetchGroups()
        XCTAssertTrue(groupsAfterRetry.isEmpty)
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    @MainActor
    func testMemberSkipsRenameAndUsesLeaveEndpoint() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(groupID: groupID, role: .member)
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentShareManagement(groupID: groupID)
        viewModel.shareGroupNameDraft = "수정 시도"

        await viewModel.completeShareManagement()

        XCTAssertTrue(api.updatedNames.isEmpty)
        XCTAssertTrue(viewModel.isShareManagementPresented)
        let didLeave = await viewModel.leaveManagedShareGroup()

        XCTAssertTrue(didLeave)
        XCTAssertEqual(api.leftGroupIDs, [groupID])
        XCTAssertTrue(api.deletedGroupIDs.isEmpty)
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    @MainActor
    func testLoadsChatTimelineOnePageAtATimeInChronologicalOrder() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let newerID = try XCTUnwrap(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let middleID = try XCTUnwrap(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        let olderID = try XCTUnwrap(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            chatPages: [
                ChatTimelinePageResponse(
                    items: [makeChatItem(id: newerID, content: "최신")],
                    nextCursor: "older-chat",
                    hasNext: true
                ),
                ChatTimelinePageResponse(
                    items: [
                        makeChatItem(id: newerID, content: "최신"),
                        makeChatItem(id: middleID, content: "중간")
                    ],
                    nextCursor: "oldest-chat",
                    hasNext: true
                ),
                ChatTimelinePageResponse(
                    items: [
                        makeChatItem(id: middleID, content: "중간"),
                        makeChatItem(id: olderID, content: "이전")
                    ],
                    nextCursor: nil,
                    hasNext: false
                )
            ]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentComments(groupID: groupID)

        await viewModel.loadChatTimeline()

        XCTAssertEqual(viewModel.chatItems.map(\.id), [newerID])
        XCTAssertEqual(api.chatCursors.count, 1)
        XCTAssertNil(api.chatCursors[0])

        await viewModel.loadOlderChat()

        XCTAssertEqual(viewModel.chatItems.map(\.id), [middleID, newerID])
        XCTAssertEqual(api.chatCursors.count, 2)
        XCTAssertEqual(api.chatCursors[1], "older-chat")

        await viewModel.loadOlderChat()

        XCTAssertEqual(viewModel.chatItems.map(\.id), [olderID, middleID, newerID])
        XCTAssertEqual(api.chatCursors.count, 3)
        XCTAssertEqual(api.chatCursors[2], "oldest-chat")
    }

    @MainActor
    func testSendsChatMessageAndMergesResponseWithoutReloadingTimeline() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstID = try XCTUnwrap(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let sentID = try XCTUnwrap(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            chatPages: [
                ChatTimelinePageResponse(
                    items: [makeChatItem(id: firstID, content: "기존")],
                    nextCursor: nil,
                    hasNext: false
                )
            ],
            createdChatMessageResponse: makeChatMessage(id: sentID, content: "사진 더 올려줘")
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentComments(groupID: groupID)
        await viewModel.loadChatTimeline()
        viewModel.commentDraft = "  사진 더 올려줘  "

        await viewModel.sendChatMessage()

        XCTAssertEqual(api.sentChatContents, ["사진 더 올려줘"])
        XCTAssertEqual(api.chatIdempotencyKeys.count, 1)
        XCTAssertEqual(api.chatCursors.count, 1)
        XCTAssertEqual(viewModel.chatItems.map(\.id), [firstID, sentID])
        XCTAssertTrue(viewModel.commentDraft.isEmpty)
    }

    @MainActor
    func testChatPaginationStopsWhenServerRepeatsCursor() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let newerID = try XCTUnwrap(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let olderID = try XCTUnwrap(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            chatPages: [
                ChatTimelinePageResponse(
                    items: [makeChatItem(id: newerID, content: "최신")],
                    nextCursor: "same-cursor",
                    hasNext: true
                ),
                ChatTimelinePageResponse(
                    items: [makeChatItem(id: olderID, content: "이전")],
                    nextCursor: "same-cursor",
                    hasNext: true
                )
            ]
        )
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: try makeStore()))
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentComments(groupID: groupID)
        await viewModel.loadChatTimeline()

        await viewModel.loadOlderChat()
        await viewModel.loadOlderChat()

        XCTAssertEqual(api.chatCursors.count, 2)
        XCTAssertEqual(viewModel.chatItems.map(\.id), [olderID, newerID])
    }

    @MainActor
    func testChatSendRetryKeepsDraftAndReusesIdempotencyKey() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let sentID = try XCTUnwrap(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            chatMessageErrors: [.noResponse, nil],
            createdChatMessageResponse: makeChatMessage(id: sentID, content: "다시 보내기")
        )
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: try makeStore()))
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentComments(groupID: groupID)
        viewModel.commentDraft = "다시 보내기"

        await viewModel.sendChatMessage()

        XCTAssertEqual(viewModel.commentDraft, "다시 보내기")
        XCTAssertTrue(viewModel.chatItems.isEmpty)

        await viewModel.sendChatMessage()

        XCTAssertEqual(api.chatIdempotencyKeys.count, 2)
        XCTAssertEqual(api.chatIdempotencyKeys[0], api.chatIdempotencyKeys[1])
        XCTAssertTrue(viewModel.commentDraft.isEmpty)
        XCTAssertEqual(viewModel.chatItems.map(\.id), [sentID])
    }

    @MainActor
    func testChatNotFoundClosesBusySheetAndRemovesGroup() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            chatMessageErrors: [
                .server(
                    statusCode: 404,
                    code: "SHARED_GROUP_NOT_FOUND",
                    message: "not found",
                    body: nil
                )
            ]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentComments(groupID: groupID)
        viewModel.commentDraft = "사라진 그룹 메시지"

        await viewModel.sendChatMessage()

        XCTAssertFalse(viewModel.isSendingChatMessage)
        XCTAssertFalse(viewModel.isCommentsPresented)
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    @MainActor
    func testChatSheetCannotDismissWhileMessageIsSending() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            chatMessageDelay: .milliseconds(50)
        )
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: try makeStore()))
        await viewModel.loadGroups(for: testCacheOwnerID)
        viewModel.presentComments(groupID: groupID)
        viewModel.commentDraft = "전송 중 메시지"

        let sendTask = Task { await viewModel.sendChatMessage() }
        while api.sentChatContents.isEmpty {
            await Task.yield()
        }
        viewModel.dismissComments()

        XCTAssertTrue(viewModel.isCommentsPresented)
        XCTAssertTrue(viewModel.isSendingChatMessage)

        await sendTask.value
        viewModel.dismissComments()
        viewModel.shareSheetDidDismiss()

        XCTAssertFalse(viewModel.isCommentsPresented)
        XCTAssertNil(viewModel.activeChatGroupID)
        XCTAssertTrue(viewModel.chatItems.isEmpty)
    }

    @MainActor
    func testRenamesAndDeletesManagedSharedAlbum() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbums: [makeSharedAlbum(id: albumID, name: "제주도")]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)
        let didRename = await viewModel.renameSharedAlbum(
            id: albumID,
            in: groupID,
            name: "  제주 여름  "
        )

        XCTAssertTrue(didRename)
        XCTAssertEqual(api.renamedAlbumIDs, [albumID])
        XCTAssertEqual(api.renamedAlbumNames, ["제주 여름"])
        XCTAssertEqual(viewModel.album(groupID: groupID, albumID: albumID)?.name, "제주 여름")

        let didDelete = await viewModel.deleteSharedAlbum(id: albumID, from: groupID)

        XCTAssertTrue(didDelete)
        XCTAssertEqual(api.deletedAlbumIDs, [albumID])
        XCTAssertTrue(viewModel.group(withID: groupID)?.albums.isEmpty == true)
    }

    @MainActor
    func testSharedAlbumManagementStaysPresentedUntilMutationSucceeds() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbums: [makeSharedAlbum(id: albumID, name: "제주도")],
            renameSharedAlbumErrors: [.noResponse, nil],
            deleteSharedAlbumErrors: [.noResponse, nil]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)
        var didDelete = false
        let detailViewModel = viewModel.makeSharedAlbumDetailViewModel(
            groupID: groupID,
            albumID: albumID,
            onDelete: { didDelete = true }
        )
        detailViewModel.presentAlbumManagement(albumTitle: "제주도")
        detailViewModel.albumTitleDraft = "제주 여름"

        await detailViewModel.completeAlbumManagement()

        XCTAssertTrue(detailViewModel.isAlbumManagementPresented)

        await detailViewModel.completeAlbumManagement()

        XCTAssertFalse(detailViewModel.isAlbumManagementPresented)
        XCTAssertEqual(viewModel.album(groupID: groupID, albumID: albumID)?.name, "제주 여름")

        detailViewModel.presentAlbumManagement(albumTitle: "제주 여름")
        detailViewModel.presentAlbumDeleteAlert()
        detailViewModel.completeAlbumManagementDismissal()
        await detailViewModel.confirmAlbumDeletion()

        XCTAssertTrue(detailViewModel.isAlbumDeleteAlertPresented)
        XCTAssertFalse(didDelete)

        await detailViewModel.confirmAlbumDeletion()

        XCTAssertFalse(detailViewModel.isAlbumDeleteAlertPresented)
        XCTAssertTrue(didDelete)
    }

    @MainActor
    func testRemoteSharedAlbumDeleteThenLocalFailureReconcilesOnNotFoundRetry() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbums: [makeSharedAlbum(id: albumID, name: "제주도")],
            deleteSharedAlbumErrors: [
                nil,
                .server(
                    statusCode: 404,
                    code: "SHARED_ALBUM_NOT_FOUND",
                    message: "not found",
                    body: nil
                )
            ]
        )
        let database = try appDatabase()
        let store = SharedGroupStore(database: database)
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)
        try await database.write { db in
            try #sql(
                """
                CREATE TRIGGER "fail_shared_album_delete"
                BEFORE DELETE ON "shared_album"
                BEGIN
                  SELECT RAISE(ABORT, 'forced local delete failure');
                END
                """
            )
            .execute(db)
        }

        let firstAttempt = await viewModel.deleteSharedAlbum(id: albumID, from: groupID)

        XCTAssertFalse(firstAttempt)
        let groupsAfterLocalFailure = try await store.fetchGroups()
        XCTAssertEqual(groupsAfterLocalFailure.first?.albums.map(\.id), [albumID])
        try await database.write { db in
            try #sql(#"DROP TRIGGER "fail_shared_album_delete""#).execute(db)
        }

        let retry = await viewModel.deleteSharedAlbum(id: albumID, from: groupID)

        XCTAssertTrue(retry)
        XCTAssertEqual(api.deletedAlbumIDs, [albumID, albumID])
        let groupsAfterRetry = try await store.fetchGroups()
        XCTAssertTrue(groupsAfterRetry.first?.albums.isEmpty == true)
        XCTAssertTrue(viewModel.group(withID: groupID)?.albums.isEmpty == true)
    }

    @MainActor
    func testBulkDeletesSelectedSharedAlbums() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let secondID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbums: [
                makeSharedAlbum(id: firstID, name: "제주도"),
                makeSharedAlbum(id: secondID, name: "부산")
            ]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)

        let didDelete = await viewModel.deleteSharedAlbums([firstID, secondID], from: groupID)

        XCTAssertTrue(didDelete)
        XCTAssertEqual(Set(api.bulkDeletedAlbumIDs), Set([firstID, secondID]))
        XCTAssertEqual(api.bulkDeleteIdempotencyKeys.count, 1)
        XCTAssertTrue(viewModel.group(withID: groupID)?.albums.isEmpty == true)
    }

    @MainActor
    func testSharedAlbumNotFoundRemovesExpiredGroupMembership() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbums: [makeSharedAlbum(id: albumID, name: "제주도")],
            groupDetailError: .server(
                statusCode: 404,
                code: "SHARED_GROUP_NOT_FOUND",
                message: "membership expired",
                body: nil
            ),
            deleteSharedAlbumErrors: [.server(
                statusCode: 404,
                code: "SHARED_ALBUM_NOT_FOUND",
                message: "not found",
                body: nil
            )]
        )
        let store = try makeStore()
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)

        let didDelete = await viewModel.deleteSharedAlbum(id: albumID, from: groupID)

        XCTAssertTrue(didDelete)
        XCTAssertEqual(api.deletedAlbumIDs, [albumID])
        XCTAssertTrue(viewModel.groups.isEmpty)
        let storedGroups = try await store.fetchGroups()
        XCTAssertTrue(storedGroups.isEmpty)
    }

    @MainActor
    func testBulkDeleteRetryReusesIdempotencyKeyAndKeepsAllOrNothingCache() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let secondID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbums: [
                makeSharedAlbum(id: firstID, name: "제주도"),
                makeSharedAlbum(id: secondID, name: "부산")
            ],
            bulkDeleteErrors: [.noResponse, nil]
        )
        let viewModel = ShareViewModel(
            repository: makeRepository(api: api, store: try makeStore())
        )
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)
        let albumIDs = Set([firstID, secondID])

        let firstAttempt = await viewModel.deleteSharedAlbums(albumIDs, from: groupID)

        XCTAssertFalse(firstAttempt)
        XCTAssertEqual(Set(viewModel.group(withID: groupID)?.albums.map(\.id) ?? []), albumIDs)

        let retry = await viewModel.deleteSharedAlbums(albumIDs, from: groupID)

        XCTAssertTrue(retry)
        XCTAssertEqual(api.bulkDeleteIdempotencyKeys.count, 2)
        XCTAssertEqual(api.bulkDeleteIdempotencyKeys[0], api.bulkDeleteIdempotencyKeys[1])
        XCTAssertTrue(viewModel.group(withID: groupID)?.albums.isEmpty == true)
    }

    @MainActor
    func testBulkDeleteReconciliationPreservesCacheWhenCursorRepeats() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let secondID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let firstAlbum = makeSharedAlbum(id: firstID, name: "제주도")
        let secondAlbum = makeSharedAlbum(id: secondID, name: "부산")
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbumPages: [
                SharedAlbumListPageResponse(
                    items: [firstAlbum, secondAlbum],
                    nextCursor: nil,
                    hasNext: false
                ),
                SharedAlbumListPageResponse(
                    items: [firstAlbum],
                    nextCursor: "same-reconcile-cursor",
                    hasNext: true
                ),
                SharedAlbumListPageResponse(
                    items: [firstAlbum],
                    nextCursor: "same-reconcile-cursor",
                    hasNext: true
                )
            ],
            bulkDeleteErrors: [
                .server(
                    statusCode: 404,
                    code: "SHARED_ALBUM_NOT_FOUND",
                    message: "not found",
                    body: nil
                )
            ]
        )
        let store = try makeStore()
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)

        let didDelete = await viewModel.deleteSharedAlbums([firstID, secondID], from: groupID)
        let storedAlbumIDs = Set(try await store.fetchGroups().first?.albums.map(\.id) ?? [])

        XCTAssertFalse(didDelete)
        XCTAssertEqual(storedAlbumIDs, Set([firstID, secondID]))
    }

    @MainActor
    func testRemoteBulkDeleteThenLocalFailureReconcilesOnNotFoundRetry() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let firstID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let secondID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let api = ManagementTrackingShareGroupAPI(
            groupID: groupID,
            role: .member,
            sharedAlbums: [
                makeSharedAlbum(id: firstID, name: "제주도"),
                makeSharedAlbum(id: secondID, name: "부산")
            ],
            bulkDeleteErrors: [
                nil,
                .server(
                    statusCode: 404,
                    code: "SHARED_ALBUM_NOT_FOUND",
                    message: "not found",
                    body: nil
                )
            ]
        )
        let database = try appDatabase()
        let store = SharedGroupStore(database: database)
        let viewModel = ShareViewModel(repository: makeRepository(api: api, store: store))
        await viewModel.loadGroups(for: testCacheOwnerID)
        await viewModel.loadSharedAlbums(groupID: groupID)
        let albumIDs = Set([firstID, secondID])
        try await database.write { db in
            try #sql(
                """
                CREATE TRIGGER "fail_shared_album_delete"
                BEFORE DELETE ON "shared_album"
                BEGIN
                  SELECT RAISE(ABORT, 'forced local delete failure');
                END
                """
            )
            .execute(db)
        }

        let firstAttempt = await viewModel.deleteSharedAlbums(albumIDs, from: groupID)

        XCTAssertFalse(firstAttempt)
        let groupsAfterLocalFailure = try await store.fetchGroups()
        XCTAssertEqual(Set(groupsAfterLocalFailure.first?.albums.map(\.id) ?? []), albumIDs)
        api.sharedAlbums = []
        try await database.write { db in
            try #sql(#"DROP TRIGGER "fail_shared_album_delete""#).execute(db)
        }

        let retry = await viewModel.deleteSharedAlbums(albumIDs, from: groupID)

        XCTAssertTrue(retry)
        XCTAssertEqual(api.bulkDeleteIdempotencyKeys.count, 2)
        XCTAssertEqual(api.bulkDeleteIdempotencyKeys[0], api.bulkDeleteIdempotencyKeys[1])
        let groupsAfterRetry = try await store.fetchGroups()
        XCTAssertTrue(groupsAfterRetry.first?.albums.isEmpty == true)
        XCTAssertTrue(viewModel.group(withID: groupID)?.albums.isEmpty == true)
    }

    private func makeJoinPreview(
        groupID: UUID,
        alreadyJoined: Bool
    ) -> ShareGroupJoinPreviewResponse {
        ShareGroupJoinPreviewResponse(
            sharedGroupId: groupID,
            name: "여행 친구",
            representativeImageUrl: "https://cdn.example.com/group.jpg",
            representativeImageUrlExpiresAt: "2099-07-15T10:15:30Z",
            createdBy: ShareGroupUserResponse(userId: nil, displayName: "집집이"),
            memberCount: 4,
            members: [ShareGroupMemberResponse(
                userId: UUID(),
                displayName: "집집이",
                role: .host,
                isMe: false,
                joinedAt: "2026-07-15T10:15:30Z"
            )],
            alreadyJoined: alreadyJoined
        )
    }

    private func makeMember(
        id: UUID,
        role: ShareGroupRoleResponse,
        isMe: Bool
    ) -> ShareGroupMemberResponse {
        ShareGroupMemberResponse(
            userId: id,
            displayName: isMe ? "나" : "친구",
            role: role,
            isMe: isMe,
            joinedAt: "2026-07-15T10:15:30Z"
        )
    }

    private func makeChatItem(
        id: UUID,
        content: String,
        isAuthor: Bool = false
    ) -> ChatTimelineItemResponse {
        ChatTimelineItemResponse(
            type: .chatMessage,
            id: id,
            photoId: nil,
            content: content,
            author: ChatAuthorResponse(userId: nil, displayName: "집집이"),
            isAuthor: isAuthor,
            createdAt: "2026-07-15T10:15:30Z",
            updatedAt: "2026-07-15T10:15:30Z"
        )
    }

    private func makeChatMessage(id: UUID, content: String) -> ChatMessageResponse {
        ChatMessageResponse(
            id: id,
            content: content,
            author: ChatAuthorResponse(userId: nil, displayName: "집집이"),
            isAuthor: true,
            createdAt: "2026-07-15T10:15:30Z",
            updatedAt: "2026-07-15T10:15:30Z"
        )
    }

    private func makeSharedAlbum(id: UUID, name: String) -> SharedAlbumResponse {
        SharedAlbumResponse(
            id: id,
            name: name,
            photoCount: 1,
            createdBy: nil,
            isCreator: false,
            createdAt: "2026-07-15T10:15:30Z",
            updatedAt: "2026-07-15T10:15:30Z"
        )
    }

    private func makeGroupListResponse(id: UUID, name: String) -> ShareGroupListPageResponse {
        ShareGroupListPageResponse(
            items: [ShareGroupSummaryResponse(
                id: id,
                name: name,
                myRole: .host,
                memberCount: 1,
                sharedAlbumCount: 0,
                photoCount: 0,
                joinedAt: "2026-07-15T10:15:30Z",
                updatedAt: "2026-07-15T10:15:30Z"
            )],
            nextCursor: nil,
            hasNext: false
        )
    }

    private func makeStore() throws -> SharedGroupStore {
        SharedGroupStore(database: try appDatabase())
    }

    @MainActor
    private func makeRepository(
        api: ShareGroupAPI,
        store: SharedGroupStore
    ) -> ShareGroupRepository {
        DefaultShareGroupRepository(api: api, store: store)
    }

    @MainActor
    private func makePreparedRepository(
        api: ShareGroupAPI,
        store: SharedGroupStore
    ) async throws -> ShareGroupRepository {
        let repository = makeRepository(api: api, store: store)
        try await repository.prepareCache(for: testCacheOwnerID)
        return repository
    }
}

private struct StubShareGroupAPI: ShareGroupAPI {
    var groupListResponse = ShareGroupListPageResponse(items: [], nextCursor: nil, hasNext: false)
    var nextGroupListResponse: ShareGroupListPageResponse?
    var groupDetailResponse: ShareGroupDetailResponse?
    var inviteCodeResponse: InviteCodeResponse?
    var sharedAlbumListResponse = SharedAlbumListPageResponse(items: [], nextCursor: nil, hasNext: false)
    var createResponse: CreateSharedGroupResponse?
    var joinPreviewResponse: ShareGroupJoinPreviewResponse?
    var joinResponse: ShareGroupJoinResponse?
    var memberListResponse = ShareGroupMemberListPageResponse(items: [], nextCursor: nil, hasNext: false)
    var updateResponse: ShareGroupUpdateResponse?

    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        cursor == nil ? groupListResponse : nextGroupListResponse ?? groupListResponse
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        try XCTUnwrap(groupDetailResponse)
    }

    func fetchMembers(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupMemberListPageResponse {
        memberListResponse
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

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreviewResponse {
        try XCTUnwrap(joinPreviewResponse)
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareGroupJoinResponse {
        try XCTUnwrap(joinResponse)
    }

    func updateGroupName(groupID: UUID, name: String) async throws -> ShareGroupUpdateResponse {
        try XCTUnwrap(updateResponse)
    }

    func deleteGroup(groupID: UUID) async throws {}

    func leaveGroup(groupID: UUID) async throws {}

    func fetchChatTimeline(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ChatTimelinePageResponse {
        ChatTimelinePageResponse(items: [], nextCursor: nil, hasNext: false)
    }

    func createChatMessage(
        groupID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> ChatMessageResponse {
        throw URLError(.unsupportedURL)
    }
}

private struct UnavailableShareGroupAPI: ShareGroupAPI {
    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        throw URLError(.notConnectedToInternet)
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        throw URLError(.notConnectedToInternet)
    }

    func fetchMembers(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupMemberListPageResponse {
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

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreviewResponse {
        throw URLError(.notConnectedToInternet)
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareGroupJoinResponse {
        throw URLError(.notConnectedToInternet)
    }

    func updateGroupName(groupID: UUID, name: String) async throws -> ShareGroupUpdateResponse {
        throw URLError(.notConnectedToInternet)
    }

    func deleteGroup(groupID: UUID) async throws {
        throw URLError(.notConnectedToInternet)
    }

    func leaveGroup(groupID: UUID) async throws {
        throw URLError(.notConnectedToInternet)
    }

    func fetchChatTimeline(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ChatTimelinePageResponse {
        throw URLError(.notConnectedToInternet)
    }

    func createChatMessage(
        groupID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> ChatMessageResponse {
        throw URLError(.notConnectedToInternet)
    }
}

private final class JoinTrackingShareGroupAPI: ShareGroupAPI {
    let previewResponse: ShareGroupJoinPreviewResponse
    let joinResponse: ShareGroupJoinResponse?
    var groupDetailErrors: [NetworkError?]
    var joinErrors: [NetworkError?]
    private(set) var previewInviteCodes: [String] = []
    private(set) var joinInviteCodes: [String] = []
    private(set) var joinIdempotencyKeys: [UUID] = []
    private(set) var fetchedGroupIDs: [UUID] = []

    init(
        previewResponse: ShareGroupJoinPreviewResponse,
        joinResponse: ShareGroupJoinResponse?,
        groupDetailErrors: [NetworkError?] = [],
        joinErrors: [NetworkError?] = []
    ) {
        self.previewResponse = previewResponse
        self.joinResponse = joinResponse
        self.groupDetailErrors = groupDetailErrors
        self.joinErrors = joinErrors
    }

    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        ShareGroupListPageResponse(items: [], nextCursor: nil, hasNext: false)
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        fetchedGroupIDs.append(id)
        if !groupDetailErrors.isEmpty, let error = groupDetailErrors.removeFirst() {
            throw error
        }
        return ShareGroupDetailResponse(
            id: id,
            name: previewResponse.name,
            myRole: .member,
            createdBy: previewResponse.createdBy,
            memberCount: previewResponse.memberCount,
            sharedAlbumCount: 0,
            photoCount: 0,
            createdAt: "2026-07-15T10:15:30Z",
            updatedAt: "2026-07-15T10:15:30Z"
        )
    }

    func fetchMembers(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupMemberListPageResponse {
        ShareGroupMemberListPageResponse(items: [], nextCursor: nil, hasNext: false)
    }

    func fetchInviteCode(groupID: UUID) async throws -> InviteCodeResponse {
        throw URLError(.notConnectedToInternet)
    }

    func fetchSharedAlbums(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedAlbumListPageResponse {
        SharedAlbumListPageResponse(items: [], nextCursor: nil, hasNext: false)
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse {
        throw URLError(.unsupportedURL)
    }

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreviewResponse {
        previewInviteCodes.append(inviteCode)
        return previewResponse
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareGroupJoinResponse {
        joinInviteCodes.append(inviteCode)
        joinIdempotencyKeys.append(idempotencyKey)
        if !joinErrors.isEmpty, let error = joinErrors.removeFirst() {
            throw error
        }
        return try XCTUnwrap(joinResponse)
    }

    func updateGroupName(groupID: UUID, name: String) async throws -> ShareGroupUpdateResponse {
        throw URLError(.unsupportedURL)
    }

    func deleteGroup(groupID: UUID) async throws {
        throw URLError(.unsupportedURL)
    }

    func leaveGroup(groupID: UUID) async throws {
        throw URLError(.unsupportedURL)
    }

    func fetchChatTimeline(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ChatTimelinePageResponse {
        ChatTimelinePageResponse(items: [], nextCursor: nil, hasNext: false)
    }

    func createChatMessage(
        groupID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> ChatMessageResponse {
        throw URLError(.unsupportedURL)
    }
}

private final class ManagementTrackingShareGroupAPI: ShareGroupAPI {
    let groupID: UUID
    let role: ShareGroupRoleResponse
    var memberPages: [ShareGroupMemberListPageResponse]
    var chatPages: [ChatTimelinePageResponse]
    var sharedAlbums: [SharedAlbumResponse]
    var sharedAlbumPages: [SharedAlbumListPageResponse]
    var groupDetailError: NetworkError?
    var groupListErrors: [NetworkError?]
    var groupListResponses: [ShareGroupListPageResponse]
    var groupListDelays: [Duration]
    var cancelsGroupListRequest: Bool
    var groupDetailDelay: Duration
    var chatMessageDelay: Duration
    var chatMessageErrors: [NetworkError?]
    var createdChatMessageResponse: ChatMessageResponse?
    var renameSharedAlbumErrors: [NetworkError?]
    var deleteGroupErrors: [NetworkError?]
    var leaveGroupErrors: [NetworkError?]
    var deleteSharedAlbumErrors: [NetworkError?]
    var bulkDeleteErrors: [NetworkError?]
    private(set) var memberCursors: [String?] = []
    private(set) var groupListRequestCount = 0
    private(set) var groupDetailRequestCount = 0
    private(set) var updatedNames: [String] = []
    private(set) var deletedGroupIDs: [UUID] = []
    private(set) var leftGroupIDs: [UUID] = []
    private(set) var chatCursors: [String?] = []
    private(set) var sharedAlbumCursors: [String?] = []
    private(set) var sentChatContents: [String] = []
    private(set) var chatIdempotencyKeys: [UUID] = []
    private(set) var renamedAlbumIDs: [UUID] = []
    private(set) var renamedAlbumNames: [String] = []
    private(set) var deletedAlbumIDs: [UUID] = []
    private(set) var bulkDeletedAlbumIDs: [UUID] = []
    private(set) var bulkDeleteIdempotencyKeys: [UUID] = []

    init(
        groupID: UUID,
        role: ShareGroupRoleResponse,
        memberPages: [ShareGroupMemberListPageResponse] = [],
        chatPages: [ChatTimelinePageResponse] = [],
        sharedAlbums: [SharedAlbumResponse] = [],
        sharedAlbumPages: [SharedAlbumListPageResponse] = [],
        groupListErrors: [NetworkError?] = [],
        groupListResponses: [ShareGroupListPageResponse] = [],
        groupListDelays: [Duration] = [],
        cancelsGroupListRequest: Bool = false,
        groupDetailDelay: Duration = .zero,
        groupDetailError: NetworkError? = nil,
        chatMessageDelay: Duration = .zero,
        chatMessageErrors: [NetworkError?] = [],
        createdChatMessageResponse: ChatMessageResponse? = nil,
        renameSharedAlbumErrors: [NetworkError?] = [],
        deleteGroupErrors: [NetworkError?] = [],
        leaveGroupErrors: [NetworkError?] = [],
        deleteSharedAlbumErrors: [NetworkError?] = [],
        bulkDeleteErrors: [NetworkError?] = []
    ) {
        self.groupID = groupID
        self.role = role
        self.memberPages = memberPages
        self.chatPages = chatPages
        self.sharedAlbums = sharedAlbums
        self.sharedAlbumPages = sharedAlbumPages
        self.groupListErrors = groupListErrors
        self.groupListResponses = groupListResponses
        self.groupListDelays = groupListDelays
        self.cancelsGroupListRequest = cancelsGroupListRequest
        self.groupDetailDelay = groupDetailDelay
        self.groupDetailError = groupDetailError
        self.chatMessageDelay = chatMessageDelay
        self.chatMessageErrors = chatMessageErrors
        self.createdChatMessageResponse = createdChatMessageResponse
        self.renameSharedAlbumErrors = renameSharedAlbumErrors
        self.deleteGroupErrors = deleteGroupErrors
        self.leaveGroupErrors = leaveGroupErrors
        self.deleteSharedAlbumErrors = deleteSharedAlbumErrors
        self.bulkDeleteErrors = bulkDeleteErrors
    }

    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        groupListRequestCount += 1
        if cancelsGroupListRequest {
            throw CancellationError()
        }
        let delay = groupListDelays.isEmpty ? .zero : groupListDelays.removeFirst()
        let response = groupListResponses.isEmpty ? nil : groupListResponses.removeFirst()
        try await Task.sleep(for: delay)
        if !groupListErrors.isEmpty, let error = groupListErrors.removeFirst() {
            throw error
        }
        if let response {
            return response
        }
        return ShareGroupListPageResponse(
            items: [ShareGroupSummaryResponse(
                id: groupID,
                name: "우리 가족",
                myRole: role,
                memberCount: 2,
                sharedAlbumCount: sharedAlbums.count,
                photoCount: sharedAlbums.reduce(0) { $0 + $1.photoCount },
                joinedAt: "2026-07-15T10:15:30Z",
                updatedAt: "2026-07-15T10:15:30Z"
            )],
            nextCursor: nil,
            hasNext: false
        )
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        groupDetailRequestCount += 1
        try await Task.sleep(for: groupDetailDelay)
        if let groupDetailError {
            throw groupDetailError
        }
        return ShareGroupDetailResponse(
            id: groupID,
            name: "우리 가족",
            myRole: role,
            createdBy: ShareGroupUserResponse(userId: nil, displayName: "집집이"),
            memberCount: 2,
            sharedAlbumCount: sharedAlbums.count,
            photoCount: sharedAlbums.reduce(0) { $0 + $1.photoCount },
            createdAt: "2026-07-15T10:15:30Z",
            updatedAt: "2026-07-15T10:15:30Z"
        )
    }

    func fetchMembers(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupMemberListPageResponse {
        memberCursors.append(cursor)
        return memberPages.isEmpty
            ? ShareGroupMemberListPageResponse(items: [], nextCursor: nil, hasNext: false)
            : memberPages.removeFirst()
    }

    func fetchInviteCode(groupID: UUID) async throws -> InviteCodeResponse {
        throw URLError(.unsupportedURL)
    }

    func fetchSharedAlbums(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedAlbumListPageResponse {
        sharedAlbumCursors.append(cursor)
        if !sharedAlbumPages.isEmpty {
            return sharedAlbumPages.removeFirst()
        }
        return SharedAlbumListPageResponse(items: sharedAlbums, nextCursor: nil, hasNext: false)
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreateSharedGroupResponse {
        throw URLError(.unsupportedURL)
    }

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreviewResponse {
        throw URLError(.unsupportedURL)
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareGroupJoinResponse {
        throw URLError(.unsupportedURL)
    }

    func updateGroupName(groupID: UUID, name: String) async throws -> ShareGroupUpdateResponse {
        updatedNames.append(name)
        return ShareGroupUpdateResponse(
            id: groupID,
            name: name,
            updatedAt: "2026-07-15T11:15:30Z"
        )
    }

    func deleteGroup(groupID: UUID) async throws {
        deletedGroupIDs.append(groupID)
        if !deleteGroupErrors.isEmpty, let error = deleteGroupErrors.removeFirst() {
            throw error
        }
    }

    func leaveGroup(groupID: UUID) async throws {
        leftGroupIDs.append(groupID)
        if !leaveGroupErrors.isEmpty, let error = leaveGroupErrors.removeFirst() {
            throw error
        }
    }

    func fetchChatTimeline(
        groupID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> ChatTimelinePageResponse {
        chatCursors.append(cursor)
        return chatPages.isEmpty
            ? ChatTimelinePageResponse(items: [], nextCursor: nil, hasNext: false)
            : chatPages.removeFirst()
    }

    func createChatMessage(
        groupID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> ChatMessageResponse {
        sentChatContents.append(content)
        chatIdempotencyKeys.append(idempotencyKey)
        try await Task.sleep(for: chatMessageDelay)
        if !chatMessageErrors.isEmpty, let error = chatMessageErrors.removeFirst() {
            throw error
        }
        if let createdChatMessageResponse {
            return createdChatMessageResponse
        }
        return ChatMessageResponse(
            id: UUID(),
            content: content,
            author: ChatAuthorResponse(userId: nil, displayName: "집집이"),
            isAuthor: true,
            createdAt: "2026-07-15T10:15:30Z",
            updatedAt: "2026-07-15T10:15:30Z"
        )
    }

    func renameSharedAlbum(id: UUID, name: String) async throws -> SharedAlbumRenameResponse {
        renamedAlbumIDs.append(id)
        renamedAlbumNames.append(name)
        if !renameSharedAlbumErrors.isEmpty, let error = renameSharedAlbumErrors.removeFirst() {
            throw error
        }
        return SharedAlbumRenameResponse(
            id: id,
            name: name,
            updatedAt: "2026-07-15T11:15:30Z"
        )
    }

    func deleteSharedAlbum(id: UUID) async throws {
        deletedAlbumIDs.append(id)
        if !deleteSharedAlbumErrors.isEmpty, let error = deleteSharedAlbumErrors.removeFirst() {
            throw error
        }
    }

    func deleteSharedAlbums(
        ids: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedAlbumBulkDeleteResponse {
        bulkDeletedAlbumIDs = ids
        bulkDeleteIdempotencyKeys.append(idempotencyKey)
        if !bulkDeleteErrors.isEmpty, let error = bulkDeleteErrors.removeFirst() {
            throw error
        }
        return SharedAlbumBulkDeleteResponse(
            deletedAlbumCount: ids.count,
            deletedPhotoCount: 0
        )
    }
}
