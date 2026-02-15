//
//  WeeklyCalendarStripView.swift
//  Tasker
//
//  Swipeable weekly calendar strip with expandable month grid.
//  Sits on the backdrop, revealed when foredrop is pulled down.
//

import SwiftUI

// MARK: - Calendar Helpers

extension Calendar {
    func taskerStartOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func taskerDaysOfWeek(startingFrom weekStart: Date) -> [Date] {
        (0..<7).compactMap { self.date(byAdding: .day, value: $0, to: weekStart) }
    }

    func taskerDaysOfMonth(for date: Date) -> [Date?] {
        guard let range = self.range(of: .day, in: .month, for: date),
              let firstOfMonth = self.date(from: dateComponents([.year, .month], from: date))
        else { return [] }

        let firstWeekday = component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - self.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            if let date = self.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        // Pad to fill last row
        let remainder = days.count % 7
        if remainder > 0 {
            days.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return days
    }
}

// MARK: - Weekly Calendar Strip

struct WeeklyCalendarStripView: View {
    @Binding var selectedDate: Date
    let todayDate: Date

    @State private var displayedWeekStart: Date
    @State private var isExpanded: Bool = false
    @GestureState private var dragOffset: CGFloat = 0

    private let calendar = Calendar.current
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    init(selectedDate: Binding<Date>, todayDate: Date = Date()) {
        self._selectedDate = selectedDate
        self.todayDate = todayDate
        self._displayedWeekStart = State(initialValue: Calendar.current.taskerStartOfWeek(for: selectedDate.wrappedValue))
    }

    var body: some View {
        VStack(spacing: spacing.s4) {
            weekStripRow
                .gesture(weekSwipeGesture)

            if isExpanded {
                monthGridView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            expandChevron
        }
        .animation(TaskerAnimation.snappy, value: isExpanded)
        .onChange(of: selectedDate) { newDate in
            let newWeekStart = calendar.taskerStartOfWeek(for: newDate)
            if !calendar.isDate(newWeekStart, inSameDayAs: displayedWeekStart) {
                withAnimation(TaskerAnimation.snappy) {
                    displayedWeekStart = newWeekStart
                }
            }
        }
        .accessibilityIdentifier("home.weeklyCalendar")
    }

    // MARK: - Week Strip

    private var daysOfWeek: [Date] {
        calendar.taskerDaysOfWeek(startingFrom: displayedWeekStart)
    }

    private var weekStripRow: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.timeIntervalSince1970) { date in
                dayCell(date: date)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(TaskerAnimation.snappy) {
                            selectedDate = date
                        }
                        TaskerFeedback.selection()
                    }
            }
        }
        .padding(.vertical, spacing.s8)
    }

    private func dayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: todayDate)
        let dayNumber = calendar.component(.day, from: date)

        return VStack(spacing: 4) {
            Text(dayAbbreviation(date))
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                .textCase(.uppercase)

            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.tasker.accentPrimary)
                        .frame(width: 34, height: 34)
                } else if isToday {
                    Circle()
                        .stroke(Color.tasker.accentPrimary, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundColor(
                        isSelected
                            ? Color.tasker.accentOnPrimary
                            : isToday
                                ? Color.tasker.accentPrimary
                                : Color.tasker.textPrimary
                    )
            }
            .frame(width: 34, height: 34)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayAbbreviation(date)) \(dayNumber)\(isToday ? ", today" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("home.calendar.day.\(dayNumber)")
    }

    // MARK: - Month Grid

    private var monthGridView: some View {
        let monthDate = displayedWeekStart
        let days = calendar.taskerDaysOfMonth(for: monthDate)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return VStack(spacing: spacing.s4) {
            // Month/Year header
            Text(monthYearText(for: monthDate))
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, spacing.s4)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        monthDayCell(date: date)
                    } else {
                        Color.clear
                            .frame(height: 34)
                    }
                }
            }
        }
        .padding(.top, spacing.s4)
    }

    private func monthDayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: todayDate)
        let dayNumber = calendar.component(.day, from: date)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedWeekStart, toGranularity: .month)

        return Button {
            withAnimation(TaskerAnimation.snappy) {
                selectedDate = date
            }
            TaskerFeedback.selection()
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.tasker.accentPrimary)
                        .frame(width: 30, height: 30)
                } else if isToday {
                    Circle()
                        .stroke(Color.tasker.accentPrimary, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundColor(
                        isSelected
                            ? Color.tasker.accentOnPrimary
                            : !isCurrentMonth
                                ? Color.tasker.textQuaternary
                                : isToday
                                    ? Color.tasker.accentPrimary
                                    : Color.tasker.textPrimary
                    )
            }
            .frame(height: 34)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expand Chevron

    private var expandChevron: some View {
        Button {
            withAnimation(TaskerAnimation.snappy) {
                isExpanded.toggle()
            }
            TaskerFeedback.selection()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.tasker.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .frame(width: 32, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse to week view" : "Expand to month view")
        .accessibilityIdentifier("home.calendar.expandToggle")
    }

    // MARK: - Gestures

    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width < -threshold {
                    advanceWeek(by: 1)
                } else if value.translation.width > threshold {
                    advanceWeek(by: -1)
                }
            }
    }

    private func advanceWeek(by offset: Int) {
        guard let newStart = calendar.date(byAdding: .weekOfYear, value: offset, to: displayedWeekStart) else { return }
        withAnimation(TaskerAnimation.snappy) {
            displayedWeekStart = newStart
        }
        TaskerFeedback.selection()
    }

    // MARK: - Formatters

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func monthYearText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
