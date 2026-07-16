//
//  GroupChatPresentationTests.swift
//  zipzip-iOSTests
//

import XCTest
@testable import zipzip_iOS

final class GroupChatPresentationTests: XCTestCase {
    func testPhotoThumbnailAppearsOnceForConsecutiveCommentsOnSamePhoto() {
        let firstPhotoID = UUID()
        let secondPhotoID = UUID()
        let author = ShareGroupUser(id: UUID(), displayName: "단아")
        let messages = [
            makeMessage(type: .photoComment, photoID: firstPhotoID, author: author),
            makeMessage(type: .photoComment, photoID: firstPhotoID, author: author),
            makeMessage(type: .photoComment, photoID: secondPhotoID, author: author),
            makeMessage(type: .photoComment, photoID: secondPhotoID, author: author)
        ]

        let rows = GroupChatPresentation.rows(for: messages)

        XCTAssertEqual(rows.map(\.showsPhotoThumbnail), [true, false, true, false])
    }

    func testRegularMessageBreaksConsecutivePhotoCommentGroup() {
        let photoID = UUID()
        let author = ShareGroupUser(id: UUID(), displayName: "단아")
        let messages = [
            makeMessage(type: .photoComment, photoID: photoID, author: author),
            makeMessage(type: .chatMessage, author: author),
            makeMessage(type: .photoComment, photoID: photoID, author: author)
        ]

        let rows = GroupChatPresentation.rows(for: messages)

        XCTAssertEqual(rows.map(\.showsPhotoThumbnail), [true, false, true])
    }

    func testProfileAppearsOnlyAtStartOfConsecutiveAuthorRun() {
        let firstAuthor = ShareGroupUser(id: UUID(), displayName: "단아")
        let secondAuthor = ShareGroupUser(id: UUID(), displayName: "집집이")
        let messages = [
            makeMessage(author: firstAuthor),
            makeMessage(author: firstAuthor),
            makeMessage(author: secondAuthor),
            makeMessage(author: nil),
            makeMessage(author: nil),
            makeMessage(author: nil, isAuthor: true),
            makeMessage(author: nil, isAuthor: true)
        ]

        let rows = GroupChatPresentation.rows(for: messages)

        XCTAssertEqual(rows.map(\.showsProfile), [true, false, true, true, true, true, false])
    }

    private func makeMessage(
        type: ChatTimelineItemTypeResponse = .chatMessage,
        photoID: UUID? = nil,
        author: ShareGroupUser? = nil,
        isAuthor: Bool = false
    ) -> ShareGroupChatItem {
        ShareGroupChatItem(
            id: UUID(),
            type: type,
            photoID: photoID,
            content: "단아 대박이네",
            author: author,
            isAuthor: isAuthor,
            createdAt: .now,
            updatedAt: .now
        )
    }
}
