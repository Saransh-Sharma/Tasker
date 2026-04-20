import Foundation

struct SyncWriteGate {
    private let modeProvider: () -> PersistentSyncMode

    init(modeProvider: @escaping () -> PersistentSyncMode = { AppDelegate.persistentSyncMode }) {
        self.modeProvider = modeProvider
    }

    func performWrite<T>(
        operation: String,
        completion: @escaping (Result<T, Error>) -> Void,
        perform: () -> Void
    ) {
        switch modeProvider() {
        case .fullSync:
            perform()
        case .writeClosed(let reason):
            completion(.failure(SyncWriteClosedError(operation: operation, reason: reason)))
        }
    }
}

struct SyncWriteClosedError: LocalizedError {
    let operation: String
    let reason: String

    var errorDescription: String? {
        "Sync unavailable, read-only mode. Recover from iCloud to resume editing."
    }

    var failureReason: String? {
        "Blocked write operation '\(operation)' because sync mode is write-closed (\(reason))."
    }
}

final class WriteClosedProjectRepositoryAdapter: ProjectRepositoryProtocol {
    private let base: ProjectRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: ProjectRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        base.fetchAllProjects(completion: completion)
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        base.fetchProject(withId: id, completion: completion)
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        base.fetchProject(withName: name, completion: completion)
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        base.fetchInboxProject(completion: completion)
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        base.fetchCustomProjects(completion: completion)
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        gate.performWrite(operation: "ProjectRepository.createProject", completion: completion) {
            self.base.createProject(project, completion: completion)
        }
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        gate.performWrite(operation: "ProjectRepository.ensureInboxProject", completion: completion) {
            self.base.ensureInboxProject(completion: completion)
        }
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        gate.performWrite(operation: "ProjectRepository.repairProjectIdentityCollisions", completion: completion) {
            self.base.repairProjectIdentityCollisions(completion: completion)
        }
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        gate.performWrite(operation: "ProjectRepository.updateProject", completion: completion) {
            self.base.updateProject(project, completion: completion)
        }
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        gate.performWrite(operation: "ProjectRepository.renameProject", completion: completion) {
            self.base.renameProject(withId: id, to: newName, completion: completion)
        }
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "ProjectRepository.deleteProject", completion: completion) {
            self.base.deleteProject(withId: id, deleteTasks: deleteTasks, completion: completion)
        }
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        base.getTaskCount(for: projectId, completion: completion)
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "ProjectRepository.moveTasks", completion: completion) {
            self.base.moveTasks(from: sourceProjectId, to: targetProjectId, completion: completion)
        }
    }

    func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
        gate.performWrite(operation: "ProjectRepository.moveProjectToLifeArea", completion: completion) {
            self.base.moveProjectToLifeArea(
                projectID: projectID,
                lifeAreaID: lifeAreaID,
                completion: completion
            )
        }
    }

    func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    ) {
        gate.performWrite(operation: "ProjectRepository.backfillProjectsWithoutLifeArea", completion: completion) {
            self.base.backfillProjectsWithoutLifeArea(
                defaultLifeAreaID: defaultLifeAreaID,
                completion: completion
            )
        }
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        base.isProjectNameAvailable(name, excludingId: excludingId, completion: completion)
    }
}

final class WriteClosedTaskDefinitionRepositoryAdapter: TaskDefinitionRepositoryProtocol {
    private let base: TaskDefinitionRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: TaskDefinitionRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchAll(completion: completion)
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchAll(query: query, completion: completion)
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        base.fetchTaskDefinition(id: id, completion: completion)
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        gate.performWrite(operation: "TaskDefinitionRepository.create", completion: completion) {
            self.base.create(task, completion: completion)
        }
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        gate.performWrite(operation: "TaskDefinitionRepository.createRequest", completion: completion) {
            self.base.create(request: request, completion: completion)
        }
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        gate.performWrite(operation: "TaskDefinitionRepository.update", completion: completion) {
            self.base.update(task, completion: completion)
        }
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        gate.performWrite(operation: "TaskDefinitionRepository.updateRequest", completion: completion) {
            self.base.update(request: request, completion: completion)
        }
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        base.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "TaskDefinitionRepository.delete", completion: completion) {
            self.base.delete(id: id, completion: completion)
        }
    }
}

final class WriteClosedTaskTagLinkRepositoryAdapter: TaskTagLinkRepositoryProtocol {
    private let base: TaskTagLinkRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: TaskTagLinkRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) {
        base.fetchTagIDs(taskID: taskID, completion: completion)
    }

    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "TaskTagLinkRepository.replaceTagLinks", completion: completion) {
            self.base.replaceTagLinks(taskID: taskID, tagIDs: tagIDs, completion: completion)
        }
    }
}

