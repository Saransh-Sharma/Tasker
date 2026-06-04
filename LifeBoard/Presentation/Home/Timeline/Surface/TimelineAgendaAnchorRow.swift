import SwiftUI

struct TimelineAgendaAnchorRow: View {
    let anchor: TimelineAnchorItem
    let row: TimelineRenderableRow
    let onTap: () -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        if let style = TimelineRoutineAnchorVisualStyle.resolve(anchorID: anchor.id, title: anchor.title, subtitle: row.subtitle) {
            TimelineRoutineAnchorCard(
                style: style,
                timeText: TimelineRailTimeFormatter.railText(for: anchor.time, kind: .exact),
                onTap: onTap,
                minimumHeight: 112,
                leadingArtworkReserve: 112,
                accessibilityHint: TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint
            )
            .accessibilityIdentifier("home.timeline.anchor.\(anchor.id)")
        } else {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(TimelineVisualTokens.anchorCapsuleFill)
                        .frame(width: metrics.agendaAnchorCircleSize, height: metrics.agendaAnchorCircleSize)
                        .overlay {
                            Image(systemName: anchor.systemImageName)
                                .font(.system(size: metrics.agendaAnchorIconSize, weight: .semibold))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .accessibilityHidden(true)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(anchor.time.formatted(date: .omitted, time: .shortened))
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                        Text(anchor.title)
                            .font(.lifeboard(.title3))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        if let subtitle = row.subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(TimelineVisualTokens.utilityText)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
            .accessibilityHint(TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint ?? "Edit timeline anchor time")
        }
    }
}
