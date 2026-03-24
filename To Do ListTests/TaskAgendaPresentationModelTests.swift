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
