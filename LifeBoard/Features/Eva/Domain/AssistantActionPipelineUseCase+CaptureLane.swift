import Foundation
import LifeBoardDomain

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
        guard commands.isEmpty == false else { return String(localized: "Nothing to save.") }
        guard commands.count <= 3 else { return String(localized: "Up to 3 at once. Review these first.") }
        guard Set(commands.map(\.family)).count == 1 else { return String(localized: "Mixed types. Review before saving.") }
        guard commands.allSatisfy({ calendar.isDate($0.effectiveDate, inSameDayAs: now) }) else {
            return String(localized: "Earlier dates need review first.")
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
        guard segments.isEmpty == false else { return .review(String(localized: "What should I save?")) }
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
            return String(localized: "Log doses in Medication.")
        }
        if value.contains("fasting") {
            return String(localized: "Use Fasting to change the timer.")
        }
        if value.contains("calories") || value.contains("meal") {
            return String(localized: "Log meals in Nutrition.")
        }
        return String(localized: "Check the type or value, then try again.")
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
        guard var run = try await fetchRun(runID) else { throw captureError(404, String(localized: "Couldn’t find that entry.")) }
        guard run.status == .applied else { throw captureError(409, String(localized: "Already handled.")) }
        guard let appliedAt = run.appliedAt, now.timeIntervalSince(appliedAt) <= undoWindow else {
            throw captureError(410, String(localized: "Undo expired."))
        }
        guard let data = run.proposalData,
              let receipt = try? JSONDecoder().decode(EvaCaptureReceipt.self, from: data) else {
            throw captureError(422, String(localized: "Couldn’t undo this."))
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
                    let priorWeight = prior.normalizedValue.formatted(.number.precision(.fractionLength(0...1)))
                    return String(localized: "You logged \(priorWeight) kg at \(time). Add another or replace it?")
                }
            }
            if case .logHydration(let value) = command, !(1...5_000).contains(value.amount) {
                return String(localized: "Water must be 1–5000 ml. Check the amount.")
            }
        }
        return nil
    }

    private func execute(_ command: EvaCaptureCommand, now: Date) async throws -> (undo: EvaCaptureUndo, reference: EvaRecordReference) {
        switch command {
        case .logBodyMetric(let sample):
            try await repositories.wellness.save(sample)
            let weight = sample.normalizedValue.formatted(.number.precision(.fractionLength(0...1)))
            return (.deleteWellnessRecord(kind: .bodyMetric, id: sample.id), .init(
                kind: .bodyMetric, recordID: sample.id,
                title: String(localized: "Weight \(weight) kg"),
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
            return (.restoreJournalDay(previous: prior, createdID: day.id), .init(kind: .journal, recordID: day.id, title: String(localized: "Journal · \(day.day.formatted(date: .abbreviated, time: .omitted))"), occurredAt: capturedAt))
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
            return (.deleteHydration(value.id), .init(kind: .hydration, recordID: value.id, title: String(localized: "Water"), subtitle: String(localized: "\(value.amount.formatted()) ml"), occurredAt: value.timestamp))
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
        if references.count == 1, let first = references.first { return String(localized: "Saved \(first.title)") }
        return String(localized: "Saved \(references.count) entries")
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
