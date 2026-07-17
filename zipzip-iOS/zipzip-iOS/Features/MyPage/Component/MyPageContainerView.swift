//
//  MyPageContainerView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/9/26.
//

import SwiftUI

struct MyPageContainerView<TopBar: View, Content: View>: View {
    private let topPadding: CGFloat
    private let horizontalPadding: CGFloat
    private let alignment: Alignment
    private let isContentScrollable: Bool
    private let topBar: TopBar
    private let content: Content

    init(
        topPadding: CGFloat = 0,
        horizontalPadding: CGFloat = 0,
        alignment: Alignment = .top,
        isContentScrollable: Bool = true,
        @ViewBuilder topBar: () -> TopBar,
        @ViewBuilder content: () -> Content
    ) {
        self.topPadding = topPadding
        self.horizontalPadding = horizontalPadding
        self.alignment = alignment
        self.isContentScrollable = isContentScrollable
        self.topBar = topBar()
        self.content = content()
    }

    var body: some View {
        Group {
            if isContentScrollable {
                ScrollView {
                    content
                        .padding(.top, FloatingHeaderLayout.buttonHeight + 30)
                }
            } else {
                content
                    .padding(.top, FloatingHeaderLayout.buttonHeight + 30)
            }
        }
        .padding(.top, topPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .background(.orange30)
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            FloatingHeaderBar {
                topBar
            }
        }
    }
}

#Preview {
    MyPageContainerView {
        RoundedIconButton(items: [
            .init(id: "back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") {}
        ])
    } content: {
        Text("Onboarding")
    }
}
