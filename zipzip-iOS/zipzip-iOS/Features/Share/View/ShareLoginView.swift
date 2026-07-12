//
//  ShareLoginView.swift
//  zipzip-iOS
//

import SwiftUI

struct ShareLoginView: View {
    let onBack: () -> Void
    let onAppleLogin: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.orange30

            ShareLoginScene()
                .frame(width: 390, height: 520)

            loginContent
                .padding(.top, 560)

            RoundedIconButton(items: [
                .init(id: "share-login-back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                    onBack()
                }
            ])
            .padding(.top, 66)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var loginContent: some View {
        VStack(spacing: 26) {
            Image(.shareLoginSocialText)
                .resizable()
                .scaledToFit()
                .frame(width: 162, height: 53)
                .accessibilityLabel("소셜 계정으로 간편하게 로그인하기")

            Button(action: onAppleLogin) {
                ZStack {
                    Text("Apple로 계속하기")
                        .font(.t3_md)
                        .foregroundStyle(.white00)

                    Image(.shareLoginAppleLogo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 7)
                        .accessibilityHidden(true)
                }
                .frame(width: 320, height: 44)
                .background(.black, in: .rect(cornerRadius: 4))
                .contentShape(.rect(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Apple로 계속하기")
        }
        .frame(width: 358)
    }
}

private struct ShareLoginScene: View {
    var body: some View {
        ZStack(alignment: .top) {
            Image(.shareLoginBackdrop)
                .resizable()
                .scaledToFit()
                .frame(width: 327, height: 148)
                .padding(.top, 219)

            LinearGradient(
                colors: [.orange30.opacity(0), .orange30],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 79)
            .padding(.top, 274)

            Image(.shareLoginForeground)
                .resizable()
                .frame(width: 390, height: 520)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Share Login", traits: .fixedLayout(width: 390, height: 844)) {
    ShareLoginView(onBack: {}, onAppleLogin: {})
}
