//
//  To_Do_ListTests.swift
//  To Do ListTests
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import XCTest
import CoreData
@testable import To_Do_List

// MARK: - Legacy test compatibility shims

typealias Task = TaskDefinition

extension TaskDefinition {
    init(
        id: UUID = UUID(),
        projectID: UUID = ProjectConstants.inboxProjectID,
        name: String,
        details: String? = nil,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        dueDate: Date? = nil,
        project: String? = ProjectConstants.inboxProjectName,
        isComplete: Bool = false,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        energy: TaskEnergy = .medium,
        category: TaskCategory = .general,
        context: TaskContext = .anywhere
    ) {
        self.init(
            id: id,
            projectID: projectID,
            projectName: project,
            title: name,
            details: details,
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            dueDate: dueDate,
            isComplete: isComplete,
            dateAdded: dateAdded,
            dateCompleted: dateCompleted
        )
    }
}

protocol LegacyTaskRepositoryShim {
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void)
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void)
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void)
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void)
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void)
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void)
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void)
    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void)
}

struct LegacyTaskUpdatePayload {
    var name: String?
    var details: String?
    var projectID: UUID?
    var dueDate: Date?
    var type: TaskType?

    init(
        name: String? = nil,
        details: String? = nil,
        projectID: UUID? = nil,
        dueDate: Date? = nil,
        type: TaskType? = nil
    ) {
        self.name = name
        self.details = details
        self.projectID = projectID
        self.dueDate = dueDate
        self.type = type
    }
}

final class LocalTaskUpdateUseCase {
    private let taskRepository: LegacyTaskRepositoryShim
    private let projectRepository: ProjectRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?

    init(
        taskRepository: LegacyTaskRepositoryShim,
        projectRepository: ProjectRepositoryProtocol,
        notificationService: NotificationServiceProtocol?
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.notificationService = notificationService
    }

    func execute(
        taskId: UUID,
        request: LegacyTaskUpdatePayload,
        completion: @escaping (Result<Task, Error>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let maybeTask):
                guard var task = maybeTask else {
                    completion(.failure(NSError(domain: "LocalTaskUpdateUseCase", code: 404)))
                    return
                }

                task.title = request.name ?? task.title
                task.details = request.details ?? task.details
                task.dueDate = request.dueDate ?? task.dueDate
                task.type = request.type ?? task.type

                let persist: (Task) -> Void = { updated in
                    self.taskRepository.updateTask(updated) { updateResult in
                        if case .success(let savedTask) = updateResult {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskUpdated"),
                                object: savedTask
                            )
                            self.notificationService?.cancelTaskReminder(taskId: savedTask.id)
                        }
                        completion(updateResult)
                    }
                }

                if let projectID = request.projectID {
                    task.projectID = projectID
                    projectRepository.fetchProject(withId: projectID) { projectResult in
                        if case .success(let project) = projectResult {
                            task.projectName = project?.name
                        }
                        persist(task)
                    }
                } else {
                    persist(task)
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

private enum LegacyTaskAdapterError: LocalizedError {
    case taskNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        }
    }
}

private final class ShimTaskReadModelAdapter: TaskReadModelRepositoryProtocol {
    private let legacyRepository: LegacyTaskRepositoryShim

