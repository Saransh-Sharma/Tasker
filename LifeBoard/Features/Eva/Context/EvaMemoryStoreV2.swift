import Foundation

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
    enum Section: String, Codable, CaseIterable, Sendable {
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
        if provenance != .inferred { confidence = nil }
    }

    func normalized() -> EvaMemoryStatement {
        var copy = self
        copy.normalize()
        return copy
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
