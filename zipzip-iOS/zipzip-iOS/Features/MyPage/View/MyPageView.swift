//
//  MyPageView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/9/26.
//

import SwiftUI
import UIKit

struct MyPageView: View {
    @Environment(Router.self) private var router
    @Environment(AuthenticationState.self) private var authenticationState
    @Environment(\.openURL) private var openURL
    @State private var viewModel: MyPageViewModel
    @State private var showsLogoutConfirmation = false
    @State private var showsWithdrawWarning = false
    @State private var showsWithdrawFinalConfirmation = false

    @MainActor
    init() {
        self.init(viewModel: MyPageViewModel())
    }

    init(viewModel: MyPageViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        MyPageContainerView {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft, accessibilityLabel: "") { router.pop() }
            ])
        } content: {
            VStack(alignment: .leading, spacing: 32) {
                loginSection
                VStack(spacing: 0) {
                    menuSection
                    if authenticationState.isLoggedIn {
                        accountSection
                    }
                }
            }
        }
        .alert("로그아웃할까요?", isPresented: $showsLogoutConfirmation) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                Task { await authenticationState.logout() }
            }
        } message: {
            Text("이 기기에 저장된 사진과 사진집은 그대로 유지돼요.")
        }
        .alert("회원 탈퇴", isPresented: $showsWithdrawWarning) {
            Button("취소", role: .cancel) {}
            Button("계속", role: .destructive) {
                showsWithdrawFinalConfirmation = true
            }
        } message: {
            Text("서버 계정과 공유 데이터가 삭제될 수 있으며 이 작업은 되돌릴 수 없어요. 로컬 사진과 사진집은 유지돼요.")
        }
        .alert("정말 탈퇴하시겠어요?", isPresented: $showsWithdrawFinalConfirmation) {
            Button("취소", role: .cancel) {}
            Button("탈퇴", role: .destructive) {
                Task { _ = await authenticationState.withdraw() }
            }
        } message: {
            Text("탈퇴가 완료된 뒤 이 기기의 로그인 정보가 삭제돼요.")
        }
    }

    private var loginSection: some View {
        VStack(spacing: 12) {
            Text("마이페이지")
                .font(.t1_sb)
                .foregroundStyle(.grey1000)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            if let user = authenticationState.currentUser {
                HStack(spacing: 14) {
                    ProfileImage(size: 44, isStroke: false)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.t2_sb)
                            .foregroundStyle(.grey1000)
                            .lineLimit(1)

                        Text("반가워요! 집집의 모든 기능을 자유롭게 이용해보세요.")
                            .font(.b2_md)
                            .foregroundStyle(.grey600)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        ProfileImage(size: 44, isStroke: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("로그인이 필요해요")
                                .font(.t2_sb)
                                .foregroundStyle(.grey1000)
                                .lineLimit(1)

                            Text("로그인하고 집집의 모든 기능을 이용해보세요.")
                                .font(.b2_md)
                                .foregroundStyle(.grey600)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    CommonButton(title: "로그인", property1: .cta) {
                        authenticationState.requestLogin(.myPage)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var menuSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                MyPageMenuRow(title: "등록 기기 관리") {
                    router.push(.registeredDeviceManagement)
                }
                MyPageMenuRow(title: "사진 접근 권한") {
                    openAppSettings()
                }
            }
            .padding(.horizontal, 16)

            Rectangle()
                .fill(.grey50)
                .frame(height: 10)

            VStack(spacing: 0) {
                MyPageMenuRow(title: "버전 정보", trailingText: viewModel.appVersion) {}
                MyPageMenuRow(title: "앱 정보") {
                    openLink(.appInfo)
                }
                MyPageMenuRow(title: "개인정보 처리 방침") {
                    openLink(.privacyPolicy)
                }
                MyPageMenuRow(title: "사용자 지원 / 문의") {
                    openLink(.support)
                }
            }
            .padding(.horizontal, 16)

            Rectangle()
                .fill(.grey50)
                .frame(height: 10)
        }
    }

    private var accountSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                accountButton("로그아웃") {
                    showsLogoutConfirmation = true
                }
                accountButton("회원 탈퇴", isDestructive: true, showsDivider: false) {
                    showsWithdrawWarning = true
                }

                if let message = authenticationState.accountErrorMessage {
                    Text(message)
                        .font(.b2_md)
                        .foregroundStyle(.orange700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
        }
        .disabled(authenticationState.operation != .idle)
        .overlay {
            if authenticationState.operation == .loggingOut
                || authenticationState.operation == .withdrawing {
                ProgressView()
            }
        }
    }

    private func accountButton(
        _ title: String,
        isDestructive: Bool = false,
        showsDivider: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.b1_md)
                .foregroundStyle(isDestructive ? .orange500 : .grey1000)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 24)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(.grey70)
                    .frame(height: 1)
            }
        }
    }

    private func openLink(_ link: MyPageLink) {
        guard let url = viewModel.url(for: link) else { return }

        openURL(url)
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }

        UIApplication.shared.open(settingsURL)
    }
}

#if DEBUG
    #Preview {
        MyPageView()
            .environment(Router())
            .environment(AuthenticationState.preview())
    }
#endif
