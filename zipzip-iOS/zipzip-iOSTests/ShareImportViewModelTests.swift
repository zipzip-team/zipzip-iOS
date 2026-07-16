import XCTest
@testable import zipzip_iOS

final class ShareImportViewModelTests: XCTestCase {
    @MainActor
    func testUploadFailureRetriesExistingCreatedAlbumWithoutCreatingDuplicate() async {
        let groupID = UUID()
        let groupRepository = ImportShareGroupRepository(groupID: groupID)
        let photoRepository = ImportSharedPhotoRepository(
            localIdentifiers: ["local-photo"],
            mutationResults: [
                .init(succeededCount: 0, failedCount: 1),
                .init(
                    succeededCount: 1,
                    succeededLocalIdentifiers: ["local-photo"]
                )
            ]
        )
        let viewModel = ShareViewModel(
            groups: [groupRepository.group],
            repository: groupRepository,
            sharedPhotoRepository: photoRepository
        )
        let personalAlbum = Album(id: 7, name: "제주 여행", count: 1)

        let firstOutcome = await viewModel.importPersonalAlbums([personalAlbum], into: groupID)
        let secondOutcome = await viewModel.importPersonalAlbums([personalAlbum], into: groupID)

        XCTAssertEqual(firstOutcome?.createdAlbumCount, 1)
        XCTAssertEqual(firstOutcome?.failedPhotoCount, 1)
        XCTAssertEqual(secondOutcome?.createdAlbumCount, 0)
        XCTAssertEqual(secondOutcome?.uploadedPhotoCount, 1)
        XCTAssertEqual(groupRepository.createRequests.count, 1)
        XCTAssertEqual(photoRepository.destinationAlbumIDs.count, 2)
        XCTAssertEqual(
            photoRepository.destinationAlbumIDs[0],
            photoRepository.destinationAlbumIDs[1]
        )
    }

    @MainActor
    func testCreateAlbumRetryReusesIdempotencyKey() async {
        let groupID = UUID()
        let groupRepository = ImportShareGroupRepository(
            groupID: groupID,
            createFailures: [true, false]
        )
        let photoRepository = ImportSharedPhotoRepository(
            localIdentifiers: ["local-photo"],
            mutationResults: [
                .init(
                    succeededCount: 1,
                    succeededLocalIdentifiers: ["local-photo"]
                )
            ]
        )
        let viewModel = ShareViewModel(
            groups: [groupRepository.group],
            repository: groupRepository,
            sharedPhotoRepository: photoRepository
        )
        let personalAlbum = Album(id: 9, name: "가족", count: 1)

        _ = await viewModel.importPersonalAlbums([personalAlbum], into: groupID)
        _ = await viewModel.importPersonalAlbums([personalAlbum], into: groupID)

        XCTAssertEqual(groupRepository.createRequests.count, 2)
        XCTAssertEqual(
            groupRepository.createRequests[0].idempotencyKey,
            groupRepository.createRequests[1].idempotencyKey
        )
    }
}

@MainActor
private final class ImportShareGroupRepository: ShareGroupRepository {
    struct CreateRequest {
        let groupID: UUID
        let name: String
        let idempotencyKey: UUID
    }

    private(set) var group: ShareAlbum
    private(set) var createRequests: [CreateRequest] = []
    private var createFailures: [Bool]

    init(groupID: UUID, createFailures: [Bool] = []) {
        self.group = ShareAlbum(
            id: groupID,
            name: "우리 가족",
            date: .now,
            memberCount: 2
        )
        self.createFailures = createFailures
    }

    func prepareCache(for userID: UUID) async throws {}
    func invalidateCacheSession() {}
    func groups() async throws -> [ShareAlbum] {
        [group]
    }

    func syncGroups(cursor: String?, size: Int) async throws -> ShareGroupRepositoryPage {
        .init(itemIDs: [group.id], nextCursor: nil, hasNext: false)
    }

