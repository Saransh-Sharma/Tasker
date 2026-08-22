import Foundation
import LifeBoardDomain

struct AssistantExecutionTrace: Codable, Sendable {
    var runID: UUID?
    var commandCount: Int
    var startedAt: Date
    var finishedAt: Date?
    var durationMillis: Int?
    var status: String
    var rollbackVerified: Bool?
    var failureReason: String?
    var createdReferences: [EvaRecordReference]

    private enum CodingKeys: String, CodingKey {
        case runID, commandCount, startedAt, finishedAt, durationMillis, status
        case rollbackVerified, failureReason, createdReferences
    }

    init(
        runID: UUID?, commandCount: Int, startedAt: Date, finishedAt: Date?,
        durationMillis: Int?, status: String, rollbackVerified: Bool?,
        failureReason: String?, createdReferences: [EvaRecordReference] = []
    ) {
        self.runID = runID
        self.commandCount = commandCount
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.durationMillis = durationMillis
        self.status = status
        self.rollbackVerified = rollbackVerified
        self.failureReason = failureReason
        self.createdReferences = createdReferences
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            runID: try values.decodeIfPresent(UUID.self, forKey: .runID),
            commandCount: try values.decode(Int.self, forKey: .commandCount),
            startedAt: try values.decode(Date.self, forKey: .startedAt),
            finishedAt: try values.decodeIfPresent(Date.self, forKey: .finishedAt),
            durationMillis: try values.decodeIfPresent(Int.self, forKey: .durationMillis),
            status: try values.decode(String.self, forKey: .status),
            rollbackVerified: try values.decodeIfPresent(Bool.self, forKey: .rollbackVerified),
            failureReason: try values.decodeIfPresent(String.self, forKey: .failureReason),
            createdReferences: try values.decodeIfPresent([EvaRecordReference].self, forKey: .createdReferences) ?? []
        )
    }
}

// MARK: - Durable multi-domain capture lane

enum EvaCaptureCommand: Codable, Hashable, Sendable {
    case logBodyMetric(BodyMetricSample)
    case captureNote(title: String, text: String, capturedAt: Date)
    case appendJournal(text: String, capturedAt: Date)
    case recordTrackerValue(trackerID: UUID, trackerTitle: String, value: Double, capturedAt: Date)
    case logMood(mood: JournalMood, energy: Int?, capturedAt: Date)
    case logHydration(HydrationLog)
    case captureLifeMoment(title: String, eventDate: Date, capturedAt: Date)

    fileprivate enum Family: String, Codable, Sendable {
        case bodyMetric, note, journal, tracker, mood, hydration, lifeMoment
    }

    fileprivate var family: Family {
        switch self {
        case .logBodyMetric: .bodyMetric
        case .captureNote: .note
        case .appendJournal: .journal
        case .recordTrackerValue: .tracker
        case .logMood: .mood
        case .logHydration: .hydration
        case .captureLifeMoment: .lifeMoment
        }
    }

    fileprivate var effectiveDate: Date {
        switch self {
        case .logBodyMetric(let value): value.observedAt
        case .captureNote(_, _, let capturedAt): capturedAt
        case .appendJournal(_, let capturedAt): capturedAt
        case .recordTrackerValue(_, _, _, let capturedAt): capturedAt
        case .logMood(_, _, let capturedAt): capturedAt
        case .logHydration(let value): value.timestamp
        case .captureLifeMoment(_, _, let capturedAt): capturedAt
        }
    }
}

enum EvaCaptureUndo: Codable, Hashable, Sendable {
    case deleteNote(UUID)
    case restoreJournalDay(previous: JournalDayValue?, createdID: UUID)
    case deleteWellnessRecord(kind: WellnessRecordKind, id: UUID)
    case deleteTrackerEntry(UUID)
    case deleteMood(UUID)
    case deleteHydration(UUID)
    case deleteLifeMoment(UUID)
    case none(reason: String)
}

struct EvaCaptureReceipt: Codable, Sendable {
    let schemaVersion: Int
    let commands: [EvaCaptureCommand]
    let undo: [EvaCaptureUndo]
    let createdReferences: [EvaRecordReference]
    let appliedAt: Date
}

struct EvaCaptureRepositories: Sendable {
    let assistantActions: AssistantActionRepositoryProtocol
    let phaseII: any PhaseIIRepository
    let track: any TrackFoundationRepository
    let wellness: any WellnessRepository
    let lifeMoments: any LifeMomentRepository
}

enum EvaCaptureLaneResult: Sendable {
    case applied(run: AssistantActionRunDefinition, references: [EvaRecordReference], message: String)
    case review(message: String)
}

enum EvaCaptureParseResult: Sendable {
    case commands([EvaCaptureCommand])
    case review(String)
}

struct EvaCaptureBatchPolicy: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func reviewReason(commands: [EvaCaptureCommand], now: Date) -> String? {
        guard commands.isEmpty == false else { return "There is nothing to capture." }
        guard commands.count <= 3 else { return "I can safely auto-capture up to three records at once. Review this larger batch first." }
        guard Set(commands.map(\.family)).count == 1 else { return "This request mixes record types, so I need you to review the whole batch before saving." }
        guard commands.allSatisfy({ calendar.isDate($0.effectiveDate, inSameDayAs: now) }) else {
            return "Backdated capture needs review so Eva does not silently change your history."
        }
        return nil
    }
}

