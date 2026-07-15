//
//  CenteredStateContent.swift
//  zipzip-iOS
//

import SwiftUI

struct CenteredStateContent<Artwork: View, Message: View, Action: View>: View {
    private let messageSpacing: CGFloat
    private let actionSpacing: CGFloat
    private let artwork: Artwork
    private let message: Message
    private let action: Action

    init(
        messageSpacing: CGFloat = 8,
        actionSpacing: CGFloat = 32,
        @ViewBuilder artwork: () -> Artwork,
        @ViewBuilder message: () -> Message,
        @ViewBuilder action: () -> Action
    ) {
        self.messageSpacing = messageSpacing
        self.actionSpacing = actionSpacing
        self.artwork = artwork()
        self.message = message()
        self.action = action()
    }

    var body: some View {
        VStack(spacing: 0) {
            artwork

            message
                .padding(.top, messageSpacing)

            action
                .padding(.top, actionSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
