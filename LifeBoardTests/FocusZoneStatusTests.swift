import XCTest
@testable import LifeBoard

final class FocusZoneStatusTests: XCTestCase {
    func testFocusZoneRowPresentationMakePrioritizesLateOverNonUrgencySignals() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Late task",
            dueDate: Calendar.current.date(byAdding: .day, value: -3, to: now)!,
            estimatedDuration: 15 * 60,
            dependencies: [TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .blocks)]
        )
        let insight = EvaFocusTaskInsight(taskID: task.id, score: 1, badge: "Quick win", rationale: [])

        let presentation = FocusZoneRowPresentation.make(task: task, insight: insight, now: now)

        XCTAssertEqual(presentation.secondaryLineText, "Late by 3d")
    }

    func testFocusZoneRowPresentationMakeShowsDueSoonWhenTaskIsApproachingDeadline() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Soon task",
            dueDate: Calendar.current.date(byAdding: .minute, value: 30, to: now)!,
            estimatedDuration: 15 * 60
        )
        let insight = EvaFocusTaskInsight(taskID: task.id, score: 1, badge: "Quick win", rationale: [])

        let presentation = FocusZoneRowPresentation.make(task: task, insight: insight, now: now)

        XCTAssertEqual(presentation.secondaryLineText, "Due soon")
    }

    func testFocusZoneRowPresentationMakeDoesNotSurfaceQuickWinWithoutUrgency() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Quick task",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!,
            estimatedDuration: 15 * 60
        )
        let insight = EvaFocusTaskInsight(taskID: task.id, score: 1, badge: "Quick win", rationale: [])

        let presentation = FocusZoneRowPresentation.make(task: task, insight: insight, now: now)

        XCTAssertNil(presentation.secondaryLineText)
    }

    func testFocusZoneRowPresentationMakeDoesNotSurfaceUnblockedWithoutUrgency() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let task = makeTask(
            title: "Unblocked task",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!,
            estimatedDuration: nil
        )

        let presentation = FocusZoneRowPresentation.make(task: task, insight: nil, now: now)

        XCTAssertNil(presentation.secondaryLineText)
    }

    func testFocusZoneRowPresentationMakeReturnsNilForCompletedTask() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        var task = makeTask(
            title: "Done task",
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: now)!,
            estimatedDuration: 15 * 60
        )
        task.isComplete = true

        let presentation = FocusZoneRowPresentation.make(task: task, insight: nil, now: now)

        XCTAssertNil(presentation.secondaryLineText)
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
