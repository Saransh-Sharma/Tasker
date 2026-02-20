import Foundation

public final class CreateTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
    private let taskDependencyRepository: TaskDependencyRepositoryProtocol?
    private let recurrenceMaterializer: RecurringTaskMaterializer

    public init(
        repository: TaskDefinitionRepositoryProtocol,
        taskTagLinkRepository: TaskTagLinkRepositoryProtocol? = nil,
        taskDependencyRepository: TaskDependencyRepositoryProtocol? = nil
    ) {
        self.repository = repository
        self.taskTagLinkRepository = taskTagLinkRepository
        self.taskDependencyRepository = taskDependencyRepository
        self.recurrenceMaterializer = RecurringTaskMaterializer(
            repository: repository,
            taskTagLinkRepository: taskTagLinkRepository
        )
    }

    public func execute(
        title: String,
        projectID: UUID,
        dueDate: Date?,
        details: String?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let request = CreateTaskDefinitionRequest(
            title: title,
            details: details,
            projectID: projectID,
            dueDate: dueDate,
            createdAt: Date()
        )
        execute(request: request, completion: completion)
    }

    public func execute(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let normalizedRequest = normalizedRequestForSeriesRoot(request)

        repository.create(request: normalizedRequest) { result in
            switch result {
            case .success(let createdTask):
                self.persistLinks(taskID: createdTask.id, request: normalizedRequest) { linkResult in
                    switch linkResult {
                    case .success:
                        self.materializeRecurringTasksIfNeeded(
                            rootTask: createdTask,
                            rootRequest: normalizedRequest
                        ) { recurrenceResult in
                            switch recurrenceResult {
                            case .success:
                                TaskNotificationDispatcher.postOnMain(
                                    name: NSNotification.Name("TaskCreated"),
                                    object: createdTask
                                )
                                TaskNotificationDispatcher.postOnMain(
                                    name: .homeTaskMutation,
                                    userInfo: [
                                        "reason": "created",
                                        "source": "createTaskDefinitionUseCase",
                                        "taskID": createdTask.id.uuidString
                                    ]
                                )
                                completion(.success(createdTask))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func maintainRecurringSeries(daysAhead: Int = 45, completion: @escaping (Result<Int, Error>) -> Void) {
        recurrenceMaterializer.maintainAllSeries(daysAhead: daysAhead, completion: completion)
    }

    private func persistLinks(
        taskID: UUID,
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var firstError: Error?

        if let taskTagLinkRepository {
            group.enter()
            taskTagLinkRepository.replaceTagLinks(taskID: taskID, tagIDs: request.tagIDs) { result in
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }

        if let taskDependencyRepository {
            group.enter()
            let dependencies = request.dependencies.map { dependency in
                TaskDependencyLinkDefinition(
                    id: dependency.id,
                    taskID: taskID,
                    dependsOnTaskID: dependency.dependsOnTaskID,
                    kind: dependency.kind,
                    createdAt: dependency.createdAt
                )
            }
            taskDependencyRepository.replaceDependencies(taskID: taskID, dependencies: dependencies) { result in
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(()))
            }
        }
    }

    private func normalizedRequestForSeriesRoot(_ request: CreateTaskDefinitionRequest) -> CreateTaskDefinitionRequest {
        guard request.repeatPattern != nil else { return request }
        var normalized = request
        normalized.recurrenceSeriesID = request.recurrenceSeriesID ?? UUID()
        return normalized
    }

    private func materializeRecurringTasksIfNeeded(
        rootTask: TaskDefinition,
        rootRequest: CreateTaskDefinitionRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard
            let repeatPattern = rootRequest.repeatPattern,
            rootTask.dueDate != nil
        else {
            completion(.success(()))
            return
        }

        recurrenceMaterializer.materializeSeries(
            rootTask: rootTask,
            rootRequest: rootRequest,
            repeatPattern: repeatPattern,
            daysAhead: 45,
            completion: completion
        )
    }
}

private final class RecurringTaskMaterializer {
    private let repository: TaskDefinitionRepositoryProtocol
    private let taskTagLinkRepository: TaskTagLinkRepositoryProtocol?

    init(
        repository: TaskDefinitionRepositoryProtocol,
        taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
    ) {
        self.repository = repository
        self.taskTagLinkRepository = taskTagLinkRepository
    }

    func maintainAllSeries(daysAhead: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        repository.fetchAll(query: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let allTasks):
                let roots = allTasks.filter { $0.recurrenceSeriesID != nil && $0.repeatPattern != nil }
                guard roots.isEmpty == false else {
                    completion(.success(0))
                    return
                }

                let group = DispatchGroup()
                let lock = NSLock()
                var firstError: Error?
                var createdCount = 0

                for root in roots {
                    guard let repeatPattern = root.repeatPattern else { continue }
                    let rootRequest = CreateTaskDefinitionRequest(
                        id: root.id,
                        recurrenceSeriesID: root.recurrenceSeriesID,
                        title: root.title,
                        details: root.details,
                        projectID: root.projectID,
                        projectName: root.projectName,
                        lifeAreaID: root.lifeAreaID,
                        sectionID: root.sectionID,
                        dueDate: root.dueDate,
                        parentTaskID: root.parentTaskID,
                        tagIDs: root.tagIDs,
                        dependencies: root.dependencies,
                        priority: root.priority,
                        type: root.type,
                        energy: root.energy,
                        category: root.category,
                        context: root.context,
                        isEveningTask: root.isEveningTask,
                        alertReminderTime: root.alertReminderTime,
                        estimatedDuration: root.estimatedDuration,
                        repeatPattern: repeatPattern,
                        createdAt: root.createdAt
                    )

                    group.enter()
                    self.materializeSeriesCountingCreated(
                        rootTask: root,
                        rootRequest: rootRequest,
                        repeatPattern: repeatPattern,
                        daysAhead: daysAhead
                    ) { result in
                        lock.lock()
                        switch result {
                        case .success(let count):
                            createdCount += count
                        case .failure(let error):
                            if firstError == nil {
                                firstError = error
                            }
                        }
                        lock.unlock()
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let firstError {
                        completion(.failure(firstError))
                    } else {
                        completion(.success(createdCount))
                    }
                }
            }
        }
    }

    func materializeSeries(
        rootTask: TaskDefinition,
        rootRequest: CreateTaskDefinitionRequest,
        repeatPattern: TaskRepeatPattern,
        daysAhead: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        self.materializeSeriesCountingCreated(
            rootTask: rootTask,
            rootRequest: rootRequest,
            repeatPattern: repeatPattern,
            daysAhead: daysAhead
        ) { result in
            completion(result.map { _ in () })
        }
    }

    private func materializeSeriesCountingCreated(
        rootTask: TaskDefinition,
        rootRequest: CreateTaskDefinitionRequest,
        repeatPattern: TaskRepeatPattern,
        daysAhead: Int,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        guard
            let recurrenceSeriesID = rootTask.recurrenceSeriesID ?? rootRequest.recurrenceSeriesID,
            let rootDueDate = rootTask.dueDate
        else {
            completion(.success(0))
            return
        }

        repository.fetchAll(query: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let tasks):
                let calendar = Calendar.current
                let horizonEnd = calendar.date(byAdding: .day, value: max(daysAhead, 1), to: Date()) ?? Date()
                let existingDayKeys = Set(tasks.compactMap { task -> Date? in
                    guard task.recurrenceSeriesID == recurrenceSeriesID, let dueDate = task.dueDate else { return nil }
                    return calendar.startOfDay(for: dueDate)
                })

                let candidateDates = Self.seriesDates(
                    startDate: rootDueDate,
                    repeatPattern: repeatPattern,
                    horizonEnd: horizonEnd
                )

                let missingDates = candidateDates.filter { date in
                    existingDayKeys.contains(calendar.startOfDay(for: date)) == false
                }

                guard missingDates.isEmpty == false else {
                    completion(.success(0))
                    return
                }

                let group = DispatchGroup()
                let lock = NSLock()
                var firstError: Error?
                var createdCount = 0

                for dueDate in missingDates {
                    let request = CreateTaskDefinitionRequest(
                        id: UUID(),
                        recurrenceSeriesID: recurrenceSeriesID,
                        title: rootTask.title,
                        details: rootTask.details,
                        projectID: rootTask.projectID,
                        projectName: rootTask.projectName,
                        lifeAreaID: rootTask.lifeAreaID,
                        sectionID: rootTask.sectionID,
                        dueDate: dueDate,
                        parentTaskID: rootTask.parentTaskID,
                        tagIDs: rootRequest.tagIDs,
                        dependencies: [],
                        priority: rootTask.priority,
                        type: rootTask.type,
                        energy: rootTask.energy,
                        category: rootTask.category,
                        context: rootTask.context,
                        isEveningTask: rootTask.isEveningTask,
                        alertReminderTime: nil,
                        estimatedDuration: rootTask.estimatedDuration,
                        repeatPattern: nil,
                        createdAt: Date()
                    )

                    group.enter()
                    self.createTaskWithoutNotifications(request: request) { result in
                        lock.lock()
                        switch result {
                        case .success:
                            createdCount += 1
                        case .failure(let error):
                            if firstError == nil {
                                firstError = error
                            }
                        }
                        lock.unlock()
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let firstError {
                        completion(.failure(firstError))
                    } else {
                        completion(.success(createdCount))
                    }
                }
            }
        }
    }

    private func createTaskWithoutNotifications(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        repository.create(request: request) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let task):
                self.persistTagLinks(taskID: task.id, tagIDs: request.tagIDs, completion: completion)
            }
        }
    }

    private func persistTagLinks(
        taskID: UUID,
        tagIDs: [UUID],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let taskTagLinkRepository else {
            completion(.success(()))
            return
        }
        taskTagLinkRepository.replaceTagLinks(taskID: taskID, tagIDs: tagIDs, completion: completion)
    }

    private static func seriesDates(
        startDate: Date,
        repeatPattern: TaskRepeatPattern,
        horizonEnd: Date
    ) -> [Date] {
        guard horizonEnd > startDate else { return [] }

        var dates: [Date] = []
        var cursor = startDate
        var guardrail = 0
        while cursor < horizonEnd, guardrail < 512 {
            guard let next = repeatPattern.nextOccurrence(after: cursor) else {
                break
            }
            if next > horizonEnd {
                break
            }
            dates.append(next)
            cursor = next
            guardrail += 1
        }
        return dates
    }
}

public final class GetTaskChildrenUseCase {
    private let repository: TaskDefinitionRepositoryProtocol

    public init(repository: TaskDefinitionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        parentTaskID: UUID,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        repository.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }
}
