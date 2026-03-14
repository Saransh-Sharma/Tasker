import XCTest
@testable import To_Do_List

final class AppOnboardingTests: XCTestCase {

    func testEligibilityReturnsFullFlowForEffectivelyEmptyWorkspace() async {
        let suiteName = UUID().uuidString
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let store = AppOnboardingStateStore(userDefaults: suite)
        let service = OnboardingEligibilityService(
            stateStore: store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "General")] },
            fetchProjects: { [Project.createInbox()] },
            fetchTasks: { [] }
        )

        let result = await service.evaluate()

        guard case .fullFlow(let snapshot) = result else {
            return XCTFail("Expected full-flow onboarding for an effectively empty workspace.")
        }
        XCTAssertEqual(snapshot.customLifeAreaCount, 0)
        XCTAssertEqual(snapshot.customProjectCount, 0)
        XCTAssertEqual(snapshot.taskCount, 0)
    }

    func testEligibilityReturnsPromptOnlyForEstablishedWorkspaceWithoutState() async {
        let suiteName = UUID().uuidString
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let store = AppOnboardingStateStore(userDefaults: suite)
        let service = OnboardingEligibilityService(
            stateStore: store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "General"), LifeArea(name: "Career")] },
            fetchProjects: { [Project.createInbox(), Project(name: "Ship one thing")] },
            fetchTasks: { [TaskDefinition(title: "Draft update"), TaskDefinition(title: "Send recap"), TaskDefinition(title: "Plan next step")] }
        )

        let result = await service.evaluate()

        guard case .promptOnly(let snapshot) = result else {
            return XCTFail("Expected prompt-only onboarding for an established workspace.")
        }
        XCTAssertEqual(snapshot.customLifeAreaCount, 1)
        XCTAssertEqual(snapshot.customProjectCount, 1)
        XCTAssertEqual(snapshot.taskCount, 3)
    }

    func testEligibilitySuppressesWhenPromptWasDismissedForCurrentVersion() async {
        let suiteName = UUID().uuidString
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let store = AppOnboardingStateStore(userDefaults: suite)
        store.markEstablishedWorkspacePromptDismissed()

        let service = OnboardingEligibilityService(
            stateStore: store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "General"), LifeArea(name: "Home")] },
            fetchProjects: { [Project.createInbox(), Project(name: "Home reset")] },
            fetchTasks: { [TaskDefinition(title: "One"), TaskDefinition(title: "Two"), TaskDefinition(title: "Three")] }
        )

        let result = await service.evaluate()
        XCTAssertEqual(result, .suppressed)
    }

    func testLifeAreaResolutionReusesExistingItemsInsteadOfDuplicates() {
        let existingArea = LifeArea(name: "Health")
        let selected = StarterWorkspaceCatalog.allLifeAreas.filter { ["health", "career"].contains($0.id) }

        let resolved = StarterWorkspaceCatalog.resolveLifeAreaSelections(
            selected: selected,
            existing: [existingArea]
        )

        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved.first?.existing?.id, existingArea.id)
        XCTAssertNil(resolved.last?.existing)
    }

    func testProjectResolutionReusesExistingProjectInsteadOfDuplicateNameFailure() {
        let lifeArea = LifeArea(name: "Career")
        let selected = StarterWorkspaceCatalog.projectTemplates(for: ["career"])
        let existingProject = Project(lifeAreaID: lifeArea.id, name: "Ship one thing")

        let resolved = StarterWorkspaceCatalog.resolveProjectSelections(
            selected: selected,
            existing: [existingProject],
            lifeAreasByTemplateID: ["career": lifeArea]
        )

        XCTAssertEqual(resolved.first?.existing?.id, existingProject.id)
    }

    func testCompletionTrackingAcceptsAnyCreatedTask() {
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let tracking = OnboardingCompletionTrackingState(
            highlightedTaskID: firstTaskID,
            acceptableTaskIDs: Set([firstTaskID, secondTaskID])
        )

        XCTAssertTrue(tracking.acceptsCompletion(reason: "completed", taskID: firstTaskID))
        XCTAssertTrue(tracking.acceptsCompletion(reason: "completed", taskID: secondTaskID))
    }

    func testCompletionTrackingRejectsNonOnboardingTask() {
        let trackedTaskID = UUID()
        let unrelatedTaskID = UUID()
        let tracking = OnboardingCompletionTrackingState(
            highlightedTaskID: trackedTaskID,
            acceptableTaskIDs: Set([trackedTaskID])
        )

        XCTAssertFalse(tracking.acceptsCompletion(reason: "completed", taskID: unrelatedTaskID))
        XCTAssertFalse(tracking.acceptsCompletion(reason: "created", taskID: trackedTaskID))
    }

    func testPresentationQueuePrefersCompletionOverLaunchPresentation() {
        var queue = OnboardingPresentationQueue()
        let summary = AppOnboardingSummary(
            lifeAreaCount: 2,
            projectCount: 2,
            createdTaskCount: 2,
            completedTaskTitle: "Walk for 10 minutes"
        )

        queue.enqueue(.prompt)
        queue.enqueue(.fullFlow(source: "launch_auto"))
        queue.enqueue(.completion(summary: summary))

        XCTAssertEqual(queue.pending, .completion(summary: summary))

        queue.markPresented(.completion(summary: summary))
        XCTAssertNil(queue.pending)
    }

    func testTodayDueIntentResolvesToSameDayDefault() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: 15, minute: 30))!

        let resolved = AddTaskPrefillDueIntent.today.resolvedDate(now: now, calendar: calendar)

        XCTAssertEqual(resolved, calendar.startOfDay(for: now))
        XCTAssertTrue(calendar.isDate(resolved ?? .distantPast, inSameDayAs: now))
    }

    @MainActor
    func testAddTaskPrefillAppliesTodayScopedDefaults() {
        let lifeArea = LifeArea(id: UUID(), name: "Health")
        let project = Project(id: UUID(), lifeAreaID: lifeArea.id, name: "Move your body")
        let dueDate = Date(timeIntervalSince1970: 1_000)

        let viewModel = AddTaskViewModel(
            manageProjectsUseCase: ManageProjectsUseCase(projectRepository: MockProjectRepository(projects: [Project.createInbox(), project])),
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(repository: MockTaskDefinitionRepository()),
            manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: MockLifeAreaRepository(lifeAreas: [lifeArea]))
        )

        let prefill = AddTaskPrefillTemplate(
            title: "Walk for 10 minutes",
            details: "Shoes on and out the door.",
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: lifeArea.id,
            priority: .low,
            type: .morning,
            dueDateIntent: .exact(dueDate),
            dueDate: dueDate,
            estimatedDuration: 600,
            energy: .low,
            showMoreDetails: true
        )

        viewModel.applyPrefill(prefill)
        waitUntil("prefill resolved") {
            viewModel.selectedProject == project.name
        }

        XCTAssertEqual(viewModel.taskName, "Walk for 10 minutes")
        XCTAssertEqual(viewModel.taskDetails, "Shoes on and out the door.")
        XCTAssertEqual(viewModel.selectedProject, project.name)
        XCTAssertEqual(viewModel.selectedLifeAreaID, lifeArea.id)
        XCTAssertEqual(viewModel.selectedPriority, .low)
        XCTAssertEqual(viewModel.selectedType, .morning)
        XCTAssertEqual(viewModel.selectedEnergy, .low)
        XCTAssertEqual(viewModel.estimatedDuration, 600)
        XCTAssertEqual(viewModel.dueDate, dueDate)
        XCTAssertTrue(viewModel.showMoreDetails)
    }

    @MainActor
    func testAddTaskPrefillLeavesInboxSelectionWhenProjectCannotBeResolved() {
        let lifeArea = LifeArea(id: UUID(), name: "Health")
        let taskRepository = MockTaskDefinitionRepository()
        let viewModel = AddTaskViewModel(
            manageProjectsUseCase: ManageProjectsUseCase(projectRepository: MockProjectRepository(projects: [Project.createInbox()])),
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(repository: taskRepository),
            manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: MockLifeAreaRepository(lifeAreas: [lifeArea]))
        )

        let prefill = AddTaskPrefillTemplate(
            title: "Walk for 10 minutes",
            projectID: UUID(),
            projectName: "Missing Project",
            lifeAreaID: lifeArea.id
        )

        viewModel.applyPrefill(prefill)
        drainMainQueue()

        XCTAssertEqual(viewModel.selectedProject, ProjectConstants.inboxProjectName)

        let expectation = expectation(description: "task created")
        viewModel.taskName = "Walk for 10 minutes"
        viewModel.createTask()
        DispatchQueue.main.async {
            XCTAssertEqual(taskRepository.lastCreateRequest?.projectID, ProjectConstants.inboxProjectID)
            XCTAssertEqual(taskRepository.lastCreateRequest?.projectName, ProjectConstants.inboxProjectName)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testHomeTasksSnapshotTreatsTodayDefaultEmptyStateAsCommittedContent() {
        let snapshot = HomeTasksSnapshot(
            morningTasks: [],
            eveningTasks: [],
            overdueTasks: [],
            inlineCompletedTasks: [],
            doneTimelineTasks: [],
            projects: [],
            projectsByID: [:],
            projectsByName: [:],
            tagNameByID: [:],
            rescueTasksByID: [:],
            activeQuickView: .today,
            todayXPSoFar: nil,
            projectGroupingMode: .defaultMode,
            customProjectOrderIDs: [],
            emptyStateMessage: nil,
            emptyStateActionTitle: nil,
            canUseManualFocusDrag: false,
            focusTasks: [],
            pinnedFocusTaskIDs: [],
            todayOpenTaskCount: 0
        )

        XCTAssertTrue(snapshot.rendersDefaultTodayEmptyState)
        XCTAssertTrue(snapshot.hasCommittedInitialContent)
    }

    func testHomeViewControllerAppliesInsightsLaunchRequestWhenAnalyticsIsAlreadyVisible() {
        let controller = HomeViewController()
        let insightsViewModel = makeInsightsViewModel()
        let request = InsightsLaunchRequest(targetTab: .systems, highlightedAchievementKey: "streak")

        controller.testingSetAnalyticsVisible(with: insightsViewModel)
        controller.testingHandleInsightsLaunchRequest(request)

        XCTAssertEqual(insightsViewModel.selectedTab, .systems)
        XCTAssertEqual(insightsViewModel.highlightedAchievementKey, "streak")
        XCTAssertNil(controller.testingPendingInsightsLaunchRequest)
    }

    @MainActor
    func testRunOnboardingEvaluationAfterDelayClearsPendingTaskAndRetriesOnSceneMismatch() async {
        let controller = HomeViewController()
        var retryCount = 0

        controller.testingSetPendingOnboardingEvaluationTask()
        controller.testingSetOnboardingEvaluationSceneToken(2)

        await controller.runOnboardingEvaluationAfterDelay(
            sceneToken: 1,
            sleepNanoseconds: 0,
            retry: { retryCount += 1 }
        )

        XCTAssertFalse(controller.testingHasPendingOnboardingEvaluationTask)
        XCTAssertEqual(retryCount, 1)
    }

    @MainActor
    func testRunOnboardingEvaluationAfterDelayClearsPendingTaskAndRetriesWhenViewIsUnavailable() async {
        let controller = HomeViewController()
        var retryCount = 0

        controller.testingSetPendingOnboardingEvaluationTask()
        controller.testingSetOnboardingEvaluationSceneToken(1)

        await controller.runOnboardingEvaluationAfterDelay(
            sceneToken: 1,
            sleepNanoseconds: 0,
            retry: { retryCount += 1 }
        )

        XCTAssertFalse(controller.testingHasPendingOnboardingEvaluationTask)
        XCTAssertEqual(retryCount, 1)
    }

    private func drainMainQueue() {
        let expectation = expectation(description: "Drain main queue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 1.0,
        condition: @escaping () -> Bool
    ) {
        let expectation = expectation(description: description)

        func poll() {
            if condition() {
                expectation.fulfill()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                poll()
            }
        }

        poll()
        wait(for: [expectation], timeout: timeout)
    }
}

private final class MockLifeAreaRepository: LifeAreaRepositoryProtocol {
    var lifeAreas: [LifeArea]

    init(lifeAreas: [LifeArea]) {
        self.lifeAreas = lifeAreas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        completion(.success(lifeAreas))
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        lifeAreas.append(area)
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class MockProjectRepository: ProjectRepositoryProtocol {
    var projects: [Project]

    init(projects: [Project]) {
        self.projects = projects
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects))
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.id == id })))
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.name == name })))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(projects.first(where: \.isInbox) ?? Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects.filter { !$0.isDefault }))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        projects.append(project)
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(projects.first(where: \.isInbox) ?? Project.createInbox()))
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: projects.count, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        guard let project = projects.first(where: { $0.id == id }) else {
            return completion(.failure(NSError(domain: "test", code: 404)))
        }
        var renamed = project
        renamed.name = newName
        completion(.success(renamed))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func moveProjectToLifeArea(projectID: UUID, lifeAreaID: UUID, completion: @escaping (Result<ProjectLifeAreaMoveResult, Error>) -> Void) {
        completion(.success(ProjectLifeAreaMoveResult(updatedProjectID: projectID, fromLifeAreaID: nil, toLifeAreaID: lifeAreaID, tasksRemappedCount: 0)))
    }

    func backfillProjectsWithoutLifeArea(defaultLifeAreaID: UUID, completion: @escaping (Result<ProjectLifeAreaBackfillResult, Error>) -> Void) {
        completion(.success(ProjectLifeAreaBackfillResult(defaultLifeAreaID: defaultLifeAreaID, projectsUpdatedCount: 0, tasksRemappedCount: 0, inboxPinned: true)))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isAvailable = projects.contains {
            $0.id != excludingId && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        } == false
        completion(.success(isAvailable))
    }
}

private final class MockTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    var lastCreateRequest: CreateTaskDefinitionRequest?

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(nil))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        lastCreateRequest = request
        completion(.success(TaskDefinition(id: request.id, projectID: request.projectID, projectName: request.projectName, title: request.title)))
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.failure(NSError(domain: "test", code: 1)))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private func makeInsightsViewModel() -> InsightsViewModel {
    let repository = MockInsightsGamificationRepository()
    return InsightsViewModel(
        engine: GamificationEngine(repository: repository),
        repository: repository
    )
}

private final class MockInsightsGamificationRepository: GamificationRepositoryProtocol {
    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) { completion(.success(nil)) }
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(false)) }
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) { completion(.success([])) }
    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) { completion(.success([])) }
}
