import Foundation

private final class V2RepositoryFetchAccumulator<State: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State
    private var firstError: Error?

    init(_ state: State) {
        self.state = state
    }

    func update(_ body: (inout State) -> Void) {
        lock.lock()
        body(&state)
        lock.unlock()
    }

    func record(_ error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func result() -> Result<State, Error> {
        lock.lock()
        let state = state
        let firstError = firstError
        lock.unlock()

        if let firstError {
            return .failure(firstError)
        }
        return .success(state)
    }
}

public protocol LifeAreaRepositoryProtocol: Sendable {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping @Sendable (Result<[LifeArea], Error>) -> Void)
    /// Executes create.
    func create(_ area: LifeArea, completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void)
    /// Executes update.
    func update(_ area: LifeArea, completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol SectionRepositoryProtocol: Sendable {
    /// Executes fetchSections.
    func fetchSections(projectID: UUID, completion: @escaping @Sendable (Result<[TaskerProjectSection], Error>) -> Void)
    /// Executes create.
    func create(_ section: TaskerProjectSection, completion: @escaping @Sendable (Result<TaskerProjectSection, Error>) -> Void)
    /// Executes update.
    func update(_ section: TaskerProjectSection, completion: @escaping @Sendable (Result<TaskerProjectSection, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol TagRepositoryProtocol: Sendable {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping @Sendable (Result<[TagDefinition], Error>) -> Void)
    /// Executes create.
    func create(_ tag: TagDefinition, completion: @escaping @Sendable (Result<TagDefinition, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol TaskDefinitionRepositoryProtocol: Sendable {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void)
    /// Executes fetchAll.
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void)
    /// Executes fetchTaskDefinition.
    func fetchTaskDefinition(id: UUID, completion: @escaping @Sendable (Result<TaskDefinition?, Error>) -> Void)
    /// Executes create.
    func create(_ task: TaskDefinition, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void)
    /// Executes create.
    func create(request: CreateTaskDefinitionRequest, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void)
    /// Executes update.
    func update(_ task: TaskDefinition, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void)
    /// Executes update.
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void)
    /// Executes fetchChildren.
    func fetchChildren(parentTaskID: UUID, completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol TaskTagLinkRepositoryProtocol: Sendable {
    /// Executes fetchTagIDs.
    func fetchTagIDs(taskID: UUID, completion: @escaping @Sendable (Result<[UUID], Error>) -> Void)
    /// Executes replaceTagLinks.
    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol TaskDependencyRepositoryProtocol: Sendable {
    /// Executes fetchDependencies.
    func fetchDependencies(taskID: UUID, completion: @escaping @Sendable (Result<[TaskDependencyLinkDefinition], Error>) -> Void)
    /// Executes replaceDependencies.
    func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    )
}

public protocol HabitRepositoryProtocol: Sendable {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping @Sendable (Result<[HabitDefinitionRecord], Error>) -> Void)
    /// Executes fetchByID.
    func fetchByID(id: UUID, completion: @escaping @Sendable (Result<HabitDefinitionRecord?, Error>) -> Void)
    /// Executes create.
    func create(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void)
    /// Executes update.
    func update(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol ScheduleRepositoryProtocol: Sendable {
    /// Executes fetchTemplates.
    func fetchTemplates(completion: @escaping @Sendable (Result<[ScheduleTemplateDefinition], Error>) -> Void)
    /// Executes fetchRules.
    func fetchRules(templateID: UUID, completion: @escaping @Sendable (Result<[ScheduleRuleDefinition], Error>) -> Void)
    /// Executes saveTemplate.
    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping @Sendable (Result<ScheduleTemplateDefinition, Error>) -> Void)
    /// Executes deleteTemplate.
    func deleteTemplate(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    /// Executes replaceRules.
    func replaceRules(
        templateID: UUID,
        rules: [ScheduleRuleDefinition],
        completion: @escaping @Sendable (Result<[ScheduleRuleDefinition], Error>) -> Void
    )
    /// Executes fetchExceptions.
    func fetchExceptions(templateID: UUID, completion: @escaping @Sendable (Result<[ScheduleExceptionDefinition], Error>) -> Void)
    /// Executes saveException.
    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping @Sendable (Result<ScheduleExceptionDefinition, Error>) -> Void)
}

public protocol OccurrenceRepositoryProtocol: Sendable {
    /// Executes fetchInRange.
    func fetchInRange(start: Date, end: Date, completion: @escaping @Sendable (Result<[OccurrenceDefinition], Error>) -> Void)
    /// Executes fetchByID.
    func fetchByID(id: UUID, completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void)
    /// Executes fetchLatestForHabit.
    func fetchLatestForHabit(habitID: UUID, on date: Date, completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void)
    /// Executes saveOccurrences.
    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    /// Executes resolve.
    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    /// Executes deleteOccurrences.
    func deleteOccurrences(ids: [UUID], completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public extension HabitRepositoryProtocol {
    func fetchByID(id: UUID, completion: @escaping @Sendable (Result<HabitDefinitionRecord?, Error>) -> Void) {
        fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let habits):
                completion(.success(habits.first(where: { $0.id == id })))
            }
        }
    }
}

public extension OccurrenceRepositoryProtocol {
    func fetchByID(id: UUID, completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void) {
        fetchInRange(start: .distantPast, end: .distantFuture) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let occurrences):
                completion(.success(occurrences.first(where: { $0.id == id })))
            }
        }
    }

    func fetchLatestForHabit(
        habitID: UUID,
        on date: Date,
        completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        fetchInRange(start: startOfDay, end: endOfDay) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let occurrences):
                let latest = occurrences
                    .filter { $0.sourceType == .habit && $0.sourceID == habitID }
                    .sorted { HabitRuntimeSupport.occurrenceDate($0) < HabitRuntimeSupport.occurrenceDate($1) }
                    .last
                completion(.success(latest))
            }
        }
    }
}

