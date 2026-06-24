import XCTest
@testable import LifeBoard

@MainActor
final class HomeSearchStateTests: XCTestCase {
    func testActivateSkipsRefreshWhenRequestSignatureIsUnchanged() {
        let state = HomeSearchState(debounceDelay: 0)
        let engine = MockHomeSearchEngine()

        state.configureIfNeeded(
            makeEngine: { engine },
            dataRevisionProvider: { HomeDataRevision(rawValue: 1) }
        )

        state.activate()
        state.activate()

        XCTAssertEqual(engine.searchInvocations.count, 1)
        XCTAssertEqual(engine.invalidatedRevisions, [1])
    }

    func testMarkDataMutatedForcesRefreshOnNextActivation() {
        let state = HomeSearchState(debounceDelay: 0)
        let engine = MockHomeSearchEngine()
        var revision = HomeDataRevision(rawValue: 1)

        state.configureIfNeeded(
            makeEngine: { engine },
            dataRevisionProvider: { revision }
        )

        state.activate()
        revision = HomeDataRevision(rawValue: 2)
        state.markDataMutated()
        state.activate()

        XCTAssertEqual(engine.invalidatedRevisions, [1, 2])
        XCTAssertEqual(engine.searchInvocations.count, 2)
        XCTAssertEqual(engine.searchInvocations.map(\.revision), [1, 2])
    }

    func testOlderSearchResultsDoNotOverrideNewerRevision() {
        let state = HomeSearchState(debounceDelay: 0)
        let engine = MockHomeSearchEngine()
        engine.autoEmitResults = false

        state.configureIfNeeded(
            makeEngine: { engine },
            dataRevisionProvider: { HomeDataRevision(rawValue: 1) }
        )

        state.activate()
        state.query = "fresh"
        state.refresh(immediate: true)

        XCTAssertEqual(engine.searchInvocations.map(\.revision), [1, 2])

        engine.onResultsUpdated?(1, [makeTask(title: "Stale")])
        XCTAssertTrue(state.sections.isEmpty)

        engine.onResultsUpdated?(2, [makeTask(title: "Fresh")])
        XCTAssertEqual(state.sections.map(\.projectName), [ProjectConstants.inboxProjectName])
        XCTAssertEqual(state.sections.first?.tasks.map(\.title), ["Fresh"])
    }

    func testRunSuggestedCommandStoresResultAndTypingClearsIt() {
        let state = HomeSearchState(debounceDelay: 0)
        let result = HomeSearchCommandResult(
            command: .overdueTasks,
            title: "Overdue tasks",
            subtitle: "1 task overdue",
            taskSections: [HomeSearchSection(projectName: ProjectConstants.inboxProjectName, tasks: [makeTask(title: "Late")])],
            habitRows: [],
            emptyTitle: "No overdue tasks",
            emptySubtitle: "Nothing late.",
            emptyPrimaryTitle: nil,
            fallbackCommand: nil
        )

        state.runSuggestedCommand(result)

        XCTAssertEqual(state.activeSuggestedCommandResult?.command, .overdueTasks)
        XCTAssertEqual(state.selectedStatus, .overdue)
        XCTAssertTrue(state.hasLoaded)
        XCTAssertFalse(state.isLoading)

        state.updateQuery("late")

        XCTAssertNil(state.activeSuggestedCommandResult)
    }

    func testOverdueCommandListsOnlyOpenOverdueTasksGroupedByProject() {
        let overdueOpen = makeTask(title: "Open overdue", projectName: "Work", dueDate: Date(timeIntervalSince1970: 100), isComplete: false)
        let overdueCompleted = makeTask(title: "Done overdue", projectName: "Work", dueDate: Date(timeIntervalSince1970: 100), isComplete: true)
        let snapshot = makeTasksSnapshot(overdueTasks: [overdueOpen, overdueCompleted])

        let result = HomeSearchCommandResultBuilder.build(
            command: .overdueTasks,
            tasksSnapshot: snapshot,
            habitsSnapshot: .empty,
            calendarSnapshot: .empty,
            now: Date(timeIntervalSince1970: 10_000)
        )

        XCTAssertEqual(result.taskSections.map(\.projectName), ["Work"])
        XCTAssertEqual(result.taskSections.first?.tasks.map(\.title), ["Open overdue"])
        XCTAssertEqual(result.resultCount, 1)
    }

