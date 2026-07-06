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
    let action: () -> Void

    init(icon: ImageResource? = nil, title: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }
}
