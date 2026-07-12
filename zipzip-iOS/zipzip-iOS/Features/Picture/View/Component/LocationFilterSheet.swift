//
//  LocationFilterSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct LocationFilterSheet: View {
    let locations: [String]
    @Binding var selected: String
    let onReset: () -> Void
    let onDone: () -> Void

    var body: some View {
        BottomSheet(
            leftItem: {
                headerButton(title: "초기화", action: onReset)
            },
            rightItem: {
                headerButton(title: "완료", action: onDone)
            }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(locations, id: \.self) { location in
                        TextMetadataChip(
                            title: location,
                            isSelected: selected == location
                        ) {
                            selected = location
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func headerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.b1_sb)
                .foregroundStyle(.white00)
                .frame(width: 72, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LocationFilterSheet(
        locations: PhotoFilterOptions.sample.locations,
        selected: .constant("도쿄"),
        onReset: {},
        onDone: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
