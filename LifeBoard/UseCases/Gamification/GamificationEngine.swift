import Foundation
import CoreData
#if canImport(WidgetKit)
import WidgetKit
#endif

public extension Notification.Name {
    static let gamificationLedgerDidMutate = Notification.Name("GamificationLedgerDidMutate")
}

private final class GamificationWidgetSnapshotState: @unchecked Sendable {
    private let lock = NSLock()
    private var weeklyAggregates: [DailyXPAggregateDefinition] = []
    private var todayEvents: [XPEventDefinition] = []
    private var todayFocusSessions: [FocusSessionDefinition] = []

    func setWeeklyAggregates(_ value: [DailyXPAggregateDefinition]) {
        lock.lock()
        weeklyAggregates = value
        lock.unlock()
    }

    func setTodayEvents(_ value: [XPEventDefinition]) {
        lock.lock()
        todayEvents = value
        lock.unlock()
    }

    func setTodayFocusSessions(_ value: [FocusSessionDefinition]) {
        lock.lock()
        todayFocusSessions = value
        lock.unlock()
    }

    func snapshot() -> (
        weeklyAggregates: [DailyXPAggregateDefinition],
        todayEvents: [XPEventDefinition],
        todayFocusSessions: [FocusSessionDefinition]
    ) {
        lock.lock()
        let snapshot = (weeklyAggregates, todayEvents, todayFocusSessions)
        lock.unlock()
        return snapshot
    }
}

private final class GamificationUnlockSaveState: @unchecked Sendable {
    private let lock = NSLock()
    private var savedUnlocks: [AchievementUnlockDefinition] = []
    private var storedError: Error?

    func record(result: Result<Void, Error>, unlock: AchievementUnlockDefinition) {
        lock.lock()
        switch result {
        case .success:
            savedUnlocks.append(unlock)
        case .failure(let error):
            if storedError == nil {
                storedError = error
            }
        }
        lock.unlock()
    }

    func result() -> Result<[AchievementUnlockDefinition], Error> {
        lock.lock()
        let error = storedError
        let unlocks = savedUnlocks
        lock.unlock()
        if let error {
            return .failure(error)
        }
        return .success(unlocks)
    }
}

private final class GamificationAggregateReconcileState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?
    private var didChange = false

    func recordError(_ error: Error) {
        lock.lock()
        if storedError == nil {
            storedError = error
        }
        lock.unlock()
    }

    func markChanged() {
        lock.lock()
        didChange = true
        lock.unlock()
    }

    func result() -> Result<Bool, Error> {
        lock.lock()
        let error = storedError
        let changed = didChange
        lock.unlock()
        if let error {
            return .failure(error)
        }
        return .success(changed)
    }
}

public struct GamificationLedgerMutation: Equatable, Sendable {
    public let source: String
    public let category: XPActionCategory
    public let awardedXP: Int
    public let dailyXPSoFar: Int
    public let totalXP: Int64
    public let level: Int
    public let previousLevel: Int
    public let streakDays: Int
    public let didChange: Bool
    public let dateKey: String
    public let occurredAt: Date
    public let unlockedAchievementKeys: [String]
    public let originatingEventID: UUID?

    public init(
        source: String,
        category: XPActionCategory,
        awardedXP: Int,
        dailyXPSoFar: Int,
        totalXP: Int64,
        level: Int,
        previousLevel: Int,
        streakDays: Int,
        didChange: Bool,
        dateKey: String,
        occurredAt: Date,
        unlockedAchievementKeys: [String] = [],
        originatingEventID: UUID? = nil
    ) {
        self.source = source
        self.category = category
        self.awardedXP = awardedXP
        self.dailyXPSoFar = dailyXPSoFar
        self.totalXP = totalXP
        self.level = level
        self.previousLevel = previousLevel
        self.streakDays = streakDays
        self.didChange = didChange
        self.dateKey = dateKey
        self.occurredAt = occurredAt
        self.unlockedAchievementKeys = unlockedAchievementKeys
        self.originatingEventID = originatingEventID
    }

    public var userInfo: [AnyHashable: Any] {
        [
            "source": source,
            "category": category.rawValue,
            "awardedXP": awardedXP,
            "dailyXPSoFar": dailyXPSoFar,
            "totalXP": totalXP,
            "level": level,
            "previousLevel": previousLevel,
            "streakDays": streakDays,
            "didChange": didChange,
            "dateKey": dateKey,
            "occurredAt": occurredAt,
            "unlockedAchievementKeys": unlockedAchievementKeys,
            "originatingEventID": originatingEventID as Any
        ]
    }

    public init?(_ userInfo: [AnyHashable: Any]?) {
        guard
            let userInfo,
            let source = userInfo["source"] as? String,
            let categoryRaw = userInfo["category"] as? String,
            let category = XPActionCategory(rawValue: categoryRaw),
            let didChange = userInfo["didChange"] as? Bool,
            let dateKey = userInfo["dateKey"] as? String,
            let occurredAt = userInfo["occurredAt"] as? Date
        else {
            return nil
        }

        let awardedXP = (userInfo["awardedXP"] as? NSNumber)?.intValue
            ?? (userInfo["awardedXP"] as? Int)
        let dailyXPSoFar = (userInfo["dailyXPSoFar"] as? NSNumber)?.intValue
            ?? (userInfo["dailyXPSoFar"] as? Int)
        let totalXP = (userInfo["totalXP"] as? NSNumber)?.int64Value
            ?? (userInfo["totalXP"] as? Int64)
            ?? (userInfo["totalXP"] as? Int).map(Int64.init)
        let level = (userInfo["level"] as? NSNumber)?.intValue
            ?? (userInfo["level"] as? Int)
        let previousLevel = (userInfo["previousLevel"] as? NSNumber)?.intValue
            ?? (userInfo["previousLevel"] as? Int)
        let streakDays = (userInfo["streakDays"] as? NSNumber)?.intValue
            ?? (userInfo["streakDays"] as? Int)
        let unlockedAchievementKeys = userInfo["unlockedAchievementKeys"] as? [String] ?? []
        let originatingEventID = userInfo["originatingEventID"] as? UUID

        guard
            let awardedXP,
            let dailyXPSoFar,
            let totalXP,
            let level,
            let previousLevel,
            let streakDays
        else {
            return nil
        }

        self.source = source
        self.category = category
        self.awardedXP = awardedXP
        self.dailyXPSoFar = dailyXPSoFar
        self.totalXP = totalXP
        self.level = level
        self.previousLevel = previousLevel
        self.streakDays = streakDays
        self.didChange = didChange
        self.dateKey = dateKey
        self.occurredAt = occurredAt
        self.unlockedAchievementKeys = unlockedAchievementKeys
        self.originatingEventID = originatingEventID
    }
}

