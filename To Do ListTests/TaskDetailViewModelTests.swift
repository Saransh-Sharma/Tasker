import XCTest
@testable import To_Do_List

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

    private func makeViewModel(
        task: TaskDefinition = TaskDefinition(title: "Task detail"),
        metadataPayload: TaskDetailMetadataPayload? = nil,
        relationshipPayload: TaskDetailRelationshipMetadataPayload? = nil,
        children: [TaskDefinition] = []
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
            onUpdate: { _, _, completion in completion(.success(task)) },
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
}
