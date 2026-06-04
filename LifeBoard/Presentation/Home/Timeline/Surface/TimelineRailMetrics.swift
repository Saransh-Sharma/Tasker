import SwiftUI

struct TimelineRailMetrics: Equatable {
    let labelLeadingX: CGFloat
    let labelWidth: CGFloat
    let timeToSpineGap: CGFloat
    let spineX: CGFloat
    let contentLeadingGap: CGFloat
    let contentX: CGFloat
    let routineTextGapFromIcon: CGFloat

    var labelLayerWidth: CGFloat { labelLeadingX + labelWidth }

    func routineTextLeadingX(iconSize: CGFloat) -> CGFloat {
        routineTextLeadingX(iconSize: iconSize, mountedSpineX: spineX)
    }

    func routineTextLeadingX(iconSize: CGFloat, mountedSpineX: CGFloat) -> CGFloat {
        mountedSpineX + (iconSize / 2) + routineTextGapFromIcon
    }

    static func make(
        for layoutClass: LifeBoardLayoutClass,
        surfaceMetrics: TimelineSurfaceMetrics,
        totalWidth: CGFloat = 390
    ) -> TimelineRailMetrics {
        switch layoutClass {
        case .phone:
            let labelLeadingX: CGFloat
            let labelWidth: CGFloat
            let timeToSpineGap: CGFloat
            let streamLaneWidth: CGFloat
            let contentGap: CGFloat

            if totalWidth <= 390 {
                labelLeadingX = 2
                labelWidth = 44
                timeToSpineGap = 4
                streamLaneWidth = 36
                contentGap = 8
            } else if totalWidth <= 430 {
                labelLeadingX = 3
                labelWidth = 46
                timeToSpineGap = 5
                streamLaneWidth = 38
                contentGap = 8
            } else {
                labelLeadingX = 4
                labelWidth = 48
                timeToSpineGap = 6
                streamLaneWidth = 42
                contentGap = 8
            }

            let streamLeadingX = labelLeadingX + labelWidth + timeToSpineGap
            let spineX = streamLeadingX + (streamLaneWidth / 2)
            let contentX = streamLeadingX + streamLaneWidth + contentGap
            return TimelineRailMetrics(
                labelLeadingX: labelLeadingX,
                labelWidth: labelWidth,
                timeToSpineGap: timeToSpineGap,
                spineX: spineX,
                contentLeadingGap: contentX - spineX,
                contentX: contentX,
                routineTextGapFromIcon: 14
            )
        case .padCompact, .padRegular, .padExpanded:
            let spineX = surfaceMetrics.expandedTimeGutter
                + surfaceMetrics.expandedTimeToSpineGap
                + (surfaceMetrics.expandedSpineLaneWidth / 2)
            let contentX = surfaceMetrics.expandedTimeGutter
                + surfaceMetrics.expandedTimeToSpineGap
                + surfaceMetrics.expandedSpineLaneWidth
                + surfaceMetrics.expandedContentInset
            return TimelineRailMetrics(
                labelLeadingX: 0,
                labelWidth: max(surfaceMetrics.expandedTimeGutter - 8, 44),
                timeToSpineGap: surfaceMetrics.expandedTimeToSpineGap,
                spineX: spineX,
                contentLeadingGap: max(contentX - spineX, 0),
                contentX: contentX,
                routineTextGapFromIcon: 14
            )
        }
    }
}
