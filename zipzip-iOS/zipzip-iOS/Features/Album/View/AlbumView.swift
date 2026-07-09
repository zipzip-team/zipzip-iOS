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

    private let albums = AlbumViewItem.samples
    private let columns = [
        GridItem(.fixed(170), spacing: 17),
        GridItem(.fixed(170), spacing: 17)
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
                    case let .detail(album):
                        if album.photoCount == 0 {
                            AlbumDetailEmptyView(album: album)
                        } else {
                            AlbumDetailView(
                                album: album,
                                onEditPhotoInfo: showPhotoInfoEdit
                            ) { isSelectionMode, selectedPhotoIDs in
                                AlbumDetailGalleryPlaceholderView(
                                    photoCount: album.photoCount,
                                    showsSelectionControls: isSelectionMode,
                                    selectedPhotoIDs: selectedPhotoIDs,
                                    onOpenPhoto: showPhotoDetail
                                )
                            }
                        }
                    case let .photoDetail(photo):
                        PhotoDetailView(photo: photo, deletionContext: .album)
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
            secondaryTitle: "삭제",
            primaryTitle: "앨범에서 제거",
            onSecondaryTap: dismissDeleteAlert,
            onPrimaryTap: dismissDeleteAlert
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
        let album = AlbumDetailItem(
            title: trimmedName.isEmpty ? "집집 🏠" : trimmedName,
            createdAt: .now,
            photoCount: 0
        )

        isCreateAlbumSheetPresented = false
        navigationPath = [.detail(album)]
    }

    private func showDetail(for album: AlbumViewItem) {
        navigationPath.append(
            .detail(
                .init(
                    title: album.name,
                    createdAt: .now,
                    photoCount: album.count
                )
            )
        )
    }

    private func showPhotoDetail(_ photo: Photo) {
        navigationPath.append(.photoDetail(photo))
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

    private func presentShareAlbumCreation() {}

    private func completeShareAlbumMove() {
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
}

private enum AlbumRoute: Hashable {
    case detail(AlbumDetailItem)
    case photoDetail(Photo)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
            .frame(width: 358)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct AlbumShareDestinationSheet: View {
    let shareAlbums: [ShareAlbum]
    let sharedAlbums: [Album]
    let onCancel: () -> Void
    let onComplete: () -> Void
    let onAddTap: () -> Void

    @State private var selectedShareAlbum: ShareAlbum?
    @State private var selectedAlbumID: Album.ID?

    var body: some View {
        BottomSheet(
            leftItem: {
                AlbumSheetTextButton(title: "취소", action: onCancel)
            },
            rightItem: {
                if selectedShareAlbum == nil {
                    addButton
                } else {
                    AlbumSheetTextButton(title: "완료", action: onComplete)
                }
            }
        ) {
            if selectedShareAlbum == nil {
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
    let id: String
    let name: String
    let count: Int
}

extension AlbumViewItem {
    fileprivate static let samples: [AlbumViewItem] = [
        .init(id: "1", name: "우리 가족", count: 678),
        .init(id: "2", name: "집집 🏠", count: 234),
        .init(id: "3", name: "도쿄 여행 🍥", count: 456),
        .init(id: "4", name: "솝트", count: 1234),
        .init(id: "5", name: "호미c🐶", count: 45),
        .init(id: "6", name: "도쿄 여행b 🍥", count: 456),
        .init(id: "7", name: "솝트a", count: 1234),
        .init(id: "8", name: "호미c🐶", count: 45),
        .init(id: "9", name: "솝트b", count: 1234),
        .init(id: "10", name: "호미a🐶", count: 45)
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
    }
}
