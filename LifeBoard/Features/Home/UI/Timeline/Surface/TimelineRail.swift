import SwiftUI

// The time rail down the side of the canvas: its labels, metrics,
// typography and formatting.

// MARK: - TimelineRailLabel

struct TimelineRailLabel: View {
    let text: String
    let kind: TimelineRailLabelKind
    let isEmphasized: Bool
    let color: Color
    let metrics: TimelineRailMetrics
    var leadingX: CGFloat? = nil

    var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .multilineTextAlignment(.trailing)
            .frame(width: metrics.labelWidth, alignment: .trailing)
            .offset(x: leadingX ?? metrics.labelLeadingX)
    }

    var font: Font {
        TimelineRailTypography.font(for: kind, isEmphasized: isEmphasized)
    }
}

// MARK: - TimelineRailLabelKind

enum TimelineRailLabelKind: Equatable {
    case compactHour
    case exact
    case current
}

// MARK: - TimelineRailMetrics

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
        for layoutClass: LayoutClass,
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

// MARK: - TimelineRailPresentationSpec

struct TimelineRailPresentationSpec: Equatable {
    let lineWidth: CGFloat
    let opacity: Double
    let isDashed: Bool

    static let compactConnector = TimelineRailPresentationSpec(
        lineWidth: 1.5,
        opacity: 0.46,
        isDashed: false
    )
}

// MARK: - TimelineRailTimeFormatter

enum TimelineRailTimeFormatter {
    static func railText(for date: Date, kind: TimelineRailLabelKind, calendar: Calendar = .current) -> String {
        switch kind {
        case .compactHour:
            return date.formatted(style(calendar: calendar).hour())
        case .exact, .current:
            return date.formatted(style(calendar: calendar).hour().minute())
        }
    }

    static func railText(forItemStart date: Date, calendar: Calendar = .current) -> String {
        let minute = calendar.component(.minute, from: date)
        let kind: TimelineRailLabelKind = minute == 0 ? .compactHour : .exact
        return railText(for: date, kind: kind, calendar: calendar)
    }

    /// Visible rail times follow the user's locale and 12/24-hour preference.
    private static func style(calendar: Calendar) -> Date.FormatStyle {
        Date.FormatStyle(
            locale: calendar.locale ?? .current,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
    }
}

// MARK: - TimelineRailTypography

enum TimelineRailTypography {
    static let compactHourSize: CGFloat = 14
    static let exactSize: CGFloat = 14
    static let currentSize: CGFloat = 13

    static func font(for kind: TimelineRailLabelKind, isEmphasized: Bool) -> Font {
        switch kind {
        case .compactHour:
            return .system(size: compactHourSize, weight: isEmphasized ? .semibold : .medium, design: .rounded)
        case .exact:
            return .system(size: exactSize, weight: isEmphasized ? .semibold : .medium, design: .rounded)
        case .current:
            return .system(size: currentSize, weight: .semibold, design: .rounded)
        }
    }
}

// MARK: - timelineRailText

func timelineRailText(for item: TimelinePlanItem) -> String {
    guard let start = item.startDate else { return "All day" }
    return start.formatted(date: .omitted, time: .shortened)
}
