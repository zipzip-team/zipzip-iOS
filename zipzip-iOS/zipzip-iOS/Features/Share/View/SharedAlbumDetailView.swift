//
//  SharedAlbumDetailView.swift
//  zipzip-iOS
//

import SwiftUI

struct SharedAlbumDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SharedAlbumDetailViewModel

    let album: SharedAlbum
    let destinationAlbums: [SharedAlbum]

    init(
        album: SharedAlbum,
        destinationAlbums: [SharedAlbum],
        viewModel: SharedAlbumDetailViewModel
    ) {
        self.album = album
        self.destinationAlbums = destinationAlbums.filter { $0.id != album.id }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack(alignment: .top) {
            Color.orange30
                .ignoresSafeArea()

            scrollContent
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .topLeading) {
            FloatingHeader(.leading) {
                leadingActionButton
            }
        }
        .overlay(alignment: .topLeading) {
            FloatingHeader(.trailing) {
                AlbumHeaderActionButton(
                    onSelectionTap: viewModel.enterSelectionMode,
                    onAddTap: viewModel.presentPhotoPicker
                )
                .disabled(viewModel.isBusy)
                .opacity(viewModel.isSelectionMode ? 0 : 1)
                .allowsHitTesting(!viewModel.isSelectionMode)
                .accessibilityHidden(viewModel.isSelectionMode)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isSelectionMode {
                ActionBar(items: selectionActionItems)
                    .padding(.bottom, 49)
            }
        }
        .navigationDestination(isPresented: $viewModel.isPhotoPickerPresented) {
            AlbumPhotoPickerView(
                viewModel: AlbumPhotoPickerViewModel(
                    onComplete: viewModel.addPhotos
                )
            )
        }
        .bottomSheet(
            isPresented: $viewModel.isAlbumManagementPresented,
            detents: [.height(549)],
            initialDetent: .height(549),
            showsDragIndicator: .visible,
            expandsToLargestDetentOnScroll: false,
            isInteractiveDismissDisabled: viewModel.isUpdatingAlbum,
            onDismiss: viewModel.completeAlbumManagementDismissal
        ) { _ in
            SharedAlbumManagementSheet(
                albumName: $viewModel.albumTitleDraft,
                isBusy: viewModel.isUpdatingAlbum,
                onClose: viewModel.dismissAlbumManagement,
                onDelete: viewModel.presentAlbumDeleteAlert,
                onComplete: {
                    Task { await viewModel.completeAlbumManagement() }
                }
            )
        }
        .bottomSheetAlert(
            isPresented: $viewModel.isAlbumDeleteAlertPresented,
            title: "이 공유집을 삭제하시겠어요?",
            message: "삭제한 공유집은 그룹의 모든 멤버에게서 사라져요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: viewModel.dismissAlbumDeleteAlert,
            onPrimaryTap: {
                Task { await viewModel.confirmAlbumDeletion() }
            }
        )
        .bottomSheet(
            isPresented: $viewModel.isCopySheetPresented,
            detents: [.full],
            isInteractiveDismissDisabled: viewModel.isPerformingPhotoMutation
        ) { _ in
            SharedAlbumCopyDestinationSheet(
                albums: destinationAlbums,
                selectedAlbumIDs: viewModel.selectedDestinationAlbumIDs,
                isBusy: viewModel.isPerformingPhotoMutation,
                onClose: viewModel.dismissCopySheet,
                onSelect: viewModel.toggleDestinationAlbum,
                onComplete: {
                    Task { await viewModel.copySelectedPhotos() }
                }
            )
        }
        .bottomSheet(
            isPresented: $viewModel.isDeleteSheetPresented,
            detents: [.height(324)],
            initialDetent: .height(324),
            showsDragIndicator: .hidden,
            expandsToLargestDetentOnScroll: false,
            isInteractiveDismissDisabled: viewModel.isPerformingPhotoMutation
        ) { _ in
            SharedAlbumPhotoDeleteSheet(
                canDeleteLocalCopies: viewModel.canDeleteSelectedLocalCopies,
                isBusy: viewModel.isPerformingPhotoMutation,
                onDeleteLocalCopies: {
                    Task { await viewModel.deleteSelectedLocalCopies() }
                },
                onDetach: {
                    Task { await viewModel.detachSelectedPhotos() }
                }
            )
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task(id: album.id) {
            await viewModel.load()
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                SharedAlbumDetailTitleSection(
                    title: album.name,
                    createdAt: album.createdAt
                )

                if viewModel.hasPhotos {
                    galleryContent
                } else {
                    SharedAlbumDetailEmptyContent(onLoadPhotos: viewModel.presentPhotoPicker)
                        .frame(minHeight: 430)
                }
            }
            .padding(.top, 166)
            .padding(.bottom, viewModel.isSelectionMode ? 140 : 40)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(alignment: .top) {
                SharedAlbumDetailFolderBackground()
                    .ignoresSafeArea()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var galleryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("총")
                Text("\(viewModel.photos.count)장")
            }
            .font(.b2_md)
            .foregroundStyle(.grey800)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            SharedAlbumPhotoGallery(
                sections: viewModel.sections,
                isSelectionMode: viewModel.isSelectionMode,
                selectedPhotoIDs: viewModel.selectedPhotoIDs,
                onSelectPhoto: viewModel.togglePhotoSelection,
                onBeginSelection: viewModel.beginSelection,
                onNeedsURLRefresh: viewModel.refreshExpiredURLsIfNeeded
            )
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionActionItems: [ActionBarItem] {
        [
            .init(
                icon: .settingAlbum,
                title: "집 관리",
                isDisabled: viewModel.isBusy
            ) {
                viewModel.presentAlbumManagement(albumTitle: album.name)
            },
            .init(
                icon: .moveToAlbum,
                title: "저장",
                isDisabled: !viewModel.hasSelectedPhotos
            ) {
                Task { await viewModel.saveSelectedPhotos() }
            },
            .init(
                icon: .moveToShare,
                title: "집으로",
                isDisabled: !viewModel.hasSelectedPhotos || destinationAlbums.isEmpty || viewModel.isBusy,
                action: viewModel.presentCopySheet
            ),
            .init(
                icon: .delete,
                title: "삭제",
                isDisabled: !viewModel.hasSelectedPhotos || viewModel.isBusy,
                action: viewModel.presentDeleteSheet
            )
        ]
    }

    @ViewBuilder private var leadingActionButton: some View {
        if viewModel.isSelectionMode {
            RoundedTextButton(
                title: "취소",
                style: .cancel,
                action: viewModel.exitSelectionMode
            )
            .disabled(viewModel.isBusy)
        } else {
            RoundedIconButton(items: [
                .init(
                    id: "shared-album-back",
                    icon: .iconChevronLeft,
                    accessibilityLabel: "뒤로가기"
                ) {
                    dismiss()
                }
            ])
        }
    }
}

private struct SharedAlbumDetailTitleSection: View {
    let title: String
    let createdAt: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.t1_sb)
                .foregroundStyle(.grey1000)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(.calendar)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.grey400)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)

                Text(createdAt.formatted(.dateTime.year().month().day()))
                    .font(.b2_md)
                    .foregroundStyle(.grey400)
            }
        }
    }
}

