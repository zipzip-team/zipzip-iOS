//
//  BottomSheetAlert.swift
//  zipzip-iOS
//
//  Created by mansuiki on 7/7/26.
//

import SwiftUI

struct BottomSheetAlert: View {
    private let title: String
    private let message: String
    private let secondaryTitle: String?
    private let primaryTitle: String
    private let onSecondaryTap: () -> Void
    private let onPrimaryTap: () -> Void

    init(
        title: String,
        message: String,
        secondaryTitle: String? = nil,
        primaryTitle: String,
        onSecondaryTap: @escaping () -> Void = {},
        onPrimaryTap: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.secondaryTitle = secondaryTitle
        self.primaryTitle = primaryTitle
        self.onSecondaryTap = onSecondaryTap
        self.onPrimaryTap = onPrimaryTap
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.t2_sb)
                .foregroundStyle(.white00)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .frame(alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.top, 49)

            Text(message)
                .font(.b2_md)
                .foregroundStyle(.grey400)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .frame(alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack(spacing: 0) {
                if let secondaryTitle {
                    CommonButton(
                        title: secondaryTitle,
                        property1: .secondary,
                        action: onSecondaryTap
                    )

                    Spacer(minLength: 16)
                }

                CommonButton(
                    title: primaryTitle,
                    property1: .cta,
                    action: onPrimaryTap
                )
            }
            .padding(.top, 44)
            .padding(.horizontal, 16)
            .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity)
        .background(.grey950, in: bottomSheetAlertShape)
    }
}

private var bottomSheetAlertShape: some Shape {
    UnevenRoundedRectangle(
        cornerRadii: .init(
            topLeading: 32,
            bottomLeading: 0,
            bottomTrailing: 0,
            topTrailing: 32
        ),
        style: .continuous
    )
}

#Preview("BottomSheetAlert") {
    BottomSheetAlert(
        title: "사진을 완전히 삭제할까요,\n아니면 사진집에서만 제거할까요?",
        message: "사진집에서 제거된 사진은 갤러리에 남아있어요",
        secondaryTitle: "삭제",
        primaryTitle: "사진집에서 제거"
    )
    .frame(width: 390)
    .frame(height: 290)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
