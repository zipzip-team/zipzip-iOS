//
//  AlbumCreationSheet.swift
//  zipzip-iOS
//

import SwiftUI

struct AlbumCreationSheet: View {
    static let preferredHeight: CGFloat = 549

    var nameLabel = "사진집 이름"
    @Binding var albumName: String

    let isCreateDisabled: Bool
    var isBusy = false
    let onClose: () -> Void
    let onDeleteTap: () -> Void
    let onCreateTap: () -> Void

    var body: some View {
        BottomSheet(
            leftItem: {
                BottomSheetCloseButton(action: onClose)
                    .disabled(isBusy)
            }
        ) {
            VStack(spacing: 34) {
                AlbumFolder(state: .plain) {
                    EmptyView()
                }
                .accessibilityHidden(true)

                VStack(spacing: 49) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(nameLabel)
                            .font(.t3_md)
                            .foregroundStyle(.grey300)

                        TextInput("이름 입력", text: $albumName)
                            .disabled(isBusy)
                    }

                    HStack(spacing: 16) {
                        CommonButton(
                            title: "삭제",
                            property1: .secondary,
                            action: onDeleteTap
                        )

                        CommonButton(
                            title: "생성",
                            property1: isCreateDisabled ? .disabled : .cta,
                            action: onCreateTap
                        )
                    }
                    .disabled(isBusy)
                }
                .frame(maxWidth: 358)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
