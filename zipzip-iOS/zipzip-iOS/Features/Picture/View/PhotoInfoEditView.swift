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
    let localIdentifiers: [String]

    var body: some View {
        ScrollView {
            PhotoInfoEditContent(metadata: metadata, localIdentifiers: localIdentifiers)
                .padding(.horizontal, 16)
                .padding(.top, 78)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.orange30.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            FloatingHeader(.leading) {
                backButton
            }
        }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") { dismiss() }
        ])
        .opacity(0.9)
    }
}

#Preview {
    PhotoInfoEditView(metadata: PhotoMetadata.samples[0], localIdentifiers: [])
}
