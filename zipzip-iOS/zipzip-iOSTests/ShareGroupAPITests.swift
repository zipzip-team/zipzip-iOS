import XCTest
@testable import zipzip_iOS

final class ShareGroupAPITests: XCTestCase {
    @MainActor
    func testCreateGroupRequestMatchesDocumentedContract() async throws {
        let provider = ShareGroupRecordingNetworkProvider()
        let api = DefaultShareGroupAPI(networkProvider: provider)
        let idempotencyKey = UUID()

        let response = try await api.createGroup(
            name: "우리 가족",
            idempotencyKey: idempotencyKey
        )

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
}

@MainActor
private final class ShareGroupRecordingNetworkProvider: NetworkProvider {
    private(set) var request: URLRequest?

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        request = try endpoint.asURLRequest()
        let json = """
        {
          "data": {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "우리 가족",
            "inviteCode": "ZZ7K9P2Q"
          }
        }
        """
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
