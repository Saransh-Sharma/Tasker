import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct TaskerWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Existing gamification widgets.
        TodayXPWidget()
        WeeklyScoreboardWidget()
        NextMilestoneWidget()
        StreakResilienceWidget()
        FocusSeedWidget()

        // Home Screen - Small
        TaskListStaticWidget(
            kind: "TopTaskNowWidget",
            displayName: "Top Task Now",
            description: "Focus on one next task and act quickly.",
            families: [.systemSmall]
        ) { entry in
            TopTaskNowWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "TodayCounterNextWidget",
            displayName: "Today Counter + Next",
            description: "Open count plus the next actionable task.",
            families: [.systemSmall]
        ) { entry in
            TodayCounterNextWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "OverdueRescueWidget",
            displayName: "Overdue Rescue",
            description: "Rescue your oldest overdue task first.",
            families: [.systemSmall]
        ) { entry in
            OverdueRescueWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "QuickWin15mWidget",
            displayName: "Quick Win 15m",
            description: "Grab a short high-impact task.",
            families: [.systemSmall]
        ) { entry in
            QuickWin15mWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "MorningKickoffWidget",
            displayName: "Morning Kickoff",
            description: "Start the day with a clear first task.",
            families: [.systemSmall]
        ) { entry in
            MorningKickoffWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "EveningWrapWidget",
            displayName: "Evening Wrap",
            description: "Check progress and prepare carry-over.",
            families: [.systemSmall]
        ) { entry in
            EveningWrapWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "WaitingOnWidget",
            displayName: "Waiting On",
            description: "Track blocked tasks with dependencies.",
            families: [.systemSmall]
        ) { entry in
            WaitingOnWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "InboxTriageWidget",
            displayName: "Inbox Triage",
            description: "Process unassigned inbox tasks quickly.",
            families: [.systemSmall]
        ) { entry in
            InboxTriageWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DueSoonRadarWidget",
            displayName: "Due Soon Radar",
            description: "Surface upcoming deadlines before they slip.",
            families: [.systemSmall]
        ) { entry in
            DueSoonRadarWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "EnergyMatchWidget",
            displayName: "Energy Match",
            description: "Pick tasks that match your current energy.",
            families: [.systemSmall]
        ) { entry in
            EnergyMatchWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectSpotlightWidget",
            displayName: "Project Spotlight",
            description: "Stay on top of your busiest project.",
            families: [.systemSmall]
        ) { entry in
            ProjectSpotlightWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CalendarTaskBridgeWidget",
            displayName: "Calendar-Task Bridge",
            description: "Connect time-bound tasks with your day plan.",
            families: [.systemSmall]
        ) { entry in
            CalendarTaskBridgeWidgetView(entry: entry)
        }

        // Home Screen - Medium
        TaskListStaticWidget(
            kind: "TodayTop3Widget",
            displayName: "Today Top 3",
            description: "See your top three tasks for today.",
            families: [.systemMedium]
        ) { entry in
            TodayTop3WidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "NowLaneWidget",
            displayName: "Now Lane",
            description: "Bounded now-list for immediate execution.",
            families: [.systemMedium]
        ) { entry in
            NowLaneWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "OverdueBoardWidget",
            displayName: "Overdue Board",
            description: "See overdue work ranked for recovery.",
            families: [.systemMedium]
        ) { entry in
            OverdueBoardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "Upcoming48hWidget",
            displayName: "Upcoming 48h",
            description: "Preview the next deadlines in two days.",
            families: [.systemMedium]
        ) { entry in
            Upcoming48hWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "MorningEveningPlanWidget",
            displayName: "Morning vs Evening Plan",
            description: "Split today into start and finish lanes.",
            families: [.systemMedium]
        ) { entry in
            MorningEveningPlanWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "QuickViewSwitcherWidget",
            displayName: "Quick View Switcher",
            description: "Jump between Today, Upcoming, and Overdue.",
            families: [.systemMedium]
        ) { entry in
            QuickViewSwitcherWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectSprintWidget",
            displayName: "Project Sprint",
            description: "See active projects and their task load.",
            families: [.systemMedium]
        ) { entry in
            ProjectSprintWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "PriorityMatrixLiteWidget",
            displayName: "Priority Matrix Lite",
            description: "Quickly balance high and low priority work.",
            families: [.systemMedium]
        ) { entry in
            PriorityMatrixLiteWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ContextWidget",
            displayName: "Context Widget",
            description: "Filter momentum by @context buckets.",
            families: [.systemMedium]
        ) { entry in
            ContextWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "FocusSessionQueueWidget",
            displayName: "Focus Session Queue",
            description: "Queue up focused work blocks.",
            families: [.systemMedium]
        ) { entry in
            FocusSessionQueueWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RecoveryWidget",
            displayName: "Recovery Widget",
            description: "Resume in-progress momentum after interruption.",
            families: [.systemMedium]
        ) { entry in
            RecoveryWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DoneReflectionWidget",
            displayName: "Done Reflection",
            description: "Reflect on wins and keep momentum.",
            families: [.systemMedium]
        ) { entry in
            DoneReflectionWidgetView(entry: entry)
        }

        // Home Screen - Large
        TaskListStaticWidget(
            kind: "TodayPlannerBoardWidget",
            displayName: "Today Planner Board",
            description: "Plan across overdue, now, and next lanes.",
            families: [.systemLarge]
        ) { entry in
            TodayPlannerBoardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "WeekTaskPlannerWidget",
            displayName: "Week Task Planner",
            description: "Map critical tasks across the next 7 days.",
            families: [.systemLarge]
        ) { entry in
            WeekTaskPlannerWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectCockpitWidget",
            displayName: "Project Cockpit",
            description: "Top project slices with workload and risk.",
            families: [.systemLarge]
        ) { entry in
            ProjectCockpitWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "BacklogHealthWidget",
            displayName: "Backlog Health",
            description: "Monitor overdue, blocked, and intake pressure.",
            families: [.systemLarge]
        ) { entry in
            BacklogHealthWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "KanbanLiteWidget",
            displayName: "Kanban Lite",
            description: "Compact board for rescue, now, and blocked.",
            families: [.systemLarge]
        ) { entry in
            KanbanLiteWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DeadlineHeatmapWidget",
            displayName: "Deadline Heatmap",
            description: "Visualize due-date concentration this week.",
            families: [.systemLarge]
        ) { entry in
            DeadlineHeatmapWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ExecutionDashboardWidget",
            displayName: "Execution Dashboard",
            description: "At-a-glance execution and throughput status.",
            families: [.systemLarge]
        ) { entry in
            ExecutionDashboardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DeepWorkAgendaWidget",
            displayName: "Deep Work Agenda",
            description: "High-focus queue for uninterrupted sessions.",
            families: [.systemLarge]
        ) { entry in
            DeepWorkAgendaWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "AssistantPlanPreviewWidget",
            displayName: "Assistant Plan Preview",
            description: "Read-only preview of your next actions.",
            families: [.systemLarge]
        ) { entry in
            AssistantPlanPreviewWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "LifeAreasBoardWidget",
            displayName: "Life Areas Board",
            description: "Balance your workload by project and energy.",
            families: [.systemLarge]
        ) { entry in
            LifeAreasBoardWidgetView(entry: entry)
        }

        // Lock Screen / Accessory
        TaskListStaticWidget(
            kind: "InlineNextTaskWidget",
            displayName: "Inline Next Task",
            description: "Lock screen inline next task.",
            families: [.accessoryInline],
            usesContainerBackground: false
        ) { entry in
            InlineNextTaskWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CircularTodayProgressWidget",
            displayName: "Circular Today Progress",
            description: "Lock screen progress ring for today tasks.",
            families: [.accessoryCircular],
            usesContainerBackground: false
        ) { entry in
            CircularTodayProgressWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularTop2TasksWidget",
            displayName: "Rectangular Top 2 Tasks",
            description: "Lock screen top two priorities.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularTop2TasksWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularOverdueAlertWidget",
            displayName: "Rectangular Overdue Alert",
            description: "Lock screen overdue summary.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularOverdueAlertWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CircularQuickAddWidget",
            displayName: "Circular Quick Add",
            description: "One-tap capture from lock screen.",
            families: [.accessoryCircular],
            usesContainerBackground: false
        ) { entry in
            CircularQuickAddWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularFocusNowWidget",
            displayName: "Rectangular Focus Now",
            description: "Current focus lane in lock screen format.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularFocusNowWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "InlineDueSoonWidget",
            displayName: "Inline Due Soon",
            description: "Inline next due task and timing.",
            families: [.accessoryInline],
            usesContainerBackground: false
        ) { entry in
            InlineDueSoonWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularWaitingOnWidget",
            displayName: "Rectangular Waiting On",
            description: "Blocked tasks in lock screen summary.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularWaitingOnWidgetView(entry: entry)
        }

        // StandBy
        TaskListStaticWidget(
            kind: "DeskTodayBoardWidget",
            displayName: "Desk Today Board",
            description: "StandBy-ready summary of today and overdue work.",
            families: [.systemMedium]
        ) { entry in
            DeskTodayBoardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CountdownPanelWidget",
            displayName: "Countdown Panel",
            description: "Countdown to the next meaningful deadline.",
            families: [.systemMedium]
        ) { entry in
            CountdownPanelWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "FocusDockWidget",
            displayName: "Focus Dock",
            description: "Keep your current focus lane visible.",
            families: [.systemMedium]
        ) { entry in
            FocusDockWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "NightlyResetWidget",
            displayName: "Nightly Reset",
            description: "Close the day and queue tomorrow cleanly.",
            families: [.systemMedium]
        ) { entry in
            NightlyResetWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "MorningBriefPanelWidget",
            displayName: "Morning Brief Panel",
            description: "A compact morning launch briefing.",
            families: [.systemMedium]
        ) { entry in
            MorningBriefPanelWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectPulseWidget",
            displayName: "Project Pulse",
            description: "Live pulse of project workload health.",
            families: [.systemMedium]
        ) { entry in
            ProjectPulseWidgetView(entry: entry)
        }
    }
}

