//
//  PhotoCalendarView.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/15/26.
//

import SwiftUI

/// 사진이 있는 날짜만 선택 가능한 커스텀 월간 캘린더.
/// `availableDays`에 없는 날짜는 회색으로 표시되고 탭이 막힌다.
/// 기본 시스템 캘린더처럼 이번 달 날짜만 노출하고, 월 전환 시 슬라이드 애니메이션을 준다.
struct PhotoCalendarView: View {
    @Binding var selection: Date?
    /// 선택 가능한 날짜 집합. `nil`이면 모든 날짜를 선택할 수 있다(날짜 편집 용도).
    let availableDays: Set<DateComponents>?

    @State private var visibleMonth: Date
    @State private var slideEdge: Edge = .trailing
    @State private var isMonthYearPickerShown = false

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let cellSize: CGFloat = 40
    private let rowSpacing: CGFloat = 8
    private let maxWeekCount = 6

    /// 주 수(5/6)와 무관하게 고정되는 날짜 영역 높이.
    private var gridHeight: CGFloat {
        CGFloat(maxWeekCount) * cellSize + CGFloat(maxWeekCount - 1) * rowSpacing
    }

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter
    }()

    init(selection: Binding<Date?>, availableDays: Set<DateComponents>? = nil) {
        self._selection = selection
        self.availableDays = availableDays
        let base = selection.wrappedValue ?? Date()
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let comps = calendar.dateComponents([.year, .month], from: base)
        self._visibleMonth = State(initialValue: calendar.date(from: comps) ?? base)
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
                .opacity(isMonthYearPickerShown ? 0 : 1)
            // 트랜지션이 걸린 calendarGrid를 안정적인 컨테이너로 감싸고,
            // 클립을 이 컨테이너(가로/세로 경계)에 적용해 슬라이드가 프레임 안에서만 보이게 한다.
            ZStack {
                calendarGrid
                    .contentShape(Rectangle())
                    .gesture(swipeGesture)
                    .opacity(isMonthYearPickerShown ? 0 : 1)
                    .allowsHitTesting(!isMonthYearPickerShown)

                monthYearPicker
                    .opacity(isMonthYearPickerShown ? 1 : 0)
                    .allowsHitTesting(isMonthYearPickerShown)
            }
            .frame(maxWidth: .infinity)
            .frame(height: gridHeight)
            .clipped()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMonthYearPickerShown.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(Self.monthTitleFormatter.string(from: visibleMonth))
                        .font(Typography.b1_sb.font)
                        .foregroundStyle(isMonthYearPickerShown ? Color.blue : .white00)
                    Image(.chevronRight)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.blue)
                        .rotationEffect(.degrees(isMonthYearPickerShown ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if !isMonthYearPickerShown {
                HStack(spacing: 24) {
                    navButton(.chevronLeft) { moveMonth(by: -1) }
                    navButton(.chevronRight) { moveMonth(by: 1) }
                }
                .transition(.opacity)
            }
        }
    }

    private var monthYearPicker: some View {
        HStack(spacing: 0) {
            Picker("연도", selection: yearSelection) {
                ForEach(yearRange, id: \.self) { year in
                    Text(verbatim: "\(year)년").tag(year)
                }
            }
            .pickerStyle(.wheel)

            Picker("월", selection: monthSelection) {
                ForEach(1 ... 12, id: \.self) { month in
                    Text(verbatim: "\(month)월").tag(month)
                }
            }
            .pickerStyle(.wheel)
        }
        .labelsHidden()
        .colorScheme(.dark)
    }

    private var yearRange: [Int] {
        let current = calendar.component(.year, from: Date())
        return Array((current - 80) ... (current + 10))
    }

    private var yearSelection: Binding<Int> {
        Binding {
            calendar.component(.year, from: visibleMonth)
        } set: { newYear in
            setVisibleMonth(year: newYear, month: calendar.component(.month, from: visibleMonth))
        }
    }

    private var monthSelection: Binding<Int> {
        Binding {
            calendar.component(.month, from: visibleMonth)
        } set: { newMonth in
            setVisibleMonth(year: calendar.component(.year, from: visibleMonth), month: newMonth)
        }
    }

    private func setVisibleMonth(year: Int, month: Int) {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        if let date = calendar.date(from: comps) {
            visibleMonth = date
        }
    }

    private func navButton(_ resource: ImageResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(resource)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.blue)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(Typography.b3_sb.font)
                    .foregroundStyle(.grey700)
                    .frame(maxWidth: .infinity, minHeight: 18)
            }
        }
    }

    /// 트랜지션은 안정적인 래퍼(`.frame`+`.clipped()`) 안쪽에서만 일어나도록 분리한다.
    private var calendarGrid: some View {
        monthGrid(for: visibleMonth)
            .id(visibleMonth)
            .transition(.push(from: slideEdge))
    }

    /// 주 수와 무관하게 항상 `gridHeight`에 딱 맞도록 행 간격을 계산한다.
    /// (`maxHeight: .infinity`를 쓰지 않으므로 트랜지션 중에도 프레임 밖으로 퍼지지 않는다.)
    private func monthGrid(for month: Date) -> some View {
        let weeks = weeks(for: month)
        let spacing = weeks.count > 1
            ? (gridHeight - CGFloat(weeks.count) * cellSize) / CGFloat(weeks.count - 1)
            : 0

        return VStack(spacing: spacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                weekRow(week)
            }
        }
        .frame(height: gridHeight, alignment: .top)
    }

    private func weekRow(_ week: [Date?]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(width: cellSize, height: cellSize)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let isSelectable = availableDays?.contains(comps) ?? true
        let isSelected = selection.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        return Text("\(calendar.component(.day, from: date))")
            .font(Typography.b1_md.font)
            .foregroundStyle(isSelectable || isSelected ? .white00 : .grey600)
            .frame(width: cellSize, height: cellSize)
            .background {
                if isSelected {
                    Circle().fill(.blue)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectable {
                    selection = date
                }
            }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                if value.translation.width < -40 {
                    moveMonth(by: 1)
                } else if value.translation.width > 40 {
                    moveMonth(by: -1)
                }
            }
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        slideEdge = value > 0 ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.25)) {
            visibleMonth = newMonth
        }
    }

    /// 이번 달 날짜만 채운 주 배열. 앞뒤 빈 칸은 `nil`로 남겨 인접 달 날짜를 노출하지 않는다.
    private func weeks(for month: Date) -> [[Date?]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month)
        else {
            return []
        }

        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0 ..< dayRange.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }

        return stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start ..< start + 7])
        }
    }
}
