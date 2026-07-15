import XCTest
@testable import zipzip_iOS

final class ShareGroupAPITests: XCTestCase {
    @MainActor
    func testGroupListRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.groupListJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)

        let response = try await api.fetchGroups(cursor: "opaque+cursor=", size: 20)

        XCTAssertEqual(response.items.first?.name, "우리 가족")
        XCTAssertEqual(response.items.first?.myRole, .host)
        XCTAssertEqual(response.nextCursor, "next-cursor")
        XCTAssertTrue(response.hasNext)

        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups")
        XCTAssertEqual(request.httpMethod, "GET")
        let queryItems = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
            .queryItems)
        XCTAssertEqual(queryItems.first(where: { $0.name == "cursor" })?.value, "opaque+cursor=")
        XCTAssertEqual(queryItems.first(where: { $0.name == "size" })?.value, "20")
    }

    @MainActor
    func testGroupDetailRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.groupDetailJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.fetchGroup(id: groupID)

        XCTAssertEqual(response.id, groupID)
        XCTAssertEqual(response.createdBy.displayName, "집집이")
        XCTAssertEqual(provider.request?.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)")
        XCTAssertEqual(provider.request?.httpMethod, "GET")
    }

    @MainActor
    func testInviteCodeRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.inviteCodeJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.fetchInviteCode(groupID: groupID)

        XCTAssertEqual(response.inviteCode, "ZZ7K9P2Q")
        XCTAssertEqual(provider.request?.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)/invite-code")
        XCTAssertEqual(provider.request?.httpMethod, "GET")
    }

    @MainActor
    func testSharedAlbumListRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.sharedAlbumListJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.fetchSharedAlbums(groupID: groupID, cursor: nil, size: 20)

        XCTAssertEqual(response.items.first?.name, "제주도")
        XCTAssertEqual(response.items.first?.photoCount, 42)
        XCTAssertNil(response.nextCursor)
        XCTAssertFalse(response.hasNext)
        XCTAssertEqual(provider.request?.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)/shared-albums")
        XCTAssertEqual(provider.request?.httpMethod, "GET")
    }

    @MainActor
    func testCreateGroupRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.createGroupJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let idempotencyKey = UUID()

        let response = try await api.createGroup(name: "우리 가족", idempotencyKey: idempotencyKey)

        let expectedID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        XCTAssertEqual(response.id, expectedID)
        XCTAssertEqual(response.name, "우리 가족")
        XCTAssertEqual(response.inviteCode, "ZZ7K9P2Q")

        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), idempotencyKey.uuidString)
        XCTAssertEqual(try requestBody(request)["name"] as? String, "우리 가족")
    }

    @MainActor
    func testJoinPreviewRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.joinPreviewJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)

        let response = try await api.previewJoin(inviteCode: "ZZ7K9P2Q")

        XCTAssertEqual(response.name, "여행 친구")
        XCTAssertFalse(response.alreadyJoined)
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups/join-preview")
        XCTAssertEqual(request.httpMethod, "GET")
        let queryItems = try XCTUnwrap(URLComponents(
            url: try XCTUnwrap(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(queryItems.first(where: { $0.name == "inviteCode" })?.value, "ZZ7K9P2Q")
    }

    @MainActor
    func testJoinRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.joinJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let idempotencyKey = UUID()

        let response = try await api.join(
            inviteCode: "ZZ7K9P2Q",
            idempotencyKey: idempotencyKey
        )

        XCTAssertEqual(response.name, "여행 친구")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups/join")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), idempotencyKey.uuidString)
        XCTAssertEqual(try requestBody(request)["inviteCode"] as? String, "ZZ7K9P2Q")
    }

    @MainActor
    func testMemberListRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.memberListJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.fetchMembers(groupID: groupID, cursor: "member-cursor", size: 50)

        XCTAssertEqual(response.items.first?.displayName, "집집이")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)/members")
        XCTAssertEqual(request.httpMethod, "GET")
        let queryItems = try XCTUnwrap(URLComponents(
            url: try XCTUnwrap(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(queryItems.first(where: { $0.name == "cursor" })?.value, "member-cursor")
        XCTAssertEqual(queryItems.first(where: { $0.name == "size" })?.value, "50")
    }

    @MainActor
    func testUpdateGroupRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.updateGroupJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.updateGroupName(groupID: groupID, name: "여름 여행")

        XCTAssertEqual(response.name, "여름 여행")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)")
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(try requestBody(request)["name"] as? String, "여름 여행")
    }

    @MainActor
    func testDeleteGroupRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.voidJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        try await api.deleteGroup(groupID: groupID)

        XCTAssertEqual(provider.request?.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)")
        XCTAssertEqual(provider.request?.httpMethod, "DELETE")
    }

    @MainActor
    func testLeaveGroupRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.voidJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        try await api.leaveGroup(groupID: groupID)

        XCTAssertEqual(provider.request?.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)/members/me")
        XCTAssertEqual(provider.request?.httpMethod, "DELETE")
    }

    @MainActor
    func testChatTimelineRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.chatTimelineJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.fetchChatTimeline(groupID: groupID, cursor: "chat-cursor", size: 30)

        XCTAssertEqual(response.items.first?.type, .photoComment)
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)/chat-messages")
        XCTAssertEqual(request.httpMethod, "GET")
        let queryItems = try XCTUnwrap(URLComponents(
            url: try XCTUnwrap(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(queryItems.first(where: { $0.name == "cursor" })?.value, "chat-cursor")
        XCTAssertEqual(queryItems.first(where: { $0.name == "size" })?.value, "30")
    }

    @MainActor
    func testCreateChatMessageRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider(json: Self.chatMessageJSON)
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let groupID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let idempotencyKey = UUID()

        let response = try await api.createChatMessage(
            groupID: groupID,
            content: "사진 더 올려줘",
            idempotencyKey: idempotencyKey
        )

        XCTAssertEqual(response.content, "사진 더 올려줘")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-groups/\(groupID.uuidString)/chat-messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), idempotencyKey.uuidString)
        XCTAssertEqual(try requestBody(request)["content"] as? String, "사진 더 올려줘")
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static let groupListJSON = """
    {
      "data": {
        "items": [{
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "우리 가족",
          "myRole": "HOST",
          "memberCount": 4,
          "sharedAlbumCount": 3,
          "photoCount": 128,
          "joinedAt": "2026-07-03T10:15:30Z",
          "updatedAt": "2026-07-03T10:15:30Z"
        }],
        "nextCursor": "next-cursor",
        "hasNext": true
      }
    }
    """

    private static let groupDetailJSON = """
    {
      "data": {
        "id": "11111111-1111-1111-1111-111111111111",
        "name": "우리 가족",
        "myRole": "MEMBER",
        "createdBy": {
          "userId": "22222222-2222-2222-2222-222222222222",
          "displayName": "집집이"
        },
        "memberCount": 4,
        "sharedAlbumCount": 3,
        "photoCount": 128,
        "createdAt": "2026-07-03T10:15:30Z",
        "updatedAt": "2026-07-03T10:15:30Z"
      }
    }
    """

    private static let inviteCodeJSON = """
    {
      "data": {
        "sharedGroupId": "11111111-1111-1111-1111-111111111111",
        "inviteCode": "ZZ7K9P2Q"
      }
    }
    """

    private static let sharedAlbumListJSON = """
    {
      "data": {
        "items": [{
          "id": "33333333-3333-3333-3333-333333333333",
          "name": "제주도",
          "photoCount": 42,
          "createdBy": {
            "userId": null,
            "displayName": null
          },
          "isCreator": true,
          "createdAt": "2026-07-03T10:15:30Z",
          "updatedAt": "2026-07-03T10:15:30Z"
        }],
        "nextCursor": null,
        "hasNext": false
      }
    }
    """

    private static let createGroupJSON = """
    {
      "data": {
        "id": "11111111-1111-1111-1111-111111111111",
        "name": "우리 가족",
        "inviteCode": "ZZ7K9P2Q"
      }
    }
    """

    private static let joinPreviewJSON = """
    {
      "data": {
        "sharedGroupId": "44444444-4444-4444-4444-444444444444",
        "name": "여행 친구",
        "representativeImageUrl": null,
        "representativeImageUrlExpiresAt": null,
        "createdBy": {
          "userId": null,
          "displayName": "집집이"
        },
        "memberCount": 4,
        "members": [],
        "alreadyJoined": false
      }
    }
    """

    private static let joinJSON = """
    {
      "data": {
        "sharedGroupId": "44444444-4444-4444-4444-444444444444",
        "name": "여행 친구",
        "myRole": "MEMBER",
        "joinedAt": "2026-07-15T10:15:30Z"
      }
    }
    """

    private static let memberListJSON = """
    {
      "data": {
        "items": [{
          "userId": "22222222-2222-2222-2222-222222222222",
          "displayName": "집집이",
          "role": "HOST",
          "isMe": true,
          "joinedAt": "2026-07-03T10:15:30Z"
        }],
        "nextCursor": null,
        "hasNext": false
      }
    }
    """

    private static let updateGroupJSON = """
    {
      "data": {
        "id": "11111111-1111-1111-1111-111111111111",
        "name": "여름 여행",
        "updatedAt": "2026-07-15T10:15:30Z"
      }
    }
    """

    private static let voidJSON = """
    {
      "status": 200,
      "code": "SUCCESS",
      "message": "success",
      "data": null
    }
    """

    private static let chatTimelineJSON = """
    {
      "data": {
        "items": [{
          "type": "PHOTO_COMMENT",
          "id": "55555555-5555-5555-5555-555555555555",
          "photoId": "66666666-6666-6666-6666-666666666666",
          "content": "사진 너무 좋다",
          "author": {
            "userId": null,
            "displayName": "집집이"
          },
          "isAuthor": false,
          "createdAt": "2026-07-15T10:15:30Z",
          "updatedAt": "2026-07-15T10:15:30Z"
        }],
        "nextCursor": null,
        "hasNext": false
      }
    }
    """

    private static let chatMessageJSON = """
    {
      "data": {
        "id": "55555555-5555-5555-5555-555555555555",
        "content": "사진 더 올려줘",
        "author": {
          "userId": null,
          "displayName": "집집이"
        },
        "isAuthor": true,
        "createdAt": "2026-07-15T10:15:30Z",
        "updatedAt": "2026-07-15T10:15:30Z"
      }
    }
    """
}

@MainActor
private final class ShareGroupRecordingNetworkProvider: NetworkProvider {
    private let json: String
    private(set) var request: URLRequest?

    init(json: String) {
        self.json = json
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        request = try endpoint.asURLRequest()
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
