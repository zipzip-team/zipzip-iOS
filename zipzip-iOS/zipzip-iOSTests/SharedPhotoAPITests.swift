import XCTest
@testable import zipzip_iOS

final class SharedPhotoAPITests: XCTestCase {
    @MainActor
    func testPhotoDetailRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.photoDetailJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let photoID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.fetchPhoto(id: photoID)

        XCTAssertEqual(response.id, photoID)
        XCTAssertNil(response.thumbnailUrl)
        XCTAssertEqual(provider.request?.url?.path, "/api/v1/photos/\(photoID.uuidString)")
        XCTAssertEqual(provider.request?.httpMethod, "GET")
    }

    @MainActor
    func testPhotoCommentListRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.commentListJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let photoID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.fetchComments(photoID: photoID, cursor: "comment-cursor", size: 20)

        XCTAssertEqual(response.items.first?.content, "사진 너무 좋다")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/photos/\(photoID.uuidString)/comments")
        XCTAssertEqual(request.httpMethod, "GET")
        let queryItems = try XCTUnwrap(URLComponents(
            url: try XCTUnwrap(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(queryItems.first(where: { $0.name == "cursor" })?.value, "comment-cursor")
        XCTAssertEqual(queryItems.first(where: { $0.name == "size" })?.value, "20")
    }

    @MainActor
    func testCreatePhotoCommentRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.commentCreateJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let photoID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let idempotencyKey = UUID()

        let response = try await api.createComment(
            photoID: photoID,
            content: "사진 너무 좋다",
            idempotencyKey: idempotencyKey
        )

        XCTAssertEqual(response.photoId, photoID)
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/photos/\(photoID.uuidString)/comments")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), idempotencyKey.uuidString)
        XCTAssertEqual(try requestBody(request)["content"] as? String, "사진 너무 좋다")
    }

    @MainActor
    func testLikePhotoRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.likedJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let photoID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.likePhoto(id: photoID)

        XCTAssertTrue(response.isLikedByMe)
        XCTAssertEqual(provider.request?.url?.path, "/api/v1/photos/\(photoID.uuidString)/like")
        XCTAssertEqual(provider.request?.httpMethod, "PUT")
    }

    @MainActor
    func testUnlikePhotoRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.unlikedJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let photoID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let response = try await api.unlikePhoto(id: photoID)

        XCTAssertFalse(response.isLikedByMe)
        XCTAssertEqual(provider.request?.url?.path, "/api/v1/photos/\(photoID.uuidString)/like")
        XCTAssertEqual(provider.request?.httpMethod, "DELETE")
    }

    @MainActor
    func testRepositoryMapsPhotoDetailAndComment() async throws {
        let photoProvider = SharedPhotoRecordingNetworkProvider(json: Self.photoDetailJSON)
        let photoID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let photoRepository = DefaultSharedPhotoRepository(
            api: DefaultSharedPhotoAPI(networkProvider: photoProvider)
        )

        let photo = try await photoRepository.photo(id: photoID)

        XCTAssertEqual(photo.sharedAlbumIDs.count, 2)
        XCTAssertEqual(photo.uploadedBy.displayName, "집집이")
        XCTAssertEqual(photo.likeCount, 3)

        let commentProvider = SharedPhotoRecordingNetworkProvider(json: Self.commentCreateJSON)
        let commentRepository = DefaultSharedPhotoRepository(
            api: DefaultSharedPhotoAPI(networkProvider: commentProvider)
        )
        let comment = try await commentRepository.createComment(
            photoID: photoID,
            content: "사진 너무 좋다",
            idempotencyKey: UUID()
        )

        XCTAssertEqual(comment.photoID, photoID)
        XCTAssertTrue(comment.isAuthor)
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static let photoDetailJSON = """
    {
      "data": {
        "id": "11111111-1111-1111-1111-111111111111",
        "sharedGroupId": "22222222-2222-2222-2222-222222222222",
        "sharedAlbumIds": [
          "33333333-3333-3333-3333-333333333333",
          "44444444-4444-4444-4444-444444444444"
        ],
        "originalUrl": "https://example.com/original.jpg",
        "originalUrlExpiresAt": "2026-07-15T10:15:30Z",
        "thumbnailUrl": null,
        "thumbnailUrlExpiresAt": null,
        "thumbnailStatus": "PROCESSING",
        "deviceModel": "iPhone 15",
        "takenAt": null,
        "displayAt": "2026-07-15T10:15:30Z",
        "latitude": null,
        "longitude": null,
        "locationName": null,
        "isInferred": false,
        "width": 4032,
        "height": 3024,
        "uploadedBy": {
          "userId": null,
          "displayName": "집집이"
        },
        "isUploader": true,
        "likeCount": 3,
        "commentCount": 2,
        "isLikedByMe": true,
        "createdAt": "2026-07-15T10:15:30Z",
        "updatedAt": "2026-07-15T10:15:30Z"
      }
    }
    """

    private static let commentListJSON = """
    {
      "data": {
        "items": [{
          "id": "55555555-5555-5555-5555-555555555555",
          "content": "사진 너무 좋다",
          "author": {
            "userId": null,
            "displayName": "집집이"
          },
          "isAuthor": true,
          "createdAt": "2026-07-15T10:15:30Z",
          "updatedAt": "2026-07-15T10:15:30Z"
        }],
        "nextCursor": null,
        "hasNext": false
      }
    }
    """

    private static let commentCreateJSON = """
    {
      "data": {
        "id": "55555555-5555-5555-5555-555555555555",
        "photoId": "11111111-1111-1111-1111-111111111111",
        "content": "사진 너무 좋다",
        "author": {
          "userId": null,
          "displayName": "집집이"
        },
        "createdAt": "2026-07-15T10:15:30Z",
        "updatedAt": "2026-07-15T10:15:30Z"
      }
    }
    """

    private static let likedJSON = """
    {
      "data": {
        "photoId": "11111111-1111-1111-1111-111111111111",
        "isLikedByMe": true,
        "likeCount": 4
      }
    }
    """

    private static let unlikedJSON = """
    {
      "data": {
        "photoId": "11111111-1111-1111-1111-111111111111",
        "isLikedByMe": false,
        "likeCount": 3
      }
    }
    """
}

@MainActor
private final class SharedPhotoRecordingNetworkProvider: NetworkProvider {
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
