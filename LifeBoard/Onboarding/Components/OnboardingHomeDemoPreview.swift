import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingHomeDemoPreview: View {
    let assistantName: String
    let selectedMascotID: AssistantMascotID
    let taskDone: Bool
    let habitDone: Bool
    let onTaskDone: () -> Void
    let onHabitDone: () -> Void

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var timelineSnapshot: HomeTimelineSnapshot {
        OnboardingHomeDemoSnapshotFactory.snapshot(taskDone: taskDone)
    }

    var habitRows: [HomeHabitRow] {
        OnboardingHomeDemoSnapshotFactory.habitRows(habitDone: habitDone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HStack(alignment: .center, spacing: spacing.s12) {
                EvaMascotView(
                    placement: .chatHelp,
                    size: .custom(58),
                    decorative: true,
                    mascotID: selectedMascotID
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(assistantName)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.marigold)
                    Text(taskDone ? "Now mark a habit done." : "Tap the next task in your Home timeline.")
                        .lifeboardFont(.bodyEmphasis)
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SunriseTimelineSurface(
                snapshot: timelineSnapshot,
                layoutClass: layoutClass,
                showsRevealHandle: false,
                hasNextHomeWidget: true,
                onSelectDate: { _ in },
                onSnapAnchor: { _ in },
                onDragChanged: { _ in },
                onDragEnded: { _ in },
                onTaskTap: handleTimelineItem(_:),
                onToggleComplete: handleTimelineItem(_:),
                onAnchorTap: { _ in },
                onAddTask: { _ in },
                onScheduleInbox: {},
                onShowCalendarInTimeline: {},
                onPlaceReplanAtTime: { _, _ in },
                onPlaceReplanAllDay: { _, _ in },
                onCancelReplanPlacement: {},
                onSkipReplanPlacement: {},
                onClearReplanError: {}
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.homeDemoTimeline)

            HabitHomeSectionCard(
                title: "Habits",
                summaryLine: "\(habitRows.count) active",
                rows: habitRows,
                onOpenBoard: nil,
                onPrimaryAction: handleHabit(_:),
                onSecondaryAction: { _ in },
                onRowAction: handleHabit(_:),
                onLastCellAction: handleHabit(_:),
                onOpenHabit: handleHabit(_:)
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.homeDemoHabits)
        }
        .padding(18)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }

    func handleTimelineItem(_ item: TimelinePlanItem) {
        guard item.taskID == OnboardingHomeDemoSnapshotFactory.demoTaskID, taskDone == false else { return }
        onTaskDone()
    }

    func handleHabit(_ row: HomeHabitRow) {
        guard row.habitID == OnboardingHomeDemoSnapshotFactory.demoHabitID, habitDone == false else { return }
        onHabitDone()
    }
}