final class WriteClosedTaskDependencyRepositoryAdapter: TaskDependencyRepositoryProtocol {
    private let base: TaskDependencyRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: TaskDependencyRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) {
        base.fetchDependencies(taskID: taskID, completion: completion)
    }

    func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        gate.performWrite(operation: "TaskDependencyRepository.replaceDependencies", completion: completion) {
            self.base.replaceDependencies(taskID: taskID, dependencies: dependencies, completion: completion)
        }
    }
}

final class WriteClosedLifeAreaRepositoryAdapter: LifeAreaRepositoryProtocol {
    private let base: LifeAreaRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: LifeAreaRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        base.fetchAll(completion: completion)
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        gate.performWrite(operation: "LifeAreaRepository.create", completion: completion) {
            self.base.create(area, completion: completion)
        }
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        gate.performWrite(operation: "LifeAreaRepository.update", completion: completion) {
            self.base.update(area, completion: completion)
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "LifeAreaRepository.delete", completion: completion) {
            self.base.delete(id: id, completion: completion)
        }
    }
}

final class WriteClosedSectionRepositoryAdapter: SectionRepositoryProtocol {
    private let base: SectionRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: SectionRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void) {
        base.fetchSections(projectID: projectID, completion: completion)
    }

    func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        gate.performWrite(operation: "SectionRepository.create", completion: completion) {
            self.base.create(section, completion: completion)
        }
    }

    func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        gate.performWrite(operation: "SectionRepository.update", completion: completion) {
            self.base.update(section, completion: completion)
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "SectionRepository.delete", completion: completion) {
            self.base.delete(id: id, completion: completion)
        }
    }
}

final class WriteClosedTagRepositoryAdapter: TagRepositoryProtocol {
    private let base: TagRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: TagRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) {
        base.fetchAll(completion: completion)
    }

    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) {
        gate.performWrite(operation: "TagRepository.create", completion: completion) {
            self.base.create(tag, completion: completion)
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "TagRepository.delete", completion: completion) {
            self.base.delete(id: id, completion: completion)
        }
    }
}

final class WriteClosedHabitRepositoryAdapter: HabitRepositoryProtocol {
    private let base: HabitRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: HabitRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) {
        base.fetchAll(completion: completion)
    }

    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        gate.performWrite(operation: "HabitRepository.create", completion: completion) {
            self.base.create(habit, completion: completion)
        }
    }

    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        gate.performWrite(operation: "HabitRepository.update", completion: completion) {
            self.base.update(habit, completion: completion)
        }
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "HabitRepository.delete", completion: completion) {
            self.base.delete(id: id, completion: completion)
        }
    }
}

final class WriteClosedScheduleRepositoryAdapter: ScheduleRepositoryProtocol {
    private let base: ScheduleRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: ScheduleRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) {
        base.fetchTemplates(completion: completion)
    }

    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        base.fetchRules(templateID: templateID, completion: completion)
    }

    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) {
        gate.performWrite(operation: "ScheduleRepository.saveTemplate", completion: completion) {
            self.base.saveTemplate(template, completion: completion)
        }
    }

    func deleteTemplate(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "ScheduleRepository.deleteTemplate", completion: completion) {
            self.base.deleteTemplate(id: id, completion: completion)
        }
    }

    func replaceRules(
        templateID: UUID,
        rules: [ScheduleRuleDefinition],
        completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void
    ) {
        gate.performWrite(operation: "ScheduleRepository.replaceRules", completion: completion) {
            self.base.replaceRules(templateID: templateID, rules: rules, completion: completion)
        }
    }

    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) {
        base.fetchExceptions(templateID: templateID, completion: completion)
    }

    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) {
        gate.performWrite(operation: "ScheduleRepository.saveException", completion: completion) {
            self.base.saveException(exception, completion: completion)
        }
    }
}

final class WriteClosedOccurrenceRepositoryAdapter: OccurrenceRepositoryProtocol {
    private let base: OccurrenceRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: OccurrenceRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) {
        base.fetchInRange(start: start, end: end, completion: completion)
    }

    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "OccurrenceRepository.saveOccurrences", completion: completion) {
            self.base.saveOccurrences(occurrences, completion: completion)
        }
    }

    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "OccurrenceRepository.resolve", completion: completion) {
            self.base.resolve(resolution, completion: completion)
        }
    }

    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "OccurrenceRepository.deleteOccurrences", completion: completion) {
            self.base.deleteOccurrences(ids: ids, completion: completion)
        }
    }
}

