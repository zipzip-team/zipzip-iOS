//
//  AlbumViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

@Observable
@MainActor
final class AlbumViewModel {
    var isSelectionMode = false
    var isDeleteAlertPresented = false
    var isCreateAlbumSheetPresented = false {
        didSet {
            if !isCreateAlbumSheetPresented {
                resetCreateAlbumDraft()
            }
        }
    }

    var isShareAlbumSheetPresented = false
    var isErrorAlertPresented = false
    private(set) var errorAlertMessage = ""
    var createAlbumName = ""
    private(set) var isCreatingAlbum = false
    private(set) var isMovingAlbumsToShare = false
    private(set) var selectedShareGroupID: ShareAlbum.ID?

    private(set) var selectedAlbumIDs: [AlbumViewItem.ID] = []
    private(set) var albums: [AlbumViewItem]
    @ObservationIgnored private let albumStore: AlbumStore
    @ObservationIgnored private let photoSectionsProvider: PhotoSectionsProvider
    @ObservationIgnored private let photoDeletion: PhotoDeletionService
    @ObservationIgnored private let sharedPhotoRepository: (any SharedPhotoRepository)?
    @ObservationIgnored private let shareGroupRepository: (any ShareGroupRepository)?
    @ObservationIgnored private let loadsAlbumsFromDatabase: Bool
    @ObservationIgnored private var errorRetryAction: (() async -> Void)?
    @ObservationIgnored private var albumMoveIdempotencyKeys: [String: UUID] = [:]
    @ObservationIgnored private var albumMoveDestinations: [String: SharedAlbum] = [:]

    init(
        albums: [AlbumViewItem]? = nil,
        albumStore: AlbumStore = AlbumStore(),
        photoSectionsProvider: PhotoSectionsProvider = PhotoSectionsProvider(),
        photoDeletion: PhotoDeletionService = PhotoDeletionService(),
        sharedPhotoRepository: (any SharedPhotoRepository)? = nil,
        shareGroupRepository: (any ShareGroupRepository)? = nil
    ) {
        self.albums = albums ?? []
        self.albumStore = albumStore
        self.photoSectionsProvider = photoSectionsProvider
        self.photoDeletion = photoDeletion
        self.sharedPhotoRepository = sharedPhotoRepository
        self.shareGroupRepository = shareGroupRepository
        self.loadsAlbumsFromDatabase = albums == nil
    }

    var isCreateAlbumDisabled: Bool {
        createAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreatingAlbum
    }

    func loadAlbums() async {
        guard loadsAlbumsFromDatabase else { return }

        do {
            albums = try await albumStore.fetchAlbums()
                .map(AlbumViewItem.init)
                .filter { !$0.isFavorite || $0.hasPhotos }
        } catch {
            return
        }
    }

    func enterSelectionMode() {
        isSelectionMode = true
    }

    func exitSelectionMode() {
        selectedAlbumIDs.removeAll()
        selectedShareGroupID = nil
        isDeleteAlertPresented = false
        isShareAlbumSheetPresented = false
        isSelectionMode = false
    }

    func resetForTabChange() {
        exitSelectionMode()
    }

    func presentCreateAlbumSheet() {
        isCreateAlbumSheetPresented = true
    }

    func dismissCreateAlbumSheet() {
        isCreateAlbumSheetPresented = false
    }

    func resetCreateAlbumDraft() {
        createAlbumName = ""
    }

    func createAlbum() async -> AlbumViewItem? {
        let trimmedName = createAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isCreatingAlbum else { return nil }

        isCreatingAlbum = true
        defer { isCreatingAlbum = false }

        let storedAlbum: StoredAlbum
        do {
            storedAlbum = try await albumStore.createAlbum(name: trimmedName)
        } catch {
            presentError("사진집을 만들지 못했어요.") { [weak self] in
                _ = await self?.createAlbum()
            }
            return nil
        }
        let album = AlbumViewItem(storedAlbum: storedAlbum)

        let insertIndex = albums.first?.isFavorite == true ? 1 : 0
        albums.insert(album, at: insertIndex)
        isCreateAlbumSheetPresented = false
        return album
    }

