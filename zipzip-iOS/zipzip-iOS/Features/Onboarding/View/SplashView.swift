//
//  Splash.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct SplashView: View {
    @Environment(Router.self) private var router
    private let continuesOnboarding: Bool

    init(continuesOnboarding: Bool = true) {
        self.continuesOnboarding = continuesOnboarding
    }

    var body: some View {
        OnboardingContainerView(
            topPadding: 0,
            bottomPadding: 0,
            horizontalPadding: 0,
            alignment: .center
        ) {
            VStack {
                Rectangle()
                    .foregroundColor(.grey100)
                    .frame(width: 200, height: 200)
                    .padding(.bottom, 24)

                Image(.splashText)
            }
        }
        .task {
            guard continuesOnboarding else { return }
            try? await Task.sleep(for: .seconds(3))
            router.push(.photoPermission)
        }
    }
}

#Preview {
    SplashView()
        .environment(Router())
}
