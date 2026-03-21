import XCTest
import UserNotifications
@testable import To_Do_List

final class AppOnboardingTests: XCTestCase {

    func testEligibilityReturnsFullFlowForEffectivelyEmptyWorkspace() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let service = OnboardingEligibilityService(
            stateStore: context.store,
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
        let context = makeStoreContext()
        defer { context.cleanup() }

        let service = OnboardingEligibilityService(
            stateStore: context.store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "General"), LifeArea(name: "Career")] },
            fetchProjects: { [Project.createInbox(), Project(name: "Ship one thing")] },
            fetchTasks: {
                [
                    TaskDefinition(title: "Draft update"),
                    TaskDefinition(title: "Send recap"),
                    TaskDefinition(title: "Plan next step")
                ]
            }
        )

        let result = await service.evaluate()

        guard case .promptOnly(let snapshot) = result else {
            return XCTFail("Expected prompt-only onboarding for an established workspace.")
        }
        XCTAssertEqual(snapshot.customLifeAreaCount, 1)
        XCTAssertEqual(snapshot.customProjectCount, 1)
        XCTAssertEqual(snapshot.taskCount, 3)
    }

    func testEligibilitySuppressesWhenCurrentVersionAlreadyHandled() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        context.store.markHandled(outcome: .completed)

        let service = OnboardingEligibilityService(
            stateStore: context.store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "Career")] },
            fetchProjects: { [Project.createInbox(), Project(name: "Ship one thing")] },
            fetchTasks: { [TaskDefinition(title: "Draft update")] }
        )

        let result = await service.evaluate()
        XCTAssertEqual(result, .suppressed)
    }

    func testDefaultLifeAreaSelectionRespectsFrictionProfileAndMode() {
        XCTAssertEqual(
            StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: .starting, mode: .guided),
            ["health", "career", "home"]
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: .overwhelmed, mode: .guided),
            ["home", "health"]
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: .remembering, mode: .custom),
            ["home"]
        )
    }

    func testCatalogReuseMatchesAliasesForExistingLifeAreasAndProjects() {
        let healthTemplate = tryUnwrap(StarterWorkspaceCatalog.lifeAreaTemplate(id: "health"))
        let existingLifeArea = LifeArea(name: "Wellness")

        let matchedLifeArea = StarterWorkspaceCatalog.matchingLifeArea(
            for: healthTemplate,
            in: [existingLifeArea]
        )

        XCTAssertEqual(matchedLifeArea?.id, existingLifeArea.id)

        let careerDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["career"], mode: .guided).first
        )
        let lifeAreaID = UUID()
        let existingProject = Project(lifeAreaID: lifeAreaID, name: "Deliverable")

        let matchedProject = StarterWorkspaceCatalog.matchingProject(
            for: careerDraft,
            lifeAreaID: lifeAreaID,
            in: [existingProject]
        )

        XCTAssertEqual(matchedProject?.id, existingProject.id)
    }

    @MainActor
    func testFlowModelCapsLifeAreaSelectionAtThree() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.begin(mode: .guided)
        viewModel.selectedLifeAreaIDs = []

        viewModel.toggleLifeArea("health")
        viewModel.toggleLifeArea("career")
        viewModel.toggleLifeArea("home")
        viewModel.toggleLifeArea("learning")

        XCTAssertEqual(viewModel.selectedLifeAreaIDs.count, 3)
        XCTAssertFalse(viewModel.selectedLifeAreaIDs.contains("learning"))
        XCTAssertTrue(viewModel.canContinueLifeAreas)
    }

    @MainActor
    func testPrepareForPresentationRestoresJourneySnapshot() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Put on workout clothes",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health"], mode: .guided).first
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .focusRoom,
            mode: .guided,
            frictionProfile: .starting,
            selectedLifeAreaIDs: ["health"],
            showAllLifeAreas: false,
            projectDrafts: [projectDraft],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "health", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdTasks: [task],
            createdTaskTemplateMap: ["task-health-move-clothes": task.id],
            focusTaskID: task.id,
            parentFocusTaskID: nil,
            focusStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            focusIsActive: true,
            successSummary: nil,
            hasSeenSuccess: false
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)

        XCTAssertEqual(viewModel.step, .focusRoom)
        XCTAssertEqual(viewModel.mode, .guided)
        XCTAssertEqual(viewModel.frictionProfile, .starting)
        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["health"]))
        XCTAssertEqual(viewModel.focusTaskID, task.id)
        XCTAssertTrue(viewModel.focusIsActive)
        XCTAssertEqual(viewModel.createdTasks.map(\.id), [task.id])
    }

    @MainActor
    func testStoreAndRestoreJourneySnapshotPreservesMidFlowState() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Put on workout clothes",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health"], mode: .guided).first
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .projects,
            mode: .custom,
            frictionProfile: .choosing,
            selectedLifeAreaIDs: ["health"],
            showAllLifeAreas: true,
            projectDrafts: [projectDraft],
            expandedProjectIDs: [UUID()],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "health", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdTasks: [task],
            createdTaskTemplateMap: ["task-health-move-clothes": task.id],
            focusTaskID: task.id,
            parentFocusTaskID: nil,
            focusStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            focusIsActive: false,
            successSummary: nil,
            hasSeenSuccess: false,
            reminderPromptDismissed: false
        )

        context.store.storeJourney(snapshot)

        let restoredSnapshot = tryUnwrap(context.store.load().journeySnapshot)
        XCTAssertEqual(restoredSnapshot.step, .projects)
        XCTAssertEqual(restoredSnapshot.selectedLifeAreaIDs, ["health"])

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: restoredSnapshot)

        XCTAssertEqual(viewModel.step, .projects)
        XCTAssertEqual(viewModel.mode, .custom)
        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["health"]))
        XCTAssertTrue(viewModel.showAllLifeAreas)
        XCTAssertEqual(viewModel.projectDrafts, [projectDraft])
        XCTAssertEqual(viewModel.createdTasks.map(\.id), [task.id])
        XCTAssertEqual(viewModel.focusTaskID, task.id)
    }

    @MainActor
    func testPrepareForPresentationRestoresSuccessStateAndReminderPrompt() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let notificationService = TestNotificationService(status: .notDetermined)
        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Fill your water bottle",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health"], mode: .guided).first
        )
        let summary = AppOnboardingSummary(
            lifeAreaCount: 1,
            projectCount: 1,
            createdTaskCount: 1,
            completedTaskCount: 1,
            completedTaskTitle: task.title,
            nextTaskTitle: nil,
            promptReminderAfterSuccess: true
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .focusRoom,
            mode: .guided,
            frictionProfile: .starting,
            selectedLifeAreaIDs: ["health"],
            showAllLifeAreas: false,
            projectDrafts: [projectDraft],
            expandedProjectIDs: [],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "health", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdTasks: [task],
            createdTaskTemplateMap: ["task-health-meal-snack": task.id],
            focusTaskID: task.id,
            parentFocusTaskID: nil,
            focusStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            focusIsActive: false,
            successSummary: summary,
            hasSeenSuccess: true,
            reminderPromptDismissed: false
        )

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            notificationService: notificationService
        )
        viewModel.prepareForPresentation(snapshot: snapshot)

        XCTAssertEqual(viewModel.step, .focusRoom)
        XCTAssertEqual(viewModel.successSummary, summary)
        XCTAssertEqual(viewModel.resolvedLifeAreas.map(\.lifeArea.name), ["Health"])
        XCTAssertEqual(viewModel.resolvedProjects.map(\.project.name), ["Move your body"])

        for _ in 0..<10 where viewModel.reminderPromptState != .prompt {
            try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(viewModel.reminderPromptState, .prompt)
    }

    func testPresentationQueuePrefersFullFlowOverPrompt() {
        var queue = OnboardingPresentationQueue()
        let snapshot = OnboardingWorkspaceSnapshot(customLifeAreaCount: 1, customProjectCount: 1, taskCount: 3)

        queue.enqueue(.prompt(snapshot: snapshot))
        XCTAssertEqual(queue.pending, .prompt(snapshot: snapshot))

        queue.enqueue(.fullFlow(source: "resume"))
        XCTAssertEqual(queue.pending, .fullFlow(source: "resume"))

        queue.markPresented(.prompt(snapshot: snapshot))
        XCTAssertEqual(queue.pending, .fullFlow(source: "resume"))

        queue.markPresented(.fullFlow(source: "resume"))
        XCTAssertNil(queue.pending)
    }

    @MainActor
    func testResetForReplayClearsPersistedJourneyAndReturnsToWelcome() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Career")
        let project = Project(lifeAreaID: area.id, name: "Ship one thing")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Open the draft and write 3 lines",
            estimatedDuration: 120
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["career"], mode: .guided).first
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .firstTask,
            mode: .guided,
            frictionProfile: .starting,
            selectedLifeAreaIDs: ["career"],
            showAllLifeAreas: false,
            projectDrafts: [projectDraft],
            expandedProjectIDs: [],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "career", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdTasks: [task],
            createdTaskTemplateMap: [:],
            focusTaskID: task.id,
            parentFocusTaskID: nil,
            focusStartedAt: nil,
            focusIsActive: false,
            successSummary: nil,
            hasSeenSuccess: false,
            reminderPromptDismissed: false
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)
        viewModel.resetForReplay()

        XCTAssertEqual(viewModel.step, .welcome)
        XCTAssertEqual(viewModel.mode, .guided)
        XCTAssertNil(viewModel.frictionProfile)
        XCTAssertTrue(viewModel.selectedLifeAreaIDs.isEmpty)
        XCTAssertTrue(viewModel.projectDrafts.isEmpty)
        XCTAssertTrue(viewModel.createdTasks.isEmpty)
        XCTAssertNil(context.store.load().journeySnapshot)
    }

    func testMarkHandledClearsPersistedJourneySnapshot() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let snapshot = OnboardingJourneySnapshot(
            step: .welcome,
            mode: .guided,
            frictionProfile: nil,
            selectedLifeAreaIDs: [],
            showAllLifeAreas: false,
            projectDrafts: [],
            expandedProjectIDs: [],
            resolvedLifeAreas: [],
            resolvedProjects: [],
            createdTasks: [],
            createdTaskTemplateMap: [:],
            focusTaskID: nil,
            parentFocusTaskID: nil,
            focusStartedAt: nil,
            focusIsActive: false,
            successSummary: nil,
            hasSeenSuccess: false,
            reminderPromptDismissed: false
        )

        context.store.storeJourney(snapshot)
        context.store.markHandled(outcome: .completed)

        let state = context.store.load()
        XCTAssertEqual(state.outcome, .completed)
        XCTAssertEqual(state.completedVersion, AppOnboardingState.currentVersion)
        XCTAssertNil(state.journeySnapshot)
        XCTAssertTrue(state.hasHandledCurrentVersion)
    }

    @MainActor
    func testSkipToFocusRoomSeedsStarterWorkspaceAndTask() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        var createdLifeAreas: [LifeArea] = []
        var createdProjects: [Project] = []
        var createdTasks: [TaskDefinition] = []

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            fetchLifeAreas: { [] },
            fetchProjects: { [] },
            fetchTask: { taskID in createdTasks.first(where: { $0.id == taskID }) },
            createLifeArea: { template in
                let area = LifeArea(name: template.name, color: template.colorHex, icon: template.icon)
                createdLifeAreas.append(area)
                return area
            },
            createProject: { draft, lifeArea in
                let project = Project(lifeAreaID: lifeArea.id, name: draft.name, projectDescription: draft.summary)
                createdProjects.append(project)
                return project
            },
            createTask: { request in
                let task = request.toTaskDefinition(projectName: request.projectName)
                createdTasks.append(task)
                return task
            }
        )

        await viewModel.skipToFocusRoom()

        XCTAssertEqual(viewModel.step, .focusRoom)
        XCTAssertFalse(createdLifeAreas.isEmpty)
        XCTAssertFalse(createdProjects.isEmpty)
        XCTAssertEqual(createdTasks.count, 1)
        XCTAssertEqual(viewModel.createdTasks.count, 1)
        XCTAssertEqual(viewModel.focusTaskID, createdTasks.first?.id)
        XCTAssertEqual(context.store.load().journeySnapshot?.step, .focusRoom)
    }

    @MainActor
    func testBreakdownPromotesFirstAddedChildTaskIntoFocus() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Career")
        let project = Project(lifeAreaID: area.id, name: "Ship one thing")
        let focusTask = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Open the draft and write 3 lines",
            estimatedDuration: 120
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["career"], mode: .guided).first
        )

        var createdChildren: [TaskDefinition] = []
        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            createTask: { request in
                let child = request.toTaskDefinition(projectName: request.projectName)
                createdChildren.append(child)
                return child
            }
        )
        viewModel.prepareForPresentation(
            snapshot: OnboardingJourneySnapshot(
                step: .focusRoom,
                mode: .guided,
                frictionProfile: .starting,
                selectedLifeAreaIDs: ["career"],
                showAllLifeAreas: false,
                projectDrafts: [projectDraft],
                resolvedLifeAreas: [
                    ResolvedLifeAreaSelection(templateID: "career", lifeArea: area, reusedExisting: true)
                ],
                resolvedProjects: [
                    ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
                ],
                createdTasks: [focusTask],
                createdTaskTemplateMap: [:],
                focusTaskID: focusTask.id,
                parentFocusTaskID: nil,
                focusStartedAt: nil,
                focusIsActive: false,
                successSummary: nil,
                hasSeenSuccess: false
            )
        )
        viewModel.breakdownSteps = [
            OnboardingBreakdownStep(title: "Open the draft", isSelected: true),
            OnboardingBreakdownStep(title: "Write one sentence", isSelected: true)
        ]

        await viewModel.applySelectedBreakdownSteps()

        XCTAssertEqual(createdChildren.count, 2)
        XCTAssertEqual(viewModel.parentFocusTaskID, focusTask.id)
        XCTAssertEqual(viewModel.focusTask?.title, "Open the draft")
        XCTAssertEqual(createdChildren.first?.parentTaskID, focusTask.id)
    }

    @MainActor
    func testCompleteFocusTaskBuildsSuccessSummaryAndReminderPrompt() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let notificationService = TestNotificationService(status: .notDetermined)
        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            id: UUID(),
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Fill your water bottle",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health"], mode: .guided).first
        )

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            notificationService: notificationService,
            setTaskCompletion: { taskID, isComplete in
                var completed = task
                completed.isComplete = isComplete
                completed.dateCompleted = isComplete ? Date() : nil
                return completed
            }
        )
        viewModel.prepareForPresentation(
            snapshot: OnboardingJourneySnapshot(
                step: .focusRoom,
                mode: .guided,
                frictionProfile: .starting,
                selectedLifeAreaIDs: ["health"],
                showAllLifeAreas: false,
                projectDrafts: [projectDraft],
                resolvedLifeAreas: [
                    ResolvedLifeAreaSelection(templateID: "health", lifeArea: area, reusedExisting: true)
                ],
                resolvedProjects: [
                    ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
                ],
                createdTasks: [task],
                createdTaskTemplateMap: [:],
                focusTaskID: task.id,
                parentFocusTaskID: nil,
                focusStartedAt: Date(),
                focusIsActive: true,
                successSummary: nil,
                hasSeenSuccess: false
            )
        )

        await viewModel.completeFocusTask()

        XCTAssertEqual(viewModel.reminderPromptState, .prompt)
        XCTAssertEqual(viewModel.successSummary?.completedTaskTitle, "Fill your water bottle")
        XCTAssertEqual(viewModel.successSummary?.completedTaskCount, 1)
        XCTAssertNil(viewModel.successSummary?.nextTaskTitle)
        XCTAssertEqual(viewModel.successSummary?.promptReminderAfterSuccess, true)
    }

    private func makeStoreContext() -> StoreContext {
        let suiteName = "AppOnboardingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = AppOnboardingStateStore(userDefaults: defaults)
        return StoreContext(store: store) {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected value to exist", file: file, line: line)
            fatalError("Unreachable after XCTFail")
        }
        return value
    }
}

private struct StoreContext {
    let store: AppOnboardingStateStore
    let cleanup: () -> Void
}

private final class TestNotificationService: NotificationServiceProtocol {
    var status: TaskerNotificationAuthorizationStatus
    var permissionGranted = true

    init(status: TaskerNotificationAuthorizationStatus) {
        self.status = status
    }

    func scheduleTaskReminder(taskId: UUID, taskName: String, at date: Date) {}
    func cancelTaskReminder(taskId: UUID) {}
    func cancelAllReminders() {}
    func send(_ notification: CollaborationNotification) {}
    func requestPermission(completion: @escaping (Bool) -> Void) { completion(permissionGranted) }
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        completion(status == .authorized || status == .provisional || status == .ephemeral)
    }
    func schedule(request: TaskerLocalNotificationRequest) {}
    func cancel(ids: [String]) {}
    func pendingRequests(completion: @escaping ([TaskerPendingNotificationRequest]) -> Void) { completion([]) }
    func registerCategories(_ categories: Set<UNNotificationCategory>) {}
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {}
    func fetchAuthorizationStatus(completion: @escaping (TaskerNotificationAuthorizationStatus) -> Void) {
        completion(status)
    }
}
