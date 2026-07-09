//
//  MyPageViewModel.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class MyPageViewModel {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    func url(for link: MyPageLink) -> URL {
        link.url
    }
}
