//
//  DateFilterSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct DateFilterSheet: View {
    @Binding var date: Date?
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
            VStack(alignment: .leading, spacing: 20) {
                MultiDatePicker("", selection: dateSelection)
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

    private var dateSelection: Binding<Set<DateComponents>> {
        Binding {
            guard let date else { return [] }
            return [dateComponents(from: date)]
        } set: { newValue in
            let previousValue = date.map { Set([dateComponents(from: $0)]) } ?? []
            let selectedComponents = newValue.subtracting(previousValue).first ?? newValue.first
            date = selectedComponents.flatMap { Calendar.autoupdatingCurrent.date(from: $0) }
        }
    }

    private func dateComponents(from date: Date) -> DateComponents {
        Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
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
    DateFilterSheet(date: .constant(Date()), onReset: {}, onDone: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black)
}
