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

    @State private var showTime = false

    private let timeAnchor = "timePicker"

    var body: some View {
        BottomSheet(
            leftItem: {
                headerButton(title: "취소", action: onCancel)
            },
            rightItem: {
                headerButton(title: "완료", action: onDone)
            }
        ) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                            .colorScheme(.dark)

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
                    .padding(.vertical, 8)
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