private struct SharedAlbumDetailEmptyContent: View {
    let onLoadPhotos: () -> Void

    var body: some View {
        CenteredStateContent {
            Image(.albumDetailEmptyArtwork)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)
        } message: {
            Image(.albumEmptyDescription)
                .resizable()
                .scaledToFit()
                .frame(width: 246, height: 20)
                .accessibilityLabel("공유집에 사진을 넣어볼까요?")
        } action: {
            CommonButton(
                title: "사진 불러오기",
                property1: .default,
                property2: .pressed,
                action: onLoadPhotos
            )
            .frame(width: 171)
        }
    }
}

private struct SharedAlbumManagementSheet: View {
    @Binding var albumName: String
    let isBusy: Bool
    let onClose: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void

    var body: some View {
        BottomSheet(
            leftItem: {
                BottomSheetCloseButton(action: onClose)
                    .disabled(isBusy)
            },
            rightItem: {
                SharedAlbumSheetHeaderButton(
                    title: "삭제",
                    isDisabled: isBusy,
                    action: onDelete
                )
            },
            content: {
                VStack(spacing: 34) {
                    AlbumFolder(state: .plain) {
                        EmptyView()
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 49) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("공유집 이름")
                                .font(.t3_md)
                                .foregroundStyle(.grey300)
                            TextInput("이름 입력", text: $albumName)
                        }

                        CommonButton(
                            title: "완료",
                            property1: isCompletionDisabled ? .disabled : .cta,
                            action: onComplete
                        )
                    }
                    .frame(maxWidth: 358)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        )
    }

