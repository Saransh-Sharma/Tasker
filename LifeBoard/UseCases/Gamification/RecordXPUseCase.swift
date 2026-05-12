import Foundation

private final class RecordXPErrorRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var firstError: Error?

    func record(_ error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func error() -> Error? {
        lock.lock()
        let firstError = firstError
        lock.unlock()
        return firstError
    }
}

public final class RecordXPUseCase: @unchecked Sendable {
    private let repository: GamificationRepositoryProtocol

    /// Initializes a new instance.
    public init(repository: GamificationRepositoryProtocol) {
        self.repository = repository
    }

    /// Executes recordTaskCompletion.
    public func recordTaskCompletion(taskID: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        let dayKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        let idempotencyKey = "complete_\(taskID.uuidString)_\(dayKey)"
        let event = XPEventDefinition(
            id: UUID(),
            occurrenceID: nil,
            taskID: taskID,
            delta: 10,
            reason: "task_completion",
            idempotencyKey: idempotencyKey,
            createdAt: Date()
        )
        repository.saveXPEvent(event) { result in
            switch result {
            case .failure(let error):
                if case GamificationRepositoryWriteError.idempotentReplay = error {
                    completion(.success(()))
                } else {
                    completion(.failure(error))
                }
            case .success:
                self.reconcileProfile { reconcileResult in
                    switch reconcileResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let profile):
                        self.repository.saveProfile(profile) { saveResult in
                            switch saveResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success:
                                self.evaluateAchievements(triggerEvent: event) { _ in
                                    completion(.success(()))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Executes reconcileProfile.
    public func reconcileProfile(completion: @escaping @Sendable (Result<GamificationSnapshot, Error>) -> Void) {
        repository.fetchXPEvents { result in
            switch result {
            case .success(let events):
                let uniqueEvents = Dictionary(grouping: events, by: { $0.idempotencyKey }).compactMap { $0.value.first }
                let xp = uniqueEvents.reduce(Int64(0)) { $0 + Int64($1.delta) }
                let level = max(1, Int(xp / 100) + 1)
                self.repository.fetchProfile { profileResult in
                    switch profileResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let existing):
                        let profile = GamificationSnapshot(
                            id: existing?.id ?? UUID(),
                            xpTotal: xp,
                            level: level,
                            currentStreak: existing?.currentStreak ?? 0,
                            bestStreak: existing?.bestStreak ?? 0,
                            lastActiveDate: Date(),
                            updatedAt: Date()
                        )
                        completion(.success(profile))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes evaluateAchievements.
    private func evaluateAchievements(triggerEvent: XPEventDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        repository.fetchXPEvents { eventsResult in
            switch eventsResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let events):
                self.repository.fetchAchievementUnlocks { unlocksResult in
                    switch unlocksResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let unlocks):
                        let unlockedKeys = Set(unlocks.map(\.achievementKey))
                        let candidateUnlocks = self.pendingUnlocks(from: events, alreadyUnlocked: unlockedKeys, triggerEvent: triggerEvent)

                        guard candidateUnlocks.isEmpty == false else {
                            completion(.success(()))
                            return
                        }

                        let group = DispatchGroup()
                        let errors = RecordXPErrorRecorder()
                        for unlock in candidateUnlocks {
                            group.enter()
                            self.repository.saveAchievementUnlock(unlock) { result in
                                if case .failure(let error) = result {
                                    errors.record(error)
                                }
                                group.leave()
                            }
                        }
                        group.notify(queue: .main) {
                            if let firstError = errors.error() {
                                completion(.failure(firstError))
                            } else {
                                completion(.success(()))
                            }
                        }
                    }
                }
            }
        }
    }

    /// Executes pendingUnlocks.
    private func pendingUnlocks(
        from events: [XPEventDefinition],
        alreadyUnlocked: Set<String>,
        triggerEvent: XPEventDefinition
    ) -> [AchievementUnlockDefinition] {
        var unlocks: [AchievementUnlockDefinition] = []
        let uniqueEvents = Dictionary(grouping: events, by: { $0.idempotencyKey }).compactMap { $0.value.first }
        let completionEvents = uniqueEvents.filter { $0.reason == "task_completion" }
        let xpTotal = uniqueEvents.reduce(Int64(0)) { $0 + Int64($1.delta) }

        if completionEvents.count >= 1, alreadyUnlocked.contains("first_step") == false {
            unlocks.append(
                AchievementUnlockDefinition(
                    id: UUID(),
                    achievementKey: "first_step",
                    unlockedAt: Date(),
                    sourceEventID: triggerEvent.id
                )
            )
        }

        if xpTotal >= 100, alreadyUnlocked.contains("xp_100") == false {
            unlocks.append(
                AchievementUnlockDefinition(
                    id: UUID(),
                    achievementKey: "xp_100",
                    unlockedAt: Date(),
                    sourceEventID: triggerEvent.id
                )
            )
        }

        if hasSevenDayCompletionStreak(events: completionEvents), alreadyUnlocked.contains("week_warrior") == false {
            unlocks.append(
                AchievementUnlockDefinition(
                    id: UUID(),
                    achievementKey: "week_warrior",
                    unlockedAt: Date(),
                    sourceEventID: triggerEvent.id
                )
            )
        }

        return unlocks
    }

    /// Executes hasSevenDayCompletionStreak.
    private func hasSevenDayCompletionStreak(events: [XPEventDefinition]) -> Bool {
        let calendar = Calendar.current
        let distinctDays = Set(
            events.map { calendar.startOfDay(for: $0.createdAt) }
        ).sorted()
        guard distinctDays.count >= 7 else { return false }

        var streak = 1
        var longest = 1
        for index in 1..<distinctDays.count {
            let prev = distinctDays[index - 1]
            let curr = distinctDays[index]
            let delta = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if delta == 1 {
                streak += 1
                longest = max(longest, streak)
            } else if delta > 1 {
                streak = 1
            }
        }
        return longest >= 7
    }
}
