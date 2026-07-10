//
//  AlbumViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation

@Observable
final class AlbumViewModel {
    var navigationPath: [AlbumRoute] = []
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

    private(set) var selectedAlbumIDs: [AlbumViewItem.ID] = []
    private(set) var albums: [AlbumViewItem]

    init(albums: [AlbumViewItem] = AlbumViewItem.samples) {
        self.albums = albums
    }

    var isDetailPresented: Bool {
        !navigationPath.isEmpty
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

    func presentCreateAlbumSheet() {
        isCreateAlbumSheetPresented = true
    }

    func dismissCreateAlbumSheet() {
        isCreateAlbumSheetPresented = false
    }

    func resetCreateAlbumDraft() {
        createAlbumName = ""
    }

    func createAlbum() {
        let trimmedName = createAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = AlbumViewItem(
            id: UUID(),
            name: trimmedName.isEmpty ? "집집 🏠" : trimmedName,
            createdAt: .now,
            count: 0,
            photoIDs: []
        )

        albums.append(album)
        isCreateAlbumSheetPresented = false
        navigationPath = [.detail(album.id)]
    }

    func showDetail(for album: AlbumViewItem) {
        navigationPath.append(.detail(album.id))
    }

    func showPhotoDetail(_ photo: Photo, in albumID: AlbumViewItem.ID) {
        navigationPath.append(.photoDetail(albumID: albumID, photo: photo))
    }

    func showPhotoInfoEdit(for photoID: UUID) {
        guard let photo = PhotoSection.sample
            .flatMap(\.photos)
            .first(where: { $0.id == photoID })
        else {
            return
        }

        navigationPath.append(.photoInfoEdit(photo.metadata))
    }

    func toggleSelection(for album: AlbumViewItem) {
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

    func presentShareAlbumCreation() {
        // 공유집 생성 화면이 구현되면 이 진입점을 연결한다.
    }

    func completeShareAlbumMove(to _: ShareAlbum, album _: Album) {
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
        let idsToDelete = Set(selectedAlbumIDs)
        albums.removeAll { idsToDelete.contains($0.id) }
        exitSelectionMode()
    }

    func album(for id: AlbumViewItem.ID) -> AlbumViewItem? {
        albums.first(where: { $0.id == id })
    }

    func makeDetailViewModel(for albumID: AlbumViewItem.ID) -> AlbumDetailViewModel {
        AlbumDetailViewModel(
            actions: AlbumDetailActions(
                onRename: { [weak self] in self?.renameAlbum(albumID, to: $0) },
                onDelete: { [weak self] in self?.deleteAlbum(albumID) },
                onAddPhotos: { [weak self] in self?.addPhotos($0, to: albumID) },
                onDeletePhotos: { [weak self] photoIDs, action in
                    self?.deletePhotos(photoIDs, from: albumID, action: action)
                },
                onMovePhotos: { [weak self] photoIDs, destination in
                    self?.movePhotos(photoIDs, from: albumID, to: destination)
                }
            ),
            onEditPhotoInfo: { [weak self] in self?.showPhotoInfoEdit(for: $0) }
        )
    }

    func deletePhotos(
        _ photoIDs: [UUID],
        from albumID: AlbumViewItem.ID,
        action: PhotoDeletionAction
    ) {
        if action == .deletePermanently {
            for albumIndex in albums.indices {
                removePhotos(photoIDs, fromAlbumAt: albumIndex)
            }
            return
        }

        guard let index = albums.firstIndex(where: { $0.id == albumID }) else {
            return
        }

        removePhotos(photoIDs, fromAlbumAt: index)
    }

    func moveDestinations(excluding albumID: AlbumViewItem.ID) -> [Album] {
        albums
            .filter { $0.id != albumID }
            .map { Album(id: $0.id, name: $0.name, count: $0.count) }
    }

    func availablePhotoSections(excluding photoIDs: [UUID]) -> [PhotoSection] {
        let excludedPhotoIDs = Set(photoIDs)

        return PhotoSection.sample.compactMap { section in
            let photos = section.photos.filter { !excludedPhotoIDs.contains($0.id) }
            return photos.isEmpty ? nil : PhotoSection(title: section.title, photos: photos)
        }
    }

    func photoSections(for album: AlbumViewItem) -> [PhotoSection] {
        let photoIDs = Set(album.photoIDs)

        return PhotoSection.sample.compactMap { section in
            let photos = section.photos.filter { photoIDs.contains($0.id) }
            return photos.isEmpty ? nil : PhotoSection(title: section.title, photos: photos)
        }
    }

    private func renameAlbum(_ albumID: AlbumViewItem.ID, to name: String) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else {
            return
        }

        albums[index].name = name
    }

    private func deleteAlbum(_ albumID: AlbumViewItem.ID) {
        albums.removeAll { $0.id == albumID }
        navigationPath.removeAll()
    }

    private func addPhotos(_ photoIDs: [UUID], to albumID: AlbumViewItem.ID) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else {
            return
        }

        let existingIDs = Set(albums[index].photoIDs)
        let newIDs = photoIDs.filter { !existingIDs.contains($0) }
        albums[index].photoIDs.append(contentsOf: newIDs)
        albums[index].count += newIDs.count
    }

