import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct LifeBoardWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Control Center / Lock Screen capture. Gated on iOS 18, where
        // `ControlWidget` exists; every other surface is unaffected.
        if #available(iOS 18.0, *) {
            CaptureControl()
            FocusControl()
        }
        FocusLiveActivityWidget()
        FastingLiveActivityWidget()
        RoutineLiveActivityWidget()

        // The widget gallery is a curated set: Today, Next up, Top tasks,
        // This week, Focus, Habits, Active days, Fasting, Journal, and four
        // Lock Screen accessories. Fifty-odd near-identical task widgets
        // ("Priority Matrix Lite", "Kanban Lite", "Rectangular Top 2 Tasks")
        // made the gallery unreadable. The retired ones still compile — see
        // `RetiredTaskWidgets` below; re-enabling one is moving its entry
        // back into this body. Their kind strings are unchanged, so a widget
        // someone already placed keeps its identity if it comes back.
        FocusSeedWidget()
        HabitsTodayWidget()
        StreakResilienceWidget()
        FastingDomainWidget()
        JournalDomainWidget()

        TaskListStaticWidget(
            kind: "HomeTimelineWidget",
            displayName: "Today",
            description: "Today’s tasks and schedule.",
            families: [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        ) { entry in
            HomeTimelineWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "TopTaskNowWidget",
            displayName: "Next Task",
            description: "Your next task.",
            families: [.systemSmall]
        ) { entry in
            TopTaskNowWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "TodayTop3Widget",
            displayName: "Top Tasks",
            description: "Your top 3 tasks for today.",
            families: [.systemMedium]
        ) { entry in
            TodayTop3WidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "WeekTaskPlannerWidget",
            displayName: "This Week",
            description: "What’s due in the next 7 days.",
            families: [.systemLarge]
        ) { entry in
            WeekTaskPlannerWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "InlineNextTaskWidget",
            displayName: "Next Task",
            description: "Your next task, above the clock.",
            families: [.accessoryInline],
            usesContainerBackground: false
        ) { entry in
            InlineNextTaskWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CircularTodayProgressWidget",
            displayName: "Today’s Progress",
            description: "How much of today is done.",
            families: [.accessoryCircular],
            usesContainerBackground: false
        ) { entry in
            CircularTodayProgressWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularTop2TasksWidget",
            displayName: "Up Next",
            description: "Your next 2 tasks.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularTop2TasksWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CircularQuickAddWidget",
            displayName: "Add Task",
            description: "Add a task from the Lock Screen.",
            families: [.accessoryCircular],
            usesContainerBackground: false
        ) { entry in
            CircularQuickAddWidgetView(entry: entry)
        }
    }
}