    init(legacyRepository: LegacyTaskRepositoryShim) {
        self.legacyRepository = legacyRepository
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                let filtered = self.applyReadQuery(query, to: tasks)
                completion(.success(TaskDefinitionSliceResult(
                    tasks: filtered.slice,
                    totalCount: filtered.totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                let filtered = self.applySearchQuery(query, to: tasks)
                completion(.success(TaskDefinitionSliceResult(
                    tasks: filtered.slice,
                    totalCount: filtered.totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchLatestTaskUpdatedAt(completion: @escaping (Result<Date?, Error>) -> Void) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                completion(.success(tasks.map(\.updatedAt).max()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                var counts: [UUID: Int] = [:]
                for task in tasks where includeCompleted || task.isComplete == false {
                    counts[task.projectID, default: 0] += 1
                }
                completion(.success(counts))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                var totals: [UUID: Int] = [:]
                for task in tasks {
                    guard task.isComplete, let completedAt = task.dateCompleted else { continue }
                    guard completedAt >= startDate && completedAt <= endDate else { continue }
                    totals[task.projectID, default: 0] += task.priority.scorePoints
                }
                completion(.success(totals))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func applyReadQuery(_ query: TaskReadQuery, to tasks: [Task]) -> (slice: [Task], totalCount: Int) {
        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let start = query.dueDateStart {
                guard let dueDate = task.dueDate, dueDate >= start else { return false }
            }
            if let end = query.dueDateEnd {
                guard let dueDate = task.dueDate, dueDate <= end else { return false }
            }
            if let updatedAfter = query.updatedAfter, task.updatedAt < updatedAfter { return false }
            return true
        }

        let sorted = sort(filtered, by: query.sortBy)
        let totalCount = sorted.count
        let start = min(max(0, query.offset), totalCount)
        let end = min(start + max(1, query.limit), totalCount)
        return (Array(sorted[start..<end]), totalCount)
    }

    private func applySearchQuery(_ query: TaskSearchQuery, to tasks: [Task]) -> (slice: [Task], totalCount: Int) {
        let text = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if text.isEmpty { return true }
            let inTitle = task.title.lowercased().contains(text)
            let inDetails = task.details?.lowercased().contains(text) ?? false
            return inTitle || inDetails
        }

        let totalCount = filtered.count
        let start = min(max(0, query.offset), totalCount)
        let end = min(start + max(1, query.limit), totalCount)
        return (Array(filtered[start..<end]), totalCount)
    }

    private func sort(_ tasks: [Task], by sort: TaskReadSort) -> [Task] {
        switch sort {
        case .dueDateAscending:
            return tasks.sorted {
                ($0.dueDate ?? Date.distantFuture, $0.updatedAt) < ($1.dueDate ?? Date.distantFuture, $1.updatedAt)
            }
        case .dueDateDescending:
            return tasks.sorted {
                ($0.dueDate ?? Date.distantPast, $0.updatedAt) > ($1.dueDate ?? Date.distantPast, $1.updatedAt)
            }
        case .updatedAtDescending:
            return tasks.sorted { $0.updatedAt > $1.updatedAt }
        }
    }
}

private final class ShimTaskDefinitionRepositoryAdapter: TaskDefinitionRepositoryProtocol {
    private let legacyRepository: LegacyTaskRepositoryShim

    init(legacyRepository: LegacyTaskRepositoryShim) {
        self.legacyRepository = legacyRepository
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        legacyRepository.fetchAllTasks(completion: completion)
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        legacyRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                completion(.success(Self.applyQuery(query, to: tasks)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        legacyRepository.fetchTask(withId: id, completion: completion)
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        legacyRepository.createTask(task, completion: completion)
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        create(request.toTaskDefinition(projectName: request.projectName), completion: completion)
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        legacyRepository.updateTask(task, completion: completion)
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        legacyRepository.fetchTask(withId: request.id) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let maybeTask):
                guard var task = maybeTask else {
                    completion(.failure(LegacyTaskAdapterError.taskNotFound(request.id)))
                    return
                }

                if let title = request.title { task.title = title }
                if let details = request.details { task.details = details }
                if let projectID = request.projectID { task.projectID = projectID }
                if request.clearLifeArea {
                    task.lifeAreaID = nil
                } else if let lifeAreaID = request.lifeAreaID {
                    task.lifeAreaID = lifeAreaID
                }
                if request.clearSection {
                    task.sectionID = nil
                } else if let sectionID = request.sectionID {
                    task.sectionID = sectionID
                }
                if request.clearDueDate {
                    task.dueDate = nil
                } else if let dueDate = request.dueDate {
                    task.dueDate = dueDate
                }

                if request.clearParentTaskLink {
                    task.parentTaskID = nil
                } else if let parentTaskID = request.parentTaskID {
                    task.parentTaskID = parentTaskID
                }

                if let tagIDs = request.tagIDs { task.tagIDs = tagIDs }
                if let dependencies = request.dependencies { task.dependencies = dependencies }
                if let priority = request.priority { task.priority = priority }
                if let type = request.type { task.type = type }
                if let energy = request.energy { task.energy = energy }
                if let category = request.category { task.category = category }
                if let context = request.context { task.context = context }

                if let isComplete = request.isComplete {
                    task.isComplete = isComplete
                    if isComplete == false {
                        task.dateCompleted = nil
                    }
                }

                if let dateCompleted = request.dateCompleted {
                    task.dateCompleted = dateCompleted
                }

                if request.clearReminderTime {
                    task.alertReminderTime = nil
                } else if let alertReminderTime = request.alertReminderTime {
                    task.alertReminderTime = alertReminderTime
                }
                if request.clearEstimatedDuration {
                    task.estimatedDuration = nil
                } else if let estimatedDuration = request.estimatedDuration {
                    task.estimatedDuration = estimatedDuration
                }
                if let actualDuration = request.actualDuration { task.actualDuration = actualDuration }
                if request.clearRepeatPattern {
                    task.repeatPattern = nil
                } else if let repeatPattern = request.repeatPattern {
                    task.repeatPattern = repeatPattern
                }
                task.updatedAt = request.updatedAt

                self.update(task, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAll { result in
            completion(result.map { tasks in
                tasks.filter { $0.parentTaskID == parentTaskID }
            })
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        legacyRepository.deleteTask(withId: id, completion: completion)
    }

    private static func applyQuery(_ query: TaskDefinitionQuery?, to tasks: [TaskDefinition]) -> [TaskDefinition] {
        guard let query else { return tasks }

        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if let sectionID = query.sectionID, task.sectionID != sectionID { return false }
            if let parentTaskID = query.parentTaskID, task.parentTaskID != parentTaskID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let start = query.dueDateStart {
                guard let dueDate = task.dueDate, dueDate >= start else { return false }
            }
            if let end = query.dueDateEnd {
                guard let dueDate = task.dueDate, dueDate <= end else { return false }
            }
            if let updatedAfter = query.updatedAfter, task.updatedAt < updatedAfter { return false }
            if let searchText = query.searchText?.trimmingCharacters(in: .whitespacesAndNewlines), searchText.isEmpty == false {
                let needle = searchText.lowercased()
                let inTitle = task.title.lowercased().contains(needle)
                let inDetails = task.details?.lowercased().contains(needle) ?? false
                if !inTitle && !inDetails { return false }
            }
            return true
        }

        let offset = max(0, query.offset ?? 0)
        let limit = max(1, query.limit ?? filtered.count)
        let start = min(offset, filtered.count)
        let end = min(start + limit, filtered.count)
        return Array(filtered[start..<end])
    }
}

private final class LegacyNoopLifeAreaRepository: LifeAreaRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) { completion(.success([])) }
    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) { completion(.success(area)) }
    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) { completion(.success(area)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopSectionRepository: SectionRepositoryProtocol {
    func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void) { completion(.success([])) }
    func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) { completion(.success(section)) }
    func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) { completion(.success(section)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTagRepository: TagRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) { completion(.success([])) }
    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) { completion(.success(tag)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTaskTagLinkRepository: TaskTagLinkRepositoryProtocol {
    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) { completion(.success([])) }
    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTaskDependencyRepository: TaskDependencyRepositoryProtocol {
    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) { completion(.success([])) }
    func replaceDependencies(taskID: UUID, dependencies: [TaskDependencyLinkDefinition], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopHabitRepository: HabitRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) { completion(.success([])) }
    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) { completion(.success(habit)) }
    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) { completion(.success(habit)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopSchedulingEngine: SchedulingEngineProtocol {
    func generateOccurrences(windowStart: Date, windowEnd: Date, sourceFilter: ScheduleSourceType?, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) { completion(.success([])) }
    func resolveOccurrence(id: UUID, resolution: OccurrenceResolutionType, actor: OccurrenceActor, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func rebuildFutureOccurrences(templateID: UUID, effectiveFrom: Date, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func applyScheduleException(templateID: UUID, occurrenceKey: String, action: ScheduleExceptionAction, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopOccurrenceRepository: OccurrenceRepositoryProtocol {
    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) { completion(.success([])) }
    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopTombstoneRepository: TombstoneRepositoryProtocol {
    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopReminderRepository: ReminderRepositoryProtocol {
    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void) { completion(.success([])) }
    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) { completion(.success(reminder)) }
    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void) { completion(.success([])) }
    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void) { completion(.success(trigger)) }
    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void) { completion(.success([])) }
    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
}

private final class LegacyNoopGamificationRepository: GamificationRepositoryProtocol {
    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) { completion(.success(nil)) }
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class LegacyNoopAssistantActionRepository: AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

private final class LegacyNoopExternalSyncRepository: ExternalSyncRepositoryProtocol {
    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchContainerMapping(provider: String, projectID: UUID, completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func upsertContainerMapping(provider: String, projectID: UUID, mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition, completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func upsertItemMappingByLocalKey(provider: String, localEntityType: String, localEntityID: UUID, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func upsertItemMappingByExternalKey(provider: String, externalItemID: String, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

extension GetHomeFilteredTasksUseCase {
    convenience init(taskRepository: LegacyTaskRepositoryShim) {
        let readModel = (taskRepository as? TaskReadModelRepositoryProtocol)
            ?? ShimTaskReadModelAdapter(legacyRepository: taskRepository)
        self.init(readModelRepository: readModel)
    }
}

extension UseCaseCoordinator {
    convenience init(
        taskRepository: LegacyTaskRepositoryShim,
        projectRepository: ProjectRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        let readModel = (taskRepository as? TaskReadModelRepositoryProtocol)
            ?? ShimTaskReadModelAdapter(legacyRepository: taskRepository)
        let taskDefinitionRepository = ShimTaskDefinitionRepositoryAdapter(legacyRepository: taskRepository)

        let v2Dependencies = V2Dependencies(
            lifeAreaRepository: LegacyNoopLifeAreaRepository(),
            sectionRepository: LegacyNoopSectionRepository(),
            tagRepository: LegacyNoopTagRepository(),
            taskDefinitionRepository: taskDefinitionRepository,
            taskTagLinkRepository: LegacyNoopTaskTagLinkRepository(),
            taskDependencyRepository: LegacyNoopTaskDependencyRepository(),
            habitRepository: LegacyNoopHabitRepository(),
            scheduleEngine: LegacyNoopSchedulingEngine(),
            occurrenceRepository: LegacyNoopOccurrenceRepository(),
            tombstoneRepository: LegacyNoopTombstoneRepository(),
            reminderRepository: LegacyNoopReminderRepository(),
            gamificationRepository: LegacyNoopGamificationRepository(),
            assistantActionRepository: LegacyNoopAssistantActionRepository(),
            externalSyncRepository: LegacyNoopExternalSyncRepository(),
            remindersProvider: nil
        )

        self.init(
            taskReadModelRepository: readModel,
            projectRepository: projectRepository,
            cacheService: cacheService,
            notificationService: notificationService,
            v2Dependencies: v2Dependencies
        )
    }
}

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
        let useCase = LocalTaskUpdateUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "project update")
        useCase.execute(
            taskId: initialTask.id,
            request: LegacyTaskUpdatePayload(projectID: workProject.id)
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.projectID, workProject.id)
                XCTAssertEqual(updated.projectName, workProject.name)
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
        let useCase = LocalTaskUpdateUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "type precedence update")
        useCase.execute(
            taskId: initialTask.id,
            request: LegacyTaskUpdatePayload(
                dueDate: futureDate,
                type: .morning
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
        let useCase = LocalTaskUpdateUseCase(
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
            request: LegacyTaskUpdatePayload(name: "New Name")
        ) { _ in }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(taskRepository.currentTask.title, "New Name")
        NotificationCenter.default.removeObserver(token)
    }

    func testPerformanceExample() {
        self.measure {
            _ = UUID().uuidString
        }
    }
}

final class ArchitectureBoundaryTests: XCTestCase {
    private static let legacySingletonRegex = try! NSRegularExpression(
        pattern: "(^|[^A-Za-z0-9_])DependencyContainer\\.shared\\b"
    )

    private static let legacyScreenRegex = try! NSRegularExpression(
        pattern: "\\bNAddTaskScreen\\b"
    )

    func testViewLayerDoesNotUseSingletonDependencyContainers() throws {
        let directories = [
            "To Do List/View",
            "To Do List/Views",
            "To Do List/ViewControllers"
        ]
        let forbiddenPatterns = [
            "PresentationDependencyContainer.shared",
            "EnhancedDependencyContainer.shared"
        ]

        for directory in directories {
            let files = try listSwiftFiles(in: directory)
            for fileURL in files {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for pattern in forbiddenPatterns {
                    XCTAssertFalse(
                        content.contains(pattern),
                        "View-layer file must not reference singleton container `\(pattern)`: \(fileURL.path)"
                    )
                }
            }
        }
    }

    func testTargetedViewsDoNotAccessEnhancedDependencyContainerSingleton() throws {
        let files = [
            "To Do List/Views/Cards/ChartCard.swift",
            "To Do List/Views/Cards/RadarChartCard.swift",
            "To Do List/Views/ProjectSelectionSheet.swift",
            "To Do List/View/AddTaskForedropView.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("EnhancedDependencyContainer.shared"),
                "View file must not access EnhancedDependencyContainer.shared directly: \(relativePath)"
            )
        }
    }

    func testTargetedControllersDoNotFallbackToEnhancedCoordinatorSingleton() throws {
        let files = [
            "To Do List/ViewControllers/HomeViewController.swift",
            "To Do List/ViewControllers/NewProjectViewController.swift",
            "To Do List/ViewControllers/LGSearchViewController.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("EnhancedDependencyContainer.shared.useCaseCoordinator"),
                "Controller must not fallback to global coordinator singleton: \(relativePath)"
            )
        }
    }

    func testMainStoryboardDoesNotContainLegacyAddTaskScene() throws {
        let storyboard = try loadWorkspaceFile("To Do List/Storyboards/Base.lproj/Main.storyboard")
        XCTAssertFalse(storyboard.contains("storyboardIdentifier=\"addTask\""))
        XCTAssertFalse(storyboard.contains("addTaskLegacy_unreachable"))
        XCTAssertFalse(storyboard.contains("customClass=\"NAddTaskScreen\""))
    }

    func testProjectBuildGraphExcludesLegacyAddTaskRuntimeSources() throws {
        let projectFile = try loadWorkspaceFile("Tasker.xcodeproj/project.pbxproj")
        XCTAssertFalse(projectFile.contains("/* NAddTaskScreen.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* DependencyContainer.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* AddTaskLegacyStubs.swift in Sources */"))
    }

    func testProjectBuildGraphExcludesHandwrittenCoreDataPropertiesFromSources() throws {
        let projectFile = try loadWorkspaceFile("Tasker.xcodeproj/project.pbxproj")
        XCTAssertFalse(projectFile.contains("/* TaskDefinitionEntity+CoreDataProperties.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* ProjectEntity+CoreDataProperties.swift in Sources */"))
    }

    func testPrimaryRuntimeFilesDoNotReferenceLegacyDependencyContainerSingleton() throws {
        let runtimeFiles = [
            "To Do List/AppDelegate.swift",
            "To Do List/SceneDelegate.swift",
            "To Do List/Presentation/DI/PresentationDependencyContainer.swift",
            "To Do List/State/DI/EnhancedDependencyContainer.swift",
            "To Do List/UseCases/Coordinator/UseCaseCoordinator.swift"
        ]

        for relativePath in runtimeFiles {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                Self.matches(Self.legacySingletonRegex, in: content),
                "Primary runtime file must not reference legacy DependencyContainer singleton: \(relativePath)"
            )
            XCTAssertFalse(
                Self.matches(Self.legacyScreenRegex, in: content),
                "Primary runtime file must not reference legacy NAddTaskScreen route: \(relativePath)"
            )
        }
    }

    func testLegacySingletonRegexDoesNotFalseMatchV2Singletons() {
        XCTAssertTrue(Self.matches(Self.legacySingletonRegex, in: "DependencyContainer.shared.inject(into: vc)"))
        XCTAssertFalse(Self.matches(Self.legacySingletonRegex, in: "PresentationDependencyContainer.shared.configureFromStateLayer()"))
        XCTAssertFalse(Self.matches(Self.legacySingletonRegex, in: "EnhancedDependencyContainer.shared.configure(with: container)"))
        XCTAssertTrue(Self.matches(Self.legacyScreenRegex, in: "NAddTaskScreen()"))
    }

    func testLegacyGuardrailValidationScriptExistsAndIsExecutable() {
        let scriptURL = workspaceRootURL().appendingPathComponent("scripts/validate_legacy_runtime_guardrails.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
    }

    func testCoreDataCodegenGuardrailValidationScriptExistsAndIsExecutable() {
        let scriptURL = workspaceRootURL().appendingPathComponent("scripts/validate_coredata_codegen_guardrails.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
    }

    func testProjectAndRescheduleUseCasesDoNotPostNotificationCenterDirectly() throws {
        let files = [
            "To Do List/UseCases/Project/ManageProjectsUseCase.swift",
            "To Do List/UseCases/Task/RescheduleTaskDefinitionUseCase.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("NotificationCenter.default.post"),
                "Use case must emit via TaskNotificationDispatcher: \(relativePath)"
            )
        }
    }

    func testChartAndProjectSelectionViewsDoNotPublishDirectShowProjectManagementNotifications() throws {
        let files = [
            "To Do List/Views/Cards/ChartCardsScrollView.swift",
            "To Do List/Views/ProjectSelectionSheet.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("ShowProjectManagement"),
                "View should use injected callback, not broadcast notification: \(relativePath)"
            )
            XCTAssertFalse(
                content.contains("NotificationCenter.default.post"),
                "View should not post direct notifications for project management routing: \(relativePath)"
            )
        }
    }

    func testViewsDirectoryDoesNotDeclarePresentationViewModelTypes() throws {
        let forbiddenDeclarations = [
            "class ChartCardViewModel",
            "class RadarChartCardViewModel",
            "class ProjectSelectionViewModel"
        ]

        let files = try listSwiftFiles(in: "To Do List/Views")
        for fileURL in files {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for forbidden in forbiddenDeclarations {
                XCTAssertFalse(
                    content.contains(forbidden),
                    "View files must not declare presentation view models: \(fileURL.path)"
                )
            }
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let workspaceRoot = workspaceRootURL()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }

    private func listSwiftFiles(in relativeDirectory: String) throws -> [URL] {
        let root = workspaceRootURL().appendingPathComponent(relativeDirectory)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            let values = try item.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(item)
            }
        }
        return files
    }

    private func workspaceRootURL() -> URL {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        return testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func matches(_ regex: NSRegularExpression, in content: String) -> Bool {
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex.firstMatch(in: content, range: range) != nil
    }
}

final class LaunchResilienceTests: XCTestCase {
    func testMakeLaunchRootModeReturnsHomeWhenStateReady() {
        let delegate = AppDelegate()
        let container = NSPersistentCloudKitContainer(
            name: "TaskModelV3",
            managedObjectModel: NSManagedObjectModel()
        )

        let mode = delegate.makeLaunchRootMode(state: .ready(container))
        XCTAssertEqual(mode, .home)
    }

    func testMakeLaunchRootModeReturnsFailureMessageWhenStateFailed() {
        let delegate = AppDelegate()
        let expectedMessage = "bootstrap failed"
        let mode = delegate.makeLaunchRootMode(state: .failed(expectedMessage))

        guard case let .bootstrapFailure(message) = mode else {
            XCTFail("Expected bootstrapFailure mode")
            return
        }
        XCTAssertEqual(message, expectedMessage)
    }

    func testTryInjectDoesNotCrashWhenContainerMayBeUnconfigured() {
        let dependencyContainer = PresentationDependencyContainer.shared
        let injected = dependencyContainer.tryInject(into: UIViewController())
        XCTAssertEqual(injected, dependencyContainer.isConfiguredForRuntime)
    }
}

final class TaskDefinitionLinkHydrationTests: XCTestCase {
    func testFetchHydratesTagAndDependencyLinksFromLinkTables() throws {
        let container = try makeInMemoryV2Container()
        let taskRepository = CoreDataTaskDefinitionRepository(container: container)
        let tagLinkRepository = CoreDataTaskTagLinkRepository(container: container)
        let dependencyRepository = CoreDataTaskDependencyRepository(container: container)

        let taskID = UUID()
        let projectID = UUID()
        let compatibilityTag = UUID()
        let compatibilityDependency = UUID()
        let linkedTag = UUID()
        let linkedDependency = UUID()

        _ = try awaitResult { completion in
            taskRepository.create(
                request: CreateTaskDefinitionRequest(
                    id: taskID,
                    title: "Hydration Candidate",
                    details: "Initial compatibility values",
                    projectID: projectID,
                    projectName: "Inbox",
                    dueDate: nil,
                    tagIDs: [compatibilityTag],
                    dependencies: [
                        TaskDependencyLinkDefinition(
                            taskID: taskID,
                            dependsOnTaskID: compatibilityDependency,
                            kind: .related
                        )
                    ],
                    createdAt: Date()
                ),
                completion: completion
            )
        }

        _ = try awaitResult { completion in
            tagLinkRepository.replaceTagLinks(taskID: taskID, tagIDs: [linkedTag], completion: completion)
        }
        _ = try awaitResult { completion in
            dependencyRepository.replaceDependencies(
                taskID: taskID,
                dependencies: [
                    TaskDependencyLinkDefinition(
                        taskID: taskID,
                        dependsOnTaskID: linkedDependency,
                        kind: .blocks
                    )
                ],
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let task = try XCTUnwrap(fetched)

        XCTAssertEqual(task.tagIDs, [linkedTag], "Read-side tags must hydrate from TaskTagLink rows")
        XCTAssertEqual(task.dependencies.count, 1)
        XCTAssertEqual(task.dependencies.first?.dependsOnTaskID, linkedDependency)
        XCTAssertEqual(task.dependencies.first?.kind, .blocks)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskDefinitionLinkHydrationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class DeterministicFetchTests: XCTestCase {
    func testTaskDefinitionFetchByIDUsesStableSelectionOrderWithDuplicateRows() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)
        let context = container.viewContext
        let taskID = UUID()
        let projectID = UUID()
        let now = Date()

        var seedError: Error?
        context.performAndWait {
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                taskID: taskID,
                projectID: projectID,
                title: "Canonical Alpha",
                createdAt: now
            )
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                taskID: taskID,
                projectID: projectID,
                title: "Duplicate Beta",
                createdAt: now.addingTimeInterval(1)
            )
            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let first = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let second = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }

        XCTAssertEqual(first?.title, "Canonical Alpha")
        XCTAssertEqual(second?.title, "Canonical Alpha")
    }

    func testTaskDefinitionFetchAllDoesNotCrashWithoutLegacyCompatibilityAttributes() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)
        let context = container.viewContext
        let taskID = UUID()
        let projectID = UUID()
        let now = Date()

        var seedError: Error?
        context.performAndWait {
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                taskID: taskID,
                projectID: projectID,
                title: "No Legacy Compatibility Keys",
                createdAt: now
            )
            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let fetched = try awaitResult { completion in
            repository.fetchAll(query: nil, completion: completion)
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, taskID)
        XCTAssertEqual(fetched.first?.tagIDs, [])
        XCTAssertEqual(fetched.first?.dependencies, [])
    }

    func testTaskDefinitionSchemaContractIncludesLifeAreaIDAndExcludesLegacyTagsAttribute() throws {
        let container = try makeInMemoryV2Container()
        guard let taskDefinition = container.managedObjectModel.entitiesByName["TaskDefinition"] else {
            XCTFail("TaskDefinition entity missing from model")
            return
        }

        XCTAssertNotNil(taskDefinition.attributesByName["taskID"])
        XCTAssertNotNil(taskDefinition.attributesByName["projectID"])
        XCTAssertNotNil(taskDefinition.attributesByName["lifeAreaID"])
        XCTAssertNil(taskDefinition.attributesByName["tags"])
        XCTAssertNotNil(taskDefinition.relationshipsByName["tagLinks"])
        XCTAssertNotNil(taskDefinition.relationshipsByName["dependencies"])
    }

    func testTaskDefinitionEntityExposesLifeAreaIDManagedAccessor() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        var taskObject: TaskDefinitionEntity?
        context.performAndWait {
            taskObject = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context) as? TaskDefinitionEntity
        }

        guard let taskObject else {
            XCTFail("Unable to create TaskDefinitionEntity from model")
            return
        }

        let getter = NSSelectorFromString("lifeAreaID")
        let setter = NSSelectorFromString("setLifeAreaID:")
        XCTAssertTrue(taskObject.responds(to: getter), "TaskDefinitionEntity must expose lifeAreaID getter")
        XCTAssertTrue(taskObject.responds(to: setter), "TaskDefinitionEntity must expose lifeAreaID setter")

        let expected = UUID()
        taskObject.setValue(expected, forKey: "lifeAreaID")
        XCTAssertEqual(taskObject.value(forKey: "lifeAreaID") as? UUID, expected)
    }

    func testTaskDefinitionModelAttributeSelectorParity() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        var taskObject: TaskDefinitionEntity?
        context.performAndWait {
            taskObject = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context) as? TaskDefinitionEntity
        }

        guard let taskObject else {
            XCTFail("Unable to create TaskDefinitionEntity from model")
            return
        }

        assertManagedAttributeSelectorsPresent(
            entityName: "TaskDefinition",
            object: taskObject,
            model: container.managedObjectModel
        )
    }

    func testProjectModelAttributeSelectorParity() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        var projectObject: ProjectEntity?
        context.performAndWait {
            projectObject = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context) as? ProjectEntity
        }

        guard let projectObject else {
            XCTFail("Unable to create ProjectEntity from model")
            return
        }

        assertManagedAttributeSelectorsPresent(
            entityName: "Project",
            object: projectObject,
            model: container.managedObjectModel
        )
    }

