import Foundation

public protocol FastingSessionRepository: Sendable {
    func fetchFastingSessions(limit: Int) async throws -> [FastingSessionValue]
    func saveFastingSession(_ value: FastingSessionValue) async throws
    func fetchFastingTemplates(includeArchived: Bool) async throws -> [FastingTemplateValue]
    func saveFastingTemplate(_ value: FastingTemplateValue) async throws
}

public extension FastingSessionRepository {
    func fetchFastingTemplates(includeArchived: Bool) async throws -> [FastingTemplateValue] { [] }

    func saveFastingTemplate(_ value: FastingTemplateValue) async throws {
        throw FastingTimerStoreError.invalidTarget
    }
}

public struct FastingRepositoryAdapter: FastingSessionRepository, Sendable {
    private let fetch: @Sendable (Int) async throws -> [FastingSessionValue]
    private let save: @Sendable (FastingSessionValue) async throws -> Void
    private let fetchTemplates: @Sendable (Bool) async throws -> [FastingTemplateValue]
    private let saveTemplate: @Sendable (FastingTemplateValue) async throws -> Void

    public init(repository: any PhaseIIRepository) {
        fetch = { limit in try await repository.fetchFastingSessions(limit: limit) }
        save = { value in try await repository.saveFastingSession(value) }
        fetchTemplates = { includeArchived in
            try await repository.fetchFastingTemplates(includeArchived: includeArchived)
        }
        saveTemplate = { value in try await repository.saveFastingTemplate(value) }
    }

    public func fetchFastingSessions(limit: Int) async throws -> [FastingSessionValue] {
        try await fetch(limit)
    }

    public func saveFastingSession(_ value: FastingSessionValue) async throws {
        try await save(value)
    }

    public func fetchFastingTemplates(includeArchived: Bool) async throws -> [FastingTemplateValue] {
        try await fetchTemplates(includeArchived)
    }

    public func saveFastingTemplate(_ value: FastingTemplateValue) async throws {
        try await saveTemplate(value)
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
    private let repository: any FastingSessionRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any FastingSessionRepository,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.now = now
    }

    public func sessions(limit: Int = 30) async throws -> [FastingSessionValue] {
        try await recover(limit: limit)
    }

    public func activeSession() async throws -> FastingSessionValue? {
        try await recover(limit: 100).first(where: { $0.endedAt == nil })
    }

    public func templates(includeArchived: Bool = false) async throws -> [FastingTemplateValue] {
        try await repository.fetchFastingTemplates(includeArchived: includeArchived)
    }

    public func saveTemplate(_ value: FastingTemplateValue) async throws {
        try await repository.saveFastingTemplate(value)
        SystemSurfaceRefresher.requestRefreshSoon()
    }

    @discardableResult
    public func start(
        template: FastingTemplateValue,
        note: String? = nil,
        at startDate: Date? = nil
    ) async throws -> FastingSessionValue {
        guard !template.isArchived else { throw FastingTimerStoreError.invalidTarget }
        return try await start(
            templateID: template.id,
            targetDuration: template.targetDuration,
            reminderOffsets: template.reminderOffsets,
            note: note,
            at: startDate
        )
    }

    @discardableResult
    public func start(
        targetDuration: TimeInterval?,
        reminderOffsets: [TimeInterval] = [],
        note: String? = nil,
        at startDate: Date? = nil
    ) async throws -> FastingSessionValue {
        try await start(
            templateID: nil,
            targetDuration: targetDuration,
            reminderOffsets: reminderOffsets,
            note: note,
            at: startDate
        )
    }

