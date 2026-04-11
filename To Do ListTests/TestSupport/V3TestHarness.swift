import Foundation
@testable import To_Do_List

// Shared V3-focused test harness utilities for building coordinators/mocks without
// relying on legacy task shim protocols.
enum V3TestHarness {
    static func makeCoordinator(
        taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        projectRepository: ProjectRepositoryProtocol,
        habitRepository: HabitRepositoryProtocol = NoopHabitRepository(),
        habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol = NoopHabitRuntimeReadRepository(),
        scheduleRepository: ScheduleRepositoryProtocol = NoopScheduleRepository(),
        scheduleEngine: SchedulingEngineProtocol = NoopSchedulingEngine(),
        occurrenceRepository: OccurrenceRepositoryProtocol = NoopOccurrenceRepository(),
        gamificationRepository: GamificationRepositoryProtocol = NoopGamificationRepository(),
        cacheService: CacheServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) -> UseCaseCoordinator {
        let dependencies = UseCaseCoordinator.V2Dependencies(
            projectRepository: projectRepository,
            lifeAreaRepository: NoopLifeAreaRepository(),
            sectionRepository: NoopSectionRepository(),
            tagRepository: NoopTagRepository(),
            taskDefinitionRepository: taskDefinitionRepository,
            taskTagLinkRepository: NoopTaskTagLinkRepository(),
            taskDependencyRepository: NoopTaskDependencyRepository(),
            habitRepository: habitRepository,
            habitRuntimeReadRepository: habitRuntimeReadRepository,
            scheduleRepository: scheduleRepository,
            scheduleEngine: scheduleEngine,
            occurrenceRepository: occurrenceRepository,
            tombstoneRepository: NoopTombstoneRepository(),
            reminderRepository: NoopReminderRepository(),
            gamificationRepository: gamificationRepository,
            assistantActionRepository: NoopAssistantActionRepository(),
            externalSyncRepository: NoopExternalSyncRepository(),
            remindersProvider: nil
        )

        return UseCaseCoordinator(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            cacheService: cacheService,
            notificationService: notificationService,
            v2Dependencies: dependencies
        )
    }
}

final class InMemoryTaskDefinitionRepositoryStub: TaskDefinitionRepositoryProtocol {
    var byID: [UUID: TaskDefinition]