    func testExternalContainerFetchUsesDeterministicFirstRowOrdering() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let context = container.viewContext
        let provider = "apple_reminders"
        let projectID = UUID()

        var seedError: Error?
        context.performAndWait {
            let first = NSEntityDescription.insertNewObject(forEntityName: "ExternalContainerMap", into: context)
            first.setValue(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, forKey: "id")
            first.setValue(provider, forKey: "provider")
            first.setValue(projectID, forKey: "projectID")
            first.setValue("first-container", forKey: "externalContainerID")
            first.setValue(true, forKey: "syncEnabled")
            first.setValue(Date(), forKey: "createdAt")

            let second = NSEntityDescription.insertNewObject(forEntityName: "ExternalContainerMap", into: context)
            second.setValue(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, forKey: "id")
            second.setValue(provider, forKey: "provider")
            second.setValue(projectID, forKey: "projectID")
            second.setValue("second-container", forKey: "externalContainerID")
            second.setValue(true, forKey: "syncEnabled")
            second.setValue(Date(), forKey: "createdAt")

            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let firstRead = try awaitResult { completion in
            repository.fetchContainerMapping(provider: provider, projectID: projectID, completion: completion)
        }
        let secondRead = try awaitResult { completion in
            repository.fetchContainerMapping(provider: provider, projectID: projectID, completion: completion)
        }

        XCTAssertEqual(firstRead?.externalContainerID, "first-container")
        XCTAssertEqual(secondRead?.externalContainerID, "first-container")
    }

    private func seedTaskDefinitionRow(
        in context: NSManagedObjectContext,
        rowID: UUID,
        taskID: UUID,
        projectID: UUID,
        title: String,
        createdAt: Date
    ) {
        let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
        object.setValue(rowID, forKey: "id")
        object.setValue(taskID, forKey: "taskID")
        object.setValue(projectID, forKey: "projectID")
        object.setValue(title, forKey: "title")
        object.setValue(nil, forKey: "notes")
        object.setValue(Int32(TaskPriority.low.rawValue), forKey: "priority")
        object.setValue(Int32(TaskType.morning.rawValue), forKey: "taskType")
        object.setValue(false, forKey: "isComplete")
        object.setValue(createdAt, forKey: "dateAdded")
        object.setValue(false, forKey: "isEveningTask")
        object.setValue("pending", forKey: "status")
        object.setValue(nil, forKey: "lifeAreaID")
        object.setValue(createdAt, forKey: "createdAt")
        object.setValue(createdAt, forKey: "updatedAt")
        object.setValue(Int32(1), forKey: "version")
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "DeterministicFetchTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    private func assertManagedAttributeSelectorsPresent(
        entityName: String,
        object: NSManagedObject,
        model: NSManagedObjectModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let entity = model.entitiesByName[entityName] else {
            XCTFail("Missing entity in managed object model: \(entityName)", file: file, line: line)
            return
        }

        for attributeName in entity.attributesByName.keys.sorted() {
            let getter = NSSelectorFromString(attributeName)
            XCTAssertTrue(
                object.responds(to: getter),
                "Missing getter selector \(attributeName) on \(entityName) managed object",
                file: file,
                line: line
            )

            let setter = NSSelectorFromString("set\(attributeName.prefix(1).uppercased())\(attributeName.dropFirst()):")
            XCTAssertTrue(
                object.responds(to: setter),
                "Missing setter selector \(setter.description) for \(attributeName) on \(entityName) managed object",
                file: file,
                line: line
            )
        }
    }
}

final class OccurrenceKeyCodecTests: XCTestCase {
    func testCanonicalRoundTrip() {
        let templateID = UUID()
        let sourceID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_705_000_000)
        let encoded = OccurrenceKeyCodec.encode(
            scheduleTemplateID: templateID,
            scheduledAt: scheduledAt,
            sourceID: sourceID
        )
        let parsed = OccurrenceKeyCodec.parse(encoded)
        XCTAssertEqual(parsed?.scheduleTemplateID, templateID)
        XCTAssertEqual(parsed?.sourceID, sourceID)
        XCTAssertEqual(parsed?.scheduledAt.timeIntervalSince1970 ?? 0, scheduledAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(parsed?.isCanonical, true)
    }

    func testLegacyKeyParsesAndCanonicalizesWithFallbackSource() {
        let templateID = UUID()
        let sourceID = UUID()
        let legacy = "\(templateID.uuidString)_2026-01-02T09:30"
        let canonical = OccurrenceKeyCodec.canonicalize(
            legacy,
            fallbackTemplateID: templateID,
            fallbackSourceID: sourceID
        )
        XCTAssertNotNil(canonical)
        XCTAssertTrue(canonical?.contains(sourceID.uuidString) ?? false)
    }

    func testMalformedKeyRejected() {
        XCTAssertNil(OccurrenceKeyCodec.parse("not-a-valid-key"))
        XCTAssertNil(
            OccurrenceKeyCodec.canonicalize(
                "bad-key",
                fallbackTemplateID: UUID(),
                fallbackSourceID: UUID()
            )
        )
    }
}

final class FeatureFlagKillSwitchTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true
    private var originalAssistantApplyEnabled = true
    private var originalAssistantUndoEnabled = true
    private var originalRemindersBackgroundRefreshEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        originalAssistantApplyEnabled = V2FeatureFlags.assistantApplyEnabled
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        originalRemindersBackgroundRefreshEnabled = V2FeatureFlags.remindersBackgroundRefreshEnabled
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        V2FeatureFlags.assistantApplyEnabled = originalAssistantApplyEnabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        V2FeatureFlags.remindersBackgroundRefreshEnabled = originalRemindersBackgroundRefreshEnabled
        super.tearDown()
    }

    func testReconcileExternalRemindersFailsClosedWhenSyncFlagDisabled() {
        // V3 runtime is always enabled in tests
        V2FeatureFlags.remindersSyncEnabled = false

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: NoopExternalSyncRepository()
        )

        let expectation = expectation(description: "reconcile-disabled")
        useCase.execute { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testAssistantApplyFailsClosedWhenApplyFlagDisabled() {
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantApplyEnabled = false

        let useCase = AssistantActionPipelineUseCase(
            repository: NoopAssistantActionRepository(),
            taskRepository: NoopTaskDefinitionRepository()
        )
        let expectation = expectation(description: "assistant-apply-disabled")
        useCase.applyConfirmedRun(id: UUID()) { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testAssistantUndoFailsClosedWhenUndoFlagDisabled() {
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantUndoEnabled = false

        let useCase = AssistantActionPipelineUseCase(
            repository: NoopAssistantActionRepository(),
            taskRepository: NoopTaskDefinitionRepository()
        )
        let expectation = expectation(description: "assistant-undo-disabled")
        useCase.undoAppliedRun(id: UUID()) { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testBackgroundRefreshFlagCanFailClosed() throws {
        V2FeatureFlags.remindersBackgroundRefreshEnabled = false
        XCTAssertFalse(V2FeatureFlags.remindersBackgroundRefreshEnabled)

        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("V2FeatureFlags.remindersBackgroundRefreshEnabled"),
            "AppDelegate must gate reminders refresh with remindersBackgroundRefreshEnabled"
        )
    }

    func testDailyBriefBackgroundPathUsesHeuristicGeneration() throws {
        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")

        XCTAssertTrue(
            appDelegateSource.contains("isAppActiveForLocalInference() == false"),
            "AppDelegate daily brief generation must check app active state before MLX inference"
        )
        XCTAssertTrue(
            appDelegateSource.contains("DailyBriefService.shared.generateBrief("),
            "Background daily brief path must use heuristic generation"
        )
        XCTAssertTrue(
            appDelegateSource.contains("DailyBriefService.shared.generateBriefOutput("),
            "Foreground daily brief path should retain MLX-capable generation"
        )
    }

    func testAddTaskSubmitCallsOnAcceptedBeforeOptimisticDispatch() throws {
        let source = try loadWorkspaceFile("To Do List/Presentation/ViewModels/AddTaskViewModel.swift")

        guard
            let acceptedRange = source.range(of: "onAccepted?(submission)"),
            let optimisticRange = source.range(of: "TaskNotificationDispatcher.postAsyncOnMain(")
        else {
            return XCTFail("AddTaskViewModel submitTask must contain accepted callback and async optimistic dispatch")
        }

        XCTAssertLessThan(
            source.distance(from: source.startIndex, to: acceptedRange.lowerBound),
            source.distance(from: source.startIndex, to: optimisticRange.lowerBound),
            "submitTask should invoke onAccepted before async optimistic dispatch enqueue"
        )
    }

    func testTaskNotificationDispatcherHasAsyncMainPostHelper() throws {
        let source = try loadWorkspaceFile("To Do List/Domain/Events/TaskNotificationDispatcher.swift")

        XCTAssertTrue(
            source.contains("static func postAsyncOnMain("),
            "TaskNotificationDispatcher should provide an explicit async main post helper"
        )
    }

    func testHomeCreatePathUsesIncrementalSortedUpsert() throws {
        let source = try loadWorkspaceFile("To Do List/Presentation/ViewModels/HomeViewModel.swift")

        XCTAssertTrue(
            source.contains("private func upsertingTaskPreservingSort"),
            "HomeViewModel should define incremental sorted upsert helper for create-path local updates"
        )
        XCTAssertTrue(
            source.contains("upcomingTasks = upsertingTaskPreservingSort(in: upcomingTasks, with: task)"),
            "Optimistic create path should use incremental sorted upsert for upcoming tasks"
        )
        XCTAssertFalse(
            source.contains("upcomingTasks = sortTasksByPriorityThenDue(upsertingTaskInPlace(in: upcomingTasks, with: task))"),
            "Optimistic create path should avoid full-array re-sort for upcomingTasks"
        )
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

final class AddTaskViewModelSubmitLatencyOrderingTests: XCTestCase {
    func testSubmitCallsOnAcceptedBeforeOptimisticDeliveryAndReturnsBeforeCommit() {
        let deferredRepository = DeferredCreateTaskDefinitionRepository()
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: deferredRepository,
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )
        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil
        )
        viewModel.taskName = "Latency ordering"

        var events: [String] = []
        let optimisticDelivered = expectation(description: "optimistic delivered")
        let commitCompletion = expectation(description: "commit completion")

        let observer = NotificationCenter.default.addObserver(
            forName: .taskCreationOptimistic,
            object: nil,
            queue: .main
        ) { _ in
            events.append("optimistic")
            optimisticDelivered.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        let submission = viewModel.submitTask(
            onAccepted: { _ in
                events.append("accepted")
            },
            completion: { result in
                if case .success = result {
                    events.append("commit")
                } else {
                    events.append("commit_failure")
                }
                commitCompletion.fulfill()
            }
        )
        events.append("returned")

        XCTAssertNotNil(submission)
        XCTAssertEqual(Array(events.prefix(2)), ["accepted", "returned"])
        XCTAssertTrue(viewModel.isSubmitting, "submitTask should return before create commit finishes")
        XCTAssertFalse(viewModel.isTaskCreated)
        XCTAssertNil(viewModel.lastCreatedTaskID)

        wait(for: [optimisticDelivered], timeout: 1.0)
        XCTAssertLessThan(indexOf("accepted", in: events), indexOf("optimistic", in: events))

        deferredRepository.completePendingCreateSuccess()
        wait(for: [commitCompletion], timeout: 1.0)

        XCTAssertLessThan(indexOf("returned", in: events), indexOf("commit", in: events))
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertTrue(viewModel.isTaskCreated)
        XCTAssertNotNil(viewModel.lastCreatedTaskID)
    }

    private func indexOf(_ event: String, in events: [String]) -> Int {
        events.firstIndex(of: event) ?? .max
    }
}

final class HomeViewModelOptimisticCreateNotificationTests: XCTestCase {
    func testOptimisticCreateThenCommitDoesNotDuplicateVisibleRow() {
        let suiteName = "HomeViewModelOptimisticCreateNotificationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let inbox = Project.createInbox()
        let seedTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Seed",
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let taskRepository = MockTaskRepository(seed: seedTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueueFlush()

        let createdID = UUID()
        let createdTask = makeVisibleTaskDefinition(id: createdID, title: "Optimistic Create")
        let startedAt = Date()

        NotificationCenter.default.post(
            name: .taskCreationOptimistic,
            object: createdTask,
            userInfo: ["startedAt": startedAt]
        )
        waitForMainQueueFlush(seconds: 0.05)
        XCTAssertEqual(visibleTaskOccurrenceCount(in: viewModel, taskID: createdID), 1)

        NotificationCenter.default.post(name: NSNotification.Name("TaskCreated"), object: createdTask)
        waitForMainQueueFlush(seconds: 0.05)
        XCTAssertEqual(visibleTaskOccurrenceCount(in: viewModel, taskID: createdID), 1)
    }

    func testOptimisticCreateRollbackRemovesVisibleRow() {
        let suiteName = "HomeViewModelOptimisticRollbackTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let inbox = Project.createInbox()
        let seedTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Seed",
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let taskRepository = MockTaskRepository(seed: seedTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueueFlush()

        let provisional = makeVisibleTaskDefinition(id: UUID(), title: "Will Roll Back")
        NotificationCenter.default.post(
            name: .taskCreationOptimistic,
            object: provisional,
            userInfo: ["startedAt": Date()]
        )
        waitForMainQueueFlush(seconds: 0.05)
        XCTAssertEqual(visibleTaskOccurrenceCount(in: viewModel, taskID: provisional.id), 1)

        NotificationCenter.default.post(name: .taskCreationRollback, object: provisional)
        waitForMainQueueFlush(seconds: 0.05)
        XCTAssertEqual(visibleTaskOccurrenceCount(in: viewModel, taskID: provisional.id), 0)
    }

    private func visibleTaskOccurrenceCount(in viewModel: HomeViewModel, taskID: UUID) -> Int {
        (viewModel.morningTasks + viewModel.eveningTasks + viewModel.overdueTasks + viewModel.upcomingTasks)
            .filter { $0.id == taskID }
            .count
    }

    private func makeVisibleTaskDefinition(id: UUID, title: String) -> TaskDefinition {
        let dueDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        return TaskDefinition(
            id: id,
            projectID: ProjectConstants.inboxProjectID,
            projectName: ProjectConstants.inboxProjectName,
            title: title,
            priority: .high,
            type: .morning,
            dueDate: dueDate,
            isComplete: false,
            dateAdded: Date(),
            isEveningTask: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func waitForMainQueueFlush(seconds: TimeInterval = 0.15) {
        let expectation = expectation(description: "MainQueueFlush")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: max(3.0, seconds + 2.5))
    }
}

private final class NoopAssistantActionRepository: AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        completion(.success(run))
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        completion(.success(run))
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        completion(.success(nil))
    }
}

private final class NoopTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.success(TaskDefinition(
            id: request.id,
            projectID: request.projectID,
            projectName: request.projectName ?? ProjectConstants.inboxProjectName,
            lifeAreaID: request.lifeAreaID,
            sectionID: request.sectionID,
            parentTaskID: request.parentTaskID,
            title: request.title,
            details: request.details,
            priority: request.priority,
            type: request.type,
            energy: request.energy,
            category: request.category,
            context: request.context,
            dueDate: request.dueDate,
            isComplete: false,
            dateAdded: request.createdAt,
            isEveningTask: request.isEveningTask,
            alertReminderTime: request.alertReminderTime,
            tagIDs: request.tagIDs,
            dependencies: request.dependencies,
            createdAt: request.createdAt,
            updatedAt: request.createdAt
        )))
    }
    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.failure(NSError(domain: "NoopTaskDefinitionRepository", code: 1)))
    }
    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class DeferredCreateTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private var pendingCreateRequest: CreateTaskDefinitionRequest?
    private var pendingCreateCompletion: ((Result<TaskDefinition, Error>) -> Void)?

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        pendingCreateRequest = request
        pendingCreateCompletion = completion
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.failure(NSError(domain: "DeferredCreateTaskDefinitionRepository", code: 1)))
    }
    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }

    func completePendingCreateSuccess() {
        guard let request = pendingCreateRequest, let completion = pendingCreateCompletion else { return }
        pendingCreateRequest = nil
        pendingCreateCompletion = nil
        completion(.success(request.toTaskDefinition(projectName: request.projectName)))
    }
}

