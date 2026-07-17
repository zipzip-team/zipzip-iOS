//
//  AlbumPhotoPickerViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation
import SQLiteData

@Observable
final class AlbumPhotoPickerViewModel {
    @ObservationIgnored
    @Dependency(\.photoSections) private var photoSectionsProvider

    let albums: [Album]
    let showsAlbumTab: Bool

    private(set) var sections: [PhotoSection]
    private(set) var albumSections: [PhotoSection] = []
    private(set) var selectedAlbum: Album?
    private(set) var selectedLocalIdentifiers: [String]
    private(set) var isCompleting = false

    var importTab: BottomSheetTabSelection = .left

    private let onComplete: ([String]) async -> Bool

    init(
        albums: [Album] = [],
        showsAlbumTab: Bool = false,
        sections: [PhotoSection] = [],
        selectedLocalIdentifiers: [String] = [],
        onComplete: @escaping ([String]) async -> Bool
    ) {
        self.albums = albums
        self.showsAlbumTab = showsAlbumTab
        self.sections = sections
        self.selectedLocalIdentifiers = selectedLocalIdentifiers
        self.onComplete = onComplete
    }

    func loadPhotos() async {
        do {
            let library = try await photoSectionsProvider.loadLibrary()
            let registeredDeviceIDs = try await photoSectionsProvider.loadRegisteredDeviceIDs()
            sections = await photoSectionsProvider.sections(
                from: library,
                filters: [],
                registeredDeviceIDs: registeredDeviceIDs
            )
        } catch {
            sections = []
        }
    }

    func selectImportTab(_ tab: BottomSheetTabSelection) {
        importTab = tab
        selectedAlbum = nil
        albumSections = []
    }

    func selectImportAlbum(_ album: Album) async {
        selectedAlbum = album
        albumSections = []
        do {
            albumSections = try await photoSectionsProvider.loadAlbumSections(albumID: album.id)
        } catch {
            albumSections = []
        }
    }

    func returnToAlbumList() {
        selectedAlbum = nil
        albumSections = []
    }

    var isCompletionDisabled: Bool {
        selectedLocalIdentifiers.isEmpty || isCompleting
    }

    /// 현재 표시 중인 섹션에서 선택된 사진의 id 목록. 선택은 localIdentifier 기준으로 관리되어
    /// 사진 탭과 사진집 탭 사이에서 동일 사진의 선택 상태가 유지된다.
    func selectedPhotoIDs(in sections: [PhotoSection]) -> [UUID] {
        let identifierToID = Dictionary(
            sections.flatMap(\.photos).map { ($0.localIdentifier, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        return selectedLocalIdentifiers.compactMap { identifierToID[$0] }
    }

    func toggleSelection(_ id: UUID, in sections: [PhotoSection]) {
        guard let localIdentifier = sections.flatMap(\.photos).first(where: { $0.id == id })?.localIdentifier,
              !localIdentifier.isEmpty
        else {
            return
        }

        if let index = selectedLocalIdentifiers.firstIndex(of: localIdentifier) {
            selectedLocalIdentifiers.remove(at: index)
        } else {
            selectedLocalIdentifiers.append(localIdentifier)
        }
    }

    func completeSelection() async -> Bool {
        guard !isCompletionDisabled else {
            return false
        }

        isCompleting = true
        defer { isCompleting = false }
        return await onComplete(selectedLocalIdentifiers)
    }
}
