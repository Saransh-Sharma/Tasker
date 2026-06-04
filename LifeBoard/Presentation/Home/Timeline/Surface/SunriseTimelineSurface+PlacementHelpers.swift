import SwiftUI

extension SunriseTimelineSurface {
    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var rendererMode: SunriseTimelineRendererMode {
        SunriseTimelineRendererPolicy.mode(
            layoutClass: layoutClass,
            dayLayoutMode: snapshot.day.layoutMode,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    var suggestedPlacementTime: Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(snapshot.selectedDate),
           snapshot.day.currentTime > snapshot.day.wakeAnchor.time,
           snapshot.day.currentTime < snapshot.day.sleepAnchor.time {
            return snapshot.day.currentTime
        }
        return snapshot.day.wakeAnchor.time
    }

    var hasMixedTimedOverlap: Bool {
        let timedItems = snapshot.day.timedItems
            .filter { $0.isAllDay == false }
            .compactMap { item -> (source: TimelinePlanItemSource, start: Date, end: Date)? in
                guard let start = item.startDate, let end = item.endDate, end > start else { return nil }
                return (item.source, start, end)
            }
            .sorted { lhs, rhs in
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.end < rhs.end
            }

        for index in timedItems.indices {
            let candidate = timedItems[index]
            for other in timedItems[timedItems.index(after: index)...] {
                guard other.start < candidate.end else { break }
                if other.source != candidate.source {
                    return true
                }
            }
        }
        return false
    }
}
