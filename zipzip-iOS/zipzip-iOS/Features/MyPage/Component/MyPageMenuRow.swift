//
//  MyPageMenuRow.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

import SwiftUI

struct MyPageMenuRow: View {
    let title: String
    var trailingText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.b1_md)
                    .foregroundStyle(.grey1000)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingText {
                    Text(trailingText)
                        .font(.b1_md)
                        .foregroundStyle(.orange500)
                        .padding(.horizontal, 6)
                } else {
                    Image(.chevronRight)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.grey600)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 24)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.grey70)
                .frame(height: 1)
        }
    }
}
