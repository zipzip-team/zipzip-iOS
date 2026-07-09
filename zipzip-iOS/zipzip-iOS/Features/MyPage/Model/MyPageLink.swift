//
//  MyPageLink.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

import Foundation

enum MyPageLink {
    case appInfo
    case privacyPolicy
    case support

    var url: URL? {
        switch self {
        case .appInfo:
            URL(string: "https://second-clove-198.notion.site/3985127da86b8085929ec179f2d880c6")
        case .privacyPolicy:
            URL(string: "https://second-clove-198.notion.site/3985127da86b801eb16dcdac262a968f")
        case .support:
            URL(string: "https://second-clove-198.notion.site/3985127da86b808ea73bcf25ecfa535e")
        }
    }
}
