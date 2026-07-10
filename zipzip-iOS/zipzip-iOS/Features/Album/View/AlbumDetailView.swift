//
//  AlbumDetailView.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/8/26.
//

import SwiftUI

struct AlbumDetailItem: Hashable, Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let photoCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date,
        photoCount: Int
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.photoCount = photoCount
    }
}

struct AlbumDetailActions {
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onAddPhotos: ([UUID]) -> Void
    let onDeletePhotos: ([UUID], PhotoDeletionAction) -> Void
    let onMovePhotos: ([UUID], ShareDestination) -> Void

    init(
        onRename: @escaping (String) -> Void = { _ in },
        onDelete: @escaping () -> Void = {},
        onAddPhotos: @escaping ([UUID]) -> Void = { _ in },
        onDeletePhotos: @escaping ([UUID], PhotoDeletionAction) -> Void = { _, _ in },
        onMovePhotos: @escaping ([UUID], ShareDestination) -> Void = { _, _ in }
    ) {
        self.onRename = onRename
        self.onDelete = onDelete
        self.onAddPhotos = onAddPhotos
        self.onDeletePhotos = onDeletePhotos
        self.onMovePhotos = onMovePhotos
    }
}

struct AlbumDetailView<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSelectionMode: Bool
    @State private var isPhotoPickerPresented = false
    @State private var isAlbumManagementPresented = false
    @State private var isAlbumDeleteAlertPresented = false
    @State private var isMoveSheetPresented = false
    @State private var isDeleteAlertPresented = false
    @State private var selectedPhotoIDs: [UUID] = []
    @State private var albumTitleDraft = ""

    let album: AlbumDetailItem
    private let contentTopSpacing: CGFloat
    private let detailContent: (Bool, Binding<[UUID]>, @escaping () -> Void) -> Content
    private let actions: AlbumDetailActions
    private let moveAlbums: [Album]
    private let photoPickerSections: [PhotoSection]
    private let onEditPhotoInfo: (UUID) -> Void

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        moveAlbums: [Album] = Album.samples,
        photoPickerSections: [PhotoSection] = PhotoSection.sample,
        onEditPhotoInfo: @escaping (UUID) -> Void = { _ in },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        _isSelectionMode = State(initialValue: initialSelectionMode)
        self.detailContent = { _, _, _ in content() }
        self.actions = actions
        self.moveAlbums = moveAlbums
        self.photoPickerSections = photoPickerSections
        self.onEditPhotoInfo = onEditPhotoInfo
    }

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        moveAlbums: [Album] = Album.samples,
        photoPickerSections: [PhotoSection] = PhotoSection.sample,
        onEditPhotoInfo: @escaping (UUID) -> Void = { _ in },
        @ViewBuilder content: @escaping (Bool) -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        _isSelectionMode = State(initialValue: initialSelectionMode)
        self.detailContent = { isSelectionMode, _, _ in content(isSelectionMode) }
        self.actions = actions
        self.moveAlbums = moveAlbums
        self.photoPickerSections = photoPickerSections
        self.onEditPhotoInfo = onEditPhotoInfo
    }

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        moveAlbums: [Album] = Album.samples,
        photoPickerSections: [PhotoSection] = PhotoSection.sample,
        onEditPhotoInfo: @escaping (UUID) -> Void = { _ in },
        @ViewBuilder content: @escaping (Bool, Binding<[UUID]>) -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        _isSelectionMode = State(initialValue: initialSelectionMode)
        self.detailContent = { isSelectionMode, selectedPhotoIDs, _ in
            content(isSelectionMode, selectedPhotoIDs)
        }
        self.actions = actions
        self.moveAlbums = moveAlbums
        self.photoPickerSections = photoPickerSections
        self.onEditPhotoInfo = onEditPhotoInfo
    }

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        moveAlbums: [Album] = Album.samples,
        photoPickerSections: [PhotoSection] = PhotoSection.sample,
        onEditPhotoInfo: @escaping (UUID) -> Void = { _ in },
        @ViewBuilder content: @escaping (Bool, @escaping () -> Void) -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        _isSelectionMode = State(initialValue: initialSelectionMode)
        self.detailContent = { isSelectionMode, _, presentPhotoPicker in
            content(isSelectionMode, presentPhotoPicker)
        }
        self.actions = actions
        self.moveAlbums = moveAlbums
        self.photoPickerSections = photoPickerSections
        self.onEditPhotoInfo = onEditPhotoInfo
    }

    init(
        album: AlbumDetailItem,
        contentTopSpacing: CGFloat = 30,
        initialSelectionMode: Bool = false,
        actions: AlbumDetailActions = .init(),
        moveAlbums: [Album] = Album.samples,
        photoPickerSections: [PhotoSection] = PhotoSection.sample,
        onEditPhotoInfo: @escaping (UUID) -> Void = { _ in },
        @ViewBuilder content: @escaping (Bool, Binding<[UUID]>, @escaping () -> Void) -> Content
    ) {
        self.album = album
        self.contentTopSpacing = contentTopSpacing
        _isSelectionMode = State(initialValue: initialSelectionMode)
        self.detailContent = content
        self.actions = actions
        self.moveAlbums = moveAlbums
        self.photoPickerSections = photoPickerSections
        self.onEditPhotoInfo = onEditPhotoInfo
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30
                .ignoresSafeArea()

            scrollContent
        }
        .overlay(alignment: .topLeading) {
            leadingActionButton
                .padding(.top, 19)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            AlbumHeaderActionButton(
                onSelectionTap: enterSelectionMode,
                onAddTap: presentPhotoPicker
            )
            .padding(.top, 19)
            .padding(.trailing, 16)
            .opacity(isSelectionMode ? 0 : 1)
            .allowsHitTesting(!isSelectionMode)
            .accessibilityHidden(isSelectionMode)
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode {
                ActionBar(items: selectionActionItems)
                    .padding(.bottom, 49)
            }
        }
        .navigationDestination(isPresented: $isPhotoPickerPresented) {
            AlbumPhotoPickerView(
                viewModel: AlbumPhotoPickerViewModel(
                    sections: photoPickerSections,
                    onComplete: actions.onAddPhotos
                )
            )
        }
        .bottomSheet(
            isPresented: $isAlbumManagementPresented,
            detents: [.height(549)],
            initialDetent: .height(549),
            showsDragIndicator: .visible,
            expandsToLargestDetentOnScroll: false
        ) { _ in
            BottomSheet(
                leftItem: {
                    AlbumManagementSheetHeaderButton(title: "취소", action: dismissAlbumManagement)
                },
                rightItem: {
                    AlbumManagementSheetHeaderButton(title: "삭제", action: deleteAlbum)
                }
            ) {
                AlbumManagementSheetContent(
                    albumName: $albumTitleDraft,
                    onCompleteTap: completeAlbumManagement
                )
            }
            .bottomSheetAlert(
                isPresented: $isAlbumDeleteAlertPresented,
                title: "이 사진집을 삭제하시겠어요?",
                message: "사진집에 담긴 사진들은 삭제되지 않아요.",
                secondaryTitle: "취소",
                primaryTitle: "삭제",
                onSecondaryTap: dismissAlbumDeleteAlert,
                onPrimaryTap: confirmAlbumDeletion
            )
        }
        .bottomSheet(isPresented: $isMoveSheetPresented, detents: [.full]) { dismiss in
            ShareSheet(
                albums: moveAlbums,
                sharedAlbums: Album.sharedSamples,
                shareAlbums: ShareAlbum.samples,
                onDismiss: { dismiss() },
                onComplete: completePhotoMove
            )
        }
        .bottomSheetAlert(
            isPresented: $isDeleteAlertPresented,
            title: deleteAlertContent.title,
            message: deleteAlertContent.message,
            secondaryTitle: deleteAlertContent.secondaryTitle,
            primaryTitle: deleteAlertContent.primaryTitle,
            onSecondaryTap: deleteSelectedPhotosPermanently,
            onPrimaryTap: removeSelectedPhotosFromAlbum
        )
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: contentTopSpacing) {
                titleSection

                detailContent(isSelectionMode, $selectedPhotoIDs, presentPhotoPicker)
            }
            .padding(.top, 168)
            .padding(.bottom, isSelectionMode ? 140 : 40)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(alignment: .top) {
                AlbumDetailFolderBackground()
                    .ignoresSafeArea()
            }
        }
    }

    private var titleSection: some View {
        AlbumDetailTitleSection(title: albumTitle, createdAt: album.createdAt)
    }

    private var albumTitle: String {
        album.title
    }

    private var selectionActionItems: [ActionBarItem] {
        let hasSelectedPhotos = !selectedPhotoIDs.isEmpty

        return [
            .init(icon: .settingAlbum, title: "집 관리", action: manageAlbum),
            .init(icon: .move, title: "이동하기", isDisabled: !hasSelectedPhotos, action: moveSelectedPhotos),
            .init(icon: .metadata, title: "정보 수정", isDisabled: !hasSelectedPhotos, action: editSelectedPhotoInfo),
            .init(icon: .delete, title: "삭제", isDisabled: !hasSelectedPhotos, action: deleteSelectedPhotos)
        ]
    }

    private var deleteAlertContent: PhotoDeleteAlertContent {
        PhotoDeletionContext.album.alertContent
    }

    @ViewBuilder private var leadingActionButton: some View {
        if isSelectionMode {
            RoundedTextButton(title: "취소", style: .cancel, action: exitSelectionMode)
        } else {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                    dismiss()
                }
            ])
        }
    }

    private func enterSelectionMode() {
        guard album.photoCount > 0 else {
            return
        }

        isSelectionMode = true
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotoIDs.removeAll()
    }

    private func presentPhotoPicker() {
        isPhotoPickerPresented = true
    }

    private func manageAlbum() {
        exitSelectionMode()
        albumTitleDraft = albumTitle
        isAlbumManagementPresented = true
    }

    private func dismissAlbumManagement() {
        isAlbumManagementPresented = false
    }

    private func completeAlbumManagement() {
        let trimmedTitle = albumTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return
        }

        actions.onRename(trimmedTitle)
        isAlbumManagementPresented = false
    }

    private func deleteAlbum() {
        isAlbumDeleteAlertPresented = true
    }

    private func dismissAlbumDeleteAlert() {
        isAlbumDeleteAlertPresented = false
    }

    private func confirmAlbumDeletion() {
        isAlbumDeleteAlertPresented = false
        isAlbumManagementPresented = false
        actions.onDelete()
    }

    private func moveSelectedPhotos() {
        guard !selectedPhotoIDs.isEmpty else {
            return
        }

        isMoveSheetPresented = true
    }

    private func completePhotoMove(to destination: ShareDestination) {
        actions.onMovePhotos(selectedPhotoIDs, destination)
        isMoveSheetPresented = false
        exitSelectionMode()
    }

    private func editSelectedPhotoInfo() {
        guard let firstPhotoID = selectedPhotoIDs.first else {
            return
        }

        onEditPhotoInfo(firstPhotoID)
    }

    private func deleteSelectedPhotos() {
        guard !selectedPhotoIDs.isEmpty else {
            return
        }

        isDeleteAlertPresented = true
    }

    private func deleteSelectedPhotosPermanently() {
        completeSelectedPhotoDeletion(.deletePermanently)
    }

    private func removeSelectedPhotosFromAlbum() {
        completeSelectedPhotoDeletion(.removeFromAlbum)
    }

    private func completeSelectedPhotoDeletion(_ action: PhotoDeletionAction) {
        actions.onDeletePhotos(selectedPhotoIDs, action)
        isDeleteAlertPresented = false
        exitSelectionMode()
    }
}

