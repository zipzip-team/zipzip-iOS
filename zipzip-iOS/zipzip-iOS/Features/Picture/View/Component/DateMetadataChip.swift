//
//  DateMetadataChip.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct DateMetadataChip: View {
    let dateText: String?

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.white00)
                    .frame(width: 20, height: 20)
                Image(.calendar)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.grey950)
            }
            Text(dateText ?? "날짜 선택")
                .font(.b2_md)
                .foregroundStyle(.grey950)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.grey70, in: .rect(cornerRadius: 8))
    }
}

#Preview {
    VStack(spacing: 12) {
        DateMetadataChip(dateText: nil)
        DateMetadataChip(dateText: "2026년 7월 2일")
    }
    .padding()
    .background(.orange30)
}
