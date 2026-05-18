import XCTest
@testable import LifeBoard

@MainActor
final class DeleteTaskDefinitionUseCaseTests: XCTestCase {
    func testSeriesDeleteNotificationIncludesAllDeletedTaskIDs() {
        let recurrenceSeriesID = UUID()
        let taskA = TaskDefinition(recurrenceSeriesID: recurrenceSeriesID, title: "Task A")
        let taskB = TaskDefinition(recurrenceSeriesID: recurrenceSeriesID, title: "Task B")
        let repository = InMemoryTaskDefinitionRepository(tasks: [taskA, taskB])
        let useCase = DeleteTaskDefinitionUseCase(repository: repository)

        let notificationExpectation = expectation(description: "TaskDeleted notification posted")
        let observedDeletedTaskIDs = LockedTestState<[String]>([])
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskDeleted"),
            object: nil,
            queue: .main
        ) { notification in
            observedDeletedTaskIDs.write(notification.userInfo?["deletedTaskIDs"] as? [String] ?? [])
            notificationExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let completionExpectation = expectation(description: "Delete completes")
        useCase.execute(taskID: taskA.id, scope: TaskDeleteScope.series) { result in
            do {
                _ = try result.get()
            } catch {
                XCTFail("Expected delete to succeed, got error: \(error)")
            }
            completionExpectation.fulfill()
        }

        wait(for: [notificationExpectation, completionExpectation], timeout: 1.0)
        let deletedTaskIDs = observedDeletedTaskIDs.read()
        XCTAssertEqual(deletedTaskIDs.count, 2)
        XCTAssertEqual(Set(deletedTaskIDs), Set([taskA.id.uuidString, taskB.id.uuidString]))
    }
}

private final class InMemoryTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private let tasksByIDState: LockedTestState<[UUID: TaskDefinition]>

    init(tasks: [TaskDefinition]) {
        self.tasksByIDState = LockedTestState(Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) }))
    }

    func fetchAll(completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(tasksByIDState.read().values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(tasksByIDState.read().values)))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping @Sendable (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(tasksByIDState.read()[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        tasksByIDState.withValue { $0[task.id] = task }
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        XCTFail("Unexpected create(request:) in DeleteTaskDefinitionUseCaseTests")
        completion(.failure(InMemoryTaskDefinitionRepositoryError.unexpectedInvocation))
    }

    func update(_ task: TaskDefinition, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        tasksByIDState.withValue { $0[task.id] = task }
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        XCTFail("Unexpected update(request:) in DeleteTaskDefinitionUseCaseTests")
        completion(.failure(InMemoryTaskDefinitionRepositoryError.unexpectedInvocation))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        tasksByIDState.withValue { $0.removeValue(forKey: id) }
        completion(.success(()))
    }
}

private enum InMemoryTaskDefinitionRepositoryError: Error {
    case unexpectedInvocation
}
