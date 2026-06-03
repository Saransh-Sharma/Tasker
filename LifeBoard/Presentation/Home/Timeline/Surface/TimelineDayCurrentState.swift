import SwiftUI

struct TimelineDayCurrentState {
    let now: Date
    let dayRelation: TimelineDayRelation
    let currentBoundaryDate: Date?
    let currentTintHex: String?
    let activeGapID: String?

    init(stable: TimelineDayStablePresentation, now: Date) {
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineCurrentStateBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        let projection = stable.projection
        let calendar = stable.calendar
        self.now = now
        let selectedDay = calendar.startOfDay(for: projection.date)
        let today = calendar.startOfDay(for: now)
        if selectedDay < today {
            dayRelation = .past
        } else if selectedDay > today {
            dayRelation = .future
        } else {
            dayRelation = .today
        }

        let sortedItems = projection.allTimedItems
        let sortedGaps = projection.actionableGaps

        let currentItem = sortedItems.first(where: { item in
            guard let start = item.startDate, let end = item.endDate, item.isComplete == false else { return false }
            return start <= now && now < end
        })

        let activeGap = currentItem == nil && dayRelation == .today
            ? sortedGaps.first(where: { $0.startDate <= now && now < $0.endDate })
            : nil

        currentBoundaryDate = dayRelation == .today ? min(max(now, projection.wakeAnchor.time), projection.sleepAnchor.time) : nil
        currentTintHex = currentItem?.tintHex
            ?? projection.allTimedItems.first(where: { $0.isComplete && $0.tintHex != nil })?.tintHex
        activeGapID = activeGap?.id
    }
}
