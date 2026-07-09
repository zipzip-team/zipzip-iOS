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
    @Environment(\.openURL) private var openURL
    @State private var viewModel = MyPageViewModel()

    var body: some View {
        MyPageContainerView {
            RoundedIconButton(items: [
                .init(id: "back", icon: .iconChevronLeft) { router.pop() }
            ])
        } content: {
            VStack(alignment: .leading, spacing: 32) {
                loginSection
                menuSection
            }
        }
    }

    private var loginSection: some View {
        VStack(spacing: 12) {
            Text("마이페이지")
                .font(.t1_sb)
                .foregroundStyle(.grey1000)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

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

                CommonButton(title: "로그인", property1: .cta) {}
                    .padding(.horizontal, 16)
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
                    openURL(viewModel.url(for: .appInfo))
                }
                MyPageMenuRow(title: "개인정보 처리 방침") {
                    openURL(viewModel.url(for: .privacyPolicy))
                }
                MyPageMenuRow(title: "사용자 지원 / 문의") {
                    openURL(viewModel.url(for: .support))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }

        UIApplication.shared.open(settingsURL)
    }
}

#Preview {
    MyPageView()
        .environment(Router())
}
