import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widgets

struct InlineNextTaskWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { _ in
            if let task = entry.snapshot.nextTask {
                Text("Next \(task.title)")
                    .font(TaskWidgetTypography.captionStrong)
                    .lineLimit(1)
            } else {
                Text("Next capture")
                    .font(TaskWidgetTypography.captionStrong)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.snapshot.nextTask.map { "Next task \($0.title)" } ?? "Next task. Capture a task")
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.quickAdd)
    }
}

struct CircularTodayProgressWidgetView: View {
    let entry: TaskListEntry

    private var totalEstimate: Int {
        max(entry.snapshot.doneTodayCount + entry.snapshot.openCount, 1)
    }

    var body: some View {
        TaskWidgetScene(alignment: .center) { context in
            Gauge(
                value: Double(entry.snapshot.doneTodayCount),
                in: 0...Double(totalEstimate)
            ) {
                Image(systemName: "checklist")
                    .widgetAccentedRenderingMode(.accented)
                    .widgetAccentable()
            } currentValueLabel: {
                Text("\(entry.snapshot.doneTodayCount)")
                    .font(TaskWidgetTypography.captionStrong)
                    .taskWidgetNumericTransition(Double(entry.snapshot.doneTodayCount), reduceMotion: context.reduceMotion)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(WidgetBrand.actionPrimary)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct RectangularTop2TasksWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let topTasks = Array(entry.snapshot.todayTopTasks.prefix(2))

        TaskWidgetScene { _ in
            VStack(alignment: .leading, spacing: 4) {
                Text("TOP 2")
                    .font(TaskWidgetTypography.eyebrow)
                    .foregroundStyle(WidgetBrand.textSecondary)
                if topTasks.isEmpty {
                    Text("No tasks queued")
                        .font(TaskWidgetTypography.support)
                        .foregroundStyle(WidgetBrand.textSecondary)
                        .lineLimit(2)
                } else {
                    ForEach(topTasks.indices, id: \.self) { index in
                        let task = topTasks[index]
                        TaskWidgetTaskLine(
                            title: "\(index + 1). \(task.title)",
                            destination: TaskWidgetRoutes.task(task.id)
                        )
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.todayTopTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct RectangularOverdueAlertWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: 4) {
                Text("OVERDUE")
                    .font(TaskWidgetTypography.eyebrow)
                    .foregroundStyle(WidgetBrand.marigold)
                Text("\(entry.snapshot.overdueCount)")
                    .font(TaskWidgetTypography.titleLarge)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .taskWidgetNumericTransition(Double(entry.snapshot.overdueCount), reduceMotion: context.reduceMotion)
                Text(entry.snapshot.overdueTasks.first?.title ?? "No overdue tasks")
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(WidgetBrand.textSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.snapshot.overdueTasks.first.map { "Overdue \(entry.snapshot.overdueCount). First task \($0.title)" } ?? "No overdue tasks")
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.overdue)
    }
}

struct CircularQuickAddWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene(alignment: .center) { _ in
            ZStack {
                Circle()
                    .fill(WidgetBrand.accentQuiet.opacity(0.22))
                Image(systemName: "plus")
                    .widgetAccentedRenderingMode(.accented)
                    .font(TaskWidgetTypography.titleLarge)
                    .foregroundStyle(WidgetBrand.actionPrimary)
                    .widgetAccentable()
            }
            .padding(6)
            .accessibilityLabel("Quick add task")
        }
        .widgetURL(TaskWidgetRoutes.quickAdd)
    }
}

struct RectangularFocusNowWidgetView: View {
    let entry: TaskListEntry

    private var task: TaskListWidgetTask? {
        entry.snapshot.focusNow.first ?? entry.snapshot.todayTopTasks.first
    }

    var body: some View {
        TaskWidgetScene { _ in
            VStack(alignment: .leading, spacing: 4) {
                Text("FOCUS")
                    .font(TaskWidgetTypography.eyebrow)
                    .foregroundStyle(WidgetBrand.actionPrimary)
                Text(task?.title ?? "No focus task")
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(task == nil ? WidgetBrand.textSecondary : WidgetBrand.textPrimary)
                    .lineLimit(2)
                if let task {
                    Text(task.priorityCode)
                        .font(TaskWidgetTypography.caption)
                        .foregroundStyle(WidgetBrand.priority(task.priorityCode))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.map { "Focus now \($0.title)" } ?? "No focus task")
        .widgetURL(task.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct InlineDueSoonWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { _ in
            if let task = entry.snapshot.upcomingTasks.first {
                Text("Due soon \(task.title)")
                    .font(TaskWidgetTypography.captionStrong)
                    .lineLimit(1)
            } else {
                Text("Due soon clear")
                    .font(TaskWidgetTypography.captionStrong)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.snapshot.upcomingTasks.first.map { "Due soon \($0.title)" } ?? "No upcoming deadline")
        .widgetURL(entry.snapshot.upcomingTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

struct RectangularWaitingOnWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { _ in
            VStack(alignment: .leading, spacing: 4) {
                Text("WAITING")
                    .font(TaskWidgetTypography.eyebrow)
                    .foregroundStyle(WidgetBrand.magenta)
                Text(entry.snapshot.waitingOn.first?.title ?? "No blocked tasks")
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(entry.snapshot.waitingOn.isEmpty ? WidgetBrand.textSecondary : WidgetBrand.textPrimary)
                    .lineLimit(2)
                Text("\(entry.snapshot.waitingOn.count) blocked")
                    .font(TaskWidgetTypography.caption)
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.snapshot.waitingOn.first.map { "Waiting on \($0.title). \(entry.snapshot.waitingOn.count) blocked tasks." } ?? "No blocked tasks")
        .widgetURL(entry.snapshot.waitingOn.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

// MARK: - StandBy Widgets

struct DeskTodayBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene(isStandByLike: true) { context in
            TaskWidgetTwoZone(
                spacing: context.panelSpacing,
                leadingWeight: context.leadRatio,
                trailingWeight: context.supportRatio
            ) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Today",
                        value: "\(entry.snapshot.todayTopTasks.count)",
                        numericValue: Double(entry.snapshot.todayTopTasks.count),
                        supporting: entry.snapshot.nextTask?.title ?? "No active tasks",
                        accent: WidgetBrand.actionPrimary
                    )
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, style: .softSection, padding: 14) {
                    TaskWidgetStatStrip(items: [
                        TaskWidgetStatItem(title: "Done", value: "\(entry.snapshot.doneTodayCount)", tint: WidgetBrand.emerald),
                        TaskWidgetStatItem(title: "Overdue", value: "\(entry.snapshot.overdueCount)", tint: WidgetBrand.marigold),
                        TaskWidgetStatItem(title: "Next", value: "\(entry.snapshot.upcomingTasks.count)", tint: WidgetBrand.sandstone)
                    ])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct CountdownPanelWidgetView: View {
    let entry: TaskListEntry

    private var next: TaskListWidgetTask? {
        entry.snapshot.nextDeadlineTask
    }

    var body: some View {
        TaskWidgetScene(isStandByLike: true) { context in
            TaskWidgetTwoZone(
                spacing: context.panelSpacing,
                leadingWeight: context.leadRatio,
                trailingWeight: context.supportRatio
            ) {
                TaskWidgetPanel(accent: WidgetBrand.marigold, padding: 14) {
                    if let next {
                        Text(next.title)
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        Text("Due \(next.dueLabel)")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    } else {
                        TaskWidgetEmptyState(title: "No upcoming deadlines.", symbol: "hourglass")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, style: .quiet, padding: 14) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Countdown",
                        value: next?.dueLabel ?? "Clear",
                        supporting: next == nil ? "Your horizon is open." : "Next meaningful deadline in sight.",
                        accent: WidgetBrand.marigold
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .widgetURL(next.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

struct FocusDockWidgetView: View {
    let entry: TaskListEntry

    private var queue: [TaskListWidgetTask] {
        entry.snapshot.focusNow.isEmpty ? entry.snapshot.todayTopTasks : entry.snapshot.focusNow
    }

    var body: some View {
        TaskWidgetScene(isStandByLike: true) { context in
            TaskWidgetTwoZone(
                spacing: context.panelSpacing,
                leadingWeight: context.leadRatio,
                trailingWeight: context.supportRatio
            ) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                    if let lead = queue.first {
                        Text(lead.title)
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        Text("\(lead.projectLabel) • \(lead.priorityCode)")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    } else {
                        TaskWidgetEmptyState(title: "No focus lane yet.", symbol: "target")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, style: .quiet, padding: 14) {
                    TaskWidgetSectionHeader(eyebrow: "Queue", title: "Next", detail: nil, accent: WidgetBrand.textPrimary)
                    TaskWidgetTaskList(tasks: Array(queue.dropFirst()), limit: context.supportListLimit, subtitle: { $0.projectLabel })
                }
            }
        }
        .accessibilityElement(children: .contain)
        .widgetURL(queue.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct NightlyResetWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene(isStandByLike: true) { context in
            TaskWidgetTwoZone(
                spacing: context.panelSpacing,
                leadingWeight: context.leadRatio,
                trailingWeight: context.supportRatio
            ) {
                TaskWidgetPanel(accent: WidgetBrand.emerald, padding: 14) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Nightly Reset",
                        value: "\(entry.snapshot.doneTodayCount)",
                        numericValue: Double(entry.snapshot.doneTodayCount),
                        supporting: entry.snapshot.overdueTasks.first.map { "Carry-over: \($0.title)" } ?? "All clear for tomorrow",
                        accent: WidgetBrand.emerald
                    )
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.marigold, style: .softSection, padding: 14) {
                    TaskWidgetSectionHeader(eyebrow: "Carry", title: "Into Tomorrow", detail: nil, accent: WidgetBrand.textPrimary)
                    TaskWidgetSummaryPill(title: "Carry", value: "\(entry.snapshot.overdueCount)", numericValue: Double(entry.snapshot.overdueCount), tint: WidgetBrand.marigold)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct MorningBriefPanelWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene(isStandByLike: true) { context in
            TaskWidgetTwoZone(
                spacing: context.panelSpacing,
                leadingWeight: context.leadRatio,
                trailingWeight: context.supportRatio
            ) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Morning Brief",
                        value: "\(entry.snapshot.todayTopTasks.count)",
                        numericValue: Double(entry.snapshot.todayTopTasks.count),
                        supporting: entry.snapshot.morningTasks.first?.title ?? "No kickoff task",
                        accent: WidgetBrand.actionPrimary
                    )
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, style: .softSection, padding: 14) {
                    TaskWidgetStatStrip(items: [
                        TaskWidgetStatItem(title: "Overdue", value: "\(entry.snapshot.overdueCount)", tint: WidgetBrand.marigold),
                        TaskWidgetStatItem(title: "Focus", value: "\(entry.snapshot.focusNow.count)", tint: WidgetBrand.sandstone)
                    ])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .widgetURL(entry.snapshot.morningTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct ProjectPulseWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene(isStandByLike: true) { context in
            TaskWidgetTwoZone(
                spacing: context.panelSpacing,
                leadingWeight: context.leadRatio,
                trailingWeight: context.supportRatio
            ) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Project Pulse",
                        value: "\(entry.snapshot.projectSlices.count)",
                        numericValue: Double(entry.snapshot.projectSlices.count),
                        supporting: entry.snapshot.projectSlices.first?.projectName ?? "No active project slices",
                        accent: WidgetBrand.actionPrimary
                    )
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.marigold, style: .quiet, padding: 14) {
                    TaskWidgetSectionHeader(eyebrow: "Portfolio", title: "Watchlist", detail: nil, accent: WidgetBrand.textPrimary)
                    ForEach(Array(entry.snapshot.projectSlices.prefix(context.supportListLimit + 1))) { slice in
                        TaskWidgetTaskLine(
                            title: slice.projectName,
                            trailing: slice.overdueCount > 0 ? "!\(slice.overdueCount)" : "\(slice.openCount)",
                            trailingTint: slice.overdueCount > 0 ? WidgetBrand.marigold : WidgetBrand.actionPrimary,
                            destination: slice.projectID.map(TaskWidgetRoutes.project(_:))
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .widgetURL(TaskWidgetRoutes.today)
    }
}