    func syncGroup(id: ShareAlbum.ID) async throws {}
    func members(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupMemberPage {
        .init(items: [], nextCursor: nil, hasNext: false)
    }

    func syncSharedAlbums(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupRepositoryPage {
        .init(itemIDs: group.albums.map(\.id), nextCursor: nil, hasNext: false)
    }

    func inviteCode(groupID: ShareAlbum.ID) async throws -> String? {
        nil
    }

    func createGroup(name: String, idempotencyKey: UUID) async throws -> CreatedShareGroup {
        throw ImportStubError.unsupported
    }

    func createSharedAlbum(
        groupID: ShareAlbum.ID,
        name: String,
        idempotencyKey: UUID
    ) async throws -> SharedAlbum {
        createRequests.append(.init(
            groupID: groupID,
            name: name,
            idempotencyKey: idempotencyKey
        ))
        if !createFailures.isEmpty, createFailures.removeFirst() {
            throw URLError(.notConnectedToInternet)
        }
        let album = SharedAlbum(
            id: UUID(),
            sharedGroupID: groupID,
            name: name,
            count: 0,
            createdBy: nil,
            isCreator: true,
            createdAt: .now,
            updatedAt: .now
        )
        group.albums.append(album)
        group.sharedAlbumCount = group.albums.count
        return album
    }

    func previewJoin(inviteCode: String) async throws -> ShareGroupJoinPreview {
        throw ImportStubError.unsupported
    }

    func join(inviteCode: String, idempotencyKey: UUID) async throws -> ShareAlbum.ID {
        throw ImportStubError.unsupported
    }

    func updateGroupName(id: ShareAlbum.ID, name: String) async throws {
        throw ImportStubError.unsupported
    }

    func deleteRemoteGroup(id: ShareAlbum.ID) async throws {
        throw ImportStubError.unsupported
    }

    func leaveGroup(id: ShareAlbum.ID) async throws {
        throw ImportStubError.unsupported
    }

    func chatTimeline(
        groupID: ShareAlbum.ID,
        cursor: String?,
        size: Int
    ) async throws -> ShareGroupChatPage {
        throw ImportStubError.unsupported
    }

    func createChatMessage(
        groupID: ShareAlbum.ID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> ShareGroupChatItem {
        throw ImportStubError.unsupported
    }

    func renameSharedAlbum(
        id: SharedAlbum.ID,
        groupID: ShareAlbum.ID,
        name: String
    ) async throws {
        throw ImportStubError.unsupported
    }

    func deleteSharedAlbum(id: SharedAlbum.ID, groupID: ShareAlbum.ID) async throws {
        throw ImportStubError.unsupported
    }

    func deleteSharedAlbums(
        ids: [SharedAlbum.ID],
        groupID: ShareAlbum.ID,
        idempotencyKey: UUID
    ) async throws -> SharedAlbumDeletionResult {
        throw ImportStubError.unsupported
    }

    func removeCachedGroup(id: ShareAlbum.ID) async throws {}
}

@MainActor
private final class ImportSharedPhotoRepository: SharedPhotoRepository {
    private let localIdentifiers: [String]
    private var mutationResults: [SharedAlbumPhotoMutationResult]
    private(set) var destinationAlbumIDs: [SharedAlbum.ID] = []

    init(
        localIdentifiers: [String],
        mutationResults: [SharedAlbumPhotoMutationResult]
    ) {
        self.localIdentifiers = localIdentifiers
        self.mutationResults = mutationResults
    }

    func prepareCache(for userID: UUID) async throws {}
    func invalidateCacheSession() {}
    func cachedPhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        []
    }

    func synchronizePhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        []
    }

    func addLocalPhotos(
        localIdentifiers: [String],
        to albumIDs: [SharedAlbum.ID],
        in groupID: ShareAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        destinationAlbumIDs.append(contentsOf: albumIDs)
        guard !mutationResults.isEmpty else { throw ImportStubError.unsupported }
        return mutationResults.removeFirst()
    }

    func copyPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to destinationAlbumIDs: [SharedAlbum.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw ImportStubError.unsupported
    }

    func detachPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw ImportStubError.unsupported
    }

    func savePhotosToLibrary(
        photoIDs: [SharedAlbumPhoto.ID],
        in albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw ImportStubError.unsupported
    }

    func deleteLocalCopies(
        photoIDs: [SharedAlbumPhoto.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        throw ImportStubError.unsupported
    }

    func localIdentifiers(inPersonalAlbum albumID: Album.ID) async throws -> [String] {
        localIdentifiers
    }

    func localIdentifiers(forAlbumPhotoIDs albumPhotoIDs: [Int]) async throws -> [String] {
        localIdentifiers
    }

    func photo(id: UUID) async throws -> SharedPhotoDetail {
        throw ImportStubError.unsupported
    }

    func comments(
        photoID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedPhotoCommentPage {
        throw ImportStubError.unsupported
    }

    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment {
        throw ImportStubError.unsupported
    }

    func setLike(photoID: UUID, isLiked: Bool) async throws -> SharedPhotoLikeState {
        throw ImportStubError.unsupported
    }
}

private enum ImportStubError: Error {
    case unsupported
}