// MARK: - Shared Provider

struct TaskListEntry: TimelineEntry {
    let date: Date
    let snapshot: TaskListWidgetSnapshot
    let gamificationSnapshot: GamificationWidgetSnapshot
}

struct TaskListProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskListEntry {
        TaskListEntry(
            date: Date(),
            snapshot: TaskListWidgetSnapshot(
                todayTopTasks: [
                    TaskListWidgetTask(
                        id: UUID(),
                        title: "Ship widget MVP",
                        projectName: "Tasker",
                        priorityCode: "P1",
                        dueDate: Date().addingTimeInterval(60 * 60),
                        estimatedDurationMinutes: 25,
                        energy: "high",
                        context: "computer"
                    )
                ],
                upcomingTasks: [
                    TaskListWidgetTask(
                        id: UUID(),
                        title: "Review backlog",
                        projectName: "Work",
                        priorityCode: "P2",
                        dueDate: Date().addingTimeInterval(3 * 60 * 60),
                        estimatedDurationMinutes: 15,
                        energy: "medium",
                        context: "office"
                    )
                ],
                overdueTasks: [
                    TaskListWidgetTask(
                        id: UUID(),
                        title: "Pay utility bill",
                        projectName: "Personal",
                        priorityCode: "P2",
                        dueDate: Date().addingTimeInterval(-6 * 60 * 60),
                        isOverdue: true,
                        estimatedDurationMinutes: 5,
                        energy: "low",
                        context: "phone"
                    )
                ],
                quickWins: [
                    TaskListWidgetTask(
                        id: UUID(),
                        title: "Reply to stakeholder",
                        projectName: "Tasker",
                        priorityCode: "P2",
                        dueDate: Date().addingTimeInterval(2 * 60 * 60),
                        estimatedDurationMinutes: 10,
                        energy: "low",
                        context: "computer"
                    )
                ],
                projectSlices: [
                    TaskListWidgetProjectSlice(projectName: "Tasker", openCount: 5, overdueCount: 1),
                    TaskListWidgetProjectSlice(projectName: "Personal", openCount: 2, overdueCount: 1)
                ],
                doneTodayCount: 2,
                focusNow: [],
                waitingOn: [],
                energyBuckets: [
                    TaskListWidgetEnergyBucket(energy: "low", count: 2),
                    TaskListWidgetEnergyBucket(energy: "medium", count: 2),
                    TaskListWidgetEnergyBucket(energy: "high", count: 1)
                ],
                openTodayCount: 4
            ),
            gamificationSnapshot: GamificationWidgetSnapshot()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskListEntry) -> Void) {
        completion(TaskListEntry(
            date: Date(),
            snapshot: resolvedTaskSnapshot(),
            gamificationSnapshot: GamificationWidgetSnapshot.load()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskListEntry>) -> Void) {
        let entry = TaskListEntry(
            date: Date(),
            snapshot: resolvedTaskSnapshot(),
            gamificationSnapshot: GamificationWidgetSnapshot.load()
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func resolvedTaskSnapshot() -> TaskListWidgetSnapshot {
        guard TaskWidgetFeatureGate.taskListWidgetsEnabled else {
            return TaskListWidgetSnapshot(
                snapshotHealth: TaskListWidgetSnapshotHealth(
                    source: "feature_disabled",
                    generatedAt: Date(),
                    isStale: true,
                    hasCorruptionFallback: false
                )
            )
        }
        return TaskListWidgetSnapshot.load()
    }
}

private struct TaskListStaticWidget: Widget {
    let kind: String
    let displayName: String
    let description: String
    let families: [WidgetFamily]
    var usesContainerBackground: Bool = true
    let content: (TaskListEntry) -> AnyView

    init(
        kind: String,
        displayName: String,
        description: String,
        families: [WidgetFamily],
        usesContainerBackground: Bool = true,
        @ViewBuilder content: @escaping (TaskListEntry) -> some View
    ) {
        self.kind = kind
        self.displayName = displayName
        self.description = description
        self.families = families
        self.usesContainerBackground = usesContainerBackground
        self.content = { entry in AnyView(content(entry)) }
    }

    init() {
        self.kind = "TaskListStaticWidget"
        self.displayName = "Task List"
        self.description = "Task list widget"
        self.families = [.systemSmall]
        self.usesContainerBackground = true
        self.content = { _ in AnyView(EmptyView()) }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskListProvider()) { entry in
            content(entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: usesContainerBackground))
        }
        .configurationDisplayName(displayName)
        .description(description)
        .supportedFamilies(families)
    }
}

private struct TaskWidgetContainerBackgroundModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.containerBackground(.fill.tertiary, for: .widget)
        } else {
            content
        }
    }
}

private enum TaskWidgetRoutes {
    static var today: URL { URL(string: "tasker://tasks/today")! }
    static var upcoming: URL { URL(string: "tasker://tasks/upcoming")! }
    static var overdue: URL { URL(string: "tasker://tasks/overdue")! }
    static var quickAdd: URL { URL(string: "tasker://quickadd")! }

    static func task(_ id: UUID) -> URL {
        URL(string: "tasker://task/\(id.uuidString)")!
    }

    static func project(_ id: UUID) -> URL {
        URL(string: "tasker://tasks/project/\(id.uuidString)")!
    }
}

private enum TaskWidgetFeatureGate {
    private static let taskListWidgetsKey = "feature.task_list.widgets"
    private static let interactiveTaskWidgetsKey = "feature.task_list.widgets.interactive"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.suiteName)
    }

    static var taskListWidgetsEnabled: Bool {
        (sharedDefaults?.object(forKey: taskListWidgetsKey) as? Bool) ?? true
    }

    static var interactiveTaskWidgetsEnabled: Bool {
        (sharedDefaults?.object(forKey: interactiveTaskWidgetsKey) as? Bool) ?? true
    }
}

private extension TaskListWidgetSnapshot {
    var nextTask: TaskListWidgetTask? {
        focusNow.first ?? todayTopTasks.first ?? overdueTasks.first ?? upcomingTasks.first ?? openTaskPool.first
    }

    var overdueCount: Int {
        overdueTasks.count
    }

    var openCount: Int {
        max(openTodayCount, allOpenTasks.count)
    }

    var hasAnyTasks: Bool {
        !allOpenTasks.isEmpty
    }

    var allOpenTasks: [TaskListWidgetTask] {
        if openTaskPool.isEmpty == false {
            return openTaskPool
        }
        return uniqueTasks(todayTopTasks + upcomingTasks + overdueTasks + focusNow + waitingOn + quickWins)
    }

    var inboxTasks: [TaskListWidgetTask] {
        allOpenTasks.filter { task in
            let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return task.projectID == nil || projectName.isEmpty || projectName.caseInsensitiveCompare("Inbox") == .orderedSame
        }
    }

