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
    var createAlbumName = ""
    private(set) var isCreatingAlbum = false

    private(set) var selectedAlbumIDs: [AlbumViewItem.ID] = []
    private(set) var albums: [AlbumViewItem]
    @ObservationIgnored private let albumStore: AlbumStore
    @ObservationIgnored private let photoSectionsProvider: PhotoSectionsProvider
    @ObservationIgnored private let photoDeletion: PhotoDeletionService
    @ObservationIgnored private let loadsAlbumsFromDatabase: Bool
    @ObservationIgnored private var favoriteWriteTasks: [String: Task<Void, Never>] = [:]

    init(
        albums: [AlbumViewItem]? = nil,
        albumStore: AlbumStore = AlbumStore(),
        photoSectionsProvider: PhotoSectionsProvider = PhotoSectionsProvider(),
        photoDeletion: PhotoDeletionService = PhotoDeletionService()
    ) {
        self.albums = albums ?? []
        self.albumStore = albumStore
        self.photoSectionsProvider = photoSectionsProvider
        self.photoDeletion = photoDeletion
        self.loadsAlbumsFromDatabase = albums == nil
    }

    var isCreateAlbumDisabled: Bool {
        createAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreatingAlbum
    }

    func loadAlbums() async {
        guard loadsAlbumsFromDatabase else { return }

        guard let storedAlbums = try? await albumStore.fetchAlbums() else { return }
        albums = storedAlbums
            .map(AlbumViewItem.init)
            .filter { !$0.isFavorite || $0.hasPhotos }
    }

    func enterSelectionMode() {
        isSelectionMode = true
    }

    func exitSelectionMode() {
        selectedAlbumIDs.removeAll()
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

        guard let storedAlbum = try? await albumStore.createAlbum(name: trimmedName) else { return nil }
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

    func showPhotoInfoEdit(for photoIDs: [UUID], from albumID: AlbumViewItem.ID, router: Router) async {
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
        router.push(.photoInfoEdit(metadata: firstPhoto.metadata, localIdentifiers: localIdentifiers))
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

        isShareAlbumSheetPresented = true
    }

    func dismissShareAlbumSheet() {
        isShareAlbumSheetPresented = false
    }

    func completeShareAlbumMove(to _: ShareAlbum) {
        let movedAlbumIDs = Set(selectedAlbumIDs)
        albums.removeAll { movedAlbumIDs.contains($0.id) }
        exitSelectionMode()
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
                    Task {
                        await self?.renameAlbum(albumID, to: name)
                    }
                },
                onDelete: { [weak self] in
                    Task {
                        guard await self?.deleteAlbums(
                            ids: [albumID],
                            beforeLocalStateUpdate: router.pop
                        ) == true else {
                            return
                        }
                    }
                },
                onAddPhotos: { [weak self] localIdentifiers in
                    Task {
                        await self?.addPhotos(
                            localIdentifiers: localIdentifiers,
                            to: [.album(albumID)]
                        )
                    }
                },
                onDeletePhotos: { [weak self] photoIDs, action in
                    Task { await self?.deletePhotos(photoIDs, from: albumID, action: action) }
                },
                onMovePhotos: { [weak self] photoIDs, destination in
                    Task {
                        guard let self,
                              await self.movePhotos(photoIDs, from: albumID, to: destination),
                              let destinationAlbumID = destination.firstPersonalAlbumID
                        else {
                            return
                        }

                        router.push(.albumDetail(destinationAlbumID))
                    }
                }
            ),
            onEditPhotoInfo: { [weak self] photoIDs in
                Task { await self?.showPhotoInfoEdit(for: photoIDs, from: albumID, router: router) }
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

    /// 같은 사진에 대한 즐겨찾기 쓰기를 제출 순서대로 직렬화한다.
    /// 연타 시 마지막 탭 의도가 DB 최종 상태와 일치하도록 보장한다.
    func setPhotoFavorite(localIdentifier: String, isFavorite: Bool) {
        let previous = favoriteWriteTasks[localIdentifier]
        favoriteWriteTasks[localIdentifier] = Task { [weak self] in
            await previous?.value
            guard let self else { return }

            try? await albumStore.setPhotoFavorite(
                localIdentifier: localIdentifier,
                isFavorite: isFavorite
            )
            await loadAlbums()
        }
    }

    func photoSections(for albumID: AlbumViewItem.ID) async -> [PhotoSection] {
        (try? await photoSectionsProvider.loadAlbumSections(albumID: albumID)) ?? []
    }

    /// 사진 목록 화면에서 선택한 사진을 개인 사진집에 영구적으로 추가한다.
    func addPhotos(localIdentifiers: [String], to destinations: [ShareDestination]) async -> Bool {
        let albumIDs = destinations.compactMap { destination -> Album.ID? in
            guard case let .album(albumID) = destination else {
                return nil
            }
            return albumID
        }

        guard !albumIDs.isEmpty, !localIdentifiers.isEmpty else {
            return false
        }

        do {
            try await albumStore.addPhotos(localIdentifiers: localIdentifiers, to: albumIDs)
        } catch {
            return false
        }

        await loadAlbums()
        return true
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

        guard !ids.isEmpty, !destinationAlbumIDs.isEmpty else {
            return false
        }

        do {
            try await albumStore.moveAlbumPhotos(
                ids: ids,
                from: sourceAlbumID,
                to: destinationAlbumIDs
            )
        } catch {
            return false
        }

        await loadAlbums()
        return true
    }

    private func renameAlbum(_ albumID: AlbumViewItem.ID, to name: String) async {
        if loadsAlbumsFromDatabase {
            do {
                try await albumStore.renameAlbum(id: albumID, name: name)
            } catch {
                return
            }
        }

        guard let index = albums.firstIndex(where: { $0.id == albumID }) else {
            return
        }
        albums[index].name = name
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
