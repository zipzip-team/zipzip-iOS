//
//  MoveInTooltip.swift
//  zipzip-iOS
//

import SwiftUI

struct MoveInTooltip: View {
    let text: String

    private enum Layout {
        static let arrowWidth: CGFloat = 14
        static let arrowHeight: CGFloat = 9
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 6
        static let cornerRadius: CGFloat = 8
    }

    var body: some View {
        VStack(spacing: 0) {
            TooltipArrow()
                .fill(.grey50)
                .frame(width: Layout.arrowWidth, height: Layout.arrowHeight)

            Text(text)
                .font(.b3_sb)
                .foregroundStyle(.grey1000)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, Layout.verticalPadding)
                .background(.grey50, in: RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        }
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
        .fixedSize()
    }
}

private struct TooltipArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
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
