//
//  SharedPhotoDetailView.swift
//  zipzip-iOS
//

import SwiftUI

struct SharedPhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: SharedPhotoDetailViewModel
    @State private var showDeleteAlert = false
    @State private var photoScale: CGFloat = 1
    @State private var photoOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    private static let minimumPhotoScale: CGFloat = 1
    private static let maximumPhotoScale: CGFloat = 4
    private static let doubleTapPhotoScale: CGFloat = 2
    private static let zoomActivationThreshold: CGFloat = 1.01

    init(viewModel: SharedPhotoDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        GeometryReader { geometry in
            let currentScale = clampedPhotoScale(photoScale * gestureScale)
            let currentOffset = clampedPhotoOffset(
                adding: photoOffset,
                and: gestureOffset,
                in: geometry.size,
                scale: currentScale
            )

            SharedPhotoRemoteImage(
                url: viewModel.imageURL,
                isLoading: viewModel.isLoading
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(currentScale)
            .offset(currentOffset)
            .clipped()
            .contentShape(.rect)
            .gesture(photoGesture(in: geometry.size))
            .onTapGesture(count: 2) {
                togglePhotoZoom(in: geometry.size)
            }
            .accessibilityLabel("공유 사진")
            .accessibilityHint("두 번 탭하여 확대하거나 축소할 수 있습니다.")
            .accessibilityAction(named: isCommittedPhotoZoomed ? "축소" : "확대") {
                togglePhotoZoom(in: geometry.size)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background {
            Color.orange30
                .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            FloatingHeader(.leading) {
                backButton
                    .opacity(isPhotoZoomed ? 0 : 1)
                    .allowsHitTesting(!isPhotoZoomed)
                    .accessibilityHidden(isPhotoZoomed)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isPhotoZoomed)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.detail != nil {
                bottomContent
                    .opacity(isPhotoZoomed ? 0 : 1)
                    .allowsHitTesting(!isPhotoZoomed)
                    .accessibilityHidden(isPhotoZoomed)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isPhotoZoomed)
            }
        }
        .overlay {
            if viewModel.hasLoadFailed {
                SharedPhotoLoadFailedView {
                    Task { await viewModel.retry() }
                }
            }
        }
        .statusBarHidden(isCommittedPhotoZoomed)
        .task(id: viewModel.photoID) {
            await viewModel.load()
        }
        .onChange(of: viewModel.imageURL) {
            resetPhotoTransform()
        }
        .bottomSheet(
            isPresented: $viewModel.isCommentsPresented,
            detents: [.height(562)],
            initialDetent: .height(562),
            showsDragIndicator: .visible,
            expandsToLargestDetentOnScroll: false,
            isInteractiveDismissDisabled: viewModel.isSendingComment,
            onDismiss: viewModel.commentsDidDismiss
        ) {
            CommentsBottomSheet(
                messages: viewModel.comments,
                comment: $viewModel.commentDraft,
                isLoading: viewModel.isLoadingComments,
                isSending: viewModel.isSendingComment,
                onClose: viewModel.dismissComments,
                onSend: { Task { await viewModel.sendComment() } }
            )
            .task(id: viewModel.photoID) {
                await viewModel.loadComments()
            }
        }
        .bottomSheetAlert(
            isPresented: $showDeleteAlert,
            title: "이 사진을 삭제하시겠어요?",
            message: "이 공유집에서 사진이 제거되고,\n다른 공유집에 없다면 완전히 삭제돼요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: { showDeleteAlert = false },
            onPrimaryTap: confirmDelete
        )
        .alert("작업을 완료하지 못했어요", isPresented: $viewModel.isErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "shared-photo-back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") {
                dismiss()
            }
        ])
        .opacity(0.9)
    }

    private var bottomContent: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if let latestComment = viewModel.latestComment {
                SharedPhotoLatestCommentToast(comment: latestComment)
            }

            ActionBar(items: actionItems)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 49)
    }

    private var actionItems: [ActionBarItem] {
        [
            .init(
                icon: viewModel.isLikedByMe ? .heartFilled : .heartStroke,
                title: "\(viewModel.likeCount)",
                isDisabled: viewModel.isUpdatingLike || viewModel.isDeleting
            ) {
                Task { await viewModel.toggleLike() }
            },
            .init(
                icon: .chatFilled,
                title: "댓글",
                isDisabled: viewModel.isDeleting
            ) {
                viewModel.presentComments()
            },
            .init(
                icon: .delete,
                title: "삭제",
                isDisabled: viewModel.isDeleting
            ) {
                showDeleteAlert = true
            }
        ]
    }

    private var isPhotoZoomed: Bool {
        clampedPhotoScale(photoScale * gestureScale) > Self.zoomActivationThreshold
    }

    private var isCommittedPhotoZoomed: Bool {
        photoScale > Self.zoomActivationThreshold
    }

    private func confirmDelete() {
        showDeleteAlert = false
        Task { await viewModel.deletePhoto() }
    }

    private func photoGesture(in containerSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let proposedScale = clampedPhotoScale(photoScale * value.magnification)
                let scale = proposedScale > Self.zoomActivationThreshold
                    ? proposedScale
                    : Self.minimumPhotoScale
                photoScale = scale
                photoOffset = clampedPhotoOffset(
                    photoOffset,
                    in: containerSize,
                    scale: scale
                )
            }
            .simultaneously(with: photoDragGesture(in: containerSize))
    }

    private func photoDragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($gestureOffset) { value, state, _ in
                guard photoScale * gestureScale > Self.zoomActivationThreshold else { return }
                state = value.translation
            }
            .onEnded { value in
                guard photoScale * gestureScale > Self.zoomActivationThreshold else { return }
                photoOffset = clampedPhotoOffset(
                    adding: photoOffset,
                    and: value.translation,
                    in: containerSize,
                    scale: photoScale
                )
            }
    }

    private func togglePhotoZoom(in containerSize: CGSize) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0)) {
            if isCommittedPhotoZoomed {
                resetPhotoTransform()
            } else {
                photoScale = Self.doubleTapPhotoScale
                photoOffset = clampedPhotoOffset(
                    photoOffset,
                    in: containerSize,
                    scale: Self.doubleTapPhotoScale
                )
            }
        }
    }

    private func resetPhotoTransform() {
        photoScale = Self.minimumPhotoScale
        photoOffset = .zero
    }

    private func clampedPhotoScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, Self.minimumPhotoScale), Self.maximumPhotoScale)
    }

    private func clampedPhotoOffset(
        _ offset: CGSize,
        in containerSize: CGSize,
        scale: CGFloat
    ) -> CGSize {
        guard scale > Self.minimumPhotoScale else { return .zero }

        let scaledPhotoSize = aspectFitPhotoSize(in: containerSize, scale: scale)
        let maximumX = max((scaledPhotoSize.width - containerSize.width) / 2, 0)
        let maximumY = max((scaledPhotoSize.height - containerSize.height) / 2, 0)

        return CGSize(
            width: min(max(offset.width, -maximumX), maximumX),
            height: min(max(offset.height, -maximumY), maximumY)
        )
    }

    private func aspectFitPhotoSize(in containerSize: CGSize, scale: CGFloat) -> CGSize {
        let imageSize = viewModel.imageSize
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0
        else {
            return containerSize
        }

        let fitScale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        return CGSize(
            width: imageSize.width * fitScale * scale,
            height: imageSize.height * fitScale * scale
        )
    }

    private func clampedPhotoOffset(
        adding lhs: CGSize,
        and rhs: CGSize,
        in containerSize: CGSize,
        scale: CGFloat
    ) -> CGSize {
        clampedPhotoOffset(
            CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height),
            in: containerSize,
            scale: scale
        )
    }
}

