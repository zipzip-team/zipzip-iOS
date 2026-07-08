//
//  Splash.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct SplashView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack {
            Rectangle()
                .foregroundColor(.grey100)
                .frame(width: 200, height: 200)
                .padding(.bottom, 24)

            Image(.splashText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.orange30)
        .task {
            try? await Task.sleep(for: .seconds(3))
            router.push(.photoPermission)
        }
    }
}

#Preview {
    SplashView()
        .environment(Router())
}
