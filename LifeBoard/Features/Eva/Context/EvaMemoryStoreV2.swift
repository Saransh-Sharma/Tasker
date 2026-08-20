import Foundation
import MLXLMCommon

/// What EVA is allowed to remember about someone between conversations.
///
/// The v1 store held twelve strings of 120 characters, written once during
/// onboarding and never revised — which is why EVA re-learned the same
/// preferences every session and could not tell a stated preference from its own
/// guess.
///
/// The shape here follows the Personal Operating Manual in the product roadmap:
/// versioned statements, each carrying where it came from. The provenance field
/// is the load-bearing part. An inference must never become indistinguishable
/// from something the person actually said, because the moment it does, a wrong
/// guess becomes a permanent fact about them that they never agreed to and
/// cannot find to correct.
struct EvaMemoryStatement: Codable, Equatable, Identifiable, Sendable {
    enum Section: String, Codable, CaseIterable, Hashable, Sendable {
        case preferences
        case routines
        case currentGoals
        case capacity
        case boundaries
    }

    enum Provenance: String, Codable, Sendable {
        /// The person wrote or explicitly confirmed this.
        case userStated
        /// EVA derived this from repeated evidence. Always revisable, never
        /// promoted to `userStated` without an explicit confirmation.
        case inferred
        /// A machine-derived statement the person explicitly confirmed.
        case inferredCandidate
    }

    let id: UUID
    var section: Section
    var text: String
    var provenance: Provenance
    /// Only meaningful for an inference; a stated preference is not a guess.
    var confidence: Double?
    var effectiveFrom: Date
    var revision: Int

    init(
        id: UUID = UUID(),
        section: Section,
        text: String,
        provenance: Provenance,
        confidence: Double? = nil,
        effectiveFrom: Date = Date(),
        revision: Int = 1
    ) {
        self.id = id
        self.section = section
        self.text = text
        self.provenance = provenance
        self.confidence = confidence
        self.effectiveFrom = effectiveFrom
        self.revision = revision
        normalize()
    }

    /// Enforces the one invariant the type exists to hold: only an inference
    /// carries a confidence.
    ///
    /// This cannot live in `init` alone. The fields are `var`, so a caller that
    /// promotes an inference by assigning `provenance = .userStated` would leave
    /// the old confidence behind — and a stated preference reported as "0.6
    /// confident" is exactly the confusion between evidence and inference this
    /// design is meant to prevent.
    mutating func normalize() {
        text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(EvaMemoryStoreV2.maxStatementCharacters))
        if provenance == .userStated { confidence = nil }
    }

    func normalized() -> EvaMemoryStatement {
        var copy = self
        copy.normalize()
        return copy
    }
}

extension EvaMemoryStatement.Section {
    var displayTitle: String {
        switch self {
        case .preferences: String(localized: "Preferences")
        case .routines: String(localized: "Routines")
        case .currentGoals: String(localized: "Current goals")
        case .capacity: String(localized: "Capacity")
        case .boundaries: String(localized: "Boundaries")
        }
    }

    var supportingCopy: String {
        switch self {
        case .preferences: String(localized: "How you prefer EVA to help.")
        case .routines: String(localized: "Patterns and routines worth carrying forward.")
        case .currentGoals: String(localized: "Goals that should shape current suggestions.")
        case .capacity: String(localized: "Stable limits on time, energy, or workload.")
        case .boundaries: String(localized: "Things EVA should protect or avoid suggesting.")
        }
    }
}

struct EvaMemoryStoreV2: Codable, Equatable, Sendable {
    static let schemaVersion = 2
    static let maxStatementCharacters = 400
    static let maxStatements = 60

    var schemaVersion: Int
    var statements: [EvaMemoryStatement]

    init(schemaVersion: Int = EvaMemoryStoreV2.schemaVersion, statements: [EvaMemoryStatement] = []) {
        self.schemaVersion = schemaVersion
        self.statements = Array(statements.prefix(Self.maxStatements))
    }

