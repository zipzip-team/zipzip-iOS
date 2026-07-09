//
//  EtcFilterSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/9/26.
//

import SwiftUI

struct EtcFilterSheet: View {
    let items: [String]
    @Binding var selected: String
    let onDone: () -> Void

    var body: some View {
        BottomSheet(rightItem: {
            Button(action: onDone) {
                Text("완료")
                    .font(.b1_sb)
                    .foregroundStyle(.white00)
                    .frame(width: 72, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }) {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            TextMetadataChip(
                                title: item,
                                isSelected: selected == item
                            ) {
                                selected = item
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var titleBlock: some View {
        Text("기타")
            .font(.t3_sb)
            .foregroundStyle(.white00)
    }
}

#Preview {
    EtcFilterSheet(
        items: PhotoFilterOptions.sample.etcItems,
        selected: .constant("장소 정보 없음"),
        onDone: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
