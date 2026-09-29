import Foundation

enum OverdueAgeFormatter {
    /// Executes lateAgeToken.
    static func lateAgeToken(dueDate: Date, now: Date = Date(), calendar: Calendar = .current) -> String? {
        let startOfToday = calendar.startOfDay(for: now)
        guard dueDate < startOfToday else { return nil }

        let dueDay = calendar.startOfDay(for: dueDate)
        let overdueDays = max(1, calendar.dateComponents([.day], from: dueDay, to: startOfToday).day ?? 0)

        if overdueDays <= 6 {
            return "\(overdueDays)d"
        }

        let overdueWeeks = max(1, overdueDays / 7)
        return "\(overdueWeeks)w"
    }

    /// The age of a task from an earlier day, in the glossary's words:
    /// "3 days old", never "late" or "overdue".
    static func lateLabel(dueDate: Date, now: Date = Date(), calendar: Calendar = .current) -> String? {
        let startOfToday = calendar.startOfDay(for: now)
        guard dueDate < startOfToday else { return nil }

        let dueDay = calendar.startOfDay(for: dueDate)
        let days = max(1, calendar.dateComponents([.day], from: dueDay, to: startOfToday).day ?? 0)
        if days <= 6 {
            return days == 1 ? String(localized: "1 day old") : String(localized: "\(days) days old")
        }
        let weeks = max(1, days / 7)
        return weeks == 1 ? String(localized: "1 week old") : String(localized: "\(weeks) weeks old")
    }
}
