import SwiftUI

struct TimelinePlanningShelf: View {
    let allDayItems: [TimelinePlanItem]
    let inboxItems: [TimelinePlanItem]
    let placementCandidate: TimelinePlacementCandidate?
    let selectedDate: Date
    let onTaskTap: (TimelinePlanItem) -> Void
    let onScheduleInbox: () -> Void
    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void

    @State var isAllDayTargeted = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let placementCandidate {
                Button {
                    LifeBoardFeedback.selection()
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isAllDayTargeted ? "calendar.badge.checkmark" : "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.lifeboard.accentPrimary)
                            .frame(width: 34, height: 34)
                            .background(Color.lifeboard.accentWash, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAllDayTargeted ? "Drop for All Day" : "Make All Day")
                                .font(.lifeboard(.support).weight(.semibold))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            Text(placementCandidate.title)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(isAllDayTargeted ? Color.lifeboard.accentWash.opacity(0.82) : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isAllDayTargeted ? Color.lifeboard.accentPrimary.opacity(0.46) : Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .scaleEffect(isAllDayTargeted && reduceMotion == false ? 1.012 : 1)
                .dropDestination(for: String.self, action: { items, _ in
                    guard items.contains(placementCandidate.taskID.uuidString) else { return false }
                    LifeBoardFeedback.success()
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                    return true
                }, isTargeted: { newValue in
                    isAllDayTargeted = newValue
                })
                .onChange(of: isAllDayTargeted) { _, newValue in
                    guard newValue else { return }
                    LifeBoardFeedback.selection()
                }
                .accessibilityHint("Places the replanned task in the all-day row for this date.")
                .accessibilityIdentifier("home.needsReplan.hotZone.allDay")
            }

            if allDayItems.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All-day commitments")
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(allDayItems) { item in
                                TimelineShelfItemCard(item: item) {
                                    onTaskTap(item)
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .accessibilityLabel("All-day commitments")
                    .accessibilityHint(allDayItems.count > 2 ? "Scroll horizontally to browse all all-day items." : "Double-tap an item to inspect it.")
                    .accessibilityIdentifier("home.timeline.allDayStrip")
                }
            }

            if inboxItems.isEmpty == false {
                TimelineInboxPlanningCard(
                    inboxItems: inboxItems,
                    onTaskTap: onTaskTap
                )
            }
        }
    }
}
