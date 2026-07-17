//
//  TextInput.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/6/26.
//

import SwiftUI

struct TextInput: View {
    enum Style {
        case text
        case search
        case comment

        var height: CGFloat {
            switch self {
            case .text, .search: 52
            case .comment: 56
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .text, .search: 16
            case .comment: 12
            }
        }

        var showsSearchIcon: Bool {
            self == .search
        }

        var supportsClearButton: Bool {
            self != .comment
        }
    }

    @Binding private var text: String
    @FocusState private var isFocused: Bool

    private let placeholder: String
    private let style: Style
    private let maxLength: Int?

    init(
        _ placeholder: String = "입력",
        text: Binding<String>,
        style: Style = .text,
        maxLength: Int? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.style = style
        self.maxLength = maxLength
    }

    var body: some View {
        HStack(spacing: 8) {
            if style.showsSearchIcon {
                searchIcon
            }

            textField

            if showsClearButton {
                clearButton
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: style.height)
        .background(.grey100, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var showsClearButton: Bool {
        style.supportsClearButton && (isFocused || !text.isEmpty)
    }

    private var searchIcon: some View {
        Image(.search)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.grey800)
            .frame(width: 24, height: 24)
    }

    private var textField: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(Typography.b1_md.font)
                .foregroundStyle(.grey600)
        )
        .font(.b1_md)
        .foregroundStyle(.grey1000)
        .tint(.orange500)
        .focused($isFocused)
        .padding(.horizontal, 4)
        .onChange(of: text) { _, newValue in
            guard let maxLength, newValue.count > maxLength else { return }
            text = String(newValue.prefix(maxLength))
        }
    }

    private var clearButton: some View {
        Button {
            text = ""
        } label: {
            Image(.cancelSm)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.grey600)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("TextInput") {
    TextInputPreview()
        .padding(.horizontal, 16)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.black)
}

private struct TextInputPreview: View {
    @State private var searchText = ""
    @State private var filledSearchText = "장소 검색"
    @State private var text = ""
    @State private var filledText = "입력"
    @State private var comment = ""

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                TextInput("장소 검색", text: $searchText, style: .search)
                TextInput("장소 검색", text: $filledSearchText, style: .search)
            }
            .frame(width: 400)

            VStack(spacing: 12) {
                TextInput("입력", text: $text)
                TextInput("입력", text: $filledText)
            }
            .frame(width: 358)

            VStack(spacing: 12) {
                TextInput("메시지 입력", text: $comment, style: .comment)
            }
            .frame(width: 358)
        }
    }
}
