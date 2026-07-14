//
//  ProfileButton.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct ProfileButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "person")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.grey1000)
                .frame(width: 24, height: 24)
                .padding(8)
                .background(.white00, in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 6, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileButton {}
        .padding()
        .background(.orange30)
}