    var morningTasks: [TaskListWidgetTask] {
        let candidates = allOpenTasks.filter { $0.isMorningCandidate }
        return candidates.isEmpty ? todayTopTasks : candidates
    }

    var eveningTasks: [TaskListWidgetTask] {
        let candidates = allOpenTasks.filter { $0.isEveningCandidate }
        return candidates.isEmpty ? upcomingTasks : candidates
    }

    var dueSoonTasks: [TaskListWidgetTask] {
        upcomingTasks
    }

    var nextDeadlineTask: TaskListWidgetTask? {
        allOpenTasks
            .filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
            .first
    }

    var contextCounts: [(key: String, value: Int)] {
        let grouped = Dictionary(grouping: allOpenTasks, by: { normalizedBucketLabel($0.context, fallback: "Any") })
        return grouped
            .map { (key: $0.key, value: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
    }

    var priorityCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for task in allOpenTasks {
            counts[task.priorityCode, default: 0] += 1
        }
        return counts
    }

    var completionProgress: Double {
        let total = Double(max(doneTodayCount + openCount, 1))
        return min(max(Double(doneTodayCount) / total, 0), 1)
    }
}

private enum TaskWidgetFormatters {
    static let relativeDueFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static let shortDueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E HH:mm"
        return formatter
    }()

    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
}

private extension TaskListWidgetTask {
    var dueLabel: String {
        guard let dueDate else { return "No due" }
        return TaskWidgetFormatters.relativeDueFormatter.localizedString(for: dueDate, relativeTo: Date())
    }

    var shortDueLabel: String {
        guard let dueDate else { return "No due" }
        return TaskWidgetFormatters.shortDueFormatter.string(from: dueDate)
    }

    var projectLabel: String {
        let candidate = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (candidate?.isEmpty == false) ? candidate! : "Inbox"
    }

    var energyLabel: String {
        normalizedBucketLabel(energy, fallback: "Medium")
    }

    var contextLabel: String {
        normalizedBucketLabel(context, fallback: "Any")
    }

    var estimateLabel: String {
        guard let minutes = estimatedDurationMinutes else { return "--" }
        return "\(minutes)m"
    }

    var isMorningCandidate: Bool {
        guard let dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour < 13
    }

    var isEveningCandidate: Bool {
        guard let dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 17
    }
}

private func normalizedBucketLabel(_ raw: String, fallback: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return fallback }
    return trimmed
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "@", with: "")
        .capitalized
}

private func uniqueTasks(_ tasks: [TaskListWidgetTask]) -> [TaskListWidgetTask] {
    var seen = Set<UUID>()
    var unique: [TaskListWidgetTask] = []
    unique.reserveCapacity(tasks.count)
    for task in tasks where seen.insert(task.id).inserted {
        unique.append(task)
    }
    return unique
}

private struct TaskRow: View {
    let task: TaskListWidgetTask
    var emphasize: Bool = false

