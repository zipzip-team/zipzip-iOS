//
//  FilterChip.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct AppliedFilterChip: View {
    let filter: AppliedFilter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(filter.value)
                .font(.b2_sb)
                .foregroundStyle(.white00)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange500, in: .rect(cornerRadius: 8))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 1)
        }
        .buttonStyle(.plain)
    }
}

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
        AppliedFilterChip(filter: AppliedFilter(kind: .device, value: "iphone 6")) {}
        AppliedFilterChip(filter: AppliedFilter(kind: .location, value: "오사카")) {}
        AddFilterChip {}
    }
    .padding()
    .background(.orange30)
}
