//
//  AlbumView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct AlbumView: View {
    @Binding private var isSelectionMode: Bool
    @Binding private var isDetailPresented: Bool
    @State private var navigationPath: [AlbumRoute] = []
    @State private var selectedAlbumIDs: [AlbumViewItem.ID] = []
    @State private var isDeleteAlertPresented = false
    @State private var isCreateAlbumSheetPresented = false
    @State private var isShareAlbumSheetPresented = false
    @State private var createAlbumName = ""

    @State private var albums = AlbumViewItem.samples
    private let columns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    init(
        isSelectionMode: Binding<Bool>,
        isDetailPresented: Binding<Bool> = .constant(false)
    ) {
        _isSelectionMode = isSelectionMode
        _isDetailPresented = isDetailPresented
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            albumList
                .toolbarVisibility(.hidden, for: .navigationBar)
                .navigationDestination(for: AlbumRoute.self) { route in
                    switch route {
                    case let .detail(albumID):
                        albumDetailDestination(for: albumID)
                    case let .photoDetail(albumID, photo):
                        PhotoDetailView(
                            photo: photo,
                            deletionContext: .album,
                            onDelete: { action in
                                deletePhotos([photo.id], from: albumID, action: action)
                            }
                        )
                    case let .photoInfoEdit(metadata):
                        PhotoInfoEditView(metadata: metadata)
                    }
                }
        }
        .onChange(of: navigationPath) { _, newValue in
            isDetailPresented = !newValue.isEmpty
        }
        .onDisappear {
            isDetailPresented = false
        }
    }

    private var albumList: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                AlbumTitleHeader(isVisible: !isSelectionMode)
                    .padding(.top, 15)
                    .frame(height: 67, alignment: .bottom)

                LazyVGrid(
                    columns: columns,
                    alignment: .center,
                    spacing: 20
                ) {
                    ForEach(albums) { album in
                        AlbumGridCard(
                            album: album,
                            selectionNumber: selectionNumber(for: album),
                            isSelectionMode: isSelectionMode,
                            onSelectionTap: { toggleSelection(for: album) },
                            onOpenTap: { showDetail(for: album) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 17)
                .padding(.bottom, isSelectionMode && !selectedAlbumIDs.isEmpty ? 140 : 20)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            AlbumHeaderActionButton(
                onSelectionTap: enterSelectionMode,
                onAddTap: presentCreateAlbumSheet
            )
            .padding(.top, 19)
            .padding(.trailing, 16)
            .opacity(isSelectionMode ? 0 : 1)
            .allowsHitTesting(!isSelectionMode)
            .accessibilityHidden(isSelectionMode)
        }
        .overlay(alignment: .topLeading) {
            RoundedTextButton(title: "취소", style: .cancel, action: exitSelectionMode)
                .padding(.top, 19)
                .padding(.leading, 16)
                .opacity(isSelectionMode ? 1 : 0)
                .allowsHitTesting(isSelectionMode)
                .accessibilityHidden(!isSelectionMode)
        }
        .overlay(alignment: .bottom) {
            ZStack {
                if isSelectionMode, !selectedAlbumIDs.isEmpty {
                    ActionBar(items: selectionActionItems)
                        .padding(.bottom, 49)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelectionMode && !selectedAlbumIDs.isEmpty)
        }
        .onChange(of: isSelectionMode) { _, newValue in
            if !newValue {
                selectedAlbumIDs.removeAll()
                isDeleteAlertPresented = false
                isShareAlbumSheetPresented = false
            }
        }
        .onChange(of: isCreateAlbumSheetPresented) { _, newValue in
            if !newValue {
                createAlbumName = ""
            }
        }
        .bottomSheetAlert(
            isPresented: $isDeleteAlertPresented,
            title: "\(selectedAlbumIDs.count)개의 사진집을 삭제하시겠어요?",
            message: "사진집에 담긴 사진들은 삭제되지 않아요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: dismissDeleteAlert,
            onPrimaryTap: confirmSelectedAlbumDeletion
        )
        .bottomSheet(
            isPresented: $isCreateAlbumSheetPresented,
            detents: [.height(549)],
            initialDetent: .height(549),
            showsDragIndicator: .visible,
            expandsToLargestDetentOnScroll: false
        ) { _ in
            BottomSheet(
                leftItem: {
                    AlbumSheetTextButton(title: "취소", action: dismissCreateAlbumSheet)
                }
            ) {
                AlbumCreateSheetContent(
                    albumName: $createAlbumName,
                    onDeleteTap: resetCreateAlbumDraft,
                    onCreateTap: createAlbum
                )
            }
        }
        .bottomSheet(isPresented: $isShareAlbumSheetPresented, detents: [.full]) { _ in
            AlbumShareDestinationSheet(
                shareAlbums: ShareAlbum.samples,
                sharedAlbums: Album.sharedSamples,
                onCancel: dismissShareAlbumSheet,
                onComplete: completeShareAlbumMove,
                onAddTap: presentShareAlbumCreation
            )
        }
    }

    private var selectionActionItems: [ActionBarItem] {
        [
            .init(icon: .moveToShare, title: "공유집으로", action: moveSelectedAlbumsToShare),
            .init(icon: .delete, title: "삭제", action: deleteSelectedAlbums)
        ]
    }

    @ViewBuilder private func albumDetailDestination(for albumID: AlbumViewItem.ID) -> some View {
        if let album = albums.first(where: { $0.id == albumID }) {
            let actions = AlbumDetailActions(
                onRename: { renameAlbum(albumID, to: $0) },
                onDelete: { deleteAlbum(albumID) },
                onAddPhotos: { addPhotos($0, to: albumID) },
                onDeletePhotos: { photoIDs, action in
                    deletePhotos(photoIDs, from: albumID, action: action)
                },
                onMovePhotos: { photoIDs, destination in
                    movePhotos(photoIDs, from: albumID, to: destination)
                }
            )

            if !album.hasPhotos {
                AlbumDetailEmptyView(
                    album: album.detailItem,
                    actions: actions,
                    moveAlbums: moveDestinations(excluding: albumID),
                    photoPickerSections: availablePhotoSections(excluding: album.photoIDs)
                )
            } else {
                AlbumDetailView(
                    album: album.detailItem,
                    actions: actions,
                    moveAlbums: moveDestinations(excluding: albumID),
                    photoPickerSections: availablePhotoSections(excluding: album.photoIDs),
                    onEditPhotoInfo: showPhotoInfoEdit
                ) { isSelectionMode, selectedPhotoIDs in
                    AlbumDetailGalleryPlaceholderView(
                        sections: photoSections(for: album),
                        photoCount: album.count,
                        showsSelectionControls: isSelectionMode,
                        selectedPhotoIDs: selectedPhotoIDs,
                        onOpenPhoto: { showPhotoDetail($0, in: albumID) }
                    )
                }
            }
        }
    }

    private func enterSelectionMode() {
        isSelectionMode = true
    }

    private func exitSelectionMode() {
        selectedAlbumIDs.removeAll()
        isSelectionMode = false
    }

    private func presentCreateAlbumSheet() {
        isCreateAlbumSheetPresented = true
    }

    private func dismissCreateAlbumSheet() {
        isCreateAlbumSheetPresented = false
    }

    private func resetCreateAlbumDraft() {
        createAlbumName = ""
    }

    private func createAlbum() {
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

    private func showDetail(for album: AlbumViewItem) {
        navigationPath.append(.detail(album.id))
    }

    private func showPhotoDetail(_ photo: Photo, in albumID: AlbumViewItem.ID) {
        navigationPath.append(.photoDetail(albumID: albumID, photo: photo))
    }

    private func showPhotoInfoEdit(for photoID: UUID) {
        guard let photo = PhotoSection.sample
            .flatMap(\.photos)
            .first(where: { $0.id == photoID })
        else {
            return
        }

        navigationPath.append(.photoInfoEdit(photo.metadata))
    }

    private func toggleSelection(for album: AlbumViewItem) {
        if let index = selectedAlbumIDs.firstIndex(of: album.id) {
            selectedAlbumIDs.remove(at: index)
        } else {
            selectedAlbumIDs.append(album.id)
        }
    }

    private func selectionNumber(for album: AlbumViewItem) -> Int? {
        selectedAlbumIDs.firstIndex(of: album.id).map { $0 + 1 }
    }

    private func moveSelectedAlbumsToShare() {
        guard !selectedAlbumIDs.isEmpty else {
            return
        }

        isShareAlbumSheetPresented = true
    }

    private func dismissShareAlbumSheet() {
        isShareAlbumSheetPresented = false
    }

    private func presentShareAlbumCreation() {
        // 공유집 생성 화면이 구현되면 이 진입점을 연결한다.
    }

    private func completeShareAlbumMove(to _: ShareAlbum, album _: Album) {
        let movedAlbumIDs = Set(selectedAlbumIDs)
        albums.removeAll { movedAlbumIDs.contains($0.id) }
        isShareAlbumSheetPresented = false
        exitSelectionMode()
    }

    private func deleteSelectedAlbums() {
        guard !selectedAlbumIDs.isEmpty else {
            return
        }

        isDeleteAlertPresented = true
    }

    private func dismissDeleteAlert() {
        isDeleteAlertPresented = false
    }

    private func confirmSelectedAlbumDeletion() {
        let idsToDelete = Set(selectedAlbumIDs)
        albums.removeAll { idsToDelete.contains($0.id) }
        isDeleteAlertPresented = false
        exitSelectionMode()
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

    private func deletePhotos(
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

    private func moveDestinations(excluding albumID: AlbumViewItem.ID) -> [Album] {
        albums
            .filter { $0.id != albumID }
            .map { Album(id: $0.id, name: $0.name, count: $0.count) }
    }

    private func availablePhotoSections(excluding photoIDs: [UUID]) -> [PhotoSection] {
        let excludedPhotoIDs = Set(photoIDs)

        return PhotoSection.sample.compactMap { section in
            let photos = section.photos.filter { !excludedPhotoIDs.contains($0.id) }
            return photos.isEmpty ? nil : PhotoSection(title: section.title, photos: photos)
        }
    }

    private func photoSections(for album: AlbumViewItem) -> [PhotoSection] {
        let photoIDs = Set(album.photoIDs)

        return PhotoSection.sample.compactMap { section in
            let photos = section.photos.filter { photoIDs.contains($0.id) }
            return photos.isEmpty ? nil : PhotoSection(title: section.title, photos: photos)
        }
    }
}

private enum AlbumRoute: Hashable {
    case detail(AlbumViewItem.ID)
    case photoDetail(albumID: AlbumViewItem.ID, photo: Photo)
    case photoInfoEdit(PhotoMetadata)
}

private struct AlbumGridCard: View {
    let album: AlbumViewItem
    let selectionNumber: Int?
    let isSelectionMode: Bool
    let onSelectionTap: () -> Void
    let onOpenTap: () -> Void

    var body: some View {
        Button(action: buttonAction) {
            card
        }
        .buttonStyle(StaticButtonStyle())
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(album.name), \(album.count)장")
        .accessibilityValue(isSelectionMode ? accessibilityValue : "")
        .accessibilityAddTraits(isSelectionMode && selectionNumber != nil ? .isSelected : [])
    }

    private var card: some View {
        AlbumCard(
            name: album.name,
            count: album.count,
            state: state
        )
    }

    private func buttonAction() {
        if isSelectionMode {
            onSelectionTap()
        } else {
            onOpenTap()
        }
    }

    private var state: AlbumFolderState {
        if let selectionNumber {
            .selected(count: selectionNumber)
        } else {
            .plain
        }
    }

    private var accessibilityValue: String {
        if let selectionNumber {
            "\(selectionNumber)번째 선택됨"
        } else {
            "선택 안 됨"
        }
    }
}

private struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private struct AlbumSheetTextButton: View {
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(isDisabled ? .grey700 : .white00)
                .frame(width: 72, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct AlbumCreateSheetContent: View {
    @Binding var albumName: String

    let onDeleteTap: () -> Void
    let onCreateTap: () -> Void

    var body: some View {
        VStack(spacing: 34) {
            AlbumFolder(state: .plain) {
                EmptyView()
            }
            .accessibilityHidden(true)

            VStack(spacing: 49) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("사진집 이름")
                        .font(.t3_md)
                        .foregroundStyle(.grey300)

                    TextInput("이름 입력", text: $albumName)
                }

                HStack(spacing: 16) {
                    CommonButton(
                        title: "삭제",
                        property1: .secondary,
                        action: onDeleteTap
                    )

                    CommonButton(
                        title: "생성",
                        property1: .cta,
                        action: onCreateTap
                    )
                }
            }
            .frame(maxWidth: 358)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct AlbumShareDestinationSheet: View {
    @Environment(AuthenticationState.self) private var authenticationState

    let shareAlbums: [ShareAlbum]
    let sharedAlbums: [Album]
    let onCancel: () -> Void
    let onComplete: (ShareAlbum, Album) -> Void
    let onAddTap: () -> Void

    @State private var selectedShareAlbum: ShareAlbum?
    @State private var selectedAlbumID: Album.ID?

    var body: some View {
        BottomSheet(
            leftItem: {
                AlbumSheetTextButton(title: "취소", action: onCancel)
            },
            rightItem: {
                if authenticationState.isLoggedIn {
                    if selectedShareAlbum == nil {
                        addButton
                    } else {
                        AlbumSheetTextButton(
                            title: "완료",
                            isDisabled: selectedAlbumID == nil,
                            action: completeSelection
                        )
                    }
                }
            }
        ) {
            if !authenticationState.isLoggedIn {
                ShareLoginPrompt {
                    authenticationState.logIn()
                }
            } else if selectedShareAlbum == nil {
                ShareAlbumList(albums: shareAlbums, onSelect: selectShareAlbum)
            } else {
                AlbumSelectionGrid(
                    albums: sharedAlbums,
                    selectedAlbumID: selectedAlbumID,
                    onSelect: selectAlbum
                )
            }
        }
    }

    private func selectShareAlbum(_ album: ShareAlbum) {
        selectedShareAlbum = album
        selectedAlbumID = nil
    }

    private func selectAlbum(_ album: Album) {
        selectedAlbumID = album.id
    }

    private func completeSelection() {
        guard let selectedShareAlbum,
              let selectedAlbum = sharedAlbums.first(where: { $0.id == selectedAlbumID })
        else {
            return
        }

        onComplete(selectedShareAlbum, selectedAlbum)
    }

    private var addButton: some View {
        Button(action: onAddTap) {
            Image(.plus)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white00)
                .frame(width: 24, height: 24)
                .frame(width: 72, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("공유집 추가")
    }
}

private struct AlbumTitleHeader: View {
    let isVisible: Bool

    var body: some View {
        Text("사진집")
            .font(.t1_sb)
            .foregroundStyle(.grey900)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(!isVisible)
    }
}

struct AlbumHeaderActionButton: View {
    let onSelectionTap: () -> Void
    let onAddTap: () -> Void

    var body: some View {
        RoundedIconButton(items: [
            .init(
                id: "selection",
                icon: .iconSelection,
                accessibilityLabel: "사진집 선택",
                action: onSelectionTap
            ),
            .init(
                id: "add",
                icon: .plus,
                accessibilityLabel: "사진집 추가",
                action: onAddTap
            )
        ])
    }
}

private struct AlbumViewItem: Identifiable, Equatable {
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

    fileprivate static let samples: [AlbumViewItem] = [
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

#Preview("Album View", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumViewPreview()
}

private struct AlbumViewPreview: View {
    @State private var selection: NavbarTab = .album
    @State private var isSelectionMode = false

    var body: some View {
        AlbumView(isSelectionMode: $isSelectionMode)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isSelectionMode {
                    Navbar(selection: $selection)
                        .padding(.bottom, 28)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .environment(AuthenticationState())
    }
}
