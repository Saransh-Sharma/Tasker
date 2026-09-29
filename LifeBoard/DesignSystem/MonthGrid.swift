import SwiftUI

/// A seven-column month, as a calendar reads: weekday header, leading blanks
/// for the first week, then one cell per day. The cell is the caller's; this
/// only owns the geometry, the header, and the month title.
///
/// Extracted for Focus history and the Journal calendar, which previously
/// each had a private grid (`WeeklyCalendarStripView.monthGridView`,
/// `HabitCalendarSection`) with nothing shared but the arithmetic.
struct MonthGrid<Cell: View>: View {
    let month: Date
    var calendar: Calendar = .current
    @ViewBuilder let cell: (Date) -> Cell

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    /// Dates for the grid, `nil` where the first week is padded.
    private var slots: [Date?] {
        guard let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let padding: [Date?] = Array(repeating: nil, count: leading)
        let days: [Date?] = (0..<dayCount).map { calendar.date(byAdding: .day, value: $0, to: monthStart) }
        return padding + days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .lifeboardFont(.caption2)
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                if let date = slot {
                    cell(date)
                } else {
                    Color.clear.frame(height: 1).accessibilityHidden(true)
                }
            }
        }
    }
}
