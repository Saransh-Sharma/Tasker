import SwiftUI

struct TimelineCompactGapRow: View {
    let gap: TimelineGap
    let row: TimelineRenderableRow
    let layoutClass: LifeBoardLayoutClass
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        Menu {
            Button(TimelineGapAction.addTask.title, action: onAddTask)
            Button("Place inbox with Compass", action: onScheduleInbox)
            Button(TimelineGapAction.dismiss.title, role: .destructive) {}
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text(gap.startDate.formatted(date: .omitted, time: .shortened))
                    .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
                    .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText.opacity(0.92))
                    .frame(width: metrics.compactTimeGutter, alignment: .trailing)

                Color.clear
                    .frame(width: metrics.compactTimeToLaneGap)

                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(LBTypographyTokens.meta)
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .frame(width: metrics.compactLaneWidth)
                    .accessibilityHidden(true)

                timelineGapPromptText(for: gap, row: row)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.vertical, 6)
                    .padding(.leading, metrics.compactContentLeadingPadding)
                    .padding(.trailing, metrics.compactContentTrailingPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityLabel("\(gap.headline), \(gap.supportingText), \(gap.compactDurationText)")
                }
            }
        .buttonStyle(.plain)
    }
}
