import Alamofire
import XCTest
@testable import zipzip_iOS

final class NetworkProviderTests: XCTestCase {
    func testSignedObjectURLsAreRedactedFromJSONLogs() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "uploads": [["uploadUrl": "https://object.example/upload?signature=upload-secret"]],
            "originalUrl": "https://object.example/original?signature=original-secret",
            "thumbnailUrl": "https://object.example/thumb?signature=thumbnail-secret",
            "representativeImageUrl": "https://object.example/representative?signature=representative-secret",
            "originalUrlExpiresAt": "2026-07-15T10:15:30Z"
        ])

        let redacted = NetworkSecretRedactor.redactBody(data)

        XCTAssertFalse(redacted.contains("signature="))
        XCTAssertFalse(redacted.contains("secret"))
        XCTAssertTrue(redacted.contains("\"uploadUrl\":\"***\""))
        XCTAssertTrue(redacted.contains("\"originalUrl\":\"***\""))
        XCTAssertTrue(redacted.contains("\"thumbnailUrl\":\"***\""))
        XCTAssertTrue(redacted.contains("\"representativeImageUrl\":\"***\""))
        XCTAssertTrue(redacted.contains("2026-07-15T10:15:30Z"))
    }

    @MainActor
    func testExplicitCancellationIsPreserved() {
        let provider = DefaultNetworkProvider(eventMonitors: [])

        XCTAssertTrue(provider.isCancellation(.explicitlyCancelled))
        XCTAssertTrue(provider.isCancellation(.sessionTaskFailed(error: URLError(.cancelled))))
        XCTAssertFalse(provider.isCancellation(.sessionTaskFailed(error: URLError(.timedOut))))
    }

    @MainActor
    func testSuccessfulStatusWithMalformedBodyMapsToDecodingError() {
        let provider = DefaultNetworkProvider(eventMonitors: [])
        let decodingError = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "malformed response")
        )
        let error = AFError.responseSerializationFailed(
            reason: .decodingFailed(error: decodingError)
        )

        let mappedError = provider.mapError(
            error,
            statusCode: 200,
            data: Data("not-json".utf8)
        )

        guard case .decodingError = mappedError else {
            return XCTFail("2xx 응답 파싱 실패는 decodingError여야 합니다.")
        }
    }

    @MainActor
    func testErrorStatusesPreserveServerEnvelope() throws {
        for statusCode in [400, 401, 403, 404, 409] {
            let provider = DefaultNetworkProvider(eventMonitors: [])
            let code = "SERVER_CODE_\(statusCode)"
            let body = try JSONSerialization.data(withJSONObject: [
                "status": statusCode,
                "code": code,
                "message": "server message"
            ])
            let error = AFError.responseValidationFailed(
                reason: .unacceptableStatusCode(code: statusCode)
            )

            let mappedError = provider.mapError(error, statusCode: statusCode, data: body)

            guard case let .server(mappedStatus, mappedCode, mappedMessage, mappedBody) = mappedError else {
                return XCTFail("\(statusCode) 응답은 server 오류여야 합니다.")
            }
            XCTAssertEqual(mappedStatus, statusCode)
            XCTAssertEqual(mappedCode, code)
            XCTAssertEqual(mappedMessage, "server message")
            XCTAssertEqual(mappedBody, body)
        }
    }
}