    var isEmpty: Bool { statements.isEmpty }

    func statements(in section: EvaMemoryStatement.Section) -> [EvaMemoryStatement] {
        statements.filter { $0.section == section }
    }

    /// Records a revision without losing what it replaced being a *statement*.
    ///
    /// An inference may never overwrite something the person stated: if it could,
    /// a confident wrong guess would silently erase a real preference. The
    /// reverse is allowed and expected — the person correcting EVA is exactly how
    /// an inference should end.
    mutating func upsert(_ statement: EvaMemoryStatement) {
        let incoming = statement.normalized()
        if let index = statements.firstIndex(where: { $0.id == incoming.id }) {
            let existing = statements[index]
            guard !(existing.provenance == .userStated && incoming.provenance == .inferred) else { return }
            var revised = incoming
            revised.revision = existing.revision + 1
            statements[index] = revised
            return
        }
        guard statements.count < Self.maxStatements else { return }
        statements.append(incoming)
    }

    mutating func remove(id: UUID) {
        statements.removeAll { $0.id == id }
    }

    /// The wire form. Mirrors `EvaPersonalMemoryContextSchema`.
    func contextPayload() -> [EvaMemoryStatementPayload] {
        statements.map {
            EvaMemoryStatementPayload(
                id: $0.id,
                section: $0.section.rawValue,
                text: $0.text,
                provenance: $0.provenance.rawValue,
                confidence: $0.confidence,
                effectiveFrom: $0.effectiveFrom
            )
        }
    }

    /// Seeds from what onboarding already learned.
    ///
    /// Everything captured in the Life Map is something the person chose on
    /// screen, so it lands as `userStated`. The v1 mapper flattened all of it
    /// into free text and lost the distinction.
    static func seeded(
        workingStyle: [String],
        momentumBlockers: [String],
        goals: [String],
        capacityNotes: [String] = [],
        now: Date = Date()
    ) -> EvaMemoryStoreV2 {
        var store = EvaMemoryStoreV2()
        func add(_ texts: [String], _ section: EvaMemoryStatement.Section) {
            for text in texts where text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                store.upsert(EvaMemoryStatement(
                    section: section, text: text, provenance: .userStated, effectiveFrom: now
                ))
            }
        }
        add(workingStyle, .preferences)
        add(momentumBlockers, .routines)
        add(goals, .currentGoals)
        add(capacityNotes, .capacity)
        return store
    }

    /// Migrates the v1 store without inventing provenance it cannot know.
    ///
    /// v1 entries came from onboarding answers, so `userStated` is the honest
    /// reading; nothing in v1 was ever machine-derived.
    static func migrating(from v1: LLMPersonalMemoryStoreV1, now: Date = Date()) -> EvaMemoryStoreV2 {
        seeded(
            workingStyle: v1.preferences.map(\.text),
            momentumBlockers: v1.routines.map(\.text),
            goals: v1.currentGoals.map(\.text),
            now: now
        )
    }
}

struct EvaMemoryStatementPayload: Encodable, Sendable {
    let id: UUID
    let section: String
    let text: String
    let provenance: String
    let confidence: Double?
    let effectiveFrom: Date
}

/// User-owned memory used by current EVA turns.
struct EvaMemoryStoreV3: Codable, Equatable, Sendable {
    static let schemaVersion = 3
    static let maxStatementCharacters = 240
    static let maxStatements = 30

    var schemaVersion = Self.schemaVersion
    var statements: [EvaMemoryStatement] = []

    init(statements: [EvaMemoryStatement] = []) {
        self.statements = Self.normalized(statements)
    }

    var isEmpty: Bool { statements.isEmpty }

    func statements(in section: EvaMemoryStatement.Section) -> [EvaMemoryStatement] {
        statements.filter { $0.section == section }
    }

