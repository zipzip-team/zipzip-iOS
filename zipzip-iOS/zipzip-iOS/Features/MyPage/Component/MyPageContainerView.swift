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
    private let topBar: TopBar
    private let content: Content

    init(
        topPadding: CGFloat = 0,
        horizontalPadding: CGFloat = 0,
        alignment: Alignment = .top,
        @ViewBuilder topBar: () -> TopBar,
        @ViewBuilder content: () -> Content
    ) {
        self.topPadding = topPadding
        self.horizontalPadding = horizontalPadding
        self.alignment = alignment
        self.topBar = topBar()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)

                content
                    .padding(.top, 8)
            }
        }
        .padding(.top, topPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .background(.orange30)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    MyPageContainerView {
        RoundedIconButton(items: [
            .init(id: "back", icon: .iconChevronLeft) {}
        ])
    } content: {
        Text("Onboarding")
    }
}
