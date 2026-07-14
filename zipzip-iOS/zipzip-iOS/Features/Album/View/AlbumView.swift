//
//  AlbumView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct AlbumView: View {
    @Environment(Router.self) private var router
    @State private var viewModel: AlbumViewModel
    let shareViewModel: ShareViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    init(viewModel: AlbumViewModel, shareViewModel: ShareViewModel) {
        _viewModel = State(initialValue: viewModel)
        self.shareViewModel = shareViewModel
    }

    var body: some View {
        albumList
            .toolbarVisibility(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadAlbums()
            }
    }

    private var albumList: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                AlbumTitleHeader(isVisible: !viewModel.isSelectionMode)
                    .frame(height: 54, alignment: .bottom)

                if !viewModel.albums.isEmpty {
                    LazyVGrid(
                        columns: columns,
                        alignment: .center,
                        spacing: 20
                    ) {
                        ForEach(viewModel.albums) { album in
                            AlbumGridCard(
                                album: album,
                                selectionNumber: viewModel.selectionNumber(for: album),
                                isSelectionMode: viewModel.isSelectionMode,
                                onSelectionTap: { viewModel.toggleSelection(for: album) },
                                onOpenTap: { viewModel.showDetail(for: album, router: router) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 17)
                    .padding(.bottom, viewModel.isSelectionMode && !viewModel.selectedAlbumIDs.isEmpty ? 140 : 20)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }

            if viewModel.albums.isEmpty {
                AlbumCollectionEmptyView(onStartTap: viewModel.presentCreateAlbumSheet)
                    .padding(.bottom, 80)
            }
        }
        .overlay(alignment: .topTrailing) {
            AlbumHeaderActionButton(
                onSelectionTap: viewModel.enterSelectionMode,
                onAddTap: viewModel.presentCreateAlbumSheet
            )
            .padding(.top, 14)
            .padding(.trailing, 16)
            .opacity(viewModel.isSelectionMode ? 0 : 1)
            .allowsHitTesting(!viewModel.isSelectionMode)
            .accessibilityHidden(viewModel.isSelectionMode)
        }
        .overlay(alignment: .topLeading) {
            RoundedTextButton(title: "취소", style: .cancel, action: viewModel.exitSelectionMode)
                .padding(.top, 14)
                .padding(.leading, 16)
                .opacity(viewModel.isSelectionMode ? 1 : 0)
                .allowsHitTesting(viewModel.isSelectionMode)
                .accessibilityHidden(!viewModel.isSelectionMode)
        }
        .overlay(alignment: .bottom) {
            ZStack {
                if viewModel.isSelectionMode, !viewModel.selectedAlbumIDs.isEmpty {
                    ActionBar(items: selectionActionItems)
                        .padding(.bottom, 49)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(
                .easeInOut(duration: 0.2),
                value: viewModel.isSelectionMode && !viewModel.selectedAlbumIDs.isEmpty
            )
        }
        .bottomSheetAlert(
            isPresented: $viewModel.isDeleteAlertPresented,
            title: "\(viewModel.selectedAlbumIDs.count)개의 사진집을 삭제하시겠어요?",
            message: "사진집에 담긴 사진들은 삭제되지 않아요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: viewModel.dismissDeleteAlert,
            onPrimaryTap: viewModel.confirmSelectedAlbumDeletion
        )
        .bottomSheet(
            isPresented: $viewModel.isCreateAlbumSheetPresented,
            detents: [.height(549)],
            initialDetent: .height(549),
            showsDragIndicator: .visible,
            expandsToLargestDetentOnScroll: false
        ) { _ in
            BottomSheet(
                leftItem: {
                    BottomSheetCloseButton(action: viewModel.dismissCreateAlbumSheet)
                }
            ) {
                AlbumCreateSheetContent(
                    albumName: $viewModel.createAlbumName,
                    isCreateDisabled: viewModel.isCreateAlbumDisabled,
                    onDeleteTap: viewModel.resetCreateAlbumDraft,
                    onCreateTap: {
                        Task {
                            if let album = await viewModel.createAlbum() {
                                router.push(.albumDetail(album.id))
                            }
                        }
                    }
                )
            }
        }
        .bottomSheet(isPresented: $viewModel.isShareAlbumSheetPresented, detents: [.full]) { _ in
            AlbumShareDestinationSheet(
                shareAlbums: shareViewModel.groups,
                onCancel: viewModel.dismissShareAlbumSheet,
                onComplete: viewModel.completeShareAlbumMove
            )
        }
    }

    private var selectionActionItems: [ActionBarItem] {
        [
            .init(icon: .moveToShare, title: "공유그룹으로", action: viewModel.moveSelectedAlbumsToShare),
            .init(icon: .delete, title: "삭제", action: viewModel.deleteSelectedAlbums)
        ]
    }
}

struct AlbumDetailDestinationView: View {
    @Environment(Router.self) private var router
    @Environment(DIContainer.self) private var container
    @State private var photoSections: [PhotoSection] = []
    @State private var lastKnownAlbum: AlbumViewItem?

    let viewModel: AlbumViewModel
    let shareViewModel: ShareViewModel
    let albumID: AlbumViewItem.ID

    init(viewModel: AlbumViewModel, shareViewModel: ShareViewModel, albumID: AlbumViewItem.ID) {
        self.viewModel = viewModel
        self.shareViewModel = shareViewModel
        self.albumID = albumID
        _lastKnownAlbum = State(initialValue: viewModel.album(for: albumID))
    }

    var body: some View {
        if let album = viewModel.album(for: albumID) ?? lastKnownAlbum {
            let detailViewModel = viewModel.makeDetailViewModel(for: albumID, router: router)

            Group {
                if !album.hasPhotos {
                    AlbumDetailEmptyView(
                        album: album.detailItem,
                        viewModel: detailViewModel,
                        moveAlbums: viewModel.moveDestinations(excluding: albumID),
                        shareAlbums: shareViewModel.groups,
                        onOpenShareAlbum: loadSharedAlbums
                    )
                } else {
                    AlbumDetailView(
                        album: album.detailItem,
                        viewModel: detailViewModel,
                        moveAlbums: viewModel.moveDestinations(excluding: albumID),
                        shareAlbums: shareViewModel.groups,
                        onOpenShareAlbum: loadSharedAlbums
                    ) { detailViewModel in
                        AlbumDetailGalleryPlaceholderView(
                            sections: photoSections,
                            photoCount: album.count,
                            showsSelectionControls: detailViewModel.isSelectionMode,
                            selectedPhotoIDs: detailViewModel.selectedPhotoIDs,
                            onSelectPhoto: detailViewModel.togglePhotoSelection,
                            onOpenPhoto: { viewModel.showPhotoDetail($0, in: albumID, router: router) }
                        )
                    }
                }
            }
            .task(id: album.count) {
                photoSections = await viewModel.photoSections(for: albumID)
            }
            .onChange(of: viewModel.album(for: albumID)) { _, album in
                if let album {
                    lastKnownAlbum = album
                }
            }
        }
    }

    private func loadSharedAlbums(groupID: ShareAlbum.ID) async {
        await shareViewModel.loadSharedAlbums(
            groupID: groupID,
            using: DefaultShareGroupAPI(networkProvider: container.networkProvider)
        )
    }
}

private struct AlbumCollectionEmptyView: View {
    let onStartTap: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 10) {
                Image(.albumCollectionEmptyArtwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 86)
                    .accessibilityHidden(true)

                Image(.albumCollectionEmptyDescription)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 257, height: 20)
                    .accessibilityLabel("집을 만들어 사진을 보관해보세요!")
            }

            CommonButton(title: "시작하기", action: onStartTap)
                .frame(width: 171)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(album.name), \(album.count)장")
        .accessibilityValue(isSelectionMode ? accessibilityValue : "")
        .accessibilityAddTraits(isSelectionMode && selectionNumber != nil ? .isSelected : [])
    }

    private var card: some View {
        AlbumCard(
            name: album.name,
            count: album.count,
            state: state,
            thumbnailLocalIdentifiers: album.thumbnailLocalIdentifiers
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

    let isCreateDisabled: Bool
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
                        property1: isCreateDisabled ? .disabled : .cta,
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
    let onCancel: () -> Void
    let onComplete: (ShareAlbum) -> Void

    @State private var selectedShareAlbumID: ShareAlbum.ID?

    var body: some View {
        BottomSheet(
            leftItem: {
                BottomSheetCloseButton(action: onCancel)
            },
            rightItem: {
                if authenticationState.isLoggedIn {
                    AlbumSheetTextButton(
                        title: "완료",
                        isDisabled: true,
                        action: completeSelection
                    )
                }
            }
        ) {
            if !authenticationState.isLoggedIn {
                ShareLoginPrompt {
                    authenticationState.requestLogin(.album)
                }
            } else {
                ShareAlbumList(
                    albums: shareAlbums,
                    selectedShareAlbumID: selectedShareAlbumID,
                    showsChevron: false,
                    onSelect: selectShareAlbum
                )
            }
        }
    }

    private func selectShareAlbum(_ album: ShareAlbum) {
        selectedShareAlbumID = album.id
    }

    private func completeSelection() {
        guard let selectedShareAlbum = shareAlbums.first(where: { $0.id == selectedShareAlbumID }) else {
            return
        }

        onComplete(selectedShareAlbum)
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

#Preview("Album View", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumViewPreview(albums: AlbumViewItem.samples)
}

#Preview("Album View Empty", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumViewPreview(albums: [])
}

private struct AlbumViewPreview: View {
    @State private var selection: NavbarTab = .album
    @State private var viewModel = AlbumViewModel(albums: AlbumViewItem.samples)

    init(albums: [AlbumViewItem]) {
        _viewModel = State(initialValue: AlbumViewModel(albums: albums))
    }

    var body: some View {
        AlbumView(viewModel: viewModel, shareViewModel: ShareViewModel())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !viewModel.isSelectionMode {
                    Navbar(selection: selection) { selection = $0 }
                        .padding(.bottom, 28)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .environment(AuthenticationState.preview())
            .environment(Router())
    }
}
