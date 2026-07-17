//
//  Splash.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import Lottie
import Photos
import SwiftUI

struct SplashView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoSyncCoordinator.self) private var photoSync
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var animationStarted = false
    @State private var lottieFinished = false
    @State private var splashContentOpacity = 1.0
    private let continuesOnboarding: Bool
    private let onAnimationFinished: (() -> Void)?
    private let finalLogoFrame: AnimationFrameTime = 57
    private let animationSpeed = 0.95

    init(continuesOnboarding: Bool = true, onAnimationFinished: (() -> Void)? = nil) {
        self.continuesOnboarding = continuesOnboarding
        self.onAnimationFinished = onAnimationFinished
    }

    var body: some View {
        OnboardingContainerView(
            topPadding: 0,
            bottomPadding: 0,
            horizontalPadding: 0,
            alignment: .center
        ) {
            VStack {
                LottieView(animation: .named("logo_motion"))
                    .playbackMode(logoPlaybackMode)
                    .animationSpeed(animationSpeed)
                    .animationDidFinish { completed in
                        guard completed, !lottieFinished else { return }
                        lottieFinished = true
                    }
                    .frame(width: 200, height: 200)
                    .padding(.bottom, 24)

                Image(.splashText)
            }
            .opacity(splashContentOpacity)
        }
        .task {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }

            animationStarted = true
        }
        .task(id: lottieFinished) {
            guard lottieFinished else { return }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            withAnimation(.easeInOut(duration: 0.4)) {
                splashContentOpacity = 0
            }

            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                return
            }

            onAnimationFinished?()
            guard continuesOnboarding else { return }
            guard router.path.isEmpty, !hasCompletedOnboarding else { return }

            // 이미 사진 접근이 허용/제한된 상태면 권한 요청 뷰를 건너뛰고 바로 서비스 설명으로 이동한다.
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .authorized || status == .limited {
                photoSync.startIfNeeded()
                router.push(.serviceIntro)
            } else {
                router.push(.photoPermission)
            }
        }
    }

    private var logoPlaybackMode: LottiePlaybackMode {
        if !animationStarted {
            return .paused(at: .frame(0))
        }
        if lottieFinished {
            return .paused(at: .frame(finalLogoFrame))
        }
        return .playing(.fromFrame(nil, toFrame: finalLogoFrame, loopMode: .playOnce))
    }
}

#Preview {
    SplashView()
        .environment(Router())
        .environment(PhotoSyncCoordinator())
}