struct AlbumDetailEmptyView: View {
    let album: AlbumDetailItem
    var actions = AlbumDetailActions()
    var moveAlbums = Album.samples
    var photoPickerSections = PhotoSection.sample

    var body: some View {
        AlbumDetailView(
            album: album,
            contentTopSpacing: 125,
            actions: actions,
            moveAlbums: moveAlbums,
            photoPickerSections: photoPickerSections
        ) { _, presentPhotoPicker in
            AlbumDetailEmptyContent(onLoadPhotos: presentPhotoPicker)
        }
    }
}

private struct AlbumDetailTitleSection: View {
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

                Text(dateText)
                    .font(.b2_md)
                    .foregroundStyle(.grey400)
            }
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. M. d"
        return formatter.string(from: createdAt)
    }
}

private struct AlbumManagementSheetHeaderButton: View {
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

private struct AlbumManagementSheetContent: View {
    @Binding var albumName: String

    let onCompleteTap: () -> Void

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

                CommonButton(
                    title: "완료",
                    property1: isCompletionDisabled ? .disabled : .cta,
                    action: onCompleteTap
                )
            }
            .frame(maxWidth: 358)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var isCompletionDisabled: Bool {
        albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AlbumDetailEmptyContent: View {
    let onLoadPhotos: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Rectangle()
                    .fill(.grey100)
                    .frame(width: 80, height: 80)

                Image(.albumEmptyDescription)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 246, height: 20)
                    .accessibilityLabel("사진집에 사진을 넣어볼까요?")
            }

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

struct AlbumDetailGalleryPlaceholderView: View {
    @Binding private var selectedPhotoIDs: [UUID]

