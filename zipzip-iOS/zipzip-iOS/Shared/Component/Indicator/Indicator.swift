//
//  Indicator.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct Indicator: View {
    enum Status {
        case selected
        case `default`
    }

    let title: String
    let status: Status

    init(
        title: String,
        status: Status = .default
    ) {
        self.title = title
        self.status = status
    }

    var body: some View {
        Text(displayTitle)
            .font(.b3_sb)
            .foregroundStyle(.orange500)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: minimumWidth)
            .frame(height: 20)
            .background(.grey50, in: .capsule)
            .clipShape(.capsule)
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 2)
            }
    }

    private var displayTitle: String {
        status == .selected ? title : ""
    }

    private var horizontalPadding: CGFloat {
        title.count >= 3 ? 4 : 1
    }

    private var minimumWidth: CGFloat {
        title.count >= 3 ? 28 : 20
    }

    private var borderColor: Color {
        switch status {
        case .selected: .orange500
        case .default: .grey900
        }
    }
}

#Preview("Indicator") {
    VStack(spacing: 18) {
        Indicator(title: "22", status: .selected)
        Indicator(title: "222", status: .selected)
        Indicator(title: "22", status: .default)
    }
    .padding()
    .background(.white00)
}
