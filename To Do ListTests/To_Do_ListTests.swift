//
//  To_Do_ListTests.swift
//  To Do ListTests
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import XCTest
@testable import To_Do_List

class To_Do_ListTests: XCTestCase {

    func testUpdateTaskUseCaseUpdatesProjectIDAndNameWhenProjectIDProvided() {
        let inbox = Project.createInbox()
        let workProject = Project(id: UUID(), name: "Work")
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Task",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox, workProject])
        let useCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "project update")
        useCase.execute(
            taskId: initialTask.id,
            request: UpdateTaskRequest(projectID: workProject.id)
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.projectID, workProject.id)
                XCTAssertEqual(updated.project, workProject.name)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateTaskUseCasePreservesExplicitTypeWhenDueDateAlsoChanges() {
        let inbox = Project.createInbox()
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Task",
            details: nil,
            type: .evening,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let futureDate = Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date()

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let useCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "type precedence update")
        useCase.execute(
            taskId: initialTask.id,
            request: UpdateTaskRequest(
                type: .morning,
                dueDate: futureDate
            )
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.type, .morning, "Explicit type should win over due-date auto-type")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateTaskUseCasePostsTaskUpdatedNotification() {
        let inbox = Project.createInbox()
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Old Name",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let useCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let notificationExpectation = expectation(description: "TaskUpdated notification")
        let token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            notificationExpectation.fulfill()
        }

        useCase.execute(
            taskId: initialTask.id,
            request: UpdateTaskRequest(name: "New Name")
        ) { _ in }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(taskRepository.currentTask.name, "New Name")
        NotificationCenter.default.removeObserver(token)
    }

    func testPerformanceExample() {
        self.measure {
            _ = UUID().uuidString
        }
    }
}

private final class MockTaskRepository: TaskRepositoryProtocol {
    private var storedTask: Task

    var currentTask: Task { storedTask }

    init(seed: Task) {
        self.storedTask = seed
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([storedTask]))
    }

    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([storedTask]))
    }

    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([storedTask]))
    }

    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([storedTask]))
    }

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([storedTask]))
    }

    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(storedTask.isComplete ? [storedTask] : []))
    }

    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(storedTask.type == type ? [storedTask] : []))
    }

    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        completion(.success(storedTask.id == id ? storedTask : nil))
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([storedTask]))
    }

    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        storedTask = task
        completion(.success(task))
    }

    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        storedTask = task
        completion(.success(task))
    }

    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        storedTask.isComplete = true
        storedTask.dateCompleted = Date()
        completion(.success(storedTask))
    }

    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        storedTask.isComplete = false
        storedTask.dateCompleted = nil
        completion(.success(storedTask))
    }

    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        storedTask.dueDate = date
        completion(.success(storedTask))
    }

    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks))
    }

    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks))
    }

    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([storedTask]))
    }
}

private final class MockProjectRepository: ProjectRepositoryProtocol {
    private let projectsByID: [UUID: Project]

    init(projects: [Project]) {
        self.projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(Array(projectsByID.values)))
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projectsByID[id]))
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        let match = projectsByID.values.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        completion(.success(match))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(Array(projectsByID.values)))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(Project.createInbox()))
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        if var project = projectsByID[id] {
            project.name = newName
            completion(.success(project))
        } else {
            completion(.failure(NSError(domain: "MockProjectRepository", code: 404)))
        }
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
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
        completion(.success(true))
    }
}
