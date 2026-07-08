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
                        ForEach(locations, id: \.self) { location in
                            LocationMetadataChip(
                                title: location,
                                isSelected: selected == location
                            ) {
                                selected = location
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
        VStack(alignment: .leading, spacing: 4) {
            Text("장소")
                .font(.t3_sb)
                .foregroundStyle(.white00)
            Text("사진을 많이 찍은 장소를 기준으로 추천해요.")
                .font(.b2_md)
                .foregroundStyle(.grey300)
        }
    }
}

#Preview {
    LocationFilterSheet(
        locations: PhotoFilterOptions.sample.locations,
        selected: .constant("도쿄"),
        onDone: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(.black)
}
