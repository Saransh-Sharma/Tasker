import Foundation

extension Notification.Name {
    static let taskerEvaChatLaunchRequestDidChange = Notification.Name("TaskerEvaChatLaunchRequestDidChange")
}

struct EvaChatLaunchRequest: Codable, Equatable {
    let id: UUID
    let prompt: String?
    let createdAt: Date

    init(id: UUID = UUID(), prompt: String?, createdAt: Date = Date()) {
        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.prompt = trimmedPrompt?.isEmpty == false ? trimmedPrompt : nil
        self.createdAt = createdAt
    }
}

enum PendingShortcutLaunchActionKind: String, Codable {
    case askEva
    case startFocus
}

struct PendingShortcutLaunchAction: Codable, Equatable {
    let id: UUID
    let kind: PendingShortcutLaunchActionKind
    let prompt: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: PendingShortcutLaunchActionKind,
        prompt: String? = nil,
        createdAt: Date = Date()
    ) {
        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.kind = kind
        self.prompt = trimmedPrompt?.isEmpty == false ? trimmedPrompt : nil
        self.createdAt = createdAt
    }
}

enum ShortcutMutationSignalKind: String, Codable {
    case taskCreated
}

struct ShortcutMutationSignal: Codable, Equatable {
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
            return "Tasker shortcut handoff is unavailable right now."
        case .encodeFailed:
            return "Tasker could not save the shortcut request."
        }
    }
}

private enum ShortcutHandoffStoreKey {
    static let chatLaunchRequest = "tasker.shortcut.chatLaunchRequest.v1"
    static let pendingLaunchAction = "tasker.shortcut.pendingLaunchAction.v1"
    static let mutationSignal = "tasker.shortcut.mutationSignal.v1"
}

private final class ShortcutHandoffCodableStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let now: () -> Date

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
    }

    func save<T: Encodable>(_ value: T, key: String) throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw ShortcutHandoffStoreError.encodeFailed
        }
        defaults.set(data, forKey: key)
        _ = defaults.synchronize()
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
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

final class EvaChatLaunchRequestStore {
    static let shared = EvaChatLaunchRequestStore()
    private static let maxAge: TimeInterval = 10 * 60

    private let store: ShortcutHandoffCodableStore

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = ShortcutHandoffCodableStore(defaults: defaults, now: now)
    }

    func submit(_ request: EvaChatLaunchRequest) throws {
        try store.save(request, key: ShortcutHandoffStoreKey.chatLaunchRequest)
        NotificationCenter.default.post(name: .taskerEvaChatLaunchRequestDidChange, object: nil)
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

final class PendingShortcutLaunchActionStore {
    static let shared = PendingShortcutLaunchActionStore()
    private static let maxAge: TimeInterval = 10 * 60

    private let store: ShortcutHandoffCodableStore

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping () -> Date = Date.init
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

final class ShortcutMutationSignalStore {
    static let shared = ShortcutMutationSignalStore()
    private static let maxAge: TimeInterval = 10 * 60

    private let store: ShortcutHandoffCodableStore

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? UserDefaults.standard,
        now: @escaping () -> Date = Date.init
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
