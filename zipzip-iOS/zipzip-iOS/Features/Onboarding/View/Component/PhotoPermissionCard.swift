//
//  PhotoPermissionCard.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI

struct PhotoPermissionCard: View {
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

#Preview {
    PhotoPermissionCard()
}