    func showDetail(for album: AlbumViewItem, router: Router) {
        router.push(.albumDetail(album.id))
    }

    func showPhotoDetail(_ photo: Photo, in albumID: AlbumViewItem.ID, router: Router) {
        router.push(.albumPhotoDetail(albumID: albumID, photo: photo))
    }

    func showPhotoInfoEdit(
        for photoIDs: [UUID],
        from albumID: AlbumViewItem.ID,
        onSuccessfulDismiss: @escaping () -> Void,
        router: Router
    ) async {
        guard let sections = try? await photoSectionsProvider.loadAlbumSections(albumID: albumID) else {
            return
        }

        let photosByID = Dictionary(
            sections.flatMap(\.photos).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let orderedPhotos = photoIDs.compactMap { photosByID[$0] }
        guard let firstPhoto = orderedPhotos.first else {
            return
        }

        let localIdentifiers = orderedPhotos.map(\.localIdentifier).filter { !$0.isEmpty }
        guard !localIdentifiers.isEmpty else {
            return
        }
        router.push(.photoInfoEdit(PhotoInfoEditDestination(
            metadata: firstPhoto.metadata,
            localIdentifiers: localIdentifiers,
            onSuccessfulDismiss: onSuccessfulDismiss
        )))
    }

    func toggleSelection(for album: AlbumViewItem) {
        guard !album.isFavorite else {
            return
        }

        if let index = selectedAlbumIDs.firstIndex(of: album.id) {
            selectedAlbumIDs.remove(at: index)
        } else {
            selectedAlbumIDs.append(album.id)
        }
    }

    func selectionNumber(for album: AlbumViewItem) -> Int? {
        selectedAlbumIDs.firstIndex(of: album.id).map { $0 + 1 }
    }

    func moveSelectedAlbumsToShare() {
        guard !selectedAlbumIDs.isEmpty else {
            return
        }

        selectedShareGroupID = nil
        isShareAlbumSheetPresented = true
    }

    func dismissShareAlbumSheet() {
        selectedShareGroupID = nil
        isShareAlbumSheetPresented = false
    }

    func selectShareGroup(_ groupID: ShareAlbum.ID) {
        selectedShareGroupID = groupID
    }

    @discardableResult
    func completeShareAlbumMove(to group: ShareAlbum) async -> Bool {
        guard !isMovingAlbumsToShare,
              let sharedPhotoRepository,
              let shareGroupRepository
        else { return false }

        let selectedIDs = Set(selectedAlbumIDs)
        let sourceAlbums = albums.filter { selectedIDs.contains($0.id) && !$0.isFavorite }
        guard !sourceAlbums.isEmpty else { return false }

        isMovingAlbumsToShare = true
        defer { isMovingAlbumsToShare = false }

        var createdAnyAlbum = false
        var succeededPhotoCount = 0
        var failedPhotoCount = 0

        for sourceAlbum in sourceAlbums {
            let requestIdentity = "\(group.id.uuidString):\(sourceAlbum.id):\(sourceAlbum.name)"
            let idempotencyKey = albumMoveIdempotencyKeys[requestIdentity] ?? UUID()
            albumMoveIdempotencyKeys[requestIdentity] = idempotencyKey

            let destinationAlbum: SharedAlbum
            if let existingDestination = albumMoveDestinations[requestIdentity] {
                destinationAlbum = existingDestination
            } else {
                do {
                    destinationAlbum = try await shareGroupRepository.createSharedAlbum(
                        groupID: group.id,
                        name: sourceAlbum.name,
                        idempotencyKey: idempotencyKey
                    )
                    albumMoveDestinations[requestIdentity] = destinationAlbum
                    createdAnyAlbum = true
                } catch is CancellationError {
                    return false
                } catch {
                    failedPhotoCount += sourceAlbum.count
                    continue
                }
            }

            do {
                let sections = try await photoSectionsProvider.loadAlbumSections(albumID: sourceAlbum.id)
                let localIdentifiers = sections
                    .flatMap(\.photos)
                    .map(\.localIdentifier)
                    .filter { !$0.isEmpty }
                guard !localIdentifiers.isEmpty else {
                    albumMoveIdempotencyKeys.removeValue(forKey: requestIdentity)
                    albumMoveDestinations.removeValue(forKey: requestIdentity)
                    continue
                }

                let result = try await sharedPhotoRepository.addLocalPhotos(
                    localIdentifiers: localIdentifiers,
                    to: [destinationAlbum.id],
                    in: group.id
                )
                let succeededIdentifiers = Set(result.succeededLocalIdentifiers)

                succeededPhotoCount += succeededIdentifiers.count
                let unresolvedCount = max(0, localIdentifiers.count - succeededIdentifiers.count)
                failedPhotoCount += max(result.failedCount, unresolvedCount)
                if unresolvedCount == 0, result.failedCount == 0 {
                    albumMoveIdempotencyKeys.removeValue(forKey: requestIdentity)
                    albumMoveDestinations.removeValue(forKey: requestIdentity)
                }
            } catch is CancellationError {
                return false
            } catch {
                failedPhotoCount += sourceAlbum.count
            }
        }

        await loadAlbums()
        let completedAnyWork = createdAnyAlbum || succeededPhotoCount > 0
        if completedAnyWork {
            exitSelectionMode()
        } else {
            dismissShareAlbumSheet()
        }
        if failedPhotoCount > 0 {
            presentMutationNotice(
                succeededCount: succeededPhotoCount,
                failedCount: failedPhotoCount,
                fallback: "사진집을 공유그룹으로 옮기지 못했어요."
            )
        }
        return completedAnyWork
    }

    func resetSharedAlbumMoveState() {
        albumMoveIdempotencyKeys = [:]
        albumMoveDestinations = [:]
        selectedShareGroupID = nil
        isMovingAlbumsToShare = false
        isShareAlbumSheetPresented = false
    }

    func deleteSelectedAlbums() {
        guard !selectedAlbumIDs.isEmpty else {
            return
        }

        isDeleteAlertPresented = true
    }

    func dismissDeleteAlert() {
        isDeleteAlertPresented = false
    }

    func confirmSelectedAlbumDeletion() {
        let albumIDs = selectedAlbumIDs
        Task {
            guard await deleteAlbums(ids: albumIDs) else {
                presentError("사진집을 삭제하지 못했어요.") { [weak self] in
                    self?.confirmSelectedAlbumDeletion()
                }
                return
            }

            exitSelectionMode()
        }
    }

    func album(for id: AlbumViewItem.ID) -> AlbumViewItem? {
        albums.first(where: { $0.id == id })
    }

    func makeDetailViewModel(for albumID: AlbumViewItem.ID, router: Router) -> AlbumDetailViewModel {
        AlbumDetailViewModel(
            actions: AlbumDetailActions(
                onRename: { [weak self] name in
                    guard let self else { return false }
                    return await self.renameAlbum(albumID, to: name)
                },
                onDelete: { [weak self] in
                    guard let self else { return false }
                    return await self.deleteAlbums(
                        ids: [albumID],
                        beforeLocalStateUpdate: router.pop
                    )
                },
                onAddPhotos: { [weak self] localIdentifiers in
                    guard let self else { return false }
                    return await self.addPhotos(
                        localIdentifiers: localIdentifiers,
                        to: [.album(albumID)]
                    )
                },
                onDeletePhotos: { [weak self] photoIDs, action in
                    guard let self else { return false }
                    return await self.deletePhotos(photoIDs, from: albumID, action: action)
                },
                onMovePhotos: { [weak self] photoIDs, destination in
                    guard let self,
                          await self.movePhotos(photoIDs, from: albumID, to: destination)
                    else {
                        return false
                    }
                    if let destinationAlbumID = destination.firstPersonalAlbumID {
                        router.push(.albumDetail(destinationAlbumID))
                    }
                    return true
                }
            ),
            onEditPhotoInfo: { [weak self] photoIDs, onSuccessfulDismiss in
                Task {
                    await self?.showPhotoInfoEdit(
                        for: photoIDs,
                        from: albumID,
                        onSuccessfulDismiss: onSuccessfulDismiss,
                        router: router
                    )
                }
            }
        )
    }

    @discardableResult
    func deletePhotos(
        _ photoIDs: [UUID],
        from albumID: AlbumViewItem.ID,
        action: PhotoDeletionAction
    ) async -> Bool {
        guard let sections = try? await photoSectionsProvider.loadAlbumSections(albumID: albumID) else {
            return false
        }

        let selectedPhotos = sections
            .flatMap(\.photos)
            .filter { photoIDs.contains($0.id) }

        do {
            switch action {
            case .deletePermanently:
                try await photoDeletion.delete(
                    localIdentifiers: selectedPhotos.map(\.localIdentifier)
                )
            case .removeFromAlbum:
                try await albumStore.removeAlbumPhotos(
                    ids: selectedPhotos.compactMap(\.albumPhotoID)
                )
            }
        } catch {
            return false
        }

        await loadAlbums()
        return true
    }

    func moveDestinations(excluding albumID: AlbumViewItem.ID) -> [Album] {
        shareDestinations.filter { $0.id != albumID }
    }

    var shareDestinations: [Album] {
        albums
            .filter { !$0.isFavorite }
            .map {
                Album(
                    id: $0.id,
                    name: $0.name,
                    count: $0.count,
                    thumbnailLocalIdentifiers: $0.thumbnailLocalIdentifiers
                )
            }
    }

    func isPhotoFavorited(localIdentifier: String) async -> Bool {
        (try? await albumStore.isPhotoFavorite(localIdentifier: localIdentifier)) ?? false
    }

    func setPhotoFavorite(localIdentifier: String, isFavorite: Bool) async -> Bool {
        do {
            try await albumStore.setPhotoFavorite(
                localIdentifier: localIdentifier,
                isFavorite: isFavorite
            )
            await loadAlbums()
            return true
        } catch {
            return false
        }
    }

    func photoSections(for albumID: AlbumViewItem.ID) async -> [PhotoSection] {
        do {
            return try await photoSectionsProvider.loadAlbumSections(albumID: albumID)
        } catch {
            presentError("사진을 불러오지 못했어요.") { [weak self] in
                _ = await self?.photoSections(for: albumID)
            }
            return []
        }
    }

    var canRetryError: Bool {
        errorRetryAction != nil
    }

    func dismissErrorAlert() {
        isErrorAlertPresented = false
        errorAlertMessage = ""
        errorRetryAction = nil
    }

    func retryErrorAction() async {
        let retry = errorRetryAction
        dismissErrorAlert()
        await retry?()
    }

    /// 사진 목록 화면에서 선택한 사진을 개인 사진집에 영구적으로 추가한다.
    func addPhotos(localIdentifiers: [String], to destinations: [ShareDestination]) async -> Bool {
        let uniqueLocalIdentifiers = Array(Set(localIdentifiers.filter { !$0.isEmpty }))
        let albumIDs = destinations.compactMap { destination -> Album.ID? in
            guard case let .album(albumID) = destination else {
                return nil
            }
            return albumID
        }
        let sharedDestinationPairs: [(ShareAlbum.ID, SharedAlbum.ID)] = destinations.compactMap { destination in
            guard case let .sharedAlbum(groupID, albumID) = destination else { return nil }
            return (groupID, albumID)
        }
        let sharedDestinations = Dictionary(grouping: sharedDestinationPairs) { $0.0 }

        guard !destinations.isEmpty, !uniqueLocalIdentifiers.isEmpty else {
            return false
        }

        var completedAnyWork = false
        if !albumIDs.isEmpty {
            do {
                try await albumStore.addPhotos(localIdentifiers: uniqueLocalIdentifiers, to: albumIDs)
                completedAnyWork = true
            } catch {
                // 공유 대상이 함께 있으면 성공한 원격 작업은 그대로 유지한다.
            }
        }

        if let sharedPhotoRepository {
            for (groupID, values) in sharedDestinations {
                do {
                    let result = try await sharedPhotoRepository.addLocalPhotos(
                        localIdentifiers: uniqueLocalIdentifiers,
                        to: values.map { $0.1 },
                        in: groupID
                    )
                    completedAnyWork = completedAnyWork || result.succeededCount > 0
                    if result.failedCount > 0 {
                        presentMutationNotice(
                            succeededCount: result.succeededCount,
                            failedCount: result.failedCount,
                            fallback: "일부 사진을 공유집에 추가하지 못했어요."
                        )
                    }
                } catch {
                    presentMutationNotice(
                        succeededCount: completedAnyWork ? uniqueLocalIdentifiers.count : 0,
                        failedCount: uniqueLocalIdentifiers.count,
                        fallback: "사진을 공유집에 추가하지 못했어요."
                    )
                }
            }
        }

        await loadAlbums()
        return completedAnyWork
    }

    func moveAlbumPhotos(
        ids: [Int],
        from sourceAlbumID: AlbumViewItem.ID,
        to destinations: [ShareDestination]
    ) async -> Bool {
        let destinationAlbumIDs = destinations.compactMap { destination -> Album.ID? in
            guard case let .album(albumID) = destination else {
                return nil
            }
            return albumID
        }
        let sharedDestinationPairs: [(ShareAlbum.ID, SharedAlbum.ID)] = destinations.compactMap { destination in
            guard case let .sharedAlbum(groupID, albumID) = destination else { return nil }
            return (groupID, albumID)
        }
        let sharedDestinations = Dictionary(grouping: sharedDestinationPairs) { $0.0 }

        guard !ids.isEmpty, !destinations.isEmpty else {
            return false
        }

        if !destinationAlbumIDs.isEmpty {
            do {
                try await albumStore.moveAlbumPhotos(
                    ids: ids,
                    from: sourceAlbumID,
                    to: destinationAlbumIDs
                )
                await loadAlbums()
                return true
            } catch {
                return false
            }
        }

        guard let sharedPhotoRepository else { return false }
        do {
            let localIdentifiers = try await sharedPhotoRepository.localIdentifiers(forAlbumPhotoIDs: ids)
            guard !localIdentifiers.isEmpty else { return false }

            var succeededIdentifiers = Set(localIdentifiers)
            var failedCount = 0
            for (groupID, values) in sharedDestinations {
                let result = try await sharedPhotoRepository.addLocalPhotos(
                    localIdentifiers: localIdentifiers,
                    to: values.map { $0.1 },
                    in: groupID
                )
                succeededIdentifiers.formIntersection(result.succeededLocalIdentifiers)
                failedCount += result.failedCount
            }

            let succeededAlbumPhotoIDs = zip(ids, localIdentifiers).compactMap { id, identifier in
                succeededIdentifiers.contains(identifier) ? id : nil
            }
            if !succeededAlbumPhotoIDs.isEmpty {
                try await albumStore.removeAlbumPhotos(ids: succeededAlbumPhotoIDs)
            }
            if failedCount > 0 {
                presentMutationNotice(
                    succeededCount: succeededIdentifiers.count,
                    failedCount: failedCount,
                    fallback: "일부 사진을 공유집으로 옮기지 못했어요."
                )
            }
            await loadAlbums()
            return !succeededIdentifiers.isEmpty
        } catch {
            presentMutationNotice(
                succeededCount: 0,
                failedCount: ids.count,
                fallback: "사진을 공유집으로 옮기지 못했어요."
            )
            return false
        }
    }

    private func renameAlbum(_ albumID: AlbumViewItem.ID, to name: String) async -> Bool {
        if loadsAlbumsFromDatabase {
            do {
                try await albumStore.renameAlbum(id: albumID, name: name)
            } catch {
                return false
            }
        }

        guard let index = albums.firstIndex(where: { $0.id == albumID }) else {
            return false
        }
        albums[index].name = name
        return true
    }

    private func deleteAlbums(
        ids: [AlbumViewItem.ID],
        beforeLocalStateUpdate: () -> Void = {}
    ) async -> Bool {
        let favoriteIDs = Set(albums.filter(\.isFavorite).map(\.id))
        let uniqueIDs = Array(Set(ids).subtracting(favoriteIDs))
        guard !uniqueIDs.isEmpty else {
            return false
        }

        if loadsAlbumsFromDatabase {
            do {
                try await albumStore.deleteAlbums(ids: uniqueIDs)
            } catch {
                return false
            }
        }

        beforeLocalStateUpdate()
        let idsToDelete = Set(uniqueIDs)
        albums.removeAll { idsToDelete.contains($0.id) }
        return true
    }

    private func movePhotos(
        _ photoIDs: [UUID],
        from albumID: AlbumViewItem.ID,
        to destinations: [ShareDestination]
    ) async -> Bool {
        guard let sections = try? await photoSectionsProvider.loadAlbumSections(albumID: albumID) else {
            return false
        }

        let photosByID = Dictionary(uniqueKeysWithValues: sections.flatMap(\.photos).map { ($0.id, $0) })
        let albumPhotoIDs = photoIDs.compactMap { photosByID[$0]?.albumPhotoID }
        return await moveAlbumPhotos(
            ids: albumPhotoIDs,
            from: albumID,
            to: destinations
        )
    }

    private func presentError(
        _ message: String,
        retry: @escaping () async -> Void
    ) {
        errorAlertMessage = message
        errorRetryAction = retry
        isErrorAlertPresented = true
    }

    private func presentMutationNotice(
        succeededCount: Int,
        failedCount: Int,
        fallback: String
    ) {
        errorAlertMessage = failedCount > 0
            ? "성공 \(succeededCount)장, 실패 \(failedCount)장이에요."
            : fallback
        errorRetryAction = nil
        isErrorAlertPresented = true
    }
}

struct AlbumViewItem: Identifiable, Equatable {
    let id: Int
    var name: String
    let createdAt: Date
    var count: Int
    var photoIDs: [UUID]
    var thumbnailLocalIdentifiers: [String] = []
    var isFavorite = false