/// Deterministic local parser for privacy-sensitive capture. The model may
/// classify the route, but raw journal/note text never needs to leave device
/// for the common direct-capture forms.
enum EvaCaptureCommandParser {
    static func parse(_ input: String, now: Date = Date()) async -> EvaCaptureParseResult {
        let segments = input
            .split(separator: ";", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard segments.isEmpty == false else { return .review("Tell me what you want to capture.") }
        var commands: [EvaCaptureCommand] = []
        for segment in segments {
            guard let command = await parseOne(segment, now: now) else {
                return .review(reviewMessage(for: segment))
            }
            commands.append(command)
        }
        return .commands(commands)
    }

    private static func parseOne(_ input: String, now: Date) async -> EvaCaptureCommand? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains("medication") || normalized.contains("dose")
            || normalized.contains("fasting") || normalized.contains("calories") {
            return nil
        }

        if let match = firstMatch(
            #"(?:weight|weigh(?:ed)?)(?:\s+(?:is|at|was))?\s*([0-9]+(?:\.[0-9]+)?)\s*(kg|kgs|kilograms?|lb|lbs|pounds?)?"#,
            in: normalized
        ), let amount = Double(match[1]) {
            let pounds = match.count > 2 && match[2].hasPrefix("lb") || (match.count > 2 && match[2].hasPrefix("pound"))
            let unit: WellnessDisplayUnit = pounds ? .pounds : .kilograms
            guard let sample = try? BodyMetricSample(
                kind: .bodyMass,
                value: amount,
                unit: unit,
                observedAt: inferredCaptureDate(from: normalized, now: now),
                source: .manual,
                sourceIdentifier: "eva_capture"
            ) else { return nil }
            return .logBodyMetric(sample)
        }

        if let match = firstMatch(#"(?:drank|drink|hydration|water)\s*([0-9]+(?:\.[0-9]+)?)\s*(ml|milliliters?|l|liters?)"#, in: normalized),
           let amount = Double(match[1]) {
            let milliliters = match[2].hasPrefix("l") ? amount * 1_000 : amount
            return .logHydration(.init(
                amount: milliliters,
                unit: .milliliters,
                timestamp: inferredCaptureDate(from: normalized, now: now),
                source: .manual,
                sourceIdentifier: "eva_capture"
            ))
        }

        if normalized.hasPrefix("note that ") || normalized.hasPrefix("save a note ")
            || normalized.hasPrefix("note: ") || normalized.hasPrefix("remember this: ") {
            let text = strippingPrefix(input, prefixes: ["note that ", "save a note ", "note: ", "remember this: "])
            guard text.isEmpty == false else { return nil }
            return .captureNote(title: noteTitle(from: text), text: text, capturedAt: now)
        }

        if normalized.hasPrefix("journal ") || normalized.hasPrefix("journal: ")
            || normalized.hasPrefix("add to my journal ") || normalized.hasPrefix("write in my journal ") {
            let text = strippingPrefix(input, prefixes: ["add to my journal ", "write in my journal ", "journal: ", "journal "])
            guard text.isEmpty == false else { return nil }
            return .appendJournal(text: text, capturedAt: inferredCaptureDate(from: normalized, now: now))
        }

        if normalized.contains("mood") || normalized.hasPrefix("feeling ") || normalized.hasPrefix("i feel ") {
            let mood = JournalMood.allCases.first(where: { $0 != .none && normalized.contains($0.rawValue) })
                ?? numericMood(in: normalized)
            if let mood {
                let energy = firstMatch(#"energy\s*([1-5])"#, in: normalized).flatMap { Int($0[1]) }
                return .logMood(mood: mood, energy: energy, capturedAt: inferredCaptureDate(from: normalized, now: now))
            }
        }

        if let match = firstMatch(#"(?:log|record)\s+([0-9]+(?:\.[0-9]+)?)\s+(?:for|in)\s+(.+)"#, in: input),
           let value = Double(match[1]), let repository = LLMContextRepositoryFactory.phaseIIRepository {
            let query = match[2].trimmingCharacters(in: .whitespacesAndNewlines)
            if let tracker = try? await repository.fetchTrackers().filter({
                $0.isArchived == false && $0.title.localizedCaseInsensitiveContains(query)
            }).first {
                return .recordTrackerValue(
                    trackerID: tracker.id,
                    trackerTitle: tracker.title,
                    value: value,
                    capturedAt: inferredCaptureDate(from: normalized, now: now)
                )
            }
        }

        if let match = firstMatch(#"(?:remember|life moment)\s+(?:that\s+)?(.+?)\s+(?:is\s+)?on\s+(\d{4}-\d{2}-\d{2})"#, in: input),
           let date = parseDay(match[2]) {
            return .captureLifeMoment(title: match[1], eventDate: date, capturedAt: now)
        }
        return nil
    }

    private static func reviewMessage(for input: String) -> String {
        let value = input.lowercased()
        if value.contains("medication") || value.contains("dose") {
            return "Medication records are safety-relevant, so Eva will not auto-apply them. Please review and log this in Medication."
        }
        if value.contains("fasting") {
            return "Fasting controls change a live timer, so open Fasting to review this action."
        }
        if value.contains("calories") || value.contains("meal") {
            return "Nutrition capture needs a review surface before Eva can write it safely."
        }
        return "I understood this as a capture request, but I need you to review the record type or value before saving it."
    }

    private static func firstMatch(_ pattern: String, in input: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: input) else { return "" }
            return String(input[range])
        }
    }

    private static func strippingPrefix(_ input: String, prefixes: [String]) -> String {
        let lower = input.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix) {
            return String(input.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func noteTitle(from text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return String(line.prefix(72)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func numericMood(in input: String) -> JournalMood? {
        guard let match = firstMatch(#"mood\s*(?:is|at|:)?\s*([1-5])"#, in: input), let value = Int(match[1]) else { return nil }
        return [.sad, .tired, .calm, .happy, .excited][value - 1]
    }

    private static func inferredCaptureDate(from input: String, now: Date) -> Date {
        if input.contains("yesterday") { return Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now }
        if input.contains("tomorrow") { return Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now }
        return now
    }

    private static func parseDay(_ input: String) -> Date? {
        let parts = input.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.autoupdatingCurrent.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts[2], hour: 12
        ))
    }
}

final class EvaCaptureLaneUseCase: @unchecked Sendable {
    private let repositories: EvaCaptureRepositories
    private let calendar: Calendar
    private let undoWindow: TimeInterval = 30 * 60

    init(repositories: EvaCaptureRepositories, calendar: Calendar = .autoupdatingCurrent) {
        self.repositories = repositories
        self.calendar = calendar
    }

    func apply(threadID: String, commands: [EvaCaptureCommand], now: Date = Date()) async throws -> EvaCaptureLaneResult {
        if let review = try await reviewReason(commands: commands, now: now) { return .review(message: review) }
        var undo: [EvaCaptureUndo] = []
        var references: [EvaRecordReference] = []
        do {
            for command in commands {
                let result = try await execute(command, now: now)
                undo.append(result.undo)
                references.append(result.reference)
            }
        } catch {
            for inverse in undo.reversed() { try? await executeUndo(inverse) }
            throw error
        }

        let receipt = EvaCaptureReceipt(
            schemaVersion: 1,
            commands: commands,
            undo: undo,
            createdReferences: references,
            appliedAt: now
        )
        let trace = AssistantExecutionTrace(
            runID: nil,
            commandCount: commands.count,
            startedAt: now,
            finishedAt: Date(),
            durationMillis: Int(Date().timeIntervalSince(now) * 1_000),
            status: "applied",
            rollbackVerified: nil,
            failureReason: nil,
            createdReferences: references
        )
        let run = AssistantActionRunDefinition(
            id: UUID(),
            threadID: threadID,
            proposalData: try JSONEncoder().encode(receipt),
            status: .applied,
            confirmedAt: now,
            appliedAt: now,
            resultSummary: summary(for: references),
            executionTraceData: try? JSONEncoder().encode(trace),
            rollbackStatus: .notNeeded,
            createdAt: now
        )
        do {
            let persisted = try await createRun(run)
            return .applied(run: persisted, references: references, message: summary(for: references))
        } catch {
            for inverse in undo.reversed() { try? await executeUndo(inverse) }
            throw error
        }
    }

    func undo(runID: UUID, now: Date = Date()) async throws -> AssistantActionRunDefinition {
        guard var run = try await fetchRun(runID) else { throw captureError(404, "That capture no longer exists.") }
        guard run.status == .applied else { throw captureError(409, "That capture has already been handled.") }
        guard let appliedAt = run.appliedAt, now.timeIntervalSince(appliedAt) <= undoWindow else {
            throw captureError(410, "The 30-minute undo window has expired.")
        }
        guard let data = run.proposalData,
              let receipt = try? JSONDecoder().decode(EvaCaptureReceipt.self, from: data) else {
            throw captureError(422, "The durable undo receipt could not be read.")
        }
        for inverse in receipt.undo.reversed() { try await executeUndo(inverse) }
        run.status = .undone
        run.resultSummary = "Capture undone"
        run.rollbackStatus = .verified
        run.rollbackVerifiedAt = now
        return try await updateRun(run)
    }

    private func reviewReason(commands: [EvaCaptureCommand], now: Date) async throws -> String? {
        if let reason = EvaCaptureBatchPolicy(calendar: calendar).reviewReason(commands: commands, now: now) {
            return reason
        }
        for command in commands {
            if case .logBodyMetric(let sample) = command {
                switch WellnessOutlierPolicy().review(kind: sample.kind, normalizedValue: sample.normalizedValue) {
                case .accepted: break
                case .requiresConfirmation(let message): return message
                }
                if let prior = try await repositories.wellness.bodyMetricSamples(kind: sample.kind)
                    .first(where: { calendar.isDate($0.observedAt, inSameDayAs: sample.observedAt) }) {
                    let time = prior.observedAt.formatted(date: .omitted, time: .shortened)
                    return "You logged \(prior.normalizedValue.formatted(.number.precision(.fractionLength(0...1)))) kg at \(time). Add another or replace it?"
                }
            }
            if case .logHydration(let value) = command, !(1...5_000).contains(value.amount) {
                return "That hydration amount is outside the 1–5000 ml safe capture range. Review the number and unit."
            }
        }
        return nil
    }

    private func execute(_ command: EvaCaptureCommand, now: Date) async throws -> (undo: EvaCaptureUndo, reference: EvaRecordReference) {
        switch command {
        case .logBodyMetric(let sample):
            try await repositories.wellness.save(sample)
            return (.deleteWellnessRecord(kind: .bodyMetric, id: sample.id), .init(
                kind: .bodyMetric, recordID: sample.id,
                title: "Weight \(sample.normalizedValue.formatted(.number.precision(.fractionLength(0...1)))) kg",
                occurredAt: sample.observedAt
            ))
        case .captureNote(let title, let text, let capturedAt):
            let spaces = try await repositories.phaseII.fetchKnowledgeSpaces()
            let space: KnowledgeSpaceValue
            if let existing = spaces.first { space = existing }
            else {
                space = KnowledgeSpaceValue(title: "Notes", icon: "note.text")
                try await repositories.phaseII.saveKnowledgeSpace(space)
            }
            let id = UUID()
            let note = KnowledgeNoteValue(
                id: id,
                spaceID: space.id,
                title: title,
                createdAt: capturedAt,
                updatedAt: capturedAt,
                blocks: [.init(noteID: id, text: text, ordinal: 0, createdAt: capturedAt, updatedAt: capturedAt)]
            )
            try await repositories.phaseII.saveKnowledgeNote(note)
            try await KnowledgeIndexingService(repository: repositories.phaseII).upsert(note)
            return (.deleteNote(note.id), .init(kind: .note, recordID: note.id, title: note.displayTitle, occurredAt: capturedAt))
        case .appendJournal(let text, let capturedAt):
            let prior = try await repositories.phaseII.fetchJournalDay(containing: capturedAt)
            let dayID = prior?.id ?? UUID()
            var day = prior ?? JournalDayValue(id: dayID, day: calendar.startOfDay(for: capturedAt), createdAt: capturedAt, updatedAt: capturedAt)
            day.blocks.append(.init(dayID: dayID, kind: .text, text: text, createdAt: capturedAt, updatedAt: capturedAt, ordinal: day.blocks.count))
            day.updatedAt = capturedAt
            try await repositories.phaseII.saveJournalDay(day)
            try await JournalIndexingService(repository: repositories.phaseII).upsert(day)
            return (.restoreJournalDay(previous: prior, createdID: day.id), .init(kind: .journal, recordID: day.id, title: "Journal — \(day.day.formatted(date: .abbreviated, time: .omitted))", occurredAt: capturedAt))
        case .recordTrackerValue(let trackerID, let trackerTitle, let value, let capturedAt):
            let entry = TrackerEntryValue(trackerID: trackerID, timestamp: capturedAt, numericValue: value, value: .quantity(value, unit: nil))
            try await repositories.phaseII.saveTrackerEntry(entry)
            return (.deleteTrackerEntry(entry.id), .init(kind: .tracker, recordID: trackerID, title: trackerTitle, subtitle: value.formatted(), occurredAt: capturedAt))
        case .logMood(let mood, let energy, let capturedAt):
            let value = MoodEnergyCheckInValue(mood: mood, energy: energy, createdAt: capturedAt)
            try await repositories.phaseII.saveMoodCheckIn(value)
            return (.deleteMood(value.id), .init(kind: .mood, recordID: value.id, title: mood.title, occurredAt: capturedAt))
        case .logHydration(let value):
            try await repositories.track.saveHydrationLog(value)
            return (.deleteHydration(value.id), .init(kind: .hydration, recordID: value.id, title: "Hydration", subtitle: "\(value.amount.formatted()) ml", occurredAt: value.timestamp))
        case .captureLifeMoment(let title, let eventDate, let capturedAt):
            let value = try LifeMoment(title: title, kind: .countdown, eventDate: eventDate, createdAt: capturedAt, updatedAt: capturedAt)
            try await repositories.lifeMoments.save(value)
            return (.deleteLifeMoment(value.id), .init(kind: .lifeMoment, recordID: value.id, title: value.title, occurredAt: eventDate))
        }
    }

    private func executeUndo(_ undo: EvaCaptureUndo) async throws {
        switch undo {
        case .deleteNote(let id):
            try await repositories.phaseII.deleteKnowledgeNote(id: id)
            try? await KnowledgeIndexingService(repository: repositories.phaseII).remove(noteID: id)
        case .restoreJournalDay(let previous, let createdID):
            if let previous {
                try await repositories.phaseII.saveJournalDay(previous)
                try await JournalIndexingService(repository: repositories.phaseII).upsert(previous)
            } else {
                try await repositories.phaseII.deleteJournalDay(id: createdID)
                try? await JournalIndexingService(repository: repositories.phaseII).remove(dayID: createdID)
            }
        case .deleteWellnessRecord(let kind, let id): try await repositories.wellness.delete(kind: kind, id: id)
        case .deleteTrackerEntry(let id): try await repositories.phaseII.deleteTrackerEntry(id: id)
        case .deleteMood(let id): try await repositories.phaseII.deleteMoodCheckIn(id: id)
        case .deleteHydration(let id): try await repositories.track.deleteHydrationLog(id: id)
        case .deleteLifeMoment(let id): try await repositories.lifeMoments.delete(id: id)
        case .none: break
        }
    }

    private func summary(for references: [EvaRecordReference]) -> String {
        if references.count == 1, let first = references.first { return "Captured \(first.title)." }
        return "Captured \(references.count) \(references.first?.kind.rawValue ?? "records") entries."
    }

    private func createRun(_ run: AssistantActionRunDefinition) async throws -> AssistantActionRunDefinition {
        try await withCheckedThrowingContinuation { continuation in
            repositories.assistantActions.createRun(run) { continuation.resume(with: $0) }
        }
    }

    private func fetchRun(_ id: UUID) async throws -> AssistantActionRunDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            repositories.assistantActions.fetchRun(id: id) { continuation.resume(with: $0) }
        }
    }

    private func updateRun(_ run: AssistantActionRunDefinition) async throws -> AssistantActionRunDefinition {
        try await withCheckedThrowingContinuation { continuation in
            repositories.assistantActions.updateRun(run) { continuation.resume(with: $0) }
        }
    }

    private func captureError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "EvaCaptureLaneUseCase", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

enum EvaCaptureLaneFactory {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: EvaCaptureLaneUseCase?

    static var lane: EvaCaptureLaneUseCase? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    static func configure(repositories: EvaCaptureRepositories) {
        lock.lock()
        storage = EvaCaptureLaneUseCase(repositories: repositories)
        lock.unlock()
    }
}

private final class AssistantActionCompletion<Value: Sendable>: @unchecked Sendable {
    private let completion: @Sendable (Result<Value, Error>) -> Void

    init(_ completion: @escaping @Sendable (Result<Value, Error>) -> Void) {
        self.completion = completion
    }

    func deliver(_ result: Result<Value, Error>) {
        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}

public final class AssistantActionPipelineUseCase: @unchecked Sendable {

    private struct TransactionResult: Sendable {
        let undoCommands: [AssistantCommand]
        let traceData: Data?
    }

    private struct TransactionFailure: Error {
        let underlying: Error
        let rollbackVerified: Bool
        let traceData: Data?
    }

    private let supportedSchemaVersion = 3
    private let minimumSupportedSchemaVersion = 1
    private let undoWindowSeconds: TimeInterval = 60 * 30
    private let commandTimeoutSeconds: TimeInterval = 10
    private let runTimeoutSeconds: TimeInterval = 90
    private let repository: AssistantActionRepositoryProtocol
    private let taskRepository: TaskDefinitionRepositoryProtocol
    private let commandExecutor: AssistantCommandExecutor

    /// Initializes a new instance.
    public init(
        repository: AssistantActionRepositoryProtocol,
        taskRepository: TaskDefinitionRepositoryProtocol,
        commandExecutor: AssistantCommandExecutor = AssistantCommandExecutor()
    ) {
        self.repository = repository
        self.taskRepository = taskRepository
        self.commandExecutor = commandExecutor
    }

    /// Executes propose.
    public func propose(threadID: String, envelope: AssistantCommandEnvelope, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard envelope.schemaVersion >= minimumSupportedSchemaVersion && envelope.schemaVersion <= supportedSchemaVersion else {
            completion(.failure(NSError(
                domain: "AssistantActionPipelineUseCase",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported assistant schema version \(envelope.schemaVersion)"]
            )))
            return
        }
        guard envelope.commands.isEmpty == false else {
            completion(.failure(NSError(
                domain: "AssistantActionPipelineUseCase",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Assistant proposal must include at least one command"]
            )))
            return
        }
        logWarning(
            event: "assistant_propose_started",
            message: "Assistant proposal received",
            fields: [
                "thread_id": threadID,
                "command_count": String(envelope.commands.count)
            ]
        )
        let payload = try? JSONEncoder().encode(envelope)
        let run = AssistantActionRunDefinition(
            id: UUID(),
            threadID: threadID,
            proposalData: payload,
            status: .pending,
            confirmedAt: nil,
            appliedAt: nil,
            rejectedAt: nil,
            resultSummary: nil,
            createdAt: Date()
        )
        repository.createRun(run, completion: completion)
    }

    /// Executes confirm.
    public func confirm(runID: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        repository.fetchRun(id: runID) { result in
            switch result {
            case .success(let run):
                guard var run else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                switch run.status {
                case .applied, .undone, .rejected, .failed:
                    completion(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Run is already \(run.status.rawValue)"]
                    )))
                    return
                default:
                    break
                }
                run.status = .confirmed
                run.confirmedAt = Date()
                logWarning(
                    event: "assistant_confirmed",
                    message: "Assistant action run confirmed",
                    fields: ["run_id": runID.uuidString]
                )
                self.repository.updateRun(run, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchRun.
    func fetchRun(id: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        repository.fetchRun(id: id, completion: completion)
    }

    /// Executes applyConfirmedRun.
    public func applyConfirmedRun(id: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        let callback = AssistantActionCompletion(completion)
        guard V2FeatureFlags.assistantApplyEnabled else {
            callback.deliver(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 403, userInfo: [NSLocalizedDescriptionKey: "Assistant apply disabled by feature flag"])))
            return
        }
        repository.fetchRun(id: id) { result in
            switch result {
            case .success(let run):
                guard let run else {
                    callback.deliver(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                guard run.status != .applied else {
                    callback.deliver(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 409, userInfo: [NSLocalizedDescriptionKey: "Run has already been applied"])))
                    return
                }
                guard run.status == .confirmed else {
                    callback.deliver(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 409, userInfo: [NSLocalizedDescriptionKey: "Run must be confirmed before apply"])))
                    return
                }
                let envelope = (run.proposalData).flatMap { try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: $0) }
                guard let envelope else {
                    callback.deliver(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid proposal payload"])))
                    return
                }
                guard envelope.schemaVersion >= self.minimumSupportedSchemaVersion && envelope.schemaVersion <= self.supportedSchemaVersion else {
                    callback.deliver(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "Unsupported assistant schema version \(envelope.schemaVersion)"]
                    )))
                    return
                }
                guard self.isAllowlisted(commands: envelope.commands) else {
                    callback.deliver(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "Proposal contains unsupported commands"]
                    )))
                    return
                }
                let originalRun = run

