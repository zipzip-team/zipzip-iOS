//
//  PhotoThumbnail.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import SwiftUI
import UIKit

struct PhotoThumbnail: View {
    let image: UIImage?

    var body: some View {
        Color.grey200
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
    }
}
