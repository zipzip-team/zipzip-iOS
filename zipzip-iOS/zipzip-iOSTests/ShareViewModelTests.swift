import XCTest
@testable import zipzip_iOS

private let testCacheOwnerID = UUID()

extension ShareGroupAPI {
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
            inviteCode: "ZZ7K9P2Q"
        )
        let store = try makeStore()
        let viewModel = ShareViewModel(
            groups: [],
            repository: makeRepository(
                api: StubShareGroupAPI(createResponse: response),
                store: store
            )
        )
        viewModel.presentCreateSheet()
        viewModel.groupNameDraft = "우리 가족"

        await viewModel.createGroup()

        XCTAssertFalse(viewModel.isCreateSheetPresented)
        XCTAssertTrue(viewModel.isInviteSheetPresented)
        XCTAssertEqual(viewModel.groups.map(\.id), [response.id])
        XCTAssertEqual(viewModel.groups.map(\.name), [response.name])
        XCTAssertEqual(viewModel.inviteCode, response.inviteCode)
        let storedGroups = try await store.fetchGroups()
        XCTAssertEqual(storedGroups.map(\.id), [response.id])

        let restoredViewModel = ShareViewModel(
            repository: makeRepository(api: UnavailableShareGroupAPI(), store: store)
        )
        await restoredViewModel.loadInviteCode(groupID: response.id)
        XCTAssertEqual(restoredViewModel.inviteCode(for: response.id), response.inviteCode)

        viewModel.completeInvitation()
        XCTAssertEqual(viewModel.groups.count, 1)
    }

    @MainActor
    func testCreateGroupFailurePresentsErrorAlertWithoutClosingSheet() async throws {
        let viewModel = ShareViewModel(
            groups: [],
            repository: makeRepository(
                api: UnavailableShareGroupAPI(),
                store: try makeStore()
            )
        )
        viewModel.presentCreateSheet()
        viewModel.groupNameDraft = "우리 가족"

        await viewModel.createGroup()

        XCTAssertTrue(viewModel.isCreateSheetPresented)
        XCTAssertFalse(viewModel.isInviteSheetPresented)
        XCTAssertTrue(viewModel.isErrorAlertPresented)
        XCTAssertEqual(viewModel.errorAlertMessage, "네트워크 연결을 확인한 후 다시 시도해 주세요.")

        viewModel.dismissErrorAlert()
        XCTAssertFalse(viewModel.isErrorAlertPresented)
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
            repository: makeRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "  ZZ7K9P2Q  "

        await viewModel.confirmJoinCode()

        XCTAssertFalse(viewModel.isJoinSheetPresented)
        XCTAssertTrue(viewModel.isJoinConfirmationPresented)
        XCTAssertEqual(viewModel.pendingJoinGroup?.id, groupID)
        XCTAssertEqual(api.previewInviteCodes, ["ZZ7K9P2Q"])

        let joinedGroupID = await viewModel.completeJoin()

        XCTAssertEqual(joinedGroupID, groupID)
        XCTAssertEqual(viewModel.groups.map(\.id), [groupID])
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
            repository: makeRepository(api: api, store: try makeStore())
        )
        viewModel.presentJoinSheet()
        viewModel.joinCode = "ZZ7K9P2Q"

        await viewModel.confirmJoinCode()
        let joinedGroupID = await viewModel.completeJoin()

        XCTAssertEqual(joinedGroupID, groupID)
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

        viewModel.presentShareManagement(groupID: groupID)
        let didLeave = await viewModel.leaveManagedShareGroup()

        XCTAssertTrue(didLeave)
        XCTAssertEqual(api.deletedGroupIDs, [groupID])
        XCTAssertTrue(api.leftGroupIDs.isEmpty)
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
        viewModel.presentShareManagement(groupID: groupID)
        let didLeave = await viewModel.leaveManagedShareGroup()

        XCTAssertTrue(didLeave)
        XCTAssertEqual(api.leftGroupIDs, [groupID])
        XCTAssertTrue(api.deletedGroupIDs.isEmpty)
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    @MainActor
    func testLoadsChatTimelineInChronologicalOrder() async throws {
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let newerID = try XCTUnwrap(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
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
                    items: [makeChatItem(id: olderID, content: "이전")],
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

        XCTAssertEqual(viewModel.chatItems.map(\.id), [olderID, newerID])
        XCTAssertEqual(api.chatCursors.count, 2)
        XCTAssertNil(api.chatCursors[0])
        XCTAssertEqual(api.chatCursors[1], "older-chat")
    }

    @MainActor
    func testSendsChatMessageThenRefreshesTimeline() async throws {
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
                ),
                ChatTimelinePageResponse(
                    items: [
                        makeChatItem(id: sentID, content: "사진 더 올려줘", isAuthor: true),
                        makeChatItem(id: firstID, content: "기존")
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
        viewModel.commentDraft = "  사진 더 올려줘  "

        await viewModel.sendChatMessage()

        XCTAssertEqual(api.sentChatContents, ["사진 더 올려줘"])
        XCTAssertEqual(api.chatIdempotencyKeys.count, 1)
        XCTAssertEqual(api.chatCursors.count, 2)
        XCTAssertEqual(viewModel.chatItems.map(\.id), [firstID, sentID])
        XCTAssertTrue(viewModel.commentDraft.isEmpty)
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

    private func makeJoinPreview(
        groupID: UUID,
        alreadyJoined: Bool
    ) -> ShareGroupJoinPreviewResponse {
        ShareGroupJoinPreviewResponse(
            sharedGroupId: groupID,
            name: "여행 친구",
            representativeImageUrl: nil,
            representativeImageUrlExpiresAt: nil,
            createdBy: ShareGroupUserResponse(userId: nil, displayName: "집집이"),
            memberCount: 4,
            members: [],
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
    private(set) var previewInviteCodes: [String] = []
    private(set) var joinInviteCodes: [String] = []
    private(set) var joinIdempotencyKeys: [UUID] = []

    init(
        previewResponse: ShareGroupJoinPreviewResponse,
        joinResponse: ShareGroupJoinResponse?
    ) {
        self.previewResponse = previewResponse
        self.joinResponse = joinResponse
    }

    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        ShareGroupListPageResponse(items: [], nextCursor: nil, hasNext: false)
    }

    func fetchGroup(id: UUID) async throws -> ShareGroupDetailResponse {
        throw URLError(.notConnectedToInternet)
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
    let sharedAlbums: [SharedAlbumResponse]
    private(set) var memberCursors: [String?] = []
    private(set) var updatedNames: [String] = []
    private(set) var deletedGroupIDs: [UUID] = []
    private(set) var leftGroupIDs: [UUID] = []
    private(set) var chatCursors: [String?] = []
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
        sharedAlbums: [SharedAlbumResponse] = []
    ) {
        self.groupID = groupID
        self.role = role
        self.memberPages = memberPages
        self.chatPages = chatPages
        self.sharedAlbums = sharedAlbums
    }

    func fetchGroups(cursor: String?, size: Int) async throws -> ShareGroupListPageResponse {
        ShareGroupListPageResponse(
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
        throw URLError(.unsupportedURL)
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
        SharedAlbumListPageResponse(items: sharedAlbums, nextCursor: nil, hasNext: false)
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
    }

    func leaveGroup(groupID: UUID) async throws {
        leftGroupIDs.append(groupID)
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
        return SharedAlbumRenameResponse(
            id: id,
            name: name,
            updatedAt: "2026-07-15T11:15:30Z"
        )
    }

    func deleteSharedAlbum(id: UUID) async throws {
        deletedAlbumIDs.append(id)
    }

    func deleteSharedAlbums(
        ids: [UUID],
        idempotencyKey: UUID
    ) async throws -> SharedAlbumBulkDeleteResponse {
        bulkDeletedAlbumIDs = ids
        bulkDeleteIdempotencyKeys.append(idempotencyKey)
        return SharedAlbumBulkDeleteResponse(
            deletedAlbumCount: ids.count,
            deletedPhotoCount: 0
        )
    }
}
