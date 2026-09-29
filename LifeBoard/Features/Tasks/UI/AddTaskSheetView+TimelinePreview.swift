import SwiftUI

struct TaskTimelinePreview: View {
    let title: String
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    var dueDate: Date? = nil
    let duration: TimeInterval?
    let lifeArea: LifeArea?
    var isAwaiting: Bool = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var role: RoleStyle { ClayColorTokens.role(.task) }
    private var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New task" : trimmed
    }
    private var lifeAreaText: String {
        lifeArea?.name ?? "Any life area"
    }
    private var durationText: String? {
        guard let duration else { return nil }
        return LifeBoardDuration.text(minutes: max(1, Int((duration / 60).rounded())))
    }
    private var timeText: String {
        guard let scheduledStartAt else { return AddTaskViewModel.anytimeLabel(day: dueDate) }
        return AddTaskViewModel.scheduleRangeLabel(start: scheduledStartAt, end: scheduledEndAt)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: ClayLayoutMetrics.sm) {
                VStack(spacing: 8) {
                    Text(scheduledStartAt.map(Self.hourText(for:)) ?? "--")
                        .lifeboardFont(.headline)
                        .foregroundStyle(ClayColorTokens.navyMuted)
                        .frame(width: 58, alignment: .trailing)
                    Circle()
                        .fill(role.base)
                        .frame(width: 10, height: 10)
                        .breathingPulse(min: isAwaiting ? 0.35 : 1.0, max: 1.0, duration: 1.6)
                    Rectangle()
                        .fill(role.border)
                        .frame(width: 2, height: 56)
                        .opacity(0.7)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ClayLayoutMetrics.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(timeText, systemImage: "clock")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(role.deep)
                        Spacer(minLength: ClayLayoutMetrics.xs)
                        if let durationText {
                            Text(durationText)
                                .font(.lifeboard(.caption1).weight(.semibold))
                                .foregroundStyle(ClayColorTokens.navyMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(ClayColorTokens.glassStrong))
                        }
                    }

                    Text(displayTitle)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(ClayColorTokens.navy)
                        .lineLimit(2)
                        .contentTransition(.opacity)
                        .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: displayTitle)

                    Label(lifeAreaText, systemImage: role.symbolName)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(ClayColorTokens.navyMuted)
                }
                .padding(ClayLayoutMetrics.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [role.softSurface, ClayColorTokens.glassStrong],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(role.border.opacity(0.82), lineWidth: 1)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addTask.timelinePreview")
        .accessibilityLabel("Timeline preview. \(displayTitle). \(timeText). \(durationText.map { "\($0). " } ?? "")\(lifeAreaText).")
    }

    /// "3 PM" or "15", following the person's 12- or 24-hour setting.
    private static func hourText(for date: Date) -> String {
        date.formatted(.dateTime.hour())
    }
}
