//
//  ShareGroupDetailView.swift
//  zipzip-iOS
//

import SwiftUI

struct ShareGroupDetailView: View {
    let groupID: ShareAlbum.ID
    let viewModel: ShareViewModel

    @State private var isSelectionMode = false
    @State private var selectedAlbumIDs: [Album.ID] = []
    @State private var isDeleteAlertPresented = false
    @State private var isMoveSheetPresented = false

    private let columns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30
                .ignoresSafeArea()

            if let group = viewModel.group(withID: groupID) {
                ScrollView(showsIndicators: false) {
                    ShareGroupHero(group: group)

                    if group.albums.isEmpty {
                        ShareGroupEmptyContent {
                            viewModel.showImport(for: groupID)
                        }
                        .frame(minHeight: 500)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(group.albums) { album in
                                Button {
                                    handleAlbumTap(album)
                                } label: {
                                    AlbumCard(
                                        name: album.name,
                                        count: album.count,
                                        state: albumState(for: album)
                                    )
                                }
                                .buttonStyle(StaticButtonStyle())
                                .accessibilityLabel("\(album.name), \(album.count)장")
                                .accessibilityValue(accessibilityValue(for: album))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 33)
                        .padding(.bottom, isSelectionMode ? 140 : 32)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .overlay(alignment: .topLeading) {
            leadingButton
                .padding(.top, 14)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            if !isSelectionMode {
                RoundedIconButton(items: [
                    .init(id: "select-shared-albums", icon: .select, accessibilityLabel: "사진집 선택") {
                        enterSelectionMode()
                    },
                    .init(id: "import-shared-content", icon: .createStroke, accessibilityLabel: "사진 불러오기") {
                        viewModel.showImport(for: groupID)
                    },
                    .init(id: "open-comments", icon: .chatStroke, accessibilityLabel: "댓글") {
                        viewModel.isCommentsPresented = true
                    }
                ])
                .padding(.top, 14)
                .padding(.trailing, 16)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode {
                ActionBar(items: selectionActionItems)
                    .padding(.bottom, 49)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
        .bottomSheetAlert(
            isPresented: $isDeleteAlertPresented,
            title: "\(selectedAlbumIDs.count)개의 사진집을 삭제하시겠어요?",
            message: "삭제하기 전에 로컬 앨범에 저장하세요.\n로컬 앨범에 저장되지 않은 사진은 완전히 삭제돼요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: { isDeleteAlertPresented = false },
            onPrimaryTap: deleteSelectedAlbums
        )
        .bottomSheet(isPresented: $isMoveSheetPresented, detents: [.full]) { dismiss in
            ShareSheet(
                albums: Album.samples,
                sharedAlbums: Album.sharedSamples,
                shareAlbums: viewModel.groups,
                onDismiss: { dismiss() },
                onComplete: { _ in exitSelectionMode() }
            )
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var leadingButton: some View {
        if isSelectionMode {
            RoundedTextButton(title: "취소", style: .cancel, action: exitSelectionMode)
        } else {
            RoundedIconButton(items: [
                .init(id: "share-group-back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                    viewModel.goBack()
                }
            ])
        }
    }

    private var selectionActionItems: [ActionBarItem] {
        [
            .init(
                icon: .settingShare,
                title: "공유 관리",
                action: presentShareManagement
            ),
            .init(
                icon: .moveToAlbum,
                title: "사진집으로",
                isDisabled: selectedAlbumIDs.isEmpty,
                action: { isMoveSheetPresented = true }
            ),
            .init(
                icon: .delete,
                title: "삭제",
                isDisabled: selectedAlbumIDs.isEmpty,
                action: { isDeleteAlertPresented = true }
            )
        ]
    }

    private func handleAlbumTap(_ album: Album) {
        if isSelectionMode {
            if let index = selectedAlbumIDs.firstIndex(of: album.id) {
                selectedAlbumIDs.remove(at: index)
            } else {
                selectedAlbumIDs.append(album.id)
            }
        } else {
            viewModel.showAlbum(album, in: groupID)
        }
    }

    private func albumState(for album: Album) -> AlbumFolderState {
        guard isSelectionMode else {
            return .plain
        }
        if let index = selectedAlbumIDs.firstIndex(of: album.id) {
            return .selected(count: index + 1)
        }
        return .deselected
    }

    private func accessibilityValue(for album: Album) -> String {
        guard isSelectionMode else {
            return ""
        }
        return selectedAlbumIDs.contains(album.id) ? "선택됨" : "선택 안 됨"
    }

    private func enterSelectionMode() {
        isSelectionMode = true
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedAlbumIDs.removeAll()
    }

    private func presentShareManagement() {
        viewModel.presentShareManagement(groupID: groupID)
        exitSelectionMode()
    }

    private func deleteSelectedAlbums() {
        viewModel.removeAlbums(Set(selectedAlbumIDs), from: groupID)
        isDeleteAlertPresented = false
        exitSelectionMode()
    }
}

private struct ShareGroupHero: View {
    let group: ShareAlbum

    var body: some View {
        VStack(spacing: 5) {
            Spacer(minLength: 150)

            Text(group.name)
                .font(.t1_sb)
                .foregroundStyle(.grey1000)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(.calendar)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.grey500)
                    .frame(width: 16, height: 16)
                Text(dateText)
                    .font(.b2_md)
                    .foregroundStyle(.grey500)
            }

            HStack(spacing: -8) {
                ForEach(0 ..< min(group.memberCount, 4), id: \.self) { _ in
                    ProfileImage(size: 32)
                }
                if group.memberCount > 4 {
                    Text("+\(group.memberCount - 4)")
                        .font(.b3_md)
                        .foregroundStyle(.grey900)
                        .frame(width: 32, height: 32)
                        .background(.grey50, in: .circle)
                }
            }

            Spacer(minLength: 48)
        }
        .frame(height: 327)
        .frame(maxWidth: .infinity)
        .background(.grey50)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. M. d"
        return formatter.string(from: group.date)
    }
}

private struct ShareGroupEmptyContent: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Image(.shareGroupEmptyArtwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)
                Image(.shareGroupEmptyText)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 259, height: 54)
                    .accessibilityLabel("친구와 함께 집을 만들어 사진을 공유해보세요")
            }
            CommonButton(title: "집 만들기", action: onCreate)
                .frame(width: 171)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShareImportView: View {
    let groupID: ShareAlbum.ID
    let viewModel: ShareViewModel

    @State private var selection: ShareImportSelection = .albums
    @State private var selectedAlbumIDs: Set<Album.ID> = []
    @State private var selectedPhotoIDs: [UUID] = []

    private let columns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ShareImportHeader(
                    selection: $selection,
                    onCancel: viewModel.goBack,
                    onComplete: completeImport
                )

                switch selection {
                case .photos:
                    ScrollView(showsIndicators: false) {
                        PhotoGallery(
                            sections: PhotoSection.sample,
                            isSelectionMode: true,
                            selectedPhotoIDs: selectedPhotoIDs,
                            onTapPhoto: togglePhoto
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 32)
                    }
                case .albums:
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Album.samples) { album in
                                Button {
                                    toggleAlbum(album)
                                } label: {
                                    AlbumCard(
                                        name: album.name,
                                        count: album.count,
                                        state: selectedAlbumIDs.contains(album.id) ? .highlighted : .plain
                                    )
                                }
                                .buttonStyle(StaticButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 29)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func toggleAlbum(_ album: Album) {
        if selectedAlbumIDs.contains(album.id) {
            selectedAlbumIDs.remove(album.id)
        } else {
            selectedAlbumIDs.insert(album.id)
        }
    }

    private func togglePhoto(_ id: UUID) {
        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }

    private func completeImport() {
        switch selection {
        case .photos:
            guard !selectedPhotoIDs.isEmpty else {
                return
            }
            viewModel.addAlbums(
                [
                    Album(
                        id: nextAvailableAlbumID,
                        name: "새 사진집",
                        count: selectedPhotoIDs.count
                    )
                ],
                to: groupID
            )
        case .albums:
            let albums = Album.samples.filter { selectedAlbumIDs.contains($0.id) }
            guard !albums.isEmpty else {
                return
            }
            viewModel.addAlbums(albums, to: groupID)
        }
    }

    private var nextAvailableAlbumID: Album.ID {
        let existingIDs = viewModel.groups
            .flatMap(\.albums)
            .map(\.id)
        return (existingIDs.max() ?? 0) + 1
    }
}

private struct ShareImportHeader: View {
    @Binding var selection: ShareImportSelection
    let onCancel: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedTextButton(title: "취소", style: .cancel, action: onCancel)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                SelectableButton(
                    title: "사진",
                    isSelected: selection == .photos,
                    selectedColor: .orange500
                ) {
                    selection = .photos
                }

                SelectableButton(
                    title: "사진집",
                    isSelected: selection == .albums,
                    selectedColor: .orange500
                ) {
                    selection = .albums
                }
            }

            Spacer(minLength: 0)

            RoundedTextButton(title: "완료", style: .cancel, action: onComplete)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }
}

#Preview("Share Group Detail", traits: .fixedLayout(width: 390, height: 844)) {
    let viewModel = ShareViewModel()
    ShareGroupDetailView(groupID: ShareAlbum.samples[0].id, viewModel: viewModel)
        .environment(AuthenticationState())
}