    init(seed: [TaskDefinition] = []) {
        self.byID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        guard let query else {
            completion(.success(Array(byID.values)))
            return
        }

        let filtered = byID.values.filter { task in
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

        completion(.success(Array(filtered)))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
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
            completion(.failure(NSError(domain: "InMemoryTaskDefinitionRepositoryStub", code: 404)))
            return
        }

        if let title = request.title { current.title = title }
        if let details = request.details { current.details = details }
        if let projectID = request.projectID { current.projectID = projectID }
        if request.clearLifeArea {
            current.lifeAreaID = nil
        } else if let lifeAreaID = request.lifeAreaID {
            current.lifeAreaID = lifeAreaID
        }
        if request.clearSection {
            current.sectionID = nil
        } else if let sectionID = request.sectionID {
            current.sectionID = sectionID
        }
        if request.clearDueDate {
            current.dueDate = nil
        } else if let dueDate = request.dueDate {
            current.dueDate = dueDate
        }
        if let parentTaskID = request.parentTaskID { current.parentTaskID = parentTaskID }
        if request.clearParentTaskLink { current.parentTaskID = nil }
        if let tagIDs = request.tagIDs { current.tagIDs = tagIDs }
        if let dependencies = request.dependencies { current.dependencies = dependencies }
        if let priority = request.priority { current.priority = priority }
        if let type = request.type { current.type = type }
        if let energy = request.energy { current.energy = energy }
        if let category = request.category { current.category = category }
        if let context = request.context { current.context = context }
        if let isComplete = request.isComplete {
            current.isComplete = isComplete
            if isComplete == false { current.dateCompleted = nil }
        }
        if let dateCompleted = request.dateCompleted { current.dateCompleted = dateCompleted }
        if request.clearReminderTime {
            current.alertReminderTime = nil
        } else if let alertReminderTime = request.alertReminderTime {
            current.alertReminderTime = alertReminderTime
        }
        if request.clearEstimatedDuration {
            current.estimatedDuration = nil
        } else if let estimatedDuration = request.estimatedDuration {
            current.estimatedDuration = estimatedDuration
        }
        if let actualDuration = request.actualDuration { current.actualDuration = actualDuration }
        if request.clearRepeatPattern {
            current.repeatPattern = nil
        } else if let repeatPattern = request.repeatPattern {
            current.repeatPattern = repeatPattern
        }
        current.updatedAt = request.updatedAt

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

final class InMemoryTaskReadModelRepositoryStub: TaskReadModelRepositoryProtocol {
    var tasks: [TaskDefinition]

    init(tasks: [TaskDefinition] = []) {
        self.tasks = tasks
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if !query.includeCompleted && task.isComplete { return false }
            if let start = query.dueDateStart {
                guard let dueDate = task.dueDate, dueDate >= start else { return false }
            }
            if let end = query.dueDateEnd {
                guard let dueDate = task.dueDate, dueDate <= end else { return false }
            }
            if let updatedAfter = query.updatedAfter, task.updatedAt < updatedAfter { return false }
            return true
        }

        let total = filtered.count
        let start = min(max(0, query.offset), total)
        let end = min(start + max(1, query.limit), total)

        completion(.success(TaskDefinitionSliceResult(
            tasks: Array(filtered[start..<end]),
            totalCount: total,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        let needle = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = tasks.filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if !query.includeCompleted && task.isComplete { return false }
            if needle.isEmpty { return true }
            let inTitle = task.title.lowercased().contains(needle)
            let inDetails = task.details?.lowercased().contains(needle) ?? false
            return inTitle || inDetails
        }

        let total = filtered.count
        let start = min(max(0, query.offset), total)
        let end = min(start + max(1, query.limit), total)

        completion(.success(TaskDefinitionSliceResult(
            tasks: Array(filtered[start..<end]),
            totalCount: total,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func fetchProjectTaskCounts(includeCompleted: Bool, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        var counts: [UUID: Int] = [:]
        for task in tasks where includeCompleted || !task.isComplete {
            counts[task.projectID, default: 0] += 1
        }
        completion(.success(counts))
    }

    func fetchProjectCompletionScoreTotals(from startDate: Date, to endDate: Date, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        var totals: [UUID: Int] = [:]
        for task in tasks {
            guard task.isComplete, let completedAt = task.dateCompleted else { continue }
            guard completedAt >= startDate && completedAt <= endDate else { continue }
            totals[task.projectID, default: 0] += task.priority.scorePoints
        }
        completion(.success(totals))
    }
}

private final class NoopLifeAreaRepository: LifeAreaRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) { completion(.success([])) }
    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) { completion(.success(area)) }
    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) { completion(.success(area)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopSectionRepository: SectionRepositoryProtocol {
    func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void) { completion(.success([])) }
    func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) { completion(.success(section)) }
    func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) { completion(.success(section)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopTagRepository: TagRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) { completion(.success([])) }
    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) { completion(.success(tag)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopTaskTagLinkRepository: TaskTagLinkRepositoryProtocol {
    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) { completion(.success([])) }
    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopTaskDependencyRepository: TaskDependencyRepositoryProtocol {
    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) { completion(.success([])) }
    func replaceDependencies(taskID: UUID, dependencies: [TaskDependencyLinkDefinition], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopHabitRepository: HabitRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) { completion(.success([])) }
    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) { completion(.success(habit)) }
    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) { completion(.success(habit)) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopHabitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol {
    func fetchAgendaHabits(for date: Date, completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func fetchSignals(start: Date, end: Date, completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchHabitLibrary(includeArchived: Bool, completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void) {
        completion(.success([]))
    }
}

private final class NoopScheduleRepository: ScheduleRepositoryProtocol {
    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) { completion(.success([])) }
    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) { completion(.success(template)) }
    func deleteTemplate(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func replaceRules(templateID: UUID, rules: [ScheduleRuleDefinition], completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) { completion(.success(rules)) }
    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) { completion(.success([])) }
    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) { completion(.success(exception)) }
}

private final class NoopSchedulingEngine: SchedulingEngineProtocol {
    func generateOccurrences(windowStart: Date, windowEnd: Date, sourceFilter: ScheduleSourceType?, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) { completion(.success([])) }
    func resolveOccurrence(id: UUID, resolution: OccurrenceResolutionType, actor: OccurrenceActor, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func rebuildFutureOccurrences(templateID: UUID, effectiveFrom: Date, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func applyScheduleException(templateID: UUID, occurrenceKey: String, action: ScheduleExceptionAction, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopOccurrenceRepository: OccurrenceRepositoryProtocol {
    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) { completion(.success([])) }
    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopTombstoneRepository: TombstoneRepositoryProtocol {
    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopReminderRepository: ReminderRepositoryProtocol {
    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void) { completion(.success([])) }
    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) { completion(.success(reminder)) }
    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void) { completion(.success([])) }
    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void) { completion(.success(trigger)) }
    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void) { completion(.success([])) }
    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
}

private final class NoopGamificationRepository: GamificationRepositoryProtocol {
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

private final class NoopAssistantActionRepository: AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) { completion(.success(nil)) }
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
