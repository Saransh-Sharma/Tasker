import XCTest
@testable import To_Do_List

final class GetHomeFilteredTasksUseCaseTests: XCTestCase {

    func testUpcomingQuickViewReturnsOnlyNext14DaysOpenTasks() {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let inSevenDays = calendar.date(byAdding: .day, value: 7, to: tomorrow)!
        let inTwentyDays = calendar.date(byAdding: .day, value: 20, to: tomorrow)!
        let overdue = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!

        let taskInsideWindow = makeTask(name: "Inside", dueDate: inSevenDays, isComplete: false)
        let taskOutsideWindow = makeTask(name: "Outside", dueDate: inTwentyDays, isComplete: false)
        let overdueTask = makeTask(name: "Overdue", dueDate: overdue, isComplete: false)
        let completedTask = makeTask(name: "Completed", dueDate: tomorrow, isComplete: true, completionDate: now)

        let repository = MockTaskRepository(tasks: [taskInsideWindow, taskOutsideWindow, overdueTask, completedTask])
        let useCase = GetHomeFilteredTasksUseCase(taskRepository: repository)

        let expectation = expectation(description: "Upcoming filters")
        var captured: HomeFilteredTasksResult?

        var state = HomeFilterState.default
        state.quickView = .upcoming

        useCase.execute(state: state) { result in
            if case let .success(value) = result {
                captured = value
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(captured?.openTasks.map(\.name), ["Inside"])
        XCTAssertEqual(captured?.doneTimelineTasks.map(\.name), ["Completed"])
    }

    func testTodayQuickViewIncludesCompletedTasksDueTodayOrOverdue() {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let todayAtNine = calendar.date(byAdding: .hour, value: 9, to: startOfToday)!
        let yesterdayAtNine = calendar.date(byAdding: .day, value: -1, to: todayAtNine)!

        let openToday = makeTask(name: "Open Today", dueDate: todayAtNine, isComplete: false)
        let completedToday = makeTask(
            name: "Completed Today",
            dueDate: todayAtNine,
            isComplete: true,
            completionDate: now
        )
        let completedOverdue = makeTask(
            name: "Completed Overdue",
            dueDate: yesterdayAtNine,
            isComplete: true,
            completionDate: now
        )

        let repository = MockTaskRepository(tasks: [openToday, completedToday, completedOverdue])
        let useCase = GetHomeFilteredTasksUseCase(taskRepository: repository)

        let expectation = expectation(description: "Today includes completed")
        var captured: HomeFilteredTasksResult?

        var state = HomeFilterState.default
        state.quickView = .today

        useCase.execute(state: state) { result in
            if case let .success(value) = result {
                captured = value
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(captured?.openTasks.map(\.name), ["Open Today"])
        XCTAssertEqual(
            Set(captured?.doneTimelineTasks.map(\.name) ?? []),
            Set(["Completed Today", "Completed Overdue"])
        )
    }

    func testDoneQuickViewLimitsToLastThirtyDaysAndSortsByDayThenPriority() {
        let now = Date()
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now)!
        let fortyDaysAgo = calendar.date(byAdding: .day, value: -40, to: now)!

        let recentHigh = makeTask(name: "Recent High", dueDate: twoDaysAgo, isComplete: true, priority: .high, completionDate: twoDaysAgo)
        let recentLow = makeTask(name: "Recent Low", dueDate: twoDaysAgo, isComplete: true, priority: .low, completionDate: twoDaysAgo)
        let olderRecent = makeTask(name: "Older Recent", dueDate: tenDaysAgo, isComplete: true, priority: .max, completionDate: tenDaysAgo)
        let tooOld = makeTask(name: "Too Old", dueDate: fortyDaysAgo, isComplete: true, priority: .max, completionDate: fortyDaysAgo)

        let repository = MockTaskRepository(tasks: [recentLow, olderRecent, tooOld, recentHigh])
        let useCase = GetHomeFilteredTasksUseCase(taskRepository: repository)

        let expectation = expectation(description: "Done filters")
        var captured: HomeFilteredTasksResult?

        var state = HomeFilterState.default
        state.quickView = .done

        useCase.execute(state: state) { result in
            if case let .success(value) = result {
                captured = value
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(captured?.doneTimelineTasks.map(\.name), ["Recent High", "Recent Low", "Older Recent"])
        XCTAssertEqual(captured?.openTasks.count, 0)
    }

    func testMorningHybridUsesTypeFirstThenDueHourFallback() {
        let now = Date()
        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: now)

        let explicitMorning = makeTask(name: "Explicit Morning", dueDate: calendar.date(byAdding: .hour, value: 20, to: baseDay), isComplete: false, type: .morning)
        let inferredMorning = makeTask(name: "Inferred Morning", dueDate: calendar.date(byAdding: .hour, value: 8, to: baseDay), isComplete: false, type: .upcoming)
        let inferredEvening = makeTask(name: "Evening", dueDate: calendar.date(byAdding: .hour, value: 19, to: baseDay), isComplete: false, type: .upcoming)

        let repository = MockTaskRepository(tasks: [explicitMorning, inferredMorning, inferredEvening])
        let useCase = GetHomeFilteredTasksUseCase(taskRepository: repository)

        let expectation = expectation(description: "Morning hybrid")
        var captured: HomeFilteredTasksResult?

        var state = HomeFilterState.default
        state.quickView = .morning

        useCase.execute(state: state) { result in
            if case let .success(value) = result {
                captured = value
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(Set(captured?.openTasks.map(\.name) ?? []), Set(["Explicit Morning", "Inferred Morning"]))
    }

    func testMorningAndEveningQuickViewsIncludeCompletedTasksInDoneTimeline() {
        let now = Date()
        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: now)

        let morningOpen = makeTask(
            name: "Morning Open",
            dueDate: calendar.date(byAdding: .hour, value: 8, to: baseDay),
            isComplete: false,
            type: .morning
        )
        let morningDone = makeTask(
            name: "Morning Done",
            dueDate: calendar.date(byAdding: .hour, value: 9, to: baseDay),
            isComplete: true,
            type: .morning,
            completionDate: now
        )
        let eveningOpen = makeTask(
            name: "Evening Open",
            dueDate: calendar.date(byAdding: .hour, value: 19, to: baseDay),
            isComplete: false,
            type: .evening
        )
        let eveningDone = makeTask(
            name: "Evening Done",
            dueDate: calendar.date(byAdding: .hour, value: 20, to: baseDay),
            isComplete: true,
            type: .evening,
            completionDate: now
        )

        let repository = MockTaskRepository(tasks: [morningOpen, morningDone, eveningOpen, eveningDone])
        let useCase = GetHomeFilteredTasksUseCase(taskRepository: repository)

        let morningExpectation = expectation(description: "Morning includes completed")
        var morningResult: HomeFilteredTasksResult?
        var morningState = HomeFilterState.default
        morningState.quickView = .morning
        useCase.execute(state: morningState) { result in
            if case let .success(value) = result {
                morningResult = value
            }
            morningExpectation.fulfill()
        }

        let eveningExpectation = expectation(description: "Evening includes completed")
        var eveningResult: HomeFilteredTasksResult?
        var eveningState = HomeFilterState.default
        eveningState.quickView = .evening
        useCase.execute(state: eveningState) { result in
            if case let .success(value) = result {
                eveningResult = value
            }
            eveningExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(morningResult?.openTasks.map(\.name), ["Morning Open"])
        XCTAssertEqual(morningResult?.doneTimelineTasks.map(\.name), ["Morning Done"])
        XCTAssertEqual(eveningResult?.openTasks.map(\.name), ["Evening Open"])
        XCTAssertEqual(eveningResult?.doneTimelineTasks.map(\.name), ["Evening Done"])
    }

    func testProjectFacetUsesORAcrossSelectedProjects() {
        let p1 = UUID()
        let p2 = UUID()
        let p3 = UUID()

        let t1 = makeTask(name: "P1", projectID: p1)
        let t2 = makeTask(name: "P2", projectID: p2)
        let t3 = makeTask(name: "P3", projectID: p3)

        let repository = MockTaskRepository(tasks: [t1, t2, t3])
        let useCase = GetHomeFilteredTasksUseCase(taskRepository: repository)

        let expectation = expectation(description: "Project OR")
        var captured: HomeFilteredTasksResult?

        var state = HomeFilterState.default
        state.quickView = .today
        state.selectedProjectIDs = [p1, p2]

        useCase.execute(state: state) { result in
            if case let .success(value) = result {
                captured = value
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(Set(captured?.openTasks.map(\.name) ?? []), Set(["P1", "P2"]))
    }

    private func makeTask(
        name: String,
        projectID: UUID = UUID(),
        dueDate: Date? = Date(),
        isComplete: Bool = false,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        completionDate: Date? = nil
    ) -> Task {
        Task(
            projectID: projectID,
            name: name,
            type: type,
            priority: priority,
            dueDate: dueDate,
            isComplete: isComplete,
            dateCompleted: completionDate
        )
    }
}

private final class MockTaskRepository: TaskRepositoryProtocol {
    private let tasks: [Task]

    init(tasks: [Task]) {
        self.tasks = tasks
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
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
        guard let task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        var updated = task
        updated.isComplete = true
        updated.dateCompleted = Date()
        completion(.success(updated))
    }
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard let task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        var updated = task
        updated.isComplete = false
        updated.dateCompleted = nil
        completion(.success(updated))
    }
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        guard let task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        var updated = task
        updated.dueDate = date
        completion(.success(updated))
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