private final class NoopExternalSyncRepository: ExternalSyncRepositoryProtocol {
    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchContainerMapping(provider: String, projectID: UUID, completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func upsertContainerMapping(provider: String, projectID: UUID, mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition, completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func upsertItemMappingByLocalKey(provider: String, localEntityType: String, localEntityID: UUID, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func upsertItemMappingByExternalKey(provider: String, externalItemID: String, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

private final class MockTaskRepository: LegacyTaskRepositoryShim, TaskReadModelRepositoryProtocol {
    private var storedTask: Task
    private let lock = NSLock()

    var currentTask: Task { readStoredTask() }
    private(set) var fetchAllTasksCallCount = 0
    private(set) var readModelFetchCallCount = 0
    private(set) var readModelSearchCallCount = 0

    init(seed: Task) {
        self.storedTask = seed
    }

    private func readStoredTask() -> Task {
        lock.lock()
        defer { lock.unlock() }
        return storedTask
    }

    private func replaceStoredTask(with task: Task) {
        lock.lock()
        storedTask = task
        lock.unlock()
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchAllTasksCallCount += 1
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        readModelFetchCallCount += 1
        let base = [readStoredTask()].filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let start = query.dueDateStart, let dueDate = task.dueDate, dueDate < start { return false }
            if let end = query.dueDateEnd, let dueDate = task.dueDate, dueDate > end { return false }
            return true
        }
        let start = min(query.offset, base.count)
        let end = min(start + query.limit, base.count)
        let slice = Array(base[start..<end])
        completion(.success(TaskDefinitionSliceResult(
            tasks: slice,
            totalCount: base.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        readModelSearchCallCount += 1
        let normalized = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = [readStoredTask()].filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if normalized.isEmpty { return true }
            let nameMatch = task.title.lowercased().contains(normalized)
            let detailMatch = task.details?.lowercased().contains(normalized) ?? false
            return nameMatch || detailMatch
        }
        let start = min(query.offset, base.count)
        let end = min(start + query.limit, base.count)
        let slice = Array(base[start..<end])
        completion(.success(TaskDefinitionSliceResult(
            tasks: slice,
            totalCount: base.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func fetchLatestTaskUpdatedAt(completion: @escaping (Result<Date?, Error>) -> Void) {
        completion(.success(readStoredTask().updatedAt))
    }

    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        let task = readStoredTask()
        if includeCompleted || task.isComplete == false {
            completion(.success([task.projectID: 1]))
        } else {
            completion(.success([:]))
        }
    }

    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        let task = readStoredTask()
        guard
            task.isComplete,
            let completedAt = task.dateCompleted,
            completedAt >= startDate,
            completedAt <= endDate
        else {
            completion(.success([:]))
            return
        }
        completion(.success([task.projectID: task.priority.scorePoints]))
    }

    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let task = readStoredTask()
        completion(.success(task.isComplete ? [task] : []))
    }

    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        let task = readStoredTask()
        completion(.success(task.type == type ? [task] : []))
    }

    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        let task = readStoredTask()
        DispatchQueue.main.async {
            completion(.success(task.id == id ? task : nil))
        }
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        replaceStoredTask(with: task)
        DispatchQueue.main.async {
            completion(.success(task))
        }
    }

    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.isComplete = true
        task.dateCompleted = Date()
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.isComplete = false
        task.dateCompleted = nil
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.dueDate = date
        replaceStoredTask(with: task)
        completion(.success(task))
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
        completion(.success([readStoredTask()]))
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

final class OccurrenceIdentityTests: XCTestCase {
    func testGeneratedOccurrenceKeyContainsTemplateScheduledDateAndSourceID() throws {
        let templateID = UUID()
        let sourceID = UUID()
        let now = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01T00:00:00Z
        let start = now
        let end = Date(timeIntervalSince1970: 1_704_153_599) // 2024-01-01T23:59:59Z

        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .task,
                sourceID: sourceID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: start,
                windowStart: "09:00",
                windowEnd: "18:00",
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
        ]

        let occurrenceRepository = InMemoryOccurrenceRepository()
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        let generated = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: start,
                windowEnd: end,
                sourceFilter: nil,
                completion: completion
            )
        }

        XCTAssertEqual(generated.count, 1)
        let keyParts = generated[0].occurrenceKey.split(separator: "|").map(String.init)
        XCTAssertEqual(keyParts.count, 3)
        XCTAssertEqual(keyParts[0], templateID.uuidString)
        XCTAssertEqual(keyParts[2], sourceID.uuidString)

        let secondPass = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: start,
                windowEnd: end,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertTrue(secondPass.isEmpty, "Deterministic keying should prevent duplicate generation")
    }

    func testResolveDoesNotMutateOccurrenceKey() throws {
        let now = Date()
        let occurrence = OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: "template|2026-01-01T09:00:00Z|\(UUID().uuidString)",
            scheduleTemplateID: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            scheduledAt: now,
            dueAt: now,
            state: .pending,
            isGenerated: true,
            generationWindow: "rolling",
            createdAt: now,
            updatedAt: now
        )

        let scheduleRepository = InMemoryScheduleRepository()
        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [occurrence]
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        _ = try awaitResult { completion in
            engine.resolveOccurrence(
                id: occurrence.id,
                resolution: .completed,
                actor: .user,
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            occurrenceRepository.fetchInRange(
                start: now.addingTimeInterval(-60),
                end: now.addingTimeInterval(60),
                completion: completion
            )
        }

        XCTAssertEqual(fetched.first?.occurrenceKey, occurrence.occurrenceKey)
    }
}

final class OccurrenceMaintenanceTests: XCTestCase {
    func testMaintenanceMarksStalePendingAsMissedAndPurgesResolvedIntoTombstones() throws {
        let now = Date()
        let stalePending = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -31, to: now) ?? now,
            state: .pending
        )
        let resolvedOld = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -91, to: now) ?? now,
            state: .completed
        )
        let recentCompleted = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now,
            state: .completed
        )

        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [stalePending, resolvedOld, recentCompleted]
        let tombstoneRepository = InMemoryTombstoneRepository()

        let useCase = MaintainOccurrencesUseCase(
            occurrenceRepository: occurrenceRepository,
            tombstoneRepository: tombstoneRepository
        )

        _ = try awaitResult { completion in
            useCase.execute(completion: completion)
        }

        let missedResolution = occurrenceRepository.resolutions.first {
            $0.occurrenceID == stalePending.id && $0.resolutionType == .missed
        }
        XCTAssertNotNil(missedResolution)

        XCTAssertTrue(occurrenceRepository.deletedOccurrenceIDs.contains(resolvedOld.id))
        XCTAssertFalse(occurrenceRepository.occurrences.contains(where: { $0.id == resolvedOld.id }))
        XCTAssertTrue(occurrenceRepository.occurrences.contains(where: { $0.id == recentCompleted.id }))
        XCTAssertTrue(tombstoneRepository.tombstones.contains(where: { $0.entityID == resolvedOld.id }))
    }

    private func makeOccurrence(scheduledAt: Date, state: OccurrenceState) -> OccurrenceDefinition {
        OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: "\(UUID().uuidString)|\(scheduledAt.timeIntervalSince1970)|\(UUID().uuidString)",
            scheduleTemplateID: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            state: state,
            isGenerated: true,
            generationWindow: "rolling",
            createdAt: scheduledAt,
            updatedAt: scheduledAt
        )
    }
}

final class TombstoneRetentionTests: XCTestCase {
    func testExpiredTombstonesArePurged() throws {
        let now = Date()
        let expired = TombstoneDefinition(
            id: UUID(),
            entityType: "Occurrence",
            entityID: UUID(),
            deletedAt: now.addingTimeInterval(-10_000),
            deletedBy: "system",
            purgeAfter: now.addingTimeInterval(-100)
        )
        let retained = TombstoneDefinition(
            id: UUID(),
            entityType: "Occurrence",
            entityID: UUID(),
            deletedAt: now,
            deletedBy: "system",
            purgeAfter: now.addingTimeInterval(10_000)
        )

        let repository = InMemoryTombstoneRepository()
        repository.tombstones = [expired, retained]
        let useCase = PurgeExpiredTombstonesUseCase(tombstoneRepository: repository)

        _ = try awaitResult { completion in
            useCase.execute(referenceDate: now, completion: completion)
        }

        XCTAssertTrue(repository.deletedIDs.contains(expired.id))
        XCTAssertFalse(repository.deletedIDs.contains(retained.id))
        XCTAssertTrue(repository.tombstones.contains(where: { $0.id == retained.id }))
    }
}

final class V2RepositoryInvariantTests: XCTestCase {
    func testTaskTagLinkUniquenessRejectsDuplicateTaskTagPairs() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskTagLinkRepository(container: container)
        let taskID = UUID()
        let tagA = UUID()
        let tagB = UUID()

        _ = try awaitResult { completion in
            repository.replaceTagLinks(
                taskID: taskID,
                tagIDs: [tagA, tagA, tagB, tagA],
                completion: completion
            )
        }

        let savedTagIDs = try awaitResult { completion in
            repository.fetchTagIDs(taskID: taskID, completion: completion)
        }

