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
                quietTrackingSummaryState: .init(stableRows: []),
                errorMessage: nil
            ),
            overlay: previous.overlay
        )

        XCTAssertEqual(current.changedSliceCount(comparedTo: previous), 1)
    }

    func testHomeRenderTransactionCountsCalendarSliceSeparately() {
        let previous = HomeRenderTransaction.empty
        let current = HomeRenderTransaction(
            chrome: previous.chrome,
            tasks: previous.tasks,
            habits: previous.habits,
            calendar: HomeCalendarSnapshot(
                moduleState: .active,
                selectedDate: Date(),
                authorizationStatus: .authorized,
                selectedCalendarCount: 1,
                availableCalendarCount: 1,
                nextMeeting: nil,
                busyBlocks: [],
                freeUntil: nil,
                selectedDayEvents: [],
                selectedDayTimelineEvents: [],
                eventsTodayCount: 2,
                isLoading: false,
                errorMessage: nil
            ),
            overlay: previous.overlay
        )

        XCTAssertEqual(current.changedSliceCount(comparedTo: previous), 1)
    }

    func testHomeRenderTransactionEqualityIncludesCalendarSlice() {
        let base = HomeRenderTransaction.empty
        let lhs = HomeRenderTransaction(
            chrome: base.chrome,
            tasks: base.tasks,
            habits: base.habits,
            calendar: .empty,
            overlay: base.overlay
        )
        let rhs = HomeRenderTransaction(
            chrome: base.chrome,
            tasks: base.tasks,
            habits: base.habits,
            calendar: HomeCalendarSnapshot(
                moduleState: .permissionRequired,
                selectedDate: Date(),
                authorizationStatus: .notDetermined,
                selectedCalendarCount: 0,
                availableCalendarCount: 2,
                nextMeeting: nil,
                busyBlocks: [],
                freeUntil: nil,
                selectedDayEvents: [],
                selectedDayTimelineEvents: [],
                eventsTodayCount: 0,
                isLoading: false,
                errorMessage: nil
            ),
            overlay: base.overlay
        )

        XCTAssertNotEqual(lhs, rhs)
        XCTAssertEqual(rhs.changedSliceCount(comparedTo: lhs), 1)
    }

    func testTodayPresentationBuildsCompressedStatusLine() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HomeChromeSnapshot(
            selectedDate: today,
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
        XCTAssertEqual(presentation.compactDateText, today.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        XCTAssertEqual(presentation.backgroundDateText, today.formatted(.dateTime.month(.wide).day()))
        XCTAssertEqual(presentation.foregroundRelativeLabel, "TODAY")
        XCTAssertEqual(presentation.dateAccessibilityLabel, "Today, \(today.formatted(.dateTime.month(.wide).day()))")
        XCTAssertFalse(presentation.showsBackToToday)
        XCTAssertTrue(presentation.showsReflectionCTA)
        XCTAssertEqual(presentation.reflectionCTATitle, "Reflect")
        XCTAssertEqual(presentation.statusText, "18/250 XP · 100% · 1d")
        XCTAssertEqual(presentation.todayStatus?.xpText, "18/250 XP")
        XCTAssertEqual(presentation.todayStatus?.completionText, "100%")
        XCTAssertEqual(presentation.todayStatus?.streakText, "1d")
        XCTAssertEqual(presentation.todayStatus?.streakAccessibilityLabel, "1 day streak")
        XCTAssertEqual(presentation.xpProgress?.earnedXP, 18)
        XCTAssertEqual(presentation.xpProgress?.targetXP, 250)
        XCTAssertEqual(presentation.xpProgress?.isStreakSafeToday, true)
        XCTAssertEqual(presentation.xpProgress?.accessibilityLabel, "XP progress, 18 of 250 XP")
        XCTAssertEqual(presentation.xpProgress?.progressFraction ?? -1, 18.0 / 250.0, accuracy: 0.0001)
    }

    func testCustomDatePresentationShowsBackToTodayAndSuppressesReflection() {
        let today = Calendar.current.startOfDay(for: Date())
        let selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
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

        XCTAssertEqual(presentation.compactDateText, selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        XCTAssertEqual(presentation.backgroundDateText, selectedDate.formatted(.dateTime.month(.wide).day()))
        XCTAssertEqual(presentation.foregroundRelativeLabel, "TOMORROW")
        XCTAssertEqual(presentation.dateAccessibilityLabel, "Tomorrow, \(selectedDate.formatted(.dateTime.month(.wide).day()))")
        XCTAssertTrue(presentation.showsBackToToday)
        XCTAssertFalse(presentation.showsReflectionCTA)
        XCTAssertEqual(presentation.statusText, "1 task · 1 habit")
        XCTAssertNil(presentation.todayStatus)
        XCTAssertNil(presentation.xpProgress)
    }

    func testCustomDateTodayPresentationSuppressesBackToTodayAsSafetyFallback() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HomeChromeSnapshot(
            selectedDate: today,
            activeScope: .customDate(today),
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

        let presentation = snapshot.homeHeaderPresentation(tasks: .empty)

        XCTAssertFalse(presentation.showsBackToToday)
    }

    func testOverduePresentationUsesTaskOnlyScopedSummary() {
        let snapshot = HomeChromeSnapshot(
            selectedDate: Calendar.current.startOfDay(for: Date()),
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
        XCTAssertNil(presentation.compactDateText)
        XCTAssertNil(presentation.backgroundDateText)
        XCTAssertNil(presentation.foregroundRelativeLabel)
        XCTAssertNil(presentation.dateAccessibilityLabel)
        XCTAssertEqual(presentation.statusText, "2 overdue tasks")
        XCTAssertNil(presentation.todayStatus)
        XCTAssertFalse(presentation.showsReflectionCTA)
        XCTAssertNil(presentation.xpProgress)
    }

    func testTodayPresentationFallsBackToDailyCapWhenTargetIsZeroInGamificationV2() {
        let originalGamificationV2Enabled = V2FeatureFlags.gamificationV2Enabled
        V2FeatureFlags.gamificationV2Enabled = true
        defer { V2FeatureFlags.gamificationV2Enabled = originalGamificationV2Enabled }

        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HomeChromeSnapshot(
            selectedDate: today,
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

        XCTAssertEqual(presentation.statusText, "18/250 XP · 100% · 1d")
        XCTAssertEqual(presentation.todayStatus?.streakText, "1d")
        XCTAssertEqual(presentation.xpProgress?.targetXP, GamificationTokens.dailyXPCap)
        XCTAssertEqual(presentation.xpProgress?.accessibilityLabel, "XP progress, 18 of 250 XP")
    }

    func testTodayPresentationRoundsCompletionPercentageForHeaderDisplay() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HomeChromeSnapshot(
            selectedDate: today,
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

        XCTAssertEqual(presentation.statusText, "18/250 XP · 33% · 1d")
        XCTAssertEqual(presentation.todayStatus?.completionText, "33%")
    }

    func testDateHeaderRelativeLabelsCoverPastAndFutureOffsets() {
        let today = Calendar.current.startOfDay(for: Date())
        let expectedLabels: [(offset: Int, label: String, accessibility: String)] = [
            (-9, "9 DAYS AGO", "9 days ago"),
            (-2, "2 DAYS AGO", "2 days ago"),
            (-1, "YESTERDAY", "Yesterday"),
            (0, "TODAY", "Today"),
            (1, "TOMORROW", "Tomorrow"),
            (2, "IN 2 DAYS", "In 2 days"),
            (9, "IN 9 DAYS", "In 9 days")
        ]

        for expected in expectedLabels {
            let selectedDate = Calendar.current.date(byAdding: .day, value: expected.offset, to: today) ?? today
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
                reflectionEligible: false,
                momentumGuidanceText: ""
            )

            let presentation = snapshot.homeHeaderPresentation(tasks: .empty)

            XCTAssertEqual(presentation.foregroundRelativeLabel, expected.label, "offset \(expected.offset)")
            XCTAssertEqual(
                presentation.dateAccessibilityLabel,
                "\(expected.accessibility), \(selectedDate.formatted(.dateTime.month(.wide).day()))",
                "offset \(expected.offset)"
            )
            XCTAssertEqual(presentation.backgroundDateText, selectedDate.formatted(.dateTime.month(.wide).day()), "offset \(expected.offset)")
            XCTAssertEqual(
                presentation.compactDateText,
                selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                "offset \(expected.offset)"
            )
        }
    }
}
