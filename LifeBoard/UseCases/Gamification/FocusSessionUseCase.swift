import Foundation

/// Manages focus session lifecycle: start, pause/resume, end, XP recording.
public final class FocusSessionUseCase: @unchecked Sendable {

    private let repository: GamificationRepositoryProtocol
    private let engine: GamificationEngine

    public init(repository: GamificationRepositoryProtocol, engine: GamificationEngine) {
        self.repository = repository
        self.engine = engine
    }

    // MARK: - Start

    public func startSession(
        taskID: UUID?,
        targetDurationSeconds: Int,
        completion: @escaping @Sendable (Result<FocusSessionDefinition, Error>) -> Void
    ) {
        repository.fetchFocusSessions(from: .distantPast, to: Date().addingTimeInterval(1)) { [weak self] fetchResult in
            guard let self else { return }
            switch fetchResult {
            case .failure(let error):
                completion(.failure(error))
                return
            case .success(let sessions):
                if sessions.contains(where: { $0.endedAt == nil }) {
                    completion(.failure(FocusSessionError.alreadyActive))
                    return
                }
            }

            // If no active session exists in storage, clear any stale foreground recovery keys.
            if UserDefaults.standard.string(forKey: "focusSessionActiveID") != nil {
                self.clearPersistedSession()
            }

            let session = FocusSessionDefinition(
                id: UUID(),
                taskID: taskID,
                startedAt: Date(),
                endedAt: nil,
                durationSeconds: 0,
                targetDurationSeconds: targetDurationSeconds,
                wasCompleted: false,
                xpAwarded: 0
            )
            self.repository.createFocusSession(session) { result in
                switch result {
                case .success:
                    // Persist active session for foreground recovery
                    UserDefaults.standard.set(session.id.uuidString, forKey: "focusSessionActiveID")
                    UserDefaults.standard.set(session.startedAt.timeIntervalSince1970, forKey: "focusSessionStartedAt")
                    UserDefaults.standard.set(taskID?.uuidString, forKey: "focusSessionTaskID")
                    UserDefaults.standard.set(targetDurationSeconds, forKey: "focusSessionTargetSeconds")
                    completion(.success(session))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - End

    public func endSession(
        sessionID: UUID,
        completion: @escaping @Sendable (Result<FocusSessionResult, Error>) -> Void
    ) {
        repository.fetchFocusSessions(from: Date.distantPast, to: Date()) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let sessions):
                guard var session = sessions.first(where: { $0.id == sessionID }) else {
                    completion(.failure(FocusSessionError.sessionNotFound))
                    return
                }
                let endedAt = Date()
                let elapsed = Int(endedAt.timeIntervalSince(session.startedAt))
                session.endedAt = endedAt
                session.durationSeconds = elapsed
                session.wasCompleted = elapsed >= session.targetDurationSeconds

                let xp = XPCalculationEngine.focusSessionXP(durationSeconds: elapsed)
                session.xpAwarded = xp
                let completedSession = session

                self.repository.updateFocusSession(completedSession) { updateResult in
                    switch updateResult {
                    case .success:
                        self.clearPersistedSession()

                        guard xp > 0 else {
                            let focusResult = FocusSessionResult(
                                session: completedSession,
                                xpResult: nil
                            )
                            completion(.success(focusResult))
                            return
                        }

                        let context = XPEventContext(
                            category: .focus,
                            source: .manual,
                            taskID: completedSession.taskID,
                            sessionID: completedSession.id,
                            focusDurationSeconds: elapsed
                        )
                        self.engine.recordEvent(context: context) { xpResult in
                            switch xpResult {
                            case .success(let xpEventResult):
                                let focusResult = FocusSessionResult(
                                    session: completedSession,
                                    xpResult: xpEventResult
                                )
                                completion(.success(focusResult))
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

    // MARK: - Recovery

    /// Recovers an interrupted session on foreground return.
    /// If gap > 5 minutes since background, auto-ends with pro-rated XP.
    public func recoverIfNeeded(completion: @escaping @Sendable (FocusSessionResult?) -> Void) {
        guard let idString = UserDefaults.standard.string(forKey: "focusSessionActiveID"),
              let sessionID = UUID(uuidString: idString),
              let startedAt = UserDefaults.standard.object(forKey: "focusSessionStartedAt") as? TimeInterval else {
            completion(nil)
            return
        }

        let elapsed = Date().timeIntervalSince1970 - startedAt
        let backgroundGap: TimeInterval = 5 * 60

        if elapsed > Double(UserDefaults.standard.integer(forKey: "focusSessionTargetSeconds")) + backgroundGap {
            // Session was abandoned - auto end with whatever duration was valid
            endSession(sessionID: sessionID) { result in
                switch result {
                case .success(let focusResult):
                    completion(focusResult)
                case .failure:
                    completion(nil)
                }
            }
        } else {
            // Session is still valid and can continue in the foreground.
            completion(nil)
        }
    }

    public func fetchActiveSession(completion: @escaping @Sendable (Result<FocusSessionDefinition?, Error>) -> Void) {
        repository.fetchFocusSessions(from: .distantPast, to: Date().addingTimeInterval(1)) { [weak self] result in
            switch result {
            case .success(let sessions):
                let activeSession = sessions
                    .filter { $0.endedAt == nil }
                    .sorted(by: { $0.startedAt > $1.startedAt })
                    .first

                if activeSession == nil,
                   UserDefaults.standard.string(forKey: "focusSessionActiveID") != nil {
                    self?.clearPersistedSession()
                }

                completion(.success(activeSession))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Query

    public func fetchTodaySessions(completion: @escaping @Sendable (Result<[FocusSessionDefinition], Error>) -> Void) {
        let start = Calendar.current.startOfDay(for: Date())
        repository.fetchFocusSessions(from: start, to: Date()) { result in
            completion(result)
        }
    }

    public func todayFocusMinutes(completion: @escaping @Sendable (Int) -> Void) {
        fetchTodaySessions { result in
            switch result {
            case .success(let sessions):
                let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
                completion(totalSeconds / 60)
            case .failure:
                completion(0)
            }
        }
    }

    // MARK: - Private

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: "focusSessionActiveID")
        UserDefaults.standard.removeObject(forKey: "focusSessionStartedAt")
        UserDefaults.standard.removeObject(forKey: "focusSessionTaskID")
        UserDefaults.standard.removeObject(forKey: "focusSessionTargetSeconds")
    }
}

// MARK: - Supporting Types

public struct FocusSessionResult: Sendable {
    public let session: FocusSessionDefinition
    public let xpResult: XPEventResult?
}

public enum FocusSessionError: Error, Sendable {
    case sessionNotFound
    case alreadyActive
}
