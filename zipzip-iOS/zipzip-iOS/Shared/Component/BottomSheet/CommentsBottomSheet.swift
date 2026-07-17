//
//  CommentsBottomSheet.swift
//  zipzip-iOS
//

import SwiftUI

protocol CommentSheetMessage: Identifiable {
    var content: String { get }
    var isAuthor: Bool { get }
    var authorDisplayName: String? { get }
}

struct CommentsBottomSheet<Message: CommentSheetMessage>: View {
    let messages: [Message]
    @Binding var comment: String
    let isLoading: Bool
    let isSending: Bool
    let onClose: () -> Void
    let onLoadOlder: (() -> Void)?
    let onSend: () -> Void

    private let bottomAnchorID = "comments-bottom"

    init(
        messages: [Message],
        comment: Binding<String>,
        isLoading: Bool,
        isSending: Bool,
        onClose: @escaping () -> Void,
        onLoadOlder: (() -> Void)? = nil,
        onSend: @escaping () -> Void
    ) {
        self.messages = messages
        _comment = comment
        self.isLoading = isLoading
        self.isSending = isSending
        self.onClose = onClose
        self.onLoadOlder = onLoadOlder
        self.onSend = onSend
    }

    var body: some View {
        BottomSheet(
            title: "댓글",
            leftItem: { BottomSheetCloseButton(action: onClose) },
            rightItem: {
                Button("완료", action: onClose)
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .frame(width: 72, height: 48)
            }
        ) {
            VStack(spacing: 12) {
                comments

                HStack(spacing: 12) {
                    TextInput("메시지 입력", text: $comment, style: .comment)
                        .disabled(isLoading || isSending)
                    ExtraSmallButton(icon: .send, action: onSend)
                        .disabled(isSendDisabled)
                        .accessibilityLabel("댓글 보내기")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var comments: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        CommentBubble(
                            text: message.content,
                            authorDisplayName: message.authorDisplayName,
                            isMine: message.isAuthor
                        )
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .defaultScrollAnchor(.bottom)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y <= geometry.contentInsets.top + 8
            } action: { wasAtTop, isAtTop in
                guard isAtTop, !wasAtTop else { return }
                onLoadOlder?()
            }
            .onChange(of: messages.last?.id) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("댓글 목록")
        }
    }

    private var isSendDisabled: Bool {
        isLoading || isSending || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct CommentBubble: View {
    let text: String
    let authorDisplayName: String?
    let isMine: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isMine {
                Spacer(minLength: 44)
            } else {
                ProfileImage(name: authorDisplayName, size: 32, isStroke: false)
                    .accessibilityHidden(true)
            }

            Text(text)
                .font(.t3_md)
                .foregroundStyle(.white00)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isMine ? .grey600 : .grey800, in: .rect(cornerRadius: 8))

            if isMine {
                ProfileImage(name: authorDisplayName, size: 32, isStroke: false)
                    .accessibilityHidden(true)
            } else {
                Spacer(minLength: 44)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isMine ? "내 댓글: \(text)" : "댓글: \(text)")
    }
}
