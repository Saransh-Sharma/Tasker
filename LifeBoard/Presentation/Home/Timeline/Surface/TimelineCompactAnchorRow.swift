import SwiftUI

struct TimelineCompactAnchorRow: View {
    let anchor: TimelineAnchorItem
    let row: TimelineRenderableRow
    let layoutClass: LifeBoardLayoutClass
    let onTap: () -> Void

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        if let style = TimelineRoutineAnchorVisualStyle.resolve(anchorID: anchor.id, title: anchor.title, subtitle: row.subtitle) {
            HStack(alignment: .center, spacing: 0) {
                Text(anchor.time.formatted(date: .omitted, time: .shortened))
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: metrics.compactTimeGutter, alignment: .trailing)
                    .accessibilityHidden(true)

                Color.clear
                    .frame(width: metrics.compactTimeToLaneGap)

                Circle()
                    .fill(style.borderColor)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(LBColorTokens.whiteStroke.opacity(0.72), lineWidth: 2)
                    }
                    .frame(width: metrics.compactLaneWidth)
                    .accessibilityHidden(true)

                TimelineRoutineAnchorCard(
                    style: style,
                    timeText: TimelineRailTimeFormatter.railText(for: anchor.time, kind: .exact),
                    onTap: onTap,
                    minimumHeight: 92,
                    leadingArtworkReserve: 76,
                    accessibilityHint: TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint
                )
                .accessibilityIdentifier("home.timeline.anchor.\(anchor.id)")

                if anchor.isActionable {
                    TimelineCompletionRing(
                        color: Color.lifeboard.accentPrimary,
                        isCompleted: false,
                        isInteractive: false,
                        label: anchor.title,
                        action: {}
                    )
                    .frame(width: metrics.compactTrailingLaneWidth, alignment: .center)
                } else {
                    Color.clear
                        .frame(width: metrics.compactTrailingLaneWidth, height: 1)
                }
            }
        } else {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 0) {
                    Text(anchor.time.formatted(date: .omitted, time: .shortened))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .frame(width: metrics.compactTimeGutter, alignment: .trailing)

                    Color.clear
                        .frame(width: metrics.compactTimeToLaneGap)

                    Circle()
                        .fill(TimelineVisualTokens.anchorCapsuleFill)
                        .frame(width: metrics.compactAnchorCircleSize, height: metrics.compactAnchorCircleSize)
                        .overlay {
                            Image(systemName: anchor.systemImageName)
                                .font(.system(size: metrics.compactAnchorIconSize, weight: .semibold))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .frame(width: metrics.compactLaneWidth)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(anchor.title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        if let subtitle = row.subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(TimelineVisualTokens.utilityText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12)

                    if anchor.isActionable {
                        TimelineCompletionRing(
                            color: Color.lifeboard.accentPrimary,
                            isCompleted: false,
                            isInteractive: false,
                            label: anchor.title,
                            action: {}
                        )
                        .frame(width: metrics.compactTrailingLaneWidth, alignment: .center)
                    } else {
                        Color.clear
                            .frame(width: metrics.compactTrailingLaneWidth, height: 1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
            .accessibilityValue(anchor.id == "wake" ? "Timeline start" : "Timeline end")
            .accessibilityHint(TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint ?? "Edit timeline anchor time")
        }
    }
}
