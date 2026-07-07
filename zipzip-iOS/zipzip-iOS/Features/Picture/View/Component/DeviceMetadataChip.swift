//
//  DeviceMetadataChip.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import SwiftUI

struct DeviceMetadataChip: View {
    let name: String
    let type: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(isSelected ? .b2_sb : .b2_md)
                    .foregroundStyle(.grey950)
                Text(type)
                    .font(.b3_md)
                    .foregroundStyle(.grey400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? .orange50 : .grey70, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.orange400 : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack(spacing: 8) {
        DeviceMetadataChip(name: "Canon IXUS 860", type: "디지털 카메라", isSelected: false) {}
        DeviceMetadataChip(name: "Sony Alpha a7 III", type: "디지털 카메라", isSelected: true) {}
    }
    .padding()
}
