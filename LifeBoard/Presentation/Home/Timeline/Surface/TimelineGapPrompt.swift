import SwiftUI

struct TimelineGapPrompt: View {
    let gap: TimelineGap
    let row: TimelineRenderableRow
    let suggestedDate: Date
    let onAddTask: () -> Void
    let onPlanBlock: () -> Void
    @Environment(\.lifeboardLayoutClass) var layoutClass

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(LBTypographyTokens.meta)
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .accessibilityHidden(true)
                timelineGapPromptText(for: gap, row: row)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Add task", systemImage: "plus", action: onAddTask)
            .buttonStyle(.plain)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(Color.lifeboard.textSecondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(Color.lifeboard.surfaceSecondary.opacity(0.58), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.56), lineWidth: 1)
            }
            .contentShape(Capsule())
            .accessibilityLabel("Add task at \(suggestedDate.formatted(date: .omitted, time: .shortened))")
            .accessibilityHint("Opens Add Task with this timeline time.")
            .accessibilityIdentifier("home.timeline.gap.createTask")

            Menu {
                Button("Place inbox with Compass", action: onPlanBlock)
                Button(TimelineGapAction.dismiss.title, role: .destructive) {}
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(LBTypographyTokens.bodyStrong)
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Open time options")
        }
        .padding(.vertical, layoutClass.isPad ? 6 : 8)
        .accessibilityElement(children: .contain)
    }
}