        XCTAssertEqual(Set(savedTagIDs), Set([tagA, tagB]))
        XCTAssertEqual(savedTagIDs.count, 2)
    }

    func testExternalMapUpsertsStayDeterministicAcrossCompositeKeys() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)

        let provider = "apple_reminders"
        let projectID = UUID()
        let localEntityID = UUID()
        let externalItemID = "reminder-1"

        let firstContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-a",
                    syncEnabled: true,
                    lastSyncAt: nil,
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }

        let secondContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-b",
                    syncEnabled: true,
                    lastSyncAt: Date(),
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }

        XCTAssertEqual(firstContainerMap.id, secondContainerMap.id)
        XCTAssertEqual(secondContainerMap.externalContainerID, "container-b")

        let firstItemMap = try awaitResult { completion in
            repository.upsertItemMappingByLocalKey(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: nil,
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        let secondItemMap = try awaitResult { completion in
            repository.upsertItemMappingByExternalKey(
                provider: provider,
                externalItemID: externalItemID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: "persisted-1",
                        lastSeenExternalModAt: Date(),
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        XCTAssertEqual(firstItemMap.id, secondItemMap.id)

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "V2RepositoryInvariantTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class TaskTagLinkUniquenessTests: XCTestCase {
    func testDuplicateTaskTagLinksCollapseToUniquePairs() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskTagLinkRepository(container: container)
        let taskID = UUID()
        let tagA = UUID()
        let tagB = UUID()

        _ = try awaitResult { completion in
            repository.replaceTagLinks(
                taskID: taskID,
                tagIDs: [tagA, tagB, tagA, tagB, tagA],
                completion: completion
            )
        }

        let stored = try awaitResult { completion in
            repository.fetchTagIDs(taskID: taskID, completion: completion)
        }

        XCTAssertEqual(Set(stored), Set([tagA, tagB]))
        XCTAssertEqual(stored.count, 2)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskTagLinkUniquenessTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class ExternalMapUniquenessTests: XCTestCase {
    func testCompositeKeyUpsertsResolveToSingleCanonicalMap() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let provider = "apple_reminders"
        let projectID = UUID()
        let localEntityID = UUID()
        let externalItemID = "external-map-\(UUID().uuidString)"

        let firstContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-a",
                    syncEnabled: true,
                    lastSyncAt: nil,
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }
        let secondContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-b",
                    syncEnabled: true,
                    lastSyncAt: Date(),
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }
        XCTAssertEqual(firstContainerMap.id, secondContainerMap.id)

        _ = try awaitResult { completion in
            repository.upsertItemMappingByLocalKey(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: nil,
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }
        _ = try awaitResult { completion in
            repository.upsertItemMappingByExternalKey(
                provider: provider,
                externalItemID: externalItemID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: "persisted-42",
                        lastSeenExternalModAt: Date(),
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "ExternalMapUniquenessTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class ScheduleExceptionRebuildTests: XCTestCase {
    func testSkipExceptionDeletesTargetOccurrenceWithoutMassSkippingFutureRows() throws {
        let templateID = UUID()
        let sourceID = UUID()
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        let windowEnd = Calendar.current.date(byAdding: .day, value: 2, to: dayStart) ?? dayStart

        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .task,
                sourceID: sourceID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: dayStart,
                windowStart: "09:00",
                windowEnd: "18:00",
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
        ]

        let occurrenceRepository = InMemoryOccurrenceRepository()
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        let initial = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: dayStart,
                windowEnd: windowEnd,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertGreaterThanOrEqual(initial.count, 2, "Expected at least two occurrences in the generation window")
        let sortedInitial = initial.sorted { $0.scheduledAt < $1.scheduledAt }
        let target = try XCTUnwrap(sortedInitial.first)
        let unaffected = try XCTUnwrap(sortedInitial.dropFirst().first)

        _ = try awaitResult { completion in
            engine.applyScheduleException(
                templateID: templateID,
                occurrenceKey: target.occurrenceKey,
                action: .skip,
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            occurrenceRepository.fetchInRange(start: dayStart, end: windowEnd, completion: completion)
        }

        let targetRows = fetched.filter { $0.occurrenceKey == target.occurrenceKey }
        XCTAssertTrue(targetRows.isEmpty, "Skipped occurrence should be removed and not recreated")

        let unaffectedRows = fetched.filter { $0.occurrenceKey == unaffected.occurrenceKey }
        XCTAssertEqual(unaffectedRows.count, 1, "Rebuild should preserve unaffected future occurrence identity")
        XCTAssertEqual(unaffectedRows.first?.state, .pending, "Rebuild must not mass-skip future unresolved occurrences")

        let secondPass = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: dayStart,
                windowEnd: windowEnd,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertTrue(secondPass.isEmpty, "Exception rebuild should not recreate skipped occurrence with same key")
    }
}

final class ConcurrencyRaceTests: XCTestCase {
    func testConcurrentTagCreatesConvergeToSingleNormalizedRow() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTagRepository(container: container)
        let candidateNames = ["Work", "work", " WORK ", "WoRk"]
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<24 {
            group.enter()
            let name = candidateNames[index % candidateNames.count]
            repository.create(TagDefinition(id: UUID(), name: name)) { result in
                if case .failure(let error) = result {
                    lock.lock()
                    if firstError == nil {
                        firstError = error
                    }
                    lock.unlock()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let tags = try awaitResult { completion in
            repository.fetchAll(completion: completion)
        }
        let normalizedMatches = tags.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "work"
        }
        XCTAssertEqual(normalizedMatches.count, 1)
    }

    func testConcurrentExternalMapUpsertsConvergeToSingleMapIdentity() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let provider = "apple_reminders"
        let localEntityID = UUID()
        let externalItemID = "race-item-\(UUID().uuidString)"
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<24 {
            group.enter()
            if index.isMultiple(of: 2) {
                repository.upsertItemMappingByLocalKey(
                    provider: provider,
                    localEntityType: "task",
                    localEntityID: localEntityID,
                    mutate: { existing in
                        ExternalItemMapDefinition(
                            id: existing?.id ?? UUID(),
                            provider: provider,
                            localEntityType: "task",
                            localEntityID: localEntityID,
                            externalItemID: externalItemID,
                            externalPersistentID: nil,
                            lastSeenExternalModAt: nil,
                            externalPayloadData: nil,
                            createdAt: existing?.createdAt ?? Date()
                        )
                    },
                    completion: { result in
                        if case .failure(let error) = result {
                            lock.lock()
                            if firstError == nil {
                                firstError = error
                            }
                            lock.unlock()
                        }
                        group.leave()
                    }
                )
            } else {
                repository.upsertItemMappingByExternalKey(
                    provider: provider,
                    externalItemID: externalItemID,
                    mutate: { existing in
                        ExternalItemMapDefinition(
                            id: existing?.id ?? UUID(),
                            provider: provider,
                            localEntityType: "task",
                            localEntityID: localEntityID,
                            externalItemID: externalItemID,
                            externalPersistentID: "persist-\(index)",
                            lastSeenExternalModAt: Date(),
                            externalPayloadData: nil,
                            createdAt: existing?.createdAt ?? Date()
                        )
                    },
                    completion: { result in
                        if case .failure(let error) = result {
                            lock.lock()
                            if firstError == nil {
                                firstError = error
                            }
                            lock.unlock()
                        }
                        group.leave()
                    }
                )
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    func testConcurrentXPEventSavesRespectIdempotencyUnderRace() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let idempotencyKey = "xp-race-\(UUID().uuidString)"
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<20 {
            group.enter()
            let event = XPEventDefinition(
                id: UUID(),
                occurrenceID: nil,
                taskID: nil,
                delta: 10 + index,
                reason: "race-test",
                idempotencyKey: idempotencyKey,
                createdAt: Date()
            )
            repository.saveXPEvent(event) { result in
                if case .failure(let error) = result {
                    lock.lock()
                    if firstError == nil {
                        firstError = error
                    }
                    lock.unlock()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let storedEvents = try awaitResult { completion in
            repository.fetchXPEvents(completion: completion)
        }
        let matches = storedEvents.filter { $0.idempotencyKey == idempotencyKey }
        XCTAssertEqual(matches.count, 1, "Race save should keep one canonical XP event per idempotency key")
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "ConcurrencyRaceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class TaskDefinitionCreationMetadataTests: XCTestCase {
    func testCreateTaskDefinitionPersistsMetadataAndLinks() throws {
        let taskRepository = MetadataCapturingTaskDefinitionRepository()
        let tagRepository = MetadataCapturingTaskTagLinkRepository()
        let dependencyRepository = MetadataCapturingTaskDependencyRepository()
        let useCase = CreateTaskDefinitionUseCase(
            repository: taskRepository,
            taskTagLinkRepository: tagRepository,
            taskDependencyRepository: dependencyRepository
        )

        let dependencyA = TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .blocks)
        let dependencyB = TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .related)
        let request = CreateTaskDefinitionRequest(
            id: UUID(),
            title: "Plan release #work",
            details: "Finalize and ship",
            projectID: UUID(),
            projectName: "Work",
            lifeAreaID: UUID(),
            sectionID: UUID(),
            dueDate: Date(),
            parentTaskID: UUID(),
            tagIDs: [UUID(), UUID()],
            dependencies: [dependencyA, dependencyB],
            priority: .high,
            type: .morning,
            energy: .high,
            category: .general,
            context: .anywhere,
            isEveningTask: false,
            alertReminderTime: Date(),
            createdAt: Date()
        )

        let createdTask = try awaitResult { completion in
            useCase.execute(request: request, completion: completion)
        }

        XCTAssertEqual(taskRepository.lastCreateRequest?.id, request.id)
        XCTAssertEqual(taskRepository.lastCreateRequest?.lifeAreaID, request.lifeAreaID)
        XCTAssertEqual(taskRepository.lastCreateRequest?.sectionID, request.sectionID)
        XCTAssertEqual(taskRepository.lastCreateRequest?.parentTaskID, request.parentTaskID)
        XCTAssertEqual(createdTask.projectID, request.projectID)
        XCTAssertEqual(createdTask.projectName, request.projectName)

        XCTAssertEqual(tagRepository.lastTaskID, request.id)
        XCTAssertEqual(Set(tagRepository.lastTagIDs ?? []), Set(request.tagIDs))

        XCTAssertEqual(dependencyRepository.lastTaskID, request.id)
        XCTAssertEqual(dependencyRepository.lastDependencies?.count, 2)
        XCTAssertEqual(Set(dependencyRepository.lastDependencies?.map(\.kind) ?? []), Set([.blocks, .related]))
    }
}

private final class InMemoryScheduleRepository: ScheduleRepositoryProtocol {
    var templates: [ScheduleTemplateDefinition] = []
    var rulesByTemplateID: [UUID: [ScheduleRuleDefinition]] = [:]
    var exceptionsByTemplateID: [UUID: [ScheduleExceptionDefinition]] = [:]

    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) {
        completion(.success(templates))
    }

    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        completion(.success(rulesByTemplateID[templateID] ?? []))
    }

    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) {
        templates.removeAll { $0.id == template.id }
        templates.append(template)
        completion(.success(template))
    }

    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) {
        completion(.success(exceptionsByTemplateID[templateID] ?? []))
    }

    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) {
        var current = exceptionsByTemplateID[exception.scheduleTemplateID] ?? []
        current.append(exception)
        exceptionsByTemplateID[exception.scheduleTemplateID] = current
        completion(.success(exception))
    }
}

private final class MetadataCapturingTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    var lastCreateRequest: CreateTaskDefinitionRequest?
    var byID: [UUID: TaskDefinition] = [:]

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        lastCreateRequest = request
        let task = request.toTaskDefinition(projectName: request.projectName)
        byID[task.id] = task
        completion(.success(task))
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        guard var current = byID[request.id] else {
            completion(.failure(NSError(domain: "MetadataCapturingTaskDefinitionRepository", code: 404)))
            return
        }
        if let title = request.title { current.title = title }
        if let details = request.details { current.details = details }
        if let projectID = request.projectID { current.projectID = projectID }
        if request.clearDueDate {
            current.dueDate = nil
        } else if let dueDate = request.dueDate {
            current.dueDate = dueDate
        }
        if let isComplete = request.isComplete { current.isComplete = isComplete }
        if request.dateCompleted != nil || request.isComplete == false { current.dateCompleted = request.dateCompleted }
        byID[current.id] = current
        completion(.success(current))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        byID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class MetadataCapturingTaskTagLinkRepository: TaskTagLinkRepositoryProtocol {
    var lastTaskID: UUID?
    var lastTagIDs: [UUID]?

    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) {
        completion(.success(lastTaskID == taskID ? (lastTagIDs ?? []) : []))
    }

    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        lastTaskID = taskID
        lastTagIDs = tagIDs
        completion(.success(()))
    }
}

private final class MetadataCapturingTaskDependencyRepository: TaskDependencyRepositoryProtocol {
    var lastTaskID: UUID?
    var lastDependencies: [TaskDependencyLinkDefinition]?

    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) {
        completion(.success(lastTaskID == taskID ? (lastDependencies ?? []) : []))
    }

    func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastTaskID = taskID
        lastDependencies = dependencies
        completion(.success(()))
    }
}

private final class InMemoryOccurrenceRepository: OccurrenceRepositoryProtocol {
    var occurrences: [OccurrenceDefinition] = []
    var resolutions: [OccurrenceResolutionDefinition] = []
    var deletedOccurrenceIDs: [UUID] = []

    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) {
        completion(.success(occurrences.filter { $0.scheduledAt >= start && $0.scheduledAt <= end }))
    }

    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) {
        for occurrence in occurrences {
            if let index = self.occurrences.firstIndex(where: { $0.id == occurrence.id }) {
                self.occurrences[index] = occurrence
            } else {
                self.occurrences.append(occurrence)
            }
        }
        completion(.success(()))
    }

    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        resolutions.append(resolution)
        if let index = occurrences.firstIndex(where: { $0.id == resolution.occurrenceID }) {
            switch resolution.resolutionType {
            case .completed:
                occurrences[index].state = .completed
            case .skipped, .deferred:
                occurrences[index].state = .skipped
            case .missed:
                occurrences[index].state = .missed
            }
            occurrences[index].updatedAt = resolution.resolvedAt
        }
        completion(.success(()))
    }

    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        deletedOccurrenceIDs.append(contentsOf: ids)
        occurrences.removeAll { ids.contains($0.id) }
        completion(.success(()))
    }
}

