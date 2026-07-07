//
//  PhotoPermissionView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct PhotoPermissionView: View {
    var body: some View {
        VStack(spacing: 58) {
            Text("편리한 집집 사용을 위해서는\n접근 권한 허용이 필요해요.")
                .font(.h1_sb)
                .foregroundStyle(Color(.grey900))
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle()
                .fill(.grey100)
                .frame(maxWidth: .infinity)

            Spacer()

            CommonButton(title: "접근 권한 설정하기", property1: .default) {}
        }
        .padding(.top, 42)
        .padding(.bottom, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.orange30)
    }
}

#Preview {
    PhotoPermissionView()
}
