import SwiftUI

func timelineSuggestedAddDate(for gap: TimelineGap, now: Date, calendar: Calendar = .current) -> Date {
    guard gap.startDate <= now, now < gap.endDate else {
        return gap.startDate
    }

    let quarterHour: TimeInterval = 15 * 60
    let roundedInterval = ceil(now.timeIntervalSinceReferenceDate / quarterHour) * quarterHour
    let roundedDate = Date(timeIntervalSinceReferenceDate: roundedInterval)
    let latestInsideGap = gap.endDate.addingTimeInterval(-60)
    return min(max(roundedDate, gap.startDate), latestInsideGap)
}
