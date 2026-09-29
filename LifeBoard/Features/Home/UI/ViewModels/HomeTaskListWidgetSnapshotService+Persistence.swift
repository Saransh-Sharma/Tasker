import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

extension TaskListWidgetSnapshotService {
    func widgetTask(from task: TaskDefinition) -> TaskListWidgetTask {
        TaskListWidgetTask(
            id: task.id,
            title: task.title,
            projectID: task.projectID,
            projectName: task.projectName,
            priorityCode: task.priority.code,
            dueDate: task.dueDate,
            isOverdue: task.isOverdue,
            estimatedDurationMinutes: task.estimatedDuration.map { max(1, Int($0 / 60)) },
            energy: task.energy.rawValue,
            context: task.context.rawValue,
            isComplete: task.isComplete,
            hasDependencies: !task.dependencies.isEmpty
        )
    }

    func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    func sortCompletedDescending(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        let lhsDate = lhs.dateCompleted ?? Date.distantPast
        let rhsDate = rhs.dateCompleted ?? Date.distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    func persistIfChanged(snapshot: TaskListWidgetSnapshot, reason: String) {
        let current = TaskListWidgetSnapshot.load()
        if Self.normalizedForReloadComparison(snapshot) == Self.normalizedForReloadComparison(current) {
            return
        }
        snapshot.save()
        WatchWidgetSnapshotSync.shared.sendTaskListSnapshot(snapshot)
        reloadTaskListTimelines()
        logDebug("TASK_WIDGET_SNAPSHOT refreshed reason=\(reason)")
    }

    static func normalizedForReloadComparison(_ snapshot: TaskListWidgetSnapshot) -> TaskListWidgetSnapshot {
        var value = snapshot
        value.updatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.generatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.hasCorruptionFallback = false
        value.calendar.updatedAt = Date(timeIntervalSince1970: 0)
        value.timeline.updatedAt = Date(timeIntervalSince1970: 0)
        value.timeline.day.currentTime = Date(timeIntervalSince1970: 0)
        value.habit.updatedAt = Date(timeIntervalSince1970: 0)
        return value
    }

    func reloadTaskListTimelines() {
        #if canImport(WidgetKit)
        let kinds = [
            "TopTaskNowWidget", "TodayCounterNextWidget", "OverdueRescueWidget", "QuickWin15mWidget",
            "MorningKickoffWidget", "EveningWrapWidget", "WaitingOnWidget", "InboxTriageWidget",
            "DueSoonRadarWidget", "EnergyMatchWidget", "ProjectSpotlightWidget", "CalendarTaskBridgeWidget",
            "TodayTop3Widget", "NowLaneWidget", "OverdueBoardWidget", "Upcoming48hWidget",
            "MorningEveningPlanWidget", "QuickViewSwitcherWidget", "ProjectSprintWidget",
            "PriorityMatrixLiteWidget", "ContextWidget", "FocusSessionQueueWidget",
            "RecoveryWidget", "DoneReflectionWidget",
            "TodayPlannerBoardWidget", "WeekTaskPlannerWidget", "ProjectCockpitWidget",
            "BacklogHealthWidget", "KanbanLiteWidget", "DeadlineHeatmapWidget",
            "ExecutionDashboardWidget", "DeepWorkAgendaWidget", "AssistantPlanPreviewWidget",
            "LifeAreasBoardWidget",
            "HomeCalendarWidget", "HomeTimelineWidget",
            "WatchTimelineComplication", "WatchMeetingScheduleComplication", "WatchHabitStreakComplication",
            "InlineNextTaskWidget", "InlineDueSoonWidget",
            "CircularTodayProgressWidget", "CircularQuickAddWidget",
            "RectangularTop2TasksWidget", "RectangularOverdueAlertWidget",
            "RectangularFocusNowWidget", "RectangularWaitingOnWidget",
            "DeskTodayBoardWidget", "CountdownPanelWidget", "NightlyResetWidget",
            "MorningBriefPanelWidget", "ProjectPulseWidget", "FocusDockWidget"
        ]
        Task { @MainActor in
            let center = WidgetCenter.shared
            for kind in kinds {
                center.reloadTimelines(ofKind: kind)
            }
        }
        #endif
    }
}
