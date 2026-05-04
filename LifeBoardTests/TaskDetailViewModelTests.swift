import XCTest
@testable import LifeBoard

@MainActor
final class TaskDetailViewModelTests: XCTestCase {
    func testDefaultDisclosureStateStartsCollapsedForMinimalTask() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.expandedDisclosureSections, [])
        XCTAssertFalse(viewModel.shouldShowRelationshipsSection)
        XCTAssertFalse(viewModel.shouldShowContextSection)
        XCTAssertEqual(viewModel.summary(for: .steps), "No steps yet")
    }

    func testTaskWithExistingSubtasksStartsWithStepsExpanded() {
        let task = TaskDefinition(
            title: "Break this down",
            subtasks: [UUID()]
        )

        let viewModel = makeViewModel(task: task)

        XCTAssertTrue(viewModel.isSectionExpanded(.steps))
    }

    func testRelationshipsSectionShowsWhenTaskAlreadyHasLinks() {
        let taskID = UUID()
        let task = TaskDefinition(
            id: taskID,
            parentTaskID: UUID(),
            title: "Linked task",
            dependencies: [
                TaskDependencyLinkDefinition(
                    taskID: taskID,
                    dependsOnTaskID: UUID(),
                    kind: .blocks
                )
            ]
        )

        let viewModel = makeViewModel(task: task)

        XCTAssertTrue(viewModel.shouldShowRelationshipsSection)
        XCTAssertTrue(viewModel.summary(for: TaskDetailDisclosureSection.relationships).contains("dependency"))
    }

    func testContextSectionShowsAfterMetadataRefresh() async {
        let metadataPayload = TaskDetailMetadataPayload(
            projects: [Project.createInbox()],
            sections: [],
            weeklyOutcomes: [],
            projectMotivation: ProjectWeeklyMotivation(
                why: "Reduce friction",
                successLooksLike: nil,
                costOfNeglect: nil
            )
        )
        let relationshipPayload = TaskDetailRelationshipMetadataPayload(
            lifeAreas: [],
            tags: [],
            availableTasks: [],
            recentReflectionNotes: [
                ReflectionNote(
                    id: UUID(),
                    kind: .freeform,
                    linkedTaskID: nil,
                    linkedProjectID: nil,
                    prompt: "What is changing about this task right now?",
                    noteText: "This task keeps slipping when the brief is vague.",
                    createdAt: Date()
                )
            ]
        )
        let viewModel = makeViewModel(
            metadataPayload: metadataPayload,
            relationshipPayload: relationshipPayload
        )

        viewModel.refreshMetadata()
        viewModel.refreshRelationshipMetadata()
        try? await _Concurrency.Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(viewModel.shouldShowContextSection)
        XCTAssertEqual(viewModel.summary(for: TaskDetailDisclosureSection.context), "1 reflection · Project motivation")
    }

    func testExistingScheduledValuesArePreselected() {
        let start = makeDate(year: 2026, month: 4, day: 29, hour: 20, minute: 15)
        let task = TaskDefinition(
            title: "Timed task",
            dueDate: start,
            scheduledStartAt: start,
            scheduledEndAt: start.addingTimeInterval(30 * 60),
            estimatedDuration: 30 * 60
        )

        let viewModel = makeViewModel(task: task)

        XCTAssertEqual(viewModel.scheduledStartAt, start)
        XCTAssertEqual(viewModel.scheduledEndAt, start.addingTimeInterval(30 * 60))
        XCTAssertEqual(viewModel.durationMinutes, 30)
    }

    func testChangingStartTimePersistsScheduledStartEndWithoutDueDateFallback() async {
        let originalStart = makeDate(year: 2026, month: 4, day: 29, hour: 20, minute: 15)
        let newStart = makeDate(year: 2026, month: 4, day: 29, hour: 21, minute: 7)
        let roundedStart = makeDate(year: 2026, month: 4, day: 29, hour: 21, minute: 0)
        let task = TaskDefinition(
            title: "Timed task",
            dueDate: originalStart,
            scheduledStartAt: originalStart,
            scheduledEndAt: originalStart.addingTimeInterval(15 * 60),
            estimatedDuration: 15 * 60
        )
        let saveExpectation = expectation(description: "Autosave updated schedule")
        var capturedRequest: UpdateTaskDefinitionRequest?

        let viewModel = makeViewModel(task: task) { _, request, completion in
            capturedRequest = request
            var updated = task
            updated.dueDate = request.dueDate ?? updated.dueDate
            updated.scheduledStartAt = request.scheduledStartAt ?? updated.scheduledStartAt
            updated.scheduledEndAt = request.scheduledEndAt ?? updated.scheduledEndAt
            updated.estimatedDuration = request.estimatedDuration ?? updated.estimatedDuration
            completion(.success(updated))
            saveExpectation.fulfill()
        }

        viewModel.setScheduledStartDate(newStart)
        viewModel.scheduleAutosave(debounced: false)
        await fulfillment(of: [saveExpectation], timeout: 1.0)

        XCTAssertNil(capturedRequest?.dueDate)
        XCTAssertEqual(capturedRequest?.scheduledStartAt, roundedStart)
        XCTAssertEqual(capturedRequest?.scheduledEndAt, roundedStart.addingTimeInterval(15 * 60))
    }

    func testChangingDurationPersistsEstimatedDurationAndScheduledEnd() async {
        let start = makeDate(year: 2026, month: 4, day: 29, hour: 20, minute: 15)
        let task = TaskDefinition(
            title: "Timed task",
            dueDate: start,
            scheduledStartAt: start,
            scheduledEndAt: start.addingTimeInterval(15 * 60),
            estimatedDuration: 15 * 60
        )
        let saveExpectation = expectation(description: "Autosave updated duration")
        var capturedRequest: UpdateTaskDefinitionRequest?

        let viewModel = makeViewModel(task: task) { _, request, completion in
            capturedRequest = request
            var updated = task
            updated.scheduledEndAt = request.scheduledEndAt ?? updated.scheduledEndAt
            updated.estimatedDuration = request.estimatedDuration ?? updated.estimatedDuration
            completion(.success(updated))
            saveExpectation.fulfill()
        }

        viewModel.setDurationMinutes(45)
        viewModel.scheduleAutosave(debounced: false)
        await fulfillment(of: [saveExpectation], timeout: 1.0)

        XCTAssertEqual(capturedRequest?.estimatedDuration, 45 * 60)
        XCTAssertEqual(capturedRequest?.scheduledEndAt, start.addingTimeInterval(45 * 60))
    }

    func testDefaultStartRoundsToNextSlotAndPastExistingTimesRemainEditable() {
        let now = makeDate(year: 2026, month: 4, day: 29, hour: 10, minute: 7)
        let defaultStart = TaskDetailViewModel.defaultScheduledStart(now: now)
        let pastStart = makeDate(year: 2026, month: 4, day: 20, hour: 8, minute: 15)
        let viewModel = makeViewModel()

        viewModel.setScheduledStartDate(pastStart)

        XCTAssertEqual(defaultStart, makeDate(year: 2026, month: 4, day: 29, hour: 10, minute: 15))
        XCTAssertEqual(viewModel.scheduledStartAt, pastStart)
    }

    func testScheduleRangeLabelsCompactSamePeriodAndCrossMidnightNormally() {
        let eveningStart = makeDate(year: 2026, month: 4, day: 29, hour: 20, minute: 15)
        let midnightStart = makeDate(year: 2026, month: 4, day: 29, hour: 23, minute: 30)

        XCTAssertEqual(
            TaskDetailViewModel.scheduleRangeLabel(start: eveningStart, end: eveningStart.addingTimeInterval(15 * 60), locale: Locale(identifier: "en_US")),
            "8:15-8:30 PM"
        )
        XCTAssertEqual(
            TaskDetailViewModel.scheduleRangeLabel(start: midnightStart, end: midnightStart.addingTimeInterval(45 * 60), locale: Locale(identifier: "en_US")),
            "11:30 PM-12:15 AM"
        )
    }

    func testScheduleRangeLabelKeepsFullTimesIn24HourLocales() {
        let eveningStart = makeDate(year: 2026, month: 4, day: 29, hour: 20, minute: 15)

        XCTAssertEqual(
            TaskDetailViewModel.scheduleRangeLabel(start: eveningStart, end: eveningStart.addingTimeInterval(15 * 60), locale: Locale(identifier: "en_GB")),
            "20:15-20:30"
        )
    }

    private func makeViewModel(
        task: TaskDefinition = TaskDefinition(title: "Task detail"),
        metadataPayload: TaskDetailMetadataPayload? = nil,
        relationshipPayload: TaskDetailRelationshipMetadataPayload? = nil,
        children: [TaskDefinition] = [],
        onUpdate: TaskDetailViewModel.UpdateHandler? = nil
    ) -> TaskDetailViewModel {
        let resolvedMetadataPayload = metadataPayload ?? TaskDetailMetadataPayload(
            projects: [Project.createInbox()],
            sections: []
        )
        let resolvedRelationshipPayload = relationshipPayload ?? TaskDetailRelationshipMetadataPayload(
            lifeAreas: [],
            tags: [],
            availableTasks: []
        )

        return TaskDetailViewModel(
            task: task,
            projects: [Project.createInbox()],
            onUpdate: onUpdate ?? { _, _, completion in completion(.success(task)) },
            onSetCompletion: { _, _, completion in completion(.success(task)) },
            onDelete: { _, _, completion in completion(.success(())) },
            onReschedule: { _, _, completion in completion(.success(task)) },
            onLoadMetadata: { _, completion in completion(.success(resolvedMetadataPayload)) },
            onLoadRelationshipMetadata: { _, completion in completion(.success(resolvedRelationshipPayload)) },
            onLoadChildren: { _, completion in completion(.success(children)) },
            onCreateTask: { _, completion in completion(.success(task)) },
            onCreateTag: { _, completion in completion(.failure(NSError(domain: "TaskDetailViewModelTests", code: 1))) },
            onCreateProject: { _, completion in completion(.failure(NSError(domain: "TaskDetailViewModelTests", code: 2))) }
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
