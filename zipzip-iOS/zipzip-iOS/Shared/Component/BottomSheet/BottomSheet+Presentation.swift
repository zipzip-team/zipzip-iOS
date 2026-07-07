//
//  BottomSheet+Presentation.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/7/26.
//

import SwiftUI

enum BottomSheetSize: Hashable {
    case content
    case quarter
    case threeQuarters
    case full
    case fraction(CGFloat)
    case height(CGFloat)

    func height(availableHeight: CGFloat, contentHeight: CGFloat) -> CGFloat {
        let availableHeight = max(availableHeight, 1)

        switch self {
        case .content:
            return min(max(contentHeight, 1), availableHeight)
        case .quarter:
            return availableHeight * 0.25
        case .threeQuarters:
            return availableHeight * 0.75
        case .full:
            return availableHeight
        case let .fraction(value):
            return availableHeight * min(max(value, 0), 1)
        case let .height(value):
            return min(max(value, 1), availableHeight)
        }
    }
}

extension View {
    func bottomSheetAlert(
        isPresented: Binding<Bool>,
        detents: [BottomSheetSize] = [.content],
        initialDetent: BottomSheetSize? = nil,
        showsDragIndicator: Visibility = .visible,
        title: String,
        message: String,
        secondaryTitle: String,
        primaryTitle: String,
        onSecondaryTap: @escaping () -> Void = {},
        onPrimaryTap: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            BottomSheetPresentationModifier(
                isPresented: isPresented,
                detents: detents,
                initialDetent: initialDetent,
                showsDragIndicator: .hidden
            ) {
                BottomSheetAlert(
                    title: title,
                    message: message,
                    secondaryTitle: secondaryTitle,
                    primaryTitle: primaryTitle,
                    onSecondaryTap: onSecondaryTap,
                    onPrimaryTap: onPrimaryTap
                )
            }
        )
    }
}

private struct BottomSheetPresentationModifier<SheetContent: View>: ViewModifier {
    @Binding private var isPresented: Bool
    @State private var contentHeight: CGFloat = 320
    @State private var dragOffset: CGFloat = 0
    @State private var selectedSize: BottomSheetSize

    private let detents: [BottomSheetSize]
    private let initialDetent: BottomSheetSize?
    private let showsDragIndicator: Visibility
    private let sheetContent: () -> SheetContent

