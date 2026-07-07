//
//  Splash.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct SplashView: View {
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
    }
}

#Preview {
    SplashView()
}
