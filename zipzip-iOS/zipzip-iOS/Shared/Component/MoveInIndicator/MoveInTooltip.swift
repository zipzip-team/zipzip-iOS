//
//  MoveInTooltip.swift
//  zipzip-iOS
//

import SwiftUI

struct MoveInTooltip: View {
    let text: String

    private enum Layout {
        static let arrowWidth: CGFloat = 14
        static let arrowHeight: CGFloat = 8
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 6
        static let cornerRadius: CGFloat = 8
    }

    var body: some View {
        Text(text)
            .font(.b3_sb)
            .foregroundStyle(.grey1000)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .padding(.top, Layout.arrowHeight)
            .background {
                TooltipBubble(
                    arrowWidth: Layout.arrowWidth,
                    arrowHeight: Layout.arrowHeight,
                    cornerRadius: Layout.cornerRadius
                )
                .fill(.grey50)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
            }
            .fixedSize()
    }
}

private struct TooltipBubble: Shape {
    let arrowWidth: CGFloat
    let arrowHeight: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyTop = rect.minY + arrowHeight
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: bodyTop, width: rect.width, height: rect.height - arrowHeight),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX - arrowWidth / 2, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.midX + arrowWidth / 2, y: bodyTop))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.orange30.ignoresSafeArea()
        MoveInTooltip(text: "1234장의 사진이 입주했어요!")
    }
}
