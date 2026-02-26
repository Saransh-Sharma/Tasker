import XCTest
@testable import To_Do_List

final class OverdueTriageServiceTests: XCTestCase {
    private let service = OverdueTriageService()

    func testBuildSuggestionReturnsNilForFewerThanThreeOpenOverdueTasks() {
        let tasks = [
            overdueTask(title: "One", priority: .none),
            overdueTask(title: "Two", priority: .low)
        ]

        XCTAssertNil(service.buildSuggestion(from: tasks, now: Date()))
    }

    func testBuildSuggestionAppliesPriorityBuckets() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar.current
        let expectedTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let expectedNextWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: now) ?? now)

        let noneTask = overdueTask(title: "p0", priority: .none)
        let lowTask = overdueTask(title: "p1", priority: .low)
        let highTask = overdueTask(title: "p2", priority: .high)
        let maxTask = overdueTask(title: "p3", priority: .max)

        let suggestion = service.buildSuggestion(from: [noneTask, lowTask, highTask, maxTask], now: now)

        guard let envelope = suggestion?.envelope else {
            return XCTFail("Expected overdue triage suggestion")
        }
        XCTAssertEqual(envelope.schemaVersion, 2)
        XCTAssertEqual(envelope.commands.count, 3)

        var dueDateByTask: [UUID: Date] = [:]
        for command in envelope.commands {
            guard case let .updateTask(taskID, _, dueDate) = command else {
                return XCTFail("Expected updateTask commands only")
            }
            dueDateByTask[taskID] = dueDate
        }

        XCTAssertEqual(dueDateByTask[noneTask.id], expectedNextWeek)
        XCTAssertEqual(dueDateByTask[lowTask.id], expectedNextWeek)
        XCTAssertEqual(dueDateByTask[highTask.id], expectedTomorrow)
        XCTAssertNil(dueDateByTask[maxTask.id])

        let summary = suggestion?.summaryLines.joined(separator: " | ") ?? ""
        XCTAssertTrue(summary.contains("next week"))
        XCTAssertTrue(summary.contains("tomorrow"))
        XCTAssertTrue(summary.contains("today focus"))
    }

    private func overdueTask(title: String, priority: TaskPriority) -> TaskDefinition {
        TaskDefinition(
            id: UUID(),
            title: title,
            priority: priority,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            isComplete: false
        )
    }
}

@MainActor
final class TaskBreakdownServiceContractTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "installedModels")
        UserDefaults.standard.removeObject(forKey: "currentModelName")
    }

    func testImmediateHeuristicEnforcesThreeToSixSteps() {
        let service = TaskBreakdownService(llm: LLMEvaluator())
        let result = service.immediateHeuristicSteps(
            taskTitle: "Write launch note",
            taskDetails: "Draft intro.",
            projectName: "Work"
        )

        XCTAssertGreaterThanOrEqual(result.steps.count, 3)
        XCTAssertLessThanOrEqual(result.steps.count, 6)
    }

    func testRefineFallsBackToThreeToSixWhenNoModelInstalled() async {
        let service = TaskBreakdownService(llm: LLMEvaluator())
        let result = await service.refine(
            taskTitle: "Plan quarterly review",
            taskDetails: nil,
            projectName: "Ops"
        )

        XCTAssertGreaterThanOrEqual(result.steps.count, 3)
        XCTAssertLessThanOrEqual(result.steps.count, 6)
        XCTAssertNil(result.modelName)
    }
}
