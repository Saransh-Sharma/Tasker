import Foundation

/// The single place a context section payload is constructed.
///
/// This exists because of a defect worth naming: `contractVersion` is a build
/// constant, but the payload shape was being decided per turn — rich when the
/// projection succeeded, legacy when it fell back, and a third shape again in the
/// route and journal helpers. The server validates every section against its
/// category schema for a v2 request, so any turn that took a fallback path sent
/// v1 shapes under a v2 version and was rejected with HTTP 400 before reaching
/// the model.
///
/// The fix is to have exactly one shape. A degraded projection produces the same
/// planning object with an empty `tasks` array and the rendered text in
/// `renderedOverview`, rather than a differently-shaped object. Nothing that
/// builds a section may bypass this factory.
enum EvaContextSectionFactory {
    /// A planning section, rich or degraded.
    static func planning(
        renderedOverview: String? = nil,
        executiveState: String? = nil,
        slashCommandState: String? = nil,
        kind: String? = nil,
        summary: EvaPlanningSummary = .empty,
        tasks: [EvaTaskRecord] = [],
        projects: [EvaProjectRecord] = [],
        lifeAreas: [EvaLifeAreaRecord] = [],
        partialSections: [String] = [],
        now: Date = Date()
    ) -> EvaCloudContextSection {
        .init(category: .planning, payload: .encoding(EvaPlanningSectionPayload(
            generatedAt: now,
            summary: summary,
            tasks: tasks,
            projects: projects,
            lifeAreas: lifeAreas,
            partialSections: partialSections,
            renderedOverview: nonEmpty(renderedOverview),
            executiveState: nonEmpty(executiveState),
            slashCommandState: nonEmpty(slashCommandState),
            kind: nonEmpty(kind)
        )))
    }

    /// Personal memory as versioned statements.
    ///
    /// The legacy path holds one rendered block rather than statements. It is
    /// carried as a single `userStated` entry rather than as a bare string:
    /// everything in it came from onboarding answers, so that is the honest
    /// provenance, and it keeps one shape on the wire.
    static func personalMemory(legacyBlock: String, now: Date = Date()) -> EvaCloudContextSection? {
        guard let text = nonEmpty(legacyBlock) else { return nil }
        return personalMemory(statements: [
            EvaMemoryStatementPayload(
                id: Self.legacyBlockIdentifier,
                section: EvaMemoryStatement.Section.preferences.rawValue,
                text: String(text.prefix(EvaMemoryStoreV2.maxStatementCharacters)),
                provenance: EvaMemoryStatement.Provenance.userStated.rawValue,
                confidence: nil,
                effectiveFrom: now
            ),
        ])
    }

    static func personalMemory(statements: [EvaMemoryStatementPayload]) -> EvaCloudContextSection? {
        guard statements.isEmpty == false else { return nil }
        return .init(category: .personalMemory, payload: .encoding(statements))
    }

    /// Evidence events for a grant-gated category.
    static func evidence(
        category: EvaCloudContextSection.Category,
        events: [EvaEvidenceEventPayload]
    ) -> EvaCloudContextSection? {
        guard events.isEmpty == false else { return nil }
        return .init(category: category, payload: .encoding(events))
    }

    /// Stable so a rendered block does not look like a different statement each
    /// turn, which would defeat prompt caching and read as churn.
    private static let legacyBlockIdentifier = UUID(uuidString: "5E9A0000-0000-4000-8000-000000000001")!

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Mirrors `EvaEvidenceContextSchema`.
struct EvaEvidenceEventPayload: Encodable, Sendable {
    let reference: String
    let domain: String
    let kind: String
    let occurredAt: Date
    let freshness: String
    let source: String?
    let value: Double?
}

/// Mirrors `EvaPlanningContextSchema`.
struct EvaPlanningSectionPayload: Encodable, Sendable {
    let generatedAt: Date
    let summary: EvaPlanningSummary
    let tasks: [EvaTaskRecord]
    let projects: [EvaProjectRecord]
    let lifeAreas: [EvaLifeAreaRecord]
    let partialSections: [String]
    let renderedOverview: String?
    let executiveState: String?
    let slashCommandState: String?
    let kind: String?
}

extension EvaPlanningSummary {
    /// Absent counts, not zero counts. The degraded path knows nothing about the
    /// roster and must not imply an empty one.
    static let empty = EvaPlanningSummary(
        overdue: 0, today: 0, tomorrow: 0, thisWeek: 0, unscheduled: 0, completedToday: 0
    )
}
