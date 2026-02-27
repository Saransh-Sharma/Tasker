import XCTest
@testable import To_Do_List

final class HomeViewModelXPScoreRegressionTests: XCTestCase {

    func testCompletingOverdueTaskIncreasesTodayXPByCompletionDate() {
        let suiteName = "HomeViewModelXPScoreRegressionTests.CompleteOverdue.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let overdueDate = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let inbox = Project.createInbox()
        let overdueTask = makeTask(
            name: "Overdue XP Task",
            project: inbox,
            dueDate: overdueDate,
            priority: .high,
            isComplete: false
        )

        let taskRepository = XPRegressionMockTaskRepository(tasks: [overdueTask])
        let projectRepository = XPRegressionMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueueFlush(seconds: 0.35)
        XCTAssertEqual(viewModel.dailyScore, 0, "Expected baseline score to start at 0")

        viewModel.toggleTaskCompletion(overdueTask)
        waitForMainQueueFlush(seconds: 0.55)

        XCTAssertEqual(viewModel.dailyScore, overdueTask.priority.scorePoints)
        XCTAssertEqual(viewModel.progressState.earnedXP, overdueTask.priority.scorePoints)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testExternalHomeTaskMutationRefreshesTodayXP() {
        let suiteName = "HomeViewModelXPScoreRegressionTests.ExternalMutation.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let overdueDate = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        let inbox = Project.createInbox()
        let overdueTask = makeTask(
            name: "Externally Completed XP Task",
            project: inbox,
            dueDate: overdueDate,
            priority: .max,
            isComplete: false
        )

        let taskRepository = XPRegressionMockTaskRepository(tasks: [overdueTask])
        let projectRepository = XPRegressionMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueueFlush(seconds: 0.35)
        XCTAssertEqual(viewModel.dailyScore, 0, "Expected baseline score to start at 0")

        taskRepository.markCompletedExternally(taskID: overdueTask.id, completedAt: Date())
        NotificationCenter.default.post(
            name: .homeTaskMutation,
            object: nil,
            userInfo: [
                "reason": HomeTaskMutationEvent.completed.rawValue,
                "source": "xp_regression_test_external_source"
            ]
        )

        waitForMainQueueFlush(seconds: 0.65)

        XCTAssertEqual(viewModel.dailyScore, overdueTask.priority.scorePoints)
        XCTAssertEqual(viewModel.progressState.earnedXP, overdueTask.priority.scorePoints)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLedgerMutationNotificationImmediatelyUpdatesGamificationSurfaces() {
        let suiteName = "HomeViewModelXPScoreRegressionTests.LedgerMutation.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let taskRepository = XPRegressionMockTaskRepository(tasks: [])
        let projectRepository = XPRegressionMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueueFlush(seconds: 0.35)

        let totalXP: Int64 = 980
        let expectedNextLevelXP = XPCalculationEngine.levelForXP(totalXP).nextThreshold
        let mutation = GamificationLedgerMutation(
            source: XPSource.manual.rawValue,
            category: .complete,
            awardedXP: 18,
            dailyXPSoFar: 72,
            totalXP: totalXP,
            level: 5,
            previousLevel: 4,
            streakDays: 9,
            didChange: true,
            dateKey: XPCalculationEngine.periodKey(),
            occurredAt: Date()
        )

        NotificationCenter.default.post(
            name: .gamificationLedgerDidMutate,
            object: nil,
            userInfo: mutation.userInfo
        )

        waitForMainQueueFlush(seconds: 0.25)

        XCTAssertEqual(viewModel.dailyScore, 72)
        XCTAssertEqual(viewModel.totalXP, totalXP)
        XCTAssertEqual(viewModel.currentLevel, 5)
        XCTAssertEqual(viewModel.streak, 9)
        XCTAssertEqual(viewModel.nextLevelXP, expectedNextLevelXP)
        XCTAssertEqual(viewModel.lastXPResult?.awardedXP, 18)

        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeTask(
        id: UUID = UUID(),
        name: String,
        project: Project,
        dueDate: Date?,
        priority: TaskPriority,
        isComplete: Bool,
        dateCompleted: Date? = nil
    ) -> Task {
        Task(
            id: id,
            projectID: project.id,
            name: name,
            priority: priority,
            dueDate: dueDate,
            project: project.name,
            isComplete: isComplete,
            dateCompleted: dateCompleted
        )
    }

    private func waitForMainQueueFlush(seconds: TimeInterval) {
        let expectation = expectation(description: "MainQueueFlush")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        // Full-suite CI runs can briefly starve the main queue; keep this flush helper resilient.
        wait(for: [expectation], timeout: max(3.0, seconds + 2.5))
    }
}

private final class XPRegressionMockProjectRepository: ProjectRepositoryProtocol {
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

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(
            scanned: projects.count,
            merged: 0,
            deleted: 0,
            inboxCandidates: projects.filter { $0.isInbox }.count,
            warnings: []
        )))
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

    func deleteProject(withId id: UUID, deleteTasks _: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        projects.removeAll { $0.id == id }
        completion(.success(()))
    }

    func getTaskCount(for _: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func getTasks(for _: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func moveTasks(from _: UUID, to _: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
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

private final class XPRegressionMockTaskRepository: LegacyTaskRepositoryShim {
    private var tasksByID: [UUID: Task]
    private let calendar = Calendar.current

    init(tasks: [Task]) {
        self.tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    func markCompletedExternally(taskID: UUID, completedAt: Date) {
        guard var task = tasksByID[taskID] else { return }
        task.isComplete = true
        task.dateCompleted = completedAt
        tasksByID[taskID] = task
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(Array(tasksByID.values)))
    }

    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        let filtered = tasksByID.values.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= start && dueDate < end
        }
        completion(.success(filtered))
    }

    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let today = Date()
        let start = calendar.startOfDay(for: today)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? today
        let filtered = tasksByID.values.filter { task in
            if let dueDate = task.dueDate, dueDate >= start, dueDate < end {
                return true
            }
            if let dueDate = task.dueDate, dueDate < start, task.isComplete == false {
                return true
            }
            return false
        }
        completion(.success(filtered))
    }

    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasksByID.values.filter { $0.projectName?.caseInsensitiveCompare(project) == .orderedSame }))
    }

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasksByID.values.filter { $0.projectID == projectID }))
    }

    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasksByID.values.filter { $0.isOverdue }))
    }

    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(Array(tasksByID.values)))
    }

    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasksByID.values.filter { $0.isComplete }))
    }

    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasksByID.values.filter { $0.type == type }))
    }

    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        completion(.success(tasksByID[id]))
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        let filtered = tasksByID.values.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startDate && dueDate <= endDate
        }
        completion(.success(filtered))
    }

    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        tasksByID[task.id] = task
        completion(.success(task))
    }

    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        tasksByID[task.id] = task
        completion(.success(task))
    }

    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasksByID[id] else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.isComplete = true
        task.dateCompleted = Date()
        tasksByID[id] = task
        completion(.success(task))
    }

    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasksByID[id] else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.isComplete = false
        task.dateCompleted = nil
        tasksByID[id] = task
        completion(.success(task))
    }

    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasksByID[id] else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.dueDate = date
        tasksByID[id] = task
        completion(.success(task))
    }

    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        tasksByID.removeValue(forKey: id)
        completion(.success(()))
    }

    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        tasksByID = tasksByID.filter { !$0.value.isComplete }
        completion(.success(()))
    }

    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        for task in tasks {
            tasksByID[task.id] = task
        }
        completion(.success(tasks))
    }

    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        for task in tasks {
            tasksByID[task.id] = task
        }
        completion(.success(tasks))
    }

    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        for id in ids {
            tasksByID.removeValue(forKey: id)
        }
        completion(.success(()))
    }

    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasksByID.values.filter { $0.projectID == ProjectConstants.inboxProjectID }))
    }

    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        for id in taskIDs {
            guard var task = tasksByID[id] else { continue }
            task.projectID = projectID
            tasksByID[id] = task
        }
        completion(.success(()))
    }

    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasksByID.values.filter { $0.projectID == ProjectConstants.inboxProjectID }))
    }
}