/// Widgets retired from the gallery on 2026-09-28 (pre-launch polish). Not
/// listed in `LifeBoardWidgetBundle.body`, so they never appear in the widget
/// gallery; kept compiling so re-enabling one is a one-line move.
///
/// Also retired from the body: `NutritionDomainWidget`, `WellnessDomainWidget`,
/// `LifeMomentsDomainWidget`, `GoalsDomainWidget`, `RoutinesDomainWidget`.
///
/// Retired task widgets: TodayCounterNextWidget, OverdueRescueWidget, QuickWin15mWidget, MorningKickoffWidget, EveningWrapWidget, WaitingOnWidget, InboxTriageWidget, DueSoonRadarWidget, EnergyMatchWidget, ProjectSpotlightWidget, CalendarTaskBridgeWidget, NowLaneWidget, OverdueBoardWidget, Upcoming48hWidget, MorningEveningPlanWidget, QuickViewSwitcherWidget, ProjectSprintWidget, PriorityMatrixLiteWidget, ContextWidget, FocusSessionQueueWidget, RecoveryWidget, DoneReflectionWidget, TodayPlannerBoardWidget, ProjectCockpitWidget, BacklogHealthWidget, KanbanLiteWidget, DeadlineHeatmapWidget, ExecutionDashboardWidget, DeepWorkAgendaWidget, AssistantPlanPreviewWidget, LifeAreasBoardWidget, HomeCalendarWidget, RectangularOverdueAlertWidget, RectangularFocusNowWidget, InlineDueSoonWidget, RectangularWaitingOnWidget, DeskTodayBoardWidget, CountdownPanelWidget, FocusDockWidget, NightlyResetWidget, MorningBriefPanelWidget, ProjectPulseWidget.
@MainActor
enum RetiredTaskWidgets {
    @WidgetBundleBuilder
    static var widgets: some Widget {
        NutritionDomainWidget()
        WellnessDomainWidget()
        LifeMomentsDomainWidget()
        GoalsDomainWidget()
        RoutinesDomainWidget()
        TaskListStaticWidget(
            kind: "TodayCounterNextWidget",
            displayName: "Today Counter + Next",
            description: "Open tasks and the next one.",
            families: [.systemSmall]
        ) { entry in
            TodayCounterNextWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "OverdueRescueWidget",
            displayName: "Rescue",
            description: "Tasks from earlier.",
            families: [.systemSmall]
        ) { entry in
            OverdueRescueWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "QuickWin15mWidget",
            displayName: "Quick Task",
            description: "A task under 15 min.",
            families: [.systemSmall]
        ) { entry in
            QuickWin15mWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "MorningKickoffWidget",
            displayName: "Morning Kickoff",
            description: "Your first task today.",
            families: [.systemSmall]
        ) { entry in
            MorningKickoffWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "EveningWrapWidget",
            displayName: "Evening Wrap",
            description: "What’s done today.",
            families: [.systemSmall]
        ) { entry in
            EveningWrapWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "WaitingOnWidget",
            displayName: "Waiting On",
            description: "Blocked tasks.",
            families: [.systemSmall]
        ) { entry in
            WaitingOnWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "InboxTriageWidget",
            displayName: "Inbox",
            description: "Tasks in your Inbox.",
            families: [.systemSmall]
        ) { entry in
            InboxTriageWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DueSoonRadarWidget",
            displayName: "Due Soon",
            description: "Tasks due in the next 2 days.",
            families: [.systemSmall]
        ) { entry in
            DueSoonRadarWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "EnergyMatchWidget",
            displayName: "Energy Match",
            description: "Tasks by energy.",
            families: [.systemSmall]
        ) { entry in
            EnergyMatchWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectSpotlightWidget",
            displayName: "Project Spotlight",
            description: "Your busiest project.",
            families: [.systemSmall]
        ) { entry in
            ProjectSpotlightWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CalendarTaskBridgeWidget",
            displayName: "Scheduled Tasks",
            description: "Tasks due today.",
            families: [.systemSmall]
        ) { entry in
            CalendarTaskBridgeWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "NowLaneWidget",
            displayName: "Now",
            description: "What to do now.",
            families: [.systemMedium]
        ) { entry in
            NowLaneWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "OverdueBoardWidget",
            displayName: "Rescue",
            description: "Tasks from earlier.",
            families: [.systemMedium]
        ) { entry in
            OverdueBoardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "Upcoming48hWidget",
            displayName: "Next 48 Hours",
            description: "What’s due in the next 2 days.",
            families: [.systemMedium]
        ) { entry in
            Upcoming48hWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "MorningEveningPlanWidget",
            displayName: "Morning and Evening",
            description: "Today’s tasks by time of day.",
            families: [.systemMedium]
        ) { entry in
            MorningEveningPlanWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "QuickViewSwitcherWidget",
            displayName: "Task Lists",
            description: "Open Today, Upcoming, or Rescue.",
            families: [.systemMedium]
        ) { entry in
            QuickViewSwitcherWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectSprintWidget",
            displayName: "Project Sprint",
            description: "Active projects and open tasks.",
            families: [.systemMedium]
        ) { entry in
            ProjectSprintWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "PriorityMatrixLiteWidget",
            displayName: "Priorities",
            description: "Open tasks by priority.",
            families: [.systemMedium]
        ) { entry in
            PriorityMatrixLiteWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ContextWidget",
            displayName: "Contexts",
            description: "Open tasks by context.",
            families: [.systemMedium]
        ) { entry in
            ContextWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "FocusSessionQueueWidget",
            displayName: "Focus Queue",
            description: "Tasks lined up for focus.",
            families: [.systemMedium]
        ) { entry in
            FocusSessionQueueWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RecoveryWidget",
            displayName: "Pick Up",
            description: "Resume where you left off.",
            families: [.systemMedium]
        ) { entry in
            RecoveryWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DoneReflectionWidget",
            displayName: "Done Today",
            description: "Tasks done today.",
            families: [.systemMedium]
        ) { entry in
            DoneReflectionWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "TodayPlannerBoardWidget",
            displayName: "Today Plan",
            description: "Now, later, and from earlier.",
            families: [.systemLarge]
        ) { entry in
            TodayPlannerBoardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectCockpitWidget",
            displayName: "Projects",
            description: "Your projects and open tasks.",
            families: [.systemLarge]
        ) { entry in
            ProjectCockpitWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "BacklogHealthWidget",
            displayName: "Backlog Health",
            description: "From earlier, blocked, and Inbox counts.",
            families: [.systemLarge]
        ) { entry in
            BacklogHealthWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "KanbanLiteWidget",
            displayName: "Task Board",
            description: "Now, from earlier, and blocked.",
            families: [.systemLarge]
        ) { entry in
            KanbanLiteWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DeadlineHeatmapWidget",
            displayName: "Deadline Heatmap",
            description: "Deadlines across the next 7 days.",
            families: [.systemLarge]
        ) { entry in
            DeadlineHeatmapWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ExecutionDashboardWidget",
            displayName: "Overview",
            description: "Today at a glance.",
            families: [.systemLarge]
        ) { entry in
            ExecutionDashboardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DeepWorkAgendaWidget",
            displayName: "Focus Agenda",
            description: "Tasks lined up for focus.",
            families: [.systemLarge]
        ) { entry in
            DeepWorkAgendaWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "AssistantPlanPreviewWidget",
            displayName: "Eva Plan",
            description: "Your next 3 tasks.",
            families: [.systemLarge]
        ) { entry in
            AssistantPlanPreviewWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "LifeAreasBoardWidget",
            displayName: "Life Areas",
            description: "Open tasks by project and energy.",
            families: [.systemLarge]
        ) { entry in
            LifeAreasBoardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "HomeCalendarWidget",
            displayName: "Home Calendar",
            description: "Today’s calendar.",
            families: [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        ) { entry in
            HomeCalendarWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularOverdueAlertWidget",
            displayName: "Rescue",
            description: "Tasks from earlier.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularOverdueAlertWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularFocusNowWidget",
            displayName: "Focus Now",
            description: "What to do now.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularFocusNowWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "InlineDueSoonWidget",
            displayName: "Due Soon",
            description: "Your next due task.",
            families: [.accessoryInline],
            usesContainerBackground: false
        ) { entry in
            InlineDueSoonWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "RectangularWaitingOnWidget",
            displayName: "Waiting On",
            description: "Blocked tasks.",
            families: [.accessoryRectangular],
            usesContainerBackground: false
        ) { entry in
            RectangularWaitingOnWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "DeskTodayBoardWidget",
            displayName: "Today Desk",
            description: "Today at a glance.",
            families: [.systemMedium]
        ) { entry in
            DeskTodayBoardWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "CountdownPanelWidget",
            displayName: "Countdown",
            description: "Time to your next deadline.",
            families: [.systemMedium]
        ) { entry in
            CountdownPanelWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "FocusDockWidget",
            displayName: "Focus Dock",
            description: "What to do now, and next.",
            families: [.systemMedium]
        ) { entry in
            FocusDockWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "NightlyResetWidget",
            displayName: "Close the Day",
            description: "What’s done and what’s left.",
            families: [.systemMedium]
        ) { entry in
            NightlyResetWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "MorningBriefPanelWidget",
            displayName: "Morning Brief",
            description: "Your first task today.",
            families: [.systemMedium]
        ) { entry in
            MorningBriefPanelWidgetView(entry: entry)
        }
        TaskListStaticWidget(
            kind: "ProjectPulseWidget",
            displayName: "Project Pulse",
            description: "Open tasks per project.",
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
                        projectName: "LifeBoard",
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
                        projectName: "LifeBoard",
                        priorityCode: "P2",
                        dueDate: Date().addingTimeInterval(2 * 60 * 60),
                        estimatedDurationMinutes: 10,
                        energy: "low",
                        context: "computer"
                    )
                ],
                projectSlices: [
                    TaskListWidgetProjectSlice(projectName: "LifeBoard", openCount: 5, overdueCount: 1),
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
                openTodayCount: 4,
                calendar: TaskListWidgetCalendarSnapshot(
                    status: .active,
                    date: Date(),
                    selectedCalendarCount: 2,
                    availableCalendarCount: 4,
                    eventsTodayCount: 3,
                    nextMeeting: TaskListWidgetCalendarNextMeeting(
                        event: TaskListWidgetCalendarEvent(
                            id: "preview-design-review",
                            title: "Design review",
                            calendarTitle: "Work",
                            calendarColorHex: "#2F7CF6",
                            startDate: Date().addingTimeInterval(45 * 60),
                            endDate: Date().addingTimeInterval(105 * 60),
                            isAllDay: false,
                            isBusy: true
                        ),
                        isInProgress: false,
                        minutesUntilStart: 45
                    ),
                    freeUntil: Date().addingTimeInterval(45 * 60),
                    timedEvents: [
                        TaskListWidgetCalendarEvent(
                            id: "preview-design-review",
                            title: "Design review",
                            calendarTitle: "Work",
                            calendarColorHex: "#2F7CF6",
                            startDate: Date().addingTimeInterval(45 * 60),
                            endDate: Date().addingTimeInterval(105 * 60),
                            isAllDay: false,
                            isBusy: true
                        ),
                        TaskListWidgetCalendarEvent(
                            id: "preview-planning",
                            title: "Planning block",
                            calendarTitle: "LifeBoard",
                            calendarColorHex: "#23A36F",
                            startDate: Date().addingTimeInterval(3 * 60 * 60),
                            endDate: Date().addingTimeInterval(4 * 60 * 60),
                            isAllDay: false,
                            isBusy: true
                        )
                    ],
                    allDayEvents: [
                        TaskListWidgetCalendarEvent(
                            id: "preview-launch",
                            title: "Launch week",
                            calendarTitle: "LifeBoard",
                            calendarColorHex: "#B06AF7",
                            startDate: Date(),
                            endDate: Date(),
                            isAllDay: true,
                            isBusy: true
                        )
                    ],
                    weekDays: TaskListProvider.previewCalendarWeek()
                ),
                timeline: TaskListProvider.previewTimeline()
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

    static func previewCalendarWeek() -> [TaskListWidgetCalendarDay] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                return nil
            }
            return TaskListWidgetCalendarDay(
                date: date,
                eventCount: offset == 0 ? 3 : (offset % 3),
                timedEvents: offset == 0 ? [
                    TaskListWidgetCalendarEvent(
                        id: "preview-week-\(offset)",
                        title: "Design review",
                        calendarTitle: "Work",
                        calendarColorHex: "#2F7CF6",
                        startDate: date.addingTimeInterval(10 * 60 * 60),
                        endDate: date.addingTimeInterval(11 * 60 * 60),
                        isAllDay: false,
                        isBusy: true
                    )
                ] : [],
                allDayEvents: []
            )
        }
    }

    static func previewTimeline() -> TaskListWidgetTimelineSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let day = calendar.startOfDay(for: now)
        let wake = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
        let sleep = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day) ?? day.addingTimeInterval(22 * 60 * 60)
        let focusStart = calendar.date(byAdding: .minute, value: 30, to: now) ?? now
        let focusEnd = calendar.date(byAdding: .minute, value: 75, to: focusStart) ?? focusStart.addingTimeInterval(75 * 60)
        let reviewStart = calendar.date(byAdding: .hour, value: 3, to: now) ?? now
        let reviewEnd = calendar.date(byAdding: .minute, value: 45, to: reviewStart) ?? reviewStart.addingTimeInterval(45 * 60)
        let timedItems = [
            TaskListWidgetTimelineItem(
                id: "task:preview-focus",
                source: .task,
                taskID: UUID(),
                title: "Draft launch notes",
                subtitle: "LifeBoard",
                startDate: focusStart,
                endDate: focusEnd,
                tintHex: "#2F7CF6",
                systemImageName: "checklist",
                accessoryText: "45 min"
            ),
            TaskListWidgetTimelineItem(
                id: "event:preview-review",
                source: .calendarEvent,
                eventID: "preview-review",
                title: "Design review",
                subtitle: "Work",
                startDate: reviewStart,
                endDate: reviewEnd,
                tintHex: "#23A36F",
                systemImageName: "calendar.badge.clock"
            )
        ]

        return TaskListWidgetTimelineSnapshot(
            date: day,
            updatedAt: now,
            day: TaskListWidgetTimelineDay(
                date: day,
                wakeAnchor: wake,
                sleepAnchor: sleep,
                currentTime: now,
                allDayItems: [
                    TaskListWidgetTimelineItem(
                        id: "task:preview-all-day",
                        source: .task,
                        taskID: UUID(),
                        title: "Launch week",
                        subtitle: "LifeBoard",
                        startDate: day,
                        isAllDay: true,
                        tintHex: "#B06AF7",
                        systemImageName: "flag.fill"
                    )
                ],
                inboxItems: [
                    TaskListWidgetTimelineItem(
                        id: "inbox:preview",
                        source: .task,
                        taskID: UUID(),
                        title: "Capture follow-up",
                        subtitle: "Inbox",
                        tintHex: "#D97706",
                        systemImageName: "tray"
                    )
                ],
                timedItems: timedItems,
                gaps: [
                    TaskListWidgetTimelineGap(
                        startDate: wake,
                        endDate: focusStart,
                        suggestedTaskCount: 1,
                        supportingText: "Free until the first task"
                    )
                ],
                currentItemID: timedItems.first?.id
            ),
            weekDays: previewCalendarWeek().map {
                TaskListWidgetTimelineWeekDay(
                    date: $0.date,
                    dayKey: $0.id,
                    allDayCount: $0.allDayEvents.count,
                    timedCount: $0.timedEvents.count,
                    tintHexes: $0.timedEvents.compactMap(\.calendarColorHex),
                    loadLevel: $0.eventCount > 2 ? .busy : ($0.eventCount > 0 ? .balanced : .light)
                )
            },
            calendarPlottingEnabled: true
        )
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
    static var today: URL { URL(string: "lifeboard://tasks/today")! }
    static var upcoming: URL { URL(string: "lifeboard://tasks/upcoming")! }
    static var overdue: URL { URL(string: "lifeboard://tasks/overdue")! }
    static var weeklyPlanner: URL { URL(string: "lifeboard://weekly/planner")! }
    static var calendarSchedule: URL { URL(string: "lifeboard://calendar/schedule")! }
    static var quickAdd: URL { URL(string: "lifeboard://quickadd")! }

    static func task(_ id: UUID) -> URL {
        URL(string: "lifeboard://task/\(id.uuidString)")!
    }

    static func project(_ id: UUID) -> URL {
        URL(string: "lifeboard://tasks/project/\(id.uuidString)")!
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
        guard let dueDate else { return "No date" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dueDate, relativeTo: Date())
    }

    var shortDueLabel: String {
        guard let dueDate else { return "No date" }
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
        guard let minutes = estimatedDurationMinutes else { return "—" }
        return "\(minutes) min"
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
        "Task List"
    }

    public static var caseDisplayRepresentations: [TaskWidgetScope: DisplayRepresentation] {
        [
            .today: "Today",
            .upcoming: "Upcoming",
            .overdue: "Rescue"
        ]
    }
}

