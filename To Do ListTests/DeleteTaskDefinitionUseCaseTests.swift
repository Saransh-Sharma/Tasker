import XCTest
@testable import To_Do_List

@MainActor
final class DeleteTaskDefinitionUseCaseTests: XCTestCase {
    func testSeriesDeleteNotificationIncludesAllDeletedTaskIDs() {
        let recurrenceSeriesID = UUID()
        let taskA = TaskDefinition(title: "Task A", recurrenceSeriesID: recurrenceSeriesID)
        let taskB = TaskDefinition(title: "Task B", recurrenceSeriesID: recurrenceSeriesID)
        let repository = InMemoryTaskDefinitionRepository(tasks: [taskA, taskB])
        let useCase = DeleteTaskDefinitionUseCase(repository: repository)

        let notificationExpectation = expectation(description: "TaskDeleted notification posted")
        var observedDeletedTaskIDs: [String] = []
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskDeleted"),
            object: nil,
            queue: .main
        ) { notification in
            observedDeletedTaskIDs = notification.userInfo?["deletedTaskIDs"] as? [String] ?? []
            notificationExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let completionExpectation = expectation(description: "Delete completes")
        useCase.execute(taskID: taskA.id, scope: .series) { result in
            XCTAssertNoThrow(try result.get())
            completionExpectation.fulfill()
        }

        wait(for: [notificationExpectation, completionExpectation], timeout: 1.0)
        XCTAssertEqual(Set(observedDeletedTaskIDs), Set([taskA.id.uuidString, taskB.id.uuidString]))
    }
}

private final class InMemoryTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private var tasksByID: [UUID: TaskDefinition]

    init(tasks: [TaskDefinition]) {
        self.tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(tasksByID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(tasksByID.values)))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(tasksByID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        tasksByID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        fatalError("Not needed in tests")
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        tasksByID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        fatalError("Not needed in tests")
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        tasksByID.removeValue(forKey: id)
        completion(.success(()))
    }
}
