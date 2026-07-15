//
//  KeyboardPrewarmer.swift
//  zipzip-iOS
//
//  Created by SeongHwan on 7/14/26.
//

import UIKit

@MainActor
enum KeyboardPrewarmer {
    private static var hasPrewarmed = false

    static func prewarm() {
        guard !hasPrewarmed else { return }

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else {
            return
        }

        hasPrewarmed = true

        let field = UITextField(frame: .zero)
        field.alpha = 0
        window.addSubview(field)
        field.becomeFirstResponder()
        field.resignFirstResponder()
        field.removeFromSuperview()
    }
}
