//
//  RoundedIconButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

enum FloatingHeaderLayout {
    static let buttonHeight: CGFloat = 44
    static let roundedIconButtonTop: CGFloat = 68
    static let mainProfileButtonTop: CGFloat = 66
    static let scrollableTitleTop: CGFloat = 71.5
    static let scrollableTitleLayoutHeight = scrollableTitleTop + buttonHeight
    static let scrollableTitleContentSpacing: CGFloat = 12.5
    static let horizontalPadding: CGFloat = 16
}

enum FloatingHeaderPosition {
    case leading
    case trailing

    var alignment: Alignment {
        switch self {
        case .leading:
            .topLeading
        case .trailing:
            .topTrailing
        }
    }

    var horizontalEdge: Edge.Set {
        switch self {
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }
}

struct FloatingHeader<Content: View>: View {
    private let position: FloatingHeaderPosition
    private let top: CGFloat
    private let content: Content

    init(
        _ position: FloatingHeaderPosition,
        top: CGFloat = FloatingHeaderLayout.roundedIconButtonTop,
        @ViewBuilder content: () -> Content
    ) {
        self.position = position
        self.top = top
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .padding(
                    .top,
                    top - geometry.frame(in: .global).minY
                )
                .padding(position.horizontalEdge, FloatingHeaderLayout.horizontalPadding)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: position.alignment
                )
        }
    }
}

struct FloatingHeaderBar<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(
                    .top,
                    FloatingHeaderLayout.roundedIconButtonTop - geometry.frame(in: .global).minY
                )
                .padding(.horizontal, FloatingHeaderLayout.horizontalPadding)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
        }
    }
}

struct ScrollableHeaderTitle: View {
    let title: String
    let isVisible: Bool
    let layoutHeight: CGFloat

    init(
        _ title: String,
        isVisible: Bool = true,
        layoutHeight: CGFloat = FloatingHeaderLayout.scrollableTitleLayoutHeight
    ) {
        self.title = title
        self.isVisible = isVisible
        self.layoutHeight = layoutHeight
    }

    var body: some View {
        Text(title)
            .font(.t1_sb)
            .foregroundStyle(.grey900)
            .frame(maxWidth: .infinity, height: FloatingHeaderLayout.buttonHeight, alignment: .leading)
            .padding(.top, FloatingHeaderLayout.scrollableTitleTop)
            .padding(.horizontal, FloatingHeaderLayout.horizontalPadding)
            .frame(maxWidth: .infinity, height: layoutHeight, alignment: .topLeading)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(!isVisible)
    }
}

struct RoundedIconButton: View {
    private let items: [RoundedIconButtonItem]

    init(items: [RoundedIconButtonItem]) {
        if items.isEmpty {
            assertionFailure("RoundedIconButton requires at least 1 item.")
            self.items = []
        } else if items.count > 3 {
            assertionFailure("RoundedIconButton supports up to 3 items.")
            self.items = Array(items.prefix(3))
        } else {
            self.items = items
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        button(for: item)

                        if index < items.count - 1 {
                            Rectangle()
                                .fill(.grey50)
                                .frame(width: 1, height: 36)
                        }
                    }
                }
                .padding(.horizontal, items.count == 1 ? 8 : 4)
                .frame(height: FloatingHeaderLayout.buttonHeight)
                .background(.white00, in: .capsule)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 4)
            }
        }
    }

    private func button(for item: RoundedIconButtonItem) -> some View {
        Button(action: item.action) {
            Image(item.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.grey1000)
                .frame(width: 28, height: 28)
                .padding(.horizontal, items.count == 1 ? 8 : 12)
                .frame(height: FloatingHeaderLayout.buttonHeight)
                .contentShape(.rect)
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel)
    }
}

#Preview("Rounded Icon Button") {
    VStack(spacing: 16) {
        RoundedIconButton(items: [
            .init(id: "back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                print("뒤로가기 버튼 선택")
            }
        ])

        RoundedIconButton(items: [
            .init(id: "filter", icon: .iconFilter, accessibilityLabel: "필터") {},
            .init(id: "selection", icon: .iconSelection, accessibilityLabel: "사진 선택") {}
        ])

        RoundedIconButton(items: [
            .init(id: "filter", icon: .iconFilter, accessibilityLabel: "필터") {},
            .init(id: "selection", icon: .iconSelection, accessibilityLabel: "사진 선택") {},
            .init(id: "filter-secondary", icon: .iconFilter, accessibilityLabel: "추가 필터") {}
        ])
    }
    .padding()
    .background(.grey100)
}
