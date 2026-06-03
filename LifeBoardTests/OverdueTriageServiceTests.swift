import XCTest
import SwiftUI
@testable import LifeBoard

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
final class OverdueRescueDeckTests: XCTestCase {
    private final class UpdateRequestCapture: @unchecked Sendable {
        var request: UpdateTaskDefinitionRequest?
    }

    func testDeckIncludesRecentOverdueAndCapsSprint() {
        let now = fixedDate()
        let tasks = (0..<18).map { index in
            rescueTask(
                title: "Task \(index)",
                priority: index == 0 ? .max : .low,
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: now)!
            )
        }
        let viewModel = makeViewModel(tasks: tasks)

        XCTAssertEqual(viewModel.allCount, 18)
        XCTAssertEqual(viewModel.cards.count, OverdueRescueViewModel.sprintLimit)
        XCTAssertEqual(viewModel.state, .active)
    }

    func testDeckUsesDeterministicPriorityFirstOrdering() {
        let now = fixedDate()
        let low = rescueTask(
            title: "Low quick",
            priority: .low,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            estimatedDuration: 10 * 60
        )
        let high = rescueTask(
            title: "High priority",
            priority: .high,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
            estimatedDuration: 90 * 60
        )
        let viewModel = makeViewModel(tasks: [low, high])

        XCTAssertEqual(viewModel.cards.first?.id, high.id)
    }

    func testMoveLaterSkipsWeekendForHighUrgencyTasks() {
        let calendar = Calendar.current
        let friday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 29))!
        let task = rescueTask(
            title: "High risk",
            priority: .max,
            dueDate: calendar.date(byAdding: .day, value: -1, to: friday)!,
            estimatedDuration: 2 * 60 * 60
        )

        let moveDate = OverdueRescueCardModel.resolvedMoveDate(for: task, recommendation: nil, now: friday)
        XCTAssertEqual(calendar.component(.weekday, from: moveDate), 2)
        XCTAssertEqual(OverdueRescueCardModel.moveButtonTitle(for: moveDate, now: friday), "Move to Monday")
    }

    func testDeleteConfirmationHardRules() {
        let projectTask = rescueTask(title: "Project", priority: .low, projectID: UUID(), details: nil)
        let notesTask = rescueTask(title: "Notes", priority: .low, details: "Important")
        let simpleTask = rescueTask(title: "Simple", priority: .low, details: nil, updatedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())!)

        XCTAssertTrue(OverdueRescueCardModel.requiresDeleteConfirmation(projectTask))
        XCTAssertTrue(OverdueRescueCardModel.requiresDeleteConfirmation(notesTask))
        XCTAssertFalse(OverdueRescueCardModel.requiresDeleteConfirmation(simpleTask))
    }

    func testStateMachineRejectsInvalidTransitions() {
        XCTAssertTrue(OverdueRescueViewModel.canTransition(from: .notStarted, to: .loading))
        XCTAssertTrue(OverdueRescueViewModel.canTransition(from: .loading, to: .active))
        XCTAssertTrue(OverdueRescueViewModel.canTransition(from: .active, to: .editing))
        XCTAssertTrue(OverdueRescueViewModel.canTransition(from: .active, to: .paused))
        XCTAssertTrue(OverdueRescueViewModel.canTransition(from: .active, to: .applyingBulk))
        XCTAssertFalse(OverdueRescueViewModel.canTransition(from: .active, to: .loading))
        XCTAssertFalse(OverdueRescueViewModel.canTransition(from: .paused, to: .editing))
        XCTAssertFalse(OverdueRescueViewModel.canTransition(from: .confirmingDelete, to: .applyingBulk))
    }

    func testRevealContentKeepsSafeViewportMarginsOnIPhoneWidth() {
        let metrics = OverdueRescueDeckLayoutMetrics.make(
            size: CGSize(width: 393, height: 852),
            bottomInset: 34,
            dynamicTypeSize: .large
        )
        let keepFrame = metrics.revealContentFrame(for: .keep)
        let moveFrame = metrics.revealContentFrame(for: .move)

        XCTAssertGreaterThanOrEqual(keepFrame.minX, 20)
        XCTAssertLessThanOrEqual(moveFrame.maxX, metrics.containerSize.width - 20)
        XCTAssertGreaterThanOrEqual(keepFrame.width, 96)
        XCTAssertEqual(keepFrame.width, moveFrame.width)
    }

    func testRevealContentKeepsSafeViewportMarginsOnNarrowIPhoneWidth() {
        let metrics = OverdueRescueDeckLayoutMetrics.make(
            size: CGSize(width: 320, height: 700),
            bottomInset: 0,
            dynamicTypeSize: .large
        )
        let keepFrame = metrics.revealContentFrame(for: .keep)
        let moveFrame = metrics.revealContentFrame(for: .move)

        XCTAssertGreaterThanOrEqual(keepFrame.minX, 20)
        XCTAssertLessThanOrEqual(moveFrame.maxX, metrics.containerSize.width - 20)
    }

    func testDragResolverRightDragBelowThresholdRevealsKeepWithoutCommit() {
        let result = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: 54, height: 8),
            cardWidth: 360
        )

        XCTAssertEqual(result.reveal, .keep)
        XCTAssertGreaterThan(result.progress, 0)
        XCTAssertNil(result.commitAction)
    }

    func testDragResolverRightDragAboveThresholdCommitsKeep() {
        let result = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: 112, height: 10),
            cardWidth: 360
        )

        XCTAssertEqual(result.reveal, .keep)
        XCTAssertEqual(result.commitAction, .keepToday)
    }

    func testDragResolverClampsVisibleOffsetBeyondLimit() {
        let cardWidth: CGFloat = 360
        let limit = OverdueRescueDragResolver.maxDragOffset(cardWidth: cardWidth)

        let rightResult = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: 900, height: 8),
            cardWidth: cardWidth
        )
        XCTAssertEqual(rightResult.commitAction, .keepToday)
        XCTAssertLessThanOrEqual(rightResult.visibleOffset.width, limit + 0.001)

        let leftResult = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: -900, height: 8),
            cardWidth: cardWidth
        )
        XCTAssertEqual(leftResult.commitAction, .moveLater)
        XCTAssertGreaterThanOrEqual(leftResult.visibleOffset.width, -limit - 0.001)
    }

    func testDragResolverLeftDragBelowThresholdRevealsMoveWithoutCommit() {
        let result = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: -62, height: 12),
            cardWidth: 360
        )

        XCTAssertEqual(result.reveal, .move)
        XCTAssertGreaterThan(result.progress, 0)
        XCTAssertNil(result.commitAction)
    }

    func testDragResolverLeftDragAboveThresholdCommitsMove() {
        let result = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: -116, height: 9),
            cardWidth: 360
        )

        XCTAssertEqual(result.reveal, .move)
        XCTAssertEqual(result.commitAction, .moveLater)
    }

    func testDragResolverVerticalDragDoesNotCommit() {
        let result = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: 34, height: 160),
            cardWidth: 360
        )

        XCTAssertEqual(result.reveal, .none)
        XCTAssertEqual(result.visibleOffset, .zero)
        XCTAssertNil(result.commitAction)
    }

    func testDragResolverReduceMotionRemovesTilt() {
        let result = OverdueRescueDragResolver.resolve(
            translation: CGSize(width: 86, height: 4),
            cardWidth: 360,
            reduceMotion: true
        )

        XCTAssertEqual(result.reveal, .keep)
        XCTAssertEqual(result.tiltDegrees, 0)
    }

    func testUndoAfterKeepRestoresCardAndSummary() async {
        let task = rescueTask(title: "Undo me", priority: .high)
        let viewModel = OverdueRescueViewModel(
            plan: nil,
            tasksByID: [task.id: task],
            projectsByID: [:],
            onUpdate: { _, completion in
                completion(.success(task))
            },
            onDelete: { _, completion in completion(.success(())) },
            onRestore: { task, completion in completion(.success(task)) },
            onApplyBulk: { _, completion in completion(.failure(NSError(domain: "test", code: 1))) },
            onUndoBulk: { completion in completion(.failure(NSError(domain: "test", code: 1))) },
            onTrack: { _, _ in }
        )

        viewModel.keepToday(source: .tap)
        await _Concurrency.Task<Never, Never>.yield()

        XCTAssertEqual(viewModel.state, .completed)
        XCTAssertEqual(viewModel.summary.kept, 1)
        XCTAssertEqual(viewModel.cards.count, 0)

        viewModel.undoLast()
        await _Concurrency.Task<Never, Never>.yield()

        XCTAssertEqual(viewModel.state, .active)
        XCTAssertEqual(viewModel.summary.kept, 0)
        XCTAssertEqual(viewModel.cards.first?.id, task.id)
    }

    func testKeepTodayPreservesTimedScheduleOnTargetDay() async {
        let calendar = Calendar.current
        let referenceDate = fixedDate()
        let today = calendar.startOfDay(for: referenceDate)
        let overdueDay = calendar.date(byAdding: .day, value: -3, to: today)!
        let originalStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: overdueDay)!
        let originalEnd = originalStart.addingTimeInterval(45 * 60)
        let expectedStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today)!
        let expectedEnd = expectedStart.addingTimeInterval(45 * 60)
        var task = rescueTask(
            title: "Keep timed",
            priority: .high,
            dueDate: originalStart,
            estimatedDuration: 45 * 60
        )
        task.scheduledStartAt = originalStart
        task.scheduledEndAt = originalEnd
        task.isAllDay = false
        let originalTask = task

        let capture = UpdateRequestCapture()
        let viewModel = OverdueRescueViewModel(
            plan: nil,
            tasksByID: [originalTask.id: originalTask],
            projectsByID: [:],
            referenceDate: referenceDate,
            onUpdate: { request, completion in
                capture.request = request
                var updatedTask = originalTask
                updatedTask.dueDate = request.dueDate
                updatedTask.scheduledStartAt = request.scheduledStartAt
                updatedTask.scheduledEndAt = request.scheduledEndAt
                updatedTask.isAllDay = request.isAllDay ?? updatedTask.isAllDay
                completion(.success(updatedTask))
            },
            onDelete: { _, completion in completion(.success(())) },
            onRestore: { task, completion in completion(.success(task)) },
            onApplyBulk: { _, completion in completion(.failure(NSError(domain: "test", code: 1))) },
            onUndoBulk: { completion in completion(.failure(NSError(domain: "test", code: 1))) },
            onTrack: { _, _ in }
        )

        viewModel.keepToday(source: .tap)
        await _Concurrency.Task<Never, Never>.yield()

        XCTAssertEqual(capture.request?.dueDate, expectedStart)
        XCTAssertEqual(capture.request?.scheduledStartAt, expectedStart)
        XCTAssertEqual(capture.request?.scheduledEndAt, expectedEnd)
        XCTAssertEqual(capture.request?.isAllDay, false)
        XCTAssertFalse(capture.request?.clearScheduledStartAt ?? true)
        XCTAssertFalse(capture.request?.clearScheduledEndAt ?? true)
    }

    private func makeViewModel(tasks: [TaskDefinition]) -> OverdueRescueViewModel {
        let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        return OverdueRescueViewModel(
            plan: nil,
            tasksByID: tasksByID,
            projectsByID: [:],
            onUpdate: { _, completion in completion(.success(tasks[0])) },
            onDelete: { _, completion in completion(.success(())) },
            onRestore: { task, completion in completion(.success(task)) },
            onApplyBulk: { _, completion in
                completion(.failure(NSError(domain: "test", code: 1)))
            },
            onUndoBulk: { completion in
                completion(.failure(NSError(domain: "test", code: 1)))
            },
            onTrack: { _, _ in }
        )
    }

    private func rescueTask(
        title: String,
        priority: TaskPriority,
        projectID: UUID = ProjectConstants.inboxProjectID,
        dueDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
        estimatedDuration: TimeInterval? = nil,
        details: String? = nil,
        updatedAt: Date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    ) -> TaskDefinition {
        TaskDefinition(
            id: UUID(),
            projectID: projectID,
            projectName: projectID == ProjectConstants.inboxProjectID ? ProjectConstants.inboxProjectName : "Project",
            title: title,
            details: details,
            priority: priority,
            dueDate: dueDate,
            isComplete: false,
            estimatedDuration: estimatedDuration,
            updatedAt: updatedAt
        )
    }

    private func fixedDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 31))!
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
