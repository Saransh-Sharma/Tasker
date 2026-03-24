import XCTest
@testable import To_Do_List

final class HomeChromeSnapshotPresentationTests: XCTestCase {
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
            projects: [],
            reflectionEligible: true,
            momentumGuidanceText: ""
        )

        let presentation = snapshot.homeHeaderPresentation(tasks: .empty)

        XCTAssertEqual(presentation.viewLabel, "Today")
        XCTAssertFalse(presentation.showsBackToToday)
        XCTAssertTrue(presentation.showsReflectionCTA)
        XCTAssertEqual(presentation.metadataItems.map(\.text), ["18/250 XP", "100%", "1d"])
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
            ],
            inlineCompletedTasks: [],
            doneTimelineTasks: [],
            projects: [],
            projectsByID: [:],
            projectsByName: [:],
            tagNameByID: [:],
            rescueTasksByID: [:],
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

        XCTAssertTrue(presentation.showsBackToToday)
        XCTAssertFalse(presentation.showsReflectionCTA)
        XCTAssertEqual(presentation.metadataItems.map(\.text), ["1 task", "1 habit"])
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
            inlineCompletedTasks: tasks.inlineCompletedTasks,
            doneTimelineTasks: tasks.doneTimelineTasks,
            projects: tasks.projects,
            projectsByID: tasks.projectsByID,
            projectsByName: tasks.projectsByName,
            tagNameByID: tasks.tagNameByID,
            rescueTasksByID: tasks.rescueTasksByID,
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
        XCTAssertEqual(presentation.metadataItems.map(\.text), ["2 overdue tasks"])
        XCTAssertFalse(presentation.showsReflectionCTA)
    }
}
