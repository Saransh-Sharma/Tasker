import SwiftUI

func timelineMetaText(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil, anchor: TimelineAnchorItem? = nil) -> String {
    switch row.metadataMode {
    case .remainingTime(let minutes):
        return "\(minutes)m remaining"
    case .done:
        guard let item, let start = item.startDate, let end = item.endDate else { return "Done" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(TimelineFormatting.timeRangeText(start: start, end: end)) · \(durationText) · Done"
    case .scheduled, .none:
        if let anchor {
            return anchor.time.formatted(date: .omitted, time: .shortened)
        }
        guard let item, let start = item.startDate, let end = item.endDate else { return "All day" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(TimelineFormatting.timeRangeText(start: start, end: end)) · \(durationText)"
    }
}