final class WriteClosedReminderRepositoryAdapter: ReminderRepositoryProtocol {
    private let base: ReminderRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: ReminderRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void) {
        base.fetchReminders(completion: completion)
    }

    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) {
        gate.performWrite(operation: "ReminderRepository.saveReminder", completion: completion) {
            self.base.saveReminder(reminder, completion: completion)
        }
    }

    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void) {
        base.fetchTriggers(reminderID: reminderID, completion: completion)
    }

    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void) {
        gate.performWrite(operation: "ReminderRepository.saveTrigger", completion: completion) {
            self.base.saveTrigger(trigger, completion: completion)
        }
    }

    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void) {
        base.fetchDeliveries(reminderID: reminderID, completion: completion)
    }

    func fetchDeliveryResponseAggregate(
        from startDate: Date?,
        to endDate: Date?,
        completion: @escaping (Result<ReminderDeliveryResponseAggregate, Error>) -> Void
    ) {
        base.fetchDeliveryResponseAggregate(from: startDate, to: endDate, completion: completion)
    }

    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        gate.performWrite(operation: "ReminderRepository.saveDelivery", completion: completion) {
            self.base.saveDelivery(delivery, completion: completion)
        }
    }

    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        gate.performWrite(operation: "ReminderRepository.updateDelivery", completion: completion) {
            self.base.updateDelivery(delivery, completion: completion)
        }
    }
}

final class WriteClosedWeeklyPlanRepositoryAdapter: WeeklyPlanRepositoryProtocol {
    private let base: WeeklyPlanRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyPlanRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchPlan(id: UUID, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        base.fetchPlan(id: id, completion: completion)
    }

    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        base.fetchPlan(forWeekStarting: weekStartDate, completion: completion)
    }

    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping (Result<[WeeklyPlan], Error>) -> Void) {
        base.fetchPlans(from: startDate, to: endDate, completion: completion)
    }

    func savePlan(_ plan: WeeklyPlan, completion: @escaping (Result<WeeklyPlan, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyPlanRepository.savePlan", completion: completion) {
            self.base.savePlan(plan, completion: completion)
        }
    }
}

final class WriteClosedWeeklyOutcomeRepositoryAdapter: WeeklyOutcomeRepositoryProtocol {
    private let base: WeeklyOutcomeRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyOutcomeRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void) {
        base.fetchOutcomes(weeklyPlanID: weeklyPlanID, completion: completion)
    }

    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping (Result<WeeklyOutcome, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyOutcomeRepository.saveOutcome", completion: completion) {
            self.base.saveOutcome(outcome, completion: completion)
        }
    }

    func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void
    ) {
        gate.performWrite(operation: "WeeklyOutcomeRepository.replaceOutcomes", completion: completion) {
            self.base.replaceOutcomes(
                weeklyPlanID: weeklyPlanID,
                outcomes: outcomes,
                completion: completion
            )
        }
    }

    func deleteOutcome(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyOutcomeRepository.deleteOutcome", completion: completion) {
            self.base.deleteOutcome(id: id, completion: completion)
        }
    }
}

final class WriteClosedWeeklyReviewRepositoryAdapter: WeeklyReviewRepositoryProtocol {
    private let base: WeeklyReviewRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyReviewRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchReview(weeklyPlanID: UUID, completion: @escaping (Result<WeeklyReview?, Error>) -> Void) {
        base.fetchReview(weeklyPlanID: weeklyPlanID, completion: completion)
    }

    func saveReview(_ review: WeeklyReview, completion: @escaping (Result<WeeklyReview, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyReviewRepository.saveReview", completion: completion) {
            self.base.saveReview(review, completion: completion)
        }
    }
}

final class WriteClosedWeeklyReviewMutationRepositoryAdapter: WeeklyReviewMutationRepositoryProtocol {
    private let base: WeeklyReviewMutationRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyReviewMutationRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping (Result<CompleteWeeklyReviewResult, Error>) -> Void
    ) {
        gate.performWrite(operation: "WeeklyReviewMutationRepository.finalizeReview", completion: completion) {
            self.base.finalizeReview(request: request, completion: completion)
        }
    }
}

final class WriteClosedReflectionNoteRepositoryAdapter: ReflectionNoteRepositoryProtocol {
    private let base: ReflectionNoteRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: ReflectionNoteRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping (Result<[ReflectionNote], Error>) -> Void) {
        base.fetchNotes(query: query, completion: completion)
    }

    func saveNote(_ note: ReflectionNote, completion: @escaping (Result<ReflectionNote, Error>) -> Void) {
        gate.performWrite(operation: "ReflectionNoteRepository.saveNote", completion: completion) {
            self.base.saveNote(note, completion: completion)
        }
    }

    func deleteNote(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "ReflectionNoteRepository.deleteNote", completion: completion) {
            self.base.deleteNote(id: id, completion: completion)
        }
    }
}

