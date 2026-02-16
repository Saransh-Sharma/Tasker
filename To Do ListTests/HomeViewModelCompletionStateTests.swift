import XCTest
@testable import To_Do_List

final class HomeViewModelCompletionStateTests: XCTestCase {

    func testRequestChartRefreshPostsReasonPayload() {
        let expectation = expectation(description: "homeTaskMutation notification")

        let suiteName = "HomeViewModelCompletionStateTests.RequestChartRefresh.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        var observedReason: String?
        let token = NotificationCenter.default.addObserver(
            forName: .homeTaskMutation,
            object: nil,
            queue: .main
        ) { notification in
            observedReason = notification.userInfo?["reason"] as? String
            expectation.fulfill()
        }

        defer {
            NotificationCenter.default.removeObserver(token)
            defaults.removePersistentDomain(forName: suiteName)
        }

        viewModel.requestChartRefresh(reason: .priorityChanged)
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(observedReason, HomeTaskMutationEvent.priorityChanged.rawValue)
    }

    func testCreateDeleteRescheduleAndToggleEmitMutationRefreshEvents() {
        let suiteName = "HomeViewModelCompletionStateTests.MutationEvents.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let seedTask = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Seed",
            type: .morning,
            dueDate: now.addingTimeInterval(1800),
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [seedTask])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        var observedReasons: [String] = []
        let token = NotificationCenter.default.addObserver(
            forName: .homeTaskMutation,
            object: nil,
            queue: .main
        ) { notification in
            if let reason = notification.userInfo?["reason"] as? String {
                observedReasons.append(reason)
            }
        }

        defer {
            NotificationCenter.default.removeObserver(token)
            defaults.removePersistentDomain(forName: suiteName)
        }

        waitForMainQueueFlush()

        viewModel.createTask(
            request: CreateTaskRequest(
                name: "Created",
                dueDate: Date().addingTimeInterval(3600)
            )
        )
        waitForMainQueueDelay(0.1)

        guard let openTask = viewModel.morningTasks.first else {
            return XCTFail("Expected an open task after initial load")
        }

