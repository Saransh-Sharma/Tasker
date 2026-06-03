import SwiftUI

struct TimelineDayStablePresentation {
    let projection: TimelineDayProjection
    let calendar: Calendar

    init(projection: TimelineDayProjection, calendar: Calendar = .current) {
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineStablePresentationBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        self.projection = projection
        self.calendar = calendar
    }
}
