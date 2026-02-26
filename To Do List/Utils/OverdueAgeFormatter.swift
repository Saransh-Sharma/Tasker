import Foundation

enum OverdueAgeFormatter {
    /// Executes lateLabel.
    static func lateLabel(dueDate: Date, now: Date = Date(), calendar: Calendar = .current) -> String? {
        let startOfToday = calendar.startOfDay(for: now)
        guard dueDate < startOfToday else { return nil }

        let dueDay = calendar.startOfDay(for: dueDate)
        let overdueDays = max(1, calendar.dateComponents([.day], from: dueDay, to: startOfToday).day ?? 0)

        if overdueDays <= 6 {
            return "\(overdueDays)d late"
        }

        let overdueWeeks = max(1, overdueDays / 7)
        return "\(overdueWeeks)w late"
    }
}
