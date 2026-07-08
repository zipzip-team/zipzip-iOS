//
//  ServiceIntroView.swift
//  zipzip-iOS
//
//  Created by kyooonnnggg on 7/8/26.
//

import SwiftUI

struct ServiceIntroView: View {
    @Environment(Router.self) private var router

    @State private var currentPage = 0

    private let pages = ServiceIntroPage.pages

    var body: some View {
        OnboardingContainerView {
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Image(currentPageContent.titleImage)

                    Text(currentPageContent.description)
                        .font(.b1_md)
                        .foregroundStyle(Color(.grey400))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    Rectangle()
                        .fill(.grey100)
                        .frame(maxWidth: .infinity, maxHeight: 420)

                    ServiceIntroPageIndicator(currentPage: currentPage, pageCount: pages.count)
                }

                Spacer()

                CommonButton(title: "다음", property1: .default) {
                    handleNextButtonTap()
                }
            }
        }
    }

    private var currentPageContent: ServiceIntroPage {
        pages[currentPage]
    }

    private func handleNextButtonTap() {
        if currentPage < pages.count - 1 {
            currentPage += 1
        } else {
            router.push(.onboardingComplete)
        }
    }
}

#Preview {
    ServiceIntroView()
        .environment(Router())
}

private struct ServiceIntroPageIndicator: View {
    let currentPage: Int
    let pageCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0 ..< pageCount, id: \.self) { index in
                Rectangle()
                    .fill(index == currentPage ? .orange500 : .grey300)
                    .frame(
                        width: index == currentPage ? 60 : 16,
                        height: index == currentPage ? 10 : 6
                    )
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
        .frame(width: 144, height: 10)
    }
}
