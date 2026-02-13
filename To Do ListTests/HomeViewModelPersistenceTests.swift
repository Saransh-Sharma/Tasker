import XCTest
@testable import To_Do_List

final class HomeViewModelPersistenceTests: XCTestCase {

    func testGroupingModeAndCustomProjectOrderPersistAcrossSessions() {
        let suiteName = "HomeViewModelPersistenceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let alpha = Project(id: UUID(), name: "Alpha", icon: .folder)
        let beta = Project(id: UUID(), name: "Beta", icon: .folder)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [
            makeTask(name: "Alpha task", project: alpha, dueDate: Date()),
            makeTask(name: "Beta task", project: beta, dueDate: Date())
        ])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox, alpha, beta])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModelA = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        viewModelA.setProjectGroupingMode(.groupByProjects)
        viewModelA.setCustomProjectOrder([beta.id, alpha.id])

        let viewModelB = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModelB.activeFilterState.projectGroupingMode, .groupByProjects)
        XCTAssertEqual(Array(viewModelB.activeFilterState.customProjectOrderIDs.prefix(2)), [beta.id, alpha.id])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testProgressStateTracksEarnedAndRemainingXP() {
        let suiteName = "HomeViewModelPersistenceTests.ProgressState.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let highXPTask = makeTask(name: "Progress task", project: inbox, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [highXPTask])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.progressState.earnedXP, viewModel.dailyScore)
        XCTAssertEqual(viewModel.progressState.remainingPotentialXP, viewModel.pointsPotential)
        XCTAssertEqual(
            viewModel.progressState.todayTargetXP,
            viewModel.progressState.earnedXP + viewModel.progressState.remainingPotentialXP
        )
        XCTAssertEqual(viewModel.progressState.isStreakSafeToday, viewModel.progressState.earnedXP > 0)

        guard let openTask = viewModel.morningTasks.first else {
            return XCTFail("Expected open task in morning list")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.progressState.earnedXP, viewModel.dailyScore)
        XCTAssertEqual(viewModel.progressState.remainingPotentialXP, viewModel.pointsPotential)
        XCTAssertEqual(
            viewModel.progressState.todayTargetXP,
            viewModel.progressState.earnedXP + viewModel.progressState.remainingPotentialXP
        )
        XCTAssertEqual(viewModel.progressState.isStreakSafeToday, viewModel.progressState.earnedXP > 0)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFocusTasksRankingPrioritizesOverdueThenDueTodayThenXP() {
        let suiteName = "HomeViewModelPersistenceTests.FocusRanking.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? now
        let todayMorning = calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? now
        let todayEvening = calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now

        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Today Low", project: inbox, dueDate: todayMorning, priority: .low),
            makeTask(name: "Overdue Low", project: inbox, dueDate: yesterday, priority: .low),
            makeTask(name: "Today High", project: inbox, dueDate: todayEvening, priority: .high),
            makeTask(name: "Overdue High", project: inbox, dueDate: yesterday, priority: .high)
        ]

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.focusTasks.map(\.name), ["Overdue High", "Overdue Low", "Today High"])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFocusTasksTieBreakUsesStableUUIDOrdering() {
        let suiteName = "HomeViewModelPersistenceTests.FocusStableID.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let inbox = Project.createInbox()

        let taskA = makeTask(id: idA, name: "A", project: inbox, dueDate: now, priority: .low)
        let taskB = makeTask(id: idB, name: "B", project: inbox, dueDate: now, priority: .low)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [taskB, taskA])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.focusTasks.map(\.id), [idA, idB])

        defaults.removePersistentDomain(forName: suiteName)
    }

    private func waitForMainQueueFlush() {
        let expectation = expectation(description: "MainQueueFlush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func makeTask(
        id: UUID = UUID(),
        name: String,
        project: Project,
        dueDate: Date,
        priority: TaskPriority = .low
    ) -> Task {
        Task(
            id: id,
            projectID: project.id,
            name: name,
            priority: priority,
            dueDate: dueDate,
            project: project.name
        )
    }
}

private final class HomeViewModelMockProjectRepository: ProjectRepositoryProtocol {
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
        completion(.success(projects.first(where: { $0.name == name })))
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
        } else {
            let inbox = Project.createInbox()
            projects.append(inbox)
            completion(.success(inbox))
        }
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

private final class HomeViewModelMockTaskRepository: TaskRepositoryProtocol {
    private let tasks: [Task]

    init(tasks: [Task]) {
        self.tasks = tasks
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.project == project })) }
    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.projectID == projectID })) }
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.isOverdue })) }
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.isComplete })) }
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.type == type })) }
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) { completion(.success(tasks.first { $0.id == id })) }
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.isComplete = true
        task.dateCompleted = Date()
        completion(.success(task))
    }
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.isComplete = false
        task.dateCompleted = nil
        completion(.success(task))
    }
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.dueDate = date
        completion(.success(task))
    }
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.projectID == ProjectConstants.inboxProjectID })) }
}