    private func start(
        templateID: UUID?,
        targetDuration: TimeInterval?,
        reminderOffsets: [TimeInterval],
        note: String?,
        at startDate: Date?
    ) async throws -> FastingSessionValue {
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
        let session = FastingSessionValue(
            templateID: templateID,
            startedAt: startDate,
            targetDuration: targetDuration,
            reminderOffsets: Array(Set(validReminders)).sorted(),
            note: trimmedNote?.isEmpty == true ? nil : trimmedNote,
            updatedAt: startDate
        )
        try await repository.saveFastingSession(session)
        await FastingLiveActivityCoordinator.shared.synchronize(session: session)
        SystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    @discardableResult
    public func finish(at endDate: Date? = nil) async throws -> FastingSessionValue {
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
        await FastingLiveActivityCoordinator.shared.synchronize(session: session)
        SystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    @discardableResult
    public func cancel(at endDate: Date? = nil) async throws -> FastingSessionValue {
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
        await FastingLiveActivityCoordinator.shared.synchronize(session: session)
        SystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    @discardableResult
    public func correct(
        sessionID: UUID,
        startedAt: Date,
        endedAt: Date?,
        targetDuration: TimeInterval?,
        note: String?
    ) async throws -> FastingSessionValue {
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
        await FastingLiveActivityCoordinator.shared.synchronize(session: session)
        SystemSurfaceRefresher.requestRefreshSoon()
        return session
    }

    public func correctWithReceipt(
        sessionID: UUID,
        startedAt: Date,
        endedAt: Date?,
        targetDuration: TimeInterval?,
        note: String?
    ) async throws -> FastingSessionMutationReceipt {
        guard let before = try await recover(limit: 100).first(where: { $0.id == sessionID }) else {
            throw FastingTimerStoreError.sessionNotFound
        }
        let after = try await correct(
            sessionID: sessionID,
            startedAt: startedAt,
            endedAt: endedAt,
            targetDuration: targetDuration,
            note: note
        )
        return .init(before: before, after: after, createdAt: now())
    }

    public func undo(_ receipt: FastingSessionMutationReceipt) async throws {
        try await repository.saveFastingSession(receipt.before)
        await FastingLiveActivityCoordinator.shared.synchronize(session: receipt.before)
        SystemSurfaceRefresher.requestRefreshSoon()
    }

    /// Repairs legacy duplicate-active states deterministically. The newest
    /// session remains active; earlier sessions close just before it began and
    /// are marked cancelled so no elapsed time is fabricated after recovery.
    private func recover(limit: Int) async throws -> [FastingSessionValue] {
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

public enum FastingLiveActivityAction: String, Codable, Hashable, Sendable {
    case finish
    case cancel
}

public struct FastingLiveActivityCommand: Codable, Hashable, Sendable {
    public var id: UUID
    public var sessionID: UUID
    public var action: FastingLiveActivityAction

    public init(id: UUID, sessionID: UUID, action: FastingLiveActivityAction) {
        self.id = id
        self.sessionID = sessionID
        self.action = action
    }
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
import OSLog

actor FastingLiveActivityCoordinator {
    static let shared = FastingLiveActivityCoordinator()
    private let logger = Logger(
        subsystem: "com.saransh1337.To-Do-List",
        category: "FastingLiveActivity"
    )

    @discardableResult
    func synchronize(
        session: FastingSessionValue,
        title: String = "Fasting",
        now: Date = Date()
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let phase = session.endedAt == nil ? "active" : "ended"
        let state = FastingActivityAttributes.ContentState(
            phase: phase,
            startedAt: session.startedAt,
            targetEndAt: session.endedAt == nil ? session.targetEnd : nil,
            elapsedDuration: session.elapsed(at: now),
            updatedAt: session.updatedAt ?? now
        )
        let content = ActivityContent(
            state: state,
            staleDate: session.endedAt == nil ? session.targetEnd : nil
        )
        let existing = Activity<FastingActivityAttributes>.activities.first {
            $0.attributes.sessionID == session.id
        }

        if session.endedAt != nil {
            if let existing {
                await existing.end(content, dismissalPolicy: .immediate)
            }
            return true
        }
        if let existing {
            await existing.update(content)
            return true
        }
        do {
            _ = try Activity.request(
                attributes: FastingActivityAttributes(
                    sessionID: session.id,
                    title: title
                ),
                content: content,
                pushType: nil
            )
            return true
        } catch {
            logger.error(
                "Live Activity start failed; canonical fasting state is unchanged: \(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func endOrphanedActivities(except sessionID: UUID?) async {
        for activity in Activity<FastingActivityAttributes>.activities
        where activity.attributes.sessionID != sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

enum FastingLiveActivityDeepLink {
    static func command(from url: URL) -> FastingLiveActivityCommand? {
        guard
            url.scheme?.lowercased() == "lifeboard",
            url.host?.lowercased() == "fasting",
            let sessionID = url.pathComponents.last.flatMap(UUID.init(uuidString:)),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let rawAction = components.queryItems?.first(where: { $0.name == "command" })?.value,
            let action = FastingLiveActivityAction(rawValue: rawAction),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value
                .flatMap(UUID.init(uuidString:))
        else { return nil }
        return FastingLiveActivityCommand(id: token, sessionID: sessionID, action: action)
    }
}
#else
actor FastingLiveActivityCoordinator {
    static let shared = FastingLiveActivityCoordinator()
    @discardableResult
    func synchronize(
        session: FastingSessionValue,
        title: String = "Fasting",
        now: Date = Date()
    ) async -> Bool { false }
    func endOrphanedActivities(except sessionID: UUID?) async {}
}

enum FastingLiveActivityDeepLink {
    static func command(from url: URL) -> FastingLiveActivityCommand? { nil }
}
#endif

public struct FastingSessionMutationReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let before: FastingSessionValue
    public let after: FastingSessionValue
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        before: FastingSessionValue,
        after: FastingSessionValue,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.before = before
        self.after = after
        self.createdAt = createdAt
    }
}

public struct FastingHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "fasting"
    private let repository: any FastingSessionRepository

    public init(repository: any FastingSessionRepository) {
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
