//
//  PhotoPermissionView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/7/26.
//

import SwiftUI

struct PhotoPermissionView: View {
    var body: some View {
        VStack(spacing: 92) {
            Text("편리한 집집 사용을 위해서는\n접근 권한 허용이 필요해요.")
                .font(.h1_sb)
                .foregroundStyle(Color(.grey900))
                .frame(maxWidth: .infinity, alignment: .leading)

            PhotoPermissionCard()

            Spacer()

            CommonButton(title: "접근 권한 설정하기", property1: .default) {}
        }
        .padding(.top, 38)
        .padding(.bottom, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.orange30)
    }
}

#Preview {
    PhotoPermissionView()
}

private struct PhotoPermissionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(.image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.grey900)
                    .frame(width: 24, height: 24)

                Text("사진 (선택)")
                    .font(.t3_sb)
                    .foregroundStyle(.grey900)
            }

            Text("기기에 저장된 사진을 찾고 정리하기 위해 필요해요.")
                .font(.b2_md)
                .foregroundStyle(.grey400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .frame(height: 89)
        .background(.grey50, in: .rect(cornerRadius: 12))
    }
}
