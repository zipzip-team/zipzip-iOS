//
//  OnboardingCompleteView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @Environment(Router.self) private var router
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            Color.orange30
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(.onboardingCompletionArtwork)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Image(.onboardingCompletionText)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 358)
                        .accessibilityLabel("사진집이 완성됐어요!")

                    Text("zipzip에서 다양한 기기의 사진들을\n더 쉽고 편리하게 정리해보세요")
                        .font(.b1_md)
                        .foregroundStyle(.grey400)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 38)
                .padding(.horizontal, 16)

                Spacer(minLength: 16)

                CommonButton(title: "입주하기", property1: .default) {
                    hasCompletedOnboarding = true
                    router.popToRoot()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 15)
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    OnboardingCompleteView()
        .environment(Router())
}
