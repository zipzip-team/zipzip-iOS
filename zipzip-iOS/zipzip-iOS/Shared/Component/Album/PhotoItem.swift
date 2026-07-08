//
//  PhotoItem.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoItem: View {
    private let cornerRadius: CGFloat = 4

    let image: Image?

    init(image: Image? = nil) {
        self.image = image
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.grey500)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white00, lineWidth: 2)
            }
    }
}

#Preview {
    HStack(spacing: 12) {
        PhotoItem()
        PhotoItem(image: Image(systemName: "photo"))
    }
    .frame(height: 80)
    .padding()
    .background(.grey200)
}