private struct SharedPhotoRemoteImage: View {
    let url: URL?
    let isLoading: Bool

    var body: some View {
        Color.grey100
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFit()
                                .accessibilityHidden(true)
                        case .empty:
                            ProgressView()
                                .tint(.grey500)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.grey500)
                                .accessibilityHidden(true)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else if isLoading {
                    ProgressView()
                        .tint(.grey500)
                }
            }
    }
}

private struct SharedPhotoLatestCommentToast: View {
    let comment: SharedPhotoComment

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.grey100)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(comment.content)
                .font(.b1_md)
                .foregroundStyle(.grey1000)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white00, in: .capsule)
        .frame(maxWidth: 292, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(comment.author.displayName ?? "멤버"): \(comment.content)")
    }
}

private struct SharedPhotoLoadFailedView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("사진을 불러오지 못했어요")
                    .font(.t3_sb)
                    .foregroundStyle(.grey1000)

                Text("네트워크 연결을 확인해 주세요")
                    .font(.b2_md)
                    .foregroundStyle(.grey500)
            }
            .multilineTextAlignment(.center)

            Button("다시 시도", action: onRetry)
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.orange500, in: .capsule)
                .buttonStyle(.plain)
        }
        .padding(24)
    }
}

#if DEBUG
    #Preview("Shared Photo Detail", traits: .fixedLayout(width: 390, height: 844)) {
        let photoID = UUID()
        let albumID = UUID()
        let repository = SharedPhotoDetailRepositoryAdapter(
            onPhoto: { _ in
                SharedPhotoDetail(
                    id: photoID,
                    sharedGroupID: UUID(),
                    sharedAlbumIDs: [albumID],
                    originalURL: "https://example.com/photo.jpg",
                    originalURLExpiresAt: .now.addingTimeInterval(3600),
                    thumbnailURL: nil,
                    thumbnailURLExpiresAt: nil,
                    thumbnailStatus: "READY",
                    deviceModel: nil,
                    takenAt: nil,
                    displayAt: .now,
                    latitude: nil,
                    longitude: nil,
                    locationName: nil,
                    isInferred: false,
                    width: 3024,
                    height: 4032,
                    uploadedBy: SharedPhotoAuthor(id: nil, displayName: "집집이"),
                    isUploader: true,
                    likeCount: 4,
                    commentCount: 0,
                    isLikedByMe: false,
                    createdAt: .now,
                    updatedAt: .now
                )
            },
            onComments: { _, _, _ in .init(items: [], nextCursor: nil, hasNext: false) },
            onCreateComment: { photoID, content, _ in
                SharedPhotoComment(
                    id: UUID(),
                    photoID: photoID,
                    content: content,
                    author: SharedPhotoAuthor(id: nil, displayName: "집집이"),
                    isAuthor: true,
                    createdAt: .now,
                    updatedAt: .now
                )
            },
            onSetLike: { id, isLiked in .init(photoID: id, isLikedByMe: isLiked, likeCount: 4) },
            onDeletePhoto: { _, _ in true }
        )

        NavigationStack {
            SharedPhotoDetailView(
                viewModel: SharedPhotoDetailViewModel(
                    photoID: photoID,
                    albumID: albumID,
                    repository: repository
                )
            )
        }
    }
#endif
