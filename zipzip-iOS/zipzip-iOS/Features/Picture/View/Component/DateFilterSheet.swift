//
//  DateFilterSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct DateFilterSheet: View {
    @Binding var date: Date
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

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .colorScheme(.dark)
                    .padding(8)
                    .background(.grey1000, in: .rect(cornerRadius: 12))

                photosBlock
            }
            .padding(.horizontal, 16)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("날짜")
                .font(.t3_sb)
                .foregroundStyle(.white00)
            Text("사진을 찍은 날짜를 선택해 주세요.")
                .font(.b2_md)
                .foregroundStyle(.grey300)
        }
    }

    private var photosBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이 날의 사진들을 확인해보세요!")
                .font(.b2_md)
                .foregroundStyle(.white00)

            // TODO: 실제 선택 날짜의 사진으로 교체 (현재 더미 플레이스홀더)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0 ..< 6, id: \.self) { _ in
                        Color.grey200
                            .frame(width: 88, height: 88)
                    }
                }
            }
        }
    }
}

#Preview {
    DateFilterSheet(date: .constant(Date()), onDone: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black)
}
