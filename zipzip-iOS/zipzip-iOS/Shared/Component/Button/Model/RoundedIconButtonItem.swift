//
//  RoundedIconButtonItem.swift
//  zipzip-iOS
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct RoundedIconButtonItem: Identifiable {
    let id: String
    let icon: ImageResource
    let accessibilityLabel: String?
    let action: () -> Void

    init(
        id: String,
        icon: ImageResource,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
