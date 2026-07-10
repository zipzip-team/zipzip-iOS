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
    let accessibilityLabel: String
    let action: () -> Void
}