public extension Notification {
    var gamificationLedgerMutation: GamificationLedgerMutation? {
        GamificationLedgerMutation(userInfo)
    }
}

/// Result returned after recording an XP event, used by UI for celebrations.
public struct XPCelebrationPayload: Sendable {
    public let awardedXP: Int
    public let level: Int
    public let didLevelUp: Bool
    public let crossedMilestone: XPCalculationEngine.Milestone?
    public let cooldownSeconds: TimeInterval
    public let occurredAt: Date
}

public struct XPEventResult: Sendable {
    public let awardedXP: Int
    public let totalXP: Int64
    public let level: Int
    public let previousLevel: Int
    public let currentStreak: Int
    public let didLevelUp: Bool
    public let dailyXPSoFar: Int
    public let dailyCap: Int
    public let unlockedAchievements: [AchievementUnlockDefinition]
    public let crossedMilestone: XPCalculationEngine.Milestone?
    public let celebration: XPCelebrationPayload?
}

/// Context describing an XP-eligible action.
public struct XPEventContext: Sendable {
    public let category: XPActionCategory
    public let source: XPSource
    public let taskID: UUID?
    public let habitID: UUID?
    public let occurrenceID: UUID?
    public let parentTaskID: UUID?
    public let childTaskID: UUID?
    public let sessionID: UUID?
    public let dueDate: Date?
    public let completedAt: Date
    public let priority: Int
    public let estimatedDuration: TimeInterval?
    public let isFocusSessionActive: Bool
    public let isPinnedInFocusStrip: Bool
    public let focusDurationSeconds: Int?
    public let fromDay: String?
    public let toDay: String?

    public init(
        category: XPActionCategory,
        source: XPSource = .manual,
        taskID: UUID? = nil,
        habitID: UUID? = nil,
        occurrenceID: UUID? = nil,
        parentTaskID: UUID? = nil,
        childTaskID: UUID? = nil,
        sessionID: UUID? = nil,
        dueDate: Date? = nil,
        completedAt: Date = Date(),
        priority: Int = 0,
        estimatedDuration: TimeInterval? = nil,
        isFocusSessionActive: Bool = false,
        isPinnedInFocusStrip: Bool = false,
        focusDurationSeconds: Int? = nil,
        fromDay: String? = nil,
        toDay: String? = nil
        ) {
        self.category = category
        self.source = source
        self.taskID = taskID
        self.habitID = habitID
        self.occurrenceID = occurrenceID
        self.parentTaskID = parentTaskID
        self.childTaskID = childTaskID
        self.sessionID = sessionID
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.isFocusSessionActive = isFocusSessionActive
        self.isPinnedInFocusStrip = isPinnedInFocusStrip
        self.focusDurationSeconds = focusDurationSeconds
        self.fromDay = fromDay
        self.toDay = toDay
    }
}

/// Central gamification engine replacing RecordXPUseCase.
/// Handles XP calculation, daily caps, level progression, streaks, and achievements.
public final class GamificationEngine: @unchecked Sendable {

    private let repository: GamificationRepositoryProtocol
    public static let celebrationCooldownSeconds: TimeInterval = 30

