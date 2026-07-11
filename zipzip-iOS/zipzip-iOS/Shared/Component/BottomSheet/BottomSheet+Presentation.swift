//
//  BottomSheet+Presentation.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/7/26.
//

import SwiftUI
import UIKit

enum BottomSheetSize: Hashable {
    case content
    case quarter
    case threeQuarters
    case full
    case fraction(CGFloat)
    case height(CGFloat)
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
    @State private var contentHeight: CGFloat = 320
    @State private var selectedSize: BottomSheetSize

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

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                sheetView
                    .environment(\.bottomSheetDragIndicatorVisibility, showsDragIndicator)
                    .presentationDetents(presentationDetents, selection: selectedDetent)
                    .presentationContentInteraction(
                        expandsToLargestDetentOnScroll ? .resizes : .scrolls
                    )
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(32)
                    .presentationBackground(.grey950)
                    .onAppear {
                        selectedSize = preferredSize
                    }
            }
            .onChange(of: isPresented) { _, newValue in
                guard newValue else {
                    return
                }

                selectedSize = preferredSize
            }
            .onChange(of: resolvedSizes) { _, _ in
                clampSelectedSizeToCurrentDetents()
            }
            .onReceive(NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                    guard keyboardOverlapsScreen(notification) else {
                        return
                    }

                    expandToLargestDetentForKeyboard()
            }
    }

    @ViewBuilder
    private var sheetView: some View {
        let content = sheetContent(dismiss)
            .frame(maxWidth: .infinity, alignment: .top)

        if usesContentHeight {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    guard abs(contentHeight - height) > 0.5 else { return }
                    contentHeight = max(height, 1)
                }
        } else {
            content
        }
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

    private var largestSize: BottomSheetSize {
        resolvedSizes.max { lhs, rhs in
            lhs.estimatedHeight(
                availableHeight: estimatedAvailableHeight,
                contentHeight: contentHeight
            ) < rhs.estimatedHeight(
                availableHeight: estimatedAvailableHeight,
                contentHeight: contentHeight
            )
        } ?? preferredSize
    }

    private var usesContentHeight: Bool {
        resolvedSizes.contains(.content)
    }

    private var presentationDetents: Set<PresentationDetent> {
        Set(
            resolvedSizes.map {
                $0.presentationDetent(contentHeight: contentHeight)
            }
        )
    }

    private var selectedDetent: Binding<PresentationDetent> {
        Binding {
            selectedSize.presentationDetent(contentHeight: contentHeight)
        } set: { newDetent in
            selectedSize = resolvedSizes.first {
                $0.presentationDetent(contentHeight: contentHeight) == newDetent
            } ?? selectedSize
        }
    }

    private func clampSelectedSizeToCurrentDetents() {
        guard isPresented, !resolvedSizes.contains(selectedSize) else {
            return
        }

        selectedSize = preferredSize
    }

    private func expandToLargestDetentForKeyboard() {
        guard isPresented, resolvedSizes.count > 1, selectedSize != largestSize else {
            return
        }

        withAnimation(.easeOut(duration: 0.25)) {
            selectedSize = largestSize
        }
    }

    private func dismiss() {
        isPresented = false
    }

    private func keyboardOverlapsScreen(_ notification: Notification) -> Bool {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return false
        }

        let screenHeight = keyWindow?.windowScene?.screen.bounds.maxY ?? endFrame.maxY

        return endFrame.minY < screenHeight
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private var estimatedAvailableHeight: CGFloat {
        max(
            keyWindow?.bounds.height ?? keyWindow?.windowScene?.screen.bounds.height ?? contentHeight,
            1
        )
    }
}

extension BottomSheetSize {
    fileprivate func estimatedHeight(availableHeight: CGFloat, contentHeight: CGFloat) -> CGFloat {
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
            return availableHeight * min(max(value, 0.01), 1)
        case let .height(value):
            return min(max(value, 1), availableHeight)
        }
    }

    fileprivate func presentationDetent(contentHeight: CGFloat) -> PresentationDetent {
        switch self {
        case .content:
            return .height(max(contentHeight, 1))
        case .quarter:
            return .fraction(0.25)
        case .threeQuarters:
            return .fraction(0.75)
        case .full:
            return .large
        case let .fraction(value):
            return .fraction(min(max(value, 0.01), 1))
        case let .height(value):
            return .height(max(value, 1))
        }
    }
}
