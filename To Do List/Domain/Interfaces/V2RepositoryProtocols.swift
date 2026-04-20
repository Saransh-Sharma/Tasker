import Foundation

public protocol LifeAreaRepositoryProtocol {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void)
    /// Executes create.
    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void)
    /// Executes update.
    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol SectionRepositoryProtocol {
    /// Executes fetchSections.
    func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void)
    /// Executes create.
    func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void)
    /// Executes update.
    func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TagRepositoryProtocol {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void)
    /// Executes create.
    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TaskDefinitionRepositoryProtocol {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void)
    /// Executes fetchAll.
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void)
    /// Executes fetchTaskDefinition.
    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void)
    /// Executes create.
    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    /// Executes create.
    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    /// Executes update.
    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    /// Executes update.
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void)
    /// Executes fetchChildren.
    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TaskTagLinkRepositoryProtocol {
    /// Executes fetchTagIDs.
    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void)
    /// Executes replaceTagLinks.
    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol TaskDependencyRepositoryProtocol {
    /// Executes fetchDependencies.
    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void)
    /// Executes replaceDependencies.
    func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

public protocol HabitRepositoryProtocol {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void)
    /// Executes create.
    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void)
    /// Executes update.
    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol ScheduleRepositoryProtocol {
    /// Executes fetchTemplates.
    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void)
    /// Executes fetchRules.
    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void)
    /// Executes saveTemplate.
    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void)
    /// Executes deleteTemplate.
    func deleteTemplate(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    /// Executes replaceRules.
    func replaceRules(
        templateID: UUID,
        rules: [ScheduleRuleDefinition],
        completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void
    )
    /// Executes fetchExceptions.
    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void)
    /// Executes saveException.
    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void)
}

public protocol OccurrenceRepositoryProtocol {
    /// Executes fetchInRange.
    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void)
    /// Executes saveOccurrences.
    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void)
    /// Executes resolve.
    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    /// Executes deleteOccurrences.
    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol ReminderRepositoryProtocol {
    /// Executes fetchReminders.
    func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void)
    /// Executes saveReminder.
    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void)
    /// Executes fetchTriggers.
    func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void)
    /// Executes saveTrigger.
    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void)
    /// Executes fetchDeliveries.
    func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void)
    /// Executes saveDelivery.
    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void)
    /// Executes updateDelivery.
    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void)
    /// Executes fetchDeliveryResponseAggregate.
    func fetchDeliveryResponseAggregate(
        from startDate: Date?,
        to endDate: Date?,
        completion: @escaping (Result<ReminderDeliveryResponseAggregate, Error>) -> Void
    )
}

public extension ReminderRepositoryProtocol {
    func fetchDeliveryResponseAggregate(
        from startDate: Date?,
        to endDate: Date?,
        completion: @escaping (Result<ReminderDeliveryResponseAggregate, Error>) -> Void
    ) {
        fetchReminders { reminderResult in
            switch reminderResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let reminders):
                guard !reminders.isEmpty else {
                    completion(.success(ReminderDeliveryResponseAggregate()))
                    return
                }

                let group = DispatchGroup()
                let lock = NSLock()
                var firstError: Error?
                var deliveries: [ReminderDeliveryDefinition] = []

                for reminder in reminders {
                    group.enter()
                    fetchDeliveries(reminderID: reminder.id) { deliveryResult in
                        lock.lock()
                        defer { lock.unlock() }
                        switch deliveryResult {
                        case .failure(let error):
                            if firstError == nil {
                                firstError = error
                            }
                        case .success(let fetched):
                            deliveries.append(contentsOf: fetched)
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let firstError {
                        completion(.failure(firstError))
                        return
                    }

                    var acknowledged = 0
                    var snoozed = 0
                    var pending = 0

                    for delivery in deliveries {
                        if let startDate,
                           delivery.createdAt < startDate {
                            continue
                        }
                        if let endDate,
                           delivery.createdAt >= endDate {
                            continue
                        }
                        let normalizedStatus = delivery.status
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased()
                        if delivery.ackAt != nil || normalizedStatus == "acked" || normalizedStatus == "acknowledged" {
                            acknowledged += 1
                        } else if delivery.snoozedUntil != nil || normalizedStatus == "snoozed" {
                            snoozed += 1
                        } else {
                            pending += 1
                        }
                    }

                    completion(
                        .success(
                            ReminderDeliveryResponseAggregate(
                                configuredReminderCount: reminders.count,
                                totalDeliveries: acknowledged + snoozed + pending,
                                acknowledgedDeliveries: acknowledged,
                                snoozedDeliveries: snoozed,
                                pendingDeliveries: pending
                            )
                        )
                    )
                }
            }
        }
    }
}