public enum WidgetSnoozeMinutes: Int, AppEnum {
    case fifteen = 15
    case sixty = 60

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Snooze For"
    }

    public static var caseDisplayRepresentations: [WidgetSnoozeMinutes: DisplayRepresentation] {
        [
            .fifteen: "15 min",
            .sixty: "1 hr"
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
    public static let title: LocalizedStringResource = "Open Task List"

    @Parameter(title: "List")
    public var scope: TaskWidgetScope

    public init() {
        self.scope = .today
    }

    public init(scope: TaskWidgetScope) {
        self.scope = scope
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "lifeboard://tasks/\(scope.rawValue)")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

public struct CompleteTaskFromWidgetIntent: AppIntent {
    public static let title: LocalizedStringResource = "Complete Task"

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
    public static let title: LocalizedStringResource = "Snooze Task"

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

/// "+1" on an amount habit's ring. Queues a step; the app applies it through
/// `LogHabitAmountUseCase` (so crossing the target completes the habit once)
/// the next time it is active. Never opens the app.
public struct LogHabitStepFromWidgetIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Habit Step"
    public static let description = IntentDescription("Adds 1 to a habit for today.")
    public static let openAppWhenRun = false

    @Parameter(title: "Habit ID")
    public var habitID: String

    @Parameter(title: "Step")
    public var step: Double

    public init() {
        habitID = ""
        step = 1
    }

    public init(habitID: String, step: Double) {
        self.habitID = habitID
        self.step = step
    }

    public func perform() async throws -> some IntentResult {
        if let habitID = UUID(uuidString: habitID), TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled {
            _ = HabitAmountActionCommand(habitID: habitID, kind: .step, delta: max(0, step)).savePending()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Hold-equivalent for a check-in habit on a widget: today done (or a clean
/// day kept for a quit habit). Never opens the app.
public struct CompleteHabitFromWidgetIntent: AppIntent {
    public static let title: LocalizedStringResource = "Complete Habit Today"
    public static let description = IntentDescription("Marks a habit done for today.")
    public static let openAppWhenRun = false

    @Parameter(title: "Habit ID")
    public var habitID: String

    @Parameter(title: "Quit habit")
    public var isQuitHabit: Bool

    public init() {
        habitID = ""
        isQuitHabit = false
    }

    public init(habitID: String, isQuitHabit: Bool) {
        self.habitID = habitID
        self.isQuitHabit = isQuitHabit
    }

    public func perform() async throws -> some IntentResult {
        if let habitID = UUID(uuidString: habitID), TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled {
            _ = HabitAmountActionCommand(habitID: habitID, kind: isQuitHabit ? .abstain : .complete).savePending()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

public struct ResolveBehaviorOccurrenceIntent: AppIntent {
    public static let title: LocalizedStringResource = "Complete Habit Check-in"

    @Parameter(title: "Check-in ID")
    public var occurrenceID: String

    @Parameter(title: "Habit ID")
    public var behaviorID: String

    public init() {
        occurrenceID = ""
        behaviorID = ""
    }

    public init(occurrenceID: String, behaviorID: String) {
        self.occurrenceID = occurrenceID
        self.behaviorID = behaviorID
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        guard let occurrenceID = UUID(uuidString: occurrenceID),
              let behaviorID = UUID(uuidString: behaviorID) else {
            return .result(opensIntent: OpenURLIntent(TaskWidgetRoutes.today))
        }
        if TaskWidgetFeatureGate.interactiveTaskWidgetsEnabled {
            _ = BehaviorOccurrenceActionCommand(
                occurrenceID: occurrenceID,
                behaviorID: behaviorID,
                action: .complete
            ).savePending()
        }
        return .result(
            opensIntent: OpenURLIntent(URL(string: "lifeboard://habits/habit/\(behaviorID.uuidString)")!)
        )
    }
}
#endif
