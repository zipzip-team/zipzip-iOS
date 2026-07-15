//
//  PhotoInfoEditView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct PhotoInfoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PhotoInfoEditViewModel
    @State private var isDismissing = false

    let metadata: PhotoMetadata
    private let onSuccessfulDismiss: () -> Void

    init(
        metadata: PhotoMetadata,
        localIdentifiers: [String],
        onSuccessfulDismiss: @escaping () -> Void = {}
    ) {
        self.metadata = metadata
        _viewModel = State(initialValue: PhotoInfoEditViewModel(localIdentifiers: localIdentifiers))
        self.onSuccessfulDismiss = onSuccessfulDismiss
    }

    var body: some View {
        ScrollView {
            PhotoInfoEditContent(metadata: metadata, viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, FloatingHeaderLayout.buttonHeight + 30)
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
            .init(id: "back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") {
                guard !isDismissing else { return }
                isDismissing = true
                Task {
                    if await viewModel.waitForPendingSaves() {
                        onSuccessfulDismiss()
                    }
                    dismiss()
                }
            }
        ])
        .opacity(0.9)
        .allowsHitTesting(!isDismissing)
    }
}

#Preview {
    PhotoInfoEditView(metadata: PhotoMetadata.samples[0], localIdentifiers: [])
}