    var body: some View {
        Link(destination: TaskWidgetRoutes.task(task.id)) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(task.title)
                    .font(.system(size: emphasize ? 12 : 11, weight: emphasize ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(task.priorityCode)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MetricChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BoardColumnView: View {
    let title: String
    let tint: Color
    let tasks: [TaskListWidgetTask]
    let fallback: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            if tasks.isEmpty {
                Text(fallback)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                ForEach(tasks) { task in
                    VStack(alignment: .leading, spacing: 2) {
                        Link(destination: TaskWidgetRoutes.task(task.id)) {
                            Text(task.title)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(2)
                        }
                        Text(task.shortDueLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Home Widgets (Small)

private struct TopTaskNowWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Now")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if let task = entry.snapshot.nextTask {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(3)

                Text(task.priorityCode + " • " + task.dueLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    if #available(iOSApplicationExtension 17.0, *) {
                        Button(intent: CompleteTaskFromWidgetIntent(taskID: task.id.uuidString)) {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete \(task.title)")

                        Button(intent: DeferTaskFromWidgetIntent(taskID: task.id.uuidString, minutes: .fifteen)) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Snooze \(task.title) by 15 minutes")
                    }

                    Spacer()
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        Text("Open")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tint, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            } else {
                Text("No open tasks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Link(destination: TaskWidgetRoutes.quickAdd) {
                    Text("Quick Add")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct TodayCounterNextWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Open Today")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.openCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            if let task = entry.snapshot.nextTask {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                Text(task.dueLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No queued tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct OverdueRescueWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Overdue")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.overdueCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }

            if let task = entry.snapshot.overdueTasks.first {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                Text(task.dueLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Link(destination: TaskWidgetRoutes.task(task.id)) {
                    Text("Rescue")
                        .font(.system(size: 11, weight: .semibold))
                }
            } else {
                Spacer()
                Text("Backlog is clean")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.overdue)
    }
}

private struct QuickWin15mWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Win 15m")
                .font(.system(size: 12, weight: .semibold))
            if let task = entry.snapshot.quickWins.first {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                Text(task.estimateLabel + " • " + task.projectLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No short tasks right now")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.quickWins.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct MorningKickoffWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Morning Kickoff")
                .font(.system(size: 12, weight: .semibold))
            if let task = entry.snapshot.morningTasks.first {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                Text(task.shortDueLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No morning tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.morningTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct EveningWrapWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evening Wrap")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                MetricChip(title: "Done", value: "\(entry.snapshot.doneTodayCount)", tint: .green)
                MetricChip(title: "Carry", value: "\(entry.snapshot.overdueCount)", tint: .orange)
            }
            Spacer(minLength: 0)
            Text(entry.snapshot.overdueCount == 0 ? "Ready to reset" : "Rescue overdue before close")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct WaitingOnWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Waiting On")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.waitingOn.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            if let task = entry.snapshot.waitingOn.first {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                Text(task.projectLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No blocked tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.waitingOn.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct InboxTriageWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let inboxTasks = entry.snapshot.inboxTasks

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Inbox Triage")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(inboxTasks.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            if let task = inboxTasks.first {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                Text(task.priorityCode)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Inbox is clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(inboxTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct DueSoonRadarWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Due Soon")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.dueSoonTasks.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            if let task = entry.snapshot.dueSoonTasks.first {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                Text(task.dueLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No near deadlines")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.dueSoonTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

private struct EnergyMatchWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let topBucket = entry.snapshot.energyBuckets.max(by: { $0.count < $1.count })
        let matching = entry.snapshot.allOpenTasks.first { task in
            task.energy.caseInsensitiveCompare(topBucket?.energy ?? "") == .orderedSame
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text("Energy Match")
                .font(.system(size: 12, weight: .semibold))
            if let bucket = topBucket {
                Text(normalizedBucketLabel(bucket.energy, fallback: "Medium") + " load: \(bucket.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if let task = matching {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            } else {
                Text("No matched task")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(matching.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct ProjectSpotlightWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let slice = entry.snapshot.projectSlices.first
        let destination = slice?.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today

        return VStack(alignment: .leading, spacing: 8) {
            Text("Project Spotlight")
                .font(.system(size: 12, weight: .semibold))
            if let slice {
                Text(slice.projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    MetricChip(title: "Open", value: "\(slice.openCount)", tint: .accentColor)
                    MetricChip(title: "Overdue", value: "\(slice.overdueCount)", tint: .orange)
                }
            } else {
                Text("No active projects")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(destination)
    }
}

private struct CalendarTaskBridgeWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let dueToday = entry.snapshot.allOpenTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Calendar Bridge")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                MetricChip(title: "Today", value: "\(dueToday.count)", tint: .accentColor)
                MetricChip(title: "48h", value: "\(entry.snapshot.upcomingTasks.count)", tint: .blue)
            }
            if let task = dueToday.first ?? entry.snapshot.upcomingTasks.first {
                Text(task.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
            } else {
                Text("No scheduled tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL((dueToday.first ?? entry.snapshot.upcomingTasks.first).map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

// MARK: - Home Widgets (Medium)

private struct TodayTop3WidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today Top 3")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Done \(entry.snapshot.doneTodayCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if entry.snapshot.todayTopTasks.isEmpty {
                Text("No tasks for today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.todayTopTasks.prefix(3)).indices, id: \.self) { index in
                    let task = entry.snapshot.todayTopTasks[index]
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(task.priorityCode)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct NowLaneWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let tasks = entry.snapshot.focusNow.isEmpty ? entry.snapshot.todayTopTasks : entry.snapshot.focusNow

        return VStack(alignment: .leading, spacing: 8) {
            Text("Now Lane")
                .font(.system(size: 12, weight: .semibold))
            if tasks.isEmpty {
                Text("No current lane")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(tasks.prefix(4))) { task in
                    TaskRow(task: task, emphasize: true)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(tasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct OverdueBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overdue Board")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.overdueCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            if entry.snapshot.overdueTasks.isEmpty {
                Text("No overdue tasks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.overdueTasks.prefix(4))) { task in
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        HStack {
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(task.dueLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.overdue)
    }
}

private struct Upcoming48hWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming 48h")
                .font(.system(size: 12, weight: .semibold))

            if entry.snapshot.upcomingTasks.isEmpty {
                Text("No deadlines in 48 hours")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.upcomingTasks.prefix(4))) { task in
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        HStack {
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(task.dueLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.upcoming)
    }
}

private struct MorningEveningPlanWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Morning")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                if entry.snapshot.morningTasks.isEmpty {
                    Text("No tasks")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entry.snapshot.morningTasks.prefix(3))) { task in
                        TaskRow(task: task)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Evening")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.blue)
                if entry.snapshot.eveningTasks.isEmpty {
                    Text("No tasks")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entry.snapshot.eveningTasks.prefix(3))) { task in
                        TaskRow(task: task)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct QuickViewSwitcherWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Views")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                quickScopeChip("Today", count: entry.snapshot.todayTopTasks.count, tint: .accentColor, url: TaskWidgetRoutes.today, scope: .today)
                quickScopeChip("Upcoming", count: entry.snapshot.upcomingTasks.count, tint: .blue, url: TaskWidgetRoutes.upcoming, scope: .upcoming)
                quickScopeChip("Overdue", count: entry.snapshot.overdueTasks.count, tint: .orange, url: TaskWidgetRoutes.overdue, scope: .overdue)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }

    @ViewBuilder
    private func quickScopeChip(
        _ title: String,
        count: Int,
        tint: Color,
        url: URL,
        scope: TaskWidgetScope
    ) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            Button(intent: OpenTaskScopeIntent(scope: scope)) {
                quickScopeChipBody(title: title, count: count, tint: tint)
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: url) {
                quickScopeChipBody(title: title, count: count, tint: tint)
            }
        }
    }

    private func quickScopeChipBody(title: String, count: Int, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProjectSprintWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project Sprint")
                .font(.system(size: 12, weight: .semibold))

            if entry.snapshot.projectSlices.isEmpty {
                Text("No active projects")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.projectSlices.prefix(4))) { slice in
                    let destination = slice.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today
                    Link(destination: destination) {
                        HStack {
                            Text(slice.projectName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(slice.openCount)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            if slice.overdueCount > 0 {
                                Text("!\(slice.overdueCount)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct PriorityMatrixLiteWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let counts = entry.snapshot.priorityCounts

        return VStack(alignment: .leading, spacing: 8) {
            Text("Priority Matrix")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                MetricChip(title: "P0/P1", value: "\(counts["P0", default: 0] + counts["P1", default: 0])", tint: .red)
                MetricChip(title: "P2", value: "\(counts["P2", default: 0])", tint: .orange)
                MetricChip(title: "P3+", value: "\(counts["P3", default: 0] + counts["P4", default: 0] + counts["P5", default: 0])", tint: .blue)
            }
            if let task = entry.snapshot.todayTopTasks.first {
                TaskRow(task: task, emphasize: true)
            } else {
                Text("No prioritized tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct ContextWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contexts")
                .font(.system(size: 12, weight: .semibold))
            if entry.snapshot.contextCounts.isEmpty {
                Text("No context-tagged tasks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.contextCounts.prefix(4)), id: \.key) { bucket in
                    HStack {
                        Text("@\(bucket.key)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(bucket.value)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct FocusSessionQueueWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let queue = entry.snapshot.focusNow.isEmpty ? entry.snapshot.todayTopTasks : entry.snapshot.focusNow

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Focus Queue")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(queue.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            if queue.isEmpty {
                Text("No focus queue")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(queue.prefix(4))) { task in
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        HStack {
                            Image(systemName: "target")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tint)
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(task.estimateLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(queue.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct RecoveryWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let completed = entry.snapshot.completedTodayTasks
        let resumeCandidate = entry.snapshot.nextTask

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recovery")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(completed.count) resumed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let resumeCandidate {
                Text("Resume: \(resumeCandidate.title)")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            } else {
                Text("No pending task to resume")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let completedTask = completed.first {
                Text("Last done: \(completedTask.title)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(resumeCandidate.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct DoneReflectionWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Done Reflection")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.doneTodayCount) done")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            Text("Streak \(entry.gamificationSnapshot.streakDays)d • XP \(entry.gamificationSnapshot.dailyXP)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let quickWin = entry.snapshot.quickWins.first {
                Link(destination: TaskWidgetRoutes.task(quickWin.id)) {
                    Text("Next quick win: \(quickWin.title)")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(2)
                }
            } else {
                Text("No quick wins queued")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

// MARK: - Home Widgets (Large)

private struct TodayPlannerBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            BoardColumnView(
                title: "Overdue",
                tint: .orange,
                tasks: Array(entry.snapshot.overdueTasks.prefix(3)),
                fallback: "None"
            )
            BoardColumnView(
                title: "Now",
                tint: .accentColor,
                tasks: Array(entry.snapshot.todayTopTasks.prefix(3)),
                fallback: "No focus task"
            )
            BoardColumnView(
                title: "Later",
                tint: .blue,
                tasks: Array(entry.snapshot.upcomingTasks.prefix(3)),
                fallback: "No upcoming"
            )
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct WeekTaskPlannerWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let datedTasks = entry.snapshot.allOpenTasks.filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Week Planner")
                .font(.system(size: 13, weight: .semibold))

            if datedTasks.isEmpty {
                Text("No scheduled deadlines")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(datedTasks.prefix(8))) { task in
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        HStack {
                            Text(task.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(task.shortDueLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(datedTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

private struct ProjectCockpitWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project Cockpit")
                .font(.system(size: 13, weight: .semibold))
            HStack(spacing: 8) {
                MetricChip(title: "Projects", value: "\(entry.snapshot.projectSlices.count)", tint: .accentColor)
                MetricChip(title: "Overdue", value: "\(entry.snapshot.projectSlices.reduce(0) { $0 + $1.overdueCount })", tint: .orange)
                MetricChip(title: "Open", value: "\(entry.snapshot.projectSlices.reduce(0) { $0 + $1.openCount })", tint: .blue)
            }

            ForEach(Array(entry.snapshot.projectSlices.prefix(6))) { slice in
                let destination = slice.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today
                Link(destination: destination) {
                    HStack {
                        Text(slice.projectName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(slice.openCount) open")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct BacklogHealthWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let blocked = entry.snapshot.waitingOn.count
        let overdue = entry.snapshot.overdueCount
        let intake = entry.snapshot.inboxTasks.count

        return VStack(alignment: .leading, spacing: 10) {
            Text("Backlog Health")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 8) {
                MetricChip(title: "Overdue", value: "\(overdue)", tint: .orange)
                MetricChip(title: "Blocked", value: "\(blocked)", tint: .purple)
                MetricChip(title: "Inbox", value: "\(intake)", tint: .blue)
            }

            Text(overdue == 0 && blocked == 0 ? "Healthy backlog" : "Recovery recommended")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ForEach(Array(entry.snapshot.overdueTasks.prefix(4))) { task in
                TaskRow(task: task)
            }

            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct KanbanLiteWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            BoardColumnView(
                title: "Rescue",
                tint: .orange,
                tasks: Array(entry.snapshot.overdueTasks.prefix(3)),
                fallback: "Empty"
            )
            BoardColumnView(
                title: "Now",
                tint: .accentColor,
                tasks: Array(entry.snapshot.todayTopTasks.prefix(3)),
                fallback: "Empty"
            )
            BoardColumnView(
                title: "Blocked",
                tint: .purple,
                tasks: Array(entry.snapshot.waitingOn.prefix(3)),
                fallback: "Empty"
            )
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct DeadlineHeatmapWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let buckets = (0..<7).map { offset -> (offset: Int, label: String, count: Int) in
            let day = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            let count = entry.snapshot.allOpenTasks.filter { task in
                guard let due = task.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }.count
            return (offset, TaskWidgetFormatters.weekdayFormatter.string(from: day), count)
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Deadline Heatmap")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 6) {
                ForEach(buckets, id: \.offset) { bucket in
                    VStack(spacing: 4) {
                        Text(bucket.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(bucket.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(bucket.count == 0 ? .secondary : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background((bucket.count == 0 ? Color(.systemGray6) : Color.red.opacity(0.12)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            if let next = entry.snapshot.nextDeadlineTask {
                Text("Next: \(next.title)")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.nextDeadlineTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

private struct ExecutionDashboardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Execution Dashboard")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 8) {
                MetricChip(title: "Done", value: "\(entry.snapshot.doneTodayCount)", tint: .green)
                MetricChip(title: "Open", value: "\(entry.snapshot.openCount)", tint: .accentColor)
                MetricChip(title: "Overdue", value: "\(entry.snapshot.overdueCount)", tint: .orange)
                MetricChip(title: "Blocked", value: "\(entry.snapshot.waitingOn.count)", tint: .purple)
            }

            if let task = entry.snapshot.nextTask {
                Text("Next action: \(task.title)")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("No active next action")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: entry.snapshot.completionProgress)

            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.nextTask.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct DeepWorkAgendaWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let deepWorkTasks = entry.snapshot.allOpenTasks
            .filter { task in
                let energy = task.energy.lowercased()
                let minutes = task.estimatedDurationMinutes ?? 0
                return energy == "high" || minutes >= 45
            }
            .sorted { lhs, rhs in
                (lhs.estimatedDurationMinutes ?? 0) > (rhs.estimatedDurationMinutes ?? 0)
            }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Deep Work Agenda")
                .font(.system(size: 13, weight: .semibold))

            if deepWorkTasks.isEmpty {
                Text("No deep-work candidates")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(deepWorkTasks.prefix(7))) { task in
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        HStack {
                            Text(task.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(task.estimateLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(deepWorkTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct AssistantPlanPreviewWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Assistant Plan")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Read-only")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(entry.snapshot.todayTopTasks.prefix(6)).indices, id: \.self) { index in
                let task = entry.snapshot.todayTopTasks[index]
                Link(destination: TaskWidgetRoutes.task(task.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(index + 1). \(task.title)")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text("Reason: \(task.priorityCode), due \(task.dueLabel)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct LifeAreasBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Life Areas")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 8) {
                ForEach(entry.snapshot.energyBuckets) { bucket in
                    VStack(spacing: 2) {
                        Text(normalizedBucketLabel(bucket.energy, fallback: "Medium"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(bucket.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            ForEach(Array(entry.snapshot.projectSlices.prefix(6))) { slice in
                let destination = slice.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today
                Link(destination: destination) {
                    HStack {
                        Text(slice.projectName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("Open \(slice.openCount)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

// MARK: - Lock Screen Widgets

private struct InlineNextTaskWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        if let task = entry.snapshot.nextTask {
            Text("Next: \(task.title)")
                .lineLimit(1)
                .widgetURL(TaskWidgetRoutes.task(task.id))
        } else {
            Text("Next: Capture a task")
                .widgetURL(TaskWidgetRoutes.quickAdd)
        }
    }
}

private struct CircularTodayProgressWidgetView: View {
    let entry: TaskListEntry

    private var totalEstimate: Int {
        max(entry.snapshot.doneTodayCount + entry.snapshot.openCount, 1)
    }

    var body: some View {
        Gauge(
            value: Double(entry.snapshot.doneTodayCount),
            in: 0...Double(totalEstimate)
        ) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            Text("\(entry.snapshot.doneTodayCount)")
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct RectangularTop2TasksWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Top 2")
                .font(.system(size: 12, weight: .semibold))
            if entry.snapshot.todayTopTasks.isEmpty {
                Text("No tasks queued")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.todayTopTasks.prefix(2))) { task in
                    Text(task.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
        }
        .widgetURL(entry.snapshot.todayTopTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct RectangularOverdueAlertWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Overdue \(entry.snapshot.overdueCount)")
                .font(.system(size: 12, weight: .semibold))
            if let task = entry.snapshot.overdueTasks.first {
                Text(task.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("No overdue tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.overdue)
    }
}

private struct CircularQuickAddWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 20, weight: .bold))
            .widgetURL(TaskWidgetRoutes.quickAdd)
            .accessibilityLabel("Quick add task")
    }
}

private struct RectangularFocusNowWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Focus")
                .font(.system(size: 12, weight: .semibold))
            if let task = (entry.snapshot.focusNow.first ?? entry.snapshot.todayTopTasks.first) {
                Text(task.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("No focus task")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL((entry.snapshot.focusNow.first ?? entry.snapshot.todayTopTasks.first).map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct InlineDueSoonWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        if let task = entry.snapshot.upcomingTasks.first {
            Text("Due soon: \(task.title)")
                .lineLimit(1)
                .widgetURL(TaskWidgetRoutes.task(task.id))
        } else {
            Text("Due soon: Clear")
                .widgetURL(TaskWidgetRoutes.upcoming)
        }
    }
}

private struct RectangularWaitingOnWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Waiting On")
                .font(.system(size: 12, weight: .semibold))
            if let task = entry.snapshot.waitingOn.first {
                Text(task.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("No blocked tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(entry.snapshot.waitingOn.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

// MARK: - StandBy Widgets

private struct DeskTodayBoardWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Desk Board")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Done \(entry.snapshot.doneTodayCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                MetricChip(title: "Now", value: "\(entry.snapshot.todayTopTasks.count)", tint: .accentColor)
                MetricChip(title: "Overdue", value: "\(entry.snapshot.overdueTasks.count)", tint: .orange)
                MetricChip(title: "Upcoming", value: "\(entry.snapshot.upcomingTasks.count)", tint: .blue)
            }

            if let task = entry.snapshot.nextTask {
                Link(destination: TaskWidgetRoutes.task(task.id)) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
            } else {
                Text("No active tasks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

private struct CountdownPanelWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let next = entry.snapshot.nextDeadlineTask

        return VStack(alignment: .leading, spacing: 8) {
            Text("Countdown")
                .font(.system(size: 12, weight: .semibold))
            if let next {
                Text(next.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                Text("Due \(next.dueLabel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("No upcoming deadlines")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(next.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.upcoming)
    }
}

private struct FocusDockWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        let queue = entry.snapshot.focusNow.isEmpty ? entry.snapshot.todayTopTasks : entry.snapshot.focusNow

        return VStack(alignment: .leading, spacing: 8) {
            Text("Focus Dock")
                .font(.system(size: 12, weight: .semibold))
            if queue.isEmpty {
                Text("No focus lane yet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(queue.prefix(3))) { task in
                    Link(destination: TaskWidgetRoutes.task(task.id)) {
                        HStack {
                            Image(systemName: "target")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tint)
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(task.priorityCode)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(queue.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct NightlyResetWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nightly Reset")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                MetricChip(title: "Done", value: "\(entry.snapshot.doneTodayCount)", tint: .green)
                MetricChip(title: "Carry", value: "\(entry.snapshot.overdueCount)", tint: .orange)
            }
            if let carry = entry.snapshot.overdueTasks.first {
                Text("Carry-over: \(carry.title)")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("All clear for tomorrow")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.overdueTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct MorningBriefPanelWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Morning Brief")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                MetricChip(title: "Today", value: "\(entry.snapshot.todayTopTasks.count)", tint: .accentColor)
                MetricChip(title: "Overdue", value: "\(entry.snapshot.overdueCount)", tint: .orange)
                MetricChip(title: "Focus", value: "\(entry.snapshot.focusNow.count)", tint: .blue)
            }
            if let kickoff = entry.snapshot.morningTasks.first {
                Text("Kickoff: \(kickoff.title)")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("No kickoff task")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.snapshot.morningTasks.first.map { TaskWidgetRoutes.task($0.id) } ?? TaskWidgetRoutes.today)
    }
}

private struct ProjectPulseWidgetView: View {
    let entry: TaskListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Project Pulse")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(entry.snapshot.projectSlices.count) active")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if entry.snapshot.projectSlices.isEmpty {
                Text("No active project slices")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.projectSlices.prefix(4))) { slice in
                    let destination = slice.projectID.map(TaskWidgetRoutes.project(_:)) ?? TaskWidgetRoutes.today
                    Link(destination: destination) {
                        HStack {
                            Text(slice.projectName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(slice.openCount)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            if slice.overdueCount > 0 {
                                Text("!\(slice.overdueCount)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(TaskWidgetRoutes.today)
    }
}

#if canImport(AppIntents)
public enum TaskWidgetScope: String, AppEnum {
    case today
    case upcoming
    case overdue

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Task Scope"
    }

    public static var caseDisplayRepresentations: [TaskWidgetScope: DisplayRepresentation] {
        [
            .today: "Today",
            .upcoming: "Upcoming",
            .overdue: "Overdue"
        ]
    }
}

public enum WidgetSnoozeMinutes: Int, AppEnum {
    case fifteen = 15
    case sixty = 60

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Snooze Duration"
    }

    public static var caseDisplayRepresentations: [WidgetSnoozeMinutes: DisplayRepresentation] {
        [
            .fifteen: "15 minutes",
            .sixty: "60 minutes"
        ]
    }

    var commandAction: TaskListWidgetActionType {
        switch self {
        case .fifteen:
            return .defer15m
        case .sixty:
            return .defer60m
        }
    }
}

public struct OpenTaskScopeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Task Scope"

    @Parameter(title: "Scope")
    public var scope: TaskWidgetScope

    public init() {
        self.scope = .today
    }

    public init(scope: TaskWidgetScope) {
        self.scope = scope
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "tasker://tasks/\(scope.rawValue)")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

public struct CompleteTaskFromWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task ID")
    public var taskID: String

    public init() {
        self.taskID = ""
    }

    public init(taskID: String) {
        self.taskID = taskID
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        guard let id = UUID(uuidString: taskID) else {
            return .result(opensIntent: OpenURLIntent(TaskWidgetRoutes.today))
        }

        if TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled {
            let command = TaskListWidgetActionCommand(taskID: id, action: .complete)
            _ = command.savePending()
        }

        // Fail-safe behavior: always open detail route; mutation only happens if command persisted and gate is enabled.
        return .result(opensIntent: OpenURLIntent(TaskWidgetRoutes.task(id)))
    }
}

public struct DeferTaskFromWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource = "Defer Task"

    @Parameter(title: "Task ID")
    public var taskID: String

    @Parameter(title: "Minutes")
    public var minutes: WidgetSnoozeMinutes

    public init() {
        self.taskID = ""
        self.minutes = .fifteen
    }

    public init(taskID: String, minutes: WidgetSnoozeMinutes) {
        self.taskID = taskID
        self.minutes = minutes
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        guard let id = UUID(uuidString: taskID) else {
            return .result(opensIntent: OpenURLIntent(TaskWidgetRoutes.today))
        }

        if TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled {
            let command = TaskListWidgetActionCommand(taskID: id, action: minutes.commandAction)
            _ = command.savePending()
        }

        // Fail-safe behavior: open detail regardless; command path is best effort and app-side gated.
        return .result(opensIntent: OpenURLIntent(TaskWidgetRoutes.task(id)))
    }
}
#endif
