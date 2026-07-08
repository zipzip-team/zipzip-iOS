//
//  HomePhotoCardButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct HomePhotoCardButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.chevronRight)
                .renderingMode(.template)
                .foregroundStyle(.grey1000)
                .frame(width: 24, height: 24)
        }
        .frame(width: 32, height: 32)
        .background(.white00, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .buttonStyle(.plain)
    }
}

#Preview {
    HomePhotoCardButton {}
        .padding()
        .background(.orange30)
}
