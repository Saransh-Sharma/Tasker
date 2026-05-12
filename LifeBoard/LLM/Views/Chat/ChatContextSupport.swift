import Combine
import Foundation

actor ChatContextInjectionTracker {
    struct CachedContext {
        let payload: String
        let querySignature: String
        let generatedAt: Date
        let usedTimeoutFallback: Bool
    }

    private var cacheByThreadID: [UUID: CachedContext] = [:]

    func cachedContext(
        for threadID: UUID,
        querySignature: String,
        now: Date,
        throttleMs: UInt64
    ) -> CachedContext? {
        guard throttleMs > 0, let cached = cacheByThreadID[threadID] else {
            return nil
        }
        guard cached.querySignature == querySignature else {
            return nil
        }
        let ageMs = now.timeIntervalSince(cached.generatedAt) * 1_000
        return ageMs < Double(throttleMs) ? cached : nil
    }

    func store(
        threadID: UUID,
        querySignature: String,
        payload: String,
        usedTimeoutFallback: Bool,
        generatedAt: Date
    ) {
        cacheByThreadID[threadID] = CachedContext(
            payload: payload,
            querySignature: querySignature,
            generatedAt: generatedAt,
            usedTimeoutFallback: usedTimeoutFallback
        )
    }

    func clear(threadID: UUID) {
        cacheByThreadID.removeValue(forKey: threadID)
    }
}

enum ChatContextInjectionPolicy {
    case perTurn(throttleMs: UInt64)

    var throttleMs: UInt64 {
        switch self {
        case .perTurn(let throttleMs):
            return throttleMs
        }
    }

    var rawValue: String {
        switch self {
        case .perTurn:
            return "per_turn"
        }
    }
}

enum ThreadContextAttachmentKind: String, Codable, Sendable {
    case slashCommand
}

enum ThreadContextAttachmentCategory: String, Codable, CaseIterable, Sendable {
    case timeSlice
    case project
    case lifeArea
    case backlog
}

struct ThreadContextAttachmentRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let threadID: UUID
    let kind: ThreadContextAttachmentKind
    let category: ThreadContextAttachmentCategory
    let commandID: SlashCommandID
    let commandLabel: String
    let summary: String
    let commandResult: SlashCommandExecutionResult
    let createdAt: Date

    init(
        id: UUID = UUID(),
        threadID: UUID,
        kind: ThreadContextAttachmentKind = .slashCommand,
        category: ThreadContextAttachmentCategory,
        commandID: SlashCommandID,
        commandLabel: String,
        summary: String,
        commandResult: SlashCommandExecutionResult,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.kind = kind
        self.category = category
        self.commandID = commandID
        self.commandLabel = commandLabel
        self.summary = summary
        self.commandResult = commandResult
        self.createdAt = createdAt
    }
}

extension SlashCommandID {
    var attachmentCategory: ThreadContextAttachmentCategory? {
        switch self {
        case .today, .tomorrow, .week, .month:
            return .timeSlice
        case .project:
            return .project
        case .area:
            return .lifeArea
        case .recent, .overdue:
            return .backlog
        case .clear:
            return nil
        }
    }
}

private struct ThreadContextAttachmentStoreFile: Codable, Sendable {
    var version: Int = 1
    var threads: [String: [ThreadContextAttachmentRecord]] = [:]
}

