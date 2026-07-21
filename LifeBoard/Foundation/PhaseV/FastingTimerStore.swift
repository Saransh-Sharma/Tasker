import Foundation

public protocol LifeBoardFastingSessionRepository: Sendable {
    func fetchFastingSessions(limit: Int) async throws -> [LifeBoardFastingSessionValue]
    func saveFastingSession(_ value: LifeBoardFastingSessionValue) async throws
}

public struct LifeBoardFastingRepositoryAdapter: LifeBoardFastingSessionRepository, Sendable {
    private let fetch: @Sendable (Int) async throws -> [LifeBoardFastingSessionValue]
    private let save: @Sendable (LifeBoardFastingSessionValue) async throws -> Void

    public init(repository: any LifeBoardPhaseIIRepository) {
        fetch = { limit in try await repository.fetchFastingSessions(limit: limit) }
        save = { value in try await repository.saveFastingSession(value) }
    }

    public func fetchFastingSessions(limit: Int) async throws -> [LifeBoardFastingSessionValue] {
        try await fetch(limit)
    }

    public func saveFastingSession(_ value: LifeBoardFastingSessionValue) async throws {
        try await save(value)
    }
}

public enum FastingTimerStoreError: LocalizedError, Equatable {
    case alreadyActive
    case noActiveSession
    case invalidTarget
    case invalidInterval
    case sessionNotFound

    public var errorDescription: String? {
        switch self {
        case .alreadyActive:
            "A fasting timer is already active. End or cancel it before starting another."
        case .noActiveSession:
            "There is no active fasting timer to update."
        case .invalidTarget:
            "Choose a target longer than zero."
        case .invalidInterval:
            "A fasting session must end after it starts."
        case .sessionNotFound:
            "That fasting session is no longer available."
        }
    }
}

