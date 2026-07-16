import XCTest
@testable import zipzip_iOS

final class SharedPhotoAPITests: XCTestCase {
    @MainActor
    func testSharedAlbumPhotoListRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.photoListJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))

        let response = try await api.fetchPhotos(
            sharedAlbumID: albumID,
            cursor: "photo+cursor=",
            size: 20
        )

        XCTAssertEqual(response.items.first?.sharedAlbumId, albumID)
        XCTAssertEqual(response.nextCursor, "next-photo-cursor")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-albums/\(albumID.uuidString)/photos")
        XCTAssertEqual(request.httpMethod, "GET")
        let queryItems = try XCTUnwrap(URLComponents(
            url: try XCTUnwrap(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems)
        XCTAssertEqual(queryItems.first(where: { $0.name == "cursor" })?.value, "photo+cursor=")
        XCTAssertEqual(queryItems.first(where: { $0.name == "size" })?.value, "20")
    }

    @MainActor
    func testUploadURLRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.uploadURLJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))

        let response = try await api.issueUploadURLs(
            sharedAlbumID: albumID,
            files: [.init(contentType: "image/jpeg", sizeBytes: 1024)]
        )

        XCTAssertEqual(response.uploads.first?.objectKey, "photos/object-key.jpg")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-albums/\(albumID.uuidString)/photos/upload-urls")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Idempotency-Key"))
        let files = try XCTUnwrap(try requestBody(request)["files"] as? [[String: Any]])
        XCTAssertEqual(files.first?["contentType"] as? String, "image/jpeg")
        XCTAssertEqual(files.first?["sizeBytes"] as? Int, 1024)
    }

    @MainActor
    func testCompleteUploadRequestMatchesDocumentedContract() async throws {
        let provider = SharedPhotoRecordingNetworkProvider(json: Self.uploadCompleteJSON)
        let api = DefaultSharedPhotoAPI(networkProvider: provider)
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let idempotencyKey = UUID()

        let response = try await api.completeUpload(
            sharedAlbumID: albumID,
            files: [
                .init(
                    objectKey: "photos/object-key.jpg",
                    deviceModel: "iPhone 15",
                    takenAt: "2026-07-15T10:15:30Z",
                    latitude: 37.5,
                    longitude: 127.0,
                    locationName: "서울",
                    isInferred: false,
                    width: 4032,
                    height: 3024
                )
            ],
            idempotencyKey: idempotencyKey
        )

        XCTAssertEqual(response.items.first?.id.uuidString, "11111111-1111-1111-1111-111111111111")
        let request = try XCTUnwrap(provider.request)
        XCTAssertEqual(request.url?.path, "/api/v1/shared-albums/\(albumID.uuidString)/photos/complete")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), idempotencyKey.uuidString)
        let files = try XCTUnwrap(try requestBody(request)["files"] as? [[String: Any]])
        XCTAssertEqual(files.first?["objectKey"] as? String, "photos/object-key.jpg")
        XCTAssertEqual(files.first?["width"] as? Int, 4032)
    }

    @MainActor
    func testAttachAndDetachRequestsMatchDocumentedContract() async throws {
        let albumID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let photoID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        let attachProvider = SharedPhotoRecordingNetworkProvider(json: Self.attachJSON)
        let attachKey = UUID()
        let attachResponse = try await DefaultSharedPhotoAPI(networkProvider: attachProvider).attachPhotos(
            sharedAlbumID: albumID,
            photoIDs: [photoID],
            idempotencyKey: attachKey
        )
        XCTAssertEqual(attachResponse.attachedCount, 1)
        XCTAssertEqual(attachProvider.request?.url?.path, "/api/v1/shared-albums/\(albumID.uuidString)/photos/attach")
        XCTAssertEqual(attachProvider.request?.value(forHTTPHeaderField: "Idempotency-Key"), attachKey.uuidString)
        XCTAssertEqual(
            try requestBody(try XCTUnwrap(attachProvider.request))["photoIds"] as? [String],
            [photoID.uuidString]
        )

        let detachProvider = SharedPhotoRecordingNetworkProvider(json: Self.detachJSON)
        let detachKey = UUID()
        let detachResponse = try await DefaultSharedPhotoAPI(networkProvider: detachProvider).detachPhotos(
            sharedAlbumID: albumID,
            photoIDs: [photoID],
            idempotencyKey: detachKey
        )
        XCTAssertEqual(detachResponse.deletedPhotoCount, 1)
        XCTAssertEqual(detachProvider.request?.url?.path, "/api/v1/shared-albums/\(albumID.uuidString)/photos/detach")
        XCTAssertEqual(detachProvider.request?.value(forHTTPHeaderField: "Idempotency-Key"), detachKey.uuidString)
    }

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

    private static let photoListItemJSON = """
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "sharedGroupId": "22222222-2222-2222-2222-222222222222",
      "sharedAlbumId": "33333333-3333-3333-3333-333333333333",
      "originalUrl": "https://object.example/original.jpg?signature=secret",
      "originalUrlExpiresAt": "2026-07-15T10:15:30Z",
      "thumbnailUrl": null,
      "thumbnailUrlExpiresAt": null,
      "thumbnailStatus": "PENDING",
      "deviceModel": "iPhone 15",
      "takenAt": "2026-07-15T09:00:00Z",
      "displayAt": "2026-07-15T09:00:00Z",
      "latitude": 37.5,
      "longitude": 127.0,
      "locationName": "서울",
      "isInferred": false,
      "width": 4032,
      "height": 3024,
      "uploadedBy": { "userId": null, "displayName": "집집이" },
      "isUploader": true,
      "likeCount": 0,
      "commentCount": 0,
      "isLikedByMe": false,
      "createdAt": "2026-07-15T10:15:30Z"
    }
    """

    private static var photoListJSON: String {
        """
        {
          "data": {
            "items": [\(photoListItemJSON)],
            "nextCursor": "next-photo-cursor",
            "hasNext": true
          }
        }
        """
    }

    private static let uploadURLJSON = """
    {
      "data": {
        "uploads": [{
          "objectKey": "photos/object-key.jpg",
          "uploadUrl": "https://object.example/upload?signature=secret",
          "uploadUrlExpiresAt": "2026-07-15T10:30:30Z",
          "contentType": "image/jpeg"
        }]
      }
    }
    """

    private static var uploadCompleteJSON: String {
        """
        { "data": { "items": [\(photoListItemJSON)] } }
        """
    }

    private static let attachJSON = """
    { "data": { "attachedCount": 1, "alreadyAttachedCount": 0 } }
    """

    private static let detachJSON = """
    { "data": { "detachedCount": 1, "deletedPhotoCount": 1 } }
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
