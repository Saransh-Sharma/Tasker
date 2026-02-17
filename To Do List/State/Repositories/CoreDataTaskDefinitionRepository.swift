import Foundation
import CoreData

public final class CoreDataTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchAll(completion: @escaping (Result<[Task], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "isComplete", ascending: true),
                NSSortDescriptor(key: "dueDate", ascending: true)
            ]
            do {
                let entities = try self.viewContext.fetch(request)
                completion(.success(entities.map(TaskDefinitionMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func create(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        backgroundContext.perform {
            let entity = NTask(context: self.backgroundContext)
            _ = TaskDefinitionMapper.apply(task, to: entity)
            do {
                try self.backgroundContext.save()
                completion(.success(task))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func update(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        backgroundContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "taskID == %@", task.id as CVarArg)
            do {
                let entity = try self.backgroundContext.fetch(request).first ?? NTask(context: self.backgroundContext)
                _ = TaskDefinitionMapper.apply(task, to: entity)
                try self.backgroundContext.save()
                completion(.success(task))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "taskID == %@", id as CVarArg)
            do {
                if let entity = try self.backgroundContext.fetch(request).first {
                    self.backgroundContext.delete(entity)
                    try self.backgroundContext.save()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

/// Bridges legacy task use cases to the V2 TaskDefinition repository.
final class V2TaskRepositoryAdapter: TaskRepositoryProtocol {
    private let taskDefinitionRepository: TaskDefinitionRepositoryProtocol

    init(taskDefinitionRepository: TaskDefinitionRepositoryProtocol) {
        self.taskDefinitionRepository = taskDefinitionRepository
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        taskDefinitionRepository.fetchAll(completion: completion)
    }

    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                let start = date.startOfDay
                let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
                return tasks.filter { task in
                    guard let due = task.dueDate else { return false }
                    return due >= start && due < end
                }
            })
        }
    }

    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                let todayStart = Date().startOfDay
                let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
                return tasks.filter { task in
                    guard task.isComplete == false, let due = task.dueDate else { return false }
                    return due < tomorrowStart
                }
            })
        }
    }

    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        let normalized = project.lowercased()
        fetchAllTasks { result in
            completion(result.map { tasks in
                tasks.filter { ($0.project ?? "").lowercased() == normalized }
            })
        }
    }

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                tasks.filter { $0.projectID == projectID }
            })
        }
    }

    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                let todayStart = Date().startOfDay
                return tasks.filter { task in
                    guard task.isComplete == false, let due = task.dueDate else { return false }
                    return due < todayStart
                }
            })
        }
    }

    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date().startOfDay) ?? Date()
                return tasks.filter { task in
                    guard task.isComplete == false, let due = task.dueDate else { return false }
                    return due >= tomorrow
                }
            })
        }
    }

    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { $0.filter(\.isComplete) })
        }
    }

    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { $0.filter { $0.type == type } })
        }
    }

    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                tasks.first(where: { $0.id == id })
            })
        }
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                tasks.filter { task in
                    guard let due = task.dueDate else { return false }
                    return due >= startDate && due <= endDate
                }
            })
        }
    }

    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        taskDefinitionRepository.create(task, completion: completion)
    }

    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        taskDefinitionRepository.update(task, completion: completion)
    }

    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        mutateTask(id: id, completion: completion) { task in
            var updated = task
            updated.isComplete = true
            updated.dateCompleted = Date()
            return updated
        }
    }

    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        mutateTask(id: id, completion: completion) { task in
            var updated = task
            updated.isComplete = false
            updated.dateCompleted = nil
            return updated
        }
    }

    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        mutateTask(id: id, completion: completion) { task in
            var updated = task
            updated.dueDate = date
            return updated
        }
    }

    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        taskDefinitionRepository.delete(id: id, completion: completion)
    }

    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        fetchCompletedTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                self?.deleteTasks(withIds: tasks.map(\.id), completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        performBatch(tasks, completion: completion) { [weak self] task, handler in
            self?.createTask(task, completion: handler)
        }
    }

    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        performBatch(tasks, completion: completion) { [weak self] task, handler in
            self?.updateTask(task, completion: handler)
        }
    }

    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var firstError: Error?
        for id in ids {
            group.enter()
            taskDefinitionRepository.delete(id: id) { result in
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if let error = firstError {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasks { result in
            completion(result.map { tasks in
                tasks.filter { $0.projectID == ProjectConstants.inboxProjectID }
            })
        }
    }

    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        fetchAllTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                let candidates = tasks.filter { taskIDs.contains($0.id) }.map { task -> Task in
                    var updated = task
                    updated.projectID = projectID
                    return updated
                }
                self?.updateTasks(candidates) { updateResult in
                    completion(updateResult.map { _ in () })
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchTasks(forProjectID: ProjectConstants.inboxProjectID, completion: completion)
    }

    private func mutateTask(
        id: UUID,
        completion: @escaping (Result<Task, Error>) -> Void,
        transform: @escaping (Task) -> Task
    ) {
        fetchTask(withId: id) { [weak self] result in
            switch result {
            case .success(let maybeTask):
                guard let task = maybeTask else {
                    completion(.failure(NSError(
                        domain: "TaskRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Task not found"]
                    )))
                    return
                }
                self?.taskDefinitionRepository.update(transform(task), completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func performBatch(
        _ tasks: [Task],
        completion: @escaping (Result<[Task], Error>) -> Void,
        operation: @escaping (_ task: Task, _ completion: @escaping (Result<Task, Error>) -> Void) -> Void
    ) {
        let group = DispatchGroup()
        var collected: [Task] = []
        var firstError: Error?

        for task in tasks {
            group.enter()
            operation(task) { result in
                switch result {
                case .success(let value):
                    collected.append(value)
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(collected))
            }
        }
    }
}