        viewModel.rescheduleTask(openTask, to: Date().addingTimeInterval(7200))
        waitForMainQueueDelay(0.1)

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.1)

        viewModel.deleteTask(openTask)
        waitForMainQueueDelay(0.1)

        let reasonSet = Set(observedReasons)
        XCTAssertTrue(reasonSet.contains(HomeTaskMutationEvent.created.rawValue))
        XCTAssertTrue(reasonSet.contains(HomeTaskMutationEvent.rescheduled.rawValue))
        XCTAssertTrue(reasonSet.contains(HomeTaskMutationEvent.completed.rawValue) || reasonSet.contains(HomeTaskMutationEvent.reopened.rawValue))
        XCTAssertTrue(reasonSet.contains(HomeTaskMutationEvent.deleted.rawValue))
    }

    func testToggleCompletionUpdatesPublishedOpenAndCompletedStateWithoutRestart() {
        let suiteName = "HomeViewModelCompletionStateTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Focusable task",
            type: .morning,
            dueDate: dueDate,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.completedTasks.count, 0)
        XCTAssertEqual(viewModel.morningTasks.map(\.id), [task.id])

        guard let openTask = viewModel.morningTasks.first else {
            return XCTFail("Expected initial open task in morning list")
        }
        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueFlush()

        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && $0.isComplete }))
        XCTAssertEqual(viewModel.completedTasks.map(\.id), [task.id])
        assertNoOpenDoneOverlap(viewModel)

        guard let completedTask = viewModel.completedTasks.first else {
            return XCTFail("Expected task to move to completed collection")
        }
        viewModel.toggleTaskCompletion(completedTask)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.completedTasks.count, 0)
        XCTAssertEqual(viewModel.morningTasks.map(\.id), [task.id])
        assertNoOpenDoneOverlap(viewModel)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testToggleCompletionUpdatesRowStateImmediatelyBeforeReloadCompletes() {
        let suiteName = "HomeViewModelCompletionStateTests.Immediate.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Immediate toggle task",
            type: .morning,
            dueDate: dueDate,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        taskRepository.fetchAllTasksDelay = 0.4

        guard let openTask = viewModel.morningTasks.first else {
            return XCTFail("Expected initial open task in morning list")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.05)

        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && $0.isComplete }))
        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.id == task.id && $0.isComplete }))
        assertNoOpenDoneOverlap(viewModel)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReopenMovesTaskBackToOpenImmediatelyBeforeReloadCompletes() {
        let suiteName = "HomeViewModelCompletionStateTests.ReopenImmediate.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Immediate reopen task",
            type: .morning,
            dueDate: now,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        taskRepository.fetchAllTasksDelay = 0.4

        guard let openTask = viewModel.morningTasks.first else {
            return XCTFail("Expected initial open task")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.05)
        guard let completedTask = viewModel.completedTasks.first(where: { $0.id == task.id }) else {
            return XCTFail("Expected completed task before reopen")
        }

        viewModel.toggleTaskCompletion(completedTask)
        waitForMainQueueDelay(0.05)

        XCTAssertFalse(viewModel.completedTasks.contains(where: { $0.id == task.id }))
        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && !$0.isComplete }))
        assertNoOpenDoneOverlap(viewModel)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCustomDateToggleCompletionKeepsTaskInlineInVisibleSection() {
        let suiteName = "HomeViewModelCompletionStateTests.CustomDateInline.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = Calendar.current
        let anchorDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: anchorDate) ?? anchorDate

        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Custom date inline task",
            type: .morning,
            dueDate: dueDate,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        viewModel.selectDate(anchorDate)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.activeScope, .customDate(anchorDate))
        guard let openTask = viewModel.morningTasks.first(where: { $0.id == task.id }) else {
            return XCTFail("Expected task in custom-date morning list")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.05)

        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && $0.isComplete }))
        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.id == task.id && $0.isComplete }))
        assertNoOpenDoneOverlap(viewModel)

        guard let completedTask = viewModel.completedTasks.first(where: { $0.id == task.id }) else {
            return XCTFail("Expected completed task in custom-date scope")
        }

        viewModel.toggleTaskCompletion(completedTask)
        waitForMainQueueDelay(0.05)

        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && !$0.isComplete }))
        XCTAssertFalse(viewModel.completedTasks.contains(where: { $0.id == task.id }))
        assertNoOpenDoneOverlap(viewModel)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDoneQuickViewReopenRemovesTaskImmediatelyBeforeReloadCompletes() {
        let suiteName = "HomeViewModelCompletionStateTests.DoneImmediate.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let completedTask = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Done timeline task",
            type: .morning,
            dueDate: now,
            project: ProjectConstants.inboxProjectName,
            isComplete: true,
            dateCompleted: now
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [completedTask])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        viewModel.setQuickView(.done)
        waitForMainQueueFlush()
        XCTAssertEqual(viewModel.doneTimelineTasks.count, 1)

        taskRepository.fetchAllTasksDelay = 0.4
        guard let task = viewModel.doneTimelineTasks.first else {
            return XCTFail("Expected task in done timeline")
        }

        viewModel.toggleTaskCompletion(task)
        waitForMainQueueDelay(0.05)

        XCTAssertTrue(viewModel.doneTimelineTasks.isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCompletionOverrideClearsAfterReloadReconcilesPersistedState() {
        let suiteName = "HomeViewModelCompletionStateTests.OverrideClear.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Override clear task",
            type: .morning,
            dueDate: now,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        taskRepository.fetchAllTasksDelay = 0.3
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        guard let openTask = viewModel.morningTasks.first else {
            return XCTFail("Expected initial open task in morning list")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.05)
        XCTAssertEqual(viewModel.completionOverride(for: task.id), true)

        waitForMainQueueDelay(0.35)
        XCTAssertNil(viewModel.completionOverride(for: task.id))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLatestReloadGenerationWinsOverStaleResponse() {
        let suiteName = "HomeViewModelCompletionStateTests.GenerationGuard.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let taskID = UUID()
        let openTask = Task(
            id: taskID,
            projectID: ProjectConstants.inboxProjectID,
            name: "Generation guarded task",
            type: .morning,
            dueDate: now,
            project: ProjectConstants.inboxProjectName,
            isComplete: false
        )
        let doneTask = Task(
            id: taskID,
            projectID: ProjectConstants.inboxProjectID,
            name: "Generation guarded task",
            type: .morning,
            dueDate: now,
            project: ProjectConstants.inboxProjectName,
            isComplete: true,
            dateCompleted: now
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [openTask])
        taskRepository.scriptedFetchAllTasksResponses = [
            (delay: 0.30, tasks: [openTask]),   // stale response (older generation)
            (delay: 0.05, tasks: [doneTask])    // latest response
        ]
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        viewModel.loadTodayTasks()
        viewModel.loadTodayTasks()

        waitForMainQueueDelay(0.45)

        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.id == taskID && $0.isComplete }))
        XCTAssertFalse(viewModel.morningTasks.contains(where: { $0.id == taskID && !$0.isComplete }))
        assertNoOpenDoneOverlap(viewModel)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRapidOpenDoneOpenTogglesDoNotProduceStaleState() {
        let suiteName = "HomeViewModelCompletionStateTests.RapidToggle.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Rapid toggle task",
            type: .morning,
            dueDate: now,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        taskRepository.fetchAllTasksDelay = 0.35
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        guard var currentTask = viewModel.morningTasks.first(where: { $0.id == task.id }) else {
            return XCTFail("Expected initial open task")
        }

        for step in 0..<4 {
            viewModel.toggleTaskCompletion(currentTask)
            waitForMainQueueDelay(0.05)
            assertNoOpenDoneOverlap(viewModel)

            if step % 2 == 0 {
                guard let doneTask = viewModel.completedTasks.first(where: { $0.id == task.id && $0.isComplete }) else {
                    return XCTFail("Expected done state at step \(step)")
                }
                currentTask = doneTask
            } else {
                guard let openTask = viewModel.morningTasks.first(where: { $0.id == task.id && !$0.isComplete }) else {
                    return XCTFail("Expected open state at step \(step)")
                }
                currentTask = openTask
            }
        }

        waitForMainQueueDelay(0.4)
        assertNoOpenDoneOverlap(viewModel)
        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && !$0.isComplete }))
        XCTAssertFalse(viewModel.completedTasks.contains(where: { $0.id == task.id }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRapidToggleOverrideReconcilesWithoutRegressingImmediateRowState() {
        let suiteName = "HomeViewModelCompletionStateTests.OverrideRapid.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Override rapid task",
            type: .morning,
            dueDate: now,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        taskRepository.fetchAllTasksDelay = 0.35
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        guard let openTask = viewModel.morningTasks.first(where: { $0.id == task.id }) else {
            return XCTFail("Expected initial open task")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.05)
        XCTAssertEqual(viewModel.completionOverride(for: task.id), true)
        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.id == task.id && $0.isComplete }))

        guard let doneTask = viewModel.completedTasks.first(where: { $0.id == task.id }) else {
            return XCTFail("Expected done task before reopen")
        }
        viewModel.toggleTaskCompletion(doneTask)
        waitForMainQueueDelay(0.05)

        XCTAssertEqual(viewModel.completionOverride(for: task.id), false)
        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && !$0.isComplete }))
        XCTAssertFalse(viewModel.completedTasks.contains(where: { $0.id == task.id }))
        assertNoOpenDoneOverlap(viewModel)

        waitForMainQueueDelay(0.4)
        XCTAssertNil(viewModel.completionOverride(for: task.id))
        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && !$0.isComplete }))
        XCTAssertFalse(viewModel.completedTasks.contains(where: { $0.id == task.id }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTodayCompletionRetainedInlineWhenReloadSnapshotTemporarilyDropsTask() {
        let suiteName = "HomeViewModelCompletionStateTests.TodayRetention.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Inline retention task",
            type: .morning,
            dueDate: dueDate,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        guard let openTask = viewModel.morningTasks.first(where: { $0.id == task.id }) else {
            return XCTFail("Expected initial task in morning list")
        }

        taskRepository.scriptedFetchAllTasksResponses = [(delay: 0.0, tasks: [])]

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.12)

        let allVisible = viewModel.morningTasks + viewModel.eveningTasks + viewModel.overdueTasks
        XCTAssertTrue(allVisible.contains(where: { $0.id == task.id && $0.isComplete }))
        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.id == task.id && $0.isComplete }))
        assertNoOpenDoneOverlap(viewModel)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testToggleCompletionIgnoresStaleFetchTaskSnapshotAndFollowsRowIntent() {
        let suiteName = "HomeViewModelCompletionStateTests.StaleFetchSnapshot.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Stale fetch task",
            type: .morning,
            dueDate: dueDate,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        guard let openTask = viewModel.morningTasks.first(where: { $0.id == task.id && !$0.isComplete }) else {
            return XCTFail("Expected open task in morning list")
        }

        var staleCompleted = task
        staleCompleted.isComplete = true
        staleCompleted.dateCompleted = Date()
        taskRepository.fetchTaskOverrideByID[task.id] = staleCompleted

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.05)

        XCTAssertEqual(taskRepository.fetchTaskCallCount, 0, "Home completion should not depend on fetchTask for toggle direction")
        XCTAssertTrue(viewModel.morningTasks.contains(where: { $0.id == task.id && $0.isComplete }))
        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.id == task.id && $0.isComplete }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testUpcomingToggleCompletionKeepsNonDateScopeBehavior() {
        let suiteName = "HomeViewModelCompletionStateTests.UpcomingNonInline.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let dueTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Upcoming scope task",
            type: .morning,
            dueDate: dueTomorrow,
            project: ProjectConstants.inboxProjectName
        )

        let taskRepository = MutableCompletionMockTaskRepository(tasks: [task])
        let projectRepository = MutableCompletionMockProjectRepository(projects: [Project.createInbox()])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()
        viewModel.setQuickView(.upcoming)
        waitForMainQueueFlush()

        guard let openTask = viewModel.upcomingTasks.first(where: { $0.id == task.id && !$0.isComplete }) else {
            return XCTFail("Expected open task in upcoming list")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueDelay(0.05)

        XCTAssertFalse(viewModel.upcomingTasks.contains(where: { $0.id == task.id }), "Upcoming should keep non-inline behavior")
        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.id == task.id && $0.isComplete }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSetCompletionUsesRequestedStateWithoutFetchTaskDirectionCheck() {
        let task = Task(
            projectID: ProjectConstants.inboxProjectID,
            name: "Deterministic use case task",
            type: .morning,
            priority: .high,
            dueDate: Date(),
            project: ProjectConstants.inboxProjectName,
            isComplete: true,
            dateCompleted: Date()
        )

        let repository = MutableCompletionMockTaskRepository(tasks: [task])
        var staleOpen = task
        staleOpen.isComplete = false
        staleOpen.dateCompleted = nil
        repository.fetchTaskOverrideByID[task.id] = staleOpen

        let useCase = CompleteTaskUseCase(
            taskRepository: repository,
            scoringService: DefaultTaskScoringService(),
            analyticsService: nil
        )

        let expectation = expectation(description: "setCompletion deterministic")
        var captured: TaskCompletionResult?

        useCase.setCompletion(taskId: task.id, to: false, taskSnapshot: task) { result in
            if case let .success(value) = result {
                captured = value
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(repository.fetchTaskCallCount, 0)
        XCTAssertEqual(captured?.task.id, task.id)
        XCTAssertEqual(captured?.task.isComplete, false)
        XCTAssertEqual(captured?.scoreEarned, -task.priority.scorePoints)
    }

    private func waitForMainQueueFlush() {
        let expectation = expectation(description: "MainQueueFlush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func waitForMainQueueDelay(_ delay: TimeInterval) {
        let expectation = expectation(description: "MainQueueDelay\(delay)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: max(1.0, delay + 0.5))
    }

    private func assertNoOpenDoneOverlap(_ viewModel: HomeViewModel) {
        let openTasks = viewModel.morningTasks + viewModel.eveningTasks + viewModel.overdueTasks + viewModel.upcomingTasks
        let openIDs = Set(openTasks.map(\.id))
        let doneIDs = Set(
            (viewModel.completedTasks + viewModel.dailyCompletedTasks + viewModel.doneTimelineTasks)
                .map(\.id)
        )
        let overlap = openIDs.intersection(doneIDs)

        if isDateAnchoredScope(viewModel.activeScope) {
            let inlineCompletedIDs = Set(openTasks.filter(\.isComplete).map(\.id))
            XCTAssertEqual(
                overlap,
                inlineCompletedIDs,
                "Only inline completed rows should overlap with done collections in date-anchored scopes"
            )
            return
        }

        XCTAssertTrue(overlap.isEmpty, "Task IDs should not exist in both open and done sets")
    }

    private func isDateAnchoredScope(_ scope: HomeListScope) -> Bool {
        switch scope {
        case .today, .customDate:
            return true
        case .upcoming, .done, .morning, .evening:
            return false
        }
    }
}

private final class MutableCompletionMockProjectRepository: ProjectRepositoryProtocol {
    private var projects: [Project]

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
        completion(.success(projects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.isInbox }) ?? Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects.filter { !$0.isInbox }))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        projects.append(project)
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        if let inbox = projects.first(where: { $0.isInbox }) {
            completion(.success(inbox))
            return
        }
        let inbox = Project.createInbox()
        projects.append(inbox)
        completion(.success(inbox))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        var updated = projects[index]
        updated.name = newName
        projects[index] = updated
        completion(.success(updated))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        projects.removeAll { $0.id == id }
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        let exists = projects.contains { project in
            if let excludingId, project.id == excludingId {
                return false
            }
            return project.name.caseInsensitiveCompare(name) == .orderedSame
        }
        completion(.success(!exists))
    }
}