    var detailItem: AlbumDetailItem {
        AlbumDetailItem(
            id: id,
            title: name,
            createdAt: createdAt,
            photoCount: count
        )
    }

    var hasPhotos: Bool {
        count > 0
    }
}

extension AlbumViewItem {
    private static let samplePhotoIDs = PhotoSection.sample.flatMap(\.photos).map(\.id)

    private static func samplePhotoIDs(offset: Int) -> [UUID] {
        guard !samplePhotoIDs.isEmpty else {
            return []
        }

        let count = min(16, samplePhotoIDs.count)
        return (0 ..< count).map { samplePhotoIDs[($0 + offset) % samplePhotoIDs.count] }
    }

    static let samples: [AlbumViewItem] = [
        .init(id: 1, name: "우리 가족", createdAt: .now, count: 678, photoIDs: samplePhotoIDs(offset: 0)),
        .init(id: 2, name: "집집 🏠", createdAt: .now, count: 234, photoIDs: samplePhotoIDs(offset: 2)),
        .init(id: 3, name: "도쿄 여행 🍥", createdAt: .now, count: 456, photoIDs: samplePhotoIDs(offset: 4)),
        .init(id: 4, name: "솝트", createdAt: .now, count: 1234, photoIDs: samplePhotoIDs(offset: 6)),
        .init(id: 5, name: "호미c🐶", createdAt: .now, count: 45, photoIDs: samplePhotoIDs(offset: 8)),
        .init(id: 6, name: "도쿄 여행b 🍥", createdAt: .now, count: 456, photoIDs: samplePhotoIDs(offset: 10)),
        .init(id: 7, name: "솝트a", createdAt: .now, count: 1234, photoIDs: samplePhotoIDs(offset: 12)),
        .init(id: 8, name: "호미c🐶", createdAt: .now, count: 45, photoIDs: samplePhotoIDs(offset: 14)),
        .init(id: 9, name: "솝트b", createdAt: .now, count: 1234, photoIDs: samplePhotoIDs(offset: 16)),
        .init(id: 10, name: "호미a🐶", createdAt: .now, count: 45, photoIDs: samplePhotoIDs(offset: 18))
    ]

    init(storedAlbum: StoredAlbum) {
        self.init(
            id: storedAlbum.id,
            name: storedAlbum.name,
            createdAt: storedAlbum.createdAt,
            count: storedAlbum.photoCount,
            photoIDs: [],
            thumbnailLocalIdentifiers: storedAlbum.thumbnailLocalIdentifiers,
            isFavorite: storedAlbum.isFavorite
        )
    }
}
