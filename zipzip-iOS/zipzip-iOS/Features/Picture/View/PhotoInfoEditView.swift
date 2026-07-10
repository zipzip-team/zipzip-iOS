//
//  PhotoInfoEditView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoInfoEditView: View {
    @Environment(\.dismiss) private var dismiss

    let metadata: PhotoMetadata

    var body: some View {
        ScrollView {
            PhotoInfoEditContent(metadata: metadata)
                .padding(.horizontal, 16)
                .padding(.top, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
        }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") { dismiss() }
        ])
        .opacity(0.9)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

#Preview {
    PhotoInfoEditView(metadata: PhotoMetadata.samples[0])
}
