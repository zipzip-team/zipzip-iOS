//
//  DeviceSelectionButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct DeviceSelectionButton: View {
    let title: String
    let subtitle: String
    let icon: ImageResource
    var iconSize: CGSize = CGSize(width: 24, height: 24)
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                iconView

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.t3_sb)
                        .foregroundStyle(isSelected ? .orange500 : .grey900)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.b2_md)
                        .foregroundStyle(.grey400)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.leading, 24)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(backgroundColor, in: .rect(cornerRadius: 12))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange400, lineWidth: 2)
                }
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var iconView: some View {
        Circle()
            .fill(isSelected ? .orange30 : .white00)
            .frame(width: 50, height: 50)
            .overlay {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isSelected ? .orange500 : .grey900)
                    .frame(width: iconSize.width, height: iconSize.height)
            }
    }

    private var backgroundColor: Color {
        isSelected ? .orange50 : .grey50
    }
}

#Preview {
    VStack(spacing: 16) {
        DeviceSelectionButton(
            title: "캐논 디지털 카메라",
            subtitle: "Canon IXUS 860",
            icon: .camera,
            iconSize: CGSize(width: 33, height: 24),
            isSelected: true
        ) {}

        DeviceSelectionButton(
            title: "아이폰",
            subtitle: "iphone 6s",
            icon: .iphone,
            iconSize: CGSize(width: 20, height: 32),
            isSelected: false
        ) {}
    }
    .padding(16)
    .background(.orange30)
}
