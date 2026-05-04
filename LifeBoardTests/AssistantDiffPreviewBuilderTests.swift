import XCTest
@testable import To_Do_List

final class AssistantDiffPreviewBuilderTests: XCTestCase {
    func testBuildRendersExpectedLinesForCoreCommandTypes() {
        let taskA = UUID()
        let taskB = UUID()
        let taskC = UUID()
        let targetProject = UUID()
        let dueDate = Date(timeIntervalSince1970: 1_700_000_000)

        let lines = AssistantDiffPreviewBuilder.build(
            commands: [
                .createTask(projectID: UUID(), title: "Draft weekly report"),
                .updateTask(taskID: taskA, title: nil, dueDate: dueDate),
                .setTaskCompletion(taskID: taskB, isComplete: true, dateCompleted: nil),
                .moveTask(taskID: taskC, targetProjectID: targetProject),
                .deleteTask(taskID: taskB)
            ],
            taskTitleByID: [taskA: "Tax docs", taskB: "Review PRD", taskC: "Call dentist"],
            projectNameByID: [targetProject: "Next Week"]
        )

        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(lines[0].text, "Add: Draft weekly report")
        XCTAssertTrue(lines[1].text.hasPrefix("Reschedule 'Tax docs' to "))
        XCTAssertEqual(lines[2].text, "Complete: 'Review PRD'")
        XCTAssertEqual(lines[3].text, "Move 'Call dentist' to 'Next Week'")
        XCTAssertEqual(lines[4].text, "Delete: 'Review PRD'")
        XCTAssertFalse(lines[0].isDestructive)
        XCTAssertTrue(lines[3].isDestructive)
        XCTAssertTrue(lines[4].isDestructive)
    }

    func testMoveFallbackUsesSelectedProjectLabel() {
        let taskID = UUID()
        let line = AssistantDiffPreviewBuilder.build(
            commands: [.moveTask(taskID: taskID, targetProjectID: UUID())],
            taskTitleByID: [taskID: "Plan trip"],
            projectNameByID: [:]
        ).first

        XCTAssertEqual(line?.text, "Move 'Plan trip' to 'selected project'")
        XCTAssertEqual(line?.isDestructive, true)
    }

    func testCountsUseUniqueAffectedTasksAndDestructiveRules() {
        let taskA = UUID()
        let taskB = UUID()
        let commands: [AssistantCommand] = [
            .updateTask(taskID: taskA, title: "Renamed", dueDate: nil),
            .setTaskCompletion(taskID: taskA, isComplete: true, dateCompleted: nil),
            .moveTask(taskID: taskB, targetProjectID: UUID()),
            .deleteTask(taskID: taskB)
        ]

        XCTAssertEqual(AssistantDiffPreviewBuilder.affectedTaskCount(for: commands), 2)
        XCTAssertEqual(AssistantDiffPreviewBuilder.destructiveCount(for: commands), 2)
    }

    func testAffectedTaskCountReturnsOneForCreateOnlyPlans() {
        let commands: [AssistantCommand] = [
            .createTask(projectID: UUID(), title: "Create inbox capture")
        ]

        XCTAssertEqual(AssistantDiffPreviewBuilder.affectedTaskCount(for: commands), 1)
    }

    func testUnknownTaskFallbackAvoidsUUIDInDiffText() {
        let unknownTaskID = UUID()
        let line = AssistantDiffPreviewBuilder.build(
            commands: [.deleteTask(taskID: unknownTaskID)],
            taskTitleByID: [:]
        ).first

        XCTAssertEqual(line?.text, "Delete: 'task'")
        XCTAssertFalse(line?.text.contains(unknownTaskID.uuidString) ?? false)
    }
}
