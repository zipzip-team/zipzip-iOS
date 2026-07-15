//
//  DeviceLoadingView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct DeviceLoadingView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoSyncCoordinator.self) private var photoSync

    var body: some View {
        @Bindable var photoSync = photoSync
        let isSyncFinished = photoSync.isFinished

        OnboardingContainerView {
            VStack(spacing: 38) {
                VStack(spacing: 4) {
                    Image(.serviceIntroLoading)
                        .accessibilityLabel("기기 목록을 불러오고 있어요.")

                    Text("잠시만 기다려주세요.")
                        .font(.b1_md)
                        .foregroundStyle(Color(.grey400))
                        .frame(maxWidth: .infinity)
                }

                Rectangle()
                    .fill(.grey100)
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)

                Spacer()

                CommonButton(
                    title: "확인",
                    property1: isSyncFinished ? .default : .disabled
                ) {
                    router.push(.deviceSelection)
                }
                .frame(alignment: .bottom)
            }
        }
        .task {
            photoSync.startIfNeeded()
        }
        .alert("기기 목록을 불러오지 못했어요.", isPresented: $photoSync.isErrorAlertPresented) {
            Button("취소", role: .cancel) {
                photoSync.dismissSyncError()
            }
            Button("다시 시도") {
                photoSync.retrySync()
            }
        } message: {
            Text("잠시 후 다시 시도해주세요.")
        }
    }
}

#Preview {
    DeviceLoadingView()
        .environment(Router())
        .environment(PhotoSyncCoordinator())
}