/// The canonical fasting lifecycle. The actor serializes every transition so
/// cards, the app, Watch, widgets, and Live Activities cannot create two active
/// sessions even when commands arrive at nearly the same time.
public actor FastingTimerStore {
    private let repository: any LifeBoardFastingSessionRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any LifeBoardFastingSessionRepository,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.now = now
    }

    public func sessions(limit: Int = 30) async throws -> [LifeBoardFastingSessionValue] {
        try await recover(limit: limit)
    }

    public func activeSession() async throws -> LifeBoardFastingSessionValue? {
        try await recover(limit: 100).first(where: { $0.endedAt == nil })
    }

    @discardableResult
    public func start(
        targetDuration: TimeInterval?,
        reminderOffsets: [TimeInterval] = [],
        note: String? = nil,
        at startDate: Date? = nil
    ) async throws -> LifeBoardFastingSessionValue {
        if let targetDuration, targetDuration <= 0 {
            throw FastingTimerStoreError.invalidTarget
        }
        guard try await activeSession() == nil else {
            throw FastingTimerStoreError.alreadyActive
        }

        let startDate = startDate ?? now()
        let validReminders = reminderOffsets
            .filter { offset in
                guard offset >= 0 else { return false }
                return targetDuration.map { offset <= $0 } ?? true
            }
            .sorted()
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = LifeBoardFastingSessionValue(
            startedAt: startDate,
            targetDuration: targetDuration,
            reminderOffsets: Array(Set(validReminders)).sorted(),
            note: trimmedNote?.isEmpty == true ? nil : trimmedNote,
            updatedAt: startDate
        )
        try await repository.saveFastingSession(session)
        LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    @discardableResult
    public func finish(at endDate: Date? = nil) async throws -> LifeBoardFastingSessionValue {
        guard var session = try await activeSession() else {
            throw FastingTimerStoreError.noActiveSession
        }
        let endDate = endDate ?? now()
        guard endDate > session.startedAt else {
            throw FastingTimerStoreError.invalidInterval
        }
        session.endedAt = endDate
        session.completionKind = session.targetEnd.map { endDate >= $0 ? .planned : .early } ?? .planned
        session.updatedAt = endDate
        try await repository.saveFastingSession(session)
        LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    @discardableResult
    public func cancel(at endDate: Date? = nil) async throws -> LifeBoardFastingSessionValue {
        guard var session = try await activeSession() else {
            throw FastingTimerStoreError.noActiveSession
        }
        let endDate = endDate ?? now()
        guard endDate > session.startedAt else {
            throw FastingTimerStoreError.invalidInterval
        }
        session.endedAt = endDate
        session.completionKind = .cancelled
        session.updatedAt = endDate
        try await repository.saveFastingSession(session)
        LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    @discardableResult
    public func correct(
        sessionID: UUID,
        startedAt: Date,
        endedAt: Date?,
        targetDuration: TimeInterval?,
        note: String?
    ) async throws -> LifeBoardFastingSessionValue {
        if let targetDuration, targetDuration <= 0 {
            throw FastingTimerStoreError.invalidTarget
        }
        if let endedAt, endedAt <= startedAt {
            throw FastingTimerStoreError.invalidInterval
        }

        let all = try await recover(limit: 100)
        guard var session = all.first(where: { $0.id == sessionID }) else {
            throw FastingTimerStoreError.sessionNotFound
        }
        if endedAt == nil, all.contains(where: { $0.id != sessionID && $0.endedAt == nil }) {
            throw FastingTimerStoreError.alreadyActive
        }

        session.startedAt = startedAt
        session.endedAt = endedAt
        session.targetDuration = targetDuration
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        session.note = trimmedNote?.isEmpty == true ? nil : trimmedNote
        session.completionKind = .corrected
        session.updatedAt = now()
        try await repository.saveFastingSession(session)
        LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    /// Repairs legacy duplicate-active states deterministically. The newest
    /// session remains active; earlier sessions close just before it began and
    /// are marked cancelled so no elapsed time is fabricated after recovery.
    private func recover(limit: Int) async throws -> [LifeBoardFastingSessionValue] {
        var values = try await repository.fetchFastingSessions(limit: max(1, limit))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt { return lhs.startedAt > rhs.startedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        let activeIndices = values.indices.filter { values[$0].endedAt == nil }
        guard activeIndices.count > 1, let keeperIndex = activeIndices.first else { return values }

        let keeperStart = values[keeperIndex].startedAt
        for index in activeIndices.dropFirst() {
            let minimumEnd = values[index].startedAt.addingTimeInterval(0.001)
            values[index].endedAt = max(minimumEnd, keeperStart)
            values[index].completionKind = .cancelled
            values[index].updatedAt = now()
            try await repository.saveFastingSession(values[index])
        }
        return values
    }
}

public struct FastingHomeContextCandidateProvider: HomeContextCandidateProvider {
    public let providerID = "fasting"
    private let repository: any LifeBoardFastingSessionRepository

    public init(repository: any LifeBoardFastingSessionRepository) {
        self.repository = repository
    }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        guard let fast = try? await repository.fetchFastingSessions(limit: 20)
            .first(where: { $0.endedAt == nil }) else { return [] }
        let elapsed = fast.elapsed(at: context.date)
        let reason: String
        if let target = fast.targetDuration {
            let remaining = max(0, target - elapsed)
            reason = remaining > 0
                ? "Your user-selected timer has \(Self.duration(remaining)) remaining."
                : "You reached the duration you selected. End whenever you choose."
        } else {
            reason = "You started this timer and asked LifeBoard to keep it visible."
        }
        return [.init(
            id: "active-fast:\(fast.id.uuidString)",
            widgetKind: .fasting,
            title: "Your fast is active · \(Self.duration(elapsed))",
            reason: .init(message: reason, signal: "active fast"),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 650,
            relevantFrom: fast.startedAt,
            relevantUntil: fast.targetDuration.map { fast.startedAt.addingTimeInterval($0 + 21_600) },
            isUserStartedActiveState: true
        )]
    }

    private static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
