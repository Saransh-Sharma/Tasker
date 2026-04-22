import Foundation

public final class CreateTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
    private let taskDependencyRepository: TaskDependencyRepositoryProtocol?
    private let recurrenceMaterializer: RecurringTaskMaterializer

    /// Initializes a new instance.
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

    /// Executes execute.
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

    /// Executes execute.
    public func execute(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let normalizedRequest = normalizedRequestForStorage(request)

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
                                let payload = HomeTaskMutationPayload(
                                    reason: .created,
                                    source: "createTaskDefinitionUseCase",
                                    taskID: createdTask.id,
                                    newIsComplete: createdTask.isComplete,
                                    newDueDate: createdTask.dueDate,
                                    newCompletionDate: createdTask.dateCompleted,
                                    newProjectID: createdTask.projectID,
                                    newPriorityRawValue: createdTask.priority.rawValue
                                )
                                TaskNotificationDispatcher.postOnMain(
                                    name: .homeTaskMutation,
                                    userInfo: payload.userInfo
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

    /// Executes maintainRecurringSeries.
    public func maintainRecurringSeries(daysAhead: Int = 45, completion: @escaping (Result<Int, Error>) -> Void) {
        recurrenceMaterializer.maintainAllSeries(daysAhead: daysAhead, completion: completion)
    }

    /// Executes persistLinks.
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

    /// Executes normalizedRequestForSeriesRoot.
    private func normalizedRequestForSeriesRoot(_ request: CreateTaskDefinitionRequest) -> CreateTaskDefinitionRequest {
        guard request.repeatPattern != nil else { return request }
        var normalized = request
        normalized.recurrenceSeriesID = request.recurrenceSeriesID ?? UUID()
        return normalized
    }

    private func normalizedRequestForStorage(_ request: CreateTaskDefinitionRequest) -> CreateTaskDefinitionRequest {
        var normalized = normalizedRequestForSeriesRoot(request)
        guard normalized.scheduledStartAt == nil,
              normalized.scheduledEndAt == nil,
              normalized.isAllDay == false
        else {
            return normalized
        }

        let schedule = TaskScheduleNormalizer.normalize(
            deadlineDate: normalized.dueDate,
            existingScheduledStartAt: nil,
            existingScheduledEndAt: nil,
            estimatedDuration: normalized.estimatedDuration,
            preserveExistingDuration: false
        )
        normalized.dueDate = schedule.dueDate
        normalized.scheduledStartAt = schedule.scheduledStartAt
        normalized.scheduledEndAt = schedule.scheduledEndAt
        normalized.isAllDay = schedule.isAllDay
        return normalized
    }

    /// Executes materializeRecurringTasksIfNeeded.
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

    /// Initializes a new instance.
    init(
        repository: TaskDefinitionRepositoryProtocol,
        taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
    ) {
        self.repository = repository
        self.taskTagLinkRepository = taskTagLinkRepository
    }

    /// Executes maintainAllSeries.
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
                        iconSymbolName: root.iconSymbolName,
                        lifeAreaID: root.lifeAreaID,
                        sectionID: root.sectionID,
                        dueDate: root.dueDate,
                        scheduledStartAt: root.scheduledStartAt,
                        scheduledEndAt: root.scheduledEndAt,
                        isAllDay: root.isAllDay,
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

    /// Executes materializeSeries.
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

    /// Executes materializeSeriesCountingCreated.
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
                    let schedule = TaskScheduleNormalizer.normalize(
                        deadlineDate: dueDate,
                        existingScheduledStartAt: rootTask.scheduledStartAt,
                        existingScheduledEndAt: rootTask.scheduledEndAt,
                        estimatedDuration: rootTask.estimatedDuration,
                        preserveExistingDuration: true
                    )
                    let request = CreateTaskDefinitionRequest(
                        id: UUID(),
                        recurrenceSeriesID: recurrenceSeriesID,
                        title: rootTask.title,
                        details: rootTask.details,
                        projectID: rootTask.projectID,
                        projectName: rootTask.projectName,
                        iconSymbolName: rootTask.iconSymbolName,
                        lifeAreaID: rootTask.lifeAreaID,
                        sectionID: rootTask.sectionID,
                        dueDate: schedule.dueDate,
                        scheduledStartAt: schedule.scheduledStartAt,
                        scheduledEndAt: schedule.scheduledEndAt,
                        isAllDay: schedule.isAllDay,
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

    /// Executes createTaskWithoutNotifications.
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

    /// Executes persistTagLinks.
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

    /// Executes seriesDates.
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

    /// Initializes a new instance.
    public init(repository: TaskDefinitionRepositoryProtocol) {
        self.repository = repository
    }

    /// Executes execute.
    public func execute(
        parentTaskID: UUID,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        repository.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }
}
