//
//  RoundedIconButtonItem.swift
//  zipzip-iOS
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct RoundedIconButtonItem: Identifiable {
    let id = UUID()
    let icon: ImageResource
    let action: () -> Void
}
