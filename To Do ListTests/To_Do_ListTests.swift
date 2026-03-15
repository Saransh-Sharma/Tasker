//
//  To_Do_ListTests.swift
//  To Do ListTests
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import XCTest
import CoreData
import UserNotifications
import MLXLMCommon
@testable import To_Do_List

final class AppDelegateCloudKitPreflightTests: XCTestCase {

    func testCloudKitMirroringModeDisablesForXCTestConfigurationRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"],
                arguments: [],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "xctest_runtime"))
    }

    func testCloudKitMirroringModeDisablesForInjectedTestHostRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: ["XCInjectBundleInto": "/tmp/This Day.app/This Day"],
                arguments: [],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "xctest_runtime"))
    }

    func testCloudKitMirroringModeDisablesForSimulatorRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: [:],
                arguments: [],
                isSimulator: true
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "simulator_runtime"))
    }

#if DEBUG
    func testCloudKitMirroringModeDisablesForLaunchArgumentOverride() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: [:],
                arguments: ["-TASKER_DISABLE_CLOUDKIT"],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .disabled(reason: "launch_arg_disable_cloudkit"))
    }
#endif

    func testCloudKitMirroringModeEnablesForSupportedRuntime() {
        let appDelegate = AppDelegate()

        let mode = appDelegate.cloudKitMirroringMode(
            context: CloudKitRuntimeContext(
                environment: [:],
                arguments: [],
                isSimulator: false
            )
        )

        XCTAssertEqual(mode, .enabled)
    }
}

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
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(false)) }
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) { completion(.success([])) }
    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) { completion(.success([])) }
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
        self.init(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            gamificationRepository: LegacyNoopGamificationRepository(),
            cacheService: cacheService,
            notificationService: notificationService
        )
    }

    convenience init(
        taskRepository: LegacyTaskRepositoryShim,
        projectRepository: ProjectRepositoryProtocol,
        gamificationRepository: GamificationRepositoryProtocol,
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
            gamificationRepository: gamificationRepository,
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

final class GamificationRemoteChangeClassifierTests: XCTestCase {
    func testClassifiesCloudKitImportTransactions() {
        XCTAssertTrue(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: "com.apple.coredata.cloudkit.import",
                contextName: "NSCloudKitMirroringDelegate.import"
            )
        )
    }

    func testRejectsNonImportOrNonCloudKitTransactions() {
        XCTAssertFalse(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: "tasker.gamification.local",
                contextName: "home.update"
            )
        )
        XCTAssertFalse(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: "com.apple.coredata.cloudkit.export",
                contextName: "NSCloudKitMirroringDelegate.export"
            )
        )
        XCTAssertFalse(
            GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: nil,
                contextName: nil
            )
        )
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

    func testPersistentStoreDescriptionsEnableAutomaticMigrationOptions() throws {
        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("cloudDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)"),
            "Cloud store description must enable automatic migration"
        )
        XCTAssertTrue(
            appDelegateSource.contains("cloudDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)"),
            "Cloud store description must enable inferred mapping migration"
        )
        XCTAssertTrue(
            appDelegateSource.contains("localDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)"),
            "Local store description must enable automatic migration"
        )
        XCTAssertTrue(
            appDelegateSource.contains("localDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)"),
            "Local store description must enable inferred mapping migration"
        )
    }

    func testGamificationStartupReconciliationFailureIsHandledBeforeFollowups() throws {
        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("gamification_startup_reconciliation_failed"),
            "Startup path must log reconciliation failures explicitly"
        )
        XCTAssertTrue(
            appDelegateSource.contains("gamification_startup_streak_update_failed"),
            "Startup path must log follow-up streak update failures"
        )
        let writeSnapshotRange = appDelegateSource.range(of: "engine.writeWidgetSnapshot()")
        let updateStreakRange = appDelegateSource.range(of: "engine.updateStreak { streakResult in")
        XCTAssertNotNil(writeSnapshotRange, "Startup path must write widget snapshot after reconciliation")
        XCTAssertNotNil(updateStreakRange, "Startup path must update streak after successful reconciliation")
        if let writeSnapshotRange, let updateStreakRange {
            XCTAssertLessThan(
                writeSnapshotRange.lowerBound,
                updateStreakRange.lowerBound,
                "Startup path must sequence writeWidgetSnapshot before updateStreak"
            )
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

final class TaskListWidgetSourceContractTests: XCTestCase {
    func testSceneDelegateRestrictsTaskScopesToDocumentedRoutes() throws {
        let source = try loadWorkspaceFile("To Do List/SceneDelegate.swift")
        XCTAssertTrue(
            source.contains("let allowedScopes: Set<String> = [\"today\", \"upcoming\", \"overdue\"]"),
            "SceneDelegate must restrict task scopes to today/upcoming/overdue."
        )
        XCTAssertFalse(
            source.contains("queryItems"),
            "SceneDelegate should not parse URL query mutations for widget routing."
        )
    }

    func testWidgetBundleDoesNotUseActionQueryDeepLinks() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskerWidgetBundle.swift")
        XCTAssertFalse(
            source.contains("?action="),
            "Widget intents must not rely on URL query mutation actions."
        )
    }

    func testWidgetBundleRegistersFullTaskListCatalogKinds() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskerWidgetBundle.swift")
        let expectedKinds = [
            "TopTaskNowWidget", "TodayCounterNextWidget", "OverdueRescueWidget", "QuickWin15mWidget",
            "MorningKickoffWidget", "EveningWrapWidget", "WaitingOnWidget", "InboxTriageWidget",
            "DueSoonRadarWidget", "EnergyMatchWidget", "ProjectSpotlightWidget", "CalendarTaskBridgeWidget",
            "TodayTop3Widget", "NowLaneWidget", "OverdueBoardWidget", "Upcoming48hWidget",
            "MorningEveningPlanWidget", "QuickViewSwitcherWidget", "ProjectSprintWidget",
            "PriorityMatrixLiteWidget", "ContextWidget", "FocusSessionQueueWidget",
            "RecoveryWidget", "DoneReflectionWidget",
            "TodayPlannerBoardWidget", "WeekTaskPlannerWidget", "ProjectCockpitWidget",
            "BacklogHealthWidget", "KanbanLiteWidget", "DeadlineHeatmapWidget",
            "ExecutionDashboardWidget", "DeepWorkAgendaWidget", "AssistantPlanPreviewWidget",
            "LifeAreasBoardWidget",
            "InlineNextTaskWidget", "InlineDueSoonWidget",
            "CircularTodayProgressWidget", "CircularQuickAddWidget",
            "RectangularTop2TasksWidget", "RectangularOverdueAlertWidget",
            "RectangularFocusNowWidget", "RectangularWaitingOnWidget",
            "DeskTodayBoardWidget", "CountdownPanelWidget", "FocusDockWidget",
            "NightlyResetWidget", "MorningBriefPanelWidget", "ProjectPulseWidget"
        ]

        for kind in expectedKinds {
            XCTAssertTrue(
                source.contains("kind: \"\(kind)\""),
                "Widget bundle must include kind \(kind)."
            )
        }
    }

    func testWidgetBundleHasNonEmptyDisplayMetadata() throws {
        let source = try loadWorkspaceFile("TaskerWidgets/TaskerWidgetBundle.swift")
        XCTAssertFalse(source.contains("displayName: \"\""))
        XCTAssertFalse(source.contains("description: \"\""))
    }

    func testRemoteKillSwitchMapsTaskWidgetFlags() throws {
        let source = try loadWorkspaceFile("To Do List/Services/GamificationRemoteKillSwitchService.swift")
        XCTAssertTrue(source.contains("feature_task_list_widgets_enabled"))
        XCTAssertTrue(source.contains("feature_task_list_widgets_interactive_enabled"))
        XCTAssertTrue(source.contains("V2FeatureFlags.taskListWidgetsEnabled"))
        XCTAssertTrue(source.contains("V2FeatureFlags.interactiveTaskWidgetsEnabled"))
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

final class TaskListWidgetSnapshotSchemaTests: XCTestCase {
    func testSnapshotV1PayloadDecodesWithBackwardCompatibleDefaults() throws {
        let json = """
        {
          "updatedAt": "2026-02-28T00:00:00Z",
          "todayTopTasks": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "title": "Legacy Task",
              "priorityCode": "P2",
              "isOverdue": false,
              "energy": "medium",
              "context": "anywhere",
              "isComplete": false,
              "hasDependencies": false
            }
          ],
          "upcomingTasks": [],
          "overdueTasks": [],
          "quickWins": [],
          "projectSlices": [],
          "doneTodayCount": 1,
          "focusNow": [],
          "waitingOn": [],
          "energyBuckets": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(TaskListWidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.todayTopTasks.count, 1)
        XCTAssertEqual(snapshot.openTodayCount, 1)
        XCTAssertTrue(snapshot.openTaskPool.isEmpty)
        XCTAssertTrue(snapshot.completedTodayTasks.isEmpty)
        XCTAssertEqual(snapshot.snapshotHealth.source, "full_query")
    }

    func testSnapshotV2RoundTripPreservesNewFields() throws {
        let now = Date()
        let task = TaskListWidgetTask(
            id: UUID(),
            title: "Round Trip",
            priorityCode: "P1",
            dueDate: now,
            isOverdue: false,
            estimatedDurationMinutes: 20,
            energy: "high",
            context: "computer",
            isComplete: false,
            hasDependencies: false
        )
        let snapshot = TaskListWidgetSnapshot(
            schemaVersion: TaskListWidgetSnapshot.currentSchemaVersion,
            updatedAt: now,
            todayTopTasks: [task],
            upcomingTasks: [],
            overdueTasks: [],
            quickWins: [],
            projectSlices: [],
            doneTodayCount: 2,
            focusNow: [task],
            waitingOn: [],
            energyBuckets: [TaskListWidgetEnergyBucket(energy: "high", count: 1)],
            openTodayCount: 3,
            openTaskPool: [task],
            completedTodayTasks: [],
            snapshotHealth: TaskListWidgetSnapshotHealth(
                source: "unit_test",
                generatedAt: now,
                isStale: false,
                hasCorruptionFallback: true
            )
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TaskListWidgetSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.schemaVersion, TaskListWidgetSnapshot.currentSchemaVersion)
        XCTAssertEqual(decoded.openTodayCount, 3)
        XCTAssertEqual(decoded.openTaskPool.count, 1)
        XCTAssertEqual(decoded.snapshotHealth.source, "unit_test")
        XCTAssertTrue(decoded.snapshotHealth.hasCorruptionFallback)
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
                    if case GamificationRepositoryWriteError.idempotentReplay = error {
                        group.leave()
                        return
                    }
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

    func testSaveXPEventReturnsIdempotentReplayErrorForDuplicateKey() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let idempotencyKey = "xp-dup-\(UUID().uuidString)"

        let first = XPEventDefinition(
            id: UUID(),
            occurrenceID: nil,
            taskID: nil,
            delta: 12,
            reason: "duplicate-test",
            idempotencyKey: idempotencyKey,
            createdAt: Date()
        )
        let second = XPEventDefinition(
            id: UUID(),
            occurrenceID: nil,
            taskID: nil,
            delta: 18,
            reason: "duplicate-test",
            idempotencyKey: idempotencyKey,
            createdAt: Date()
        )

        try awaitResult { completion in
            repository.saveXPEvent(first, completion: completion)
        }

        let duplicateExpectation = expectation(description: "duplicate save result")
        var duplicateResult: Result<Void, Error>?
        repository.saveXPEvent(second) { result in
            duplicateResult = result
            duplicateExpectation.fulfill()
        }
        wait(for: [duplicateExpectation], timeout: 2.0)

        switch duplicateResult {
        case .success?:
            XCTFail("Expected duplicate save to return idempotent replay error")
        case .failure(let error)?:
            guard case GamificationRepositoryWriteError.idempotentReplay(let key) = error else {
                return XCTFail("Expected idempotent replay error, got \(error)")
            }
            XCTAssertEqual(key, idempotencyKey)
        case nil:
            XCTFail("Duplicate save did not complete")
        }

        let storedEvents = try awaitResult { completion in
            repository.fetchXPEvents(completion: completion)
        }
        XCTAssertEqual(storedEvents.filter { $0.idempotencyKey == idempotencyKey }.count, 1)
    }

    func testGamificationReadContextReturnsLatestAggregateImmediatelyAfterWrite() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let dateKey = XPCalculationEngine.periodKey()

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 12,
                    eventCount: 1,
                    updatedAt: Date()
                ),
                completion: completion
            )
        }

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 39,
                    eventCount: 2,
                    updatedAt: Date().addingTimeInterval(1)
                ),
                completion: completion
            )
        }

        let aggregate = try awaitResult { completion in
            repository.fetchDailyAggregate(dateKey: dateKey, completion: completion)
        }
        XCTAssertEqual(aggregate?.totalXP, 39)
        XCTAssertEqual(aggregate?.eventCount, 2)
    }

    func testSaveDailyAggregateUpdatesWhenOnlyUpdatedAtChanges() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let dateKey = XPCalculationEngine.periodKey()
        let initialUpdatedAt = Date()
        let newerUpdatedAt = initialUpdatedAt.addingTimeInterval(30)

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 25,
                    eventCount: 3,
                    updatedAt: initialUpdatedAt
                ),
                completion: completion
            )
        }

        try awaitResult { completion in
            repository.saveDailyAggregate(
                DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 25,
                    eventCount: 3,
                    updatedAt: newerUpdatedAt
                ),
                completion: completion
            )
        }

        let aggregate = try awaitResult { completion in
            repository.fetchDailyAggregate(dateKey: dateKey, completion: completion)
        }
        XCTAssertEqual(aggregate?.updatedAt, newerUpdatedAt)
    }

    func testGamificationModelDefinesUniquenessConstraintsForXPEventAndDailyAggregate() throws {
        let container = try makeInMemoryV2Container()
        let model = container.managedObjectModel

        guard let xpEventEntity = model.entitiesByName["XPEvent"] else {
            return XCTFail("Expected XPEvent entity in model")
        }
        guard let dailyAggregateEntity = model.entitiesByName["DailyXPAggregate"] else {
            return XCTFail("Expected DailyXPAggregate entity in model")
        }

        let xpEventConstraints = normalizedUniquenessConstraints(for: xpEventEntity)
        let dailyAggregateConstraints = normalizedUniquenessConstraints(for: dailyAggregateEntity)

        XCTAssertTrue(
            xpEventConstraints.contains(["idempotencyKey"]),
            "XPEvent must enforce uniqueness on idempotencyKey"
        )
        XCTAssertTrue(
            dailyAggregateConstraints.contains(["dateKey"]),
            "DailyXPAggregate must enforce uniqueness on dateKey"
        )
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

    private func normalizedUniquenessConstraints(for entity: NSEntityDescription) -> Set<Set<String>> {
        Set(entity.uniquenessConstraints.map { rawConstraint in
            Set(rawConstraint.compactMap { $0 as? String })
        })
    }
}

final class FocusSessionUseCaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearPersistedFocusSessionKeys()
    }

    override func tearDown() {
        clearPersistedFocusSessionKeys()
        super.tearDown()
    }

    func testStartSessionFailsWhenUnfinishedSessionAlreadyExists() {
        let repository = FocusSessionRepositorySpy()
        repository.focusSessions = [
            FocusSessionDefinition(
                id: UUID(),
                taskID: UUID(),
                startedAt: Date().addingTimeInterval(-300),
                endedAt: nil,
                durationSeconds: 0,
                targetDurationSeconds: 25 * 60,
                wasCompleted: false,
                xpAwarded: 0
            )
        ]
        let useCase = FocusSessionUseCase(repository: repository, engine: GamificationEngine(repository: repository))

        let expectation = expectation(description: "start-session-fails-already-active")
        useCase.startSession(taskID: nil, targetDurationSeconds: 25 * 60) { result in
            switch result {
            case .success:
                XCTFail("Expected startSession to fail when an unfinished session exists")
            case .failure(let error):
                guard let focusError = error as? FocusSessionError else {
                    return XCTFail("Expected FocusSessionError.alreadyActive but got \(error)")
                }
                if case .alreadyActive = focusError {
                    // expected
                } else {
                    XCTFail("Expected alreadyActive, got \(focusError)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.createFocusSessionCallCount, 0)
    }

    func testStartSessionCreatesSessionWhenNoUnfinishedSessionExists() throws {
        let repository = FocusSessionRepositorySpy()
        repository.focusSessions = [
            FocusSessionDefinition(
                id: UUID(),
                taskID: UUID(),
                startedAt: Date().addingTimeInterval(-1_800),
                endedAt: Date().addingTimeInterval(-1_200),
                durationSeconds: 600,
                targetDurationSeconds: 25 * 60,
                wasCompleted: false,
                xpAwarded: 10
            )
        ]
        let useCase = FocusSessionUseCase(repository: repository, engine: GamificationEngine(repository: repository))

        let createdSession = try awaitResult { completion in
            useCase.startSession(taskID: nil, targetDurationSeconds: 20 * 60, completion: completion)
        }

        XCTAssertEqual(repository.createFocusSessionCallCount, 1)
        XCTAssertEqual(repository.createdSessions.first?.id, createdSession.id)
        XCTAssertEqual(repository.createdSessions.first?.targetDurationSeconds, 20 * 60)
    }

    private func clearPersistedFocusSessionKeys() {
        UserDefaults.standard.removeObject(forKey: "focusSessionActiveID")
        UserDefaults.standard.removeObject(forKey: "focusSessionStartedAt")
        UserDefaults.standard.removeObject(forKey: "focusSessionTaskID")
        UserDefaults.standard.removeObject(forKey: "focusSessionTargetSeconds")
    }
}

private final class FocusSessionRepositorySpy: GamificationRepositoryProtocol {
    var focusSessions: [FocusSessionDefinition] = []
    private(set) var createFocusSessionCallCount = 0
    private(set) var createdSessions: [FocusSessionDefinition] = []

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) { completion(.success(nil)) }
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(false)) }
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) { completion(.success([])) }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        createFocusSessionCallCount += 1
        createdSessions.append(session)
        focusSessions.append(session)
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = focusSessions.firstIndex(where: { $0.id == session.id }) {
            focusSessions[index] = session
        } else {
            focusSessions.append(session)
        }
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        let filtered = focusSessions.filter { $0.startedAt >= startDate && $0.startedAt < endDate }
        completion(.success(filtered))
    }
}

final class HomeViewModelFocusSessionThreadingTests: XCTestCase {
    func testStartFocusSessionCompletionIsDeliveredOnMainQueue() {
        let suiteName = "HomeViewModelFocusSessionThreadingTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let inbox = Project.createInbox()
        let seedTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Focus threading",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let taskRepository = MockTaskRepository(seed: seedTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            gamificationRepository: BackgroundFocusSessionRepository()
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        let completionExpectation = expectation(description: "focus session completion")
        var completionOnMainThread = false
        viewModel.startFocusSession(taskID: nil, targetDurationSeconds: 60) { result in
            completionOnMainThread = Thread.isMainThread
            if case .failure(let error) = result {
                XCTFail("Expected successful start session, got \(error)")
            }
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
        XCTAssertTrue(completionOnMainThread)
    }
}

private final class BackgroundFocusSessionRepository: GamificationRepositoryProtocol {
    private let callbackQueue = DispatchQueue(label: "BackgroundFocusSessionRepository.callback")

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        completion(.success(nil))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        completion(.success(nil))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        callbackQueue.async {
            completion(.success(()))
        }
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        callbackQueue.async {
            completion(.success([]))
        }
    }
}

final class GamificationEngineMutationOrderingTests: XCTestCase {
    func testRecordEventEmitsLedgerMutationWithUpdatedStreak() throws {
        let repository = InMemoryGamificationEngineRepository()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        repository.profile = GamificationSnapshot(
            xpTotal: 0,
            level: 1,
            currentStreak: 0,
            bestStreak: 0,
            lastActiveDate: yesterday,
            updatedAt: Date(),
            gamificationV2ActivatedAt: nil,
            nextLevelXP: 100,
            returnStreak: 0,
            bestReturnStreak: 0
        )

        let engine = GamificationEngine(repository: repository)
        let taskID = UUID()
        var observedMutation: GamificationLedgerMutation?
        let mutationExpectation = expectation(description: "ledger mutation")
        let completionExpectation = expectation(description: "record completion")
        var capturedResult: Result<XPEventResult, Error>?
        let token = NotificationCenter.default.addObserver(
            forName: .gamificationLedgerDidMutate,
            object: nil,
            queue: .main
        ) { notification in
            guard let mutation = notification.gamificationLedgerMutation else { return }
            guard mutation.category == .complete else { return }
            observedMutation = mutation
            mutationExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(token)
        }

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: taskID,
                completedAt: Date(),
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [mutationExpectation, completionExpectation], timeout: 2.0)
        let result = try XCTUnwrap(capturedResult).get()
        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(observedMutation?.streakDays, 1)
        XCTAssertEqual(observedMutation?.didChange, true)
    }

    func testRecordEventRecoversWhenDailyAggregateWriteFailsAfterEventSave() throws {
        let repository = InMemoryGamificationEngineRepository()
        repository.failNextDailyAggregateSave = true
        let engine = GamificationEngine(repository: repository)

        let completedAt = Date()
        let dateKey = XPCalculationEngine.periodKey(for: completedAt)
        var observedMutation: GamificationLedgerMutation?
        var capturedResult: Result<XPEventResult, Error>?
        let mutationExpectation = expectation(description: "recovery mutation")
        let completionExpectation = expectation(description: "record completion")

        let token = NotificationCenter.default.addObserver(
            forName: .gamificationLedgerDidMutate,
            object: nil,
            queue: .main
        ) { notification in
            guard let mutation = notification.gamificationLedgerMutation else { return }
            guard mutation.category == .complete else { return }
            observedMutation = mutation
            mutationExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(token)
        }

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                completedAt: completedAt,
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [mutationExpectation, completionExpectation], timeout: 3.0)

        let result = try XCTUnwrap(capturedResult).get()
        XCTAssertGreaterThan(result.awardedXP, 0)
        XCTAssertTrue(observedMutation?.didChange ?? false)

        let aggregate = try awaitResult { completion in
            repository.fetchDailyAggregate(dateKey: dateKey, completion: completion)
        }
        XCTAssertEqual(aggregate?.totalXP, result.dailyXPSoFar)
        XCTAssertEqual(aggregate?.eventCount, 1)
    }

    func testFullReconciliationSkipsNoOpWritesWhenLedgerAlreadyCanonical() {
        let repository = InMemoryGamificationEngineRepository()
        let now = Date()
        let dateKey = XPCalculationEngine.periodKey(for: now)
        repository.seed(events: [
            XPEventDefinition(
                id: UUID(),
                taskID: UUID(),
                delta: 18,
                reason: "task_completion",
                idempotencyKey: "reconcile.noop.1",
                createdAt: now,
                category: .complete,
                source: .manual,
                qualityWeight: 1.0,
                periodKey: dateKey
            )
        ])

        let engine = GamificationEngine(repository: repository)

        let firstPass = expectation(description: "first reconciliation")
        engine.fullReconciliation { result in
            if case .failure(let error) = result {
                XCTFail("Expected first reconciliation to succeed, got error: \(error)")
            }
            firstPass.fulfill()
        }
        wait(for: [firstPass], timeout: 2.0)

        repository.resetWriteCounters()

        let secondPass = expectation(description: "second reconciliation")
        engine.fullReconciliation { result in
            if case .failure(let error) = result {
                XCTFail("Expected second reconciliation to succeed, got error: \(error)")
            }
            secondPass.fulfill()
        }
        wait(for: [secondPass], timeout: 2.0)

        XCTAssertEqual(repository.saveProfileCount, 0, "Second reconciliation should skip unchanged profile write")
        XCTAssertEqual(repository.saveDailyAggregateCount, 0, "Second reconciliation should skip unchanged daily aggregate writes")
    }

    func testRecordEventTreatsIdempotentReplaySaveErrorAsSuccessWithoutMutation() {
        let repository = InMemoryGamificationEngineRepository()
        let now = Date()
        let dateKey = XPCalculationEngine.periodKey(for: now)
        let seededProfile = GamificationSnapshot(
            xpTotal: 220,
            level: 4,
            currentStreak: 5,
            bestStreak: 8,
            lastActiveDate: now,
            updatedAt: now,
            gamificationV2ActivatedAt: nil,
            nextLevelXP: 300,
            returnStreak: 0,
            bestReturnStreak: 0
        )
        repository.seed(
            profile: seededProfile,
            dailyAggregates: [
                dateKey: DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 40,
                    eventCount: 2,
                    updatedAt: now
                )
            ]
        )
        repository.hasXPEventOverride = false
        repository.failNextSaveXPEventError = GamificationRepositoryWriteError.idempotentReplay(idempotencyKey: "forced.replay")

        let engine = GamificationEngine(repository: repository)
        let completionExpectation = expectation(description: "record completion")
        let mutationExpectation = expectation(description: "ledger mutation")
        var capturedResult: Result<XPEventResult, Error>?
        var observedMutation: GamificationLedgerMutation?

        let token = NotificationCenter.default.addObserver(
            forName: .gamificationLedgerDidMutate,
            object: nil,
            queue: .main
        ) { notification in
            guard let mutation = notification.gamificationLedgerMutation else { return }
            guard mutation.category == .complete else { return }
            observedMutation = mutation
            mutationExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                completedAt: now,
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [mutationExpectation, completionExpectation], timeout: 2.0)
        let result = try? XCTUnwrap(capturedResult).get()

        XCTAssertEqual(result?.awardedXP, 0)
        XCTAssertEqual(result?.totalXP, seededProfile.xpTotal)
        XCTAssertEqual(result?.dailyXPSoFar, 40)
        XCTAssertEqual(observedMutation?.didChange, false)
        XCTAssertEqual(repository.saveProfileCount, 0)
        XCTAssertEqual(repository.saveDailyAggregateCount, 0)
    }

    func testRecordEventHandlesConcurrentAchievementUnlockCallbacks() throws {
        let repository = InMemoryGamificationEngineRepository()
        repository.concurrentUnlockCallbacks = true
        repository.profile = GamificationSnapshot(
            xpTotal: 95,
            level: 1,
            currentStreak: 0,
            bestStreak: 0,
            lastActiveDate: Date(),
            updatedAt: Date(),
            gamificationV2ActivatedAt: nil,
            nextLevelXP: 100,
            returnStreak: 0,
            bestReturnStreak: 0
        )
        let engine = GamificationEngine(repository: repository)
        let completionExpectation = expectation(description: "record completion")
        var capturedResult: Result<XPEventResult, Error>?

        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                completedAt: Date(),
                priority: 2
            )
        ) { result in
            capturedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)
        let result = try XCTUnwrap(capturedResult).get()
        let unlocked = Set(result.unlockedAchievements.map(\.achievementKey))
        XCTAssertTrue(unlocked.contains("first_step"))
        XCTAssertTrue(unlocked.contains("xp_100"))
    }
}

private final class InMemoryGamificationEngineRepository: GamificationRepositoryProtocol {
    private let lock = NSLock()
    var profile: GamificationSnapshot?
    private var events: [XPEventDefinition] = []
    private var dailyAggregates: [String: DailyXPAggregateDefinition] = [:]
    private var unlocks: [AchievementUnlockDefinition] = []
    private var focusSessions: [FocusSessionDefinition] = []
    private(set) var saveProfileCount = 0
    private(set) var saveDailyAggregateCount = 0
    var failNextDailyAggregateSave = false
    var failNextSaveXPEventError: Error?
    var hasXPEventOverride: Bool?
    var concurrentUnlockCallbacks = false

    func seed(
        profile: GamificationSnapshot? = nil,
        events: [XPEventDefinition] = [],
        dailyAggregates: [String: DailyXPAggregateDefinition] = [:]
    ) {
        lock.lock()
        self.profile = profile
        self.events = events
        self.dailyAggregates = dailyAggregates
        lock.unlock()
    }

    func resetWriteCounters() {
        lock.lock()
        saveProfileCount = 0
        saveDailyAggregateCount = 0
        lock.unlock()
    }

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        lock.lock()
        let snapshot = profile
        lock.unlock()
        completion(.success(snapshot))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        self.profile = profile
        saveProfileCount += 1
        lock.unlock()
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        let current = events
        lock.unlock()
        completion(.success(current))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        let filtered = events.filter { $0.createdAt >= startDate && $0.createdAt < endDate }
        lock.unlock()
        completion(.success(filtered))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        if let injectedError = failNextSaveXPEventError {
            failNextSaveXPEventError = nil
            lock.unlock()
            completion(.failure(injectedError))
            return
        }
        if events.contains(where: { $0.idempotencyKey == event.idempotencyKey }) == false {
            events.append(event)
        }
        lock.unlock()
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        lock.lock()
        if let override = hasXPEventOverride {
            lock.unlock()
            completion(.success(override))
            return
        }
        let exists = events.contains { $0.idempotencyKey == idempotencyKey }
        lock.unlock()
        completion(.success(exists))
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        lock.lock()
        let current = unlocks
        lock.unlock()
        completion(.success(current))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        let write = {
            self.lock.lock()
            if self.unlocks.contains(where: { $0.achievementKey == unlock.achievementKey }) == false {
                self.unlocks.append(unlock)
            }
            self.lock.unlock()
            completion(.success(()))
        }
        if concurrentUnlockCallbacks {
            DispatchQueue.global(qos: .userInitiated).async(execute: write)
            return
        }
        write()
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        lock.lock()
        let aggregate = dailyAggregates[dateKey]
        lock.unlock()
        completion(.success(aggregate))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        if failNextDailyAggregateSave {
            failNextDailyAggregateSave = false
            lock.unlock()
            completion(.failure(NSError(
                domain: "InMemoryGamificationEngineRepository",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Injected saveDailyAggregate failure"]
            )))
            return
        }
        dailyAggregates[aggregate.dateKey] = aggregate
        saveDailyAggregateCount += 1
        lock.unlock()
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        lock.lock()
        let values = dailyAggregates.values
            .filter { $0.dateKey >= startDateKey && $0.dateKey <= endDateKey }
            .sorted { $0.dateKey < $1.dateKey }
        lock.unlock()
        completion(.success(values))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        focusSessions.append(session)
        lock.unlock()
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        if let index = focusSessions.firstIndex(where: { $0.id == session.id }) {
            focusSessions[index] = session
        } else {
            focusSessions.append(session)
        }
        lock.unlock()
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        lock.lock()
        let current = focusSessions.filter { $0.startedAt >= startDate && $0.startedAt < endDate }
        lock.unlock()
        completion(.success(current))
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

@MainActor
final class AddTaskViewModelAISuggestionPerformanceTests: XCTestCase {
    override func tearDown() {
        V2FeatureFlags.assistantCopilotEnabled = true
        UserDefaults.standard.removeObject(forKey: "currentModelName")
        UserDefaults.standard.removeObject(forKey: "installedModels")
        super.tearDown()
    }

    func testDeferredRefineKeepsInstantSuggestionWhenRuntimeIsCold() {
        V2FeatureFlags.assistantCopilotEnabled = true

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        var refineInvocationCount = 0
        let aiSuggestionService = AISuggestionService(
            llm: LLMEvaluator(),
            generateOutput: { _, _, _, _, _ in
                refineInvocationCount += 1
                return """
                {"priority":"high","energy":"high","type":"morning","context":"computer","rationale":"refined","confidence":0.9}
                """
            }
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil,
            gamificationEngine: nil,
            aiSuggestionService: aiSuggestionService,
            isAISuggestionRefinementReady: { false }
        )

        let expectation = expectation(description: "heuristic suggestion surfaced")
        viewModel.taskName = "call pharmacy before lunch"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            XCTAssertEqual(refineInvocationCount, 0)
            XCTAssertNotNil(viewModel.aiSuggestion)
            XCTAssertNil(viewModel.aiSuggestion?.modelName)
            XCTAssertFalse(viewModel.aiSuggestionIsRefined)
            XCTAssertFalse(viewModel.isGeneratingSuggestion)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.5)
    }

    func testRapidTypingCancelsStaleRefineBeforePublishing() {
        V2FeatureFlags.assistantCopilotEnabled = true
        configureInstalledModels([ModelConfiguration.qwen_3_0_6b_4bit.name])

        let manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let createTaskUseCase = CreateTaskDefinitionUseCase(
            repository: NoopTaskDefinitionRepository(),
            taskTagLinkRepository: nil,
            taskDependencyRepository: nil
        )

        let aiSuggestionService = AISuggestionService(
            llm: LLMEvaluator(),
            generateOutput: { _, thread, _, _, _ in
                let prompt = thread.messages.first?.content ?? ""
                if prompt.contains("draft weekly plan for team sync") {
                    try? await _Concurrency.Task.sleep(nanoseconds: 600_000_000)
                    return """
                    {"priority":"high","energy":"high","type":"morning","context":"computer","rationale":"stale-first","confidence":0.9}
                    """
                }

                try? await _Concurrency.Task.sleep(nanoseconds: 120_000_000)
                return """
                {"priority":"low","energy":"medium","type":"evening","context":"anywhere","rationale":"latest-second","confidence":0.7}
                """
            }
        )

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: nil,
            manageProjectsUseCase: manageProjectsUseCase,
            createTaskDefinitionUseCase: createTaskUseCase,
            rescheduleTaskDefinitionUseCase: nil,
            manageLifeAreasUseCase: nil,
            manageSectionsUseCase: nil,
            manageTagsUseCase: nil,
            gamificationEngine: nil,
            aiSuggestionService: aiSuggestionService,
            isAISuggestionRefinementReady: { true }
        )

        let expectation = expectation(description: "latest refined suggestion wins")
        viewModel.taskName = "draft weekly plan for team sync"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            viewModel.taskName = "call dentist after standup"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            XCTAssertEqual(viewModel.taskName, "call dentist after standup")
            XCTAssertEqual(viewModel.aiSuggestion?.rationale, "latest-second")
            XCTAssertEqual(viewModel.aiSuggestion?.type, .evening)
            XCTAssertTrue(viewModel.aiSuggestionIsRefined)
            XCTAssertFalse(viewModel.isGeneratingSuggestion)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.5)
    }

    private func configureInstalledModels(_ models: [String]) {
        let data = try? JSONEncoder().encode(models)
        UserDefaults.standard.set(data, forKey: "installedModels")
        UserDefaults.standard.removeObject(forKey: "currentModelName")
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

private final class CountingTaskDefinitionRepositorySpy: TaskDefinitionRepositoryProtocol {
    private let base: InMemoryTaskDefinitionRepositoryStub
    private(set) var fetchAllInvocationCount = 0

    init(seed: [TaskDefinition] = []) {
        self.base = InMemoryTaskDefinitionRepositoryStub(seed: seed)
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAllInvocationCount += 1
        base.fetchAll(completion: completion)
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAllInvocationCount += 1
        base.fetchAll(query: query, completion: completion)
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        base.fetchTaskDefinition(id: id, completion: completion)
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.create(task, completion: completion)
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.create(request: request, completion: completion)
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.update(task, completion: completion)
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        base.update(request: request, completion: completion)
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        base.delete(id: id, completion: completion)
    }
}

final class TaskNotificationOrchestratorTests: XCTestCase {
    func testReconcileCoalescesBurstReasonsIntoSingleFetchPass() {
        let notificationService = CapturingNotificationService()
        let repository = CountingTaskDefinitionRepositorySpy(seed: [])
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate },
            reconcileDebounceInterval: 0.05
        )

        let expectation = expectation(description: "coalesced reconcile finished")
        orchestrator.reconcile(reason: "scene_active")
        orchestrator.reconcile(reason: "scene_foreground")
        orchestrator.reconcile(reason: "scene_background")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(repository.fetchAllInvocationCount, 1)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testDailyNotificationsUseDefaultTimesAndFallbackCopy() {
        let notificationService = CapturingNotificationService()
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [])
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test")

        let morningIDs = Set(
            notificationService.scheduled
                .filter { $0.kind == .morningPlan }
                .map(\.id)
        )
        XCTAssertEqual(
            morningIDs,
            Set(["daily.morning.20260224", "daily.morning.20260225", "daily.morning.20260226"])
        )

        let morning = notificationService.scheduled.first(where: { $0.id == "daily.morning.20260224" })
        XCTAssertEqual(morning?.title, "Morning Plan")
        XCTAssertEqual(morning?.body, "No tasks queued. Capture one meaningful win.")
        XCTAssertEqual(morning.map { calendar.component(.hour, from: $0.fireDate) }, 8)
        XCTAssertEqual(morning.map { calendar.component(.minute, from: $0.fireDate) }, 0)
        XCTAssertEqual(
            morning?.route,
            .dailySummary(kind: .morning, dateStamp: "20260224")
        )

        let nightlySummaryIDs = Set(
            notificationService.scheduled
                .map(\.id)
                .filter { $0.hasPrefix("daily.nightly.") }
        )
        XCTAssertEqual(
            nightlySummaryIDs,
            Set(["daily.nightly.20260224", "daily.nightly.20260225", "daily.nightly.20260226"])
        )

        let reflectionIDs = Set(
            notificationService.scheduled
                .map(\.id)
                .filter { $0.hasPrefix("daily.reflection.") }
        )
        XCTAssertEqual(
            reflectionIDs,
            Set([
                "daily.reflection.20260224.evening",
                "daily.reflection.20260224.followup",
                "daily.reflection.20260225.evening",
                "daily.reflection.20260225.followup",
                "daily.reflection.20260226.evening",
                "daily.reflection.20260226.followup"
            ])
        )

        let nightly = notificationService.scheduled.first(where: { $0.id == "daily.nightly.20260224" })
        XCTAssertEqual(nightly?.title, "Day Retrospective")
        XCTAssertEqual(nightly?.body, "No completions today. Pick one tiny restart for tomorrow.")
        XCTAssertEqual(nightly.map { calendar.component(.hour, from: $0.fireDate) }, 21)
        XCTAssertEqual(nightly.map { calendar.component(.minute, from: $0.fireDate) }, 0)
        XCTAssertEqual(
            nightly?.route,
            .dailySummary(kind: .nightly, dateStamp: "20260224")
        )
    }

    func testNightlyRetrospectiveUsesExactLedgerXPWhenAvailable() {
        let notificationService = CapturingNotificationService()
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let completionDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 18, minute: 45)

        var completedTask = TaskDefinition(title: "Ship release notes", priority: .high, isComplete: true)
        completedTask.dueDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 17, minute: 0)
        completedTask.dateCompleted = completionDate

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [completedTask])
        let store = makePreferencesStore()
        let gamificationRepository = InsightsRepositorySpy()
        gamificationRepository.weekAggregates = [
            DailyXPAggregateDefinition(dateKey: "2026-02-24", totalXP: 44, eventCount: 2)
        ]

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            gamificationRepository: gamificationRepository,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_exact_xp")

        let nightly = notificationService.scheduled.first(where: { $0.id == "daily.nightly.20260224" })
        XCTAssertEqual(
            nightly?.body,
            "Completed 1/1 tasks, earned 44 XP. Biggest win: \"Ship release notes\"."
        )
    }

    func testNightlyRetrospectiveOmitsNumericXPWhenExactAggregateUnavailable() {
        let notificationService = CapturingNotificationService()
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let completionDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 19, minute: 10)

        var completedTask = TaskDefinition(title: "Close loops", priority: .low, isComplete: true)
        completedTask.dueDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 18, minute: 0)
        completedTask.dateCompleted = completionDate

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [completedTask])
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_no_exact_xp")

        let nightly = notificationService.scheduled.first(where: { $0.id == "daily.nightly.20260224" })
        XCTAssertEqual(
            nightly?.body,
            "Completed 1/1 tasks. Biggest win: \"Close loops\". Open Tasker for exact XP."
        )
    }

    func testReconcileSchedulesTaskReminderDueSoonAndOverdueWithExpectedContent() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var reminderTask = TaskDefinition(title: "Write report")
        reminderTask.dueDate = nowDate.addingTimeInterval(3 * 3600)
        reminderTask.alertReminderTime = nowDate.addingTimeInterval(5 * 60)

        var dueSoonPrimary = TaskDefinition(title: "Send status update", priority: .high)
        dueSoonPrimary.dueDate = nowDate.addingTimeInterval(45 * 60)

        var dueSoonSecondary = TaskDefinition(title: "Check inbox", priority: .low)
        dueSoonSecondary.dueDate = nowDate.addingTimeInterval(90 * 60)

        var overdue = TaskDefinition(title: "Submit invoice", priority: .max)
        overdue.dueDate = nowDate.addingTimeInterval(-26 * 3600)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [reminderTask, dueSoonPrimary, dueSoonSecondary, overdue])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test")

        let reminderID = "task.reminder.\(reminderTask.id.uuidString)"
        let reminder = notificationService.scheduled.first(where: { $0.id == reminderID })
        XCTAssertEqual(
            reminder?.title,
            "Task Reminder"
        )
        XCTAssertEqual(reminder?.route, .taskDetail(taskID: reminderTask.id))

        let dueSoonID = "task.dueSoon.\(dueSoonPrimary.id.uuidString).20260224"
        let dueSoon = notificationService.scheduled.first(where: { $0.id == dueSoonID })
        let dueSoonBody = dueSoon?.body ?? ""
        XCTAssertTrue(dueSoonBody.contains("\"Send status update\" is due in"))
        XCTAssertTrue(dueSoonBody.contains("+ 1 more due soon"))
        XCTAssertEqual(notificationService.scheduled.filter { $0.kind == .dueSoon }.count, 1)
        XCTAssertEqual(dueSoon?.route, .taskDetail(taskID: dueSoonPrimary.id))

        let overdueAMID = "task.overdue.\(overdue.id.uuidString).20260224.am"
        let overdueAM = notificationService.scheduled.first(where: { $0.id == overdueAMID })
        let overdueBody = overdueAM?.body ?? ""
        XCTAssertEqual(overdueBody, "\"Submit invoice\" is overdue by 1 day(s).")
        XCTAssertEqual(overdueAM?.route, .taskDetail(taskID: overdue.id))

        let overdueTomorrowAMID = "task.overdue.\(overdue.id.uuidString).20260225.am"
        let overdueTomorrowPMID = "task.overdue.\(overdue.id.uuidString).20260225.pm"
        XCTAssertEqual(
            notificationService.scheduled.first(where: { $0.id == overdueTomorrowAMID })?.route,
            .taskDetail(taskID: overdue.id)
        )
        XCTAssertEqual(
            notificationService.scheduled.first(where: { $0.id == overdueTomorrowPMID })?.route,
            .taskDetail(taskID: overdue.id)
        )
    }

    func testReconcileCancelsStaleManagedIdentifiersAndKeepsUnmanagedOnes() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 12, minute: 0)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [])
        let notificationService = CapturingNotificationService()
        notificationService.pending = [
            TaskerPendingNotificationRequest(id: "task.reminder.\(UUID().uuidString)", fireDate: nil, kind: .taskReminder),
            TaskerPendingNotificationRequest(id: "task.snooze.task.reminder.\(UUID().uuidString).1772000000", fireDate: nil, kind: .snoozedTask),
            TaskerPendingNotificationRequest(id: "daily.morning.20260224", fireDate: nil, kind: .morningPlan),
            TaskerPendingNotificationRequest(id: "external.alert.keep", fireDate: nil, kind: nil)
        ]

        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: false,
                dueSoonEnabled: false,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: false,
                nightlyRetrospectiveEnabled: false
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test")

        XCTAssertTrue(notificationService.canceledIDs.contains(where: { $0.hasPrefix("task.reminder.") }))
        XCTAssertTrue(notificationService.canceledIDs.contains(where: { $0.hasPrefix("task.snooze.") }))
        XCTAssertTrue(notificationService.canceledIDs.contains("daily.morning.20260224"))
        XCTAssertFalse(notificationService.canceledIDs.contains("external.alert.keep"))
    }

    func testReconcileDoesNotRescheduleUnchangedPendingRequests() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var task = TaskDefinition(title: "Write report")
        task.dueDate = nowDate.addingTimeInterval(3 * 3600)
        task.alertReminderTime = nowDate.addingTimeInterval(5 * 60)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "first")
        let firstScheduleCalls = notificationService.scheduleInvocationIDs.count

        orchestrator.reconcile(reason: "second_same_state")

        XCTAssertEqual(notificationService.scheduleInvocationIDs.count, firstScheduleCalls)
        XCTAssertTrue(notificationService.canceledIDs.isEmpty)
    }

    func testReconcileReschedulesWhenPendingRequestFingerprintChanges() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var task = TaskDefinition(title: "Write report")
        task.dueDate = nowDate.addingTimeInterval(3 * 3600)
        task.alertReminderTime = nowDate.addingTimeInterval(5 * 60)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        let reminderID = "task.reminder.\(task.id.uuidString)"

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "first")
        let firstScheduleCalls = notificationService.scheduleInvocationIDs.count

        notificationService.pending = notificationService.pending.map { pending in
            guard pending.id == reminderID else { return pending }
            return TaskerPendingNotificationRequest(
                id: pending.id,
                fireDate: pending.fireDate?.addingTimeInterval(60),
                kind: pending.kind,
                title: pending.title,
                body: "\(pending.body) stale",
                categoryIdentifier: pending.categoryIdentifier,
                routePayload: pending.routePayload,
                taskID: pending.taskID
            )
        }

        orchestrator.reconcile(reason: "changed_pending")

        XCTAssertEqual(notificationService.scheduleInvocationIDs.count, firstScheduleCalls + 1)
        XCTAssertTrue(notificationService.canceledIDs.contains(reminderID))
    }

    func testDueSoonUsesConfiguredLeadMinutes() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 30)

        var dueSoonTask = TaskDefinition(title: "Prepare status deck", priority: .high)
        dueSoonTask.dueDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 10, minute: 0)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [dueSoonTask])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: false,
                dueSoonEnabled: true,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: false,
                nightlyRetrospectiveEnabled: false,
                dueSoonLeadMinutes: 60
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_due_soon_lead")

        guard let dueSoon = notificationService.scheduled.first(where: { $0.kind == .dueSoon }) else {
            return XCTFail("Expected due soon notification")
        }
        XCTAssertEqual(calendar.component(.hour, from: dueSoon.fireDate), 9)
        XCTAssertEqual(calendar.component(.minute, from: dueSoon.fireDate), 0)
        XCTAssertTrue(dueSoon.body.contains("due in 60m"))
        XCTAssertEqual(dueSoon.route, .taskDetail(taskID: dueSoonTask.id))
    }

    func testQuietHoursDefersTaskReminderToQuietWindowEnd() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 21, minute: 50)

        var reminderTask = TaskDefinition(title: "Late reminder")
        reminderTask.alertReminderTime = makeUTCDate(year: 2026, month: 2, day: 24, hour: 22, minute: 30)

        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [reminderTask])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: true,
                dueSoonEnabled: false,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: false,
                nightlyRetrospectiveEnabled: false,
                quietHoursEnabled: true,
                quietHoursStartHour: 22,
                quietHoursStartMinute: 0,
                quietHoursEndHour: 7,
                quietHoursEndMinute: 0,
                quietHoursAppliesToTaskAlerts: true
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_quiet_hours_task")

        let reminderID = "task.reminder.\(reminderTask.id.uuidString)"
        guard let reminder = notificationService.scheduled.first(where: { $0.id == reminderID }) else {
            return XCTFail("Expected reminder notification")
        }
        XCTAssertEqual(calendar.component(.day, from: reminder.fireDate), 25)
        XCTAssertEqual(calendar.component(.hour, from: reminder.fireDate), 7)
        XCTAssertEqual(calendar.component(.minute, from: reminder.fireDate), 0)
    }

    func testQuietHoursCanDeferDailySummaryWhenEnabledForDailyNotifications() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 7, minute: 30)
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [])
        let notificationService = CapturingNotificationService()
        let store = makePreferencesStore()
        store.save(
            TaskerNotificationPreferences(
                taskRemindersEnabled: false,
                dueSoonEnabled: false,
                overdueNudgesEnabled: false,
                morningAgendaEnabled: true,
                nightlyRetrospectiveEnabled: false,
                morningHour: 8,
                morningMinute: 0,
                quietHoursEnabled: true,
                quietHoursStartHour: 7,
                quietHoursStartMinute: 0,
                quietHoursEndHour: 9,
                quietHoursEndMinute: 0,
                quietHoursAppliesToTaskAlerts: false,
                quietHoursAppliesToDailySummaries: true
            )
        )

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: repository,
            notificationService: notificationService,
            preferencesStore: store,
            calendar: calendar,
            now: { nowDate }
        )

        orchestrator.reconcile(reason: "unit_test_quiet_hours_daily")

        guard let morning = notificationService.scheduled.first(where: { $0.kind == .morningPlan && $0.id == "daily.morning.20260224" }) else {
            return XCTFail("Expected morning plan notification")
        }
        XCTAssertEqual(calendar.component(.hour, from: morning.fireDate), 9)
        XCTAssertEqual(calendar.component(.minute, from: morning.fireDate), 0)
    }

    private func makePreferencesStore() -> TaskerNotificationPreferencesStore {
        let suiteName = "tasker.notification.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TaskerNotificationPreferencesStore(defaults: defaults)
    }
}

final class TaskerNotificationRouteTests: XCTestCase {
    func testDailySummaryRoutePayloadRoundTrip() {
        let morning: TaskerNotificationRoute = .dailySummary(kind: .morning, dateStamp: "20260225")
        XCTAssertEqual(
            TaskerNotificationRoute.from(payload: morning.payload, fallbackTaskID: nil),
            morning
        )

        let nightlyNoDate: TaskerNotificationRoute = .dailySummary(kind: .nightly, dateStamp: nil)
        XCTAssertEqual(
            TaskerNotificationRoute.from(payload: nightlyNoDate.payload, fallbackTaskID: nil),
            nightlyNoDate
        )
    }
}

final class SceneDelegateNotificationRoutingTests: XCTestCase {
    override func tearDown() {
        clearRouteBus()
        TaskerNotificationRuntime.actionHandler = nil
        super.tearDown()
    }

    func testHandleNotificationLaunchFallsBackToPendingTaskDetailRouteWhenRuntimeHandlerUnavailable() {
        let taskID = UUID()
        let sceneDelegate = SceneDelegate()

        sceneDelegate.handleNotificationLaunch(
            request: makeUNNotificationRequest(
                id: "task.reminder.\(taskID.uuidString)",
                kind: .taskReminder,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .taskDetail(taskID: taskID))
    }

    func testHandleNotificationLaunchUsesRuntimeActionHandlerWhenAvailable() {
        let notificationService = CapturingNotificationService()
        TaskerNotificationRuntime.actionHandler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        let sceneDelegate = SceneDelegate()
        sceneDelegate.handleNotificationLaunch(
            request: makeUNNotificationRequest(
                id: "daily.nightly.20260224",
                kind: .nightlyRetrospective,
                route: .dailySummary(kind: .nightly, dateStamp: "20260224"),
                category: TaskerNotificationCategoryID.dailyNightly.rawValue
            ),
            actionIdentifier: TaskerNotificationActionID.openDone.rawValue
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .homeDone)
    }

    private func clearRouteBus() {
        while TaskerNotificationRouteBus.shared.consumePendingRoute() != nil {}
    }
}

final class DailySummaryModalUseCaseTests: XCTestCase {
    func testBuildSummaryMorningIncludesFocusRiskAndAgenda() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 0)
        let dayStart = calendar.startOfDay(for: nowDate)

        var overdueBlocked = TaskDefinition(title: "Resolve production incident", priority: .high)
        overdueBlocked.dueDate = dayStart.addingTimeInterval(-3600)
        overdueBlocked.estimatedDuration = 90 * 60
        overdueBlocked.dependencies = [
            TaskDependencyLinkDefinition(
                taskID: overdueBlocked.id,
                dependsOnTaskID: UUID(),
                kind: .blocks
            )
        ]

        var dueMorning = TaskDefinition(title: "Draft proposal", priority: .max, type: .morning)
        dueMorning.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)

        var dueEvening = TaskDefinition(title: "Send recap", priority: .low, type: .evening, isEveningTask: true)
        dueEvening.dueDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: nowDate)

        var tomorrow = TaskDefinition(title: "Plan next sprint", priority: .high)
        tomorrow.dueDate = calendar.date(byAdding: .day, value: 1, to: nowDate)

        var completed = TaskDefinition(title: "Closed meeting notes", priority: .low, isComplete: true)
        completed.dateCompleted = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: nowDate)
        completed.dueDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nowDate)

        let allTasks = [overdueBlocked, dueMorning, dueEvening, tomorrow, completed]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )

        let summary = useCase.buildSummary(
            kind: .morning,
            date: nowDate,
            allTasks: allTasks,
            analytics: nil,
            streakCount: nil
        )

        guard case .morning(let morning) = summary else {
            return XCTFail("Expected morning summary")
        }

        XCTAssertEqual(morning.openTodayCount, 3)
        XCTAssertEqual(morning.highPriorityCount, 2)
        XCTAssertEqual(morning.overdueCount, 1)
        XCTAssertEqual(morning.blockedCount, 1)
        XCTAssertEqual(morning.longTaskCount, 1)
        XCTAssertEqual(morning.morningPlannedCount, 1)
        XCTAssertEqual(morning.eveningPlannedCount, 1)
        XCTAssertEqual(morning.focusTasks.first?.taskID, dueMorning.id)
    }

    func testBuildSummaryNightlyIncludesWinsCarryOverAndTomorrowPreview() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 21, minute: 0)
        let dayStart = calendar.startOfDay(for: nowDate)

        var openDueMorning = TaskDefinition(title: "Open today A", priority: .high, type: .morning)
        openDueMorning.dueDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nowDate)

        var openDueEvening = TaskDefinition(title: "Open today B", priority: .low, type: .evening, isEveningTask: true)
        openDueEvening.dueDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: nowDate)

        var overdue = TaskDefinition(title: "Overdue cleanup", priority: .high)
        overdue.dueDate = dayStart.addingTimeInterval(-7200)

        var completedHigh = TaskDefinition(title: "Ship release", priority: .max, type: .morning, isComplete: true)
        completedHigh.dateCompleted = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: nowDate)
        completedHigh.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)

        var completedLow = TaskDefinition(title: "Tidy inbox", priority: .low, type: .evening, isComplete: true, isEveningTask: true)
        completedLow.dateCompleted = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: nowDate)
        completedLow.dueDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: nowDate)

        var tomorrow = TaskDefinition(title: "Tomorrow task", priority: .high)
        tomorrow.dueDate = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: nowDate) ?? nowDate)

        let allTasks = [openDueMorning, openDueEvening, overdue, completedHigh, completedLow, tomorrow]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )
        let analytics = DailyAnalytics(
            date: nowDate,
            totalTasks: 4,
            completedTasks: 2,
            completionRate: 0.5,
            totalScore: completedHigh.priority.scorePoints + completedLow.priority.scorePoints,
            morningTasksCompleted: 1,
            eveningTasksCompleted: 1,
            priorityBreakdown: [:]
        )

        let summary = useCase.buildSummary(
            kind: .nightly,
            date: nowDate,
            allTasks: allTasks,
            analytics: analytics,
            streakCount: 6
        )

        guard case .nightly(let nightly) = summary else {
            return XCTFail("Expected nightly summary")
        }

        XCTAssertEqual(nightly.completedCount, 2)
        XCTAssertEqual(nightly.totalCount, 4)
        XCTAssertEqual(
            nightly.xpEarned,
            completedHigh.priority.scorePoints + completedLow.priority.scorePoints
        )
        XCTAssertEqual(nightly.completionRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(nightly.streakCount, 6)
        XCTAssertEqual(nightly.biggestWins.first?.taskID, completedHigh.id)
        XCTAssertEqual(nightly.carryOverDueTodayCount, 2)
        XCTAssertEqual(nightly.carryOverOverdueCount, 1)
        XCTAssertEqual(nightly.tomorrowPreview.map(\.taskID), [tomorrow.id])
        XCTAssertEqual(nightly.morningCompletedCount, 1)
        XCTAssertEqual(nightly.eveningCompletedCount, 1)
    }

    func testBuildSummaryMorningUsesDateTasksSplitWhenProvided() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 8, minute: 0)

        var morningTaskA = TaskDefinition(title: "Morning A", priority: .high, type: .morning)
        morningTaskA.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)
        var morningTaskB = TaskDefinition(title: "Morning B", priority: .low, type: .morning)
        morningTaskB.dueDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nowDate)
        var eveningTask = TaskDefinition(title: "Evening A", priority: .low, type: .evening, isEveningTask: true)
        eveningTask.dueDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: nowDate)

        let allTasks = [morningTaskA, morningTaskB, eveningTask]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )

        let dateTasks = DateTasksResult(
            date: nowDate,
            morningTasks: [morningTaskA, morningTaskB],
            eveningTasks: [eveningTask],
            overdueTasks: [],
            completedTasks: [],
            totalCount: 3
        )

        let summary = useCase.buildSummary(
            kind: .morning,
            date: nowDate,
            allTasks: allTasks,
            analytics: nil,
            streakCount: nil,
            dateTasks: dateTasks
        )

        guard case .morning(let morning) = summary else {
            return XCTFail("Expected morning summary")
        }

        XCTAssertEqual(morning.morningPlannedCount, 2)
        XCTAssertEqual(morning.eveningPlannedCount, 1)
    }

    func testBuildSummaryNightlyPrefersAnalyticsTotalCountForHeroDenominator() {
        let calendar = Calendar(identifier: .gregorian, timeZoneID: "UTC")
        let nowDate = makeUTCDate(year: 2026, month: 2, day: 24, hour: 21, minute: 0)

        var completed = TaskDefinition(title: "Completed", priority: .high, type: .morning, isComplete: true)
        completed.dateCompleted = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nowDate)
        completed.dueDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: nowDate)

        let allTasks = [completed]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: allTasks)
        let useCase = GetDailySummaryModalUseCase(
            getTasksUseCase: GetTasksUseCase(readModelRepository: readModel),
            analyticsUseCase: CalculateAnalyticsUseCase(taskReadModelRepository: readModel),
            calendar: calendar,
            now: { nowDate }
        )
        let analytics = DailyAnalytics(
            date: nowDate,
            totalTasks: 5,
            completedTasks: 1,
            completionRate: 0.2,
            totalScore: completed.priority.scorePoints,
            morningTasksCompleted: 1,
            eveningTasksCompleted: 0,
            priorityBreakdown: [:]
        )

        let summary = useCase.buildSummary(
            kind: .nightly,
            date: nowDate,
            allTasks: allTasks,
            analytics: analytics,
            streakCount: 2
        )

        guard case .nightly(let nightly) = summary else {
            return XCTFail("Expected nightly summary")
        }

        XCTAssertEqual(nightly.completedCount, 1)
        XCTAssertEqual(nightly.totalCount, 5)
    }
}

final class TaskerNotificationActionHandlerTests: XCTestCase {
    func testCompleteActionMarksTaskDoneAndCancelsTaskBoundNotifications() throws {
        let taskID = UUID()
        let task = TaskDefinition(
            id: taskID,
            title: "Complete from notification",
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: repository,
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )

        let notificationService = CapturingNotificationService()
        notificationService.pending = [
            TaskerPendingNotificationRequest(id: "task.reminder.\(taskID.uuidString)", fireDate: nil, kind: .taskReminder),
            TaskerPendingNotificationRequest(id: "task.overdue.\(taskID.uuidString).20260224.am", fireDate: nil, kind: .overdue),
            TaskerPendingNotificationRequest(id: "task.snooze.task.reminder.\(taskID.uuidString).1772000000", fireDate: nil, kind: .snoozedTask, taskID: taskID)
        ]

        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { coordinator },
            now: { Date(timeIntervalSince1970: 1_772_000_000) }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.complete.rawValue,
            request: makeUNNotificationRequest(
                id: "task.reminder.\(taskID.uuidString)",
                kind: .taskReminder,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        let updated = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(updated?.isComplete, true)
        XCTAssertTrue(notificationService.canceledIDs.contains("task.reminder.\(taskID.uuidString)"))
        XCTAssertTrue(notificationService.canceledIDs.contains("task.overdue.\(taskID.uuidString).20260224.am"))
        XCTAssertTrue(notificationService.canceledIDs.contains("task.snooze.task.reminder.\(taskID.uuidString).1772000000"))
    }

    func testSnoozeActionsUseCategoryDurations() {
        let fixedNow = Date(timeIntervalSince1970: 1_772_000_000)
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil },
            now: { fixedNow }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.snooze30m.rawValue,
            request: makeUNNotificationRequest(
                id: "daily.morning.20260224",
                kind: .morningPlan,
                route: .homeToday(taskID: nil),
                category: TaskerNotificationCategoryID.dailyMorning.rawValue
            )
        )

        let snoozed = notificationService.scheduled.first
        XCTAssertEqual(snoozed?.kind, .snoozedMorning)
        guard let fireDate = snoozed?.fireDate else {
            XCTFail("Expected snoozed fire date")
            return
        }
        XCTAssertEqual(fireDate.timeIntervalSince1970, fixedNow.addingTimeInterval(30 * 60).timeIntervalSince1970, accuracy: 1)
    }

    func testSnoozeRespectsQuietHoursWhenEnabledForTaskAlerts() {
        let fixedNow = makeUTCDate(year: 2026, month: 2, day: 24, hour: 23, minute: 0)
        let notificationService = CapturingNotificationService()
        let suiteName = "tasker.notification.action.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let preferencesStore = TaskerNotificationPreferencesStore(defaults: defaults)
        preferencesStore.save(
            TaskerNotificationPreferences(
                quietHoursEnabled: true,
                quietHoursStartHour: 22,
                quietHoursStartMinute: 0,
                quietHoursEndHour: 7,
                quietHoursEndMinute: 0,
                quietHoursAppliesToTaskAlerts: true,
                quietHoursAppliesToDailySummaries: false
            )
        )

        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil },
            preferencesStore: preferencesStore,
            calendar: Calendar(identifier: .gregorian, timeZoneID: "UTC"),
            now: { fixedNow }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.snooze15m.rawValue,
            request: makeUNNotificationRequest(
                id: "task.reminder.\(UUID().uuidString)",
                kind: .taskReminder,
                route: .homeToday(taskID: nil),
                category: TaskerNotificationCategoryID.taskActionable.rawValue
            )
        )

        guard let snoozed = notificationService.scheduled.first else {
            return XCTFail("Expected snoozed request")
        }
        XCTAssertEqual(Calendar(identifier: .gregorian, timeZoneID: "UTC").component(.day, from: snoozed.fireDate), 25)
        XCTAssertEqual(Calendar(identifier: .gregorian, timeZoneID: "UTC").component(.hour, from: snoozed.fireDate), 7)
        XCTAssertEqual(Calendar(identifier: .gregorian, timeZoneID: "UTC").component(.minute, from: snoozed.fireDate), 0)
    }

    func testOpenDoneActionRoutesToDoneQuickView() {
        clearRouteBus()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.openDone.rawValue,
            request: makeUNNotificationRequest(
                id: "daily.nightly.20260224",
                kind: .nightlyRetrospective,
                route: .homeDone,
                category: TaskerNotificationCategoryID.dailyNightly.rawValue
            )
        )

        let routed = TaskerNotificationRouteBus.shared.consumePendingRoute()
        if case .some(.homeDone) = routed {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected route to be homeDone")
        }
    }

    func testDefaultTapRoutesToDailySummaryWhenPayloadContainsDailySummaryRoute() {
        clearRouteBus()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        let expectedRoute: TaskerNotificationRoute = .dailySummary(kind: .morning, dateStamp: "20260225")
        handler.handleAction(
            identifier: UNNotificationDefaultActionIdentifier,
            request: makeUNNotificationRequest(
                id: "daily.morning.20260225",
                kind: .morningPlan,
                route: expectedRoute,
                category: TaskerNotificationCategoryID.dailyMorning.rawValue
            )
        )

        let routed = TaskerNotificationRouteBus.shared.consumePendingRoute()
        XCTAssertEqual(routed, expectedRoute)
    }

    func testDefaultTapRoutesTaskAlertToTaskDetail() {
        clearRouteBus()
        let taskID = UUID()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: UNNotificationDefaultActionIdentifier,
            request: makeUNNotificationRequest(
                id: "task.overdue.\(taskID.uuidString).20260224.am",
                kind: .overdue,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .taskDetail(taskID: taskID))
    }

    func testOpenActionRoutesTaskAlertToTaskDetail() {
        clearRouteBus()
        let taskID = UUID()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.open.rawValue,
            request: makeUNNotificationRequest(
                id: "task.dueSoon.\(taskID.uuidString).20260224",
                kind: .dueSoon,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            )
        )

        XCTAssertEqual(TaskerNotificationRouteBus.shared.consumePendingRoute(), .taskDetail(taskID: taskID))
    }

    func testCompleteActionInvokesCompletionExactlyOnce() throws {
        let taskID = UUID()
        let task = TaskDefinition(
            id: taskID,
            title: "Complete with callback",
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let repository = InMemoryTaskDefinitionRepositoryStub(seed: [task])
        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: repository,
            projectRepository: MockProjectRepository(projects: [Project.createInbox()])
        )
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { coordinator },
            now: { Date(timeIntervalSince1970: 1_772_000_000) }
        )

        let completionExpectation = expectation(description: "action completion")
        var completionCount = 0

        handler.handleAction(
            identifier: TaskerNotificationActionID.complete.rawValue,
            request: makeUNNotificationRequest(
                id: "task.reminder.\(taskID.uuidString)",
                kind: .taskReminder,
                route: .taskDetail(taskID: taskID),
                taskID: taskID
            ),
            completion: {
                completionCount += 1
                completionExpectation.fulfill()
            }
        )

        wait(for: [completionExpectation], timeout: 1.0)
        XCTAssertEqual(completionCount, 1)
    }

    func testOpenTodayActionRoutesToHomeTodayNotTaskDetail() {
        clearRouteBus()
        let taskID = UUID()
        let notificationService = CapturingNotificationService()
        let handler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: { nil }
        )

        handler.handleAction(
            identifier: TaskerNotificationActionID.openToday.rawValue,
            request: makeUNNotificationRequest(
                id: "daily.morning.20260224",
                kind: .morningPlan,
                route: .homeToday(taskID: taskID),
                taskID: taskID,
                category: TaskerNotificationCategoryID.dailyMorning.rawValue
            )
        )

        let routed = TaskerNotificationRouteBus.shared.consumePendingRoute()
        if case .some(.homeToday(let routedTaskID)) = routed {
            XCTAssertEqual(routedTaskID, taskID)
        } else {
            XCTFail("Expected route to be homeToday(taskID:)")
        }
    }

    private func clearRouteBus() {
        while TaskerNotificationRouteBus.shared.consumePendingRoute() != nil {}
    }
}

private final class CapturingNotificationService: NotificationServiceProtocol {
    var scheduled: [TaskerLocalNotificationRequest] = []
    var canceledIDs: [String] = []
    var pending: [TaskerPendingNotificationRequest] = []
    var scheduleInvocationIDs: [String] = []
    var authorizationStatus: TaskerNotificationAuthorizationStatus = .authorized

    func scheduleTaskReminder(taskId: UUID, taskName: String, at date: Date) {}
    func cancelTaskReminder(taskId: UUID) {}
    func cancelAllReminders() {}
    func send(_ notification: CollaborationNotification) {}
    func requestPermission(completion: @escaping (Bool) -> Void) { completion(true) }
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) { completion(true) }
    func fetchAuthorizationStatus(completion: @escaping (TaskerNotificationAuthorizationStatus) -> Void) { completion(authorizationStatus) }
    func registerCategories(_ categories: Set<UNNotificationCategory>) {}
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {}

    func schedule(request: TaskerLocalNotificationRequest) {
        scheduleInvocationIDs.append(request.id)
        scheduled.removeAll(where: { $0.id == request.id })
        scheduled.append(request)
        pending.removeAll(where: { $0.id == request.id })
        pending.append(
            TaskerPendingNotificationRequest(
                id: request.id,
                fireDate: request.fireDate,
                kind: request.kind,
                title: request.title,
                body: request.body,
                categoryIdentifier: request.categoryIdentifier,
                routePayload: request.route.payload,
                taskID: request.taskID
            )
        )
    }

    func cancel(ids: [String]) {
        canceledIDs.append(contentsOf: ids)
        pending.removeAll(where: { ids.contains($0.id) })
        scheduled.removeAll(where: { ids.contains($0.id) })
    }

    func pendingRequests(completion: @escaping ([TaskerPendingNotificationRequest]) -> Void) {
        completion(pending)
    }
}

private func makeUNNotificationRequest(
    id: String,
    kind: TaskerLocalNotificationKind,
    route: TaskerNotificationRoute,
    taskID: UUID? = nil,
    category: String = TaskerNotificationCategoryID.taskActionable.rawValue
) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "Title"
    content.body = "Body"
    content.categoryIdentifier = category
    var userInfo: [AnyHashable: Any] = [
        TaskerLocalNotificationRequest.UserInfoKey.kind: kind.rawValue,
        TaskerLocalNotificationRequest.UserInfoKey.route: route.payload
    ]
    if let taskID {
        userInfo[TaskerLocalNotificationRequest.UserInfoKey.taskID] = taskID.uuidString
    }
    content.userInfo = userInfo
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
    return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
}

private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date ?? Date(timeIntervalSince1970: 0)
}

private extension Calendar {
    init(identifier: Calendar.Identifier, timeZoneID: String) {
        self.init(identifier: identifier)
        self.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
    }
}

final class InsightsViewModelPerformanceLogicTests: XCTestCase {
    func testOnAppearLoadsSelectedTabOnly() {
        let repository = InsightsRepositorySpy()
        repository.dailyAggregatesByDateKey[XPCalculationEngine.periodKey()] = DailyXPAggregateDefinition(
            dateKey: XPCalculationEngine.periodKey(),
            totalXP: 42,
            eventCount: 3
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 20, reason: "task_completion", idempotencyKey: "a", category: .complete)
        ]
        let viewModel = makeInsightsViewModel(repository: repository)

        viewModel.onAppear()
        waitUntil {
            viewModel.refreshState(for: .today).isLoaded
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount, 1)
        XCTAssertEqual(repository.fetchXPEventsRangeCount, 1)
        XCTAssertEqual(repository.fetchDailyAggregatesCount, 0)
        XCTAssertEqual(repository.fetchAchievementUnlocksCount, 0)
    }

    func testCleanTabSwitchDoesNotRefetchLoadedTab() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 12, eventCount: 1)

        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let key = formatter.string(from: day)
            repository.weekAggregates.append(
                DailyXPAggregateDefinition(dateKey: key, totalXP: (dayOffset + 1) * 5, eventCount: dayOffset + 1)
            )
        }

        let viewModel = makeInsightsViewModel(repository: repository)
        viewModel.onAppear()
        waitUntil {
            viewModel.refreshState(for: .today).isLoaded
        }

        viewModel.selectTab(.week)
        waitUntil {
            viewModel.refreshState(for: .week).isLoaded
        }

        let dailyAggregateFetchesBeforeReselect = repository.fetchDailyAggregateCount
        let xpRangeFetchesBeforeReselect = repository.fetchXPEventsRangeCount

        viewModel.selectTab(.today)
        waitUntil {
            viewModel.selectedTab == .today
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount, dailyAggregateFetchesBeforeReselect)
        XCTAssertEqual(repository.fetchXPEventsRangeCount, xpRangeFetchesBeforeReselect)
    }

    func testTodayRefreshAllowsTotalTasksTodayToDecreaseWhenEventsShrink() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(
            dateKey: todayKey,
            totalXP: 30,
            eventCount: 3
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "a", category: .complete),
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "b", category: .complete),
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "c", category: .complete)
        ]

        let viewModel = makeInsightsViewModel(repository: repository)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .today).isLoaded
                && viewModel.todayState.totalTasksToday == 3
        }

        repository.todayEvents = [
            XPEventDefinition(delta: 10, reason: "task_completion", idempotencyKey: "d", category: .complete)
        ]

        viewModel.noteMutation(.taskCompleted)

        waitUntil(timeout: 2.0) {
            viewModel.refreshState(for: .today).inFlight == false
                && viewModel.todayState.tasksCompletedToday == 1
                && viewModel.todayState.totalTasksToday == 1
        }

        XCTAssertEqual(viewModel.todayState.tasksCompletedToday, 1)
        XCTAssertEqual(viewModel.todayState.totalTasksToday, 1)
    }

    func testMutationBurstCoalescesIntoSingleRefreshPass() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 8, eventCount: 1)
        repository.todayEvents = [
            XPEventDefinition(delta: 8, reason: "task_completion", idempotencyKey: "burst", category: .complete)
        ]
        let viewModel = makeInsightsViewModel(repository: repository)

        viewModel.onAppear()
        waitUntil {
            viewModel.refreshState(for: .today).isLoaded
        }

        let beforeDailyAggregateFetches = repository.fetchDailyAggregateCount
        let beforeXPRangeFetches = repository.fetchXPEventsRangeCount

        viewModel.noteMutation(.taskCompleted)
        viewModel.noteMutation(.taskCompleted)
        viewModel.noteMutation(.taskCompleted)

        waitUntil(timeout: 2.0) {
            repository.fetchXPEventsRangeCount >= beforeXPRangeFetches + 1
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount - beforeDailyAggregateFetches, 1)
        XCTAssertEqual(repository.fetchXPEventsRangeCount - beforeXPRangeFetches, 1)
    }

    func testMutationDuringInFlightTriggersSingleReplay() {
        let repository = InsightsRepositorySpy()
        repository.rangeFetchDelay = 0.35
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 14, eventCount: 2)
        repository.todayEvents = [
            XPEventDefinition(delta: 14, reason: "task_completion", idempotencyKey: "inflight", category: .complete)
        ]
        let viewModel = makeInsightsViewModel(repository: repository)

        viewModel.onAppear()
        waitUntil(timeout: 1.0) {
            viewModel.refreshState(for: .today).inFlight
        }

        viewModel.noteMutation(.taskCompleted)

        waitUntil(timeout: 3.0) {
            viewModel.refreshState(for: .today).isLoaded
                && viewModel.refreshState(for: .today).inFlight == false
                && repository.fetchXPEventsRangeCount >= 2
        }

        XCTAssertEqual(repository.fetchXPEventsRangeCount, 2)
        XCTAssertEqual(repository.fetchDailyAggregateCount, 2)
    }

    func testWeeklyBarIdentityUsesUniqueDateKey() {
        let repository = InsightsRepositorySpy()
        let todayKey = XPCalculationEngine.periodKey()
        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(dateKey: todayKey, totalXP: 20, eventCount: 2)

        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)
        repository.weekAggregates = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DailyXPAggregateDefinition(
                dateKey: formatter.string(from: day),
                totalXP: (offset + 1) * 3,
                eventCount: offset + 1
            )
        }

        let viewModel = makeInsightsViewModel(repository: repository)
        viewModel.selectTab(.week)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .week).isLoaded
        }

        let ids = viewModel.weekState.weeklyBars.map(\.id)
        XCTAssertEqual(ids.count, 7)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testLedgerMutationAppliesProjectionWithoutRepositoryRefetch() {
        let repository = InsightsRepositorySpy()
        let center = NotificationCenter()
        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)
        let todayKey = XPCalculationEngine.periodKey()

        repository.dailyAggregatesByDateKey[todayKey] = DailyXPAggregateDefinition(
            dateKey: todayKey,
            totalXP: 20,
            eventCount: 2
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 20, reason: "task_completion", idempotencyKey: "pre", category: .complete)
        ]
        repository.weekAggregates = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DailyXPAggregateDefinition(
                dateKey: formatter.string(from: day),
                totalXP: offset == 0 ? 20 : 0,
                eventCount: offset == 0 ? 2 : 0
            )
        }

        let viewModel = makeInsightsViewModel(repository: repository, notificationCenter: center)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .today).isLoaded
        }

        viewModel.selectTab(.week)
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .week).isLoaded
        }

        let dailyAggregateFetches = repository.fetchDailyAggregateCount
        let xpRangeFetches = repository.fetchXPEventsRangeCount
        let weeklyAggregateFetches = repository.fetchDailyAggregatesCount

        let mutation = GamificationLedgerMutation(
            source: XPSource.manual.rawValue,
            category: .complete,
            awardedXP: 15,
            dailyXPSoFar: 35,
            totalXP: 220,
            level: 4,
            previousLevel: 3,
            streakDays: 5,
            didChange: true,
            dateKey: todayKey,
            occurredAt: Date()
        )
        center.post(
            name: .gamificationLedgerDidMutate,
            object: nil,
            userInfo: mutation.userInfo
        )

        waitUntil(timeout: 1.5) {
            viewModel.todayState.dailyXP == 35
                && viewModel.weekState.weeklyBars.contains(where: { $0.dateKey == todayKey && $0.xp == 35 })
        }

        XCTAssertEqual(repository.fetchDailyAggregateCount, dailyAggregateFetches)
        XCTAssertEqual(repository.fetchXPEventsRangeCount, xpRangeFetches)
        XCTAssertEqual(repository.fetchDailyAggregatesCount, weeklyAggregateFetches)
    }

    func testWeekScaleModePersistsAcrossViewModelInstances() {
        let suiteName = "insights.week.scale.mode.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create isolated defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let repository = InsightsRepositorySpy()
        let engine = GamificationEngine(repository: repository)
        let first = InsightsViewModel(
            engine: engine,
            repository: repository,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults
        )
        XCTAssertEqual(first.weekScaleMode, .personalMax)

        first.setWeekScaleMode(.goal)

        let second = InsightsViewModel(
            engine: engine,
            repository: repository,
            notificationCenter: NotificationCenter(),
            userDefaults: defaults
        )
        XCTAssertEqual(second.weekScaleMode, .goal)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLedgerMutationRefreshesSystemsAndLoadsUnlockedAchievements() {
        let repository = InsightsRepositorySpy()
        let center = NotificationCenter()
        let viewModel = makeInsightsViewModel(repository: repository, notificationCenter: center)

        viewModel.selectTab(.systems)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .systems).isLoaded
        }

        let unlockedKey = "streak_7"
        let baselineUnlockFetches = repository.fetchAchievementUnlocksCount
        repository.achievements = [
            AchievementUnlockDefinition(
                id: UUID(),
                achievementKey: unlockedKey,
                unlockedAt: Date(),
                sourceEventID: nil
            )
        ]
        let mutation = GamificationLedgerMutation(
            source: XPSource.manual.rawValue,
            category: .complete,
            awardedXP: 12,
            dailyXPSoFar: 12,
            totalXP: 150,
            level: 2,
            previousLevel: 1,
            streakDays: 7,
            didChange: true,
            dateKey: XPCalculationEngine.periodKey(),
            occurredAt: Date(),
            unlockedAchievementKeys: [unlockedKey],
            originatingEventID: UUID()
        )
        center.post(
            name: .gamificationLedgerDidMutate,
            object: nil,
            userInfo: mutation.userInfo
        )

        waitUntil(timeout: 1.5) {
            repository.fetchAchievementUnlocksCount > baselineUnlockFetches
                && viewModel.systemsState.unlockedAchievements.contains(unlockedKey)
        }

        XCTAssertTrue(viewModel.systemsState.unlockedAchievements.contains(unlockedKey))
    }

    func testTodayProjectionBuildsDuePressureFocusAndMixModules() {
        let repository = InsightsRepositorySpy()
        let calendar = XPCalculationEngine.mondayCalendar()
        let today = calendar.startOfDay(for: Date())
        let overdueDate = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        let dueLaterToday = calendar.date(byAdding: .hour, value: 10, to: today) ?? today
        let completedAt = calendar.date(byAdding: .hour, value: 9, to: today) ?? today

        repository.dailyAggregatesByDateKey[XPCalculationEngine.periodKey(for: today)] = DailyXPAggregateDefinition(
            dateKey: XPCalculationEngine.periodKey(for: today),
            totalXP: 48,
            eventCount: 4
        )
        repository.todayEvents = [
            XPEventDefinition(delta: 18, reason: "task_completion", idempotencyKey: "today-1", createdAt: completedAt, category: .complete),
            XPEventDefinition(delta: 12, reason: "focus", idempotencyKey: "today-2", createdAt: completedAt, category: .focus),
            XPEventDefinition(delta: 8, reason: "recover", idempotencyKey: "today-3", createdAt: completedAt, category: .recoverReschedule),
            XPEventDefinition(delta: 10, reason: "reflection", idempotencyKey: "today-4", createdAt: completedAt, category: .reflection)
        ]
        repository.focusSessions = [
            FocusSessionDefinition(startedAt: completedAt, endedAt: calendar.date(byAdding: .minute, value: 30, to: completedAt), durationSeconds: 1_800, targetDurationSeconds: 1_800, wasCompleted: true, xpAwarded: 12),
            FocusSessionDefinition(
                startedAt: calendar.date(byAdding: .hour, value: 2, to: completedAt) ?? completedAt,
                endedAt: calendar.date(byAdding: .hour, value: 2, to: completedAt)?.addingTimeInterval(1_200),
                durationSeconds: 1_200,
                targetDurationSeconds: 1_500,
                wasCompleted: false,
                xpAwarded: 0
            )
        ]

        let tasks = [
            TaskDefinition(
                title: "High leverage task",
                priority: .high,
                type: .morning,
                energy: .high,
                context: .computer,
                dueDate: dueLaterToday,
                isComplete: true,
                dateCompleted: completedAt
            ),
            TaskDefinition(
                title: "Blocked overdue task",
                priority: .max,
                type: .morning,
                energy: .medium,
                context: .office,
                dueDate: overdueDate,
                dependencies: [TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .blocks, createdAt: Date())],
                estimatedDuration: 7_200
            )
        ]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: tasks)
        let viewModel = makeInsightsViewModel(repository: repository, taskReadModelRepository: readModel)

        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .today).isLoaded
                && !viewModel.todayState.completionMixSections.isEmpty
        }

        XCTAssertEqual(viewModel.todayState.momentumMetrics.count, 4)
        XCTAssertEqual(viewModel.todayState.duePressureMetrics.first(where: { $0.id == "overdue" })?.value, "1")
        XCTAssertEqual(viewModel.todayState.duePressureMetrics.first(where: { $0.id == "blocked" })?.value, "1")
        XCTAssertEqual(viewModel.todayState.focusMetrics.first(where: { $0.id == "focus_minutes" })?.value, "50")
        XCTAssertTrue(viewModel.todayState.recoveryMetrics.contains(where: { $0.id == "reflection" && $0.value == "Claimed" }))
    }

    func testWeekProjectionBuildsLeaderboardAndMix() {
        let repository = InsightsRepositorySpy()
        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        let formatter = makeDateFormatter(calendar: calendar)

        repository.weekAggregates = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DailyXPAggregateDefinition(
                dateKey: formatter.string(from: day),
                totalXP: offset < 4 ? (offset + 1) * 15 : 0,
                eventCount: offset < 4 ? offset + 1 : 0
            )
        }

        let projectA = UUID()
        let projectB = UUID()
        let completionDayOne = calendar.date(byAdding: .day, value: 1, to: weekStart) ?? weekStart
        let completionDayTwo = calendar.date(byAdding: .day, value: 2, to: weekStart) ?? weekStart
        repository.allEvents = [
            XPEventDefinition(delta: 15, reason: "task_completion", idempotencyKey: "week-1", createdAt: completionDayOne, category: .complete),
            XPEventDefinition(delta: 20, reason: "task_completion", idempotencyKey: "week-2", createdAt: completionDayTwo, category: .complete)
        ]

        let tasks = [
            TaskDefinition(
                projectID: projectA,
                projectName: "Apollo",
                title: "Apollo close",
                priority: .high,
                type: .morning,
                dueDate: completionDayOne,
                isComplete: true,
                dateCompleted: completionDayOne
            ),
            TaskDefinition(
                projectID: projectA,
                projectName: "Apollo",
                title: "Apollo follow-up",
                priority: .max,
                type: .evening,
                dueDate: completionDayTwo,
                isComplete: true,
                dateCompleted: completionDayTwo
            ),
            TaskDefinition(
                projectID: projectB,
                projectName: "Beacon",
                title: "Beacon prep",
                priority: .low,
                type: .upcoming,
                dueDate: completionDayTwo,
                isComplete: true,
                dateCompleted: completionDayTwo
            )
        ]
        let readModel = InMemoryTaskReadModelRepositoryStub(tasks: tasks)
        let viewModel = makeInsightsViewModel(repository: repository, taskReadModelRepository: readModel)

        viewModel.selectTab(.week)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .week).isLoaded
                && !viewModel.weekState.projectLeaderboard.isEmpty
        }

        XCTAssertEqual(viewModel.weekState.projectLeaderboard.first?.title, "Apollo")
        XCTAssertFalse(viewModel.weekState.priorityMix.isEmpty)
        XCTAssertFalse(viewModel.weekState.taskTypeMix.isEmpty)
        XCTAssertEqual(viewModel.weekState.weeklyBars.count, 7)
    }

    func testSystemsProjectionBuildsReminderResponseAndFocusHealth() {
        let repository = InsightsRepositorySpy()
        let reminderRepository = InsightsReminderRepositorySpy()
        let now = Date()

        repository.allEvents = [
            XPEventDefinition(delta: 8, reason: "recover", idempotencyKey: "sys-1", createdAt: now, category: .recoverReschedule),
            XPEventDefinition(delta: 6, reason: "reflection", idempotencyKey: "sys-2", createdAt: now, category: .reflection),
            XPEventDefinition(delta: 4, reason: "decompose", idempotencyKey: "sys-3", createdAt: now, category: .decompose)
        ]
        repository.focusSessions = [
            FocusSessionDefinition(startedAt: now.addingTimeInterval(-86_400), endedAt: now.addingTimeInterval(-84_600), durationSeconds: 1_800, targetDurationSeconds: 1_800, wasCompleted: true, xpAwarded: 10),
            FocusSessionDefinition(startedAt: now.addingTimeInterval(-43_200), endedAt: now.addingTimeInterval(-42_000), durationSeconds: 1_200, targetDurationSeconds: 1_500, wasCompleted: false, xpAwarded: 0)
        ]

        let reminder = ReminderDefinition(
            id: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            occurrenceID: nil,
            policy: "default",
            channelMask: 1,
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
        reminderRepository.reminders = [reminder]
        reminderRepository.deliveriesByReminderID[reminder.id] = [
            ReminderDeliveryDefinition(id: UUID(), reminderID: reminder.id, triggerID: UUID(), status: "acked", scheduledAt: now, sentAt: now, ackAt: now, snoozedUntil: nil, errorCode: nil, createdAt: now),
            ReminderDeliveryDefinition(id: UUID(), reminderID: reminder.id, triggerID: UUID(), status: "snoozed", scheduledAt: now, sentAt: now, ackAt: nil, snoozedUntil: now.addingTimeInterval(600), errorCode: nil, createdAt: now),
            ReminderDeliveryDefinition(id: UUID(), reminderID: reminder.id, triggerID: UUID(), status: "pending", scheduledAt: now, sentAt: nil, ackAt: nil, snoozedUntil: nil, errorCode: nil, createdAt: now)
        ]

        let viewModel = makeInsightsViewModel(
            repository: repository,
            reminderRepository: reminderRepository
        )

        viewModel.selectTab(.systems)
        viewModel.onAppear()
        waitUntil(timeout: 1.5) {
            viewModel.refreshState(for: .systems).isLoaded
                && viewModel.systemsState.reminderResponse.totalDeliveries == 3
        }

        XCTAssertEqual(viewModel.systemsState.reminderResponse.acknowledgedDeliveries, 1)
        XCTAssertEqual(viewModel.systemsState.reminderResponse.snoozedDeliveries, 1)
        XCTAssertEqual(viewModel.systemsState.reminderResponse.pendingDeliveries, 1)
        XCTAssertEqual(viewModel.systemsState.focusHealthMetrics.first(where: { $0.id == "focus_sessions" })?.value, "2")
        XCTAssertTrue(viewModel.systemsState.recoveryHealthMetrics.contains(where: { $0.id == "reflections" && $0.value == "1" }))
    }

    private func makeInsightsViewModel(
        repository: InsightsRepositorySpy,
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        reminderRepository: ReminderRepositoryProtocol? = nil,
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> InsightsViewModel {
        let engine = GamificationEngine(repository: repository)
        return InsightsViewModel(
            engine: engine,
            repository: repository,
            taskReadModelRepository: taskReadModelRepository,
            reminderRepository: reminderRepository,
            notificationCenter: notificationCenter
        )
    }

    private func makeDateFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            let nextTick = Date().addingTimeInterval(0.01)
            if Thread.isMainThread {
                RunLoop.main.run(mode: .default, before: nextTick)
            } else {
                DispatchQueue.main.sync {}
                RunLoop.current.run(mode: .default, before: nextTick)
            }
        }
        XCTFail("Condition not met before timeout", file: file, line: line)
    }
}

final class CelebrationRouterBehaviorTests: XCTestCase {
    func testXPBurstCooldownSuppressesRapidRepeatBursts() {
        let router = DefaultCelebrationRouter()
        let first = router.route(event: makeEvent(kind: .xpBurst, signature: "xp-1", secondsFromBase: 0))
        let second = router.route(event: makeEvent(kind: .xpBurst, signature: "xp-2", secondsFromBase: 1))

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testLevelUpIsNotBlockedByXPBurstCooldown() {
        let router = DefaultCelebrationRouter()
        _ = router.route(event: makeEvent(kind: .xpBurst, signature: "xp-1", secondsFromBase: 0))

        let levelUp = router.route(event: makeEvent(kind: .levelUp, signature: "level-2", secondsFromBase: 0.1))
        XCTAssertNotNil(levelUp)
    }

    func testDuplicateSignatureIsDedupedAcrossKinds() {
        let router = DefaultCelebrationRouter()
        let first = router.route(event: makeEvent(kind: .milestone, signature: "same-signature", secondsFromBase: 0))
        let duplicate = router.route(event: makeEvent(kind: .milestone, signature: "same-signature", secondsFromBase: 12))

        XCTAssertNotNil(first)
        XCTAssertNil(duplicate)
    }

    func testAchievementUnlockUsesOwnCooldownWindow() {
        let router = DefaultCelebrationRouter()
        let first = router.route(event: makeEvent(kind: .achievementUnlock, signature: "achievement-1", secondsFromBase: 0))
        let suppressed = router.route(event: makeEvent(kind: .achievementUnlock, signature: "achievement-2", secondsFromBase: 0.4))
        let allowed = router.route(event: makeEvent(kind: .achievementUnlock, signature: "achievement-3", secondsFromBase: 1.2))

        XCTAssertNotNil(first)
        XCTAssertNil(suppressed)
        XCTAssertNotNil(allowed)
    }

    private func makeEvent(
        kind: CelebrationKind,
        signature: String,
        secondsFromBase: TimeInterval
    ) -> CelebrationEvent {
        let milestone = kind == .milestone ? XPCalculationEngine.milestones.first : nil
        return CelebrationEvent(
            kind: kind,
            awardedXP: 8,
            level: 3,
            milestone: milestone,
            achievementKey: kind == .achievementUnlock ? "streak_7" : nil,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000 + secondsFromBase),
            signature: signature
        )
    }
}

final class XPCalculationEngineExactPreviewTests: XCTestCase {
    func testCompletionXPIfCompletedNowIncludesOnTimeBonus() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let dueDate = completedAt
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.none.rawValue,
            estimatedDuration: nil,
            dueDate: dueDate,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 17)
        XCTAssertFalse(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowOmitsBonusForOverdueTask() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let dueDate = Calendar.current.date(byAdding: .day, value: -1, to: completedAt)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.none.rawValue,
            estimatedDuration: nil,
            dueDate: dueDate,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 11)
        XCTAssertFalse(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowAppliesEffortWeight() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.high.rawValue,
            estimatedDuration: 90 * 60,
            dueDate: nil,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 17)
        XCTAssertFalse(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowClampsToRemainingCapHeadroom() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.max.rawValue,
            estimatedDuration: nil,
            dueDate: completedAt,
            completedAt: completedAt,
            dailyEarnedSoFar: 245,
            isGamificationV2Enabled: true
        )

        XCTAssertEqual(preview.awardedXP, 5)
        XCTAssertTrue(preview.isCapped)
    }

    func testCompletionXPIfCompletedNowUsesLegacyFixedRewardWhenV2Disabled() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.max.rawValue,
            estimatedDuration: 120 * 60,
            dueDate: completedAt,
            completedAt: completedAt,
            dailyEarnedSoFar: 10_000,
            isGamificationV2Enabled: false
        )

        XCTAssertEqual(preview.awardedXP, 10)
        XCTAssertFalse(preview.isCapped)
    }
}

final class XPExactPreviewParityTests: XCTestCase {
    func testPreviewMatchesGamificationEngineAwardForStandardCompletion() throws {
        let repository = InMemoryGamificationEngineRepository()
        let engine = GamificationEngine(repository: repository)
        let completedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let dueDate = completedAt

        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.high.rawValue,
            estimatedDuration: 60 * 60,
            dueDate: dueDate,
            completedAt: completedAt,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: true
        )

        var recordedResult: Result<XPEventResult, Error>?
        let completionExpectation = expectation(description: "record completion")
        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                dueDate: dueDate,
                completedAt: completedAt,
                priority: max(0, Int(TaskPriority.high.rawValue) - 1),
                estimatedDuration: 60 * 60
            )
        ) { result in
            recordedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)
        let awarded = try XCTUnwrap(recordedResult).get().awardedXP
        XCTAssertEqual(preview.awardedXP, awarded)
    }

    func testPreviewMatchesGamificationEngineAwardWhenNearDailyCap() throws {
        let repository = InMemoryGamificationEngineRepository()
        let engine = GamificationEngine(repository: repository)
        let completedAt = Date(timeIntervalSince1970: 1_700_000_200)
        let dateKey = XPCalculationEngine.periodKey(for: completedAt)
        repository.seed(
            dailyAggregates: [
                dateKey: DailyXPAggregateDefinition(
                    id: UUID(),
                    dateKey: dateKey,
                    totalXP: 245,
                    eventCount: 10,
                    updatedAt: completedAt
                )
            ]
        )

        let preview = XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: TaskPriority.max.rawValue,
            estimatedDuration: nil,
            dueDate: completedAt,
            completedAt: completedAt,
            dailyEarnedSoFar: 245,
            isGamificationV2Enabled: true
        )

        var recordedResult: Result<XPEventResult, Error>?
        let completionExpectation = expectation(description: "record near-cap completion")
        engine.recordEvent(
            context: XPEventContext(
                category: .complete,
                source: .manual,
                taskID: UUID(),
                dueDate: completedAt,
                completedAt: completedAt,
                priority: max(0, Int(TaskPriority.max.rawValue) - 1),
                estimatedDuration: nil
            )
        ) { result in
            recordedResult = result
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)
        let result = try XCTUnwrap(recordedResult).get()
        XCTAssertEqual(preview.awardedXP, result.awardedXP)
        XCTAssertTrue(preview.isCapped)
        XCTAssertEqual(result.dailyXPSoFar, 245 + preview.awardedXP)
    }
}

final class XPRewardPreviewCopyRegressionTests: XCTestCase {
    func testCompletionRewardSurfacesUseExactPreviewAPI() throws {
        let rewardSurfaceFiles = [
            "To Do List/View/TaskRowView.swift",
            "To Do List/View/TaskDetailSheetView.swift",
            "To Do List/View/AddTaskXPPreview.swift"
        ]

        for relativePath in rewardSurfaceFiles {
            let source = try loadWorkspaceFile(relativePath)
            XCTAssertTrue(
                source.contains("completionXPIfCompletedNow("),
                "\(relativePath) should use exact completion preview API."
            )
            XCTAssertFalse(
                source.contains("completionEstimate("),
                "\(relativePath) should not use range-based completion estimate API."
            )
        }
    }

    func testCompletionRewardSurfacesDoNotUseApproximateCopy() throws {
        let rewardCopyFiles = [
            "To Do List/View/TaskRowView.swift",
            "To Do List/View/TaskDetailComponents.swift",
            "To Do List/View/AddTaskXPPreview.swift"
        ]

        for relativePath in rewardCopyFiles {
            let source = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(source.contains("Est. +"), "\(relativePath) should not show estimated XP labels.")
            XCTAssertFalse(source.contains("~+"), "\(relativePath) should not show approximate compact XP labels.")
            XCTAssertFalse(source.contains("Estimated reward"), "\(relativePath) should use reward wording.")
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

private final class InsightsRepositorySpy: GamificationRepositoryProtocol {
    private let lock = NSLock()

    var profile = GamificationSnapshot(
        xpTotal: 120,
        level: 2,
        currentStreak: 3,
        bestStreak: 5,
        nextLevelXP: 150,
        returnStreak: 0,
        bestReturnStreak: 0
    )
    var dailyAggregatesByDateKey: [String: DailyXPAggregateDefinition] = [:]
    var weekAggregates: [DailyXPAggregateDefinition] = []
    var todayEvents: [XPEventDefinition] = []
    var allEvents: [XPEventDefinition] = []
    var focusSessions: [FocusSessionDefinition] = []
    var achievements: [AchievementUnlockDefinition] = []
    var rangeFetchDelay: TimeInterval = 0

    private(set) var fetchProfileCount = 0
    private(set) var fetchDailyAggregateCount = 0
    private(set) var fetchDailyAggregatesCount = 0
    private(set) var fetchXPEventsAllCount = 0
    private(set) var fetchXPEventsRangeCount = 0
    private(set) var fetchAchievementUnlocksCount = 0
    private(set) var fetchFocusSessionsCount = 0

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        lock.lock()
        fetchProfileCount += 1
        let snapshot = profile
        lock.unlock()
        completion(.success(snapshot))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        fetchXPEventsAllCount += 1
        let events = allEvents.isEmpty ? todayEvents : allEvents
        lock.unlock()
        completion(.success(events))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        lock.lock()
        fetchXPEventsRangeCount += 1
        let sourceEvents = allEvents.isEmpty ? todayEvents : allEvents
        let events = sourceEvents.filter { $0.createdAt >= startDate && $0.createdAt < endDate }
        let delay = rangeFetchDelay
        lock.unlock()

        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                completion(.success(events))
            }
            return
        }

        completion(.success(events))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        lock.lock()
        fetchAchievementUnlocksCount += 1
        let unlocks = achievements
        lock.unlock()
        completion(.success(unlocks))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        lock.lock()
        fetchDailyAggregateCount += 1
        let aggregate = dailyAggregatesByDateKey[dateKey]
        lock.unlock()
        completion(.success(aggregate))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        lock.lock()
        fetchDailyAggregatesCount += 1
        let values = weekAggregates.filter { $0.dateKey >= startDateKey && $0.dateKey <= endDateKey }
        lock.unlock()
        completion(.success(values.sorted { $0.dateKey < $1.dateKey }))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        lock.lock()
        fetchFocusSessionsCount += 1
        let sessions = focusSessions.filter { $0.startedAt >= startDate && $0.startedAt < endDate }
        lock.unlock()
        completion(.success(sessions))
    }
}

private final class InsightsReminderRepositorySpy: ReminderRepositoryProtocol {
    var reminders: [ReminderDefinition] = []
    var deliveriesByReminderID: [UUID: [ReminderDeliveryDefinition]] = [:]

    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void) {
        completion(.success(reminders))
    }

    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) {
        completion(.success(reminder))
    }

    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void) {
        completion(.success(trigger))
    }

    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void) {
        completion(.success(deliveriesByReminderID[reminderID] ?? []))
    }

    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        completion(.success(delivery))
    }

    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        completion(.success(delivery))
    }
}
