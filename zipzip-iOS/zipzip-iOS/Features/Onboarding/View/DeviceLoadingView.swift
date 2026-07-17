//
//  DeviceLoadingView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import Lottie
import SwiftUI

struct DeviceLoadingView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoSyncCoordinator.self) private var photoSync
    @State private var isHoldingFinalFrame = false
    private let finalLogoFrame: AnimationFrameTime = 57
    private let animationSpeed = 0.95

    var body: some View {
        @Bindable var photoSync = photoSync
        let isSyncFinished = photoSync.isFinished

        OnboardingContainerView(topPadding: 0, bottomPadding: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(.serviceIntroLoading)
                        .accessibilityLabel("기기 목록을 불러오고 있어요.")

                    Text("잠시만 기다려주세요.")
                        .font(.b1_md)
                        .foregroundStyle(Color(.grey400))
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 38)

                Spacer()

                CommonButton(
                    title: "확인",
                    property1: isSyncFinished ? .default : .disabled
                ) {
                    router.push(.deviceSelection)
                }
                .frame(alignment: .bottom)
                .padding(.bottom, 15)
            }
            .overlay {
                LottieView(animation: .named("logo_motion"))
                    .playbackMode(
                        isHoldingFinalFrame
                            ? .paused(at: .frame(finalLogoFrame))
                            : .playing(.fromFrame(0, toFrame: finalLogoFrame, loopMode: .playOnce))
                    )
                    .animationSpeed(animationSpeed)
                    .animationDidFinish { completed in
                        guard completed, !isHoldingFinalFrame else { return }
                        isHoldingFinalFrame = true
                    }
                    .frame(width: 150, height: 100)
                    .accessibilityHidden(true)
            }
        }
        .task {
            photoSync.startIfNeeded()
        }
        .task(id: isHoldingFinalFrame) {
            guard isHoldingFinalFrame else { return }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            isHoldingFinalFrame = false
        }
    }
}

#Preview {
    DeviceLoadingView()
        .environment(Router())
        .environment(PhotoSyncCoordinator())
}
