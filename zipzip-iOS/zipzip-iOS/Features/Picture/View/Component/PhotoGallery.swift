//
//  PhotoGallery.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoGallery: View {
    let sections: [PhotoSection]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 4
    )

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.b2_sb)
                        .foregroundStyle(.grey1000)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0 ..< section.count, id: \.self) { _ in
                            Color.grey200
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        PhotoGallery(sections: PhotoSection.sample)
            .padding(.horizontal, 16)
    }
}
