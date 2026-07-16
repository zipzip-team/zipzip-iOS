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

    init(name: String?, size: CGFloat = 24, isStroke: Bool = true) {
        self.init(image: Self.avatar(for: name), size: size, isStroke: isStroke)
    }

    var body: some View {
        Circle()
            .fill(.grey100)
            .frame(width: size, height: size)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }
            }
            .overlay {
                if isStroke {
                    Circle()
                        .stroke(.grey50, lineWidth: 1)
                }
            }
    }
}

extension ProfileImage {
    private static let avatars: [ImageResource] = [
        .profile01, .profile02, .profile03, .profile04, .profile05, .profile06,
        .profile07, .profile08, .profile09, .profile10, .profile11, .profile12
    ]

    static func avatar(for name: String?) -> Image? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        var hash: UInt64 = 5381
        for byte in trimmed.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return Image(avatars[Int(hash % UInt64(avatars.count))])
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
