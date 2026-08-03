import Foundation

/// The hours the user actually works, plus which day their week starts on.
///
/// A `WorkingHoursProfile` drives every capacity number, free-window projection,
/// and overload signal in Plan and on Home — and until now the only way to reach
/// it was an unlabelled slider icon in the Plan toolbar. Everyone silently ran on
/// a Mon–Fri 08:00–18:00 default, which is wrong for anyone on shifts.
///
/// Deliberately coarse: weekdays and weekend, not seven independent rows. The
/// step is prefilled with the same defaults the app already assumed, so accepting
/// is one tap and editing is opt-in.
struct OnboardingDayShapeDraft: Codable, Equatable {
    var weekdayStartMinute: Int
    var weekdayEndMinute: Int
    var weekendStartMinute: Int
    var weekendEndMinute: Int
    var worksWeekends: Bool
    var weekStartsOn: Weekday

    init(
        weekdayStartMinute: Int = 8 * 60,
        weekdayEndMinute: Int = 18 * 60,
        weekendStartMinute: Int = 9 * 60,
        weekendEndMinute: Int = 14 * 60,
        worksWeekends: Bool = true,
        weekStartsOn: Weekday = .monday
    ) {
        self.weekdayStartMinute = weekdayStartMinute
        self.weekdayEndMinute = weekdayEndMinute
        self.weekendStartMinute = weekendStartMinute
        self.weekendEndMinute = weekendEndMinute
        self.worksWeekends = worksWeekends
        self.weekStartsOn = weekStartsOn
    }

    /// Weekday indices follow `Calendar`: 1 is Sunday, 7 is Saturday.
    func makeProfile(id: UUID = UUID(), now: Date = Date()) -> WorkingHoursProfile {
        var intervals: [Int: [WorkingHoursInterval]] = [:]
        let weekday = WorkingHoursInterval(
            startMinute: weekdayStartMinute,
            endMinute: max(weekdayStartMinute, weekdayEndMinute)
        )
        for index in 2...6 { intervals[index] = [weekday] }

        if worksWeekends {
            let weekend = WorkingHoursInterval(
                startMinute: weekendStartMinute,
                endMinute: max(weekendStartMinute, weekendEndMinute)
            )
            intervals[1] = [weekend]
            intervals[7] = [weekend]
        }

        return WorkingHoursProfile(
            id: id,
            name: "My hours",
            intervalsByWeekday: intervals,
            bufferDuration: 30 * 60,
            isDefault: true,
            updatedAt: now
        )
    }

    /// "8:00 AM" style, localised, for the step's summary line.
    static func label(forMinute minute: Int, calendar: Calendar = .current) -> String {
        var components = DateComponents()
        components.hour = minute / 60
        components.minute = minute % 60
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
