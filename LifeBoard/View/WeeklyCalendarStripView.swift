//
//  WeeklyCalendarStripView.swift
//  LifeBoard
//
//  Swipeable weekly calendar strip with expandable month grid.
//  Sits on the backdrop, revealed when foredrop is pulled down.
//

 import SwiftUI

// MARK: - Calendar Helpers

extension Calendar {
    /// Executes lifeboardStartOfWeek.
    func lifeboardStartOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    /// Executes lifeboardDaysOfWeek.
    func lifeboardDaysOfWeek(startingFrom weekStart: Date) -> [Date] {
        (0..<7).compactMap { self.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// Executes lifeboardDaysOfMonth.
    func lifeboardDaysOfMonth(for date: Date) -> [Date?] {
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

@MainActor
private struct WeeklyCalendarDayCell: View, Equatable {
    let dayLabel: String
    let dayNumber: Int
    let isSelected: Bool
    let isToday: Bool

    nonisolated static func == (lhs: WeeklyCalendarDayCell, rhs: WeeklyCalendarDayCell) -> Bool {
        lhs.dayLabel == rhs.dayLabel &&
        lhs.dayNumber == rhs.dayNumber &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isToday == rhs.isToday
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayLabel)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary.opacity(0.7))
                .textCase(.uppercase)

            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.lifeboard.accentPrimary)
                        .frame(width: 34, height: 34)
                } else if isToday {
                    Circle()
                        .stroke(Color.lifeboard.accentOnPrimary.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(
                        isSelected
                            ? Color.lifeboard.accentOnPrimary
                            : isToday
                                ? Color.lifeboard.accentOnPrimary
                                : Color.lifeboard.textPrimary
                    )
            }
            .frame(width: 34, height: 34)
        }
    }
}

struct WeeklyCalendarStripView: View {
    @Binding var selectedDate: Date
    let todayDate: Date

    @State private var displayedWeekStart: Date
    @State private var isExpanded: Bool = false
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private let calendar = Calendar.current
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "EEE"
        return formatter
    }()
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// Initializes a new instance.
    init(selectedDate: Binding<Date>, todayDate: Date = Date()) {
        self._selectedDate = selectedDate
        self.todayDate = todayDate
        self._displayedWeekStart = State(initialValue: Calendar.current.lifeboardStartOfWeek(for: selectedDate.wrappedValue))
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
        .animation(LifeBoardAnimation.snappy, value: isExpanded)
        .onChange(of: selectedDate) { _, newDate in
            let newWeekStart = calendar.lifeboardStartOfWeek(for: newDate)
            if !calendar.isDate(newWeekStart, inSameDayAs: displayedWeekStart) {
                withAnimation(LifeBoardAnimation.snappy) {
                    displayedWeekStart = newWeekStart
                }
            }
        }
        .accessibilityIdentifier("home.weeklyCalendar")
    }

    // MARK: - Week Strip

    private var daysOfWeek: [Date] {
        calendar.lifeboardDaysOfWeek(startingFrom: displayedWeekStart)
    }

    private var weekStripRow: some View {
        HStack(spacing: spacing.s8) {
            calendarNavButton(systemImage: "chevron.left", label: "Previous week") {
                advanceWeek(by: -1)
            }

            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.timeIntervalSince1970) { date in
                    Button {
                        withAnimation(LifeBoardAnimation.snappy) {
                            selectedDate = date
                        }
                        LifeBoardFeedback.selection()
                    } label: {
                        dayCell(date: date)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .gesture(weekSwipeGesture)

            calendarNavButton(systemImage: "chevron.right", label: "Next week") {
                advanceWeek(by: 1)
            }
        }
        .padding(.vertical, spacing.s8)
    }

    private func calendarNavButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .frame(width: 30, height: 30)
                .background(Color.lifeboard.surfaceSecondary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Executes dayCell.
    private func dayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: todayDate)
        let dayNumber = calendar.component(.day, from: date)
        let dayLabel = dayAbbreviation(date)

        return WeeklyCalendarDayCell(
            dayLabel: dayLabel,
            dayNumber: dayNumber,
            isSelected: isSelected,
            isToday: isToday
        )
        .equatable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayLabel) \(dayNumber)\(isToday ? ", today" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("home.calendar.day.\(dayNumber)")
    }

    // MARK: - Month Grid

    private var monthGridView: some View {
        let monthDate = displayedWeekStart
        let days = calendar.lifeboardDaysOfMonth(for: monthDate)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return VStack(spacing: spacing.s4) {
            // Month/Year header
            Text(monthYearText(for: monthDate))
                .font(.lifeboard(.headline))
                .foregroundColor(Color.lifeboard.textPrimary)
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

    /// Executes monthDayCell.
    private func monthDayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: todayDate)
        let dayNumber = calendar.component(.day, from: date)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedWeekStart, toGranularity: .month)

        return Button {
            withAnimation(LifeBoardAnimation.snappy) {
                selectedDate = date
            }
            LifeBoardFeedback.selection()
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.lifeboard.accentPrimary)
                        .frame(width: 30, height: 30)
                } else if isToday {
                    Circle()
                        .stroke(Color.lifeboard.accentPrimary, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundColor(
                        isSelected
                            ? Color.lifeboard.accentOnPrimary
                            : !isCurrentMonth
                                ? Color.lifeboard.textQuaternary
                                : isToday
                                    ? Color.lifeboard.accentPrimary
                                    : Color.lifeboard.textPrimary
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
            withAnimation(LifeBoardAnimation.snappy) {
                isExpanded.toggle()
            }
            LifeBoardFeedback.selection()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.lifeboard.textTertiary)
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

    /// Executes advanceWeek.
    private func advanceWeek(by offset: Int) {
        guard let newStart = calendar.date(byAdding: .weekOfYear, value: offset, to: displayedWeekStart) else { return }
        withAnimation(LifeBoardAnimation.snappy) {
            displayedWeekStart = newStart
        }
        LifeBoardFeedback.selection()
    }

    // MARK: - Formatters

    /// Executes dayAbbreviation.
    private func dayAbbreviation(_ date: Date) -> String {
        Self.weekdayFormatter.string(from: date).uppercased()
    }

    /// Executes monthYearText.
    private func monthYearText(for date: Date) -> String {
        Self.monthYearFormatter.string(from: date)
    }
}