    let photoCount: Int
    var showsSelectionControls = false

    private let sections: [PhotoSection]
    private let onOpenPhoto: ((Photo) -> Void)?

    init(
        sections: [PhotoSection] = PhotoSection.sample,
        photoCount: Int,
        showsSelectionControls: Bool = false,
        selectedPhotoIDs: Binding<[UUID]> = .constant([]),
        onOpenPhoto: ((Photo) -> Void)? = nil
    ) {
        self.sections = sections
        self.photoCount = photoCount
        self.showsSelectionControls = showsSelectionControls
        _selectedPhotoIDs = selectedPhotoIDs
        self.onOpenPhoto = onOpenPhoto
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            totalCount

            PhotoGallery(
                sections: sections,
                isSelectionMode: showsSelectionControls,
                selectedPhotoIDs: selectedPhotoIDs,
                onTapPhoto: toggleSelection,
                onOpenPhoto: onOpenPhoto
            )
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: showsSelectionControls) { _, newValue in
            if !newValue {
                selectedPhotoIDs.removeAll()
            }
        }
    }

    private var totalCount: some View {
        HStack(spacing: 6) {
            Text("총")
            Text("\(photoCount)장")
        }
        .font(.b2_md)
        .foregroundStyle(.grey800)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleSelection(_ id: UUID) {
        guard showsSelectionControls else {
            return
        }

        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }
}

private struct AlbumDetailFolderBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let topOffset: CGFloat = 68
            let width = proxy.size.width + 6
            let referenceHeight = width * AlbumDetailFolderShape.referenceHeight / AlbumDetailFolderShape.referenceWidth
            let height = max(referenceHeight, proxy.size.height - topOffset + 16)