public protocol ReminderRepositoryProtocol: Sendable {
    /// Executes fetchReminders.
    func fetchReminders(completion: @escaping @Sendable (Result<[ReminderDefinition], Error>) -> Void)
    /// Executes saveReminder.
    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping @Sendable (Result<ReminderDefinition, Error>) -> Void)
    /// Executes fetchTriggers.
    func fetchTriggers(reminderID: UUID, completion: @escaping @Sendable (Result<[ReminderTriggerDefinition], Error>) -> Void)
    /// Executes saveTrigger.
    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping @Sendable (Result<ReminderTriggerDefinition, Error>) -> Void)
    /// Executes fetchDeliveries.
    func fetchDeliveries(reminderID: UUID, completion: @escaping @Sendable (Result<[ReminderDeliveryDefinition], Error>) -> Void)
    /// Executes saveDelivery.
    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping @Sendable (Result<ReminderDeliveryDefinition, Error>) -> Void)
    /// Executes updateDelivery.
    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping @Sendable (Result<ReminderDeliveryDefinition, Error>) -> Void)
    /// Executes fetchDeliveryResponseAggregate.
    func fetchDeliveryResponseAggregate(
        from startDate: Date?,
        to endDate: Date?,
        completion: @escaping @Sendable (Result<ReminderDeliveryResponseAggregate, Error>) -> Void
    )
}

public extension ReminderRepositoryProtocol {
    func fetchDeliveryResponseAggregate(
        from startDate: Date?,
        to endDate: Date?,
        completion: @escaping @Sendable (Result<ReminderDeliveryResponseAggregate, Error>) -> Void
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
                let accumulator = V2RepositoryFetchAccumulator([ReminderDeliveryDefinition]())

                for reminder in reminders {
                    group.enter()
                    fetchDeliveries(reminderID: reminder.id) { deliveryResult in
                        switch deliveryResult {
                        case .failure(let error):
                            accumulator.record(error)
                        case .success(let fetched):
                            accumulator.update { $0.append(contentsOf: fetched) }
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    let deliveries: [ReminderDeliveryDefinition]
                    switch accumulator.result() {
                    case .failure(let firstError):
                        completion(.failure(firstError))
                        return
                    case .success(let fetchedDeliveries):
                        deliveries = fetchedDeliveries
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

public protocol WeeklyPlanRepositoryProtocol: Sendable {
    func fetchPlan(id: UUID, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void)
    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void)
    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[WeeklyPlan], Error>) -> Void)
    func savePlan(_ plan: WeeklyPlan, completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void)
}

public protocol WeeklyOutcomeRepositoryProtocol: Sendable {
    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void)
    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping @Sendable (Result<WeeklyOutcome, Error>) -> Void)
    func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void
    )
    func deleteOutcome(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol WeeklyReviewRepositoryProtocol: Sendable {
    func fetchReview(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<WeeklyReview?, Error>) -> Void)
    func saveReview(_ review: WeeklyReview, completion: @escaping @Sendable (Result<WeeklyReview, Error>) -> Void)
}

public protocol WeeklyReviewMutationRepositoryProtocol: Sendable {
    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping @Sendable (Result<CompleteWeeklyReviewResult, Error>) -> Void
    )
}

