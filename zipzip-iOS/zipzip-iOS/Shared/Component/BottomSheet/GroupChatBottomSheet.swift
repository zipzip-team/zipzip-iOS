//
//  GroupChatBottomSheet.swift
//  zipzip-iOS
//

import SwiftUI

struct GroupChatRowPresentation: Identifiable, Equatable {
    let message: ShareGroupChatItem
    let showsPhotoThumbnail: Bool
    let showsProfile: Bool
    let isContinuation: Bool

    var id: ShareGroupChatItem.ID {
        message.id
    }
}

enum GroupChatPresentation {
    static func rows(for messages: [ShareGroupChatItem]) -> [GroupChatRowPresentation] {
        messages.enumerated().map { index, message in
            let previous = index > messages.startIndex ? messages[index - 1] : nil
            let isContinuation = previous.map { hasSameAuthor($0, message) } ?? false

            return GroupChatRowPresentation(
                message: message,
                showsPhotoThumbnail: shouldShowPhotoThumbnail(for: message, after: previous),
                showsProfile: !isContinuation,
                isContinuation: isContinuation
            )
        }
    }

    private static func shouldShowPhotoThumbnail(
        for message: ShareGroupChatItem,
        after previous: ShareGroupChatItem?
    ) -> Bool {
        guard message.type == .photoComment, let photoID = message.photoID else {
            return false
        }
        return previous?.type != .photoComment || previous?.photoID != photoID
    }

    private static func hasSameAuthor(
        _ lhs: ShareGroupChatItem,
        _ rhs: ShareGroupChatItem
    ) -> Bool {
        guard lhs.isAuthor == rhs.isAuthor else { return false }
        if lhs.isAuthor {
            return true
        }
        guard let lhsAuthor = lhs.author, let rhsAuthor = rhs.author else {
            return false
        }
        return lhsAuthor == rhsAuthor
    }
}

struct GroupChatBottomSheet: View {
    let messages: [ShareGroupChatItem]
    let photoURLs: [UUID: URL]
    @Binding var messageDraft: String
    let isLoading: Bool
    let isSending: Bool
    let onClose: () -> Void
    let onLoadOlder: () -> Void
    let onSend: () -> Void

    private let bottomAnchorID = "group-chat-bottom"

    var body: some View {
        BottomSheet(
            title: "채팅",
            leftItem: { BottomSheetCloseButton(action: onClose) },
            rightItem: {
                Button("완료", action: onClose)
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .frame(width: 72, height: 48)
            }
        ) {
            VStack(spacing: 12) {
                timelineContent

                HStack(spacing: 12) {
                    TextInput("메시지 입력", text: $messageDraft, style: .comment)
                        .disabled(isLoading || isSending)
                    ExtraSmallButton(icon: .send, action: onSend)
                        .disabled(isSendDisabled)
                        .accessibilityLabel("메시지 보내기")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder private var timelineContent: some View {
        if messages.isEmpty {
            if isLoading {
                ProgressView()
                    .tint(.grey100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("채팅 불러오는 중")
            } else {
                GroupChatEmptyState()
            }
        } else {
            timeline
        }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(GroupChatPresentation.rows(for: messages)) { row in
                        GroupChatMessageRow(
                            row: row,
                            photoURL: row.message.photoID.flatMap { photoURLs[$0] }
                        )
                        .padding(.top, row.isContinuation ? 8 : 16)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, 16)
            }
            .defaultScrollAnchor(.bottom)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y <= geometry.contentInsets.top + 8
            } action: { wasAtTop, isAtTop in
                guard isAtTop, !wasAtTop else { return }
                onLoadOlder()
            }
            .onChange(of: messages.last?.id) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("채팅 목록")
        }
    }

    private var isSendDisabled: Bool {
        isLoading || isSending || messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct GroupChatEmptyState: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(.shareChatEmptyIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 80)
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)

            Image(.shareChatEmptyText)
                .resizable()
                .scaledToFit()
                .frame(width: 199, height: 54)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("아직 메시지가 없어요. 첫 대화를 시작해보세요.")
    }
}

private struct GroupChatMessageRow: View {
    let row: GroupChatRowPresentation
    let photoURL: URL?

    private var message: ShareGroupChatItem {
        row.message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isAuthor {
                Spacer(minLength: 44)
            } else {
                profile
            }

            VStack(alignment: message.isAuthor ? .trailing : .leading, spacing: 8) {
                if row.showsPhotoThumbnail {
                    GroupChatPhotoThumbnail(url: photoURL)
                }

                Text(message.content)
                    .font(.t3_md)
                    .foregroundStyle(.white00)
                    .multilineTextAlignment(message.isAuthor ? .trailing : .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.isAuthor ? .grey600 : .grey800,
                        in: .rect(cornerRadius: 8)
                    )
            }

            if message.isAuthor {
                profile
            } else {
                Spacer(minLength: 44)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var profile: some View {
        if row.showsProfile {
            ProfileImage(size: 32, isStroke: false)
                .accessibilityHidden(true)
        } else {
            Color.clear
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityLabel: String {
        let prefix = message.isAuthor ? "내 메시지" : "메시지"
        return row.showsPhotoThumbnail
            ? "\(prefix), 사진 댓글: \(message.content)"
            : "\(prefix): \(message.content)"
    }
}

private struct GroupChatPhotoThumbnail: View {
    let url: URL?

    var body: some View {
        Color.grey500
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                                .accessibilityHidden(true)
                        case .empty:
                            ProgressView()
                                .tint(.grey100)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.grey100)
                                .accessibilityHidden(true)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}
