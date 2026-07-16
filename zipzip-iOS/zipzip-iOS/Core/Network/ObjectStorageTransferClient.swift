//
//  ObjectStorageTransferClient.swift
//  zipzip-iOS
//

import Foundation
import UniformTypeIdentifiers

nonisolated protocol ObjectStorageTransferClient: Sendable {
    func upload(
        fileURL: URL,
        to signedURL: URL,
        contentType: String,
        contentLength: Int
    ) async throws

    /// 반환된 임시 파일은 호출자가 사용 후 삭제해야 한다.
    func download(from signedURL: URL) async throws -> URL
}

nonisolated enum ObjectStorageTransferError: Error, Equatable {
    case invalidResponse
    case unexpectedStatusCode(Int)
    case contentLengthMismatch(expected: Int, actual: Int)
}

/// Zipzip 인증/로깅 계층을 거치지 않고 presigned URL과 직접 통신한다.
final nonisolated class DefaultObjectStorageTransferClient: ObjectStorageTransferClient, @unchecked Sendable {
    private let session: URLSession
    private let fileManager: FileManager

    init(
        session: URLSession? = nil,
        fileManager: FileManager = .default
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
        self.fileManager = fileManager
    }

    func upload(
        fileURL: URL,
        to signedURL: URL,
        contentType: String,
        contentLength: Int
    ) async throws {
        let actualContentLength = try fileSize(at: fileURL)
        guard actualContentLength == contentLength else {
            throw ObjectStorageTransferError.contentLengthMismatch(
                expected: contentLength,
                actual: actualContentLength
            )
        }

        var request = URLRequest(
            url: signedURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 60 * 15
        )
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")

        do {
            let (_, response) = try await session.upload(for: request, fromFile: fileURL)
            try validate(response)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
    }

    func download(from signedURL: URL) async throws -> URL {
        var request = URLRequest(
            url: signedURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 60 * 10
        )
        request.httpMethod = "GET"

        do {
            let (temporaryURL, response) = try await session.download(for: request)
            try validate(response)

            let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(
                downloadFilename(signedURL: signedURL, response: response),
                isDirectory: false
            )
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            return destinationURL
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
    }

    private func fileSize(at fileURL: URL) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes[.size] as? NSNumber else {
            throw ObjectStorageTransferError.contentLengthMismatch(expected: 0, actual: -1)
        }
        return fileSize.intValue
    }

    private func downloadFilename(signedURL: URL, response: URLResponse) -> String {
        let filename = "shared-photo-download-\(UUID().uuidString)"
        let pathExtensions = [
            response.suggestedFilename.map { URL(fileURLWithPath: $0).pathExtension },
            signedURL.pathExtension,
            response.mimeType.flatMap {
                UTType(mimeType: $0)?.preferredFilenameExtension
            }
        ]
        let pathExtension = pathExtensions
            .compactMap { $0 }
            .first { !$0.isEmpty }

        guard let pathExtension else {
            return filename
        }
        return "\(filename).\(pathExtension)"
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw ObjectStorageTransferError.invalidResponse
        }
        guard 200 ..< 300 ~= response.statusCode else {
            throw ObjectStorageTransferError.unexpectedStatusCode(response.statusCode)
        }
    }
}