private final class MutableCompletionMockTaskRepository: TaskRepositoryProtocol {
    private var tasks: [Task]
    var fetchAllTasksDelay: TimeInterval = 0
    var scriptedFetchAllTasksResponses: [(delay: TimeInterval, tasks: [Task])] = []
    var fetchTaskCallCount: Int = 0
    var fetchTaskOverrideByID: [UUID: Task] = [:]

    init(tasks: [Task]) {
        self.tasks = tasks
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        if !scriptedFetchAllTasksResponses.isEmpty {
            let response = scriptedFetchAllTasksResponses.removeFirst()
            guard response.delay > 0 else {
                completion(.success(response.tasks))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + response.delay) {
                completion(.success(response.tasks))
            }
            return
        }

        let snapshot = tasks
        guard fetchAllTasksDelay > 0 else {
            completion(.success(snapshot))
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + fetchAllTasksDelay) {
            completion(.success(snapshot))
        }
    }
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.project == project })) }
    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.projectID == projectID })) }
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.isOverdue })) }
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.isComplete })) }
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.type == type })) }
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        fetchTaskCallCount += 1
        if let override = fetchTaskOverrideByID[id] {
            completion(.success(override))
            return
        }
        completion(.success(tasks.first { $0.id == id }))
    }
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { task in
        guard let dueDate = task.dueDate else { return false }
        return dueDate >= startDate && dueDate <= endDate
    })) }
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        tasks.append(task)
        completion(.success(task))
    }
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        tasks[index] = task
        completion(.success(task))
    }
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        tasks[index].isComplete = true
        tasks[index].dateCompleted = Date()
        completion(.success(tasks[index]))
    }
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        tasks[index].isComplete = false
        tasks[index].dateCompleted = nil
        completion(.success(tasks[index]))
    }
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        tasks[index].dueDate = date
        completion(.success(tasks[index]))
    }
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        tasks.removeAll { $0.id == id }
        completion(.success(()))
    }
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        tasks.removeAll { $0.isComplete }
        completion(.success(()))
    }
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        self.tasks.append(contentsOf: tasks)
        completion(.success(tasks))
    }
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        for task in tasks {
            if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                self.tasks[index] = task
            }
        }
        completion(.success(tasks))
    }
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        let idSet = Set(ids)
        tasks.removeAll { idSet.contains($0.id) }
        completion(.success(()))
    }
    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }
    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let idSet = Set(taskIDs)
        for index in tasks.indices where idSet.contains(tasks[index].id) {
            tasks[index].projectID = projectID
        }
        completion(.success(()))
    }
    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks.filter { $0.projectID == ProjectConstants.inboxProjectID }))
    }
}