    init(
        isPresented: Binding<Bool>,
        detents: [BottomSheetSize],
        initialDetent: BottomSheetSize?,
        showsDragIndicator: Visibility,
        @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) {
        _isPresented = isPresented
        self.detents = detents
        self.initialDetent = initialDetent
        self.showsDragIndicator = showsDragIndicator
        self.sheetContent = sheetContent
        _selectedSize = State(initialValue: initialDetent ?? (detents.first ?? .content))
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    ZStack(alignment: .bottom) {
                        if isPresented {
                            Color.black00
                                .opacity(0.45)
                                .ignoresSafeArea()
                                .onTapGesture(perform: dismiss)
                                .transition(.opacity)

                            sheetView(in: proxy)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .allowsHitTesting(isPresented)
            }
            .onChange(of: isPresented) { _, newValue in
                guard newValue else { return }
                dragOffset = 0
                selectedSize = preferredSize
            }
            .animation(.easeOut(duration: 0.2), value: isPresented)
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.9), value: selectedSize)
    }

    private var resolvedSizes: [BottomSheetSize] {
        var sizes = detents.isEmpty ? [.content] : detents

        if let initialDetent, !sizes.contains(initialDetent) {
            sizes.insert(initialDetent, at: 0)
        }

        return sizes
    }

    private var preferredSize: BottomSheetSize {
        initialDetent ?? resolvedSizes.first ?? .content
    }

    private var usesContentHeight: Bool {
        resolvedSizes.contains(.content)
    }

    private var isDragIndicatorVisible: Bool {
        if case .visible = showsDragIndicator {
            return true
        }

        return false
    }

    private func sheetView(in proxy: GeometryProxy) -> some View {
        let bottomFillerHeight = max(proxy.safeAreaInsets.bottom, 34)
        let availableHeight = proxy.size.height
        let selectedHeight = selectedSize.height(
            availableHeight: availableHeight,
            contentHeight: contentHeight
        )
        let allowedHeights = resolvedSizes.map {
            $0.height(availableHeight: availableHeight, contentHeight: contentHeight)
        }
        let minimumHeight = allowedHeights.min() ?? selectedHeight
        let maximumHeight = allowedHeights.max() ?? selectedHeight
        let baseOffset = maximumHeight - selectedHeight
        let maximumOffset = maximumHeight - minimumHeight + 160
        let stableDragOffset = abs(dragOffset) < 2 ? 0 : dragOffset
        let currentOffset = min(max(baseOffset + stableDragOffset, 0), maximumOffset)

        return measuredSheetSurface(availableHeight: availableHeight)
            .frame(maxWidth: .infinity)
            .frame(height: maximumHeight, alignment: .top)
            .background(.grey950, in: bottomSheetPresentationShape)
            .clipShape(bottomSheetPresentationShape)
            .background(alignment: .bottom) {
                Color.grey950
                    .frame(height: bottomFillerHeight)
                    .offset(y: bottomFillerHeight)
                    .ignoresSafeArea(edges: .bottom)
            }
            .offset(y: currentOffset)
            .transaction { transaction in
                guard dragOffset != 0 else { return }
                transaction.animation = nil
            }
    }

    @ViewBuilder
    private func measuredSheetSurface(availableHeight: CGFloat) -> some View {
        if usesContentHeight {
            sheetSurface(availableHeight: availableHeight)
                .fixedSize(horizontal: false, vertical: true)
                .readBottomSheetHeight { height in
                    guard abs(contentHeight - height) > 0.5 else { return }
                    contentHeight = height
                }
        } else {
            sheetSurface(availableHeight: availableHeight)
        }
    }

    private func sheetSurface(availableHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if isDragIndicatorVisible {
                BottomSheetDragIndicator()
                    .gesture(dragGesture(availableHeight: availableHeight))
            }

            sheetContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func dragGesture(availableHeight: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                snapSheet(
                    translation: value.translation.height,
                    predictedTranslation: value.predictedEndTranslation.height,
                    availableHeight: availableHeight
                )
            }
    }

    private func snapSheet(
        translation: CGFloat,
        predictedTranslation: CGFloat,
        availableHeight: CGFloat
    ) {
        let selectedHeight = selectedSize.height(
            availableHeight: availableHeight,
            contentHeight: contentHeight
        )
        let proposedHeight = selectedHeight - predictedTranslation
        let allowedHeights = resolvedSizes.map {
            $0.height(availableHeight: availableHeight, contentHeight: contentHeight)
        }
        let minimumHeight = allowedHeights.min() ?? selectedHeight

        if translation > 120, proposedHeight < minimumHeight + 48 {
            dismiss()
            return
        }

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
            selectedSize = nearestSize(
                to: proposedHeight,
                availableHeight: availableHeight,
                contentHeight: contentHeight
            )
            dragOffset = 0
        }
    }

    private func nearestSize(
        to height: CGFloat,
        availableHeight: CGFloat,
        contentHeight: CGFloat
    ) -> BottomSheetSize {
        resolvedSizes.min { lhs, rhs in
            let lhsHeight = lhs.height(
                availableHeight: availableHeight,
                contentHeight: contentHeight
            )
            let rhsHeight = rhs.height(
                availableHeight: availableHeight,
                contentHeight: contentHeight
            )
            return abs(lhsHeight - height) < abs(rhsHeight - height)
        } ?? preferredSize
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = 0
            isPresented = false
        }
    }
}

private struct BottomSheetDragIndicator: View {
    var body: some View {
        Capsule()
            .fill(.grey600)
            .frame(width: 68, height: 6)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
    }
}

private var bottomSheetPresentationShape: some Shape {
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

extension View {
    fileprivate func readBottomSheetHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: BottomSheetHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        }
        .onPreferenceChange(BottomSheetHeightPreferenceKey.self, perform: onChange)
    }
}

private struct BottomSheetHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 1

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
