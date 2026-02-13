import XCTest
@testable import To_Do_List

final class HomeViewModelCompletionStateTests: XCTestCase {

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

        XCTAssertTrue(viewModel.morningTasks.isEmpty)
        XCTAssertEqual(viewModel.completedTasks.map(\.id), [task.id])

        guard let completedTask = viewModel.completedTasks.first else {
            return XCTFail("Expected task to move to completed collection")
        }
        viewModel.toggleTaskCompletion(completedTask)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.completedTasks.count, 0)
        XCTAssertEqual(viewModel.morningTasks.map(\.id), [task.id])

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

        XCTAssertEqual(viewModel.morningTasks.first?.id, task.id)
        XCTAssertEqual(viewModel.morningTasks.first?.isComplete, true)

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

    init(tasks: [Task]) {
        self.tasks = tasks
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
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
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) { completion(.success(tasks.first { $0.id == id })) }
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
