import SwiftUI

// MARK: - Home Widgets (Small)

private struct TopTaskActionRow: View {
    let task: TaskListWidgetTask

    var body: some View {
        HStack(spacing: 10) {
            if #available(iOSApplicationExtension 17.0, *), TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled {
                Button(intent: CompleteTaskFromWidgetIntent(taskID: task.id.uuidString)) {
                    Image(systemName: "checkmark.circle.fill")
                        .widgetAccentedRenderingMode(.accented)
                        .foregroundStyle(WidgetBrand.actionPrimary)
                        .widgetAccentable()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete ‘\(task.title)’")

                Button(intent: DeferTaskFromWidgetIntent(taskID: task.id.uuidString, minutes: .fifteen)) {
                    Image(systemName: "clock.arrow.circlepath")
                        .widgetAccentedRenderingMode(.accented)
                        .foregroundStyle(WidgetBrand.sandstone)
                        .widgetAccentable()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Snooze ‘\(task.title)’ 15 min")
            }

            Link(destination: TaskWidgetRoutes.task(task.id)) {
                TaskWidgetActionBandLabel(
                    title: TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled ? "Open" : "Review",
                    accent: WidgetBrand.actionPrimary
                )
            }
            .accessibilityLabel(TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled ? "Open ‘\(task.title)’" : "Review ‘\(task.title)’")
        }
    }
}

private struct SmallStoryShell<Content: View>: View {
    let eyebrow: String
    let title: String
    let detail: String?
    let accent: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(
                    eyebrow: eyebrow,
                    title: title,
                    detail: detail,
                    accent: WidgetBrand.textPrimary
                )
                content()
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct TopTaskNowWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Today",
            title: "Next up",
            detail: entry.snapshot.nextTask?.priorityCode,
            accent: WidgetBrand.actionPrimary
        ) {
            if let task = entry.snapshot.nextTask {
                Text(task.title)
                    .font(TaskWidgetTypography.titleLarge)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(3)
                    .invalidatableContent()
                Text("\(task.projectLabel) • \(task.dueLabel)")
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(WidgetBrand.textSecondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                TopTaskActionRow(task: task)
            } else {
                TaskWidgetEmptyState(title: "No open tasks", symbol: "tray")
                Spacer(minLength: 0)
                Link(destination: TaskWidgetRoutes.quickAdd) {
                    TaskWidgetActionBandLabel(title: "Add task", accent: WidgetBrand.actionPrimary)
                }
            }
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.quickAdd)
    }
}

struct TodayCounterNextWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Today",
            title: "Open tasks",
            detail: entry.snapshot.nextTask?.priorityCode,
            accent: WidgetBrand.actionPrimary
        ) {
            TaskWidgetHeroMetric(
                eyebrow: "Open today",
                value: "\(entry.snapshot.openCount)",
                numericValue: Double(entry.snapshot.openCount),
                supporting: entry.snapshot.nextTask?.title ?? "No open tasks",
                accent: WidgetBrand.actionPrimary
            )
            if let task = entry.snapshot.nextTask {
                Text(task.dueLabel)
                    .font(TaskWidgetTypography.caption)
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct OverdueRescueWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Rescue",
            title: "Rescue",
            detail: "\(entry.snapshot.overdueCount)",
            accent: WidgetBrand.sunriseGold
        ) {
            TaskWidgetHeroMetric(
                eyebrow: "From earlier",
                value: "\(entry.snapshot.overdueCount)",
                numericValue: Double(entry.snapshot.overdueCount),
                supporting: entry.snapshot.overdueTasks.first?.title ?? "Nothing from earlier",
                accent: WidgetBrand.sunriseGold
            )
            if let task = entry.snapshot.overdueTasks.first {
                Text(task.dueLabel)
                    .font(TaskWidgetTypography.caption)
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.overdue)
    }
}