    mutating func upsert(_ statement: EvaMemoryStatement) {
        var incoming = statement
        incoming.text = Self.normalizedText(incoming.text)
        guard incoming.text.isEmpty == false else { return }
        if incoming.provenance == .inferred { incoming.provenance = .inferredCandidate }
        incoming.normalize()
        if let index = statements.firstIndex(where: { $0.id == incoming.id }) {
            incoming.revision = statements[index].revision + 1
            statements[index] = incoming
        } else if let index = statements.firstIndex(where: {
            Self.deduplicationKey($0.text) == Self.deduplicationKey(incoming.text)
        }) {
            guard statements[index].provenance != .userStated || incoming.provenance == .userStated else { return }
            incoming.revision = statements[index].revision + 1
            statements[index] = incoming
        } else {
            guard statements.count < Self.maxStatements else { return }
            statements.append(incoming)
        }
        statements = Self.normalized(statements)
    }

    mutating func remove(id: UUID) {
        statements.removeAll { $0.id == id }
    }

    func contextPayload() -> [EvaMemoryStatementPayload] {
        statements.map {
            EvaMemoryStatementPayload(
                id: $0.id,
                section: $0.section.rawValue,
                text: $0.text,
                provenance: $0.provenance == .userStated ? "userStated" : "inferredCandidate",
                confidence: $0.confidence,
                effectiveFrom: $0.effectiveFrom
            )
        }
    }

    static func migrating(from store: EvaMemoryStoreV2) -> EvaMemoryStoreV3 {
        EvaMemoryStoreV3(statements: store.statements.map { statement in
            var migrated = statement
            if migrated.provenance == .inferred { migrated.provenance = .inferredCandidate }
            return migrated
        })
    }

    static func migrating(from store: LLMPersonalMemoryStoreV1, now: Date = Date()) -> EvaMemoryStoreV3 {
        var statements: [EvaMemoryStatement] = []
        func append(_ entries: [LLMPersonalMemoryEntry], section: EvaMemoryStatement.Section) {
            statements += entries.map {
                EvaMemoryStatement(
                    id: $0.id,
                    section: section,
                    text: $0.text,
                    provenance: .userStated,
                    effectiveFrom: now
                )
            }
        }
        append(store.preferences, section: .preferences)
        append(store.routines, section: .routines)
        append(store.currentGoals, section: .currentGoals)
        return EvaMemoryStoreV3(statements: statements)
    }

    private static func normalized(_ statements: [EvaMemoryStatement]) -> [EvaMemoryStatement] {
        var seen = Set<String>()
        let ordered = statements.sorted {
            if $0.provenance == .userStated && $1.provenance != .userStated { return true }
            if $0.provenance != .userStated && $1.provenance == .userStated { return false }
            return $0.effectiveFrom > $1.effectiveFrom
        }
        return ordered.compactMap { statement in
            var copy = statement
            copy.text = normalizedText(copy.text)
            guard copy.text.isEmpty == false,
                  seen.insert(deduplicationKey(copy.text)).inserted else { return nil }
            if copy.provenance == .inferred { copy.provenance = .inferredCandidate }
            copy.normalize()
            return copy
        }.prefix(Self.maxStatements).map { $0 }
    }

    private static func normalizedText(_ text: String) -> String {
        String(text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(maxStatementCharacters))
    }

