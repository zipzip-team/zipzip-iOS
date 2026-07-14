//
//  MoveInIndicator.swift
//  zipzip-iOS
//

import SwiftUI

struct MoveInIndicator: View {
    var remainingMinutes: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private enum Layout {
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 10
        static let contentSpacing: CGFloat = 4
        static let dotSpacing: CGFloat = 2
        static let dotSize: CGFloat = 4
        static let dotsHeight: CGFloat = 18
    }

    var body: some View {
        HStack(spacing: Layout.contentSpacing) {
            Text(label)
                .font(.b1_sb)
                .foregroundStyle(.orange500)

            dots
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(.white00, in: Capsule())
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
        .onAppear { isAnimating = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var dots: some View {
        HStack(spacing: Layout.dotSpacing) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(.orange500)
                    .frame(width: Layout.dotSize, height: Layout.dotSize)
                    .opacity(reduceMotion ? 1 : (isAnimating ? 1 : 0.3))
                    .animation(dotAnimation(index), value: isAnimating)
            }
        }
        .frame(height: Layout.dotsHeight)
    }

    private func dotAnimation(_ index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.2)
    }

    private var label: String {
        guard let remainingMinutes else { return "이사 중" }
        return Self.remainingText(remainingMinutes)
    }

    private var accessibilityText: String {
        guard let remainingMinutes else { return "사진을 정리하고 있어요" }
        return "사진 정리 중, 약 \(Self.remainingText(remainingMinutes))"
    }

    private static func remainingText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return "\(mins)분 남음"
        }
        if mins == 0 {
            return "\(hours)시간 남음"
        }
        return "\(hours)시간 \(mins)분 남음"
    }
}

#Preview {
    ZStack {
        Color.orange30.ignoresSafeArea()
        VStack(spacing: 16) {
            MoveInIndicator()
            MoveInIndicator(remainingMinutes: 6)
            MoveInIndicator(remainingMinutes: 1035)
        }
    }
}