struct QuickWin15mWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Short",
            title: "Quick task",
            detail: "15 min",
            accent: WidgetBrand.sandstone
        ) {
            if let task = entry.snapshot.quickWins.first {
                Text(task.title)
                    .font(TaskWidgetTypography.titleLarge)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(3)
                Text("\(task.estimateLabel) • \(task.projectLabel)")
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(WidgetBrand.textSecondary)
            } else {
                TaskWidgetEmptyState(title: "No short tasks", symbol: "sparkles")
            }
        }
        .widgetURL(entry.snapshot.quickWins.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct MorningKickoffWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Morning",
            title: "First task",
            detail: nil,
            accent: WidgetBrand.actionPrimary
        ) {
            if let task = entry.snapshot.morningTasks.first {
                Text(task.title)
                    .font(TaskWidgetTypography.titleLarge)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(3)
                Text(task.shortDueLabel)
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(WidgetBrand.textSecondary)
            } else {
                TaskWidgetEmptyState(title: "No morning tasks", symbol: "sun.horizon")
            }
        }
        .widgetURL(entry.snapshot.morningTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct EveningWrapWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Evening",
            title: "Wrap-up",
            detail: nil,
            accent: WidgetBrand.emerald
        ) {
            TaskWidgetHeroMetric(
                eyebrow: "Done today",
                value: "\(entry.snapshot.doneTodayCount)",
                numericValue: Double(entry.snapshot.doneTodayCount),
                supporting: entry.snapshot.overdueCount == 0 ? "All clear" : "\(entry.snapshot.overdueCount) from earlier",
                accent: WidgetBrand.emerald
            )
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct WaitingOnWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Blocked",
            title: "Waiting on",
            detail: "\(entry.snapshot.waitingOn.count)",
            accent: WidgetBrand.magenta
        ) {
            TaskWidgetHeroMetric(
                eyebrow: "Blocked",
                value: "\(entry.snapshot.waitingOn.count)",
                numericValue: Double(entry.snapshot.waitingOn.count),
                supporting: entry.snapshot.waitingOn.first?.title ?? "No blocked tasks",
                accent: WidgetBrand.magenta
            )
            if let task = entry.snapshot.waitingOn.first {
                Text(task.projectLabel)
                    .font(TaskWidgetTypography.caption)
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .widgetURL(entry.snapshot.waitingOn.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct InboxTriageWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let inboxTasks = entry.snapshot.inboxTasks

        return SmallStoryShell(
            eyebrow: "Capture",
            title: "Inbox",
            detail: "\(inboxTasks.count)",
            accent: WidgetBrand.sandstone
        ) {
            TaskWidgetHeroMetric(
                eyebrow: "In Inbox",
                value: "\(inboxTasks.count)",
                numericValue: Double(inboxTasks.count),
                supporting: inboxTasks.first?.title ?? "Inbox is empty",
                accent: WidgetBrand.sandstone
            )
        }
        .widgetURL(inboxTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct DueSoonRadarWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        SmallStoryShell(
            eyebrow: "Upcoming",
            title: "Due soon",
            detail: "\(entry.snapshot.dueSoonTasks.count)",
            accent: WidgetBrand.sunriseGold
        ) {
            TaskWidgetHeroMetric(
                eyebrow: "Next 2 days",
                value: "\(entry.snapshot.dueSoonTasks.count)",
                numericValue: Double(entry.snapshot.dueSoonTasks.count),
                supporting: entry.snapshot.dueSoonTasks.first?.title ?? "Nothing due soon",
                accent: WidgetBrand.sunriseGold
            )
            if let task = entry.snapshot.dueSoonTasks.first {
                Text(task.dueLabel)
                    .font(TaskWidgetTypography.caption)
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .widgetURL(entry.snapshot.dueSoonTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

struct EnergyMatchWidgetView: View {
    let entry: TaskListEntry

    private var topBucket: TaskListWidgetEnergyBucket? {
        entry.snapshot.energyBuckets.max(by: { $0.count < $1.count })
    }

    private var matchingTask: TaskListWidgetTask? {
        guard let topBucket else { return nil }
        return entry.snapshot.allOpenTasks.first {
            $0.energy.caseInsensitiveCompare(topBucket.energy) == .orderedSame
        }
    }

    var body: some View {
        SmallStoryShell(
            eyebrow: "Energy",
            title: "Best match",
            detail: nil,
            accent: WidgetBrand.actionPrimary
        ) {
            if let topBucket {
                TaskWidgetHeroMetric(
                    eyebrow: normalizedBucketLabel(topBucket.energy, fallback: "Medium"),
                    value: "\(topBucket.count)",
                    numericValue: Double(topBucket.count),
                    supporting: matchingTask?.title ?? "No match",
                    accent: WidgetBrand.actionPrimary
                )
            } else {
                TaskWidgetEmptyState(title: "No energy set", symbol: "bolt")
            }
        }
        .widgetURL(matchingTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct ProjectSpotlightWidgetView: View {
    let entry: TaskListEntry

    private var slice: TaskListWidgetProjectSlice? {
        entry.snapshot.projectSlices.first
    }

    var body: some View {
        SmallStoryShell(
            eyebrow: "Project",
            title: "Spotlight",
            detail: nil,
            accent: WidgetBrand.actionPrimary
        ) {
            if let slice {
                Text(slice.projectName)
                    .font(TaskWidgetTypography.titleLarge)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    TaskWidgetSummaryPill(title: "Open", value: "\(slice.openCount)", numericValue: Double(slice.openCount), tint: WidgetBrand.actionPrimary)
                    TaskWidgetSummaryPill(title: "Rescue", value: "\(slice.overdueCount)", numericValue: Double(slice.overdueCount), tint: WidgetBrand.goldInk)
                }
            } else {
                TaskWidgetEmptyState(title: "No active projects", symbol: "square.grid.2x2")
            }
        }
        .widgetURL(slice?.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today)
    }
}

struct CalendarTaskBridgeWidgetView: View {
    let entry: TaskListEntry

    private var dueToday: [TaskListWidgetTask] {
        entry.snapshot.allOpenTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }
    }

    var body: some View {
        SmallStoryShell(
            eyebrow: "Today",
            title: "Scheduled",
            detail: "\(dueToday.count) today",
            accent: WidgetBrand.sandstone
        ) {
            TaskWidgetHeroMetric(
                eyebrow: "Due today",
                value: "\(dueToday.count)",
                numericValue: Double(dueToday.count),
                supporting: (dueToday.first ?? entry.snapshot.upcomingTasks.first)?.title ?? "Nothing scheduled",
                accent: WidgetBrand.sandstone
            )
            Text("Next 48 hr: \(entry.snapshot.upcomingTasks.count)")
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(WidgetBrand.textSecondary)
        }
        .widgetURL((dueToday.first ?? entry.snapshot.upcomingTasks.first).map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

// MARK: - Home Widgets (Medium)

private struct ScopeChipView: View {
    let title: String
    let count: Int
    let tint: Color
    let url: URL
    let scope: TaskWidgetScope

    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            Button(intent: OpenTaskScopeIntent(scope: scope)) {
                label
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: url) {
                label
            }
        }
    }

    private var label: some View {
        HStack {
            Text(title)
                .font(TaskWidgetTypography.captionStrong)
            Spacer(minLength: 6)
            Text("\(count)")
                .font(TaskWidgetTypography.meta)
                .foregroundStyle(tint)
                .widgetAccentable()
        }
        .foregroundStyle(WidgetBrand.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WidgetBrand.canvasElevated, in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.34), lineWidth: 1)
        )
    }
}

struct TodayTop3WidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(
                        eyebrow: "Today",
                        title: "Top tasks",
                        detail: "\(entry.snapshot.doneTodayCount) done",
                        accent: WidgetBrand.textPrimary
                    )
                    if let task = entry.snapshot.todayTopTasks.first {
                        Text(task.title)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        Text("\(task.projectLabel) • \(task.dueLabel)")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    } else {
                        TaskWidgetEmptyState(title: "No tasks today", symbol: "sun.max")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(
                        eyebrow: "After that",
                        title: "Also today",
                        detail: nil,
                        accent: WidgetBrand.textPrimary
                    )
                    if entry.snapshot.todayTopTasks.isEmpty {
                        TaskWidgetEmptyState(title: "Nothing else today", symbol: "checkmark")
                    } else {
                        TaskWidgetTaskList(
                            tasks: entry.snapshot.todayTopTasks,
                            limit: 3,
                            subtitle: { $0.projectLabel },
                            trailing: { $0.priorityCode },
                            trailingTint: { WidgetBrand.priority($0.priorityCode) }
                        )
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.todayTopTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct NowLaneWidgetView: View {
    let entry: TaskListEntry

    private var tasks: [TaskListWidgetTask] {
        entry.snapshot.focusNow.isEmpty ? entry.snapshot.todayTopTasks : entry.snapshot.focusNow
    }

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Focus", title: "Now", detail: nil, accent: WidgetBrand.textPrimary)
                    if let lead = tasks.first {
                        Text(lead.title)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        Text("\(lead.projectLabel) • \(lead.priorityCode)")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    } else {
                        TaskWidgetEmptyState(title: "Nothing now", symbol: "target")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Later", title: "Next up", detail: nil, accent: WidgetBrand.textPrimary)
                    TaskWidgetTaskList(
                        tasks: tasks.dropFirstArray(),
                        limit: 3,
                        subtitle: { $0.projectLabel },
                        trailing: { $0.priorityCode },
                        trailingTint: { WidgetBrand.priority($0.priorityCode) }
                    )
                }
            }
        }
        .widgetURL(tasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct OverdueBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.sunriseGold, padding: 12) {
                    TaskWidgetHeroMetric(
                        eyebrow: "From earlier",
                        value: "\(entry.snapshot.overdueCount)",
                        numericValue: Double(entry.snapshot.overdueCount),
                        supporting: entry.snapshot.overdueTasks.first?.title ?? "Nothing from earlier",
                        accent: WidgetBrand.sunriseGold
                    )
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sunriseGold, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Rescue", title: "By priority", detail: nil, accent: WidgetBrand.textPrimary)
                        TaskWidgetTaskList(
                            tasks: entry.snapshot.overdueTasks,
                            limit: context.supportListLimit,
                            subtitle: { $0.dueLabel },
                            trailing: { $0.priorityCode },
                            trailingTint: { WidgetBrand.priority($0.priorityCode) }
                        )
                }
            }
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.overdue)
    }
}

struct Upcoming48hWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Upcoming", title: "Next 48 hr", detail: nil, accent: WidgetBrand.textPrimary)
                    if let lead = entry.snapshot.upcomingTasks.first {
                        Text(lead.title)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        Text("Due \(lead.dueLabel)")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    } else {
                        TaskWidgetEmptyState(title: "Nothing due in 48 hr", symbol: "calendar")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Then", title: "By due date", detail: nil, accent: WidgetBrand.textPrimary)
                        TaskWidgetTaskList(
                            tasks: entry.snapshot.upcomingTasks,
                            limit: context.supportListLimit,
                            subtitle: { $0.projectLabel },
                            trailing: { $0.dueLabel },
                            trailingTint: { _ in WidgetBrand.textSecondary }
                        )
                }
            }
        }
        .widgetURL(entry.snapshot.upcomingTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

struct MorningEveningPlanWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Morning", title: "Start", detail: nil, accent: WidgetBrand.actionPrimary)
                    if entry.snapshot.morningTasks.isEmpty {
                        TaskWidgetEmptyState(title: "No morning tasks", symbol: "sunrise")
                    } else {
                        TaskWidgetTaskList(tasks: entry.snapshot.morningTasks, limit: context.supportListLimit, subtitle: { $0.shortDueLabel })
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Evening", title: "Finish", detail: nil, accent: WidgetBrand.sandstone)
                    if entry.snapshot.eveningTasks.isEmpty {
                        TaskWidgetEmptyState(title: "No evening tasks", symbol: "moon.stars")
                    } else {
                        TaskWidgetTaskList(tasks: entry.snapshot.eveningTasks, limit: context.supportListLimit, subtitle: { $0.shortDueLabel })
                    }
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct QuickViewSwitcherWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Today",
                        value: "\(entry.snapshot.todayTopTasks.count)",
                        numericValue: Double(entry.snapshot.todayTopTasks.count),
                        supporting: "Open a list",
                        accent: WidgetBrand.actionPrimary
                    )
                }
            } trailing: {
                VStack(alignment: .leading, spacing: 8) {
                    ScopeChipView(title: "Today", count: entry.snapshot.todayTopTasks.count, tint: WidgetBrand.actionPrimary, url: TaskWidgetRoutes.today, scope: .today)
                    ScopeChipView(title: "Upcoming", count: entry.snapshot.upcomingTasks.count, tint: WidgetBrand.sandstone, url: TaskWidgetRoutes.upcoming, scope: .upcoming)
                    ScopeChipView(title: "Rescue", count: entry.snapshot.overdueTasks.count, tint: WidgetBrand.sunriseGold, url: TaskWidgetRoutes.overdue, scope: .overdue)
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct ProjectSprintWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Projects", title: "Busiest", detail: "\(entry.snapshot.projectSlices.count) active", accent: WidgetBrand.textPrimary)
                    if let lead = entry.snapshot.projectSlices.first {
                        Text(lead.projectName)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(2)
                        HStack(spacing: 12) {
                            TaskWidgetSummaryPill(title: "Open", value: "\(lead.openCount)", numericValue: Double(lead.openCount), tint: WidgetBrand.actionPrimary)
                            TaskWidgetSummaryPill(title: "Rescue", value: "\(lead.overdueCount)", numericValue: Double(lead.overdueCount), tint: WidgetBrand.sunriseGold)
                        }
                    } else {
                        TaskWidgetEmptyState(title: "No active projects", symbol: "square.stack.3d.up")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "More", title: "Other projects", detail: nil, accent: WidgetBrand.textPrimary)
                    ForEach(Array(entry.snapshot.projectSlices.dropFirst().prefix(3))) { slice in
                        TaskWidgetTaskLine(
                            title: slice.projectName,
                            subtitle: "\(slice.openCount) open",
                            trailing: slice.overdueCount > 0 ? "!\(slice.overdueCount)" : nil,
                            trailingTint: WidgetBrand.sunriseGold,
                            destination: slice.projectID.map(TaskWidgetRoutes.project(_:))
                        )
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.projectSlices.first?.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today)
    }
}

struct PriorityMatrixLiteWidgetView: View {
    let entry: TaskListEntry

    private var counts: [String: Int] {
        entry.snapshot.priorityCounts
    }

    var body: some View {
        let high = counts["P0", default: 0] + counts["P1", default: 0]
        let medium = counts["P2", default: 0]
        let low = counts["P3", default: 0] + counts["P4", default: 0] + counts["P5", default: 0]

        return TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.red, padding: 12) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Priority",
                        value: "\(high)",
                        numericValue: Double(high),
                        supporting: "High priority",
                        accent: WidgetBrand.red
                    )
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "All", title: "By priority", detail: nil, accent: WidgetBrand.textPrimary)
                    VStack(alignment: .leading, spacing: 8) {
                        TaskWidgetTaskLine(title: "P0 / P1", trailing: "\(high)", trailingTint: WidgetBrand.red)
                        TaskWidgetTaskLine(title: "P2", trailing: "\(medium)", trailingTint: WidgetBrand.sunriseGold)
                        TaskWidgetTaskLine(title: "P3+", trailing: "\(low)", trailingTint: WidgetBrand.sandstone)
                    }
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct ContextWidgetView: View {
    let entry: TaskListEntry

    private var topContext: (key: String, value: Int)? {
        entry.snapshot.contextCounts.first
    }

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    if let topContext {
                        TaskWidgetHeroMetric(
                            eyebrow: "Context",
                            value: topContext.key,
                            supporting: topContext.value == 1 ? "1 task" : "\(topContext.value) tasks",
                            accent: WidgetBrand.sandstone,
                            alignment: .leading
                        )
                    } else {
                        TaskWidgetEmptyState(title: "No contexts", symbol: "tag")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Contexts", title: "All", detail: nil, accent: WidgetBrand.textPrimary)
                    ForEach(Array(entry.snapshot.contextCounts.prefix(4)), id: \.key) { contextBucket in
                        TaskWidgetTaskLine(
                            title: contextBucket.key,
                            trailing: "\(contextBucket.value)",
                            trailingTint: WidgetBrand.actionPrimary
                        )
                    }
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct FocusSessionQueueWidgetView: View {
    let entry: TaskListEntry

    private var queue: [TaskListWidgetTask] {
        entry.snapshot.focusNow.isEmpty ? entry.snapshot.todayTopTasks : entry.snapshot.focusNow
    }

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Focus", title: "Up next", detail: nil, accent: WidgetBrand.textPrimary)
                    if let lead = queue.first {
                        Text(lead.title)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        Text("\(lead.estimateLabel) • \(lead.energyLabel)")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    } else {
                        TaskWidgetEmptyState(title: "Nothing up next", symbol: "timer")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Then", title: "After that", detail: nil, accent: WidgetBrand.textPrimary)
                    TaskWidgetTaskList(tasks: queue.dropFirstArray(), limit: context.supportListLimit, subtitle: { "\($0.estimateLabel) • \($0.projectLabel)" })
                }
            }
        }
        .widgetURL(queue.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct RecoveryWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.sunriseGold, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Resume", title: "Pick up", detail: nil, accent: WidgetBrand.textPrimary)
                    if let task = entry.snapshot.nextTask {
                        Text(task.title)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        Text(task.projectLabel)
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    } else {
                        TaskWidgetEmptyState(title: "Nothing to pick up", symbol: "arrow.clockwise")
                    }
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Status", title: "Open", detail: nil, accent: WidgetBrand.textPrimary)
                    VStack(alignment: .leading, spacing: 8) {
                        TaskWidgetTaskLine(title: "Now", trailing: "\(entry.snapshot.focusNow.count)", trailingTint: WidgetBrand.actionPrimary)
                        TaskWidgetTaskLine(title: "Rescue", trailing: "\(entry.snapshot.overdueCount)", trailingTint: WidgetBrand.sunriseGold)
                        TaskWidgetTaskLine(title: "Blocked", trailing: "\(entry.snapshot.waitingOn.count)", trailingTint: WidgetBrand.magenta)
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct DoneReflectionWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            TaskWidgetTwoZone(spacing: context.panelSpacing) {
                TaskWidgetPanel(accent: WidgetBrand.emerald, padding: 12) {
                    TaskWidgetHeroMetric(
                        eyebrow: "Today",
                        value: "\(entry.snapshot.doneTodayCount)",
                        numericValue: Double(entry.snapshot.doneTodayCount),
                        supporting: entry.snapshot.doneTodayCount == 1 ? "task done" : "tasks done",
                        accent: WidgetBrand.emerald
                    )
                }
            } trailing: {
                TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Next", title: "Up next", detail: nil, accent: WidgetBrand.textPrimary)
                    if let task = entry.snapshot.nextTask {
                        TaskWidgetTaskLine(title: task.title, subtitle: task.projectLabel, trailing: task.priorityCode, trailingTint: WidgetBrand.priority(task.priorityCode), destination: TaskWidgetRoutes.task(task.id), emphasize: true)
                    } else {
                        TaskWidgetEmptyState(title: "No open tasks", symbol: "party.popper")
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

// MARK: - Home Widgets (Large)

private struct DeadlineHeatCell: View {
    let label: String
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(TaskWidgetTypography.eyebrow)
                .foregroundStyle(WidgetBrand.textSecondary)
            Text("\(count)")
                .font(TaskWidgetTypography.title)
                .foregroundStyle(count == 0 ? WidgetBrand.textSecondary : WidgetBrand.textPrimary)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(WidgetBrand.canvasElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((count == 0 ? WidgetBrand.line : WidgetBrand.red).opacity(0.34), lineWidth: 1)
        )
    }
}

struct TodayPlannerBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Today", title: "Plan", detail: "\(entry.snapshot.doneTodayCount) done", accent: WidgetBrand.textPrimary)
                HStack(spacing: 10) {
                    TaskWidgetSummaryPill(title: "Now", value: "\(entry.snapshot.todayTopTasks.count)", numericValue: Double(entry.snapshot.todayTopTasks.count), tint: WidgetBrand.actionPrimary)
                    TaskWidgetSummaryPill(title: "Rescue", value: "\(entry.snapshot.overdueTasks.count)", numericValue: Double(entry.snapshot.overdueTasks.count), tint: WidgetBrand.sunriseGold)
                    TaskWidgetSummaryPill(title: "Later", value: "\(entry.snapshot.upcomingTasks.count)", numericValue: Double(entry.snapshot.upcomingTasks.count), tint: WidgetBrand.sandstone)
                }
                TaskWidgetTwoZone(
                    spacing: context.panelSpacing,
                    leadingWeight: context.leadRatio,
                    trailingWeight: context.supportRatio
                ) {
                    TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                        TaskWidgetSectionHeader(eyebrow: "First", title: "Now", detail: nil, accent: WidgetBrand.textPrimary)
                        if let lead = entry.snapshot.todayTopTasks.first {
                            TaskWidgetTaskLine(
                                title: lead.title,
                                subtitle: "\(lead.projectLabel) • \(lead.dueLabel)",
                                trailing: lead.priorityCode,
                                trailingTint: WidgetBrand.priority(lead.priorityCode),
                                destination: TaskWidgetRoutes.task(lead.id),
                                emphasize: true
                            )
                        } else {
                            TaskWidgetEmptyState(title: "Nothing now", symbol: "target")
                        }
                    }
                } trailing: {
                    VStack(alignment: .leading, spacing: context.panelSpacing) {
                        TaskWidgetColumn(title: "Rescue", accent: WidgetBrand.sunriseGold, tasks: Array(entry.snapshot.overdueTasks.prefix(context.supportListLimit)), fallback: "Nothing from earlier")
                        TaskWidgetColumn(title: "Later", accent: WidgetBrand.sandstone, tasks: Array(entry.snapshot.upcomingTasks.prefix(context.supportListLimit)), fallback: "Nothing upcoming")
                    }
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct WeekTaskPlannerWidgetView: View {
    let entry: TaskListEntry

    private var datedTasks: [TaskListWidgetTask] {
        entry.snapshot.allOpenTasks
            .filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Plan", title: "This week", detail: nil, accent: WidgetBrand.textPrimary)
                TaskWidgetTwoZone(
                    spacing: context.panelSpacing,
                    leadingWeight: context.leadRatio,
                    trailingWeight: context.supportRatio
                ) {
                    TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 14) {
                        if let lead = datedTasks.first {
                            Text(lead.title)
                                .font(TaskWidgetTypography.titleLarge)
                                .foregroundStyle(WidgetBrand.textPrimary)
                                .lineLimit(3)
                            Text("Due \(lead.shortDueLabel)")
                                .font(TaskWidgetTypography.support)
                                .foregroundStyle(WidgetBrand.textSecondary)
                            HStack(spacing: 12) {
                                TaskWidgetSummaryPill(title: "Scheduled", value: "\(datedTasks.count)", numericValue: Double(datedTasks.count), tint: WidgetBrand.sandstone)
                                TaskWidgetSummaryPill(title: "Rescue", value: "\(entry.snapshot.overdueCount)", numericValue: Double(entry.snapshot.overdueCount), tint: WidgetBrand.sunriseGold)
                            }
                        } else {
                            TaskWidgetEmptyState(title: "Nothing due this week", symbol: "calendar.badge.checkmark")
                        }
                    }
                } trailing: {
                    TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                        TaskWidgetSectionHeader(eyebrow: "Coming up", title: "By due date", detail: nil, accent: WidgetBrand.textPrimary)
                        TaskWidgetTaskList(tasks: datedTasks, limit: context.supportListLimit + 1, subtitle: { $0.projectLabel }, trailing: { $0.shortDueLabel })
                    }
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.weeklyPlanner)
    }
}

struct ProjectCockpitWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let lead = entry.snapshot.projectSlices.first

        return TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Projects", title: "Overview", detail: "\(entry.snapshot.projectSlices.count) active", accent: WidgetBrand.textPrimary)
                TaskWidgetTwoZone(
                    spacing: context.panelSpacing,
                    leadingWeight: context.leadRatio,
                    trailingWeight: context.supportRatio
                ) {
                    TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                        if let lead {
                            Text(lead.projectName)
                                .font(TaskWidgetTypography.display)
                                .foregroundStyle(WidgetBrand.textPrimary)
                                .lineLimit(2)
                            HStack(spacing: 14) {
                                TaskWidgetSummaryPill(title: "Open", value: "\(lead.openCount)", numericValue: Double(lead.openCount), tint: WidgetBrand.actionPrimary)
                                TaskWidgetSummaryPill(title: "Rescue", value: "\(lead.overdueCount)", numericValue: Double(lead.overdueCount), tint: WidgetBrand.sunriseGold)
                            }
                        } else {
                            TaskWidgetEmptyState(title: "No active projects", symbol: "square.stack.3d.down.right")
                        }
                    }
                } trailing: {
                    TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 14) {
                        TaskWidgetSectionHeader(eyebrow: "More", title: "Other projects", detail: nil, accent: WidgetBrand.textPrimary)
                        ForEach(Array(entry.snapshot.projectSlices.dropFirst().prefix(context.supportListLimit + 1))) { slice in
                            TaskWidgetTaskLine(
                                title: slice.projectName,
                                subtitle: "\(slice.openCount) open",
                                trailing: slice.overdueCount > 0 ? "!\(slice.overdueCount)" : nil,
                            trailingTint: WidgetBrand.sunriseGold,
                                destination: slice.projectID.map(TaskWidgetRoutes.project(_:))
                            )
                        }
                    }
                }
            }
        }
        .widgetURL(lead?.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today)
    }
}

