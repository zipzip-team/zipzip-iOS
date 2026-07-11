//
//  StaticButtonStyle.swift
//  zipzip-iOS
//
//  Created by Codex on 7/12/26.
//

import SwiftUI

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .transaction { transaction in
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
    }
}