private final class InMemoryTombstoneRepository: TombstoneRepositoryProtocol {
    var tombstones: [TombstoneDefinition] = []
    var deletedIDs: [UUID] = []

    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        tombstones.append(tombstone)
        completion(.success(()))
    }

    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) {
        completion(.success(tombstones.filter { $0.purgeAfter <= date }))
    }

    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        deletedIDs.append(contentsOf: ids)
        tombstones.removeAll { ids.contains($0.id) }
        completion(.success(()))
    }
}

final class ReconcileExternalRemindersConflictTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.remindersSyncEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        super.tearDown()
    }

    func testEqualTimestampConflictDeterministicallyPullsWhenRemoteClockWinsNodeTie() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_705_000_000)
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-a"
        let externalID = "ext-a"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local Title",
                dueDate: fixedDate,
                isComplete: false,
                dateAdded: fixedDate,
                createdAt: fixedDate,
                updatedAt: fixedDate
            )
        ])
        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: fixedDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: fixedDate,
                externalPayloadData: nil,
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: fixedDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Remote Title",
                notes: "remote",
                dueDate: fixedDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: fixedDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "aaa-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pulledFromExternal, 0)
        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(provider.upsertedSnapshots.count, 0)

        let updatedTask = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(updatedTask?.title, "Remote Title")
        XCTAssertEqual(updatedTask?.details, "remote")
    }

    func testNewerTombstoneSuppressesBothPullAndPush() throws {
        let baseDate = Date(timeIntervalSince1970: 1_705_100_000)
        let tombstone = SyncClock(
            physicalMillis: Int64(baseDate.timeIntervalSince1970 * 1_000) + 10_000,
            logicalCounter: 0,
            nodeID: "remote.apple_reminders"
        )
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-b"
        let externalID = "ext-b"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local Tombstoned",
                dueDate: nil,
                isComplete: false,
                dateAdded: baseDate,
                createdAt: baseDate,
                updatedAt: baseDate
            )
        ])

        var state = ReminderMergeState()
        state.tombstoneClock = tombstone

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: baseDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: baseDate,
                externalPayloadData: nil,
                syncStateData: state.encodedData(),
                createdAt: baseDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Remote Tombstoned",
                notes: nil,
                dueDate: nil,
                completionDate: nil,
                isCompleted: false,
                priority: 0,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: baseDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pulledFromExternal, 0)
        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(provider.upsertedSnapshots.count, 0)
    }

    func testNewerLocalUpdateResurrectsAfterOlderTombstone() throws {
        let oldDate = Date(timeIntervalSince1970: 1_705_200_000)
        let newDate = oldDate.addingTimeInterval(3_600)
        let tombstone = SyncClock(
            physicalMillis: Int64(oldDate.timeIntervalSince1970 * 1_000),
            logicalCounter: 0,
            nodeID: "remote.apple_reminders"
        )

        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-c"
        let externalID = "ext-c"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Locally Resurrected",
                dueDate: newDate,
                isComplete: false,
                dateAdded: oldDate,
                createdAt: oldDate,
                updatedAt: newDate
            )
        ])

        var state = ReminderMergeState()
        state.tombstoneClock = tombstone
        state.lastWriteClock = tombstone

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: oldDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: oldDate,
                externalPayloadData: nil,
                syncStateData: state.encodedData(),
                createdAt: oldDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Old Remote Value",
                notes: nil,
                dueDate: oldDate,
                completionDate: nil,
                isCompleted: false,
                priority: 0,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: oldDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pushedToExternal, 1)
        XCTAssertEqual(provider.upsertedSnapshots.count, 1)

        let updatedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let updatedState = ReminderMergeState.decode(from: updatedMap?.syncStateData)
        XCTAssertNil(updatedState.tombstoneClock, "Successful resurrection must clear obsolete tombstone clock")
    }

    func testMappedMissingRemoteWithDeletedLocalCreatesTombstone() throws {
        let oldDate = Date(timeIntervalSince1970: 1_705_260_000)
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-missing-remote"
        let externalID = "ext-missing-remote"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [])
        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: oldDate
            )
        ]

        let envelope = ReminderMergeEnvelope(
            known: ReminderMergeEnvelope.KnownFields(
                title: "Previously Synced",
                notes: "legacy",
                dueDate: oldDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: []
            ),
            passthroughData: Data("legacy-passthrough".utf8)
        )

        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: oldDate,
                externalPayloadData: try JSONEncoder().encode(envelope),
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: oldDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = []

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(summary.pulledFromExternal, 0)

        let updatedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let state = ReminderMergeState.decode(from: updatedMap?.syncStateData)
        XCTAssertNotNil(state.tombstoneClock, "Missing remote + missing local must persist a tombstone decision")
    }
}

final class ReminderPayloadRoundTripTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.remindersSyncEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        super.tearDown()
    }

    func testLegacyPayloadDecodePreservesRawBytesAsPassthrough() {
        let legacyPayload = Data(#"{"title":"Legacy Reminder","notes":"n","unsupported":{"alpha":1}}"#.utf8)
        let mergeEngine = ReminderMergeEngine()
        let decoded = mergeEngine.decodeEnvelope(data: legacyPayload)

        XCTAssertEqual(decoded?.known.title, "Legacy Reminder")
        XCTAssertEqual(decoded?.passthroughData, legacyPayload)
    }

    func testUnsupportedPayloadBytesArePreservedAcrossPush() throws {
        let baseDate = Date(timeIntervalSince1970: 1_705_300_000)
        let passthrough = Data("opaque-payload".utf8)
        let originalEnvelope = ReminderMergeEnvelope(
            known: ReminderMergeEnvelope.KnownFields(
                title: "Old",
                notes: "old-note",
                dueDate: baseDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: "https://example.com",
                alarmDates: []
            ),
            passthroughData: passthrough
        )
        let originalPayload = try JSONEncoder().encode(originalEnvelope)

        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-roundtrip"
        let externalID = "ext-roundtrip"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local New Title",
                details: "Local New Notes",
                dueDate: baseDate.addingTimeInterval(86_400),
                isComplete: false,
                dateAdded: baseDate,
                createdAt: baseDate,
                updatedAt: baseDate.addingTimeInterval(120)
            )
        ])

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: baseDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: baseDate,
                externalPayloadData: originalPayload,
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: baseDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Older Remote Title",
                notes: nil,
                dueDate: baseDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: baseDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }
        XCTAssertEqual(summary.pushedToExternal, 1)

        let pushedPayload = try XCTUnwrap(provider.upsertedSnapshots.first?.payloadData)
        let pushedEnvelope = try JSONDecoder().decode(ReminderMergeEnvelope.self, from: pushedPayload)
        XCTAssertEqual(pushedEnvelope.passthroughData, passthrough)
        XCTAssertEqual(pushedEnvelope.known.title, "Local New Title")

        let savedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let savedPayload = try XCTUnwrap(savedMap?.externalPayloadData)
        let savedEnvelope = try JSONDecoder().decode(ReminderMergeEnvelope.self, from: savedPayload)
        XCTAssertEqual(savedEnvelope.passthroughData, passthrough)
        XCTAssertEqual(savedEnvelope.known.title, "Local New Title")
    }
}

final class SyncClockDeterminismTests: XCTestCase {
    func testLogicalCounterBreaksPhysicalTimestampTie() {
        let lhs = SyncClock(physicalMillis: 1_000, logicalCounter: 1, nodeID: "node-a")
        let rhs = SyncClock(physicalMillis: 1_000, logicalCounter: 2, nodeID: "node-a")
        XCTAssertTrue(rhs > lhs)
    }

    func testNodeIDBreaksFullClockTieDeterministically() {
        let lhs = SyncClock(physicalMillis: 1_000, logicalCounter: 0, nodeID: "node-a")
        let rhs = SyncClock(physicalMillis: 1_000, logicalCounter: 0, nodeID: "node-b")
        XCTAssertTrue(lhs < rhs)
        XCTAssertTrue(rhs > lhs)
    }
}

final class AssistantPipelineTransactionalTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalAssistantApplyEnabled = true
    private var originalAssistantUndoEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalAssistantApplyEnabled = V2FeatureFlags.assistantApplyEnabled
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantApplyEnabled = true
        V2FeatureFlags.assistantUndoEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.assistantApplyEnabled = originalAssistantApplyEnabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        super.tearDown()
    }

    func testPartialApplyFailureRollsBackAndPersistsVerifiedRollbackOutcome() throws {
        let taskID = UUID()
        let projectID = UUID()
        let initialTask = TaskDefinition(
            id: taskID,
            projectID: projectID,
            projectName: "Inbox",
            title: "Before Apply",
            dueDate: nil,
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [initialTask])
        taskRepository.failUpdateOnCall = 2
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [
                .updateTask(taskID: taskID, title: "Step 1", dueDate: nil),
                .updateTask(taskID: taskID, title: "Step 2", dueDate: nil)
            ]
        )
        let run = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .confirmed,
            confirmedAt: Date(),
            createdAt: Date()
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(run, completion: completion)
        }

        let applyExpectation = expectation(description: "apply-fails")
        useCase.applyConfirmedRun(id: runID) { result in
            if case .failure = result {
                applyExpectation.fulfill()
            } else {
                XCTFail("Expected apply to fail")
            }
        }
        waitForExpectations(timeout: 2.0)

        let persistedRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(persistedRun?.status, .failed)
        XCTAssertEqual(persistedRun?.rollbackStatus, .verified)
        XCTAssertNotNil(persistedRun?.rollbackVerifiedAt)
        XCTAssertNotNil(persistedRun?.executionTraceData)
        XCTAssertEqual(persistedRun?.lastErrorCode, "assistant_apply_failed")

        let finalTask = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(finalTask?.title, "Before Apply", "Rollback must restore pre-apply state")
    }

    func testSuccessfulApplyGeneratesDeterministicUndoPlan() throws {
        let taskID = UUID()
        let projectID = UUID()
        let initialTask = TaskDefinition(
            id: taskID,
            projectID: projectID,
            projectName: "Inbox",
            title: "Before Undo",
            dueDate: nil,
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [initialTask])
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [
                .updateTask(taskID: taskID, title: "After Undo", dueDate: nil)
            ]
        )
        let run = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .confirmed,
            confirmedAt: Date(),
            createdAt: Date()
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(run, completion: completion)
        }

        _ = try awaitResult { completion in
            useCase.applyConfirmedRun(id: runID, completion: completion)
        }

        let appliedRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(appliedRun?.status, .applied)
        let appliedData = try XCTUnwrap(appliedRun?.proposalData)
        let appliedEnvelope = try JSONDecoder().decode(AssistantCommandEnvelope.self, from: appliedData)
        XCTAssertEqual(appliedEnvelope.undoCommands?.count, 1)

        _ = try awaitResult { completion in
            useCase.undoAppliedRun(id: runID, completion: completion)
        }

        let undoneRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(undoneRun?.status, .confirmed)

        let taskAfterUndo = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(taskAfterUndo?.title, "Before Undo")
    }
}

final class AssistantUndoWindowTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalAssistantUndoEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = true
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        // V3 runtime is always enabled in tests
        V2FeatureFlags.assistantUndoEnabled = true
    }

    override func tearDown() {
        _ = originalV2Enabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        super.tearDown()
    }

    func testUndoWindowExpirationIsDeterministic() throws {
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [])
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [.createTask(projectID: UUID(), title: "Expired")],
            undoCommands: [.deleteTask(taskID: UUID())]
        )
        let staleRun = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .applied,
            confirmedAt: Date().addingTimeInterval(-4_000),
            appliedAt: Date().addingTimeInterval(-4_000),
            createdAt: Date().addingTimeInterval(-4_000)
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(staleRun, completion: completion)
        }

        let expectation = expectation(description: "undo-expired")
        useCase.undoAppliedRun(id: runID) { result in
            switch result {
            case .failure(let error as NSError):
                XCTAssertEqual(error.code, 410)
                expectation.fulfill()
            default:
                XCTFail("Expected undo window expiration failure")
            }
        }
        waitForExpectations(timeout: 2.0)
    }
}

final class ReadModelQueryPathTests: XCTestCase {
    func testHomeAndSearchUseCasesPreferReadModelQueriesOverFetchAll() {
        let inbox = Project.createInbox()
        let task = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "ReadModel Task",
            details: "searchable",
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let repository = MockTaskRepository(seed: task)

        let homeUseCase = GetHomeFilteredTasksUseCase(readModelRepository: repository)
        let homeExpectation = expectation(description: "home-read-model")
        homeUseCase.execute(state: HomeFilterState.default, scope: HomeListScope.today) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected home failure: \(error)")
            }
            homeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.readModelFetchCallCount, 1)
        XCTAssertEqual(repository.fetchAllTasksCallCount, 0)

        let getTasksUseCase = GetTasksUseCase(readModelRepository: repository)
        let searchExpectation = expectation(description: "search-read-model")
        getTasksUseCase.searchTasks(query: "ReadModel", in: .all) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected search failure: \(error)")
            }
            searchExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.readModelSearchCallCount, 1)
        XCTAssertEqual(repository.fetchAllTasksCallCount, 0)
    }
}

final class V2PerformanceGateTests: XCTestCase {
    private struct PerfSnapshot: Decodable {
        struct Percentiles: Decodable {
            let p95_ms: Double
            let p99_ms: Double
        }
        struct Metrics: Decodable {
            let home: Percentiles
            let project: Percentiles
            let search: Percentiles
        }
        let metrics: Metrics
    }

