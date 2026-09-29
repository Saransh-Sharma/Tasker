import Foundation
import LifeBoardContracts

extension Notification.Name {
    static let lifeboardEvaChatLaunchRequestDidChange = Notification.Name("LifeBoardEvaChatLaunchRequestDidChange")
}

/// What Eva is being asked about, as records rather than prose: the chat
/// turns it into context attachments, so the envelope stays "records, not
/// prose" and the journal consent gate still applies.
struct EvaLaunchContext: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case day, task, habit, journalDay, insight, project
    }

    let kind: Kind
    /// Record ids the context points at (task, habit, journal day, project, evidence).
    let recordIDs: [UUID]
    /// A day, when `kind` is `.day` or `.journalDay`.
    let date: Date?
    /// One line for the sheet's header; never the record's content.
    let summary: String?

    init(kind: Kind, recordIDs: [UUID] = [], date: Date? = nil, summary: String? = nil) {
        self.kind = kind
        self.recordIDs = recordIDs
        self.date = date
        self.summary = summary
    }

    var title: String {
        switch kind {
        case .day: "About today"
        case .task: "About this task"
        case .habit: "About this habit"
        case .journalDay: "About this day"
        case .insight: "About this pattern"
        case .project: "About this project"
        }
    }
}

struct EvaChatLaunchRequest: Codable, Equatable, Sendable {
    let id: UUID
    let prompt: String?
    let createdAt: Date
    /// Optional so requests written before contexts existed still decode.
    let context: EvaLaunchContext?

    init(id: UUID = UUID(), prompt: String?, context: EvaLaunchContext? = nil, createdAt: Date = Date()) {
        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.prompt = trimmedPrompt?.isEmpty == false ? trimmedPrompt : nil
        self.context = context
        self.createdAt = createdAt
    }
}

enum PendingShortcutLaunchActionKind: String, Codable, Sendable {
    case askEva
    case startFocus
}

struct PendingShortcutLaunchAction: Codable, Equatable, Sendable {
    let id: UUID
    let kind: PendingShortcutLaunchActionKind
    let prompt: String?
    /// For `.startFocus`: which `FocusPreset` to start. Optional so payloads
    /// written before presets existed still decode (nil = the default preset).
    let presetID: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: PendingShortcutLaunchActionKind,
        prompt: String? = nil,
        presetID: String? = nil,
        createdAt: Date = Date()
    ) {
        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.kind = kind
        self.prompt = trimmedPrompt?.isEmpty == false ? trimmedPrompt : nil
        self.presetID = presetID
        self.createdAt = createdAt
    }
}

enum ShortcutMutationSignalKind: String, Codable, Sendable {
    case taskCreated
}

struct ShortcutMutationSignal: Codable, Equatable, Sendable {
    let id: UUID
    let kind: ShortcutMutationSignalKind
    let taskID: UUID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: ShortcutMutationSignalKind,
        taskID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.taskID = taskID
        self.createdAt = createdAt
    }
}

enum ShortcutHandoffStoreError: LocalizedError {
    case unavailable
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "LifeBoard shortcut handoff is unavailable right now."
        case .encodeFailed:
            return "LifeBoard could not save the shortcut request."
        }
    }
}

private enum ShortcutHandoffStoreKey {
    static let chatLaunchRequest = "lifeboard.shortcut.chatLaunchRequest.v1"
    static let pendingLaunchAction = "lifeboard.shortcut.pendingLaunchAction.v1"
    static let mutationSignal = "lifeboard.shortcut.mutationSignal.v1"
}

private final class ShortcutHandoffCodableStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private let now: @Sendable () -> Date

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.now = now
    }

    func save<T: Encodable>(_ value: T, key: String) throws {
        let data: Data
        do {
            lock.lock()
            defer { lock.unlock() }
            data = try encoder.encode(value)
        } catch {
            throw ShortcutHandoffStoreError.encodeFailed
        }
        defaults.set(data, forKey: key)
        _ = defaults.synchronize()
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return try? decoder.decode(type, from: data)
    }

    func remove(key: String) {
        defaults.removeObject(forKey: key)
        _ = defaults.synchronize()
    }

    func consumeIfFresh<T: Decodable>(
        _ type: T.Type,
        key: String,
        createdAt: (T) -> Date,
        maxAge: TimeInterval
    ) -> T? {
        guard let value = load(type, key: key) else { return nil }
        if now().timeIntervalSince(createdAt(value)) > maxAge {
            remove(key: key)
            return nil
        }
        remove(key: key)
        return value
    }
}

final class EvaChatLaunchRequestStore: @unchecked Sendable {
    static let shared = EvaChatLaunchRequestStore()
    private static let maxAge: TimeInterval = 10 * 60

    private let store: ShortcutHandoffCodableStore

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = ShortcutHandoffCodableStore(defaults: defaults, now: now)
    }

    func submit(_ request: EvaChatLaunchRequest) throws {
        try store.save(request, key: ShortcutHandoffStoreKey.chatLaunchRequest)
        NotificationCenter.default.post(name: .lifeboardEvaChatLaunchRequestDidChange, object: nil)
    }

    func consumePendingRequest() -> EvaChatLaunchRequest? {
        store.consumeIfFresh(
            EvaChatLaunchRequest.self,
            key: ShortcutHandoffStoreKey.chatLaunchRequest,
            createdAt: \.createdAt,
            maxAge: Self.maxAge
        )
    }
}

final class PendingShortcutLaunchActionStore: @unchecked Sendable {
    static let shared = PendingShortcutLaunchActionStore()
    private static let maxAge: TimeInterval = 10 * 60

    private let store: ShortcutHandoffCodableStore

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = ShortcutHandoffCodableStore(defaults: defaults, now: now)
    }

    func submit(_ action: PendingShortcutLaunchAction) throws {
        try store.save(action, key: ShortcutHandoffStoreKey.pendingLaunchAction)
    }

    func consumePendingAction() -> PendingShortcutLaunchAction? {
        store.consumeIfFresh(
            PendingShortcutLaunchAction.self,
            key: ShortcutHandoffStoreKey.pendingLaunchAction,
            createdAt: \.createdAt,
            maxAge: Self.maxAge
        )
    }
}

final class ShortcutMutationSignalStore: @unchecked Sendable {
    static let shared = ShortcutMutationSignalStore()
    private static let maxAge: TimeInterval = 10 * 60

    private let store: ShortcutHandoffCodableStore

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = ShortcutHandoffCodableStore(defaults: defaults, now: now)
    }

    func submitTaskCreated(taskID: UUID?) throws {
        let signal = ShortcutMutationSignal(kind: .taskCreated, taskID: taskID)
        try store.save(signal, key: ShortcutHandoffStoreKey.mutationSignal)
    }

    func consumePendingSignal() -> ShortcutMutationSignal? {
        store.consumeIfFresh(
            ShortcutMutationSignal.self,
            key: ShortcutHandoffStoreKey.mutationSignal,
            createdAt: \.createdAt,
            maxAge: Self.maxAge
        )
    }
}
