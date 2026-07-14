//
//  HomePhotoCard.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct HomePhotoCard: View {
    let eyebrow: String
    let title: String
    let backgroundColor: Color
    let image: ImageResource

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(eyebrow)
                    .font(.b3_md)
                    .foregroundStyle(.grey800)

                Text(title)
                    .font(.b1_sb)
                    .foregroundStyle(.grey1000)
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)

            Spacer(minLength: 12)

            ZStack(alignment: .bottomTrailing) {
                Image(image)
                    .frame(width: 120, height: 120)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HomePhotoCardButton {}
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 160, height: 200)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    HomePhotoCard(
        eyebrow: "어딜 다녀왔더라?",
        title: "장소를 모르는 사진",
        backgroundColor: .orange400,
        image: .homeCard01
    )
    .padding()
    .background(.orange30)
}
