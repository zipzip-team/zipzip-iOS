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
