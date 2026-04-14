import XCTest
@testable import To_Do_List

final class TaskAgendaPresentationModelTests: XCTestCase {
    func testOverdueTaskMapsToDangerBadgeAndMoveAction() {
        let task = TaskDefinition(
            title: "Ship release notes",
            details: "Needs the migration summary",
            priority: .high,
            type: .morning,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            project: "Work"
        )

        let presentation = TaskAgendaPresentationModelBuilder.build(
            task: task,
            showTypeBadge: false,
            isInOverdueSection: true,
            tagNameByID: [:]
        )

        XCTAssertEqual(presentation.title, "Ship release notes")
        XCTAssertEqual(presentation.primaryBadge.text, "Overdue")
        XCTAssertEqual(presentation.primaryBadge.tone, .danger)
        XCTAssertEqual(presentation.secondaryLine, "Needs the migration summary")
        XCTAssertEqual(presentation.secondaryActionTitle, "Move")
    }

    func testTodayTaskIncludesTypeAndProjectInMetadataWhenRequested() {
        let task = TaskDefinition(
            title: "Plan focus block",
            priority: .medium,
            type: .evening,
            dueDate: Date(),
            project: "Deep Work"
        )

        let presentation = TaskAgendaPresentationModelBuilder.build(
            task: task,
            showTypeBadge: true,
            isInOverdueSection: false,
            tagNameByID: [:]
        )

        XCTAssertEqual(presentation.primaryBadge.text, "Today")
        XCTAssertTrue(presentation.metadataLine?.contains(task.type.displayName) == true)
        XCTAssertTrue(presentation.metadataLine?.contains("Deep Work") == true)
    }

    func testAgendaMetadataStillKeepsDueTodayTimeAndSuppressesInboxProject() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 18, minute: 0))!
        let task = TaskDefinition(
            projectID: ProjectConstants.inboxProjectID,
            projectName: ProjectConstants.inboxProjectName,
            title: "Inbox follow-up",
            priority: .medium,
            type: .morning,
            dueDate: dueDate
        )

        let presentation = TaskAgendaPresentationModelBuilder.build(
            task: task,
            showTypeBadge: false,
            isInOverdueSection: false,
            tagNameByID: [:],
            now: now
        )

        XCTAssertEqual(presentation.metadataLine, dueDate.formatted(date: .omitted, time: .shortened))
    }

    func testCompletedTaskMapsToSuccessBadgeAndReopenAction() {
        var task = TaskDefinition(
            title: "Log weekly review",
            priority: .low,
            type: .morning
        )
        task.isComplete = true
        task.dateCompleted = Date()

        let presentation = TaskAgendaPresentationModelBuilder.build(
            task: task,
            showTypeBadge: false,
            isInOverdueSection: false,
            tagNameByID: [:]
        )

        XCTAssertEqual(presentation.primaryBadge.text, "Done")
        XCTAssertEqual(presentation.primaryBadge.tone, .success)
        XCTAssertEqual(presentation.primaryActionTitle, "Reopen")
        XCTAssertNil(TaskAgendaPresentationModelBuilder.dueTimingText(for: task))
    }
}
