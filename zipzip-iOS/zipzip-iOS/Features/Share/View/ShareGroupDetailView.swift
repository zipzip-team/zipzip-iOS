//
//  ShareGroupDetailView.swift
//  zipzip-iOS
//

import SwiftUI

struct ShareGroupDetailView: View {
    @Environment(Router.self) private var router
    let groupID: ShareAlbum.ID
    let viewModel: ShareViewModel
    var onMoveAlbumsToPersonal: ([SharedAlbum]) async -> [Album.ID] = { _ in [] }
    var onMoveSucceeded: () -> Void = {}

    @State private var isSelectionMode = false
    @State private var selectedAlbumIDs: [SharedAlbum.ID] = []
    @State private var isDeleteAlertPresented = false
    @State private var isMoveAlertPresented = false
    @State private var isCopyingAlbumsToPersonal = false

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

                    if group.albums.isEmpty, viewModel.hasLoadedSharedAlbums(groupID: groupID) {
                        ShareGroupEmptyContent {
                            router.push(.shareImport(groupID))
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
                                        state: albumState(for: album),
                                        thumbnailRemoteURLs: album.validThumbnailURLs()
                                    )
                                }
                                .buttonStyle(StaticButtonStyle())
                                .accessibilityLabel("\(album.name), \(album.count)장")
                                .accessibilityValue(accessibilityValue(for: album))
                                .task {
                                    await viewModel.loadMoreSharedAlbumsIfNeeded(
                                        groupID: groupID,
                                        currentAlbumID: album.id
                                    )
                                }
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
            FloatingHeader(.leading) {
                leadingButton
            }
        }
        .overlay(alignment: .topLeading) {
            FloatingHeader(.trailing) {
                if !isSelectionMode {
                    RoundedIconButton(items: [
                        .init(id: "select-shared-albums", icon: .select, accessibilityLabel: "사진집 선택") {
                            enterSelectionMode()
                        },
                        .init(id: "create-shared-album", icon: .createStroke, accessibilityLabel: "공유집 생성") {
                            viewModel.presentCreateSharedAlbumSheet(groupID: groupID)
                        },
                        .init(id: "open-comments", icon: .chatStroke, accessibilityLabel: "댓글") {
                            viewModel.presentComments(groupID: groupID)
                        }
                    ])
                }
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
        .bottomSheetAlert(
            isPresented: $isMoveAlertPresented,
            title: "선택한 공유집을\n사진집으로 옮길까요?",
            message: "공유집에 있는 모든 사진이 기기에 저장돼요.",
            secondaryTitle: "취소",
            primaryTitle: "옮기기",
            onSecondaryTap: { isMoveAlertPresented = false },
            onPrimaryTap: moveSelectedAlbumsToPersonal
        )
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task(id: groupID) {
            async let groupRequest: Void = viewModel.loadGroup(id: groupID)
            async let albumRequest: Void = viewModel.loadSharedAlbums(groupID: groupID)
            async let memberRequest: Void = viewModel.loadMembers(groupID: groupID)
            _ = await(groupRequest, albumRequest, memberRequest)
        }
    }

    @ViewBuilder private var leadingButton: some View {
        if isSelectionMode {
            RoundedTextButton(title: "취소", style: .cancel, action: exitSelectionMode)
                .disabled(isCopyingAlbumsToPersonal)
        } else {
            RoundedIconButton(items: [
                .init(id: "share-group-back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                    router.pop()
                }
            ])
        }
    }

    private var selectionActionItems: [ActionBarItem] {
        [
            .init(
                icon: .settingShare,
                title: "공유 관리",
                isDisabled: isCopyingAlbumsToPersonal,
                action: presentShareManagement
            ),
            .init(
                icon: .moveToAlbum,
                title: "사진집으로",
                isDisabled: selectedAlbumIDs.isEmpty || isCopyingAlbumsToPersonal,
                action: { isMoveAlertPresented = true }
            ),
            .init(
                icon: .delete,
                title: "삭제",
                isDisabled: selectedAlbumIDs.isEmpty
                    || viewModel.isDeletingSharedAlbums
                    || isCopyingAlbumsToPersonal,
                action: { isDeleteAlertPresented = true }
            )
        ]
    }

    private func handleAlbumTap(_ album: SharedAlbum) {
        guard !isCopyingAlbumsToPersonal else { return }
        if isSelectionMode {
            if let index = selectedAlbumIDs.firstIndex(of: album.id) {
                selectedAlbumIDs.remove(at: index)
            } else {
                selectedAlbumIDs.append(album.id)
            }
        } else {
            router.push(.shareAlbum(groupID: groupID, albumID: album.id))
        }
    }

    private func albumState(for album: SharedAlbum) -> AlbumFolderState {
        guard isSelectionMode else {
            return .plain
        }
        if let index = selectedAlbumIDs.firstIndex(of: album.id) {
            return .selected(count: index + 1)
        }
        return .deselected
    }

    private func accessibilityValue(for album: SharedAlbum) -> String {
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
        isMoveAlertPresented = false
    }

    private func presentShareManagement() {
        viewModel.presentShareManagement(groupID: groupID)
        exitSelectionMode()
    }

    private func deleteSelectedAlbums() {
        isDeleteAlertPresented = false
        let albumIDs = Set(selectedAlbumIDs)
        Task {
            guard await viewModel.deleteSharedAlbums(albumIDs, from: groupID) else { return }
            exitSelectionMode()
        }
    }

    private func moveSelectedAlbumsToPersonal() {
        isMoveAlertPresented = false
        guard !isCopyingAlbumsToPersonal,
              let group = viewModel.group(withID: groupID)
        else {
            return
        }

        let albumsByID = Dictionary(uniqueKeysWithValues: group.albums.map { ($0.id, $0) })
        let sourceAlbums = selectedAlbumIDs.compactMap { albumsByID[$0] }
        guard !sourceAlbums.isEmpty else { return }

        isCopyingAlbumsToPersonal = true
        Task {
            defer { isCopyingAlbumsToPersonal = false }
            let createdAlbumIDs = await onMoveAlbumsToPersonal(sourceAlbums)
            guard !createdAlbumIDs.isEmpty else {
                return
            }

            exitSelectionMode()
            onMoveSucceeded()
        }
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
    @Environment(Router.self) private var router
    let groupID: ShareAlbum.ID
    let viewModel: ShareViewModel
    let albums: [Album]
    let photoSections: [PhotoSection]

    @State private var selection: ShareImportSelection = .albums
    @State private var selectedAlbumIDs: Set<Album.ID> = []
    @State private var selectedPhotoIDs: [UUID] = []
    @State private var selectedDestinationAlbumID: SharedAlbum.ID?
    @State private var isDestinationPresented = false
    @State private var isImporting = false

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
                    onCancel: router.pop,
                    isCompleteDisabled: isCompleteDisabled,
                    onComplete: completeImport
                )

                switch selection {
                case .photos:
                    ScrollView(showsIndicators: false) {
                        PhotoGallery(
                            sections: photoSections,
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
                            ForEach(albums) { album in
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
        .bottomSheet(
            isPresented: $isDestinationPresented,
            detents: [.full],
            isInteractiveDismissDisabled: isImporting
        ) { dismiss in
            ShareImportDestinationSheet(
                albums: sharedAlbums,
                selectedAlbumID: selectedDestinationAlbumID,
                isBusy: isImporting,
                onClose: {
                    selectedDestinationAlbumID = nil
                    dismiss()
                },
                onSelect: { selectedDestinationAlbumID = $0 },
                onComplete: completePhotoImport
            )
        }
        .task(id: groupID) {
            await viewModel.loadSharedAlbums(groupID: groupID)
        }
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
        guard !isCompleteDisabled else { return }
        switch selection {
        case .photos:
            selectedDestinationAlbumID = nil
            isDestinationPresented = true
        case .albums:
            let selectedAlbums = albums.filter { selectedAlbumIDs.contains($0.id) }
            isImporting = true
            Task {
                defer { isImporting = false }
                guard let outcome = await viewModel.importPersonalAlbums(
                    selectedAlbums,
                    into: groupID
                ) else { return }

                if outcome.completedAnyWork {
                    router.pop()
                }
            }
        }
    }

    private func completePhotoImport() {
        guard let selectedDestinationAlbumID, !isImporting else { return }
        let selectedIDs = Set(selectedPhotoIDs)
        let localIdentifiers = photoSections
            .flatMap(\.photos)
            .filter { selectedIDs.contains($0.id) }
            .map(\.localIdentifier)
            .filter { !$0.isEmpty }
        guard !localIdentifiers.isEmpty else { return }

        isImporting = true
        Task {
            defer { isImporting = false }
            guard let result = await viewModel.importPhotos(
                localIdentifiers: localIdentifiers,
                into: selectedDestinationAlbumID,
                groupID: groupID
            ) else { return }

            isDestinationPresented = false
            if result.succeededCount > 0 || result.failedCount == 0 {
                router.pop()
            }
        }
    }

    private var isCompleteDisabled: Bool {
        if isImporting { return true }
        return switch selection {
        case .photos:
            selectedPhotoIDs.isEmpty || sharedAlbums.isEmpty
        case .albums:
            selectedAlbumIDs.isEmpty
        }
    }

    private var sharedAlbums: [SharedAlbum] {
        viewModel.group(withID: groupID)?.albums ?? []
    }
}

private struct ShareImportHeader: View {
    @Binding var selection: ShareImportSelection
    let onCancel: () -> Void
    let isCompleteDisabled: Bool
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
                .disabled(isCompleteDisabled)
                .opacity(isCompleteDisabled ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }
}

private struct ShareImportDestinationSheet: View {
    let albums: [SharedAlbum]
    let selectedAlbumID: SharedAlbum.ID?
    let isBusy: Bool
    let onClose: () -> Void
    let onSelect: (SharedAlbum.ID) -> Void
    let onComplete: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 17),
        GridItem(.flexible(), spacing: 17)
    ]

    var body: some View {
        BottomSheet(
            leftItem: {
                BottomSheetCloseButton(action: onClose)
                    .disabled(isBusy)
            },
            rightItem: {
                Button("완료", action: onComplete)
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .frame(width: 72, height: 48)
                    .disabled(selectedAlbumID == nil || isBusy)
                    .opacity(selectedAlbumID == nil || isBusy ? 0.4 : 1)
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("사진을 넣을 공유집")
                    .font(.t3_sb)
                    .foregroundStyle(.white00)
                    .padding(.horizontal, 16)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(albums) { album in
                            Button {
                                onSelect(album.id)
                            } label: {
                                AlbumCard(
                                    name: album.name,
                                    count: album.count,
                                    state: selectedAlbumID == album.id ? .highlighted : .plain,
                                    nameColorOverride: .white00,
                                    thumbnailRemoteURLs: album.validThumbnailURLs()
                                )
                            }
                            .buttonStyle(StaticButtonStyle())
                            .disabled(isBusy)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
    }
}

#if DEBUG
    #Preview("Share Group Detail", traits: .fixedLayout(width: 390, height: 844)) {
        let group = ShareAlbum(name: "집집팟", date: .now, memberCount: 4)
        let container = DIContainer()
        let viewModel = ShareViewModel(
            groups: [group],
            repository: container.shareGroupRepository
        )
        ShareGroupDetailView(groupID: group.id, viewModel: viewModel)
            .environment(AuthenticationState.preview(isLoggedIn: true))
            .environment(container)
            .environment(Router())
    }
#endif
