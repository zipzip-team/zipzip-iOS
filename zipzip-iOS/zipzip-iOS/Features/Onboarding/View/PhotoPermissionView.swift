//
//  PhotoPermissionView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct PhotoPermissionView: View {
    @Environment(Router.self) private var router

    @State private var viewModel = PhotoPermissionViewModel()

    var body: some View {
        OnboardingContainerView {
            VStack(spacing: 92) {
                Text("편리한 집집 사용을 위해서는\n접근 권한 허용이 필요해요.")
                    .font(.h1_sb)
                    .foregroundStyle(Color(.grey900))
                    .frame(maxWidth: .infinity, alignment: .leading)

                PhotoPermissionCard()

                Spacer()

                CommonButton(title: "접근 권한 설정하기", property1: .default) {
                    viewModel.requestPhotoPermission()
                }
            }
        }
        .bottomSheetAlert(
            isPresented: Binding(
                get: { viewModel.showsPermissionAlert },
                set: { viewModel.showsPermissionAlert = $0 }
            ),
            title: "사진 접근 권한이 필요해요",
            message: "사진을 불러오고 정리하려면\n설정에서 사진 접근 권한을 허용해주세요.",
            secondaryTitle: "취소",
            primaryTitle: "설정",
            onSecondaryTap: {
                viewModel.dismissPermissionAlert()
            },
            onPrimaryTap: {
                viewModel.openAppSettings()
            }
        )
        .onChange(of: viewModel.showsDeviceLoadingView) { _, showsDeviceLoadingView in
            guard showsDeviceLoadingView else { return }
            router.push(.deviceLoading)
        }
    }
}

#Preview {
    PhotoPermissionView()
        .environment(Router())
}
