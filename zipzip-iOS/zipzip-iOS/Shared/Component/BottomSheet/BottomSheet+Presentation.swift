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
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: [BottomSheetSize] = [.content],
        initialDetent: BottomSheetSize? = nil,
        showsDragIndicator: Visibility = .visible,
        expandsToLargestDetentOnScroll: Bool = true,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        bottomSheet(
            isPresented: isPresented,
            detents: detents,
            initialDetent: initialDetent,
            showsDragIndicator: showsDragIndicator,
            expandsToLargestDetentOnScroll: expandsToLargestDetentOnScroll
        ) { _ in
            content()
        }
    }

    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: [BottomSheetSize] = [.content],
        initialDetent: BottomSheetSize? = nil,
        showsDragIndicator: Visibility = .visible,
        expandsToLargestDetentOnScroll: Bool = true,
        @ViewBuilder content: @escaping (@escaping () -> Void) -> SheetContent
    ) -> some View {
        modifier(
            BottomSheetPresentationModifier(
                isPresented: isPresented,
                detents: detents,
                initialDetent: initialDetent,
                showsDragIndicator: showsDragIndicator,
                expandsToLargestDetentOnScroll: expandsToLargestDetentOnScroll,
                sheetContent: content
            )
        )
    }

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
                showsDragIndicator: .hidden,
                expandsToLargestDetentOnScroll: false
            ) { _ in
                BottomSheetAlert(
                    title: title,
                    message: message,
                    secondaryTitle: secondaryTitle,
                    primaryTitle: primaryTitle,
                    onSecondaryTap: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            onSecondaryTap()
                        }
                    },
                    onPrimaryTap: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            onPrimaryTap()
                        }
                    }
                )
            }
        )
    }
}

private struct BottomSheetPresentationModifier<SheetContent: View>: ViewModifier {
    @Binding private var isPresented: Bool

    private let detents: [BottomSheetSize]
    private let initialDetent: BottomSheetSize?
    private let showsDragIndicator: Visibility
    private let expandsToLargestDetentOnScroll: Bool
    private let sheetContent: (@escaping () -> Void) -> SheetContent

    init(
        isPresented: Binding<Bool>,
        detents: [BottomSheetSize],
        initialDetent: BottomSheetSize?,
        showsDragIndicator: Visibility,
        expandsToLargestDetentOnScroll: Bool,
        @ViewBuilder sheetContent: @escaping (@escaping () -> Void) -> SheetContent
    ) {
        _isPresented = isPresented
        self.detents = detents
        self.initialDetent = initialDetent
        self.showsDragIndicator = showsDragIndicator
        self.expandsToLargestDetentOnScroll = expandsToLargestDetentOnScroll
        self.sheetContent = sheetContent
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                BottomSheetPresentationOverlay(
                    isPresented: $isPresented,
                    detents: detents,
                    initialDetent: initialDetent,
                    showsDragIndicator: showsDragIndicator,
                    expandsToLargestDetentOnScroll: expandsToLargestDetentOnScroll,
                    sheetContent: sheetContent
                )
            }
    }
}

private struct BottomSheetPresentationOverlay<SheetContent: View>: View {
    @Binding private var isPresented: Bool
    @State private var contentHeight: CGFloat = 320
    @State private var dragOffset: CGFloat = 0
    @State private var selectedSize: BottomSheetSize
    @GestureState private var isScrollExpansionGestureActive = false

    private let detents: [BottomSheetSize]
    private let initialDetent: BottomSheetSize?
    private let showsDragIndicator: Visibility
    private let expandsToLargestDetentOnScroll: Bool
    private let sheetContent: (@escaping () -> Void) -> SheetContent

    init(
        isPresented: Binding<Bool>,
        detents: [BottomSheetSize],
        initialDetent: BottomSheetSize?,
        showsDragIndicator: Visibility,
        expandsToLargestDetentOnScroll: Bool,
        @ViewBuilder sheetContent: @escaping (@escaping () -> Void) -> SheetContent
    ) {
        _isPresented = isPresented
        self.detents = detents
        self.initialDetent = initialDetent
        self.showsDragIndicator = showsDragIndicator
        self.expandsToLargestDetentOnScroll = expandsToLargestDetentOnScroll
        self.sheetContent = sheetContent
        _selectedSize = State(initialValue: initialDetent ?? (detents.first ?? .content))
    }

