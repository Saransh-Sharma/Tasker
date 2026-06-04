import SwiftUI

struct TimelineInboxPlanningCard: View {
    let inboxItems: [TimelinePlanItem]
    let onTaskTap: (TimelinePlanItem) -> Void
    let onScheduleInbox: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(inboxItems.count == 1 ? "1 inbox task ready" : "\(inboxItems.count) inbox tasks ready")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Text("Fill open time first")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text("Pull something unplaced into the timeline before inspecting the rest of the day.")
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Schedule Inbox") {
                    onScheduleInbox()
                }
                .buttonStyle(.plain)
                .font(.lifeboard(.buttonSmall))
                .foregroundStyle(Color.lifeboard.accentOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.lifeboard.accentPrimary, in: Capsule())
                .accessibilityHint("Starts placing inbox tasks into open time.")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(inboxItems.prefix(4)) { item in
                        Button {
                            onTaskTap(item)
                        } label: {
                            Text(item.title)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.lifeboard.surfacePrimary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if inboxItems.count > 4 {
                        Text("+\(inboxItems.count - 4) more")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.lifeboard.surfacePrimary, in: Capsule())
                            .accessibilityLabel("\(inboxItems.count - 4) more inbox tasks")
                    }
                }
                .padding(.trailing, 4)
            }
            .accessibilityLabel("Inbox task previews")
            .accessibilityHint(inboxItems.count > 4 ? "Scroll horizontally to inspect more inbox tasks." : "Swipe through inbox tasks to inspect them.")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary)
        )
    }
}
