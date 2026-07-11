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
    let deviceType: DeviceType
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
            .padding(.leading, 20)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }

    private var iconView: some View {
        Circle()
            .fill(isSelected ? .orange30 : .white00)
            .frame(width: 50, height: 50)
            .overlay {
                Image(deviceType.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isSelected ? .orange500 : .grey800)
                    .frame(
                        width: deviceType.iconSize.width,
                        height: deviceType.iconSize.height
                    )
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
            deviceType: .camera,
            isSelected: true
        ) {}

        DeviceSelectionButton(
            title: "아이폰",
            subtitle: "iphone 6s",
            deviceType: .phone,
            isSelected: false
        ) {}
    }
    .padding(16)
    .background(.orange30)
}

extension DeviceType {
    fileprivate var icon: ImageResource {
        switch self {
        case .camera: .camera
        case .phone: .iphone
        }
    }

    fileprivate var iconSize: CGSize {
        switch self {
        case .camera: CGSize(width: 34, height: 34)
        case .phone: CGSize(width: 36, height: 36)
        }
    }
}
