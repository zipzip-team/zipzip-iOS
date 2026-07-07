//
//  LocationMetadataChip.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/7/26.
//

import SwiftUI

struct LocationMetadataChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.b2_sb)
                .hidden()
                .overlay {
                    Text(title)
                        .font(isSelected ? .b2_sb : .b2_md)
                        .foregroundStyle(.grey950)
                        .contentTransition(.identity)
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
        LocationMetadataChip(title: "오사카", isSelected: false) {}
        LocationMetadataChip(title: "도쿄", isSelected: true) {}
    }
    .padding()
}
