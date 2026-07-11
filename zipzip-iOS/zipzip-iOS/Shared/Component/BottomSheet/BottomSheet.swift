//
//  BottomSheet.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/7/26.
//

import SwiftUI

enum BottomSheetTabSelection {
    case left
    case right
}

struct BottomSheetMiddleItem {
    let leftField: String
    let rightField: String
    fileprivate let selection: Binding<BottomSheetTabSelection>

    init(
        leftField: String,
        rightField: String,
        selection: Binding<BottomSheetTabSelection>
    ) {
        self.leftField = leftField
        self.rightField = rightField
        self.selection = selection
    }
}

struct BottomSheet<Content: View>: View {
    @Environment(\.bottomSheetDragIndicatorVisibility) private var dragIndicatorVisibility

    private let middleItem: BottomSheetMiddleItem?
    private let leftItem: AnyView?
    private let rightItem: AnyView?
    private let content: Content

    init(
        middleItem: BottomSheetMiddleItem? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.middleItem = middleItem
        self.leftItem = nil
        self.rightItem = nil
        self.content = content()
    }

    init<LeftItem: View>(
        middleItem: BottomSheetMiddleItem? = nil,
        @ViewBuilder leftItem: () -> LeftItem,
        @ViewBuilder content: () -> Content
    ) {
        self.middleItem = middleItem
        self.leftItem = AnyView(leftItem())
        self.rightItem = nil
        self.content = content()
    }

    init<RightItem: View>(
        middleItem: BottomSheetMiddleItem? = nil,
        @ViewBuilder rightItem: () -> RightItem,
        @ViewBuilder content: () -> Content
    ) {
        self.middleItem = middleItem
        self.leftItem = nil
        self.rightItem = AnyView(rightItem())
        self.content = content()
    }

    init<LeftItem: View, RightItem: View>(
        middleItem: BottomSheetMiddleItem? = nil,
        @ViewBuilder leftItem: () -> LeftItem,
        @ViewBuilder rightItem: () -> RightItem,
        @ViewBuilder content: () -> Content
    ) {
        self.middleItem = middleItem
        self.leftItem = AnyView(leftItem())
        self.rightItem = AnyView(rightItem())
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if dragIndicatorVisibility != .hidden {
                dragIndicator
            }

            if showsHeader {
                header
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.grey950, in: bottomSheetShape)
    }

    private var showsHeader: Bool {
        middleItem != nil || leftItem != nil || rightItem != nil
    }

    private var dragIndicator: some View {
        Capsule()
            .fill(.grey600)
            .frame(width: 100, height: 6)
            .padding(.top, 16)
            .frame(height: 46, alignment: .top)
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerLeftItem
                .frame(width: 72, alignment: .leading)

            Spacer(minLength: 0)

            headerMiddleItem
                .layoutPriority(1)

            Spacer(minLength: 0)

            headerRightItem
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
    }

    @ViewBuilder
    private var headerLeftItem: some View {
        if let leftItem {
            leftItem
        }
    }

    @ViewBuilder
    private var headerMiddleItem: some View {
        if let middleItem {
            HStack(spacing: 12) {
                SelectableButton(
                    title: middleItem.leftField,
                    isSelected: middleItem.selection.wrappedValue == .left,
                    selectedColor: .orange500
                ) {
                    middleItem.selection.wrappedValue = .left
                }

                SelectableButton(
                    title: middleItem.rightField,
                    isSelected: middleItem.selection.wrappedValue == .right,
                    selectedColor: .orange500
                ) {
                    middleItem.selection.wrappedValue = .right
                }
            }
            .frame(minHeight: 48)
        }
    }

    @ViewBuilder
    private var headerRightItem: some View {
        if let rightItem {
            rightItem
        }
    }
}

struct BottomSheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.cancel)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white00)
                .frame(width: 24, height: 24)
                .frame(width: 72, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("닫기")
    }
}

struct BottomSheetBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.chevronLeft)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white00)
                .frame(width: 24, height: 24)
                .frame(width: 72, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("뒤로가기")
    }
}

extension EnvironmentValues {
    @Entry var bottomSheetDragIndicatorVisibility: Visibility = .visible
}

#Preview("BottomSheet") {
    BottomSheetPreview()
}

private var bottomSheetShape: some Shape {
    UnevenRoundedRectangle(
        cornerRadii: .init(
            topLeading: 32,
            bottomLeading: 0,
            bottomTrailing: 0,
            topTrailing: 32
        ),
        style: .continuous
    )
}

private struct BottomSheetPreview: View {
    @State private var selection: BottomSheetTabSelection = .right

    var body: some View {
        BottomSheet(
            middleItem: .init(
                leftField: "개인",
                rightField: "공유",
                selection: $selection
            ),
            leftItem: {
                BottomSheetCloseButton {}
            },
            rightItem: {
                Button {} label: {
                    Image(.plus)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white00)
                        .frame(width: 24, height: 24)
                        .frame(width: 72, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        ) {
            Rectangle()
                .fill(.grey950)
        }
        .frame(width: 390, height: 782)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black)
    }
}