    var body: some View {
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
        .onChange(of: isPresented) { _, newValue in
            guard newValue else { return }
            dragOffset = 0
            selectedSize = preferredSize
        }
        .onChange(of: resolvedSizes) { _, _ in
            clampSelectedSizeToCurrentDetents()
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
        let bottomSafeAreaInset = proxy.safeAreaInsets.bottom
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
        let sheetHeight = maximumHeight + bottomSafeAreaInset
        let visibleHeight = max(maximumHeight - currentOffset + bottomSafeAreaInset, 1)

        return measuredSheetSurface(
            availableHeight: availableHeight,
            visibleHeight: visibleHeight,
            bottomSafeAreaInset: bottomSafeAreaInset
        )
        .frame(maxWidth: .infinity)
        .frame(height: sheetHeight, alignment: .top)
        .background(.grey950, in: bottomSheetPresentationShape)
        .clipShape(bottomSheetPresentationShape)
        .offset(y: currentOffset + bottomSafeAreaInset)
        .transaction { transaction in
            guard dragOffset != 0 else { return }
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private func measuredSheetSurface(
        availableHeight: CGFloat,
        visibleHeight: CGFloat,
        bottomSafeAreaInset: CGFloat
    ) -> some View {
        if usesContentHeight {
            sheetSurface(
                availableHeight: availableHeight,
                visibleHeight: nil,
                bottomSafeAreaInset: bottomSafeAreaInset
            )
            .fixedSize(horizontal: false, vertical: true)
            .readBottomSheetHeight { height in
                guard abs(contentHeight - height) > 0.5 else { return }
                contentHeight = height
            }
        } else {
            sheetSurface(
                availableHeight: availableHeight,
                visibleHeight: visibleHeight,
                bottomSafeAreaInset: bottomSafeAreaInset
            )
        }
    }

    @ViewBuilder
    private func sheetSurface(
        availableHeight: CGFloat,
        visibleHeight: CGFloat?,
        bottomSafeAreaInset: CGFloat
    ) -> some View {
        let shouldExpandBeforeScrolling = shouldExpandBeforeScrolling(
            availableHeight: availableHeight
        )
        let shouldLockScrolling = shouldExpandBeforeScrolling || isScrollExpansionGestureActive
        let surface = VStack(spacing: 0) {
            if isDragIndicatorVisible {
                BottomSheetDragIndicator()
                    .highPriorityGesture(dragGesture(availableHeight: availableHeight))
            }

            lockedScrollContent(
                availableHeight: availableHeight,
                bottomSafeAreaInset: bottomSafeAreaInset,
                shouldLockScrolling: shouldLockScrolling
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())

        if let visibleHeight {
            surface.frame(height: visibleHeight, alignment: .top)
        } else {
            surface
        }
    }

    @ViewBuilder
    private func lockedScrollContent(
        availableHeight: CGFloat,
        bottomSafeAreaInset: CGFloat,
        shouldLockScrolling: Bool
    ) -> some View {
        let content = sheetContent(dismiss)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .bottomSheetSafeAreaInset(bottomSafeAreaInset)
            .scrollDisabled(shouldLockScrolling)

        if shouldLockScrolling {
            content.highPriorityGesture(
                scrollExpansionGesture(availableHeight: availableHeight)
            )
        } else {
            content
        }
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
        let isAtMinimumHeight = selectedHeight <= minimumHeight + 0.5
        let distanceToMinimumHeight = max(selectedHeight - minimumHeight, 0)
        let shouldDismissFromMinimumHeight = isAtMinimumHeight
            && translation > 120
            && proposedHeight < minimumHeight + 48
        let shouldDismissFromHigherHeight = !isAtMinimumHeight && (
            translation > 220 && proposedHeight < minimumHeight - 48 ||
                translation > 40 && predictedTranslation > distanceToMinimumHeight + 320
        )

        if shouldDismissFromMinimumHeight || shouldDismissFromHigherHeight {
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

    private func clampSelectedSizeToCurrentDetents() {
        guard isPresented, !resolvedSizes.contains(selectedSize) else {
            return
        }

        dragOffset = 0
        selectedSize = preferredSize
    }

    private func shouldExpandBeforeScrolling(availableHeight: CGFloat) -> Bool {
        guard expandsToLargestDetentOnScroll, resolvedSizes.count > 1 else {
            return false
        }

        let selectedHeight = selectedSize.height(
            availableHeight: availableHeight,
            contentHeight: contentHeight
        )
        let largestHeight = largestSize(
            availableHeight: availableHeight,
            contentHeight: contentHeight
        )
        .height(availableHeight: availableHeight, contentHeight: contentHeight)

        return selectedHeight < largestHeight - 0.5
    }

    private func largestSize(
        availableHeight: CGFloat,
        contentHeight: CGFloat
    ) -> BottomSheetSize {
        resolvedSizes.max { lhs, rhs in
            lhs.height(
                availableHeight: availableHeight,
                contentHeight: contentHeight
            ) < rhs.height(
                availableHeight: availableHeight,
                contentHeight: contentHeight
            )
        } ?? preferredSize
    }

    private func scrollExpansionGesture(availableHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($isScrollExpansionGestureActive) { value, state, _ in
                guard value.translation.height < -8 || value.predictedEndTranslation.height < -20 else {
                    return
                }

                state = true
            }
            .onChanged { value in
                guard value.translation.height < -8 || value.predictedEndTranslation.height < -20 else {
                    return
                }
                guard shouldExpandBeforeScrolling(availableHeight: availableHeight) else {
                    return
                }

                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
                    selectedSize = largestSize(
                        availableHeight: availableHeight,
                        contentHeight: contentHeight
                    )
                    dragOffset = 0
                }
            }
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
    @ViewBuilder
    fileprivate func bottomSheetSafeAreaInset(_ height: CGFloat) -> some View {
        if height > 0.5 {
            safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: height)
            }
        } else {
            self
        }
    }

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
