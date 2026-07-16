//
//  ShareGroupManagementSheet.swift
//  zipzip-iOS
//
//  Created by Codex on 7/12/26.
//

import SwiftUI
import UIKit

struct ShareGroupManagementSheet: View {
    let group: ShareAlbum
    let members: [ShareGroupMember]
    @Binding var groupName: String
    let inviteCode: String
    let isInviteCodeAvailable: Bool
    let isUpdating: Bool
    let isLeaving: Bool
    let onClose: () -> Void
    let onComplete: () -> Void
    let onLeave: () -> Void

    @State private var isLeaveConfirmationPresented = false

    var body: some View {
        BottomSheet(
            leftItem: { BottomSheetCloseButton(action: onClose) },
            rightItem: {
                Button("완료", action: onComplete)
                    .font(.b1_sb)
                    .foregroundStyle(isCompleteDisabled ? .grey700 : .white00)
                    .frame(width: 72, height: 48)
                    .disabled(isCompleteDisabled)
            }
        ) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        groupInformationSection
                        invitationSection
                        memberSection
                        leaveSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .onChange(of: isLeaveConfirmationPresented) { _, isPresented in
                    guard isPresented else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(leaveConfirmationID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var groupInformationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("공유 그룹 정보")

            VStack(alignment: .leading, spacing: 24) {
                ShareGroupNameField(text: $groupName)
                    .disabled(group.currentUserRole != .admin || isUpdating || isLeaving)
                groupMetadata
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.grey800)
                .frame(height: 1)
        }
    }

    private var groupMetadata: some View {
        HStack(alignment: .top, spacing: 38) {
            VStack(alignment: .leading, spacing: 4) {
                Text("생성자")
                Text("생성일")
                Text("사진 수")
            }
            .font(.b2_md)
            .foregroundStyle(.grey100)
            .frame(width: 46, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.createdBy?.displayName ?? "")
                Text(formattedCreationDate)
                Text("총 \(photoCount)장")
            }
            .font(.b2_sb)
            .foregroundStyle(.grey50)
        }
    }

    private var invitationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("참여자 초대")

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("#")
                        .font(.t2_md)
                        .foregroundStyle(.white00)
                        .frame(width: 12)
                    Text(inviteCode)
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
                    UIPasteboard.general.string = inviteCode
                }
                .disabled(!isInviteCodeAvailable)
            }
            .padding(12)
            .background(.grey900, in: .rect(cornerRadius: 12))
        }
        .padding(.vertical, 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.grey800)
                .frame(height: 1)
        }
    }

    private var leaveSection: some View {
        VStack(spacing: 24) {
            ShareGroupLeaveButton(isDisabled: isLeaveConfirmationPresented || isUpdating || isLeaving) {
                isLeaveConfirmationPresented = true
            }

            if isLeaveConfirmationPresented {
                ShareGroupLeaveConfirmation(
                    role: group.currentUserRole,
                    isBusy: isLeaving,
                    onStay: { isLeaveConfirmationPresented = false },
                    onLeave: onLeave
                )
                .id(leaveConfirmationID)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 20)
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionTitle("멤버")
            ShareGroupMemberGrid(members: members)
        }
        .padding(.vertical, 20)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.t3_md)
            .foregroundStyle(.grey300)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedCreationDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. M. d"
        return formatter.string(from: group.date)
    }

    private var photoCount: Int {
        group.photoCount
    }

    private var leaveConfirmationID: String {
        "share-group-leave-confirmation"
    }

    private var isCompleteDisabled: Bool {
        isUpdating || isLeaving
    }
}

private struct ShareGroupMemberGrid: View {
    let members: [ShareGroupMember]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(members) { member in
                ShareGroupMemberCard(member: member)
            }
        }
    }
}

private struct ShareGroupMemberCard: View {
    let member: ShareGroupMember

    var body: some View {
        HStack(spacing: 10) {
            ProfileImage(size: 32, isStroke: false)
                .accessibilityHidden(true)

            HStack(spacing: 4) {
                Text(member.displayName)
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if member.role == .admin {
                    Image(.crown)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.orange500)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
        .background(backgroundColor, in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        member.isMe ? .grey600 : .grey800
    }

    private var accessibilityLabel: String {
        var labels = [member.displayName]
        if member.isMe {
            labels.append("나")
        }
        if member.role == .admin {
            labels.append("방장")
        }
        return labels.joined(separator: ", ")
    }
}

private struct ShareGroupNameField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("공유 그룹 이름", text: $text)
                .font(.b1_md)
                .foregroundStyle(.grey1000)
                .tint(.orange500)
                .focused($isFocused)

            Button {
                isFocused = true
            } label: {
                Image(.edit)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.grey600)
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("공유 그룹 이름 수정")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(.grey100, in: .rect(cornerRadius: 8))
    }
}

private struct ShareGroupLeaveButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("나가기")
                .font(.t3_sb)
                .foregroundStyle(isDisabled ? Color.grey700 : Color.orange500)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(.grey900, in: .rect(cornerRadius: 12))
        .disabled(isDisabled)
    }
}

private struct ShareGroupLeaveConfirmation: View {
    let role: ShareGroupRole
    let isBusy: Bool
    let onStay: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.t2_sb)
                    .foregroundStyle(.white00)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.b2_md)
                    .foregroundStyle(.grey600)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                CommonButton(title: "머무르기", property1: .secondary, action: onStay)
                CommonButton(title: "나가기", property1: .cta, action: onLeave)
            }
            .disabled(isBusy)
        }
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch role {
        case .admin:
            "방을 삭제하고 나가시겠어요?"
        case .participant:
            "방을 나가시겠어요?"
        }
    }

    private var message: String {
        switch role {
        case .admin:
            "방장이 나가면 이 공유공간은 사라져요."
        case .participant:
            "방을 나가면 다시 사진을 볼 수 없어요."
        }
    }
}

#Preview("Share Group Management - Admin", traits: .fixedLayout(width: 390, height: 844)) {
    @Previewable @State var groupName = "집집집"

    ShareGroupManagementSheet(
        group: ShareAlbum(
            name: groupName,
            date: .now,
            memberCount: 1,
            photoCount: 0,
            createdBy: ShareGroupUser(id: nil, displayName: nil)
        ),
        members: [
            ShareGroupMember(
                id: UUID(),
                displayName: "류단아",
                role: .admin,
                isMe: true,
                joinedAt: .now
            ),
            ShareGroupMember(
                id: UUID(),
                displayName: "집집이",
                role: .participant,
                isMe: false,
                joinedAt: .now
            ),
            ShareGroupMember(
                id: UUID(),
                displayName: "사진왕",
                role: .participant,
                isMe: false,
                joinedAt: .now
            ),
            ShareGroupMember(
                id: UUID(),
                displayName: "여행자",
                role: .participant,
                isMe: false,
                joinedAt: .now
            )
        ],
        groupName: $groupName,
        inviteCode: "3d2dsd322d32d23",
        isInviteCodeAvailable: true,
        isUpdating: false,
        isLeaving: false,
        onClose: {},
        onComplete: {},
        onLeave: {}
    )
}