    func testQuickWinsCommandUsesFifteenMinuteThreshold() {
        let short = makeTask(title: "Short", estimatedDuration: 15 * 60, priority: .high)
        let long = makeTask(title: "Long", estimatedDuration: 16 * 60, priority: .max)
        let missingEstimate = makeTask(title: "No estimate", estimatedDuration: nil, priority: .max)
        let snapshot = makeTasksSnapshot(morningTasks: [short, long, missingEstimate])

        let result = HomeSearchCommandResultBuilder.build(
            command: .quickWins,
            tasksSnapshot: snapshot,
            habitsSnapshot: .empty,
            calendarSnapshot: .empty
        )

        XCTAssertEqual(result.taskSections.flatMap(\.tasks).map(\.title), ["Short"])
    }

    func testMissedHabitsCommandIncludesRecoveryOverdueAndRecentFailureRows() {
        let failedMark = HabitDayMark(date: Date(timeIntervalSince1970: 100), state: .failure)
        let stableMissed = makeHabit(title: "Stable missed", state: .due, last14Days: [failedMark])
        let recovery = makeHabit(title: "Recovery", state: .overdue)
        let completed = makeHabit(title: "Completed", state: .completedToday)
        let habits = HomeHabitsSnapshot(
            habitHomeSectionState: HabitHomeSectionState(primaryRows: [stableMissed, completed], recoveryRows: [recovery]),
            quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: []),
            errorMessage: nil
        )

        let result = HomeSearchCommandResultBuilder.build(
            command: .missedHabits,
            tasksSnapshot: .empty,
            habitsSnapshot: habits,
            calendarSnapshot: .empty
        )

        XCTAssertEqual(result.habitRows.map(\.title), ["Recovery", "Stable missed"])
    }

    func testBeforeMeetingCommandShowsFallbackWhenNoMeetingExists() {
        let result = HomeSearchCommandResultBuilder.build(
            command: .beforeMeeting,
            tasksSnapshot: .empty,
            habitsSnapshot: .empty,
            calendarSnapshot: .empty
        )

        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.emptyTitle, "No meeting ahead")
        XCTAssertEqual(result.fallbackCommand, .quickWins)
    }

    func testBeforeMeetingCommandKeepsTasksThatFitAvailableWindow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let meetingStart = now.addingTimeInterval(45 * 60)
        let meeting = LifeBoardCalendarEventSnapshot(
            id: "meeting",
            calendarID: "work",
            calendarTitle: "Work",
            title: "Design Review",
            startDate: meetingStart,
            endDate: meetingStart.addingTimeInterval(30 * 60),
            isAllDay: false
        )
        let calendarSnapshot = HomeCalendarSnapshot(
            moduleState: .active,
            selectedDate: now,
            authorizationStatus: .authorized,
            accessAction: .noneNeeded,
            selectedCalendarCount: 1,
            availableCalendarCount: 1,
            nextMeeting: LifeBoardNextMeetingSummary(event: meeting, isInProgress: false, minutesUntilStart: 45),
            busyBlocks: [],
            freeUntil: meetingStart,
            selectedDayEvents: [meeting],
            selectedDayTimelineEvents: [meeting],
            eventsTodayCount: 1,
            isLoading: false,
            errorMessage: nil
        )
        let fits = makeTask(title: "Fits", estimatedDuration: 30 * 60)
        let tooLong = makeTask(title: "Too long", estimatedDuration: 40 * 60)
        let snapshot = makeTasksSnapshot(morningTasks: [fits, tooLong])

        let result = HomeSearchCommandResultBuilder.build(
            command: .beforeMeeting,
            tasksSnapshot: snapshot,
            habitsSnapshot: .empty,
            calendarSnapshot: calendarSnapshot,
            now: now
        )

        XCTAssertEqual(result.taskSections.flatMap(\.tasks).map(\.title), ["Fits"])
        XCTAssertEqual(result.subtitle, "35 min before Design Review")
    }
}

