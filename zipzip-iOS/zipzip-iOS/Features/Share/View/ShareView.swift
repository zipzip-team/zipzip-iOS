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
    @Environment(DIContainer.self) private var container
    @Environment(Router.self) private var router
    let viewModel: ShareViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        rootContent
            .toolbarVisibility(.hidden, for: .navigationBar)
            .bottomSheet(
                isPresented: $viewModel.isJoinSheetPresented,
                detents: [.height(552)],
                initialDetent: .height(552),
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                ShareEntryFormSheet(
                    title: "공유 그룹 입장하기",
                    placeholder: "코드 입력",
                    value: $viewModel.joinCode,
                    onCancel: { viewModel.isJoinSheetPresented = false },
                    onConfirm: viewModel.confirmJoinCode
                )
            }
            .bottomSheet(
                isPresented: $viewModel.isCreateSheetPresented,
                detents: [.height(552)],
                initialDetent: .height(552),
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                ShareEntryFormSheet(
                    title: "공유 그룹 생성하기",
                    placeholder: "공유 그룹 이름",
                    value: $viewModel.groupNameDraft,
                    isConfirming: viewModel.isCreatingGroup,
                    onCancel: { viewModel.isCreateSheetPresented = false },
                    onConfirm: {
                        Task {
                            await viewModel.createGroup(
                                using: DefaultShareGroupAPI(networkProvider: container.networkProvider)
                            )
                        }
                    }
                )
            }
            .bottomSheet(
                isPresented: $viewModel.isJoinConfirmationPresented,
                detents: [.height(477)],
                initialDetent: .height(477),
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                ShareJoinConfirmationSheet(
                    group: viewModel.pendingJoinGroup,
                    onCancel: viewModel.cancelJoinConfirmation,
                    onConfirm: viewModel.completeJoin
                )
            }
            .bottomSheet(
                isPresented: $viewModel.isInviteSheetPresented,
                detents: [.height(552)],
                initialDetent: .height(552),
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                ShareInvitationSheet(
                    code: viewModel.inviteCode,
                    onComplete: viewModel.completeInvitation
                )
            }
            .bottomSheet(
                isPresented: $viewModel.isCommentsPresented,
                detents: [.height(562)],
                initialDetent: .height(562),
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                ShareCommentsSheet(
                    comment: $viewModel.commentDraft,
                    onClose: { viewModel.isCommentsPresented = false }
                )
            }
            .bottomSheet(
                isPresented: $viewModel.isAlbumManagementPresented,
                detents: [.height(549)],
                initialDetent: .height(549),
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                ShareAlbumManagementSheet(
                    albumName: $viewModel.albumNameDraft,
                    onClose: viewModel.dismissAlbumManagement,
                    onDelete: viewModel.deleteManagedAlbum,
                    onComplete: viewModel.completeAlbumManagement
                )
            }
            .bottomSheet(
                isPresented: $viewModel.isShareManagementPresented,
                detents: [.full],
                initialDetent: .full,
                showsDragIndicator: .visible,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                if let group = viewModel.managedShareGroup {
                    ShareGroupManagementSheet(
                        group: group,
                        groupName: $viewModel.shareGroupNameDraft,
                        inviteCode: viewModel.inviteCode,
                        onClose: viewModel.dismissShareManagement,
                        onComplete: viewModel.completeShareManagement,
                        onLeave: leaveManagedShareGroup
                    )
                }
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
        guard viewModel.leaveManagedShareGroup() else {
            return
        }
        router.popToRoot()
    }
}

struct ShareAlbumDetailDestinationView: View {
    @Environment(Router.self) private var router
    let groupID: ShareAlbum.ID
    let albumID: Album.ID
    let viewModel: ShareViewModel

    var body: some View {
        if let group = viewModel.group(withID: groupID),
           let album = viewModel.album(groupID: groupID, albumID: albumID) {
            AlbumDetailView(
                album: .init(
                    id: album.id,
                    title: album.name,
                    createdAt: group.date,
                    photoCount: album.count
                ),
                viewModel: detailViewModel
            ) { detailViewModel in
                AlbumDetailGalleryPlaceholderView(
                    photoCount: album.count,
                    showsSelectionControls: detailViewModel.isSelectionMode,
                    selectedPhotoIDs: detailViewModel.selectedPhotoIDs,
                    onSelectPhoto: detailViewModel.togglePhotoSelection
                )
            }
        } else {
            ContentUnavailableView("사진집을 찾을 수 없어요", systemImage: "photo.on.rectangle")
                .navigationBarBackButtonHidden(true)
                .toolbarVisibility(.hidden, for: .navigationBar)
                .overlay(alignment: .topLeading) {
                    RoundedIconButton(items: [
                        .init(id: "missing-share-album-back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                            router.pop()
                        }
                    ])
                    .padding(.top, 14)
                    .padding(.leading, 16)
                }
        }
    }

    private var detailViewModel: AlbumDetailViewModel {
        AlbumDetailViewModel(
            actions: .init(
                onRename: { name in
                    viewModel.renameAlbum(groupID: groupID, albumID: albumID, to: name)
                },
                onDelete: {
                    viewModel.removeAlbums([albumID], from: groupID)
                    router.pop()
                }
            )
        )
    }
}

