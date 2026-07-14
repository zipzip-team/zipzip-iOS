//
//  MoveInIndicator.swift
//  zipzip-iOS
//

import SwiftUI

struct MoveInIndicator: View {
    var remainingMinutes: Int?
    var tooltipText: String?
    @Binding var isTooltipPresented: Bool

    init(
        remainingMinutes: Int? = nil,
        tooltipText: String? = nil,
        isTooltipPresented: Binding<Bool> = .constant(false)
    ) {
        self.remainingMinutes = remainingMinutes
        self.tooltipText = tooltipText
        _isTooltipPresented = isTooltipPresented
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private static let tooltipAutoDismiss: Duration = .seconds(2)

    private enum Layout {
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 10
        static let contentSpacing: CGFloat = 4
        static let dotSpacing: CGFloat = 2
        static let dotSize: CGFloat = 4
        static let dotsHeight: CGFloat = 18
        static let tooltipGap: CGFloat = 12
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
        .onTapGesture {
            guard tooltipText != nil else { return }
            isTooltipPresented.toggle()
        }
        .overlay(alignment: .bottom) {
            if isTooltipPresented, let tooltipText {
                MoveInTooltip(text: tooltipText)
                    .alignmentGuide(VerticalAlignment.bottom) { dimensions in
                        dimensions[VerticalAlignment.top] - Layout.tooltipGap
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isTooltipPresented)
        .task(id: isTooltipPresented) {
            guard isTooltipPresented else { return }
            try? await Task.sleep(for: Self.tooltipAutoDismiss)
            guard !Task.isCancelled else { return }
            isTooltipPresented = false
        }
        .onAppear { isAnimating = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(tooltipText == nil ? "" : "두 번 탭하면 등록된 사진 수를 볼 수 있습니다.")
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
        VStack(spacing: 60) {
            MoveInIndicator()
            MoveInIndicator(remainingMinutes: 6)
            MoveInIndicator(
                remainingMinutes: 1035,
                tooltipText: "1234장의 사진이 입주했어요!",
                isTooltipPresented: .constant(true)
            )
        }
    }
}
