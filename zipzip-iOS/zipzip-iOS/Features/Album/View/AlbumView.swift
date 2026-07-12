//
//  AlbumView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI

struct AlbumView: View {
    @State private var viewModel: AlbumViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    init(viewModel: AlbumViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
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
                                viewModel.deletePhotos([photo.id], from: albumID, action: action)
                            }
                        )
                    case let .photoInfoEdit(metadata):
                        PhotoInfoEditView(metadata: metadata)
                    }
                }
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
                                onOpenTap: { viewModel.showDetail(for: album) }
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
                    onDeleteTap: viewModel.resetCreateAlbumDraft,
                    onCreateTap: viewModel.createAlbum
                )
            }
        }
        .bottomSheet(isPresented: $viewModel.isShareAlbumSheetPresented, detents: [.full]) { _ in
            AlbumShareDestinationSheet(
                shareAlbums: ShareAlbum.samples,
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

    @ViewBuilder private func albumDetailDestination(for albumID: AlbumViewItem.ID) -> some View {
        if let album = viewModel.album(for: albumID) {
            let detailViewModel = viewModel.makeDetailViewModel(for: albumID)

            if !album.hasPhotos {
                AlbumDetailEmptyView(
                    album: album.detailItem,
                    viewModel: detailViewModel,
                    moveAlbums: viewModel.moveDestinations(excluding: albumID),
                    photoPickerSections: viewModel.availablePhotoSections(excluding: album.photoIDs)
                )
            } else {
                AlbumDetailView(
                    album: album.detailItem,
                    viewModel: detailViewModel,
                    moveAlbums: viewModel.moveDestinations(excluding: albumID),
                    photoPickerSections: viewModel.availablePhotoSections(excluding: album.photoIDs)
                ) { detailViewModel in
                    AlbumDetailGalleryPlaceholderView(
                        sections: viewModel.photoSections(for: album),
                        photoCount: album.count,
                        showsSelectionControls: detailViewModel.isSelectionMode,
                        selectedPhotoIDs: detailViewModel.selectedPhotoIDs,
                        onSelectPhoto: detailViewModel.togglePhotoSelection,
                        onOpenPhoto: { viewModel.showPhotoDetail($0, in: albumID) }
                    )
                }
            }
        }
    }
}

private struct AlbumCollectionEmptyView: View {
    let onStartTap: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 10) {
                illustration

                Text("집을 만들어 사진을 보관해보세요!")
                    .font(.t2_md)
                    .foregroundStyle(.grey1000)
                    .multilineTextAlignment(.center)
            }

            CommonButton(title: "시작하기", action: onStartTap)
                .frame(width: 171)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var illustration: some View {
        ZStack {
            Image(.albumFolder)
                .resizable()
                .scaledToFit()
                .frame(width: 62, height: 56)
                .offset(x: -12, y: 12)

            Image(systemName: "hammer.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.orange500)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-12))
                .offset(x: 19, y: -12)
        }
        .frame(width: 96, height: 86)
        .accessibilityHidden(true)
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
                        isDisabled: selectedShareAlbumID == nil,
                        action: completeSelection
                    )
                }
            }
        ) {
            if !authenticationState.isLoggedIn {
                ShareLoginPrompt {
                    authenticationState.logIn()
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
    AlbumViewPreview()
}

private struct AlbumViewPreview: View {
    @State private var selection: NavbarTab = .album
    @State private var viewModel = AlbumViewModel()

    var body: some View {
        AlbumView(viewModel: viewModel)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !viewModel.isSelectionMode {
                    Navbar(selection: $selection)
                        .padding(.bottom, 28)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .environment(AuthenticationState())
    }
}
