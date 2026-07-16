//
//  MoveInIndicator.swift
//  zipzip-iOS
//

import SwiftUI

struct MoveInIndicator: View {
    enum Mode {
        case moveIn
        case uploading
    }

    var mode: Mode = .moveIn
    var remainingMinutes: Int?
    var tooltipText: String?
    var onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    @State private var indicatorHeight: CGFloat = 0
    @State private var showTooltip = false

    private static let tooltipAutoDismiss: Duration = .seconds(2)

    private enum Layout {
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 10
        static let contentSpacing: CGFloat = 4
        static let dotSpacing: CGFloat = 2
        static let dotSize: CGFloat = 4
        static let dotsHeight: CGFloat = 18
        static let tooltipGap: CGFloat = 8
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
        .contentShape(Capsule())
        .onTapGesture { onTap?() }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { indicatorHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, newHeight in indicatorHeight = newHeight }
            }
        }
        .overlay(alignment: .top) {
            if showTooltip, let tooltipText {
                MoveInTooltip(text: tooltipText)
                    .fixedSize()
                    .offset(y: indicatorHeight + Layout.tooltipGap)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showTooltip)
        .task(id: tooltipText != nil) {
            guard tooltipText != nil else { return }
            showTooltip = true
            try? await Task.sleep(for: Self.tooltipAutoDismiss)
            guard !Task.isCancelled else { return }
            showTooltip = false
        }
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

    private var baseText: String {
        mode == .uploading ? "사진 업로드 중" : "입주하는 중"
    }

    private var label: String {
        guard let remainingMinutes else { return baseText }
        return "\(baseText) · 약 \(Self.durationText(remainingMinutes))"
    }

    private var accessibilityText: String {
        guard let remainingMinutes else { return baseText }
        return "\(baseText), 약 \(Self.durationText(remainingMinutes))"
    }

    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return "\(mins)분"
        }
        if mins == 0 {
            return "\(hours)시간"
        }
        return "\(hours)시간 \(mins)분"
    }
}

#Preview {
    ZStack {
        Color.orange30.ignoresSafeArea()
        VStack(spacing: 60) {
            MoveInIndicator()
            MoveInIndicator(remainingMinutes: 6)
            MoveInIndicator(
                remainingMinutes: 1035,
                tooltipText: "1234장의 사진이 입주했어요!"
            )
        }
    }
}
