//
//  FilterChip.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

/// 적용된 필터를 나타내는 주황 라벨 칩.
struct AppliedFilterChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.b2_sb)
            .foregroundStyle(.white00)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.orange500, in: .rect(cornerRadius: 8))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 1)
    }
}

/// 필터를 추가하는 흰색 "+" 칩.
struct AddFilterChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.plus)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.orange500)
                .frame(width: 29, height: 29)
                .background(.white00, in: .rect(cornerRadius: 8))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 10) {
        AppliedFilterChip(title: "iphone 6")
        AppliedFilterChip(title: "오사카")
        AddFilterChip {}
    }
    .padding()
    .background(.orange30)
}
