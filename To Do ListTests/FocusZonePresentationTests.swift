import XCTest
@testable import To_Do_List

final class FocusZonePresentationTests: XCTestCase {
    func testOverdueBadgeBeatsDueSoon() {
        let now = Date()
        let overdueTask = makeTask(
            title: "Overdue task",
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: now),
            estimatedDuration: 900
        )

        let presentation = FocusZoneRowPresentation.make(task: overdueTask, insight: nil, now: now)

        XCTAssertEqual(presentation.visibleBadge?.text, "2d late")
        XCTAssertEqual(presentation.visibleBadge?.tone, .danger)
    }

    func testDueTodayTimingShowsWhenTaskIsNotDueSoon() {
        let now = Calendar.current.startOfDay(for: Date())
        let dueTodayTask = makeTask(
            title: "Later today",
            projectName: "M26",
            dueDate: Calendar.current.date(byAdding: .hour, value: 8, to: now)
        )

        let presentation = FocusZoneRowPresentation.make(
            task: dueTodayTask,
            insight: nil,
            now: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        )

        let expectedTime = (Calendar.current.date(byAdding: .hour, value: 8, to: now) ?? now)
            .formatted(date: .omitted, time: .shortened)
        XCTAssertEqual(presentation.visibleBadge?.text, "Due \(expectedTime)")
    }

    func testDueSoonPrimaryBadgeSuppressesDueTodayTiming() {
        let now = Date()
        let dueSoonTask = makeTask(
            title: "Soon",
            dueDate: Calendar.current.date(byAdding: .minute, value: 45, to: now)
        )

        let presentation = FocusZoneRowPresentation.make(task: dueSoonTask, insight: nil, now: now)

        XCTAssertEqual(presentation.visibleBadge?.text, "Due soon")
    }

    func testDueBadgeUsesInjectedNowForSameDayComparison() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 18, minute: 0))!
        let task = makeTask(
            title: "Deterministic due today",
            projectName: "M26",
            dueDate: dueDate
        )

        let presentation = FocusZoneRowPresentation.make(task: task, insight: nil, now: now)

        XCTAssertEqual(
            presentation.visibleBadge,
            FocusZoneBadgePresentation(
                text: "Due \(dueDate.formatted(date: .omitted, time: .shortened))",
                tone: .warning
            )
        )
    }

    func testQuickWinDoesNotRenderWithoutTimePressure() {
        let now = Date()
        let task = makeTask(
            title: "Quick win task",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now),
            estimatedDuration: 600
        )

        let presentation = FocusZoneRowPresentation.make(task: task, insight: nil, now: now)

        XCTAssertNil(presentation.visibleBadge)
    }

    func testCompactPresentationHidesPriorityAndKeepsContext() {
        let task = makeTask(
            title: "Priority task",
            projectID: ProjectConstants.inboxProjectID,
            projectName: "Inbox",
            priority: .high
        )

        let presentation = FocusZoneRowPresentation.make(task: task, insight: nil)

        XCTAssertEqual(presentation.secondaryLineText, "Inbox")
        XCTAssertNil(presentation.visibleBadge)
    }

    func testDependencyFreeTaskDoesNotShowUnblockedBadge() {
        let task = makeTask(
            title: "Dependency-free task",
            projectName: "Project Alpha"
        )

        let presentation = FocusZoneRowPresentation.make(task: task, insight: nil)

        XCTAssertNil(presentation.visibleBadge)
    }

    func testBlockedTaskDoesNotShowVisibleBadgeWithoutUrgency() {
        let taskID = UUID()
        let blockedTask = makeTask(
            id: taskID,
            title: "Blocked task",
            projectName: "Project Alpha",
            dependencies: [
                TaskDependencyLinkDefinition(
                    taskID: taskID,
                    dependsOnTaskID: UUID(),
                    kind: .blocks
                )
            ]
        )

        let presentation = FocusZoneRowPresentation.make(task: blockedTask, insight: nil)

        XCTAssertNil(presentation.visibleBadge)
    }

    private func makeTask(
        id: UUID = UUID(),
        title: String,
        projectID: UUID = ProjectConstants.inboxProjectID,
        projectName: String? = "Inbox",
        dueDate: Date? = nil,
        priority: TaskPriority = .low,
        estimatedDuration: TimeInterval? = nil,
        dependencies: [TaskDependencyLinkDefinition] = []
    ) -> TaskDefinition {
        TaskDefinition(
            id: id,
            projectID: projectID,
            projectName: projectName,
            title: title,
            priority: priority,
            dueDate: dueDate,
            dependencies: dependencies,
            estimatedDuration: estimatedDuration
        )
    }
}

final class EvaFocusWhySheetPresentationTests: XCTestCase {
    func testTaskCardPresentationUsesFirstRationaleLabelAndContext() {
        let task = makeTask(
            title: "Choose tomorrow's first work step",
            projectID: UUID(),
            projectName: "Career",
            priority: .high
        )
        let insight = EvaFocusTaskInsight(
            taskID: task.id,
            score: 0.91,
            badge: nil,
            rationale: [
                EvaRationaleFactor(factor: "deadline", label: "Needs to land before the afternoon handoff", contribution: 0.8),
                EvaRationaleFactor(factor: "momentum", label: "High leverage if started now", contribution: 0.6)
            ]
        )

        let presentation = EvaFocusWhyTaskCardPresentation.make(task: task, insight: insight)

        XCTAssertEqual(presentation.title, task.title)
        XCTAssertEqual(presentation.contextText, "Career")
        XCTAssertEqual(presentation.summaryText, "Needs to land before the afternoon handoff")
        XCTAssertEqual(presentation.reasonLines, insight.rationale.map(\.label))
        XCTAssertFalse(presentation.isComplete)
    }

    func testTaskCardPresentationFallsBackToGenericSummaryWithoutRationale() {
        var task = makeTask(title: "Quiet reset", projectID: UUID(), projectName: nil, priority: .low)
        task.isComplete = true

        let presentation = EvaFocusWhyTaskCardPresentation.make(task: task, insight: nil)

        XCTAssertEqual(presentation.summaryText, String(localized: "Eva selected this using urgency and effort balance."))
        XCTAssertEqual(presentation.reasonLines, [])
        XCTAssertNil(presentation.contextText)
        XCTAssertTrue(presentation.isComplete)
    }

    func testCandidatePresentationFallsBackToSwapCopyWithoutInsight() {
        let task = makeTask(title: "Prep launch notes", projectID: UUID(), projectName: "Inbox", priority: .low)

        let presentation = EvaFocusWhyCandidatePresentation.make(task: task, insight: nil)

        XCTAssertEqual(presentation.title, task.title)
        XCTAssertEqual(presentation.contextText, "Inbox")
        XCTAssertEqual(presentation.summaryText, String(localized: "Swap into Focus Now"))
    }

    private func makeTask(
        id: UUID = UUID(),
        title: String,
        projectID: UUID = ProjectConstants.inboxProjectID,
        projectName: String? = "Inbox",
        priority: TaskPriority = .low
    ) -> TaskDefinition {
        TaskDefinition(
            id: id,
            projectID: projectID,
            projectName: projectName,
            title: title,
            priority: priority
        )
    }
}
