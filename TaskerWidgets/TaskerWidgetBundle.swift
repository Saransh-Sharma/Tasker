import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct TaskerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayXPWidget()
        WeeklyScoreboardWidget()
        NextMilestoneWidget()
        StreakResilienceWidget()
        FocusSeedWidget()

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
        completion(
            TaskListEntry(
                date: Date(),
                snapshot: resolvedTaskSnapshot(),
                gamificationSnapshot: GamificationWidgetSnapshot.load()
            )
        )
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

struct TaskListStaticWidget: Widget {
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

enum TaskWidgetRoutes {
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

enum TaskWidgetFeatureGate {
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

extension TaskListWidgetSnapshot {
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

extension TaskListWidgetTask {
    var dueLabel: String {
        guard let dueDate else { return "No due" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dueDate, relativeTo: Date())
    }

    var shortDueLabel: String {
        guard let dueDate else { return "No due" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E HH:mm"
        return formatter.string(from: dueDate)
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

func normalizedBucketLabel(_ raw: String, fallback: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return fallback }
    return trimmed
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "@", with: "")
        .capitalized
}

func uniqueTasks(_ tasks: [TaskListWidgetTask]) -> [TaskListWidgetTask] {
    var seen = Set<UUID>()
    var unique: [TaskListWidgetTask] = []
    unique.reserveCapacity(tasks.count)
    for task in tasks where seen.insert(task.id).inserted {
        unique.append(task)
    }
    return unique
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

        return .result(opensIntent: OpenURLIntent(TaskWidgetRoutes.task(id)))
    }
}
#endif
