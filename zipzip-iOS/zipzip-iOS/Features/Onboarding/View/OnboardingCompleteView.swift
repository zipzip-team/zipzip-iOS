//
//  OnboardingCompleteView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @Environment(Router.self) private var router

    var body: some View {
        OnboardingContainerView(topPadding: 72) {
            VStack(spacing: 18) {
                Rectangle()
                    .fill(.grey100)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)

                Image(.onboardingCompletionText)

                Text("zipzip에서 다양한 기기의 사진들을\n더 쉽고 편리하게 정리해보세요")
                    .font(.b2_md)
                    .foregroundStyle(.grey400)
                    .multilineTextAlignment(.center)

                Spacer()

                CommonButton(title: "입주하기", property1: .default) {}
            }
        }
    }
}

#Preview {
    OnboardingCompleteView()
        .environment(Router())
}