    private func movePhotos(
        _ photoIDs: [UUID],
        from albumID: AlbumViewItem.ID,
        to destination: ShareDestination
    ) {
        if case let .album(destinationID) = destination,
           let destinationIndex = albums.firstIndex(where: { $0.id == destinationID }) {
            let destinationPhotoIDs = Set(albums[destinationIndex].photoIDs)
            let movedPhotoIDs = photoIDs.filter { !destinationPhotoIDs.contains($0) }
            albums[destinationIndex].photoIDs.append(contentsOf: movedPhotoIDs)
            albums[destinationIndex].count += movedPhotoIDs.count
        }

        deletePhotos(photoIDs, from: albumID, action: .removeFromAlbum)
    }

    private func removePhotos(_ photoIDs: [UUID], fromAlbumAt index: Int) {
        let idsToDelete = Set(photoIDs)
        let previousCount = albums[index].photoIDs.count
        albums[index].photoIDs.removeAll { idsToDelete.contains($0) }
        let deletedCount = previousCount - albums[index].photoIDs.count
        albums[index].count = max(0, albums[index].count - deletedCount)
    }
}

enum AlbumRoute: Hashable {
    case detail(AlbumViewItem.ID)
    case photoDetail(albumID: AlbumViewItem.ID, photo: Photo)
    case photoInfoEdit(PhotoMetadata)
}

struct AlbumViewItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var count: Int
    var photoIDs: [UUID]

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
        .init(id: UUID(), name: "우리 가족", createdAt: .now, count: 678, photoIDs: samplePhotoIDs(offset: 0)),
        .init(id: UUID(), name: "집집 🏠", createdAt: .now, count: 234, photoIDs: samplePhotoIDs(offset: 2)),
        .init(id: UUID(), name: "도쿄 여행 🍥", createdAt: .now, count: 456, photoIDs: samplePhotoIDs(offset: 4)),
        .init(id: UUID(), name: "솝트", createdAt: .now, count: 1234, photoIDs: samplePhotoIDs(offset: 6)),
        .init(id: UUID(), name: "호미c🐶", createdAt: .now, count: 45, photoIDs: samplePhotoIDs(offset: 8)),
        .init(id: UUID(), name: "도쿄 여행b 🍥", createdAt: .now, count: 456, photoIDs: samplePhotoIDs(offset: 10)),
        .init(id: UUID(), name: "솝트a", createdAt: .now, count: 1234, photoIDs: samplePhotoIDs(offset: 12)),
        .init(id: UUID(), name: "호미c🐶", createdAt: .now, count: 45, photoIDs: samplePhotoIDs(offset: 14)),
        .init(id: UUID(), name: "솝트b", createdAt: .now, count: 1234, photoIDs: samplePhotoIDs(offset: 16)),
        .init(id: UUID(), name: "호미a🐶", createdAt: .now, count: 45, photoIDs: samplePhotoIDs(offset: 18))
    ]
}