final class WriteClosedGamificationRepositoryAdapter: GamificationRepositoryProtocol {
    private let base: GamificationRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: GamificationRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        base.fetchProfile(completion: completion)
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "GamificationRepository.saveProfile", completion: completion) {
            self.base.saveProfile(profile, completion: completion)
        }
    }

    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        base.fetchXPEvents(completion: completion)
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        base.fetchXPEvents(from: startDate, to: endDate, completion: completion)
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "GamificationRepository.saveXPEvent", completion: completion) {
            self.base.saveXPEvent(event, completion: completion)
        }
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        base.hasXPEvent(idempotencyKey: idempotencyKey, completion: completion)
    }

    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        base.fetchAchievementUnlocks(completion: completion)
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "GamificationRepository.saveAchievementUnlock", completion: completion) {
            self.base.saveAchievementUnlock(unlock, completion: completion)
        }
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        base.fetchDailyAggregate(dateKey: dateKey, completion: completion)
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "GamificationRepository.saveDailyAggregate", completion: completion) {
            self.base.saveDailyAggregate(aggregate, completion: completion)
        }
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        base.fetchDailyAggregates(from: startDateKey, to: endDateKey, completion: completion)
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "GamificationRepository.createFocusSession", completion: completion) {
            self.base.createFocusSession(session, completion: completion)
        }
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "GamificationRepository.updateFocusSession", completion: completion) {
            self.base.updateFocusSession(session, completion: completion)
        }
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        base.fetchFocusSessions(from: startDate, to: endDate, completion: completion)
    }
}

final class WriteClosedAssistantActionRepositoryAdapter: AssistantActionRepositoryProtocol {
    private let base: AssistantActionRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: AssistantActionRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        gate.performWrite(operation: "AssistantActionRepository.createRun", completion: completion) {
            self.base.createRun(run, completion: completion)
        }
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        gate.performWrite(operation: "AssistantActionRepository.updateRun", completion: completion) {
            self.base.updateRun(run, completion: completion)
        }
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        base.fetchRun(id: id, completion: completion)
    }
}

final class WriteClosedExternalSyncRepositoryAdapter: ExternalSyncRepositoryProtocol {
    private let base: ExternalSyncRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: ExternalSyncRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) {
        base.fetchContainerMappings(completion: completion)
    }

    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "ExternalSyncRepository.saveContainerMapping", completion: completion) {
            self.base.saveContainerMapping(mapping, completion: completion)
        }
    }

    func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void
    ) {
        base.fetchContainerMapping(provider: provider, projectID: projectID, completion: completion)
    }

    func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void
    ) {
        gate.performWrite(operation: "ExternalSyncRepository.upsertContainerMapping", completion: completion) {
            self.base.upsertContainerMapping(
                provider: provider,
                projectID: projectID,
                mutate: mutate,
                completion: completion
            )
        }
    }

    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) {
        base.fetchItemMappings(completion: completion)
    }

    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "ExternalSyncRepository.saveItemMapping", completion: completion) {
            self.base.saveItemMapping(mapping, completion: completion)
        }
    }

    func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        gate.performWrite(operation: "ExternalSyncRepository.upsertItemMappingByLocalKey", completion: completion) {
            self.base.upsertItemMappingByLocalKey(
                provider: provider,
                localEntityType: localEntityType,
                localEntityID: localEntityID,
                mutate: mutate,
                completion: completion
            )
        }
    }

    func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        gate.performWrite(operation: "ExternalSyncRepository.upsertItemMappingByExternalKey", completion: completion) {
            self.base.upsertItemMappingByExternalKey(
                provider: provider,
                externalItemID: externalItemID,
                mutate: mutate,
                completion: completion
            )
        }
    }

    func fetchItemMapping(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        base.fetchItemMapping(
            provider: provider,
            localEntityType: localEntityType,
            localEntityID: localEntityID,
            completion: completion
        )
    }

    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) {
        base.fetchItemMapping(provider: provider, externalItemID: externalItemID, completion: completion)
    }
}

final class WriteClosedTombstoneRepositoryAdapter: TombstoneRepositoryProtocol {
    private let base: TombstoneRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: TombstoneRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "TombstoneRepository.create", completion: completion) {
            self.base.create(tombstone, completion: completion)
        }
    }

    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) {
        base.fetchExpired(before: date, completion: completion)
    }

    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "TombstoneRepository.delete", completion: completion) {
            self.base.delete(ids: ids, completion: completion)
        }
    }
}
