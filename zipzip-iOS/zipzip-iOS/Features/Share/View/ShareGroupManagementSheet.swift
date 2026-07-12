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
    @Binding var groupName: String
    let inviteCode: String
    let onClose: () -> Void
    let onComplete: () -> Void
    let onLeave: () -> Void

    @State private var isLeaveConfirmationPresented = false

    private let memberColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        BottomSheet(
            leftItem: { BottomSheetCloseButton(action: onClose) },
            rightItem: {
                Button("완료", action: onComplete)
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .frame(width: 72, height: 48)
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
                Text("류단아")
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
                Text(inviteCode)
                    .font(.t2_md)
                    .foregroundStyle(.white00)
                    .lineLimit(1)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(.orange400)
                            .frame(height: 1)
                            .offset(y: 4)
                    }

                Spacer(minLength: 0)

                RoundedTextButton(title: "복사", style: .large) {
                    UIPasteboard.general.string = inviteCode
                }
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

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionTitle("멤버")

            LazyVGrid(columns: memberColumns, spacing: 16) {
                ForEach(members) { member in
                    ShareGroupMemberCard(member: member)
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var leaveSection: some View {
        VStack(spacing: 24) {
            ShareGroupLeaveButton(isDisabled: isLeaveConfirmationPresented) {
                isLeaveConfirmationPresented = true
            }

            if isLeaveConfirmationPresented {
                ShareGroupLeaveConfirmation(
                    role: group.currentUserRole,
                    onStay: { isLeaveConfirmationPresented = false },
                    onLeave: onLeave
                )
                .id(leaveConfirmationID)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
        group.albums.reduce(0) { $0 + $1.count }
    }

    private var members: [ShareGroupMember] {
        (0 ..< max(group.memberCount, 1)).map { index in
            ShareGroupMember(
                id: index,
                name: "류단아",
                isCurrentUser: index == 0,
                isAdmin: index == 0
            )
        }
    }

    private var leaveConfirmationID: String {
        "share-group-leave-confirmation"
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

private struct ShareGroupMember: Identifiable {
    let id: Int
    let name: String
    let isCurrentUser: Bool
    let isAdmin: Bool
}

private struct ShareGroupMemberCard: View {
    let member: ShareGroupMember

    var body: some View {
        HStack(spacing: 10) {
            ProfileImage(size: 32, isStroke: false)

            HStack(spacing: 4) {
                Text(member.name)
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .lineLimit(1)

                if member.isAdmin {
                    Image(.crown)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .accessibilityLabel("방장")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            member.isCurrentUser ? Color.grey600 : Color.grey800,
            in: .rect(cornerRadius: 8)
        )
        .accessibilityElement(children: .combine)
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
        group: ShareAlbum.samples[0],
        groupName: $groupName,
        inviteCode: "# 3d2dsd322d32d23",
        onClose: {},
        onComplete: {},
        onLeave: {}
    )
}
