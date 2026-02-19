import Foundation

public protocol LifeAreaRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void)
    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void)
    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol SectionRepositoryProtocol {
    func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void)
    func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void)
    func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TagRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void)
    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TaskDefinitionRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void)
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void)
    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void)
    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TaskTagLinkRepositoryProtocol {
    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void)
    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TaskDependencyRepositoryProtocol {
    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void)
    func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

public protocol HabitRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void)
    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void)
    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol ScheduleRepositoryProtocol {
    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void)
    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void)
    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void)
    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void)
    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void)
}

public protocol OccurrenceRepositoryProtocol {
    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void)
    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void)
    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol ReminderRepositoryProtocol {
    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void)
    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void)
    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void)
    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void)
    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void)
    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void)
    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void)
}

public protocol GamificationRepositoryProtocol {
    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void)
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void)
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void)
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void)
    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void)
    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void)
}

public protocol ExternalSyncRepositoryProtocol {
    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void)
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void
    )
    func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void
    )
    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void)
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    )
    func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    )
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void)
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void)
}

public protocol TombstoneRepositoryProtocol {
    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void)
    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
}
