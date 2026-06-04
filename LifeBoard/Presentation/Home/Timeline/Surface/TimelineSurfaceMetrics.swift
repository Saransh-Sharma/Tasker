import SwiftUI

struct TimelineSurfaceMetrics {
    let compactTimeGutter: CGFloat
    let compactLaneWidth: CGFloat
    let compactTrailingLaneWidth: CGFloat
    let compactTimeToLaneGap: CGFloat
    let compactConnectorHeight: CGFloat
    let compactAnchorRowHeight: CGFloat
    let compactGapRowHeight: CGFloat
    let compactItemMinRowHeight: CGFloat
    let compactReadableWidth: CGFloat?
    let compactContentLeadingPadding: CGFloat
    let compactContentTrailingPadding: CGFloat
    let compactAnchorCircleSize: CGFloat
    let compactAnchorIconSize: CGFloat

    let expandedTimeGutter: CGFloat
    let expandedSpineLaneWidth: CGFloat
    let expandedTrailingLaneWidth: CGFloat
    let expandedContentInset: CGFloat
    let expandedTimeToSpineGap: CGFloat
    let expandedCapsuleMinWidth: CGFloat
    let expandedSingleColumnTextMaxWidth: CGFloat
    let expandedOverlappingTextMaxWidth: CGFloat
    let expandedAnchorCircleSize: CGFloat
    let expandedAnchorIconSize: CGFloat

    let agendaCapsuleWidth: CGFloat
    let agendaAnchorCircleSize: CGFloat
    let agendaAnchorIconSize: CGFloat

    let timelineBottomPadding: CGFloat

    func resolvedTimelineBottomPadding(hasNextHomeWidget: Bool) -> CGFloat {
        hasNextHomeWidget ? 0 : timelineBottomPadding
    }

    static func make(for layoutClass: LifeBoardLayoutClass) -> TimelineSurfaceMetrics {
        let bottomProtection = TimelineBottomProtectionBudget.make(for: layoutClass).timelineInset
        switch layoutClass {
        case .phone:
            return TimelineSurfaceMetrics(
                compactTimeGutter: 62,
                compactLaneWidth: 52,
                compactTrailingLaneWidth: 40,
                compactTimeToLaneGap: 10,
                compactConnectorHeight: 10,
                compactAnchorRowHeight: 56,
                compactGapRowHeight: 56,
                compactItemMinRowHeight: 72,
                compactReadableWidth: nil,
                compactContentLeadingPadding: 12,
                compactContentTrailingPadding: 4,
                compactAnchorCircleSize: 48,
                compactAnchorIconSize: 18,
                expandedTimeGutter: 68,
                expandedSpineLaneWidth: 0,
                expandedTrailingLaneWidth: 0,
                expandedContentInset: 4,
                expandedTimeToSpineGap: 3,
                expandedCapsuleMinWidth: 60,
                expandedSingleColumnTextMaxWidth: 360,
                expandedOverlappingTextMaxWidth: 300,
                expandedAnchorCircleSize: 56,
                expandedAnchorIconSize: 20,
                agendaCapsuleWidth: 56,
                agendaAnchorCircleSize: 48,
                agendaAnchorIconSize: 18,
                timelineBottomPadding: bottomProtection
            )
        case .padCompact:
            return TimelineSurfaceMetrics(
                compactTimeGutter: 72,
                compactLaneWidth: 60,
                compactTrailingLaneWidth: 48,
                compactTimeToLaneGap: 12,
                compactConnectorHeight: 12,
                compactAnchorRowHeight: 60,
                compactGapRowHeight: 62,
                compactItemMinRowHeight: 78,
                compactReadableWidth: 680,
                compactContentLeadingPadding: 14,
                compactContentTrailingPadding: 8,
                compactAnchorCircleSize: 52,
                compactAnchorIconSize: 18,
                expandedTimeGutter: 76,
                expandedSpineLaneWidth: 84,
                expandedTrailingLaneWidth: 52,
                expandedContentInset: 16,
                expandedTimeToSpineGap: 12,
                expandedCapsuleMinWidth: 64,
                expandedSingleColumnTextMaxWidth: 420,
                expandedOverlappingTextMaxWidth: 320,
                expandedAnchorCircleSize: 56,
                expandedAnchorIconSize: 20,
                agendaCapsuleWidth: 60,
                agendaAnchorCircleSize: 52,
                agendaAnchorIconSize: 18,
                timelineBottomPadding: bottomProtection
            )
        case .padRegular, .padExpanded:
            return TimelineSurfaceMetrics(
                compactTimeGutter: 72,
                compactLaneWidth: 60,
                compactTrailingLaneWidth: 48,
                compactTimeToLaneGap: 12,
                compactConnectorHeight: 12,
                compactAnchorRowHeight: 60,
                compactGapRowHeight: 62,
                compactItemMinRowHeight: 78,
                compactReadableWidth: 680,
                compactContentLeadingPadding: 14,
                compactContentTrailingPadding: 8,
                compactAnchorCircleSize: 52,
                compactAnchorIconSize: 18,
                expandedTimeGutter: 76,
                expandedSpineLaneWidth: 84,
                expandedTrailingLaneWidth: 52,
                expandedContentInset: 16,
                expandedTimeToSpineGap: 12,
                expandedCapsuleMinWidth: 64,
                expandedSingleColumnTextMaxWidth: 420,
                expandedOverlappingTextMaxWidth: 320,
                expandedAnchorCircleSize: 56,
                expandedAnchorIconSize: 20,
                agendaCapsuleWidth: 60,
                agendaAnchorCircleSize: 56,
                agendaAnchorIconSize: 20,
                timelineBottomPadding: bottomProtection
            )
        }
    }
}
