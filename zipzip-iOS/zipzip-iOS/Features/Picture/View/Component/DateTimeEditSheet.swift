//
//  DateTimeEditSheet.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/8/26.
//

import SwiftUI

struct DateTimeEditSheet: View {
    @Binding var date: Date
    let onCancel: () -> Void
    let onDone: () -> Void

    @State private var showTime = true

    private let timeAnchor = "timePicker"

    var body: some View {
        BottomSheet(
            leftItem: {
                BottomSheetCloseButton(action: onCancel)
            },
            rightItem: {
                headerButton(title: "완료", action: onDone)
            }
        ) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        PhotoCalendarView(selection: calendarSelection)
                            .background(.grey1000, in: .rect(cornerRadius: 12))

                        timeRow

                        if showTime {
                            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ko_KR"))
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity)
                                .background(.grey1000, in: .rect(cornerRadius: 12))
                                .id(timeAnchor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .onChange(of: showTime) { _, expanded in
                    guard expanded else { return }
                    withAnimation {
                        proxy.scrollTo(timeAnchor, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// 캘린더는 날짜(연·월·일)만 바꾸고 기존 시각(시·분)은 유지한다.
    private var calendarSelection: Binding<Date?> {
        Binding {
            date
        } set: { newValue in
            guard let newValue else { return }
            let calendar = Calendar.current
            let day = calendar.dateComponents([.year, .month, .day], from: newValue)
            let time = calendar.dateComponents([.hour, .minute, .second], from: date)
            var merged = DateComponents()
            merged.year = day.year
            merged.month = day.month
            merged.day = day.day
            merged.hour = time.hour
            merged.minute = time.minute
            merged.second = time.second
            if let combined = calendar.date(from: merged) {
                date = combined
            }
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

    private var timeRow: some View {
        HStack {
            Text("시간")
                .font(.b1_md)
                .foregroundStyle(.grey300)
            Spacer()
            Button {
                withAnimation { showTime.toggle() }
            } label: {
                Text(timeText)
                    .font(.b1_md)
                    .foregroundStyle(.white00)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.grey800, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var timeText: String {
        date.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).hour().minute())
    }
}

#Preview {
    DateTimeEditSheet(date: .constant(Date()), onCancel: {}, onDone: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.black)
}
