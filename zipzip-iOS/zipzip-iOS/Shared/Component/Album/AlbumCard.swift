//
//  AlbumCard.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct AlbumCard: View {
    let name: String
    let count: Int
    var state: AlbumFolderState = .plain
    var nameColorOverride: Color? = nil
    var thumbnailLocalIdentifiers: [String]? = nil

    var body: some View {
        VStack(spacing: 8) {
            AlbumFolder(state: state) {
                PhotoGroup(localIdentifiers: thumbnailLocalIdentifiers)
            }

            VStack(spacing: 0) {
                Text(name)
                    .font(.b2_sb)
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(count)")
                    .font(.b3_md)
                    .foregroundStyle(.grey600)
            }
            .frame(width: 134)
        }
        .frame(maxWidth: 170)
    }

    private var nameColor: Color {
        switch state {
        case .highlighted, .selected:
            return Color.orange500
        default:
            return nameColorOverride ?? Color.grey950
        }
    }
}

#Preview {
    HStack(alignment: .top, spacing: 16) {
        AlbumCard(name: "우리 가족", count: 678)
        AlbumCard(name: "동아리 앨범", count: 45, state: .selected(count: 22))
    }
    .padding()
    .background(.orange30)
}