public protocol WeeklyPlanRepositoryProtocol {
    func fetchPlan(id: UUID, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void)
    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void)
    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping (Result<[WeeklyPlan], Error>) -> Void)
    func savePlan(_ plan: WeeklyPlan, completion: @escaping (Result<WeeklyPlan, Error>) -> Void)
}

public protocol WeeklyOutcomeRepositoryProtocol {
    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void)
    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping (Result<WeeklyOutcome, Error>) -> Void)
    func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void
    )
    func deleteOutcome(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol WeeklyReviewRepositoryProtocol {
    func fetchReview(weeklyPlanID: UUID, completion: @escaping (Result<WeeklyReview?, Error>) -> Void)
    func saveReview(_ review: WeeklyReview, completion: @escaping (Result<WeeklyReview, Error>) -> Void)
}

public protocol WeeklyReviewMutationRepositoryProtocol {
    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping (Result<CompleteWeeklyReviewResult, Error>) -> Void
    )
}

public protocol WeeklyReviewDraftStoreProtocol {
    func fetchDraft(
        weekStartDate: Date,
        completion: @escaping (Result<WeeklyReviewDraft?, Error>) -> Void
    )
    func saveDraft(
        _ draft: WeeklyReviewDraft,
        completion: @escaping (Result<WeeklyReviewDraft, Error>) -> Void
    )
    func clearDraft(
        weekStartDate: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    )
    func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    )
}

public protocol ReflectionNoteRepositoryProtocol {
    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping (Result<[ReflectionNote], Error>) -> Void)
    func saveNote(_ note: ReflectionNote, completion: @escaping (Result<ReflectionNote, Error>) -> Void)
    func deleteNote(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

public enum GamificationRepositoryWriteError: Error, Equatable {
    case idempotentReplay(idempotencyKey: String)
}

public protocol GamificationRepositoryProtocol {
    // MARK: - Profile
    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void)
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void)

    // MARK: - XP Events
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void)
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void)
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void)

    // MARK: - Achievement Unlocks
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void)
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void)

    // MARK: - Daily XP Aggregates
    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void)
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void)

    // MARK: - Focus Sessions
    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void)
}

public protocol AssistantActionRepositoryProtocol {
    /// Executes createRun.
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void)
    /// Executes updateRun.
    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void)
    /// Executes fetchRun.
    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void)
}

public protocol ExternalSyncRepositoryProtocol {
    /// Executes fetchContainerMappings.
    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void)
    /// Executes saveContainerMapping.
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    /// Executes fetchContainerMapping.
    func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void
    )
    /// Executes upsertContainerMapping.
    func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void
    )
    /// Executes fetchItemMappings.
    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void)
    /// Executes saveItemMapping.
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    /// Executes upsertItemMappingByLocalKey.
    func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    )
    /// Executes upsertItemMappingByExternalKey.
    func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    )
    /// Executes fetchItemMapping.
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void)
    /// Executes fetchItemMapping.
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void)
}

public protocol TombstoneRepositoryProtocol {
    /// Executes create.
    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void)
    /// Executes fetchExpired.
    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void)
    /// Executes delete.
    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
}
