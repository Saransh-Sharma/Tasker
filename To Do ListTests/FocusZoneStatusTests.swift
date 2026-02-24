import XCTest
@testable import To_Do_List

final class FocusZoneStatusTests: XCTestCase {

    func testResolverPrioritizesLateOverOtherSignals() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Late task",
            dueDate: Calendar.current.date(byAdding: .day, value: -3, to: now)!,
            estimatedDuration: 15 * 60,
            dependencies: [TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .blocks)]
        )
        let insight = EvaFocusTaskInsight(taskID: task.id, score: 1, badge: "Quick win", rationale: [])

        XCTAssertEqual(FocusZoneStatusChipResolver.resolve(task: task, insight: insight, now: now), .late("3d late"))
    }

    func testResolverPrioritizesDueSoonBeforeQuickWin() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Soon task",
            dueDate: Calendar.current.date(byAdding: .minute, value: 30, to: now)!,
            estimatedDuration: 15 * 60
        )
        let insight = EvaFocusTaskInsight(taskID: task.id, score: 1, badge: "Quick win", rationale: [])

        XCTAssertEqual(FocusZoneStatusChipResolver.resolve(task: task, insight: insight, now: now), .dueSoon)
    }

    func testResolverPrioritizesQuickWinBeforeUnblocked() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Quick task",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!,
            estimatedDuration: 15 * 60
        )
        let insight = EvaFocusTaskInsight(taskID: task.id, score: 1, badge: nil, rationale: [])

        XCTAssertEqual(FocusZoneStatusChipResolver.resolve(task: task, insight: insight, now: now), .quickWin)
    }

    func testResolverFallsBackToUnblockedWhenNoUrgencyOrQuickWin() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Unblocked task",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!,
            estimatedDuration: nil
        )

        XCTAssertEqual(FocusZoneStatusChipResolver.resolve(task: task, insight: nil, now: now), .unblocked)
    }

    func testResolverReturnsNilForCompletedTask() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        var task = makeTask(
            title: "Done task",
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: now)!,
            estimatedDuration: 15 * 60
        )
        task.isComplete = true

        XCTAssertNil(FocusZoneStatusChipResolver.resolve(task: task, insight: nil, now: now))
    }

    private func makeTask(
        title: String,
        dueDate: Date,
        estimatedDuration: TimeInterval?,
        dependencies: [TaskDependencyLinkDefinition] = []
    ) -> TaskDefinition {
        TaskDefinition(
            title: title,
            priority: .high,
            dueDate: dueDate,
            dependencies: dependencies,
            estimatedDuration: estimatedDuration
        )
    }
}