private struct ShareGroupListView: View {
    let viewModel: ShareViewModel
    let onOpenGroup: (ShareAlbum.ID) -> Void

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            if viewModel.groups.isEmpty, !viewModel.isAddMode {
                ShareCollectionEmptyView(onCreate: viewModel.presentCreateSheet)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.groups) { group in
                            Button {
                                onOpenGroup(group.id)
                            } label: {
                                ShareAlbumCard(
                                    thumbnail: nil,
                                    title: group.name,
                                    date: group.date,
                                    profileImages: Array(repeating: nil, count: min(group.memberCount, 4)),
                                    memberCount: group.memberCount
                                )
                            }
                            .buttonStyle(StaticButtonStyle())
                            .accessibilityLabel("\(group.name), \(group.memberCount)명")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 69)
                    .padding(.bottom, viewModel.isAddMode ? 130 : 24)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.isAddMode {
                RoundedTextButton(title: "취소", style: .cancel, action: viewModel.exitAddMode)
                    .padding(.top, 14)
                    .padding(.leading, 16)
            } else {
                Text("공유")
                    .font(.t1_sb)
                    .foregroundStyle(.grey900)
                    .frame(height: 44)
                    .padding(.top, 14)
                    .padding(.leading, 16)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !viewModel.isAddMode {
                RoundedIconButton(items: [
                    .init(id: "add-share-group", icon: .plus, accessibilityLabel: "공유 그룹 추가") {
                        viewModel.enterAddMode()
                    }
                ])
                .padding(.top, 14)
                .padding(.trailing, 16)
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
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(.shareLoginRequiredArtwork)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 80)
                        .accessibilityHidden(true)
                    Image(.shareLoginRequiredText)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 146, height: 53)
                        .accessibilityLabel("공유는 로그인이 필요해요")
                }

                CommonButton(title: "로그인", property1: .cta, action: onLogin)
                    .frame(width: 171)
            }
            .padding(.top, 252)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct ShareCollectionEmptyView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Image(.shareCollectionEmptyArtwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 79, height: 105)
                    .accessibilityHidden(true)
                Image(.shareCollectionEmptyText)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 141, height: 54)
                    .accessibilityLabel("공유 공간에서 추억을 기록하세요")
            }

            CommonButton(title: "그룹 만들기", action: onCreate)
                .frame(width: 171)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 16)
    }
}

private struct ShareRootStateContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()
            content()
        }
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.t1_sb)
                .foregroundStyle(.grey900)
                .padding(.top, 19)
                .padding(.leading, 16)
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
    let group: ShareAlbum?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        BottomSheet {
            VStack(spacing: 18) {
                ShareAssetPlaceholder(width: 160, height: 160)

                VStack(spacing: 4) {
                    Text("\(group?.name ?? "공유 그룹")에 들어갈까요?")
                        .font(.t3_sb)
                        .foregroundStyle(.white00)
                    Text("생성자: 김집집")
                        .font(.b3_md)
                        .foregroundStyle(.grey400)
                    HStack(spacing: -8) {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            ProfileImage(size: 24)
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    CommonButton(title: "취소", property1: .secondary, action: onCancel)
                    CommonButton(title: "확인", property1: .cta, action: onConfirm)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 49)
        }
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
                    Text(code)
                        .font(.b1_sb)
                        .foregroundStyle(.white00)
                        .lineLimit(1)
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
    @Binding var comment: String
    let onClose: () -> Void

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
                        ShareCommentBubble(text: "단어 대박이네", isMine: false)
                        ShareCommentBubble(text: "단어 대박이네", isMine: true)
                        ShareCommentBubble(text: "좋은 추억이다", isMine: false)
                        ShareCommentBubble(text: "사진 더 올려줘", isMine: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                HStack(spacing: 12) {
                    TextInput("메시지 입력", text: $comment, style: .comment)
                    ExtraSmallButton(icon: .send, action: { comment = "" })
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
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

private struct ShareAlbumManagementSheet: View {
    @Binding var albumName: String
    let onClose: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void

    @State private var isDeleteAlertPresented = false

    var body: some View {
        BottomSheet(
            leftItem: { BottomSheetCloseButton(action: onClose) },
            rightItem: {
                Button("삭제") {
                    isDeleteAlertPresented = true
                }
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
            }
        ) {
            VStack(spacing: 34) {
                AlbumFolder { EmptyView() }

                VStack(alignment: .leading, spacing: 12) {
                    Text("사진집 이름")
                        .font(.t3_md)
                        .foregroundStyle(.grey400)
                    TextInput("이름 입력", text: $albumName)
                    CommonButton(
                        title: "완료",
                        property1: albumName.isEmpty ? .disabled : .cta,
                        action: onComplete
                    )
                    .padding(.top, 37)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .bottomSheetAlert(
            isPresented: $isDeleteAlertPresented,
            title: "이 사진집을 삭제하시겠어요?",
            message: "로컬 사진집에 저장되지 않은 사진은 완전히 삭제돼요.",
            secondaryTitle: "취소",
            primaryTitle: "삭제",
            onSecondaryTap: { isDeleteAlertPresented = false },
            onPrimaryTap: onDelete
        )
    }
}

#if DEBUG
    #Preview("Share Login", traits: .fixedLayout(width: 390, height: 844)) {
        ShareViewPreview(isLoggedIn: false, groups: ShareAlbum.samples)
    }

    #Preview("Share List", traits: .fixedLayout(width: 390, height: 844)) {
        ShareViewPreview(isLoggedIn: true, groups: ShareAlbum.samples)
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
        _authenticationState = State(initialValue: authenticationState)
        _viewModel = State(initialValue: ShareViewModel(groups: groups))
    }
    
    var body: some View {
        ShareView(viewModel: viewModel)
            .environment(authenticationState)
            .environment(container)
            .environment(Router())
    }
}
#endif