struct BacklogHealthWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let blocked = entry.snapshot.waitingOn.count
        let inbox = entry.snapshot.inboxTasks.count

        return TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Backlog", title: "Overview", detail: nil, accent: WidgetBrand.textPrimary)
                HStack(spacing: 12) {
                    TaskWidgetSummaryPill(title: "Rescue", value: "\(entry.snapshot.overdueCount)", numericValue: Double(entry.snapshot.overdueCount), tint: WidgetBrand.sunriseGold)
                    TaskWidgetSummaryPill(title: "Blocked", value: "\(blocked)", numericValue: Double(blocked), tint: WidgetBrand.magenta)
                    TaskWidgetSummaryPill(title: "Inbox", value: "\(inbox)", numericValue: Double(inbox), tint: WidgetBrand.sandstone)
                }
                TaskWidgetTwoZone(
                    spacing: context.panelSpacing,
                    leadingWeight: context.leadRatio,
                    trailingWeight: context.supportRatio
                ) {
                    TaskWidgetPanel(accent: WidgetBrand.sunriseGold, padding: 14) {
                        Text(entry.snapshot.overdueCount == 0 && blocked == 0 ? "All clear" : "\(entry.snapshot.overdueCount) from earlier")
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(2)
                    }
                } trailing: {
                    TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                        TaskWidgetSectionHeader(eyebrow: "Rescue", title: "From earlier", detail: nil, accent: WidgetBrand.textPrimary)
                        TaskWidgetTaskList(tasks: entry.snapshot.overdueTasks, limit: context.supportListLimit + 1, subtitle: { $0.dueLabel }, trailing: { $0.priorityCode }, trailingTint: { WidgetBrand.priority($0.priorityCode) })
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct KanbanLiteWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Board", title: "Tasks", detail: nil, accent: WidgetBrand.textPrimary)
                TaskWidgetTwoZone(
                    spacing: context.panelSpacing,
                    leadingWeight: context.leadRatio,
                    trailingWeight: context.supportRatio
                ) {
                    TaskWidgetColumn(title: "Now", accent: WidgetBrand.actionPrimary, tasks: Array(entry.snapshot.todayTopTasks.prefix(context.supportListLimit)), fallback: "Empty")
                } trailing: {
                    VStack(alignment: .leading, spacing: context.panelSpacing) {
                        TaskWidgetColumn(title: "Rescue", accent: WidgetBrand.sunriseGold, tasks: Array(entry.snapshot.overdueTasks.prefix(context.supportListLimit)), fallback: "Empty")
                        TaskWidgetColumn(title: "Blocked", accent: WidgetBrand.magenta, tasks: Array(entry.snapshot.waitingOn.prefix(context.supportListLimit)), fallback: "Empty")
                    }
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

struct DeadlineHeatmapWidgetView: View {
    let entry: TaskListEntry

    private var buckets: [(offset: Int, label: String, count: Int)] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            let count = entry.snapshot.allOpenTasks.filter { task in
                guard let due = task.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }.count
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return (offset, formatter.string(from: day), count)
        }
    }

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Deadlines", title: "Next 7 days", detail: nil, accent: WidgetBrand.textPrimary)
                HStack(spacing: 8) {
                    ForEach(buckets, id: \.offset) { bucket in
                        DeadlineHeatCell(label: bucket.label, count: bucket.count)
                    }
                }
                TaskWidgetPanel(accent: WidgetBrand.red, padding: 14) {
                    if let next = entry.snapshot.nextDeadlineTask {
                        TaskWidgetTaskLine(
                            title: next.title,
                            subtitle: next.projectLabel,
                            trailing: next.shortDueLabel,
                            trailingTint: WidgetBrand.red,
                            destination: TaskWidgetRoutes.task(next.id),
                            emphasize: true
                        )
                    } else {
                        TaskWidgetEmptyState(title: "Nothing due this week", symbol: "calendar.badge.clock")
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.nextDeadlineTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

struct ExecutionDashboardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Today", title: "Overview", detail: nil, accent: WidgetBrand.textPrimary)
                HStack(spacing: 12) {
                    TaskWidgetSummaryPill(title: "Done", value: "\(entry.snapshot.doneTodayCount)", numericValue: Double(entry.snapshot.doneTodayCount), tint: WidgetBrand.emerald)
                    TaskWidgetSummaryPill(title: "Open", value: "\(entry.snapshot.openCount)", numericValue: Double(entry.snapshot.openCount), tint: WidgetBrand.actionPrimary)
                    TaskWidgetSummaryPill(title: "Rescue", value: "\(entry.snapshot.overdueCount)", numericValue: Double(entry.snapshot.overdueCount), tint: WidgetBrand.sunriseGold)
                    TaskWidgetSummaryPill(title: "Blocked", value: "\(entry.snapshot.waitingOn.count)", numericValue: Double(entry.snapshot.waitingOn.count), tint: WidgetBrand.magenta)
                }
                TaskWidgetTwoZone(
                    spacing: context.panelSpacing,
                    leadingWeight: context.leadRatio,
                    trailingWeight: context.supportRatio
                ) {
                    TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                        if let task = entry.snapshot.nextTask {
                            Text(task.title)
                                .font(TaskWidgetTypography.titleLarge)
                                .foregroundStyle(WidgetBrand.textPrimary)
                                .lineLimit(3)
                            Text("Next • \(task.projectLabel)")
                                .font(TaskWidgetTypography.support)
                                .foregroundStyle(WidgetBrand.textSecondary)
                        } else {
                            TaskWidgetEmptyState(title: "No next task", symbol: "bolt.badge.clock")
                        }
                    }
                } trailing: {
                    TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 14) {
                        TaskWidgetSectionHeader(eyebrow: "Also", title: "Now and rescue", detail: nil, accent: WidgetBrand.textPrimary)
                        TaskWidgetTaskList(tasks: entry.snapshot.focusNow + entry.snapshot.overdueTasks, limit: context.supportListLimit + 1, subtitle: { $0.projectLabel }, trailing: { $0.priorityCode }, trailingTint: { WidgetBrand.priority($0.priorityCode) })
                    }
                }
            }
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct DeepWorkAgendaWidgetView: View {
    let entry: TaskListEntry

    private var queue: [TaskListWidgetTask] {
        entry.snapshot.focusNow.isEmpty ? entry.snapshot.todayTopTasks : entry.snapshot.focusNow
    }

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Focus", title: "Agenda", detail: nil, accent: WidgetBrand.textPrimary)
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
                            Text("\(lead.estimateLabel) • \(lead.energyLabel) energy")
                                .font(TaskWidgetTypography.support)
                                .foregroundStyle(WidgetBrand.textSecondary)
                        } else {
                            TaskWidgetEmptyState(title: "Nothing up next", symbol: "brain.head.profile")
                        }
                    }
                } trailing: {
                    TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 14) {
                        TaskWidgetSectionHeader(eyebrow: "Short", title: "Quick tasks", detail: nil, accent: WidgetBrand.textPrimary)
                        TaskWidgetTaskList(tasks: entry.snapshot.quickWins + queue.dropFirstArray(), limit: context.supportListLimit + 1, subtitle: { "\($0.estimateLabel) • \($0.projectLabel)" })
                    }
                }
            }
        }
        .widgetURL(queue.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct AssistantPlanPreviewWidgetView: View {
    let entry: TaskListEntry

    private var planTasks: [TaskListWidgetTask] {
        uniqueTasks(entry.snapshot.focusNow + entry.snapshot.todayTopTasks + entry.snapshot.overdueTasks + entry.snapshot.upcomingTasks).prefixArray(3)
    }

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Eva", title: "Plan", detail: nil, accent: WidgetBrand.textPrimary)
                TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                    if planTasks.isEmpty {
                        TaskWidgetEmptyState(title: "No plan yet", symbol: "list.bullet.rectangle")
                    } else {
                        ForEach(Array(planTasks.enumerated()), id: \.element.id) { index, task in
                            TaskWidgetTaskLine(
                                title: "\(index + 1). \(task.title)",
                                subtitle: task.projectLabel,
                                trailing: task.priorityCode,
                                trailingTint: WidgetBrand.priority(task.priorityCode),
                                destination: TaskWidgetRoutes.task(task.id),
                                emphasize: index == 0
                            )
                        }
                    }
                }
            }
        }
        .widgetURL(planTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

struct LifeAreasBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Balance", title: "Life areas", detail: nil, accent: WidgetBrand.textPrimary)
                TaskWidgetTwoZone(spacing: context.panelSpacing) {
                    TaskWidgetPanel(accent: WidgetBrand.sandstone, padding: 14) {
                        TaskWidgetHeroMetric(
                            eyebrow: "Active projects",
                            value: "\(entry.snapshot.projectSlices.count)",
                            numericValue: Double(entry.snapshot.projectSlices.count),
                            supporting: "With open tasks",
                            accent: WidgetBrand.sandstone
                        )
                    }
                } trailing: {
                    TaskWidgetPanel(accent: WidgetBrand.actionPrimary, padding: 14) {
                        TaskWidgetSectionHeader(eyebrow: "Energy", title: "By energy", detail: nil, accent: WidgetBrand.textPrimary)
                        ForEach(Array(entry.snapshot.energyBuckets.prefix(4))) { bucket in
                            TaskWidgetTaskLine(
                                title: normalizedBucketLabel(bucket.energy, fallback: "Medium"),
                                trailing: "\(bucket.count)",
                                trailingTint: WidgetBrand.actionPrimary
                            )
                        }
                    }
                }
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private extension Array {
    func prefixArray(_ limit: Int) -> [Element] {
        Array(prefix(limit))
    }

    func dropFirstArray() -> [Element] {
        Array(dropFirst())
    }
}
