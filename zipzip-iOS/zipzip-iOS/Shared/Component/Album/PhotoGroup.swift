//
//  PhotoGroup.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoGroup: View {
    var body: some View {
        ZStack {
            PhotoItem()
                .frame(width: 100, height: 80)

            PhotoItem()
                .frame(width: 100, height: 80)
                .rotationEffect(.degrees(8))

            PhotoItem()
                .frame(width: 100, height: 80)
                .rotationEffect(.degrees(-10))
        }
        .frame(width: 112, height: 96)
    }
}

#Preview {
    PhotoGroup()
        .padding()
        .background(.grey50)
}