public protocol WeeklyReviewDraftStoreProtocol: Sendable {
    func fetchDraft(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<WeeklyReviewDraft?, Error>) -> Void
    )
    func saveDraft(
        _ draft: WeeklyReviewDraft,
        completion: @escaping @Sendable (Result<WeeklyReviewDraft, Error>) -> Void
    )
    func clearDraft(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    )
    func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    )
    func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    )
}

public protocol DailyReflectionStoreProtocol: Sendable {
    func isCompleted(on date: Date) -> Bool
    func completedDateStamps() -> Set<String>
    func fetchReflectionPayload(on date: Date) -> ReflectionPayload?
    @discardableResult
    func saveReflectionPayload(_ payload: ReflectionPayload) throws -> ReflectionPayload
    @discardableResult
    func markCompleted(
        on reflectionDate: Date,
        completedAt: Date,
        payload: ReflectionPayload?
    ) throws -> ReflectionPayload?
    func fetchPlanDraft(on date: Date) -> DailyPlanDraft?
    @discardableResult
    func savePlanDraft(_ draft: DailyPlanDraft, replaceExisting: Bool) throws -> DailyPlanDraft
    func clearPlanDraft(on date: Date) throws
}

public protocol ReflectionNoteRepositoryProtocol: Sendable {
    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping @Sendable (Result<[ReflectionNote], Error>) -> Void)
    func saveNote(_ note: ReflectionNote, completion: @escaping @Sendable (Result<ReflectionNote, Error>) -> Void)
    func deleteNote(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public enum GamificationRepositoryWriteError: Error, Equatable {
    case idempotentReplay(idempotencyKey: String)
}

public protocol GamificationRepositoryProtocol: Sendable {
    // MARK: - Profile
    func fetchProfile(completion: @escaping @Sendable (Result<GamificationSnapshot?, Error>) -> Void)
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping @Sendable (Result<Void, Error>) -> Void)

    // MARK: - XP Events
    func fetchXPEvents(completion: @escaping @Sendable (Result<[XPEventDefinition], Error>) -> Void)
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[XPEventDefinition], Error>) -> Void)
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    func hasXPEvent(idempotencyKey: String, completion: @escaping @Sendable (Result<Bool, Error>) -> Void)

    // MARK: - Achievement Unlocks
    func fetchAchievementUnlocks(completion: @escaping @Sendable (Result<[AchievementUnlockDefinition], Error>) -> Void)
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)

    // MARK: - Daily XP Aggregates
    func fetchDailyAggregate(dateKey: String, completion: @escaping @Sendable (Result<DailyXPAggregateDefinition?, Error>) -> Void)
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping @Sendable (Result<[DailyXPAggregateDefinition], Error>) -> Void)

    // MARK: - Focus Sessions
    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[FocusSessionDefinition], Error>) -> Void)
}

public protocol AssistantActionRepositoryProtocol: Sendable {
    /// Executes createRun.
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void)
    /// Executes updateRun.
    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void)
    /// Executes fetchRun.
    func fetchRun(id: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition?, Error>) -> Void)
}

public protocol ExternalSyncRepositoryProtocol: Sendable {
    /// Executes fetchContainerMappings.
    func fetchContainerMappings(completion: @escaping @Sendable (Result<[ExternalContainerMapDefinition], Error>) -> Void)
    /// Executes saveContainerMapping.
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    /// Executes fetchContainerMapping.
    func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping @Sendable (Result<ExternalContainerMapDefinition?, Error>) -> Void
    )
    /// Executes upsertContainerMapping.
    func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping @Sendable (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping @Sendable (Result<ExternalContainerMapDefinition, Error>) -> Void
    )
    /// Executes fetchItemMappings.
    func fetchItemMappings(completion: @escaping @Sendable (Result<[ExternalItemMapDefinition], Error>) -> Void)
    /// Executes saveItemMapping.
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    /// Executes upsertItemMappingByLocalKey.
    func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping @Sendable (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping @Sendable (Result<ExternalItemMapDefinition, Error>) -> Void
    )
    /// Executes upsertItemMappingByExternalKey.
    func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping @Sendable (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping @Sendable (Result<ExternalItemMapDefinition, Error>) -> Void
    )
    /// Executes fetchItemMapping.
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping @Sendable (Result<ExternalItemMapDefinition?, Error>) -> Void)
    /// Executes fetchItemMapping.
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping @Sendable (Result<ExternalItemMapDefinition?, Error>) -> Void)
}

public protocol TombstoneRepositoryProtocol: Sendable {
    /// Executes create.
    func create(_ tombstone: TombstoneDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    /// Executes fetchExpired.
    func fetchExpired(before date: Date, completion: @escaping @Sendable (Result<[TombstoneDefinition], Error>) -> Void)
    /// Executes delete.
    func delete(ids: [UUID], completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}
