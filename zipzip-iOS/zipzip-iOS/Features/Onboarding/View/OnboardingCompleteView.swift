//
//  OnboardingCompleteView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI

struct OnboardingCompleteView: View {
    var body: some View {
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
        .padding(.top, 72)
        .padding(.bottom, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.orange30)
    }
}

#Preview {
    OnboardingCompleteView()
}
