//
//  ActionBarItem.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct ActionBarItem: Identifiable {
    let id = UUID()
    let icon: ImageResource?
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    init(icon: ImageResource? = nil, title: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }
}
