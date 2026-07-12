//
//  PhotoDetailImage.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import SwiftUI
import UIKit

struct PhotoDetailImage: View {
    let image: UIImage?
    let contentMode: ContentMode

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            }
    }
}
