//
//  ShareAlbumCard.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct ShareAlbumCard: View {
    let thumbnail: Image?
    let title: String
    let date: Date
    let profileImages: [Image?]
    let memberCount: Int
    var isPressed: Bool = false

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. M. d"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                thumbnailView

                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(.t3_sb)
                            .foregroundStyle(.grey1000)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        HStack(spacing: 4) {
                            Image(.calendar)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.grey600)
                                .frame(width: 18, height: 18)
                            Text(dateText)
                                .font(.b2_md)
                                .foregroundStyle(.grey600)
                        }
                    }

                    HStack(spacing: 4) {
                        profileStack
                        Text("\(memberCount)명")
                            .font(.b2_md)
                            .foregroundStyle(.grey600)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(.chevronRight)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.grey800)
                .frame(width: 24, height: 24)
                .frame(width: 40, height: 40)
        }
        .padding(16)
        .background(isPressed ? .grey70 : .grey50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.grey100)
            .overlay {
                if let thumbnail {
                    thumbnail
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(width: 76, height: 76)
    }

    private var profileStack: some View {
        HStack(spacing: -8) {
            ForEach(Array(profileImages.prefix(4).enumerated()), id: \.offset) { _, image in
                ProfileImage(image: image, size: 24, isStroke: true)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ShareAlbumCard(
            thumbnail: nil,
            title: "집집팟",
            date: .now,
            profileImages: Array(repeating: Image(systemName: "person.fill"), count: 4),
            memberCount: 4
        )

        ShareAlbumCard(
            thumbnail: nil,
            title: "집집팟",
            date: .now,
            profileImages: Array(repeating: Image(systemName: "person.fill"), count: 4),
            memberCount: 4,
            isPressed: true
        )

        ShareAlbumCard(
            thumbnail: nil,
            title: "아주 긴 앨범 이름이 들어가면 어떻게 될까요 테스트",
            date: .now,
            profileImages: [Image(systemName: "person.fill")],
            memberCount: 1
        )
    }
    .padding()
}