@MainActor
private final class MockHomeSearchEngine: HomeSearchEngine {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)?
    var projects: [Project] = []
    var searchInvocations: [(query: String, revision: Int)] = []
    var invalidatedRevisions: [Int] = []
    var autoEmitResults = true

    func search(query: String, revision: Int) {
        searchInvocations.append((query, revision))
        if autoEmitResults {
            onResultsUpdated?(revision, [])
        }
    }

    func loadProjects(completion: (@MainActor @Sendable () -> Void)?) {
        completion?()
    }

    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32]) {}

    func clearFilters() {}

    func toggleProjectFilter(_ project: String) {}

    func togglePriorityFilter(_ priority: Int32) {}

    func setStatusFilter(_ filter: HomeSearchStatusFilter) {}

    func invalidateSearchCache(revision: Int) {
        invalidatedRevisions.append(revision)
    }

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        Dictionary(grouping: tasks) { $0.projectName ?? ProjectConstants.inboxProjectName }
            .map { (project: $0.key, tasks: $0.value) }
            .sorted { $0.project < $1.project }
    }
}

private func makeTask(
    title: String,
    projectName: String = ProjectConstants.inboxProjectName,
    dueDate: Date = Date(),
    estimatedDuration: TimeInterval? = nil,
    priority: TaskPriority = .low,
    isComplete: Bool = false
) -> TaskDefinition {
    Task(
        id: UUID(),
        projectID: ProjectConstants.inboxProjectID,
        name: title,
        priority: priority,
        dueDate: dueDate,
        project: projectName,
        isComplete: isComplete,
        dateCompleted: nil
    )
    .withEstimatedDuration(estimatedDuration)
}

private func makeTasksSnapshot(
    morningTasks: [TaskDefinition] = [],
    eveningTasks: [TaskDefinition] = [],
    overdueTasks: [TaskDefinition] = [],
    focusTasks: [TaskDefinition] = []
) -> HomeTasksSnapshot {
    HomeTasksSnapshot(
        morningTasks: morningTasks,
        eveningTasks: eveningTasks,
        overdueTasks: overdueTasks,
        dueTodaySection: nil,
        todaySections: [],
        focusNowSectionState: FocusNowSectionState(rows: focusTasks.map(HomeTodayRow.task), pinnedTaskIDs: []),
        todayAgendaSectionState: TodayAgendaSectionState(sections: []),
        agendaTailItems: [],
        habitHomeSectionState: HabitHomeSectionState(primaryRows: [], recoveryRows: []),
        quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: []),
        inlineCompletedTasks: [],
        doneTimelineTasks: [],
        projects: [],
        projectsByID: [:],
        lifeAreas: [],
        lifeAreasByID: [:],
        tagNameByID: [:],
        activeQuickView: .today,
        todayXPSoFar: nil,
        projectGroupingMode: .defaultMode,
        customProjectOrderIDs: [],
        emptyStateMessage: nil,
        emptyStateActionTitle: nil,
        canUseManualFocusDrag: false,
        focusTasks: focusTasks,
        focusRows: focusTasks.map(HomeTodayRow.task),
        pinnedFocusTaskIDs: [],
        todayOpenTaskCount: morningTasks.count + eveningTasks.count + overdueTasks.count + focusTasks.count,
        lifeAreaLensActivity: [:]
    )
}

private func makeHabit(
    title: String,
    state: HomeHabitRowState,
    last14Days: [HabitDayMark] = []
) -> HomeHabitRow {
    HomeHabitRow(
        habitID: UUID(),
        title: title,
        kind: .positive,
        trackingMode: .dailyCheckIn,
        lifeAreaName: "Health",
        iconSymbolName: "checkmark.circle",
        state: state,
        currentStreak: 0,
        last14Days: last14Days
    )
}

private extension TaskDefinition {
    func withEstimatedDuration(_ estimatedDuration: TimeInterval?) -> TaskDefinition {
        var copy = self
        copy.estimatedDuration = estimatedDuration
        return copy
    }
}
