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
    @State private var isSaveFailureAlertPresented = false

    let metadata: PhotoMetadata
    private let onSuccessfulDismiss: () -> Void

    init(
        metadata: PhotoMetadata,
        viewModel: PhotoInfoEditViewModel,
        onSuccessfulDismiss: @escaping () -> Void = {}
    ) {
        self.metadata = metadata
        _viewModel = State(initialValue: viewModel)
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
        .alert("변경사항을 저장하지 못했어요.", isPresented: $isSaveFailureAlertPresented) {
            Button("계속 편집", role: .cancel) {}
            Button("나가기", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("입력한 정보가 저장되지 않았어요.")
        }
    }

    private var backButton: some View {
        RoundedIconButton(items: [
            .init(id: "back", icon: .chevronLeft, accessibilityLabel: "뒤로가기") {
                guard !isDismissing else { return }
                isDismissing = true
                Task {
                    let hasChanges = await viewModel.waitForPendingSaves()
                    guard !viewModel.hasSaveFailure else {
                        isDismissing = false
                        isSaveFailureAlertPresented = true
                        return
                    }
                    if hasChanges {
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
    PhotoInfoEditView(
        metadata: PhotoMetadata.samples[0],
        viewModel: PhotoInfoEditViewModel()
    )
}