    private var isCompletionDisabled: Bool {
        isBusy || albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct SharedAlbumCopyDestinationSheet: View {
    let albums: [SharedAlbum]
    let selectedAlbumIDs: [SharedAlbum.ID]
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
                SharedAlbumSheetHeaderButton(
                    title: "완료",
                    isDisabled: selectedAlbumIDs.isEmpty || isBusy,
                    action: onComplete
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("사진을 복사할 공유집")
                        .font(.t3_sb)
                        .foregroundStyle(.white00)
                        .padding(.horizontal, 16)

                    if albums.isEmpty {
                        ContentUnavailableView(
                            "복사할 다른 공유집이 없어요",
                            systemImage: "photo.on.rectangle.angled"
                        )
                        .foregroundStyle(.grey300)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(albums) { album in
                                    Button {
                                        onSelect(album.id)
                                    } label: {
                                        AlbumCard(
                                            name: album.name,
                                            count: album.count,
                                            state: selectedAlbumIDs.contains(album.id) ? .highlighted : .plain,
                                            nameColorOverride: .white00
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
        )
    }
}

private struct SharedAlbumPhotoDeleteSheet: View {
    let canDeleteLocalCopies: Bool
    let isBusy: Bool
    let onDeleteLocalCopies: () -> Void
    let onDetach: () -> Void

    var body: some View {
        BottomSheet {
            VStack(spacing: 0) {
                Text("사진을 어디에서 삭제할까요?")
                    .font(.t2_sb)
                    .foregroundStyle(.white00)
                    .multilineTextAlignment(.center)
                    .padding(.top, 38)

                Text("공유집에서 제거해도 로컬 갤러리의 사진은 남아있어요.")
                    .font(.b2_md)
                    .foregroundStyle(.grey400)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                HStack(spacing: 16) {
                    CommonButton(
                        title: "삭제",
                        property1: canDeleteLocalCopies && !isBusy ? .secondary : .disabled,
                        action: onDeleteLocalCopies
                    )
                    CommonButton(
                        title: "공유집에서 제거",
                        property1: isBusy ? .disabled : .cta,
                        action: onDetach
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 44)
                .padding(.bottom, 31.5)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SharedAlbumSheetHeaderButton: View {
    let title: String
    let isDisabled: Bool
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

private struct SharedAlbumDetailFolderBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let topOffset: CGFloat = 68
            let width = proxy.size.width + 6
            let referenceHeight = width
                * SharedAlbumDetailFolderShape.referenceHeight
                / SharedAlbumDetailFolderShape.referenceWidth
            let height = max(referenceHeight, proxy.size.height - topOffset + 16)

            SharedAlbumDetailFolderShape()
                .fill(.grey50)
                .overlay {
                    SharedAlbumDetailFolderShape()
                        .stroke(.grey70, lineWidth: 4)
                }
                .frame(width: width, height: height)
                .offset(x: -3, y: topOffset)
        }
        .allowsHitTesting(false)
    }
}

private struct SharedAlbumDetailFolderShape: Shape {
    static let referenceWidth: CGFloat = 396
    static let referenceHeight: CGFloat = 797
    private static let referenceBottomLineY: CGFloat = 794.632
    private static let referenceSideBottomY: CGFloat = 784.632

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let scale = rect.width / Self.referenceWidth
            return CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        func xPosition(_ x: CGFloat) -> CGFloat {
            rect.minX + x * rect.width / Self.referenceWidth
        }

        let scale = rect.width / Self.referenceWidth
        let bottomLineY = rect.maxY - (Self.referenceHeight - Self.referenceBottomLineY) * scale
        let sideBottomY = bottomLineY
            - (Self.referenceBottomLineY - Self.referenceSideBottomY) * scale

        var path = Path()
        path.move(to: point(262.33, 2.54639))
        path.addCurve(
            to: point(271.422, 3.87744),
            control1: point(265.397, 1.48902),
            control2: point(268.787, 1.98521)
        )
        path.addLine(to: point(389.833, 88.9019))
        path.addCurve(
            to: point(394, 97.0239),
            control1: point(392.449, 90.7803),
            control2: point(394, 93.8035)
        )
        path.addLine(to: CGPoint(x: xPosition(394), y: sideBottomY))
        path.addCurve(
            to: CGPoint(x: xPosition(384), y: bottomLineY),
            control1: CGPoint(
                x: xPosition(394),
                y: sideBottomY + (790.155 - Self.referenceSideBottomY) * scale
            ),
            control2: CGPoint(x: xPosition(389.523), y: bottomLineY)
        )
        path.addLine(to: CGPoint(x: xPosition(12), y: bottomLineY))
        path.addCurve(
            to: CGPoint(x: xPosition(2), y: sideBottomY),
            control1: CGPoint(x: xPosition(6.47716), y: bottomLineY),
            control2: CGPoint(
                x: xPosition(2),
                y: sideBottomY + (790.155 - Self.referenceSideBottomY) * scale
            )
        )
        path.addLine(to: point(2, 99.4243))
        path.addCurve(
            to: point(8.74121, 89.9702),
            control1: point(2, 95.1577),
            control2: point(4.70753, 91.3608)
        )
        path.addLine(to: point(262.33, 2.54639))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
    #Preview("Shared Album Detail", traits: .fixedLayout(width: 390, height: 844)) {
        let groupID = UUID()
        let albumID = UUID()
        let photos = (0 ..< 12).map { index in
            SharedAlbumPhoto(
                id: UUID(),
                thumbnailStatus: .pending,
                displayAt: Calendar.current.date(byAdding: .day, value: -(index / 4), to: .now) ?? .now
            )
        }
        let repository = SharedAlbumDetailRepositoryAdapter(
            onCachedPhotos: { _ in photos },
            onSynchronizePhotos: { _ in photos },
            onRenameAlbum: { _, _, _ in true },
            onDeleteAlbum: { _, _ in true },
            onUploadPhotos: { identifiers, _ in .init(succeededCount: identifiers.count) },
            onSavePhotosToLibrary: { ids, _ in .init(succeededCount: ids.count) },
            onCopyPhotos: { ids, _, _ in .init(succeededCount: ids.count) },
            onDeleteLocalCopies: { ids in .init(succeededCount: ids.count) },
            onDetachPhotos: { ids, _ in .init(succeededCount: ids.count) }
        )

        NavigationStack {
            SharedAlbumDetailView(
                album: SharedAlbum(
                    id: albumID,
                    sharedGroupID: groupID,
                    name: "여름 휴가",
                    count: photos.count,
                    createdBy: nil,
                    isCreator: true,
                    createdAt: .now,
                    updatedAt: .now
                ),
                destinationAlbums: [],
                viewModel: SharedAlbumDetailViewModel(
                    groupID: groupID,
                    albumID: albumID,
                    repository: repository
                )
            )
        }
    }
#endif