    public init(repository: GamificationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Record Event

    public func recordEvent(context: XPEventContext, completion: @escaping @Sendable (Result<XPEventResult, Error>) -> Void) {
        resolveIdempotencyKey(for: context) { [weak self] keyResult in
            guard let self else { return }
            switch keyResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let idempotencyKey):
                // Step 1: Check idempotency
                self.repository.hasXPEvent(idempotencyKey: idempotencyKey) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let exists):
                        if exists {
                            self.completeIdempotentReplay(context: context, completion: completion)
                            return
                        }

                        // Step 2: Calculate XP
                        self.calculateAndRecord(context: context, idempotencyKey: idempotencyKey, completion: completion)
                    }
                }
            }
        }
    }

    public func recordCompensationEvent(
        context: XPEventContext,
        completion: @escaping @Sendable (Result<XPEventResult, Error>) -> Void
    ) {
        let delta = XPCalculationEngine.baseXP(for: context.category)
        guard delta < 0 else {
            recordEvent(context: context, completion: completion)
            return
        }

        let idempotencyKey = self.idempotencyKey(for: context)
        repository.hasXPEvent(idempotencyKey: idempotencyKey) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let exists):
                if exists {
                    self.completeIdempotentReplay(context: context, completion: completion)
                    return
                }

                self.saveCompensationEvent(
                    context: context,
                    delta: delta,
                    idempotencyKey: idempotencyKey,
                    completion: completion
                )
            }
        }
    }

    // MARK: - Queries

    public func fetchTodayXP(completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        let dateKey = XPCalculationEngine.periodKey()
        repository.fetchDailyAggregate(dateKey: dateKey) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let aggregate):
                completion(.success(aggregate?.totalXP ?? 0))
            }
        }
    }

    public func fetchCurrentProfile(completion: @escaping @Sendable (Result<GamificationSnapshot, Error>) -> Void) {
        repository.fetchProfile { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let profile):
                completion(.success(profile ?? GamificationSnapshot()))
            }
        }
    }

    // MARK: - Widget Snapshot

    /// Writes the current gamification state to the App Group container for widgets.
    public func writeWidgetSnapshot() {
        fetchTodayXP { [weak self] xpResult in
            guard let self = self else { return }
            let dailyXP = (try? xpResult.get()) ?? 0

            self.fetchCurrentProfile { profileResult in
                let profile = (try? profileResult.get()) ?? GamificationSnapshot()
                let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                let milestone = XPCalculationEngine.nextMilestone(for: profile.xpTotal)
                let calendar = XPCalculationEngine.mondayCalendar()
                let now = Date()
                let today = calendar.startOfDay(for: now)
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
                let weekStart = XPCalculationEngine.mondayStartOfWeek(for: now, calendar: calendar)
                let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

                var milestoneProgress: Double = 0
                if let ms = milestone {
                    let prev = XPCalculationEngine.milestones
                        .last { $0.xpThreshold <= profile.xpTotal }?.xpThreshold ?? 0
                    let range = ms.xpThreshold - prev
                    let progress = profile.xpTotal - prev
                    milestoneProgress = range > 0 ? Double(progress) / Double(range) : 0
                }

                var snapshot = GamificationWidgetSnapshot(
                    dailyXP: dailyXP,
                    dailyCap: XPCalculationEngine.dailyCap,
                    level: levelInfo.level,
                    totalXP: profile.xpTotal,
                    nextLevelXP: levelInfo.nextThreshold,
                    currentLevelThreshold: levelInfo.currentThreshold,
                    streakDays: profile.currentStreak,
                    bestStreak: max(profile.bestStreak, profile.bestReturnStreak),
                    nextMilestoneName: milestone?.name,
                    nextMilestoneXP: milestone?.xpThreshold,
                    milestoneProgress: milestoneProgress,
                    updatedAt: now
                )

                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                df.locale = Locale(identifier: "en_US_POSIX")
                df.timeZone = calendar.timeZone

                let weekStartKey = df.string(from: weekStart)
                let weekEndKey = df.string(from: weekEndDate)
                let completionReasons = Set(["task_completion", "complete", "complete_on_time"])
                let focusKey = XPActionCategory.focus.rawValue

                let syncGroup = DispatchGroup()
                let snapshotState = GamificationWidgetSnapshotState()

                syncGroup.enter()
                self.repository.fetchDailyAggregates(from: weekStartKey, to: weekEndKey) { aggResult in
                    if case .success(let aggregates) = aggResult {
                        snapshotState.setWeeklyAggregates(aggregates)
                    }
                    syncGroup.leave()
                }

                syncGroup.enter()
                self.repository.fetchXPEvents(from: today, to: tomorrow) { eventsResult in
                    if case .success(let events) = eventsResult {
                        snapshotState.setTodayEvents(events)
                    }
                    syncGroup.leave()
                }

                syncGroup.enter()
                self.repository.fetchFocusSessions(from: today, to: tomorrow) { sessionsResult in
                    if case .success(let sessions) = sessionsResult {
                        snapshotState.setTodayFocusSessions(sessions)
                    }
                    syncGroup.leave()
                }

                syncGroup.notify(queue: .main) {
                    let snapshotValues = snapshotState.snapshot()
                    let weeklyAggregates = snapshotValues.weeklyAggregates
                    let todayEvents = snapshotValues.todayEvents
                    let todayFocusSessions = snapshotValues.todayFocusSessions
                    var weeklyXP: [Int] = []
                    var total = 0
                    for dayOffset in 0..<7 {
                        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                            weeklyXP.append(0)
                            continue
                        }
                        let key = df.string(from: day)
                        let xp = weeklyAggregates.first { $0.dateKey == key }?.totalXP ?? 0
                        weeklyXP.append(xp)
                        total += xp
                    }

                    snapshot.weeklyXP = weeklyXP
                    snapshot.weeklyTotalXP = total
                    snapshot.tasksCompletedToday = todayEvents.filter { event in
                        if event.category == .complete { return true }
                        if completionReasons.contains(event.reason) { return true }
                        return event.reason.contains("on_time")
                    }.count
                    let focusFromEvents = todayEvents
                        .filter { $0.category == .focus || $0.reason == focusKey }
                        .reduce(0) { $0 + max(0, $1.delta) }
                    let focusFromSessions = todayFocusSessions.reduce(0) { $0 + max(0, $1.durationSeconds / 60) }
                    snapshot.focusMinutesToday = max(focusFromEvents, focusFromSessions)
                    snapshot.save()
                    WatchWidgetSnapshotSync.shared.sendGamificationSnapshot(snapshot)
                    self.reloadWidgetTimelines()
                }
            }
        }
    }

    private func reloadWidgetTimelines() {
        if V2FeatureFlags.gamificationWidgetsEnabled {
            DispatchQueue.main.async {
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }

    // MARK: - Full Reconciliation

    /// Recomputes profile and daily aggregates from the event ledger.
    /// Called on launch and on NSPersistentStoreRemoteChange for CloudKit sync.
    public func fullReconciliation(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        repository.fetchProfile { [weak self] profileResult in
            guard let self = self else { return }
            switch profileResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existingProfile):
                let profile = existingProfile ?? GamificationSnapshot()
                self.repository.fetchXPEvents { eventsResult in
                    switch eventsResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let allEvents):
                        // Filter to v2 events if activation date exists
                        let events: [XPEventDefinition]
                        if let activatedAt = profile.gamificationV2ActivatedAt {
                            events = allEvents.filter { $0.createdAt >= activatedAt }
                        } else {
                            events = allEvents
                        }

                        // Deduplicate by idempotency key
                        let unique = Dictionary(grouping: events, by: \.idempotencyKey)
                            .compactMap { $0.value.first }

                        // Recompute total XP
                        let xpTotal = unique.reduce(Int64(0)) { $0 + Int64($1.delta) }
                        let levelInfo = XPCalculationEngine.levelForXP(xpTotal)

                        // Recompute daily aggregates
                        let grouped = Dictionary(grouping: unique) {
                            XPCalculationEngine.periodKey(for: $0.createdAt)
                        }

                        var updatedProfile = profile
                        updatedProfile.xpTotal = xpTotal
                        updatedProfile.level = levelInfo.level
                        updatedProfile.nextLevelXP = levelInfo.nextThreshold

                        let shouldSaveProfile = existingProfile == nil
                            || profile.xpTotal != updatedProfile.xpTotal
                            || profile.level != updatedProfile.level
                            || profile.nextLevelXP != updatedProfile.nextLevelXP

                        let continueWithAggregateReconciliation: @Sendable (_ profileChanged: Bool) -> Void = { profileChanged in
                            // Save each daily aggregate and refresh widgets once ledger reconciliation succeeds.
                            self.reconcileDailyAggregates(grouped: grouped) { reconcileResult in
                                switch reconcileResult {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success(let aggregatesChanged):
                                    if profileChanged || aggregatesChanged {
                                        self.writeWidgetSnapshot()
                                    }
                                    completion(.success(()))
                                }
                            }
                        }

                        guard shouldSaveProfile else {
                            continueWithAggregateReconciliation(false)
                            return
                        }

                        updatedProfile.updatedAt = Date()
                        self.repository.saveProfile(updatedProfile) { saveResult in
                            if case .failure(let error) = saveResult {
                                completion(.failure(error))
                                return
                            }
                            continueWithAggregateReconciliation(true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Streak Update

    public func updateStreak(completion: @escaping @Sendable (Result<GamificationSnapshot, Error>) -> Void) {
        repository.fetchProfile { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existing):
                var profile = existing ?? GamificationSnapshot()
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())

                if let lastActive = profile.lastActiveDate {
                    let lastDay = calendar.startOfDay(for: lastActive)
                    let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

                    if daysBetween == 0 {
                        // Same day — no streak change
                        completion(.success(profile))
                        return
                    } else if daysBetween == 1 {
                        // Consecutive day
                        profile.currentStreak += 1
                        profile.bestStreak = max(profile.bestStreak, profile.currentStreak)
                    } else if daysBetween > 1 {
                        // Gap — track return streak
                        let previousStreak = profile.currentStreak
                        profile.currentStreak = 1
                        if previousStreak > 0 && daysBetween <= 7 {
                            profile.returnStreak += 1
                            profile.bestReturnStreak = max(profile.bestReturnStreak, profile.returnStreak)
                        } else {
                            profile.returnStreak = 0
                        }
                    }
                } else {
                    // First ever activity
                    profile.currentStreak = 1
                }

                profile.lastActiveDate = today
                profile.updatedAt = Date()

                let savedProfile = profile
                self.repository.saveProfile(savedProfile) { saveResult in
                    switch saveResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        completion(.success(savedProfile))
                    }
                }
            }
        }
    }

    // MARK: - Private: Calculate and Record

    private func calculateAndRecord(
        context: XPEventContext,
        idempotencyKey: String,
        completion: @escaping @Sendable (Result<XPEventResult, Error>
    ) -> Void) {
        let periodKey = XPCalculationEngine.periodKey(for: context.completedAt)

        // Fetch daily aggregate to know cap headroom
        repository.fetchDailyAggregate(dateKey: periodKey) { [weak self] aggResult in
            guard let self = self else { return }
            switch aggResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existingAgg):
                let dailyEarnedSoFar = existingAgg?.totalXP ?? 0

                // Calculate XP
                let base: Int
                let bonus: Int
                let weight: Double

                if context.category == .focus {
                    base = XPCalculationEngine.focusSessionXP(durationSeconds: context.focusDurationSeconds ?? 0)
                    bonus = 0
                    weight = 1.0
                } else if XPCalculationEngine.isHabitCategory(context.category) {
                    base = XPCalculationEngine.baseXP(for: context.category)
                    bonus = 0
                    weight = 1.0
                } else {
                    base = XPCalculationEngine.baseXP(for: context.category)
                    bonus = (context.category == .complete && XPCalculationEngine.isOnTimeCompletion(
                        dueDate: context.dueDate,
                        completedAt: context.completedAt
                    )) ? XPCalculationEngine.onTimeBonusXP() : 0

                    weight = XPCalculationEngine.qualityWeight(
                        priority: context.priority,
                        estimatedDuration: context.estimatedDuration,
                        isFocusSessionActive: context.isFocusSessionActive,
                        isPinnedInFocusStrip: context.isPinnedInFocusStrip
                    )
                }

                let finalXP = XPCalculationEngine.calculateFinalXP(
                    base: base,
                    bonus: bonus,
                    qualityWeight: weight,
                    dailyEarnedSoFar: dailyEarnedSoFar
                )

                let shouldRecordZeroXPEvent = XPCalculationEngine.isHabitCategory(context.category)

                guard finalXP > 0 || shouldRecordZeroXPEvent else {
                    // Cap reached — return current state
                    self.fetchCurrentState { stateResult in
                        switch stateResult {
                        case .failure(let error):
                            completion(.failure(error))
                        case .success(let (profile, _)):
                            let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                            let result = XPEventResult(
                                awardedXP: 0,
                                totalXP: profile.xpTotal,
                                level: levelInfo.level,
                                previousLevel: levelInfo.level,
                                currentStreak: profile.currentStreak,
                                didLevelUp: false,
                                dailyXPSoFar: dailyEarnedSoFar,
                                dailyCap: XPCalculationEngine.dailyCap,
                                unlockedAchievements: [],
                                crossedMilestone: nil,
                                celebration: nil
                            )
                            self.emitLedgerMutation(context: context, result: result, didChange: false)
                            completion(.success(result))
                        }
                    }
                    return
                }

                // Create XP event
                let eventReason: String
                if context.category == .complete && bonus > 0 {
                    eventReason = "complete_on_time"
                } else {
                    eventReason = context.category.rawValue
                }

                let event = XPEventDefinition(
                    id: UUID(),
                    occurrenceID: context.occurrenceID,
                    taskID: context.taskID,
                    delta: finalXP,
                    reason: eventReason,
                    idempotencyKey: idempotencyKey,
                    createdAt: context.completedAt,
                    category: context.category,
                    source: context.source,
                    qualityWeight: weight,
                    periodKey: periodKey
                )

                // Save event
                self.repository.saveXPEvent(event) { saveResult in
                    if case .failure(let error) = saveResult {
                        if self.isIdempotentReplayError(error) {
                            self.completeIdempotentReplay(context: context, completion: completion)
                        } else {
                            completion(.failure(error))
                        }
                        return
                    }

                    // Update daily aggregate
                    let newDailyXP = dailyEarnedSoFar + finalXP
                    let updatedAggregate = DailyXPAggregateDefinition(
                        id: existingAgg?.id ?? UUID(),
                        dateKey: periodKey,
                        totalXP: newDailyXP,
                        eventCount: (existingAgg?.eventCount ?? 0) + 1,
                        updatedAt: Date()
                    )
                    self.repository.saveDailyAggregate(updatedAggregate) { aggSaveResult in
                        if case .failure(let error) = aggSaveResult {
                            self.recoverAfterPersistedEvent(
                                context: context,
                                awardedXP: finalXP,
                                recoveryError: error,
                                completion: completion
                            )
                            return
                        }

                        // Update profile
                        self.updateProfile(addedXP: Int64(finalXP), event: event, newDailyXP: newDailyXP) { profileResult in
                            switch profileResult {
                            case .failure(let error):
                                self.recoverAfterPersistedEvent(
                                    context: context,
                                    awardedXP: finalXP,
                                    recoveryError: error,
                                    completion: completion
                                )
                            case .success(let (profile, previousLevel)):
                                // Evaluate achievements
                                self.evaluateAchievements(triggerEvent: event) { achieveResult in
                                    let unlocked: [AchievementUnlockDefinition]
                                    if case .success(let u) = achieveResult {
                                        unlocked = u
                                    } else {
                                        unlocked = []
                                    }

                                    let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                                    let milestone = XPCalculationEngine.milestoneCrossed(
                                        previousXP: profile.xpTotal - Int64(finalXP),
                                        newXP: profile.xpTotal
                                    )
                                    let didLevelUp = levelInfo.level > previousLevel
                                    let celebration = XPCelebrationPayload(
                                        awardedXP: finalXP,
                                        level: levelInfo.level,
                                        didLevelUp: didLevelUp,
                                        crossedMilestone: milestone,
                                        cooldownSeconds: Self.celebrationCooldownSeconds,
                                        occurredAt: Date()
                                    )
                                    self.updateStreak { streakResult in
                                        let resolvedStreak: Int
                                        if case .success(let streakProfile) = streakResult {
                                            resolvedStreak = streakProfile.currentStreak
                                        } else {
                                            resolvedStreak = profile.currentStreak
                                        }

                                        let result = XPEventResult(
                                            awardedXP: finalXP,
                                            totalXP: profile.xpTotal,
                                            level: levelInfo.level,
                                            previousLevel: previousLevel,
                                            currentStreak: resolvedStreak,
                                            didLevelUp: didLevelUp,
                                            dailyXPSoFar: newDailyXP,
                                            dailyCap: XPCalculationEngine.dailyCap,
                                            unlockedAchievements: unlocked,
                                            crossedMilestone: milestone,
                                            celebration: celebration
                                        )

                                        self.emitXPFunnelTelemetry(context: context, result: result)
                                        self.writeWidgetSnapshot()
                                        self.emitLedgerMutation(
                                            context: context,
                                            result: result,
                                            didChange: true,
                                            originatingEventID: event.id
                                        )
                                        completion(.success(result))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveCompensationEvent(
        context: XPEventContext,
        delta: Int,
        idempotencyKey: String,
        completion: @escaping @Sendable (Result<XPEventResult, Error>) -> Void
    ) {
        let periodKey = XPCalculationEngine.periodKey(for: context.completedAt)
        let event = XPEventDefinition(
            id: UUID(),
            occurrenceID: context.occurrenceID,
            taskID: context.taskID,
            delta: delta,
            reason: context.category.rawValue,
            idempotencyKey: idempotencyKey,
            createdAt: context.completedAt,
            category: context.category,
            source: context.source,
            qualityWeight: 1.0,
            periodKey: periodKey
        )

        repository.saveXPEvent(event) { [weak self] saveResult in
            guard let self else { return }

            if case .failure(let error) = saveResult {
                if self.isIdempotentReplayError(error) {
                    self.completeIdempotentReplay(context: context, completion: completion)
                } else {
                    completion(.failure(error))
                }
                return
            }

            self.fullReconciliation { reconcileResult in
                switch reconcileResult {
                case .failure(let error):
                    completion(.failure(error))
                case .success:
                    self.fetchCurrentState(for: context.completedAt) { stateResult in
                        switch stateResult {
                        case .failure(let error):
                            completion(.failure(error))
                        case .success(let (profile, dailyXP)):
                            let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                            let previousXP = profile.xpTotal - Int64(delta)
                            let previousLevel = XPCalculationEngine.levelForXP(previousXP).level
                            let result = XPEventResult(
                                awardedXP: delta,
                                totalXP: profile.xpTotal,
                                level: levelInfo.level,
                                previousLevel: previousLevel,
                                currentStreak: profile.currentStreak,
                                didLevelUp: false,
                                dailyXPSoFar: dailyXP,
                                dailyCap: XPCalculationEngine.dailyCap,
                                unlockedAchievements: [],
                                crossedMilestone: nil,
                                celebration: nil
                            )
                            self.writeWidgetSnapshot()
                            self.emitLedgerMutation(
                                context: context,
                                result: result,
                                didChange: true,
                                originatingEventID: event.id
                            )
                            completion(.success(result))
                        }
                    }
                }
            }
        }
    }

    private func recoverAfterPersistedEvent(
        context: XPEventContext,
        awardedXP: Int,
        recoveryError: Error,
        completion: @escaping @Sendable (Result<XPEventResult, Error>) -> Void
    ) {
        logError(
            event: "gamification_partial_write_recovery_started",
            message: "Gamification detected a post-ledger write failure and is recovering from authoritative reconciliation",
            fields: [
                "category": context.category.rawValue,
                "source": context.source.rawValue,
                "awarded_xp": String(awardedXP),
                "error": recoveryError.localizedDescription
            ]
        )

        fullReconciliation { [weak self] reconcileResult in
            guard let self else { return }

            switch reconcileResult {
            case .failure(let reconcileError):
                logError(
                    event: "gamification_partial_write_recovery_failed",
                    message: "Gamification reconciliation failed while recovering from partial write failure",
                    fields: [
                        "original_error": recoveryError.localizedDescription,
                        "reconcile_error": reconcileError.localizedDescription
                    ]
                )
                completion(.failure(recoveryError))
            case .success:
                self.fetchCurrentState { stateResult in
                    switch stateResult {
                    case .failure(let stateError):
                        logError(
                            event: "gamification_partial_write_state_fetch_failed",
                            message: "Recovered reconciliation but failed to fetch current state for UI mutation replay",
                            fields: [
                                "original_error": recoveryError.localizedDescription,
                                "state_error": stateError.localizedDescription
                            ]
                        )
                        completion(.failure(recoveryError))
                    case .success(let (profile, dailyXP)):
                        let awarded = max(0, awardedXP)
                        let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                        let previousXP = max(0, profile.xpTotal - Int64(awarded))
                        let previousLevel = XPCalculationEngine.levelForXP(previousXP).level
                        let crossedMilestone = XPCalculationEngine.milestoneCrossed(
                            previousXP: previousXP,
                            newXP: profile.xpTotal
                        )
                        let didLevelUp = levelInfo.level > previousLevel
                        let celebration: XPCelebrationPayload? = awarded > 0 ? XPCelebrationPayload(
                            awardedXP: awarded,
                            level: levelInfo.level,
                            didLevelUp: didLevelUp,
                            crossedMilestone: crossedMilestone,
                            cooldownSeconds: Self.celebrationCooldownSeconds,
                            occurredAt: Date()
                        ) : nil

                        let result = XPEventResult(
                            awardedXP: awarded,
                            totalXP: profile.xpTotal,
                            level: levelInfo.level,
                            previousLevel: previousLevel,
                            currentStreak: profile.currentStreak,
                            didLevelUp: didLevelUp,
                            dailyXPSoFar: max(0, dailyXP),
                            dailyCap: XPCalculationEngine.dailyCap,
                            unlockedAchievements: [],
                            crossedMilestone: crossedMilestone,
                            celebration: celebration
                        )

                        self.emitLedgerMutation(context: context, result: result, didChange: awarded > 0)
                        completion(.success(result))
                    }
                }
            }
        }
    }

    // MARK: - Private: Profile Update

    private func updateProfile(
        addedXP: Int64,
        event: XPEventDefinition,
        newDailyXP: Int,
        completion: @escaping @Sendable (Result<(GamificationSnapshot, Int), Error>) -> Void
    ) {
        repository.fetchProfile { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existing):
                var profile = existing ?? GamificationSnapshot()
                let previousLevel = profile.level

                // Set v2 activation on first event
                if profile.gamificationV2ActivatedAt == nil {
                    profile.gamificationV2ActivatedAt = event.createdAt
                }

                profile.xpTotal += addedXP
                let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                profile.level = levelInfo.level
                profile.nextLevelXP = levelInfo.nextThreshold
                profile.updatedAt = Date()

                let savedProfile = profile
                self.repository.saveProfile(savedProfile) { saveResult in
                    switch saveResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        completion(.success((savedProfile, previousLevel)))
                    }
                }
            }
        }
    }

    // MARK: - Private: Achievement Evaluation

    private func evaluateAchievements(
        triggerEvent: XPEventDefinition,
        completion: @escaping @Sendable (Result<[AchievementUnlockDefinition], Error>) -> Void
    ) {
        repository.fetchXPEvents { [weak self] eventsResult in
            guard let self = self else { return }
            switch eventsResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let events):
                self.repository.fetchAchievementUnlocks { unlocksResult in
                    switch unlocksResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let unlocks):
                        self.repository.fetchProfile { profileResult in
                            let profile: GamificationSnapshot
                            if case .success(let p) = profileResult {
                                profile = p ?? GamificationSnapshot()
                            } else {
                                profile = GamificationSnapshot()
                            }

                            let unlockedKeys = Set(unlocks.map(\.achievementKey))
                            let candidates = self.pendingUnlocks(
                                from: events,
                                profile: profile,
                                alreadyUnlocked: unlockedKeys,
                                triggerEvent: triggerEvent
                            )

                            guard !candidates.isEmpty else {
                                completion(.success([]))
                                return
                            }

                            let group = DispatchGroup()
                            let saveState = GamificationUnlockSaveState()

                            for unlock in candidates {
                                group.enter()
                                self.repository.saveAchievementUnlock(unlock) { result in
                                    saveState.record(result: result, unlock: unlock)
                                    group.leave()
                                }
                            }

                            group.notify(queue: .main) {
                                switch saveState.result() {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success(let savedUnlocks):
                                    completion(.success(savedUnlocks))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func pendingUnlocks(
        from events: [XPEventDefinition],
        profile: GamificationSnapshot,
        alreadyUnlocked: Set<String>,
        triggerEvent: XPEventDefinition
    ) -> [AchievementUnlockDefinition] {
        var unlocks: [AchievementUnlockDefinition] = []
        let unique = Dictionary(grouping: events, by: \.idempotencyKey)
            .compactMap { $0.value.first }
        let completionEvents = unique.filter {
            $0.category == .complete
                || $0.reason == "task_completion"
                || $0.reason == "complete"
        }
        let habitSuccessEvents = unique.filter {
            guard let category = $0.category else { return false }
            return XPCalculationEngine.isHabitCategory(category)
                && (category == .habitPositiveComplete
                    || category == .habitNegativeSuccess
                    || category == .habitRecovery
                    || category == .habitStreakMilestone)
        }
        let xpTotal = profile.xpTotal

        func tryUnlock(_ key: String, condition: Bool) {
            if condition && !alreadyUnlocked.contains(key) {
                unlocks.append(AchievementUnlockDefinition(
                    id: UUID(),
                    achievementKey: key,
                    unlockedAt: Date(),
                    sourceEventID: triggerEvent.id
                ))
            }
        }

        // first_step: Complete 1 task
        tryUnlock("first_step", condition: completionEvents.count >= 1)

        // habit_first_success: Record a successful habit event
        tryUnlock("habit_first_success", condition: habitSuccessEvents.isEmpty == false)

        // xp_100: Reach 100 XP
        tryUnlock("xp_100", condition: xpTotal >= 100)

        // week_warrior: 7-day streak
        tryUnlock("week_warrior", condition: profile.currentStreak >= 7)

        // seven_day_return: 7-day return streak
        tryUnlock("seven_day_return", condition: profile.returnStreak >= 7)

        // on_time_10_week: 10 on-time completions in a week
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentOnTime = completionEvents.filter {
            $0.createdAt >= oneWeekAgo && ($0.reason.contains("on_time") || $0.reason.contains("onTime"))
        }
        tryUnlock("on_time_10_week", condition: recentOnTime.count >= 10)

        // decomposer_20: Decompose 20 tasks
        let decomposeEvents = unique.filter { $0.category == .decompose || $0.reason == "decompose" }
        tryUnlock("decomposer_20", condition: decomposeEvents.count >= 20)

        // reflection_7: 7 daily reflections
        let reflectionEvents = unique.filter { $0.category == .reflection || $0.reason == "reflection" }
        tryUnlock("reflection_7", condition: reflectionEvents.count >= 7)

        // habit_7_success: 7 successful habit events in the recent window
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentHabitSuccesses = habitSuccessEvents.filter { $0.createdAt >= sevenDaysAgo }
        tryUnlock("habit_7_success", condition: recentHabitSuccesses.count >= 7)

        // habit_streak_3: three habit success events on distinct days within the recent window
        let recentHabitDays = Set(
            recentHabitSuccesses.map { calendar.startOfDay(for: $0.createdAt).timeIntervalSinceReferenceDate }
        )
        tryUnlock("habit_streak_3", condition: recentHabitDays.count >= 3)

        // comeback_after_7_idle: Return after 7+ idle days (handled by streak logic)
        if let lastActive = profile.lastActiveDate {
            let daysSinceActive = calendar.dateComponents([.day], from: lastActive, to: Date()).day ?? 0
            tryUnlock("comeback_after_7_idle", condition: daysSinceActive >= 7 && profile.currentStreak == 1)
        }

        return unlocks
    }

    // MARK: - Private: Helpers

    private func emitXPFunnelTelemetry(context: XPEventContext, result: XPEventResult) {
        guard result.awardedXP > 0 else { return }
        logWarning(
            event: "xp_event_recorded",
            message: "XP event recorded",
            fields: [
                "category": context.category.rawValue,
                "source": context.source.rawValue,
                "awarded_xp": String(result.awardedXP),
                "daily_xp_so_far": String(result.dailyXPSoFar),
                "daily_cap": String(result.dailyCap),
                "total_xp": String(result.totalXP),
                "level": String(result.level),
                "reached_30_xp_threshold": result.dailyXPSoFar >= 30 ? "true" : "false",
                "did_level_up": result.didLevelUp ? "true" : "false",
                "crossed_milestone": result.crossedMilestone?.name ?? "none"
            ]
        )
    }

    private func emitLedgerMutation(
        context: XPEventContext,
        result: XPEventResult,
        didChange: Bool,
        originatingEventID: UUID? = nil
    ) {
        let payload = GamificationLedgerMutation(
            source: context.source.rawValue,
            category: context.category,
            awardedXP: result.awardedXP,
            dailyXPSoFar: result.dailyXPSoFar,
            totalXP: result.totalXP,
            level: result.level,
            previousLevel: result.previousLevel,
            streakDays: result.currentStreak,
            didChange: didChange,
            dateKey: XPCalculationEngine.periodKey(for: context.completedAt),
            occurredAt: Date(),
            unlockedAchievementKeys: result.unlockedAchievements.map(\.achievementKey),
            originatingEventID: originatingEventID
        )
        TaskNotificationDispatcher.postOnMain(
            name: .gamificationLedgerDidMutate,
            userInfo: payload.userInfo
        )
    }

    private func completeIdempotentReplay(
        context: XPEventContext,
        completion: @escaping @Sendable (Result<XPEventResult, Error>) -> Void
    ) {
        fetchCurrentState { stateResult in
            switch stateResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (profile, dailyXP)):
                let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                let result = XPEventResult(
                    awardedXP: 0,
                    totalXP: profile.xpTotal,
                    level: levelInfo.level,
                    previousLevel: levelInfo.level,
                    currentStreak: profile.currentStreak,
                    didLevelUp: false,
                    dailyXPSoFar: dailyXP,
                    dailyCap: XPCalculationEngine.dailyCap,
                    unlockedAchievements: [],
                    crossedMilestone: nil,
                    celebration: nil
                )
                self.emitLedgerMutation(context: context, result: result, didChange: false)
                completion(.success(result))
            }
        }
    }

    private func isIdempotentReplayError(_ error: Error) -> Bool {
        if case GamificationRepositoryWriteError.idempotentReplay = error {
            return true
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            let replayCodes: Set<Int> = [
                NSManagedObjectConstraintMergeError,
                NSValidationMultipleErrorsError
            ]
            if replayCodes.contains(nsError.code) {
                return true
            }
            if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError],
               detailedErrors.contains(where: { replayCodes.contains($0.code) }) {
                return true
            }
        }
        return false
    }

    private func idempotencyKey(for context: XPEventContext) -> String {
        XPCalculationEngine.idempotencyKey(
            category: context.category,
            taskID: context.taskID,
            habitID: context.habitID,
            parentTaskID: context.parentTaskID,
            childTaskID: context.childTaskID,
            sessionID: context.sessionID,
            fromDay: context.fromDay,
            toDay: context.toDay,
            periodKey: XPCalculationEngine.periodKey(for: context.completedAt)
        )
    }

    private func resolveIdempotencyKey(
        for context: XPEventContext,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        let baseKey = idempotencyKey(for: context)
        guard let compensationPrefix = habitSuccessCompensationPrefix(for: context) else {
            completion(.success(baseKey))
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: context.completedAt)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? context.completedAt

        repository.fetchXPEvents(from: startOfDay, to: endOfDay) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let events):
                let compensationCount = events.filter { event in
                    event.idempotencyKey.hasPrefix(compensationPrefix)
                }.count
                completion(.success("\(baseKey):cycle\(compensationCount)"))
            }
        }
    }

    private func habitSuccessCompensationPrefix(for context: XPEventContext) -> String? {
        guard let identifier = context.habitID ?? context.taskID else { return nil }

        switch context.category {
        case .habitPositiveComplete:
            return "habit_positive_complete_undo:\(identifier.uuidString):\(XPCalculationEngine.periodKey(for: context.completedAt))"
        case .habitNegativeSuccess:
            return "habit_negative_success_undo:\(identifier.uuidString):\(XPCalculationEngine.periodKey(for: context.completedAt))"
        default:
            return nil
        }
    }

    private func fetchCurrentState(completion: @escaping @Sendable (Result<(GamificationSnapshot, Int), Error>) -> Void) {
        fetchCurrentState(forDateKey: XPCalculationEngine.periodKey(), completion: completion)
    }

    private func fetchCurrentState(
        for date: Date,
        completion: @escaping @Sendable (Result<(GamificationSnapshot, Int), Error>) -> Void
    ) {
        fetchCurrentState(forDateKey: XPCalculationEngine.periodKey(for: date), completion: completion)
    }

    private func fetchCurrentState(
        forDateKey dateKey: String,
        completion: @escaping @Sendable (Result<(GamificationSnapshot, Int), Error>) -> Void
    ) {
        repository.fetchProfile { [weak self] profileResult in
            guard let self = self else { return }
            switch profileResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let profile):
                let p = profile ?? GamificationSnapshot()
                self.repository.fetchDailyAggregate(dateKey: dateKey) { aggResult in
                    switch aggResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let agg):
                        completion(.success((p, agg?.totalXP ?? 0)))
                    }
                }
            }
        }
    }

    private func reconcileDailyAggregates(
        grouped: [String: [XPEventDefinition]],
        completion: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) {
        guard grouped.isEmpty == false else {
            completion(.success(false))
            return
        }

        let group = DispatchGroup()
        let state = GamificationAggregateReconcileState()

        for (dateKey, events) in grouped {
            let totalXP = events.reduce(0) { $0 + $1.delta }
            group.enter()
            repository.fetchDailyAggregate(dateKey: dateKey) { fetchResult in
                switch fetchResult {
                case .failure(let error):
                    state.recordError(error)
                    group.leave()
                case .success(let existing):
                    let isUnchanged = existing?.totalXP == totalXP
                        && existing?.eventCount == events.count
                    guard isUnchanged == false else {
                        group.leave()
                        return
                    }

                    let aggregate = DailyXPAggregateDefinition(
                        id: existing?.id ?? UUID(),
                        dateKey: dateKey,
                        totalXP: totalXP,
                        eventCount: events.count,
                        updatedAt: Date()
                    )
                    self.repository.saveDailyAggregate(aggregate) { saveResult in
                        if case .failure(let error) = saveResult {
                            state.recordError(error)
                        } else {
                            state.markChanged()
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            switch state.result() {
            case .failure(let error):
                completion(.failure(error))
            case .success(let didChange):
                completion(.success(didChange))
            }
        }
    }
}
