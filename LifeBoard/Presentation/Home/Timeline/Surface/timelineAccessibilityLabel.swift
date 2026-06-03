import SwiftUI

func timelineAccessibilityLabel(for row: TimelineRenderableRow, item: TimelinePlanItem) -> String {
    var parts = [item.title, timelineMetaText(for: row, item: item)]
    if row.utilityItems.isEmpty == false {
        parts.append(row.utilityItems.map(\.accessibilityLabel).joined(separator: ", "))
    }
    return parts.joined(separator: ", ")
}