    func testPerfSeedHarnessProducesBalancedProfileSnapshot() throws {
#if !os(macOS)
        throw XCTSkip("Shell command perf harness is only supported on macOS host tests")
#endif
        let root = workspaceRootURLForTests()
        let outputURL = root.appendingPathComponent("build/benchmarks/v2_readmodel.test.json")
        let command = [
            "swift",
            "scripts/perf_seed_v3.swift",
            "--tasks", "2000",
            "--occurrences", "20000",
            "--iterations", "60",
            "--output", outputURL.path
        ].joined(separator: " ")

        let status = try runShellCommand(command, in: root)
        XCTAssertEqual(status, 0, "Benchmark harness command failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let data = try Data(contentsOf: outputURL)
        let snapshot = try JSONDecoder().decode(PerfSnapshot.self, from: data)
        XCTAssertLessThanOrEqual(snapshot.metrics.home.p95_ms, 250)
        XCTAssertLessThanOrEqual(snapshot.metrics.project.p95_ms, 250)
        XCTAssertLessThanOrEqual(snapshot.metrics.search.p95_ms, 300)
        XCTAssertLessThanOrEqual(snapshot.metrics.home.p99_ms, 600)
        XCTAssertLessThanOrEqual(snapshot.metrics.project.p99_ms, 600)
        XCTAssertLessThanOrEqual(snapshot.metrics.search.p99_ms, 600)
    }
}

final class FlowctlToolingTests: XCTestCase {
    func testFlowctlInstallAndVerifyScriptsSucceed() throws {
#if !os(macOS)
        throw XCTSkip("flowctl shell checks are only supported on macOS host tests")
#endif
        let root = workspaceRootURLForTests()
        XCTAssertEqual(try runShellCommand("FLOWCTL_ALLOW_SHIM=1 bash scripts/install_flowctl.sh", in: root), 0)
        XCTAssertEqual(try runShellCommand("FLOWCTL_ALLOW_SHIM=1 bash scripts/verify_flowctl.sh", in: root), 0)
        let flowctlPath = root.appendingPathComponent(".flow/bin/flowctl").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: flowctlPath))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: flowctlPath))
    }
}

final class AssistantPipelineImplementationTests: XCTestCase {
    func testPipelineImplementationContainsNoSemaphoreWaits() throws {
        let root = workspaceRootURLForTests()
        let sourceURL = root.appendingPathComponent("To Do List/UseCases/LLM/AssistantActionPipelineUseCase.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertFalse(source.contains("DispatchSemaphore"))
        XCTAssertFalse(source.contains(".wait(timeout:"))
    }
}

private final class InMemoryAssistantActionRepository: AssistantActionRepositoryProtocol {
    private var byID: [UUID: AssistantActionRunDefinition] = [:]

    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        byID[run.id] = run
        completion(.success(run))
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        byID[run.id] = run
        completion(.success(run))
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }
}

private final class InMemoryTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private(set) var byID: [UUID: TaskDefinition]
    private(set) var updateCallCount = 0
    var failUpdateOnCall: Int?

    init(seed: [TaskDefinition]) {
        byID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        let filtered = Array(byID.values).filter { task in
            guard let query else { return true }
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let parentTaskID = query.parentTaskID, task.parentTaskID != parentTaskID { return false }
            if let start = query.dueDateStart, let due = task.dueDate, due < start { return false }
            if let end = query.dueDateEnd, let due = task.dueDate, due > end { return false }
            if let searchText = query.searchText?.lowercased(), searchText.isEmpty == false {
                let nameMatch = task.title.lowercased().contains(searchText)
                let detailMatch = task.details?.lowercased().contains(searchText) ?? false
                if !nameMatch && !detailMatch { return false }
            }
            return true
        }
        completion(.success(filtered))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        let task = TaskDefinition(
            id: request.id,
            projectID: request.projectID,
            projectName: request.projectName ?? ProjectConstants.inboxProjectName,
            lifeAreaID: request.lifeAreaID,
            sectionID: request.sectionID,
            parentTaskID: request.parentTaskID,
            title: request.title,
            details: request.details,
            priority: request.priority,
            type: request.type,
            energy: request.energy,
            category: request.category,
            context: request.context,
            dueDate: request.dueDate,
            isComplete: false,
            dateAdded: request.createdAt,
            isEveningTask: request.isEveningTask,
            alertReminderTime: request.alertReminderTime,
            tagIDs: request.tagIDs,
            dependencies: request.dependencies,
            createdAt: request.createdAt,
            updatedAt: request.createdAt
        )
        byID[task.id] = task
        completion(.success(task))
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        updateCallCount += 1
        if failUpdateOnCall == updateCallCount {
            completion(.failure(NSError(domain: "InMemoryTaskDefinitionRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Injected update failure"])))
            return
        }
        byID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        guard var current = byID[request.id] else {
            completion(.failure(NSError(domain: "InMemoryTaskDefinitionRepository", code: 404)))
            return
        }
        if let title = request.title { current.title = title }
        if let details = request.details { current.details = details }
        if let projectID = request.projectID { current.projectID = projectID }
        if request.clearDueDate {
            current.dueDate = nil
        } else if let dueDate = request.dueDate {
            current.dueDate = dueDate
        }
        if let isComplete = request.isComplete { current.isComplete = isComplete }
        if request.dateCompleted != nil || request.isComplete == false { current.dateCompleted = request.dateCompleted }
        current.updatedAt = Date()
        byID[current.id] = current
        completion(.success(current))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values.filter { $0.parentTaskID == parentTaskID })))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        byID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class InMemoryExternalSyncRepository: ExternalSyncRepositoryProtocol {
    var containerMappings: [ExternalContainerMapDefinition] = []
    var itemMappings: [ExternalItemMapDefinition] = []

    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) {
        completion(.success(containerMappings))
    }

    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = containerMappings.firstIndex(where: { $0.id == mapping.id }) {
            containerMappings[index] = mapping
        } else if let index = containerMappings.firstIndex(where: {
            $0.provider == mapping.provider && $0.projectID == mapping.projectID
        }) {
            containerMappings[index] = mapping
        } else {
            containerMappings.append(mapping)
        }
        completion(.success(()))
    }

    func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void
    ) {
        completion(.success(containerMappings.first { $0.provider == provider && $0.projectID == projectID }))
    }

    func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void
    ) {
        let existing = containerMappings.first { $0.provider == provider && $0.projectID == projectID }
        let mutated = mutate(existing)
        saveContainerMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) {
        completion(.success(itemMappings))
    }

    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = itemMappings.firstIndex(where: { $0.id == mapping.id }) {
            itemMappings[index] = mapping
        } else if let index = itemMappings.firstIndex(where: {
            $0.provider == mapping.provider &&
            $0.localEntityType == mapping.localEntityType &&
            $0.localEntityID == mapping.localEntityID
        }) {
            itemMappings[index] = mapping
        } else if let index = itemMappings.firstIndex(where: {
            $0.provider == mapping.provider && $0.externalItemID == mapping.externalItemID
        }) {
            itemMappings[index] = mapping
        } else {
            itemMappings.append(mapping)
        }
        completion(.success(()))
    }

    func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        let existing = itemMappings.first {
            $0.provider == provider && $0.localEntityType == localEntityType && $0.localEntityID == localEntityID
        }
        let mutated = mutate(existing)
        saveItemMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        let existing = itemMappings.first { $0.provider == provider && $0.externalItemID == externalItemID }
        let mutated = mutate(existing)
        saveItemMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func fetchItemMapping(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        completion(.success(itemMappings.first {
            $0.provider == provider && $0.localEntityType == localEntityType && $0.localEntityID == localEntityID
        }))
    }

    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) {
        completion(.success(itemMappings.first { $0.provider == provider && $0.externalItemID == externalItemID }))
    }
}

private final class InMemoryAppleRemindersProvider: AppleRemindersProviderProtocol {
    var requestAccessGranted = true
    var lists: [AppleReminderListSnapshot] = []
    var remindersByListID: [String: [AppleReminderItemSnapshot]] = [:]
    var upsertedSnapshots: [AppleReminderItemSnapshot] = []

    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(requestAccessGranted))
    }

    func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        completion(.success(lists))
    }

    func fetchReminders(listID: String, completion: @escaping (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        completion(.success(remindersByListID[listID] ?? []))
    }

    func upsertReminder(
        listID: String,
        snapshot: AppleReminderItemSnapshot,
        completion: @escaping (Result<AppleReminderItemSnapshot, Error>) -> Void
    ) {
        upsertedSnapshots.append(snapshot)
        var persisted = snapshot
        persisted.lastModifiedAt = snapshot.lastModifiedAt ?? Date()
        var existing = remindersByListID[listID] ?? []
        if let index = existing.firstIndex(where: { $0.itemID == snapshot.itemID }) {
            existing[index] = persisted
        } else {
            existing.append(persisted)
        }
        remindersByListID[listID] = existing
        completion(.success(persisted))
    }

    func deleteReminder(itemID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        for key in remindersByListID.keys {
            remindersByListID[key]?.removeAll(where: { $0.itemID == itemID })
        }
        completion(.success(()))
    }
}

final class LifeAreaIdentityRepairTests: XCTestCase {
    func testLifeAreaRepairMergesDuplicateGeneralAndRepointsProjectTaskHabit() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        let canonicalID = UUID()
        let duplicateID = UUID()

        context.performAndWait {
            _ = makeLifeArea(
                in: context,
                id: canonicalID,
                name: "General",
                color: nil,
                icon: nil,
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 1_000)
            )
            _ = makeLifeArea(
                in: context,
                id: duplicateID,
                name: " general ",
                color: "#4A6FA5",
                icon: "square.grid.2x2",
                isArchived: true,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
            _ = makeProject(in: context, lifeAreaID: duplicateID)
            _ = makeTaskDefinition(in: context, lifeAreaID: duplicateID)
            _ = makeHabitDefinition(in: context, lifeAreaID: duplicateID)
            try? context.save()
        }

        let report = try LifeAreaIdentityRepair.repair(in: context)
        try context.save()

        XCTAssertEqual(report.duplicateGroups, 1)
        XCTAssertEqual(report.merged, 1)
        XCTAssertEqual(report.repointedProjects, 1)
        XCTAssertEqual(report.repointedTasks, 1)
        XCTAssertEqual(report.repointedHabits, 1)

        let lifeAreas = try fetchObjects(entityName: "LifeArea", in: context)
        let general = lifeAreas.filter {
            LifeAreaIdentityRepair.normalizedNameKey($0.value(forKey: "name") as? String) == "general"
        }
        XCTAssertEqual(general.count, 1)
        XCTAssertEqual(general.first?.value(forKey: "id") as? UUID, canonicalID)
        XCTAssertEqual(general.first?.value(forKey: "color") as? String, "#4A6FA5")
        XCTAssertEqual(general.first?.value(forKey: "icon") as? String, "square.grid.2x2")

        let projects = try fetchObjects(entityName: "Project", in: context)
        XCTAssertEqual(projects.first?.value(forKey: "lifeAreaID") as? UUID, canonicalID)
        let tasks = try fetchObjects(entityName: "TaskDefinition", in: context)
        XCTAssertEqual(tasks.first?.value(forKey: "lifeAreaID") as? UUID, canonicalID)
        let habits = try fetchObjects(entityName: "HabitDefinition", in: context)
        XCTAssertEqual(habits.first?.value(forKey: "lifeAreaID") as? UUID, canonicalID)
    }

    func testLifeAreaRepairMergesDuplicateCustomNamesCaseInsensitive() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        let firstID = UUID()
        let secondID = UUID()

        context.performAndWait {
            _ = makeLifeArea(
                in: context,
                id: firstID,
                name: "Work",
                color: "#111111",
                icon: "briefcase",
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 1_500)
            )
            _ = makeLifeArea(
                in: context,
                id: secondID,
                name: " work ",
                color: "#222222",
                icon: "desktopcomputer",
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
            _ = makeProject(in: context, lifeAreaID: secondID)
            _ = makeTaskDefinition(in: context, lifeAreaID: secondID)
            try? context.save()
        }

        let report = try LifeAreaIdentityRepair.repair(in: context)
        try context.save()

        XCTAssertEqual(report.duplicateGroups, 1)
        XCTAssertEqual(report.merged, 1)
        XCTAssertEqual(report.canonicalIDsByNormalizedName["work"], secondID)

        let lifeAreas = try fetchObjects(entityName: "LifeArea", in: context)
        let workAreas = lifeAreas.filter {
            LifeAreaIdentityRepair.normalizedNameKey($0.value(forKey: "name") as? String) == "work"
        }
        XCTAssertEqual(workAreas.count, 1)
        XCTAssertEqual(workAreas.first?.value(forKey: "id") as? UUID, secondID)
    }

    func testLifeAreaRepairFillsMissingNameAndMaintainsSingleGeneral() throws {
        let container = try makeInMemoryV2Container()
        let context = container.viewContext

        let canonicalGeneralID = UUID()

        context.performAndWait {
            _ = makeLifeArea(
                in: context,
                id: canonicalGeneralID,
                name: "General",
                color: "#123456",
                icon: "square.grid.2x2",
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 1_000)
            )
            _ = makeLifeArea(
                in: context,
                id: UUID(),
                name: nil,
                color: nil,
                icon: nil,
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
            _ = makeLifeArea(
                in: context,
                id: UUID(),
                name: "   ",
                color: nil,
                icon: nil,
                isArchived: false,
                createdAt: Date(timeIntervalSince1970: 3_000)
            )
            try? context.save()
        }

        let report = try LifeAreaIdentityRepair.repair(in: context)
        try context.save()

        XCTAssertGreaterThanOrEqual(report.normalized, 2)
        XCTAssertEqual(report.merged, 2)

        let lifeAreas = try fetchObjects(entityName: "LifeArea", in: context)
        let generalAreas = lifeAreas.filter {
            LifeAreaIdentityRepair.normalizedNameKey($0.value(forKey: "name") as? String) == "general"
        }
        XCTAssertEqual(generalAreas.count, 1)
        XCTAssertEqual(generalAreas.first?.value(forKey: "id") as? UUID, canonicalGeneralID)
        XCTAssertEqual(generalAreas.first?.value(forKey: "name") as? String, "General")
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "LifeAreaIdentityRepairTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    @discardableResult
    private func makeLifeArea(
        in context: NSManagedObjectContext,
        id: UUID,
        name: String?,
        color: String?,
        icon: String?,
        isArchived: Bool,
        createdAt: Date
    ) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(name, forKey: "name")
        object.setValue(color, forKey: "color")
        object.setValue(icon, forKey: "icon")
        object.setValue(Int32(0), forKey: "sortOrder")
        object.setValue(isArchived, forKey: "isArchived")
        object.setValue(createdAt, forKey: "createdAt")
        object.setValue(createdAt, forKey: "updatedAt")
        return object
    }

    @discardableResult
    private func makeProject(in context: NSManagedObjectContext, lifeAreaID: UUID) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue("Test Project", forKey: "name")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    @discardableResult
    private func makeTaskDefinition(in context: NSManagedObjectContext, lifeAreaID: UUID) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue("Repair Task", forKey: "title")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    @discardableResult
    private func makeHabitDefinition(in context: NSManagedObjectContext, lifeAreaID: UUID) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "HabitDefinition", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue("Repair Habit", forKey: "title")
        object.setValue("daily", forKey: "habitType")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    private func fetchObjects(
        entityName: String,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.returnsObjectsAsFaults = false
        return try context.fetch(request)
    }
}

