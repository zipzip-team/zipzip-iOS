import Foundation
import XCTest
@testable import zipzip_iOS

@MainActor
final class NavigationArchitectureTests: XCTestCase {
    func testRouterMutatesOneHomogeneousRoutePath() throws {
        let router = Router()
        let groupID = try XCTUnwrap(UUID(uuidString: "2B7CC071-0559-4584-AEA7-F7E4E77385D9"))
        let albumID = try XCTUnwrap(UUID(uuidString: "9F1C7A64-6C2E-4B3A-9E0D-1F4B2C8A7D51"))

        router.push(.shareGroup(groupID))
        router.push(.shareAlbum(groupID: groupID, albumID: albumID))
        router.push(.shareImport(groupID))

        XCTAssertEqual(
            router.path,
            [
                .shareGroup(groupID),
                .shareAlbum(groupID: groupID, albumID: albumID),
                .shareImport(groupID)
            ]
        )

        router.pop()
        XCTAssertEqual(router.path.last, .shareAlbum(groupID: groupID, albumID: albumID))

        router.replacePath(with: [.albumDetail(7)])
        XCTAssertEqual(router.path, [.albumDetail(7)])

        router.popToRoot()
        XCTAssertTrue(router.path.isEmpty)
    }

    func testOnlyRootViewOwnsAPathBoundNavigationStack() throws {
        let sourceDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("zipzip-iOS", isDirectory: true)
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourceDirectory,
                includingPropertiesForKeys: nil
            )
        )
        var owners: [String] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            guard source.range(
                of: #"NavigationStack\s*\(\s*path:"#,
                options: .regularExpression
            ) != nil else {
                continue
            }

            owners.append(
                fileURL.path.replacingOccurrences(
                    of: sourceDirectory.path + "/",
                    with: ""
                )
            )
        }

        XCTAssertEqual(owners.sorted(), ["App/RootView.swift"])
    }
}
