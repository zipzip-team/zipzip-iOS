//
//  ServiceIntroViewModel.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import Observation

@MainActor
@Observable
final class ServiceIntroViewModel {
    private let pages: [ServiceIntroPage]

    var currentPage = 0
    var showsOnboardingCompleteView = false

    init(pages: [ServiceIntroPage] = ServiceIntroPage.pages) {
        self.pages = pages
    }

    var currentPageContent: ServiceIntroPage {
        pages[currentPage]
    }

    var pageCount: Int {
        pages.count
    }

    func handleNextButtonTap() {
        if currentPage < pageCount - 1 {
            currentPage += 1
        } else {
            showsOnboardingCompleteView = true
        }
    }
}