    private static func deduplicationKey(_ text: String) -> String {
        normalizedText(text).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct EvaMemoryCandidate: Codable, Equatable, Identifiable, Sendable {
    enum State: String, Codable, Sendable { case inline, later }

    let id: UUID
    var section: EvaMemoryStatement.Section
    var text: String
    let createdAt: Date
    var state: State

    init(
        id: UUID = UUID(),
        section: EvaMemoryStatement.Section,
        text: String,
        createdAt: Date = Date(),
        state: State = .inline
    ) {
        self.id = id
        self.section = section
        self.text = String(text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(EvaMemoryStoreV3.maxStatementCharacters))
        self.createdAt = createdAt
        self.state = state
    }

    var expiresAt: Date { createdAt.addingTimeInterval(30 * 24 * 60 * 60) }
    var suppressionKey: String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
}

struct EvaMemoryCandidateInbox: Codable, Equatable, Sendable {
    var pending: [EvaMemoryCandidate] = []
    var suppressedKeys: Set<String> = []

    mutating func propose(_ candidate: EvaMemoryCandidate, now: Date = Date()) {
        removeExpired(now: now)
        guard candidate.text.isEmpty == false,
              candidate.expiresAt > now,
              suppressedKeys.contains(candidate.suppressionKey) == false,
              pending.contains(where: { $0.suppressionKey == candidate.suppressionKey }) == false else { return }
        pending.append(candidate)
    }

    mutating func deferCandidate(id: UUID) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[index].state = .later
    }

    mutating func dismiss(id: UUID) {
        guard let candidate = pending.first(where: { $0.id == id }) else { return }
        suppressedKeys.insert(candidate.suppressionKey)
        pending.removeAll { $0.id == id }
    }

    mutating func removeExpired(now: Date = Date()) {
        pending.removeAll { $0.expiresAt <= now }
    }
}

enum EvaMemoryDefaultsStoreV3 {
    static let key = "eva.personalMemory.v3"
    private static var secureStore: LLMSecureBlobStore {
        LLMSecureBlobStore(
            service: (Bundle.main.bundleIdentifier ?? "LifeBoard") + ".secureStorage",
            account: key
        )
    }

    static func load(defaults: UserDefaults = .standard) -> EvaMemoryStoreV3 {
        if let data = secureStore.loadData() {
            if let current = try? JSONDecoder().decode(EvaMemoryStoreV3.self, from: data) {
                return EvaMemoryStoreV3(statements: current.statements)
            }
            if let legacy = try? JSONDecoder().decode(EvaMemoryStoreV2.self, from: data) {
                let migrated = EvaMemoryStoreV3.migrating(from: legacy)
                save(migrated, defaults: defaults)
                return migrated
            }
        }
        let migrated = EvaMemoryStoreV3.migrating(
            from: LLMPersonalMemoryDefaultsStore.load(defaults: defaults)
        )
        if migrated.isEmpty == false { save(migrated, defaults: defaults) }
        return migrated
    }

    static func save(_ store: EvaMemoryStoreV3, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(EvaMemoryStoreV3(statements: store.statements)),
              secureStore.saveData(data) else { return }
        defaults.removeObject(forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        secureStore.clear()
        defaults.removeObject(forKey: key)
    }

    static func promptBlock(for model: MLXLMCommon.ModelConfiguration) -> String? {
        let store = load()
        guard store.isEmpty == false else { return nil }
        var lines = ["User-confirmed memory:"]
        for section in EvaMemoryStatement.Section.allCases {
            let values = store.statements(in: section).map(\.text).joined(separator: "; ")
            if values.isEmpty == false { lines.append("\(section.rawValue): \(values)") }
        }
        return LLMTokenBudgetEstimator.trimPrefix(
            lines.joined(separator: "\n"),
            toTokenBudget: model.tokenBudget.personalMemoryTokens
        )
    }
}

enum EvaMemoryCandidateDefaultsStore {
    static let key = "eva.memoryCandidates.v1"
    private static var secureStore: LLMSecureBlobStore {
        LLMSecureBlobStore(
            service: (Bundle.main.bundleIdentifier ?? "LifeBoard") + ".secureStorage",
            account: key
        )
    }

    static func load() -> EvaMemoryCandidateInbox {
        guard let data = secureStore.loadData(),
              var inbox = try? JSONDecoder().decode(EvaMemoryCandidateInbox.self, from: data) else {
            return EvaMemoryCandidateInbox()
        }
        inbox.removeExpired()
        return inbox
    }

    static func save(_ inbox: EvaMemoryCandidateInbox) {
        guard let data = try? JSONEncoder().encode(inbox) else { return }
        _ = secureStore.saveData(data)
    }
}
