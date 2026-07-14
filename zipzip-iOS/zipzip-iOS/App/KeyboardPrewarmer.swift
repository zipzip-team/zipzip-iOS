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
    private static var field: UITextField?
    private static var observer: NSObjectProtocol?

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
        Self.field = field

        Self.observer = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { warmInputThenFinish() }
        }

        field.becomeFirstResponder()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            MainActor.assumeIsolated { finish() }
        }
    }

    private static func warmInputThenFinish() {
        if let field = field {
            field.insertText("a")
            field.deleteBackward()
        }

        finish()
    }

    private static func finish() {
        guard let field = Self.field else { return }

        if let observer = Self.observer {
            NotificationCenter.default.removeObserver(observer)
            Self.observer = nil
        }

        field.resignFirstResponder()
        field.removeFromSuperview()
        Self.field = nil
    }
}
