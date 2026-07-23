import XCTest
@testable import LifeBoard

@MainActor
final class SunriseFocusZonePresentationTests: XCTestCase {
    func testOverdueBadgeBeatsDueSoon() {
        let now = Date()
        let overdueTask = makeTask(
            title: "Overdue task",
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: now),
            estimatedDuration: 900
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: overdueTask, insight: nil, now: now)

        XCTAssertEqual(presentation.secondaryLineText, "Late by 2d")
    }

    func testSecondaryLineUsesSingleSharedSeparatorForUrgencyAndMetadata() {
        let now = Date()
        let overdueProjectTask = makeTask(
            title: "Overdue with project",
            projectID: UUID(),
            projectName: "Project Alpha",
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: now),
            estimatedDuration: 600
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: overdueProjectTask, insight: nil, now: now)

        XCTAssertEqual(presentation.secondaryLineText, "Late by 2d · Project Alpha")
    }

    func testEmptyStateMessageUsesGenericCopyWhenVisibleRowLimitIsNil() {
        XCTAssertEqual(
            SunriseFocusZone.emptyStateMessage(maxVisibleRows: nil),
            "Add tasks for today to see your upcoming tasks."
        )
    }

    func testEmptyStateMessageInterpolatesConfiguredVisibleRowLimit() {
        XCTAssertEqual(
            SunriseFocusZone.emptyStateMessage(maxVisibleRows: 5),
            "Add tasks for today to see your next 5."
        )
    }

    func testDueTodayTimingIsHiddenForInboxTasksInUnifiedList() {
        let now = Calendar.current.startOfDay(for: Date())
        let dueTodayTask = makeTask(
            title: "Later today",
            dueDate: Calendar.current.date(byAdding: .hour, value: 8, to: now)
        )

        let presentation = SunriseFocusZoneRowPresentation.make(
            task: dueTodayTask,
            insight: nil,
            now: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        )

        XCTAssertNil(presentation.secondaryLineText)
    }

    func testDueSoonPrimaryBadgeSuppressesDueTodayTiming() {
        let now = Date()
        let dueSoonTask = makeTask(
            title: "Soon",
            dueDate: Calendar.current.date(byAdding: .minute, value: 45, to: now)
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: dueSoonTask, insight: nil, now: now)

        XCTAssertEqual(presentation.secondaryLineText, "Due soon")
    }

    func testDueTodayTasksKeepNonInboxProjectNameWithoutTime() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 18, minute: 0))!
        let task = makeTask(
            title: "Deterministic due today",
            projectID: UUID(),
            projectName: "M26",
            dueDate: dueDate
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: task, insight: nil, now: now)

        XCTAssertEqual(presentation.secondaryLineText, "M26")
    }

    func testQuickWinDoesNotRenderWithoutTimePressureForInboxTask() {
        let now = Date()
        let task = makeTask(
            title: "Quick win task",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now),
            estimatedDuration: 600
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: task, insight: nil, now: now)

        XCTAssertNil(presentation.secondaryLineText)
    }

    func testCompactPresentationHidesPriorityAndInboxContext() {
        let task = makeTask(
            title: "Priority task",
            projectID: ProjectConstants.inboxProjectID,
            projectName: "Inbox",
            priority: .high
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: task, insight: nil)

        XCTAssertNil(presentation.secondaryLineText)
    }

    func testDependencyFreeTaskKeepsNonInboxProjectContext() {
        let task = makeTask(
            title: "Dependency-free task",
            projectID: UUID(),
            projectName: "Project Alpha"
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: task, insight: nil)

        XCTAssertEqual(presentation.secondaryLineText, "Project Alpha")
    }

    func testBlockedTaskKeepsNonInboxProjectContextWithoutUrgency() {
        let taskID = UUID()
        let blockedTask = makeTask(
            id: taskID,
            title: "Blocked task",
            projectID: UUID(),
            projectName: "Project Alpha",
            dependencies: [
                TaskDependencyLinkDefinition(
                    taskID: taskID,
                    dependsOnTaskID: UUID(),
                    kind: .blocks
                )
            ]
        )

        let presentation = SunriseFocusZoneRowPresentation.make(task: blockedTask, insight: nil)

        XCTAssertEqual(presentation.secondaryLineText, "Project Alpha")
    }

    func testSecondaryLineResolverKeepsInboxByDefaultForOtherSurfaces() {
        let task = makeTask(
            title: "Inbox task",
            projectID: ProjectConstants.inboxProjectID,
            projectName: "Inbox"
        )

        let metadata = SunriseFocusZoneSecondaryLineResolver.resolve(task: task)

        XCTAssertEqual(metadata.text, "Inbox")
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

final class FocusNowPresentationSupportTests: XCTestCase {
    func testDurationDefaultUsesTaskEstimateBeforeStoredFallback() {
        let suiteName = "FocusNowPresentationSupportTests.DurationEstimate.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        FocusDurationStore.saveLastUsedDurationSeconds(45 * 60, defaults: defaults)

        let task = makeTask(title: "Estimated block", estimatedDuration: 15 * 60)

        XCTAssertEqual(FocusDurationStore.defaultDurationSeconds(for: task, defaults: defaults), 15 * 60)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDurationDefaultFallsBackToLastUsedThenTwentyFiveMinutes() {
        let suiteName = "FocusNowPresentationSupportTests.DurationFallback.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let task = makeTask(title: "No estimate", estimatedDuration: nil)
        XCTAssertEqual(FocusDurationStore.defaultDurationSeconds(for: task, defaults: defaults), 25 * 60)

        FocusDurationStore.saveLastUsedDurationSeconds(60 * 60, defaults: defaults)
        XCTAssertEqual(FocusDurationStore.defaultDurationSeconds(for: task, defaults: defaults), 60 * 60)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDurationStoreBoundsCustomValues() {
        let suiteName = "FocusNowPresentationSupportTests.DurationBounds.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        FocusDurationStore.saveLastUsedDurationSeconds(10, defaults: defaults)
        XCTAssertEqual(FocusDurationStore.lastUsedDurationSeconds(defaults: defaults), 60)

        FocusDurationStore.saveLastUsedDurationSeconds(400 * 60, defaults: defaults)
        XCTAssertEqual(FocusDurationStore.lastUsedDurationSeconds(defaults: defaults), 180 * 60)
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeTask(
        id: UUID = UUID(),
        title: String,
        projectID: UUID = ProjectConstants.inboxProjectID,
        projectName: String? = "Inbox",
        priority: TaskPriority = .low,
        estimatedDuration: TimeInterval? = nil
    ) -> TaskDefinition {
        TaskDefinition(
            id: id,
            projectID: projectID,
            projectName: projectName,
            title: title,
            priority: priority,
            estimatedDuration: estimatedDuration
        )
    }
}
