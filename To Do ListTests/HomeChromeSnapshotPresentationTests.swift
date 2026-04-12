import XCTest
@testable import To_Do_List

final class HomeChromeSnapshotPresentationTests: XCTestCase {
    func testHomeTasksSnapshotEqualityIgnoresHabitOnlyMutations() {
        let row = HomeHabitRow(
            habitID: UUID(),
            title: "Hydrate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Health",
            iconSymbolName: "drop.fill"
        )
        let quietRow = HomeHabitRow(
            habitID: UUID(),
            title: "Steps",
            kind: .positive,
            trackingMode: .lapseOnly,
            lifeAreaName: "Health",
            iconSymbolName: "figure.walk"
        )

        let lhs = HomeTasksSnapshot.empty
        let rhs = HomeTasksSnapshot(
            morningTasks: lhs.morningTasks,
            eveningTasks: lhs.eveningTasks,
            overdueTasks: lhs.overdueTasks,
            dueTodaySection: lhs.dueTodaySection,
            todaySections: lhs.todaySections,
            focusNowSectionState: lhs.focusNowSectionState,
            todayAgendaSectionState: lhs.todayAgendaSectionState,
            agendaTailItems: lhs.agendaTailItems,
            habitHomeSectionState: HabitHomeSectionState(primaryRows: [row], recoveryRows: []),
            quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: [quietRow]),
            inlineCompletedTasks: lhs.inlineCompletedTasks,
            doneTimelineTasks: lhs.doneTimelineTasks,
            projects: lhs.projects,
            projectsByID: lhs.projectsByID,
            tagNameByID: lhs.tagNameByID,
            activeQuickView: lhs.activeQuickView,
            todayXPSoFar: lhs.todayXPSoFar,
            projectGroupingMode: lhs.projectGroupingMode,
            customProjectOrderIDs: lhs.customProjectOrderIDs,
            emptyStateMessage: lhs.emptyStateMessage,
            emptyStateActionTitle: lhs.emptyStateActionTitle,
            canUseManualFocusDrag: lhs.canUseManualFocusDrag,
            focusTasks: lhs.focusTasks,
            focusRows: lhs.focusRows,
            pinnedFocusTaskIDs: lhs.pinnedFocusTaskIDs,
            todayOpenTaskCount: lhs.todayOpenTaskCount
        )

