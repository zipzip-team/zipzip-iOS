//
//  ProfileImage.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct ProfileImage: View {
    let image: Image?
    var size: CGFloat = 24
    var isStroke: Bool = true

    init(image: Image? = nil, size: CGFloat = 24, isStroke: Bool = true) {
        self.image = image
        self.size = size
        self.isStroke = isStroke
    }

    var body: some View {
        Circle()
            .fill(.grey100)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(Circle())
            .overlay {
                if isStroke {
                    Circle()
                        .stroke(.grey50, lineWidth: 1)
                }
            }
            .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            ProfileImage(size: 24, isStroke: true)
            ProfileImage(size: 32, isStroke: true)
            ProfileImage(size: 24, isStroke: false)
            ProfileImage(size: 32, isStroke: false)
        }
        HStack(spacing: 20) {
            ProfileImage(image: Image(systemName: "person.fill"), size: 24, isStroke: true)
            ProfileImage(image: Image(systemName: "person.fill"), size: 32, isStroke: true)
            ProfileImage(image: Image(systemName: "person.fill"), size: 32, isStroke: false)
        }
    }
    .padding()
    .background(.grey950)
}