                self.executeTransaction(runID: id, commands: envelope.commands) { execResult in
                    switch execResult {
                    case .success(let transaction):
                        var persistedEnvelope = envelope
                        persistedEnvelope.schemaVersion = self.supportedSchemaVersion
                        guard self.validateUndoPlan(forward: envelope.commands, inverse: transaction.undoCommands) else {
                            callback.deliver(.failure(NSError(
                                domain: "AssistantActionPipelineUseCase",
                                code: 422,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to generate deterministic undo plan"]
                            )))
                            return
                        }
                        var appliedRun = originalRun
                        persistedEnvelope.undoCommands = transaction.undoCommands
                        appliedRun.status = .applied
                        appliedRun.appliedAt = Date()
                        appliedRun.proposalData = try? JSONEncoder().encode(persistedEnvelope)
                        appliedRun.resultSummary = "Applied \(envelope.commands.count) commands transactionally"
                        appliedRun.executionTraceData = transaction.traceData
                        appliedRun.rollbackStatus = .notNeeded
                        appliedRun.rollbackVerifiedAt = nil
                        appliedRun.lastErrorCode = nil
                        logWarning(
                            event: "assistant_apply_completed",
                            message: "Assistant action run applied",
                            fields: [
                                "run_id": id.uuidString,
                                "command_count": String(envelope.commands.count)
                            ]
                        )
                        self.repository.updateRun(appliedRun) { result in
                            callback.deliver(result)
                        }
                    case .failure(let error):
                        let transactionFailure = error as? TransactionFailure
                        var failedRun = originalRun
                        failedRun.status = .failed
                        failedRun.resultSummary = transactionFailure?.underlying.localizedDescription ?? error.localizedDescription
                        failedRun.executionTraceData = transactionFailure?.traceData
                        failedRun.rollbackStatus = (transactionFailure?.rollbackVerified == true) ? .verified : .failed
                        failedRun.rollbackVerifiedAt = Date()
                        failedRun.lastErrorCode = "assistant_apply_failed"
                        logError(
                            event: "assistant_apply_failed",
                            message: "Assistant action run apply failed",
                            fields: [
                                "run_id": id.uuidString,
                                "error": transactionFailure?.underlying.localizedDescription ?? error.localizedDescription
                            ]
                        )
                        self.repository.updateRun(failedRun) { _ in }
                        callback.deliver(.failure(transactionFailure?.underlying ?? error))
                    }
                }
            case .failure(let error):
                callback.deliver(.failure(error))
            }
        }
    }

    /// Executes reject.
    public func reject(runID: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        repository.fetchRun(id: runID) { result in
            switch result {
            case .success(let run):
                guard var run else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                run.status = .rejected
                run.rejectedAt = Date()
                run.resultSummary = "Rejected by user"
                logWarning(
                    event: "assistant_rejected",
                    message: "Assistant action run rejected",
                    fields: ["run_id": runID.uuidString]
                )
                self.repository.updateRun(run, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes undoAppliedRun.
    public func undoAppliedRun(id: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        let callback = AssistantActionCompletion(completion)
        guard V2FeatureFlags.assistantUndoEnabled else {
            callback.deliver(.failure(NSError(
                domain: "AssistantActionPipelineUseCase",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Assistant undo disabled by feature flag"]
            )))
            return
        }
        repository.fetchRun(id: id) { result in
            switch result {
            case .failure(let error):
                callback.deliver(.failure(error))
            case .success(let run):
                guard let run else {
                    callback.deliver(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                guard run.status == .applied else {
                    callback.deliver(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Only applied runs can be undone"]
                    )))
                    return
                }
                guard let appliedAt = run.appliedAt, Date().timeIntervalSince(appliedAt) <= self.undoWindowSeconds else {
                    callback.deliver(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 410,
                        userInfo: [NSLocalizedDescriptionKey: "Undo window expired"]
                    )))
                    return
                }
                guard
                    let payload = run.proposalData,
                    let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: payload),
                    let undoCommands = envelope.undoCommands,
                    undoCommands.isEmpty == false
                else {
                    callback.deliver(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "No compensating undo commands available"]
                    )))
                    return
                }
                let originalRun = run

                self.executeTransaction(runID: id, commands: undoCommands) { undoResult in
                    switch undoResult {
                    case .success:
                        var undoneRun = originalRun
                        undoneRun.status = .undone
                        undoneRun.resultSummary = "Undo applied (\(undoCommands.count) commands)"
                        undoneRun.rollbackStatus = .verified
                        undoneRun.rollbackVerifiedAt = Date()
                        undoneRun.lastErrorCode = nil
                        logWarning(
                            event: "assistant_undo_completed",
                            message: "Assistant action run undo completed",
                            fields: ["run_id": id.uuidString]
                        )
                        self.repository.updateRun(undoneRun) { result in
                            callback.deliver(result)
                        }
                    case .failure(let error):
                        logError(
                            event: "assistant_undo_failed",
                            message: "Assistant action run undo failed",
                            fields: [
                                "run_id": id.uuidString,
                                "error": error.localizedDescription
                            ]
                        )
                        callback.deliver(.failure(error))
                    }
                }
            }
        }
    }

    /// Executes executeTransaction.
    private func executeTransaction(
        runID: UUID,
        commands: [AssistantCommand],
        completion: @escaping @MainActor @Sendable (Result<TransactionResult, Error>) -> Void
    ) {
        _Concurrency.Task {
            let result = await self.executeTransactionResult(runID: runID, commands: commands)
            await MainActor.run {
                completion(result)
            }
        }
    }

    private func executeTransactionResult(
        runID: UUID,
        commands: [AssistantCommand]
    ) async -> Result<TransactionResult, Error> {
        do {
            let result = try await commandExecutor.enqueue {
                try await self.executeTransactionAsync(runID: runID, commands: commands)
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /// Executes executeTransactionAsync.
    private func executeTransactionAsync(
        runID: UUID,
        commands: [AssistantCommand]
    ) async throws -> TransactionResult {
        var trace = AssistantExecutionTrace(
            runID: runID,
            commandCount: commands.count,
            startedAt: Date(),
            finishedAt: nil,
            durationMillis: nil,
            status: "running",
            rollbackVerified: nil,
            failureReason: nil,
            createdReferences: []
        )
        let baselineTasks = try await fetchAllTasksAsync()
        let baselineMap = Dictionary(uniqueKeysWithValues: baselineTasks.map { ($0.id, $0) })
        var taskMap = baselineMap
        var inverses: [AssistantCommand] = []
        var touchedTaskIDs = Set<UUID>()

        do {
            for command in commands {
                try _Concurrency.Task.checkCancellation()
                if Date().timeIntervalSince(trace.startedAt) > runTimeoutSeconds {
                    throw runTimedOutError()
                }
                let inverse = try await apply(
                    command: command,
                    taskMap: &taskMap,
                    touchedTaskIDs: &touchedTaskIDs,
                    createdReferences: &trace.createdReferences
                )
                inverses.insert(inverse, at: 0)
            }
            trace.finishedAt = Date()
            trace.durationMillis = Int((trace.finishedAt?.timeIntervalSince(trace.startedAt) ?? 0) * 1_000)
            trace.status = "success"
            return TransactionResult(undoCommands: inverses, traceData: encodeTrace(trace))
        } catch {
            let rollbackVerified = await rollbackAndVerify(
                commands: inverses,
                baselineMap: baselineMap,
                touchedTaskIDs: touchedTaskIDs
            )
            trace.finishedAt = Date()
            trace.durationMillis = Int((trace.finishedAt?.timeIntervalSince(trace.startedAt) ?? 0) * 1_000)
            trace.status = "failed"
            trace.rollbackVerified = rollbackVerified
            trace.failureReason = error.localizedDescription
            throw TransactionFailure(
                underlying: error,
                rollbackVerified: rollbackVerified,
                traceData: encodeTrace(trace)
            )
        }
    }

    /// Executes runTimedOutError.
    private func runTimedOutError() -> NSError {
        NSError(
            domain: "AssistantActionPipelineUseCase",
            code: 408,
            userInfo: [NSLocalizedDescriptionKey: "Assistant run timed out"]
        )
    }

    /// Executes rollbackAndVerify.
    private func rollbackAndVerify(
        commands: [AssistantCommand],
        baselineMap: [UUID: TaskDefinition],
        touchedTaskIDs: Set<UUID>
    ) async -> Bool {
        do {
            let current = try await fetchAllTasksAsync()
            var taskMap = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
            var rollbackTouched = Set<UUID>()
            for command in commands {
                var ignoredReferences: [EvaRecordReference] = []
                _ = try await apply(
                    command: command,
                    taskMap: &taskMap,
                    touchedTaskIDs: &rollbackTouched,
                    createdReferences: &ignoredReferences
                )
            }
            let afterRollback = Dictionary(uniqueKeysWithValues: (try await fetchAllTasksAsync()).map { ($0.id, $0) })
            return touchedTaskIDs.allSatisfy { taskID in
                let baseline = baselineMap[taskID]
                let candidate = afterRollback[taskID]
                switch (baseline, candidate) {
                case (nil, nil):
                    return true
                case let (lhs?, rhs?):
                    return tasksEquivalent(lhs, rhs)
                default:
                    return false
                }
            }
        } catch {
            return false
        }
    }

    /// Executes tasksEquivalent.
    private func tasksEquivalent(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        AssistantTaskSnapshot(task: lhs) == AssistantTaskSnapshot(task: rhs)
    }

    /// Executes apply.
    private func apply(
        command: AssistantCommand,
        taskMap: inout [UUID: TaskDefinition],
        touchedTaskIDs: inout Set<UUID>,
        createdReferences: inout [EvaRecordReference]
    ) async throws -> AssistantCommand {
        switch command {
        case .createTask(let projectID, let title):
            let task = TaskDefinition(
                projectID: projectID,
                projectName: ProjectConstants.inboxProjectName,
                title: title,
                dueDate: nil
            )
            let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.createTaskAsync(task)
            }
            taskMap[createdTask.id] = createdTask
            touchedTaskIDs.insert(createdTask.id)
            createdReferences.append(.init(kind: .task, recordID: createdTask.id, title: createdTask.title, occurredAt: createdTask.dateAdded))
            return .deleteTask(taskID: createdTask.id)

        case let .restoreTask(taskID, projectID, title, dueDate, isComplete, dateCompleted):
            let snapshot = AssistantTaskSnapshot(task: TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: ProjectConstants.inboxProjectName,
                title: title,
                dueDate: dueDate,
                isComplete: isComplete,
                dateAdded: Date(),
                dateCompleted: dateCompleted
            ))
            return try await apply(
                command: .restoreTaskSnapshot(snapshot: snapshot),
                taskMap: &taskMap,
                touchedTaskIDs: &touchedTaskIDs,
                createdReferences: &createdReferences
            )

        case .restoreTaskSnapshot(let snapshot):
            let task = snapshot.toTaskDefinition()
            if taskMap[task.id] == nil {
                let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                    try await self.createTaskAsync(task)
                }
                taskMap[task.id] = createdTask
                touchedTaskIDs.insert(task.id)
                return .deleteTask(taskID: task.id)
            }

            let previous = taskMap[task.id]
            let updatedTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[task.id] = updatedTask
            touchedTaskIDs.insert(task.id)
            if let previous {
                return .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: previous))
            }
            return .deleteTask(taskID: task.id)

        case .deleteTask(let taskID):
            let previous = taskMap[taskID]
            guard let previous else {
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Delete command is not invertible without pre-state for task \(taskID)"]
                )
            }
            try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.deleteTaskAsync(id: taskID)
            }
            taskMap.removeValue(forKey: taskID)
            touchedTaskIDs.insert(taskID)
            return .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: previous))

        case .updateTask(let taskID, let title, let dueDate):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            if let title {
                task.title = title
            }
            if let dueDate {
                if TaskScheduleNormalizer.isDateOnly(dueDate) {
                    task.dueDate = Calendar.current.startOfDay(for: dueDate)
                    task.scheduledStartAt = nil
                    task.scheduledEndAt = nil
                    task.isAllDay = true
                } else {
                    task.dueDate = dueDate
                    task.isAllDay = false
                }
            }
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .setTaskCompletion(let taskID, let isComplete, let dateCompleted):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.isComplete = isComplete
            task.dateCompleted = dateCompleted
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .completeTask(let taskID):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.isComplete = true
            task.dateCompleted = Date()
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .moveTask(let taskID, let targetProjectID):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.projectID = targetProjectID
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .createScheduledTask(
            let projectID,
            let title,
            let scheduledStartAt,
            let scheduledEndAt,
            let estimatedDuration,
            let lifeAreaID,
            let priority,
            let energy,
            let category,
            let context,
            let details,
            let tagIDs
        ):
            guard scheduledEndAt > scheduledStartAt else {
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Scheduled task end must be after start"]
                )
            }
            let duration = estimatedDuration ?? scheduledEndAt.timeIntervalSince(scheduledStartAt)
            let task = TaskDefinition(
                projectID: projectID,
                projectName: projectID == ProjectConstants.inboxProjectID ? ProjectConstants.inboxProjectName : nil,
                lifeAreaID: lifeAreaID,
                title: title,
                details: details,
                priority: priority ?? .low,
                energy: energy ?? .medium,
                category: category ?? .general,
                context: context ?? .anywhere,
                dueDate: scheduledStartAt,
                scheduledStartAt: scheduledStartAt,
                scheduledEndAt: scheduledEndAt,
                tagIDs: tagIDs,
                estimatedDuration: duration,
                planningBucket: .thisWeek
            )
            let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.createTaskAsync(task)
            }
            taskMap[createdTask.id] = createdTask
            touchedTaskIDs.insert(createdTask.id)
            createdReferences.append(.init(kind: .task, recordID: createdTask.id, title: createdTask.title, occurredAt: createdTask.dateAdded))
            return .deleteTask(taskID: createdTask.id)

        case .createInboxTask(
            let projectID,
            let title,
            let estimatedDuration,
            let lifeAreaID,
            let priority,
            let category,
            let details,
            let tagIDs
        ):
            let task = TaskDefinition(
                projectID: projectID,
                projectName: projectID == ProjectConstants.inboxProjectID ? ProjectConstants.inboxProjectName : nil,
                lifeAreaID: lifeAreaID,
                title: title,
                details: details,
                priority: priority ?? .low,
                category: category ?? .general,
                dueDate: nil,
                tagIDs: tagIDs,
                estimatedDuration: estimatedDuration,
                planningBucket: .thisWeek
            )
            let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.createTaskAsync(task)
            }
            taskMap[createdTask.id] = createdTask
            touchedTaskIDs.insert(createdTask.id)
            createdReferences.append(.init(kind: .task, recordID: createdTask.id, title: createdTask.title, occurredAt: createdTask.dateAdded))
            return .deleteTask(taskID: createdTask.id)

        case .updateTaskSchedule(let taskID, let scheduledStartAt, let scheduledEndAt, let estimatedDuration, let dueDate):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let effectiveStart = scheduledStartAt ?? task.scheduledStartAt
            let effectiveEnd = scheduledEndAt ?? task.scheduledEndAt
            if let effectiveStart, let effectiveEnd, effectiveEnd <= effectiveStart {
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Scheduled task end must be after start"]
                )
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.scheduledStartAt = effectiveStart
            task.scheduledEndAt = effectiveEnd
            task.estimatedDuration = estimatedDuration ?? effectiveEnd.flatMap { end in
                effectiveStart.map { end.timeIntervalSince($0) }
            } ?? task.estimatedDuration
            task.dueDate = dueDate ?? effectiveStart ?? task.dueDate
            task.isAllDay = false
            task.replanCount = max(0, task.replanCount) + 1
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .updateTaskFields(
            let taskID,
            let title,
            let details,
            let priority,
            let energy,
            let category,
            let context,
            let lifeAreaID,
            let tagIDs
        ):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            if case .set(let title) = title { task.title = title }
            switch details {
            case .set(let details): task.details = details
            case .clear: task.details = nil
            case .absent: break
            }
            if case .set(let priority) = priority { task.priority = priority }
            if case .set(let energy) = energy { task.energy = energy }
            if case .set(let category) = category { task.category = category }
            if case .set(let context) = context { task.context = context }
            switch lifeAreaID {
            case .set(let lifeAreaID): task.lifeAreaID = lifeAreaID
            case .clear: task.lifeAreaID = nil
            case .absent: break
            }
            switch tagIDs {
            case .set(let tagIDs): task.tagIDs = tagIDs
            case .clear: task.tagIDs = []
            case .absent: break
            }
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .deferTask(let taskID, let targetDate, _):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.dueDate = targetDate
            task.scheduledStartAt = nil
            task.scheduledEndAt = nil
            task.isAllDay = true
            task.deferredCount = max(0, task.deferredCount) + 1
            task.replanCount = max(0, task.replanCount) + 1
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .dropTaskFromToday(let taskID, let destination, _):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.dueDate = nil
            task.scheduledStartAt = nil
            task.scheduledEndAt = nil
            task.isAllDay = false
            switch destination {
            case .inbox:
                task.projectID = ProjectConstants.inboxProjectID
                task.projectName = ProjectConstants.inboxProjectName
            case .later:
                task.planningBucket = .later
            case .someday:
                task.planningBucket = .someday
            }
            task.deferredCount = max(0, task.deferredCount) + 1
            task.replanCount = max(0, task.replanCount) + 1
            task.updatedAt = Date()
            let taskForUpdate = task
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(taskForUpdate)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse
        }
    }

    /// Executes validateUndoPlan.
    private func validateUndoPlan(forward: [AssistantCommand], inverse: [AssistantCommand]) -> Bool {
        guard inverse.isEmpty == false, inverse.count == forward.count else {
            return false
        }
        return isAllowlisted(commands: inverse)
    }

    /// Executes encodeTrace.
    private func encodeTrace(_ trace: AssistantExecutionTrace) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(trace)
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 408,
                    userInfo: [NSLocalizedDescriptionKey: "Assistant command timed out"]
                )
            }
            let first = try await group.next()
            group.cancelAll()
            guard let first else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 500)
            }
            return first
        }
    }

    /// Executes fetchAllTasksAsync.
    private func fetchAllTasksAsync() async throws -> [TaskDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes createTaskAsync.
    private func createTaskAsync(_ task: TaskDefinition) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.create(task) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes updateTaskAsync.
    private func updateTaskAsync(_ task: TaskDefinition) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.update(task) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes deleteTaskAsync.
    private func deleteTaskAsync(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.delete(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes isAllowlisted.
    private func isAllowlisted(commands: [AssistantCommand]) -> Bool {
        for command in commands {
            switch command {
            case .createTask,
                 .restoreTask,
                 .restoreTaskSnapshot,
                 .deleteTask,
                 .updateTask,
                 .setTaskCompletion,
                 .completeTask,
                 .moveTask,
                 .createScheduledTask,
                 .createInboxTask,
                 .updateTaskSchedule,
                 .updateTaskFields,
                 .deferTask,
                 .dropTaskFromToday:
                continue
            }
        }
        return true
    }

}
