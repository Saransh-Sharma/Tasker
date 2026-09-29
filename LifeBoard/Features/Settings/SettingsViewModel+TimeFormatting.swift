import Foundation

extension SettingsViewModel {
    func formattedTime(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    var timelineWindDownOccursNextDay: Bool {
        minutesSinceMidnight(
            hour: workspacePreferences.timelineWindDownHour,
            minute: workspacePreferences.timelineWindDownMinute
        ) <= minutesSinceMidnight(
            hour: workspacePreferences.timelineRiseAndShineHour,
            minute: workspacePreferences.timelineRiseAndShineMinute
        )
    }

    private func minutesSinceMidnight(hour: Int, minute: Int) -> Int {
        max(0, min(23, hour)) * 60 + max(0, min(59, minute))
    }
}