actor ThreadContextAttachmentStore {
    static let shared = ThreadContextAttachmentStore()

    private var cachedFile = ThreadContextAttachmentStoreFile()
    private var hasLoaded = false

    private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return appSupport.appendingPathComponent("llm-thread-context-attachments.json")
    }

    private func loadIfNeeded() {
        guard hasLoaded == false else { return }
        defer { hasLoaded = true }

        let url = Self.storeURL()
        guard let data = try? Data(contentsOf: url) else { return }
        guard let decoded = try? JSONDecoder().decode(ThreadContextAttachmentStoreFile.self, from: data) else {
            return
        }
        cachedFile = decoded
    }

    private func persist() {
        let url = Self.storeURL()
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        guard let data = try? JSONEncoder().encode(cachedFile) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func attachments(for threadID: UUID) -> [ThreadContextAttachmentRecord] {
        loadIfNeeded()
        return cachedFile.threads[threadID.uuidString, default: []]
            .sorted { $0.createdAt > $1.createdAt }
    }

    func upsert(
        _ record: ThreadContextAttachmentRecord,
        maxAttachmentsPerThread: Int = 3
    ) -> [ThreadContextAttachmentRecord] {
        loadIfNeeded()
        var records = cachedFile.threads[record.threadID.uuidString, default: []]
        records.removeAll { $0.category == record.category }
        records.insert(record, at: 0)
        records = Array(records.sorted { $0.createdAt > $1.createdAt }.prefix(maxAttachmentsPerThread))
        cachedFile.threads[record.threadID.uuidString] = records
        persist()
        return records
    }

    func remove(attachmentID: UUID, threadID: UUID) -> [ThreadContextAttachmentRecord] {
        loadIfNeeded()
        var records = cachedFile.threads[threadID.uuidString, default: []]
        records.removeAll { $0.id == attachmentID }
        cachedFile.threads[threadID.uuidString] = records
        persist()
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    func clear(threadID: UUID) {
        loadIfNeeded()
        cachedFile.threads.removeValue(forKey: threadID.uuidString)
        persist()
    }
}

enum ThreadContextAttachmentResolver {
    static func promptBlock(
        for attachments: [ThreadContextAttachmentRecord],
        tokenBudget: Int
    ) -> String? {
        guard attachments.isEmpty == false else { return nil }

        var lines = ["Pinned context:"]
        for attachment in attachments.sorted(by: { $0.createdAt > $1.createdAt }) {
            lines.append("- \(attachment.commandLabel): \(attachment.summary)")
            for section in attachment.commandResult.sections.prefix(2) {
                lines.append("\(section.title):")
                for task in section.tasks.prefix(4) {
                    var parts = [task.title]
                    if let dueLabel = task.dueLabel, dueLabel.isEmpty == false {
                        parts.append(dueLabel)
                    }
                    if task.projectName.isEmpty == false {
                        parts.append(task.projectName)
                    }
                    lines.append("- " + parts.joined(separator: " | "))
                }
            }
        }

        let block = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard block.isEmpty == false else { return nil }
        return LLMTokenBudgetEstimator.trimPrefix(block, toTokenBudget: tokenBudget)
    }
}

@MainActor
final class ChatContextCoordinator: ObservableObject {
    @Published private(set) var activeAttachments: [ThreadContextAttachmentRecord] = []
    private var boundThreadID: UUID?

    func loadAttachments(for threadID: UUID?) {
        boundThreadID = threadID
        guard let threadID else {
            activeAttachments = []
            return
        }

        let currentThreadID = threadID
        Task {
            let attachments = await ThreadContextAttachmentStore.shared.attachments(for: currentThreadID)
            await MainActor.run {
                guard self.boundThreadID == currentThreadID else { return }
                self.activeAttachments = attachments
            }
        }
    }

    func upsert(commandResult: SlashCommandExecutionResult, threadID: UUID) {
        guard V2FeatureFlags.llmSlashPinsEnabled,
              let category = commandResult.commandID.attachmentCategory else {
            return
        }

        let record = ThreadContextAttachmentRecord(
            threadID: threadID,
            category: category,
            commandID: commandResult.commandID,
            commandLabel: commandResult.commandLabel,
            summary: commandResult.summary,
            commandResult: commandResult
        )
        let currentThreadID = threadID

        Task {
            let attachments = await ThreadContextAttachmentStore.shared.upsert(record)
            await MainActor.run {
                guard self.boundThreadID == currentThreadID else { return }
                self.activeAttachments = attachments
            }
            logWarning(
                event: "chat_slash_pin_upserted",
                message: "Stored thread-scoped slash context pin",
                fields: [
                    "thread_id": threadID.uuidString,
                    "command_id": commandResult.commandID.rawValue,
                    "category": category.rawValue,
                    "active_pin_count": String(attachments.count)
                ]
            )
        }
    }

    func remove(_ record: ThreadContextAttachmentRecord) {
        let currentThreadID = record.threadID
        Task {
            let attachments = await ThreadContextAttachmentStore.shared.remove(
                attachmentID: record.id,
                threadID: currentThreadID
            )
            await MainActor.run {
                guard self.boundThreadID == currentThreadID else { return }
                self.activeAttachments = attachments
            }
            logWarning(
                event: "chat_slash_pin_removed",
                message: "Removed thread-scoped slash context pin",
                fields: [
                    "thread_id": record.threadID.uuidString,
                    "command_id": record.commandID.rawValue,
                    "category": record.category.rawValue,
                    "active_pin_count": String(attachments.count)
                ]
            )
        }
    }

    func clear(threadID: UUID?) {
        boundThreadID = threadID
        guard let threadID else {
            activeAttachments = []
            return
        }
        let currentThreadID = threadID
        Task {
            await ThreadContextAttachmentStore.shared.clear(threadID: currentThreadID)
            await MainActor.run {
                guard self.boundThreadID == currentThreadID else { return }
                self.activeAttachments = []
            }
            logWarning(
                event: "chat_slash_pins_cleared",
                message: "Cleared all thread-scoped slash context pins",
                fields: ["thread_id": currentThreadID.uuidString]
            )
        }
    }
}
