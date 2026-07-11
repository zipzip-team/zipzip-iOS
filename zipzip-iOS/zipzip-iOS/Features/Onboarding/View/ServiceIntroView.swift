//
//  ServiceIntroView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI

struct ServiceIntroView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoSyncCoordinator.self) private var photoSync

    @State private var viewModel: ServiceIntroViewModel

    @MainActor
    init() {
        self.init(viewModel: ServiceIntroViewModel())
    }

    init(viewModel: ServiceIntroViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        OnboardingContainerView {
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Image(viewModel.currentPageContent.titleImage)

                    Text(viewModel.currentPageContent.description)
                        .font(.b1_md)
                        .foregroundStyle(Color(.grey400))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    ServiceIntroArtwork(
                        image: viewModel.currentPageContent.illustrationImage
                    )

                    ServiceIntroPageIndicator(
                        currentPage: viewModel.currentPage,
                        pageCount: viewModel.pageCount
                    )
                }

                Spacer()

                CommonButton(title: "다음", property1: .default) {
                    viewModel.handleNextButtonTap()
                }
            }
        }
        .onChange(of: viewModel.didReachEnd) { _, didReachEnd in
            guard didReachEnd else { return }
            router.push(photoSync.isFinished ? .deviceSelection : .deviceLoading)
        }
    }
}

#Preview {
    ServiceIntroView()
        .environment(Router())
        .environment(PhotoSyncCoordinator())
}

private struct ServiceIntroArtwork: View {
    let image: ImageResource?

    var body: some View {
        if let image {
            Image(image)
                .resizable()
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .padding(.horizontal, -16)
        } else {
            Rectangle()
                .fill(.grey100)
                .frame(maxWidth: .infinity)
                .frame(height: 420)
        }
    }
}

private struct ServiceIntroPageIndicator: View {
    let currentPage: Int
    let pageCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0 ..< pageCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(index == currentPage ? .orange500 : .grey300)
                    .frame(
                        width: index == currentPage ? 60 : 16,
                        height: index == currentPage ? 10 : 6
                    )
                    .animation(.easeInOut(duration: 0.35), value: currentPage)
            }
        }
        .frame(width: 144, height: 10)
    }
}