            AlbumDetailFolderShape()
                .fill(.grey50)
                .overlay {
                    AlbumDetailFolderShape()
                        .stroke(.grey70, lineWidth: 4)
                }
                .frame(width: width, height: height)
                .offset(x: -3, y: topOffset)
        }
        .allowsHitTesting(false)
    }
}

private struct AlbumDetailFolderShape: Shape {
    static let referenceWidth: CGFloat = 396
    static let referenceHeight: CGFloat = 797
    private static let referenceBottomLineY: CGFloat = 794.632
    private static let referenceSideBottomY: CGFloat = 784.632

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let scale = rect.width / Self.referenceWidth
            return CGPoint(
                x: rect.minX + x * scale,
                y: rect.minY + y * scale
            )
        }

        func xPosition(_ x: CGFloat) -> CGFloat {
            let scale = rect.width / Self.referenceWidth
            return rect.minX + x * scale
        }

        let scale = rect.width / Self.referenceWidth
        let bottomLineY = rect.maxY - (Self.referenceHeight - Self.referenceBottomLineY) * scale
        let sideBottomY = bottomLineY - (Self.referenceBottomLineY - Self.referenceSideBottomY) * scale

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

#Preview("Album Detail Empty", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailEmptyView(
        album: .init(
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 0
        )
    )
}

#Preview("Album Detail Gallery", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailView(
        album: .init(
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 123
        )
    ) {
        AlbumDetailGalleryPlaceholderView(photoCount: 123)
    }
}

#Preview("Album Detail Selection", traits: .fixedLayout(width: 390, height: 844)) {
    AlbumDetailView(
        album: .init(
            title: "집집 🏠",
            createdAt: .now,
            photoCount: 123
        ),
        initialSelectionMode: true
    ) { isSelectionMode, selectedPhotoIDs in
        AlbumDetailGalleryPlaceholderView(
            photoCount: 123,
            showsSelectionControls: isSelectionMode,
            selectedPhotoIDs: selectedPhotoIDs
        )
    }
}