        XCTAssertEqual(lhs, rhs)
    }

    func testHomeRenderTransactionCountsHabitSliceSeparately() {
        let habitRow = HomeHabitRow(
            habitID: UUID(),
            title: "Hydrate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Health",
            iconSymbolName: "drop.fill"
        )
        let previous = HomeRenderTransaction.empty
        let current = HomeRenderTransaction(
            chrome: previous.chrome,
            tasks: previous.tasks,
            habits: HomeHabitsSnapshot(
                habitHomeSectionState: HabitHomeSectionState(primaryRows: [habitRow], recoveryRows: []),
                quietTrackingSummaryState: .init(stableRows: [])
            ),
            overlay: previous.overlay
        )

        XCTAssertEqual(current.changedSliceCount(comparedTo: previous), 1)
    }

    func testTodayPresentationBuildsXPCompletionAndStreakMetadata() {
        let snapshot = HomeChromeSnapshot(
            selectedDate: Date(timeIntervalSince1970: 0),
            activeScope: .today,
            activeFilterState: .default,
            savedHomeViews: [],
            quickViewCounts: [:],
            progressState: HomeProgressState(
                earnedXP: 18,
                remainingPotentialXP: 32,
                todayTargetXP: 250,
                streakDays: 1,
                isStreakSafeToday: true
            ),
            dailyScore: 18,
            completionRate: 1,
            weeklySummary: nil,
            projects: [],
            reflectionEligible: true,
            momentumGuidanceText: ""
        )

        let presentation = snapshot.homeHeaderPresentation(tasks: HomeTasksSnapshot.empty)

        XCTAssertEqual(presentation.viewLabel, "Today")
        XCTAssertEqual(
            presentation.centeredDateText,
            Date(timeIntervalSince1970: 0).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        )
        XCTAssertFalse(presentation.showsBackToToday)
        XCTAssertTrue(presentation.showsReflectionCTA)
        XCTAssertEqual(presentation.reflectionCTATitle, "Reflect")
        XCTAssertEqual(presentation.metadataItems.map { $0.text }, ["18/250 XP", "100%", "1d"])
        XCTAssertEqual(presentation.xpProgress?.earnedXP, 18)
        XCTAssertEqual(presentation.xpProgress?.targetXP, 250)
        XCTAssertEqual(presentation.xpProgress?.isStreakSafeToday, true)
        XCTAssertEqual(presentation.xpProgress?.accessibilityLabel, "XP progress, 18 of 250 XP")
        XCTAssertEqual(presentation.xpProgress?.progressFraction ?? -1, 18.0 / 250.0, accuracy: 0.0001)
    }

    func testCustomDatePresentationShowsBackToTodayAndSuppressesReflection() {
        let selectedDate = Date(timeIntervalSince1970: 86_400)
        let snapshot = HomeChromeSnapshot(
            selectedDate: selectedDate,
            activeScope: .customDate(selectedDate),
            activeFilterState: .default,
            savedHomeViews: [],
            quickViewCounts: [:],
            progressState: .empty,
            dailyScore: 0,
            completionRate: 0,
            weeklySummary: nil,
            projects: [],
            reflectionEligible: true,
            momentumGuidanceText: ""
        )
        let tasks = HomeTasksSnapshot(
            morningTasks: [],
            eveningTasks: [],
            overdueTasks: [],
            dueTodaySection: nil,
            todaySections: [
                HomeListSection(
                    anchor: .dueTodaySummary,
                    rows: [
                        .task(TaskDefinition(title: "Legacy Task")),
                        .task(TaskDefinition(title: "Legacy Task 2")),
                        .task(TaskDefinition(title: "Legacy Task 3"))
                    ]
                )
            ],
            focusNowSectionState: FocusNowSectionState(rows: [], pinnedTaskIDs: []),
            todayAgendaSectionState: TodayAgendaSectionState(
                sections: [
                    HomeListSection(
                        anchor: .dueTodaySummary,
                        rows: [
                            .task(TaskDefinition(title: "Task")),
                            .habit(
                                HomeHabitRow(
                                    habitID: UUID(),
                                    title: "Habit",
                                    kind: .positive,
                                    trackingMode: .dailyCheckIn,
                                    lifeAreaName: "General",
                                    iconSymbolName: "repeat"
                                )
                            )
                        ]
                    )
                ]
            ),
            agendaTailItems: [],
            habitHomeSectionState: HabitHomeSectionState(primaryRows: [], recoveryRows: []),
            quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: []),
            inlineCompletedTasks: [],
            doneTimelineTasks: [],
            projects: [],
            projectsByID: [:],
            tagNameByID: [:],
            activeQuickView: .today,
            todayXPSoFar: nil,
            projectGroupingMode: .defaultMode,
            customProjectOrderIDs: [],
            emptyStateMessage: nil,
            emptyStateActionTitle: nil,
            canUseManualFocusDrag: false,
            focusTasks: [],
            focusRows: [],
            pinnedFocusTaskIDs: [],
            todayOpenTaskCount: 0
        )

        let presentation = snapshot.homeHeaderPresentation(tasks: tasks)

        XCTAssertEqual(
            presentation.centeredDateText,
            selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        )
        XCTAssertTrue(presentation.showsBackToToday)
        XCTAssertFalse(presentation.showsReflectionCTA)
        XCTAssertEqual(presentation.metadataItems.map { $0.text }, ["1 task", "1 habit"])
        XCTAssertNil(presentation.xpProgress)
    }

    func testOverduePresentationUsesTaskOnlyScopedSummary() {
        let snapshot = HomeChromeSnapshot(
            selectedDate: Date(timeIntervalSince1970: 0),
            activeScope: .overdue,
            activeFilterState: .default,
            savedHomeViews: [],
            quickViewCounts: [:],
            progressState: .empty,
            dailyScore: 0,
            completionRate: 0,
            weeklySummary: nil,
            projects: [],
            reflectionEligible: false,
            momentumGuidanceText: ""
        )
        var tasks = HomeTasksSnapshot.empty
        tasks = HomeTasksSnapshot(
            morningTasks: tasks.morningTasks,
            eveningTasks: tasks.eveningTasks,
            overdueTasks: [
                TaskDefinition(title: "Overdue 1"),
                TaskDefinition(title: "Overdue 2")
            ],
            dueTodaySection: tasks.dueTodaySection,
            todaySections: tasks.todaySections,
            focusNowSectionState: tasks.focusNowSectionState,
            todayAgendaSectionState: tasks.todayAgendaSectionState,
            agendaTailItems: tasks.agendaTailItems,
            habitHomeSectionState: tasks.habitHomeSectionState,
            quietTrackingSummaryState: tasks.quietTrackingSummaryState,
            inlineCompletedTasks: tasks.inlineCompletedTasks,
            doneTimelineTasks: tasks.doneTimelineTasks,
            projects: tasks.projects,
            projectsByID: tasks.projectsByID,
            tagNameByID: tasks.tagNameByID,
            activeQuickView: .overdue,
            todayXPSoFar: tasks.todayXPSoFar,
            projectGroupingMode: tasks.projectGroupingMode,
            customProjectOrderIDs: tasks.customProjectOrderIDs,
            emptyStateMessage: tasks.emptyStateMessage,
            emptyStateActionTitle: tasks.emptyStateActionTitle,
            canUseManualFocusDrag: tasks.canUseManualFocusDrag,
            focusTasks: tasks.focusTasks,
            focusRows: tasks.focusRows,
            pinnedFocusTaskIDs: tasks.pinnedFocusTaskIDs,
            todayOpenTaskCount: tasks.todayOpenTaskCount
        )

        let presentation = snapshot.homeHeaderPresentation(tasks: tasks)

        XCTAssertEqual(presentation.viewLabel, "Overdue")
        XCTAssertNil(presentation.centeredDateText)
        XCTAssertEqual(presentation.metadataItems.map { $0.text }, ["2 overdue tasks"])
        XCTAssertFalse(presentation.showsReflectionCTA)
        XCTAssertNil(presentation.xpProgress)
    }

    func testTodayPresentationFallsBackToDailyCapWhenTargetIsZeroInGamificationV2() {
        let originalGamificationV2Enabled = V2FeatureFlags.gamificationV2Enabled
        V2FeatureFlags.gamificationV2Enabled = true
        defer { V2FeatureFlags.gamificationV2Enabled = originalGamificationV2Enabled }

        let snapshot = HomeChromeSnapshot(
            selectedDate: Date(timeIntervalSince1970: 0),
            activeScope: .today,
            activeFilterState: .default,
            savedHomeViews: [],
            quickViewCounts: [:],
            progressState: HomeProgressState(
                earnedXP: 18,
                remainingPotentialXP: 0,
                todayTargetXP: 0,
                streakDays: 1,
                isStreakSafeToday: true
            ),
            dailyScore: 18,
            completionRate: 1,
            weeklySummary: nil,
            projects: [],
            reflectionEligible: true,
            momentumGuidanceText: ""
        )

        let presentation = snapshot.homeHeaderPresentation(tasks: HomeTasksSnapshot.empty)

        XCTAssertEqual(presentation.metadataItems.map { $0.text }, ["18/250 XP", "100%", "1d"])
        XCTAssertEqual(presentation.xpProgress?.targetXP, GamificationTokens.dailyXPCap)
        XCTAssertEqual(presentation.xpProgress?.accessibilityLabel, "XP progress, 18 of 250 XP")
    }

    func testTodayPresentationRoundsCompletionPercentageForHeaderDisplay() {
        let snapshot = HomeChromeSnapshot(
            selectedDate: Date(timeIntervalSince1970: 0),
            activeScope: .today,
            activeFilterState: .default,
            savedHomeViews: [],
            quickViewCounts: [:],
            progressState: HomeProgressState(
                earnedXP: 18,
                remainingPotentialXP: 32,
                todayTargetXP: 250,
                streakDays: 1,
                isStreakSafeToday: true
            ),
            dailyScore: 18,
            completionRate: 1.0 / 3.0,
            weeklySummary: nil,
            projects: [],
            reflectionEligible: true,
            momentumGuidanceText: ""
        )

        let presentation = snapshot.homeHeaderPresentation(tasks: HomeTasksSnapshot.empty)

        XCTAssertEqual(presentation.metadataItems.map { $0.text }, ["18/250 XP", "33%", "1d"])
    }

    func testPrimaryWidgetDefaultPolicyPrefersFocusNowWhenAvailable() {
        let resolved = HomePrimaryWidgetDefaultPolicy.resolve(
            availableWidgets: [.weeklyOperating, .focusNow],
            currentSelection: nil,
            userHasInteracted: false
        )

        XCTAssertEqual(resolved, .focusNow)
    }

    func testPrimaryWidgetDefaultPolicyFallsBackToWeeklyWhenFocusNowUnavailable() {
        let resolved = HomePrimaryWidgetDefaultPolicy.resolve(
            availableWidgets: [.weeklyOperating],
            currentSelection: nil,
            userHasInteracted: false
        )

        XCTAssertEqual(resolved, .weeklyOperating)
    }

    func testPrimaryWidgetDefaultPolicyResolvesMissingManualSelectionBackToDefault() {
        let resolved = HomePrimaryWidgetDefaultPolicy.resolve(
            availableWidgets: [.focusNow],
            currentSelection: .weeklyOperating,
            userHasInteracted: true
        )

        XCTAssertEqual(resolved, .focusNow)
    }

    func testPrimaryWidgetRailStateShowsBothWidgetsOnTodayWhenWeeklySummaryExists() {
        let tasks = makePrimaryWidgetTasksSnapshot(
            activeQuickView: .today,
            focusRows: [.task(TaskDefinition(title: "Focus"))]
        )
        let chrome = makePrimaryWidgetChromeSnapshot(weeklySummary: makeWeeklySummary())

        let state = HomePrimaryWidgetRailState.build(
            tasksSnapshot: tasks,
            chromeSnapshot: chrome
        )

        XCTAssertEqual(state.widgets, [.focusNow, .weeklyOperating])
    }

    func testPrimaryWidgetRailStateHidesWeeklyWidgetOutsideTodayQuickView() {
        let tasks = makePrimaryWidgetTasksSnapshot(
            activeQuickView: .overdue,
            focusRows: [.task(TaskDefinition(title: "Focus"))]
        )
        let chrome = makePrimaryWidgetChromeSnapshot(weeklySummary: makeWeeklySummary())

        let state = HomePrimaryWidgetRailState.build(
            tasksSnapshot: tasks,
            chromeSnapshot: chrome
        )

        XCTAssertEqual(state.widgets, [.focusNow])
    }

    private func makePrimaryWidgetTasksSnapshot(
        activeQuickView: HomeQuickView,
        focusRows: [HomeTodayRow]
    ) -> HomeTasksSnapshot {
        let empty = HomeTasksSnapshot.empty
        return HomeTasksSnapshot(
            morningTasks: empty.morningTasks,
            eveningTasks: empty.eveningTasks,
            overdueTasks: empty.overdueTasks,
            dueTodaySection: empty.dueTodaySection,
            todaySections: empty.todaySections,
            focusNowSectionState: FocusNowSectionState(rows: focusRows, pinnedTaskIDs: []),
            todayAgendaSectionState: empty.todayAgendaSectionState,
            agendaTailItems: empty.agendaTailItems,
            habitHomeSectionState: empty.habitHomeSectionState,
            quietTrackingSummaryState: empty.quietTrackingSummaryState,
            inlineCompletedTasks: empty.inlineCompletedTasks,
            doneTimelineTasks: empty.doneTimelineTasks,
            projects: empty.projects,
            projectsByID: empty.projectsByID,
            tagNameByID: empty.tagNameByID,
            activeQuickView: activeQuickView,
            todayXPSoFar: empty.todayXPSoFar,
            projectGroupingMode: empty.projectGroupingMode,
            customProjectOrderIDs: empty.customProjectOrderIDs,
            emptyStateMessage: empty.emptyStateMessage,
            emptyStateActionTitle: empty.emptyStateActionTitle,
            canUseManualFocusDrag: empty.canUseManualFocusDrag,
            focusTasks: empty.focusTasks,
            focusRows: empty.focusRows,
            pinnedFocusTaskIDs: empty.pinnedFocusTaskIDs,
            todayOpenTaskCount: empty.todayOpenTaskCount
        )
    }

    private func makePrimaryWidgetChromeSnapshot(weeklySummary: HomeWeeklySummary?) -> HomeChromeSnapshot {
        HomeChromeSnapshot(
            selectedDate: Date(timeIntervalSince1970: 0),
            activeScope: .today,
            activeFilterState: .default,
            savedHomeViews: [],
            quickViewCounts: [:],
            progressState: .empty,
            dailyScore: 0,
            completionRate: 0,
            weeklySummary: weeklySummary,
            projects: [],
            reflectionEligible: false,
            momentumGuidanceText: ""
        )
    }

    private func makeWeeklySummary() -> HomeWeeklySummary {
        HomeWeeklySummary(
            weekStartDate: Date(timeIntervalSince1970: 0),
            ctaState: .planThisWeek,
            plannerPresentation: .thisWeek,
            outcomeCount: 1,
            thisWeekTaskCount: 2,
            completedThisWeekTaskCount: 0,
            overCapacityCount: 0,
            reviewCompleted: false
        )
    }
}
