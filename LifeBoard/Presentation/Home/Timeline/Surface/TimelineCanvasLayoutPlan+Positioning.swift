import SwiftUI

extension TimelineCanvasLayoutPlan {
    static func yPosition(for date: Date, start: Date, pointsPerMinute: CGFloat, calendar: Calendar) -> CGFloat {
        minuteOffset(for: date, start: start, calendar: calendar) * pointsPerMinute
    }
}
