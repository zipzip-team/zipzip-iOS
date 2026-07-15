//
//  ShareLoginView.swift
//  zipzip-iOS
//

import AuthenticationServices
import SwiftUI

struct ShareLoginView: View {
    @Environment(AuthenticationState.self) private var authenticationState

    var body: some View {
        @Bindable var authenticationState = authenticationState

        ZStack(alignment: .top) {
            Color.orange30

            ShareLoginScene()
                .frame(width: 390, height: 520)

            loginContent(displayName: $authenticationState.displayNameDraft)
                .padding(.top, 560)

            if authenticationState.isAuthenticating {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            if !authenticationState.isAuthenticating {
                FloatingHeader(.leading) {
                    RoundedIconButton(items: [
                        .init(id: "share-login-back", icon: .iconChevronLeft, accessibilityLabel: "뒤로가기") {
                            authenticationState.cancelLogin()
                        }
                    ])
                }
            }
        }
    }

    private func loginContent(displayName: Binding<String>) -> some View {
        VStack(spacing: 20) {
            Image(.shareLoginSocialText)
                .resizable()
                .scaledToFit()
                .frame(width: 162, height: 53)
                .accessibilityLabel("소셜 계정으로 간편하게 로그인하기")

            if authenticationState.requiresDisplayName {
                VStack(spacing: 6) {
                    TextInput("이름 입력", text: displayName)
                        .frame(width: 320)

                    Text("이름은 1자 이상 50자 이하로 입력해 주세요.")
                        .font(.b2_md)
                        .foregroundStyle(
                            authenticationState.isDisplayNameValid ? .grey600 : .orange700
                        )
                        .frame(width: 320, alignment: .leading)
                }
            }

            SignInWithAppleButton(
                .continue,
                onRequest: authenticationState.prepareAppleRequest,
                onCompletion: authenticationState.handleAppleCompletion
            )
            .signInWithAppleButtonStyle(.black)
            .frame(width: 320, height: 44)
            .clipShape(.rect(cornerRadius: 4))
            .disabled(
                authenticationState.isAuthenticating
                    || (authenticationState.requiresDisplayName && !authenticationState.isDisplayNameValid)
            )

            #if DEBUG
                if DevelopmentAuthConfiguration.current != nil {
                    CommonButton(title: "개발 계정으로 로그인", property1: .secondary) {
                        Task { await authenticationState.loginForDevelopment() }
                    }
                    .frame(width: 320)
                    .disabled(authenticationState.isAuthenticating)
                }
            #endif

            if let errorMessage = authenticationState.loginErrorMessage {
                Text(errorMessage)
                    .font(.b2_md)
                    .foregroundStyle(.orange700)
                    .multilineTextAlignment(.center)
                    .frame(width: 320)
            }
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

#if DEBUG
    #Preview("Share Login", traits: .fixedLayout(width: 390, height: 844)) {
        ShareLoginView()
            .environment(AuthenticationState.preview())
    }
#endif
