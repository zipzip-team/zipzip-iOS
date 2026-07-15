import Alamofire
import XCTest
@testable import zipzip_iOS

final class NetworkProviderTests: XCTestCase {
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
