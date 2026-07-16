import XCTest
@testable import zipzip_iOS

final class ObjectStorageTransferClientTests: XCTestCase {
    override func tearDown() {
        ObjectStorageTestURLProtocol.handler = nil
        super.tearDown()
    }

    func testUploadUsesExactSignedRequestHeadersWithoutAuthorization() async throws {
        let bytes = Data("jpeg-bytes".utf8)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("object-storage-upload-\(UUID().uuidString)")
        try bytes.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let signedURL = try XCTUnwrap(URL(string: "https://object.example/upload?signature=secret"))
        ObjectStorageTestURLProtocol.handler = { request in
            XCTAssertEqual(request.url, signedURL)
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Length"), String(bytes.count))
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (Self.response(url: signedURL, statusCode: 200), Data())
        }

        try await makeClient().upload(
            fileURL: fileURL,
            to: signedURL,
            contentType: "image/jpeg",
            contentLength: bytes.count
        )
    }

    func testUploadRejectsMismatchedContentLengthBeforeRequest() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("object-storage-upload-\(UUID().uuidString)")
        try Data("jpeg".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let signedURL = try XCTUnwrap(URL(string: "https://object.example/upload?signature=secret"))

        do {
            try await makeClient().upload(
                fileURL: fileURL,
                to: signedURL,
                contentType: "image/jpeg",
                contentLength: 100
            )
            XCTFail("파일 바이트와 서명된 Content-Length가 다르면 요청 전에 실패해야 합니다.")
        } catch let error as ObjectStorageTransferError {
            XCTAssertEqual(error, .contentLengthMismatch(expected: 100, actual: 4))
        }
    }

    func testDownloadUsesUnauthenticatedGETAndReturnsOwnedTemporaryFile() async throws {
        let signedURL = try XCTUnwrap(URL(string: "https://object.example/photo?signature=secret"))
        let bytes = Data("downloaded-photo".utf8)
        ObjectStorageTestURLProtocol.handler = { request in
            XCTAssertEqual(request.url, signedURL)
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (Self.response(url: signedURL, statusCode: 200), bytes)
        }

        let downloadedURL = try await makeClient().download(from: signedURL)
        defer { try? FileManager.default.removeItem(at: downloadedURL) }

        XCTAssertEqual(try Data(contentsOf: downloadedURL), bytes)
        XCTAssertTrue(downloadedURL.lastPathComponent.hasPrefix("shared-photo-download-"))
    }

    func testNonSuccessfulObjectStorageStatusIsRejected() async throws {
        let signedURL = try XCTUnwrap(URL(string: "https://object.example/photo?signature=expired"))
        ObjectStorageTestURLProtocol.handler = { _ in
            (Self.response(url: signedURL, statusCode: 403), Data())
        }

        do {
            _ = try await makeClient().download(from: signedURL)
            XCTFail("2xx가 아닌 Object Storage 응답은 실패해야 합니다.")
        } catch let error as ObjectStorageTransferError {
            XCTAssertEqual(error, .unexpectedStatusCode(403))
        }
    }

    private func makeClient() -> DefaultObjectStorageTransferClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ObjectStorageTestURLProtocol.self]
        return DefaultObjectStorageTransferClient(session: URLSession(configuration: configuration))
    }

    private static func response(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }
}

private final class ObjectStorageTestURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
