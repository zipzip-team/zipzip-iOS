//
//  OnboardingContainerView.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct OnboardingContainerView<Content: View>: View {
    private let topPadding: CGFloat
    private let bottomPadding: CGFloat
    private let horizontalPadding: CGFloat
    private let alignment: Alignment
    private let content: Content

    init(
        topPadding: CGFloat = 38,
        bottomPadding: CGFloat = 15,
        horizontalPadding: CGFloat = 16,
        alignment: Alignment = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.horizontalPadding = horizontalPadding
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .background(.orange30)
            .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    OnboardingContainerView {
        Text("Onboarding")
    }
}
