//
//  ShareView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/5/26.
//

import SwiftUI
import UIKit

struct ShareView: View {
    @Environment(AuthenticationState.self) private var authenticationState
    @Environment(Router.self) private var router
    let viewModel: ShareViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        rootContent
            .toolbarVisibility(.hidden, for: .navigationBar)
            .bottomSheet(
                isPresented: Binding(
                    get: { viewModel.presentedSheet != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.dismissPresentedSheet()
                        }
                    }
                ),
                detents: sheetDetents,
                initialDetent: sheetDetents.first,
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false,
                isInteractiveDismissDisabled: viewModel.isPresentedSheetBusy,
                onDismiss: viewModel.shareSheetDidDismiss
            ) { _ in
                presentedSheetContent
            }
            .onChange(of: viewModel.completedJoinNavigationGroupID) { _, groupID in
                guard let groupID else { return }
                router.push(.shareGroup(groupID))
                viewModel.consumeCompletedJoinNavigation()
            }
    }

    private var sheetDetents: [BottomSheetSize] {
        switch viewModel.displayedSheet {
        case .joinConfirmation:
            [.height(477)]
        case .comments:
            [.height(562)]
        case .management:
            [.full]
        default:
            [.height(552)]
        }
    }

    @ViewBuilder private var presentedSheetContent: some View {
        @Bindable var viewModel = viewModel
        switch viewModel.displayedSheet {
        case .joinEntry:
            ShareEntryFormSheet(
                title: "공유 그룹 입장하기",
                placeholder: "코드 입력",
                value: $viewModel.joinCode,
                isConfirming: viewModel.isPreviewingJoin,
                onCancel: viewModel.dismissPresentedSheet,
                onConfirm: { Task { await viewModel.confirmJoinCode() } }
            )
        case .createGroup:
            ShareEntryFormSheet(
                title: "공유 그룹 생성하기",
                placeholder: "공유 그룹 이름",
                value: $viewModel.groupNameDraft,
                isConfirming: viewModel.isCreatingGroup,
                onCancel: viewModel.dismissPresentedSheet,
                onConfirm: { Task { await viewModel.createGroup() } }
            )
        case .joinConfirmation:
            ShareJoinConfirmationSheet(
                preview: viewModel.pendingJoinPreview,
                isConfirming: viewModel.isJoiningGroup,
                onCancel: viewModel.cancelJoinConfirmation,
                onConfirm: {
                    Task {
                        _ = await viewModel.completeJoin()
                    }
                }
            )
        case .invitation:
            ShareInvitationSheet(code: viewModel.inviteCode, onComplete: viewModel.completeInvitation)
        case .comments:
            ShareCommentsSheet(
                messages: viewModel.chatItems,
                comment: $viewModel.commentDraft,
                isLoading: viewModel.isLoadingChat || viewModel.isLoadingOlderChat,
                isSending: viewModel.isSendingChatMessage,
                onClose: viewModel.dismissComments,
                onLoadOlder: { Task { await viewModel.loadOlderChat() } },
                onSend: { Task { await viewModel.sendChatMessage() } }
            )
            .task(id: viewModel.activeChatGroupID) {
                await viewModel.loadChatTimeline()
            }
        case .management:
            if let group = viewModel.managedShareGroup {
                ShareGroupManagementSheet(
                    group: group,
                    members: viewModel.members(for: group.id),
                    groupName: $viewModel.shareGroupNameDraft,
                    inviteCode: viewModel.inviteCode(for: group.id) ?? "",
                    isInviteCodeAvailable: viewModel.isInviteCodeAvailable(for: group.id),
                    isUpdating: viewModel.isUpdatingGroup,
                    isLeaving: viewModel.isLeavingGroup,
                    onClose: viewModel.dismissShareManagement,
                    onComplete: { Task { await viewModel.completeShareManagement() } },
                    onLeave: leaveManagedShareGroup
                )
                .task(id: group.id) {
                    async let inviteRequest: Void = viewModel.loadInviteCode(groupID: group.id)
                    async let memberRequest: Void = viewModel.loadMembers(groupID: group.id)
                    _ = await(inviteRequest, memberRequest)
                }
            }
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder private var rootContent: some View {
        if authenticationState.isLoggedIn {
            ShareGroupListView(
                viewModel: viewModel,
                onOpenGroup: { router.push(.shareGroup($0)) }
            )
        } else {
            ShareRootLoginView {
                authenticationState.requestLogin(.share)
            }
        }
    }

    private func leaveManagedShareGroup() {
        Task {
            guard await viewModel.leaveManagedShareGroup() else {
                return
            }
            router.popToRoot()
        }
    }
}

struct ShareAlbumDetailDestinationView: View {
    @Environment(Router.self) private var router
    let groupID: ShareAlbum.ID
    let albumID: SharedAlbum.ID
    let viewModel: ShareViewModel

    var body: some View {
        if let album = viewModel.album(groupID: groupID, albumID: albumID) {
            SharedAlbumDetailView(
                album: album,
                destinationAlbums: viewModel.group(withID: groupID)?.albums ?? [],
                viewModel: viewModel.makeSharedAlbumDetailViewModel(
                    groupID: groupID,
                    albumID: albumID,
                    onDelete: router.pop
                ),
                onOpenPhoto: { photoID in
                    router.push(.sharePhotoDetail(
                        groupID: groupID,
                        albumID: albumID,
                        photoID: photoID
                    ))
                }
            )
        } else {
            ContentUnavailableView("사진집을 찾을 수 없어요", systemImage: "photo.on.rectangle")
                .navigationBarBackButtonHidden(true)
                .toolbarVisibility(.hidden, for: .navigationBar)
                .overlay(alignment: .topLeading) {
                    FloatingHeader(.leading) {
                        RoundedIconButton(items: [
                            .init(id: "missing-share-album-back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                                router.pop()
                            }
                        ])
                    }
                }
        }
    }
}

private struct ShareGroupListView: View {
    @Environment(AuthenticationState.self) private var authenticationState
    let viewModel: ShareViewModel
    let onOpenGroup: (ShareAlbum.ID) -> Void

    private var showsEmptyState: Bool {
        viewModel.groups.isEmpty && viewModel.hasLoadedGroups && !viewModel.isAddMode
    }

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if !viewModel.isAddMode {
                        ScrollableHeaderTitle("공유")
                    }

                    if showsEmptyState {
                        ShareCollectionEmptyView(onCreate: viewModel.presentCreateSheet)
                            .containerRelativeFrame(.vertical) { length, _ in
                                max(length - FloatingHeaderLayout.scrollableTitleLayoutHeight, 0)
                            }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.groups) { group in
                                Button {
                                    onOpenGroup(group.id)
                                } label: {
                                    ShareAlbumCard(
                                        thumbnailURL: group.validRepresentativeImageURL(),
                                        title: group.name,
                                        date: group.date,
                                        profileImages: Array(repeating: nil, count: min(group.memberCount, 4)),
                                        memberCount: group.memberCount
                                    )
                                }
                                .buttonStyle(StaticButtonStyle())
                                .accessibilityLabel("\(group.name), \(group.memberCount)명")
                                .task {
                                    async let imageRequest: Void = viewModel.loadRepresentativeImage(groupID: group.id)
                                    async let paginationRequest: Void = viewModel.loadMoreGroupsIfNeeded(
                                        currentGroupID: group.id
                                    )
                                    _ = await(imageRequest, paginationRequest)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(
                            .top,
                            viewModel.isAddMode
                                ? FloatingHeaderLayout.roundedIconButtonTop + FloatingHeaderLayout.buttonHeight + 16
                                : FloatingHeaderLayout.scrollableTitleContentSpacing
                        )
                        .padding(.bottom, viewModel.isAddMode ? 130 : 24)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .refreshable {
                guard let userID = authenticationState.currentUser?.id else { return }
                await viewModel.loadGroups(for: userID, refresh: true)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.isAddMode {
                RoundedTextButton(title: "취소", style: .cancel, action: viewModel.exitAddMode)
                    .padding(.top, 14)
                    .padding(.leading, 16)
            }
        }
        .overlay(alignment: .topLeading) {
            FloatingHeader(.trailing) {
                if !viewModel.isAddMode {
                    RoundedIconButton(items: [
                        .init(id: "add-share-group", icon: .plus, accessibilityLabel: "공유 그룹 추가") {
                            viewModel.enterAddMode()
                        }
                    ])
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isAddMode {
                ActionBar(items: [
                    .init(icon: .enter, title: "입장하기", action: viewModel.presentJoinSheet),
                    .init(icon: .create, title: "생성하기", action: viewModel.presentCreateSheet)
                ])
                .padding(.bottom, 49)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAddMode)
    }
}

private struct ShareRootLoginView: View {
    let onLogin: () -> Void

    var body: some View {
        ShareRootStateContainer(title: "공유") {
            CenteredStateContent {
                Image(.shareLoginRequiredArtwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 80)
                    .accessibilityHidden(true)
            } message: {
                Image(.shareLoginRequiredText)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 146, height: 53)
                    .accessibilityLabel("공유는 로그인이 필요해요")
            } action: {
                CommonButton(title: "로그인", property1: .cta, action: onLogin)
                    .frame(width: 171)
            }
        }
    }
}

private struct ShareCollectionEmptyView: View {
    let onCreate: () -> Void

    var body: some View {
        CenteredStateContent {
            Image(.shareCollectionEmptyArtwork)
                .resizable()
                .scaledToFit()
                .frame(width: 79, height: 105)
                .accessibilityHidden(true)
        } message: {
            Image(.shareCollectionEmptyText)
                .resizable()
                .scaledToFit()
                .frame(width: 141, height: 54)
                .accessibilityLabel("공유 공간에서 추억을 기록하세요")
        } action: {
            CommonButton(title: "그룹 만들기", action: onCreate)
                .frame(width: 171)
        }
    }
}

private struct ShareRootStateContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ScrollableHeaderTitle(title)

                    content()
                        .containerRelativeFrame(.vertical) { length, _ in
                            max(length - FloatingHeaderLayout.scrollableTitleLayoutHeight, 0)
                        }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct ShareAssetPlaceholder: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.grey200)
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

private struct ShareEntryFormSheet: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    var isConfirming = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        BottomSheet {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.t3_md)
                    .foregroundStyle(.grey400)

                TextInput(placeholder, text: $value)
                    .disabled(isConfirming)

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    CommonButton(title: "취소", property1: .secondary, action: onCancel)
                    CommonButton(
                        title: "확인",
                        property1: isConfirmDisabled ? .disabled : .cta,
                        action: onConfirm
                    )
                }
                .disabled(isConfirming)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 49)
        }
    }

    private var isConfirmDisabled: Bool {
        isConfirming || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ShareJoinConfirmationSheet: View {
    let preview: ShareGroupJoinPreview?
    let isConfirming: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        BottomSheet {
            VStack(spacing: 16) {
                representativeImage

                VStack(spacing: 8) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(preview?.group.name ?? "공유 그룹")
                                .foregroundStyle(.orange500)
                            Text("에 들어갈까요?")
                                .foregroundStyle(.white00)
                        }
                        .font(.t2_sb)

                        Text("생성자: \(creatorName)")
                            .font(.b2_md)
                            .foregroundStyle(.grey200)
                    }

                    HStack(spacing: -8) {
                        ForEach(0 ..< visibleMemberCount, id: \.self) { _ in
                            ProfileImage(size: 24)
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    CommonButton(title: "취소", property1: .secondary, action: onCancel)
                    CommonButton(
                        title: "확인",
                        property1: isConfirming ? .disabled : .cta,
                        action: onConfirm
                    )
                }
                .disabled(isConfirming)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 49)
        }
    }

    @ViewBuilder private var representativeImage: some View {
        if let url = validRepresentativeImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(.rect(cornerRadius: 12))
                default:
                    representativeImagePlaceholder
                }
            }
        } else {
            representativeImagePlaceholder
        }
    }

    private var representativeImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.grey500)
            .frame(width: 160, height: 160)
            .accessibilityHidden(true)
    }

    private var validRepresentativeImageURL: URL? {
        guard let preview else { return nil }
        if let expiresAt = preview.representativeImageURLExpiresAt, expiresAt <= .now {
            return nil
        }
        return preview.representativeImageURL
    }

    private var creatorName: String {
        preview?.group.createdBy?.displayName ?? "-"
    }

    private var visibleMemberCount: Int {
        min(preview?.members.count ?? preview?.group.memberCount ?? 0, 4)
    }
}