final class ManageLifeAreasUseCaseValidationTests: XCTestCase {
    func testManageLifeAreasCreateRejectsDuplicateNormalizedName() {
        let existing = LifeArea(name: "General", color: nil, icon: nil)
        let repository = CapturingLifeAreaRepository(storedAreas: [existing])
        let useCase = ManageLifeAreasUseCase(repository: repository)

        let expectation = expectation(description: "reject duplicate life area")
        useCase.create(name: "  gEnErAl ", color: "#123456", icon: "circle") { result in
            switch result {
            case .success:
                XCTFail("Expected duplicate life area create to fail")
            case .failure(let error):
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, "ManageLifeAreasUseCase")
                XCTAssertEqual(nsError.code, 409)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.createCallCount, 0)
    }
}

final class AddTaskViewModelLifeAreaDedupeTests: XCTestCase {
    func testLoadLifeAreasDedupesSameNameChipsAndKeepsStableSelection() {
        let duplicateGeneralA = LifeArea(id: UUID(), name: "General", color: nil, icon: "square.grid.2x2")
        let duplicateGeneralB = LifeArea(id: UUID(), name: " general ", color: "#111111", icon: "circle")
        let health = LifeArea(id: UUID(), name: "Health", color: "#00AA00", icon: "heart")

        let deferredRepository = DeferredLifeAreaRepository(storedAreas: [duplicateGeneralA, duplicateGeneralB, health])
        let lifeAreasUseCase = ManageLifeAreasUseCase(repository: deferredRepository)

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: lifeAreasUseCase,
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil
        )

        viewModel.selectedLifeAreaID = duplicateGeneralB.id

        let expectation = expectation(description: "life areas loaded")
        deferredRepository.completePendingFetch()
        DispatchQueue.main.async {
            XCTAssertEqual(viewModel.lifeAreas.count, 2)
            XCTAssertEqual(viewModel.selectedLifeAreaID, duplicateGeneralB.id)
            let normalizedNames = Set(viewModel.lifeAreas.map { LifeAreaIdentityRepair.normalizedNameKey($0.name) })
            XCTAssertEqual(normalizedNames, Set(["general", "health"]))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}

final class AddTaskViewModelTagCreationTests: XCTestCase {
    func testCreateTagAddsChipAndSelectsTag() throws {
        let tagRepository = InMemoryTagRepositoryForAddTaskTests()
        let manageTagsUseCase = ManageTagsUseCase(repository: tagRepository)

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: manageTagsUseCase
        )

        let createExpectation = expectation(description: "tag created")
        viewModel.createTag(name: "Errands") { success in
            XCTAssertTrue(success)
            createExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(viewModel.tags.count, 1)
        guard let createdTag = viewModel.tags.first else {
            XCTFail("Expected created tag in view model")
            return
        }
        XCTAssertEqual(createdTag.name, "Errands")
        XCTAssertTrue(viewModel.selectedTagIDs.contains(createdTag.id))

        let reloadedViewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: manageTagsUseCase
        )
        let reloadExpectation = expectation(description: "reloaded tags fetched")
        DispatchQueue.main.async {
            XCTAssertTrue(reloadedViewModel.tags.contains(where: { $0.id == createdTag.id }))
            reloadExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }
}

final class RecurringTaskSeriesMaterializationTests: XCTestCase {
    func testCreateDailyRecurringTaskMaterializesConcreteSeriesWithSharedSeriesID() throws {
        let repository = InMemoryTaskDefinitionRepositoryStub()
        let tagLinkRepository = CapturingTaskTagLinkRepositoryForRecurrenceTests()
        let useCase = CreateTaskDefinitionUseCase(
            repository: repository,
            taskTagLinkRepository: tagLinkRepository,
            taskDependencyRepository: nil
        )

        let startDate = Calendar.current.startOfDay(for: Date())
        let tagID = UUID()
        let request = CreateTaskDefinitionRequest(
            title: "Daily workout",
            details: "Stay consistent",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: startDate,
            tagIDs: [tagID],
            repeatPattern: .daily
        )

        let created = try awaitResult { completion in
            useCase.execute(request: request, completion: completion)
        }

        guard let seriesID = created.recurrenceSeriesID else {
            XCTFail("Expected recurrence series ID on recurring root task")
            return
        }

        let seriesTasks = repository.byID.values
            .filter { $0.recurrenceSeriesID == seriesID }
            .sorted {
                guard let left = $0.dueDate, let right = $1.dueDate else { return $0.id.uuidString < $1.id.uuidString }
                return left < right
            }

        XCTAssertGreaterThan(seriesTasks.count, 1, "Expected concrete future tasks for daily recurring series")
        XCTAssertEqual(seriesTasks.first?.id, created.id)
        XCTAssertTrue(seriesTasks.dropFirst().allSatisfy { $0.repeatPattern == nil })
        XCTAssertTrue(seriesTasks.allSatisfy { Set($0.tagIDs) == Set([tagID]) })

        let calendar = Calendar.current
        let uniqueDays = Set(seriesTasks.compactMap { $0.dueDate }.map { calendar.startOfDay(for: $0) })
        XCTAssertEqual(uniqueDays.count, seriesTasks.count, "Expected one task per day in series")
    }

    func testMaintainRecurringSeriesIsDedupedAcrossRuns() throws {
        let repository = InMemoryTaskDefinitionRepositoryStub()
        let tagLinkRepository = CapturingTaskTagLinkRepositoryForRecurrenceTests()
        let useCase = CreateTaskDefinitionUseCase(
            repository: repository,
            taskTagLinkRepository: tagLinkRepository,
            taskDependencyRepository: nil
        )

        let startDate = Calendar.current.startOfDay(for: Date())
        let request = CreateTaskDefinitionRequest(
            title: "Weekday focus",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: startDate,
            repeatPattern: .weekdays
        )

        let created = try awaitResult { completion in
            useCase.execute(request: request, completion: completion)
        }
        let initialSeriesCount = repository.byID.values.count

        let firstTopUpCount = try awaitResult { completion in
            useCase.maintainRecurringSeries(daysAhead: 45, completion: completion)
        }
        let secondTopUpCount = try awaitResult { completion in
            useCase.maintainRecurringSeries(daysAhead: 45, completion: completion)
        }

        XCTAssertEqual(firstTopUpCount, 0)
        XCTAssertEqual(secondTopUpCount, 0)
        XCTAssertEqual(repository.byID.values.count, initialSeriesCount)

        let seriesTasks = repository.byID.values.filter { $0.recurrenceSeriesID == created.recurrenceSeriesID }
        XCTAssertGreaterThan(seriesTasks.count, 1)
    }
}

final class DeleteTaskDefinitionUseCaseSeriesScopeTests: XCTestCase {
    func testDeleteSingleScopeDeletesOnlyTargetTask() throws {
        let seriesID = UUID()
        let first = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 1")
        let second = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 2")
        let third = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 3")
        let unrelated = TaskDefinition(recurrenceSeriesID: UUID(), title: "Unrelated")
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [first, second, third, unrelated])
        let useCase = DeleteTaskDefinitionUseCase(repository: repository, tombstoneRepository: nil)

        let _: Void = try awaitResult { completion in
            useCase.execute(taskID: second.id, scope: TaskDeleteScope.single, completion: completion)
        }

        let remaining = Set(repository.byID.keys)
        XCTAssertFalse(remaining.contains(second.id))
        XCTAssertTrue(remaining.contains(first.id))
        XCTAssertTrue(remaining.contains(third.id))
        XCTAssertTrue(remaining.contains(unrelated.id))
    }

    func testDeleteSeriesScopeDeletesAllTasksInSeriesOnly() throws {
        let seriesID = UUID()
        let first = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 1")
        let second = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 2")
        let third = TaskDefinition(recurrenceSeriesID: seriesID, title: "Daily 3")
        let unrelated = TaskDefinition(recurrenceSeriesID: UUID(), title: "Unrelated")
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [first, second, third, unrelated])
        let useCase = DeleteTaskDefinitionUseCase(repository: repository, tombstoneRepository: nil)

        let _: Void = try awaitResult { completion in
            useCase.execute(taskID: second.id, scope: TaskDeleteScope.series, completion: completion)
        }

        let remaining = Set(repository.byID.keys)
        XCTAssertFalse(remaining.contains(first.id))
        XCTAssertFalse(remaining.contains(second.id))
        XCTAssertFalse(remaining.contains(third.id))
        XCTAssertTrue(remaining.contains(unrelated.id))
    }
}

private final class InMemoryTagRepositoryForAddTaskTests: TagRepositoryProtocol {
    private(set) var tags: [TagDefinition] = []

    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) {
        completion(.success(tags))
    }

    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) {
        tags.removeAll(where: { $0.id == tag.id })
        tags.append(tag)
        completion(.success(tag))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        tags.removeAll(where: { $0.id == id })
        completion(.success(()))
    }
}

private final class CapturingTaskTagLinkRepositoryForRecurrenceTests: TaskTagLinkRepositoryProtocol {
    private var linksByTaskID: [UUID: Set<UUID>] = [:]

    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) {
        completion(.success(Array(linksByTaskID[taskID] ?? []).sorted { $0.uuidString < $1.uuidString }))
    }

    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        linksByTaskID[taskID] = Set(tagIDs)
        completion(.success(()))
    }
}

private final class CapturingLifeAreaRepository: LifeAreaRepositoryProtocol {
    private(set) var storedAreas: [LifeArea]
    private(set) var createCallCount = 0

    init(storedAreas: [LifeArea]) {
        self.storedAreas = storedAreas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        completion(.success(storedAreas))
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        createCallCount += 1
        storedAreas.append(area)
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class DeferredLifeAreaRepository: LifeAreaRepositoryProtocol {
    private let storedAreas: [LifeArea]
    private var pendingFetchCompletion: ((Result<[LifeArea], Error>) -> Void)?

    init(storedAreas: [LifeArea]) {
        self.storedAreas = storedAreas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        pendingFetchCompletion = completion
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func completePendingFetch() {
        pendingFetchCompletion?(.success(storedAreas))
        pendingFetchCompletion = nil
    }
}

private func workspaceRootURLForTests() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
}

@discardableResult
private func runShellCommand(_ command: String, in directory: URL) throws -> Int32 {
#if os(macOS)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", command]
    process.currentDirectoryURL = directory
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
#else
    _ = command
    _ = directory
    throw NSError(domain: "runShellCommand", code: 501, userInfo: [NSLocalizedDescriptionKey: "Shell commands unavailable on iOS simulator test runtime"])
#endif
}

private extension XCTestCase {
    func awaitResult<T>(
        timeout: TimeInterval = 2.0,
        _ execute: (@escaping (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let expectation = expectation(description: "awaitResult")
        var captured: Result<T, Error>?
        execute { result in
            captured = result
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout)
        return try XCTUnwrap(captured).get()
    }
}

final class TaskDefinitionClearFlagPersistenceTests: XCTestCase {
    func testUpdateRequestClearFlagsRemovePersistedOptionalFields() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)

        let taskID = UUID()
        let lifeAreaID = UUID()
        let sectionID = UUID()
        let dueDate = Date().addingTimeInterval(86_400)
        let reminderTime = Date().addingTimeInterval(43_200)

        _ = try awaitResult { completion in
            repository.create(
                request: CreateTaskDefinitionRequest(
                    id: taskID,
                    title: "Clear me",
                    details: "Has optional metadata",
                    projectID: ProjectConstants.inboxProjectID,
                    projectName: ProjectConstants.inboxProjectName,
                    lifeAreaID: lifeAreaID,
                    sectionID: sectionID,
                    dueDate: dueDate,
                    alertReminderTime: reminderTime,
                    estimatedDuration: 45 * 60,
                    repeatPattern: .daily,
                    createdAt: Date()
                ),
                completion: completion
            )
        }

        _ = try awaitResult { completion in
            repository.update(
                request: UpdateTaskDefinitionRequest(
                    id: taskID,
                    clearLifeArea: true,
                    clearSection: true,
                    clearDueDate: true,
                    clearReminderTime: true,
                    clearEstimatedDuration: true,
                    clearRepeatPattern: true
                ),
                completion: completion
            )
        }

        let updated = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let task = try XCTUnwrap(updated)

        XCTAssertNil(task.lifeAreaID)
        XCTAssertNil(task.sectionID)
        XCTAssertNil(task.dueDate)
        XCTAssertNil(task.alertReminderTime)
        XCTAssertNil(task.estimatedDuration)
        XCTAssertNil(task.repeatPattern)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskDefinitionClearFlagPersistenceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}
