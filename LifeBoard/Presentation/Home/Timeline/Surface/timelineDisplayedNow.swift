import SwiftUI

func timelineDisplayedNow(for projection: TimelineDayProjection, timelineDate: Date) -> Date {
    Calendar.current.isDate(projection.date, inSameDayAs: timelineDate) ? timelineDate : projection.currentTime
}