private struct ShareInvitationSheet: View {
    let code: String
    let onComplete: () -> Void

    var body: some View {
        BottomSheet {
            VStack(alignment: .leading, spacing: 12) {
                Text("참여자 초대")
                    .font(.t3_md)
                    .foregroundStyle(.grey400)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("#")
                            .font(.t2_md)
                            .foregroundStyle(.white00)
                            .frame(width: 12)
                        Text(code)
                            .font(.t2_md)
                            .foregroundStyle(.white00)
                            .lineLimit(1)
                            .padding(.vertical, 4)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(.orange400)
                                    .frame(height: 1)
                            }
                    }
                    Spacer(minLength: 0)
                    RoundedTextButton(title: "복사", style: .large) {
                        UIPasteboard.general.string = code
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 64)
                .background(.grey900, in: .rect(cornerRadius: 12))

                Spacer(minLength: 0)

                CommonButton(title: "완료", property1: .cta, action: onComplete)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 49)
        }
    }
}

private struct ShareCommentsSheet: View {
    let messages: [ShareGroupChatItem]
    @Binding var comment: String
    let isLoading: Bool
    let isSending: Bool
    let onClose: () -> Void
    let onLoadOlder: () -> Void
    let onSend: () -> Void

    var body: some View {
        BottomSheet(
            leftItem: { BottomSheetCloseButton(action: onClose) },
            rightItem: {
                Button("완료", action: onClose)
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .frame(width: 72, height: 48)
            }
        ) {
            VStack(spacing: 12) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            ShareCommentBubble(text: message.content, isMine: message.isAuthor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .defaultScrollAnchor(.bottom)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y <= geometry.contentInsets.top + 8
                } action: { wasAtTop, isAtTop in
                    guard isAtTop, !wasAtTop else { return }
                    onLoadOlder()
                }

                HStack(spacing: 12) {
                    TextInput("메시지 입력", text: $comment, style: .comment)
                        .disabled(isLoading || isSending)
                    ExtraSmallButton(icon: .send, action: onSend)
                        .disabled(isSendDisabled)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var isSendDisabled: Bool {
        isLoading || isSending || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ShareCommentBubble: View {
    let text: String
    let isMine: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isMine {
                Spacer(minLength: 44)
            } else {
                ProfileImage(size: 32, isStroke: false)
            }

            Text(text)
                .font(.b1_md)
                .foregroundStyle(.white00)
                .padding(12)
                .background(isMine ? .grey700 : .grey900, in: .rect(cornerRadius: 8))

            if isMine {
                ProfileImage(size: 32, isStroke: false)
            } else {
                Spacer(minLength: 44)
            }
        }
    }
}

#if DEBUG
    #Preview("Share Login", traits: .fixedLayout(width: 390, height: 844)) {
        ShareViewPreview(isLoggedIn: false, groups: [])
    }

    #Preview("Share List", traits: .fixedLayout(width: 390, height: 844)) {
        ShareViewPreview(
            isLoggedIn: true,
            groups: [ShareAlbum(name: "집집팟", date: .now, memberCount: 4)]
        )
    }

    #Preview("Share Empty", traits: .fixedLayout(width: 390, height: 844)) {
        ShareViewPreview(isLoggedIn: true, groups: [])
    }

    private struct ShareViewPreview: View {
        @State private var authenticationState: AuthenticationState
        @State private var viewModel: ShareViewModel
        @State private var container = DIContainer()

        init(isLoggedIn: Bool, groups: [ShareAlbum]) {
            let authenticationState = AuthenticationState.preview(isLoggedIn: isLoggedIn)
            let container = DIContainer()
            _authenticationState = State(initialValue: authenticationState)
            _viewModel = State(
                initialValue: ShareViewModel(
                    groups: groups,
                    repository: container.shareGroupRepository
                )
            )
            _container = State(initialValue: container)
        }

        var body: some View {
            ShareView(viewModel: viewModel)
                .environment(authenticationState)
                .environment(container)
                .environment(Router())
        }
    }
#endif
