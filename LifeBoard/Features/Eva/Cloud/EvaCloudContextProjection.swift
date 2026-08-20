import Foundation

/// Builds the consent-gated context sections for a cloud request.
///
/// Every payload here goes through `EvaContextSectionFactory`, so the shapes on
/// the wire are identical whether the rich projection succeeded or the turn fell
/// back to the rendered summary. They used to differ, which meant a fallback turn
/// sent v1 shapes under `contractVersion: 2` and the Worker rejected the whole
/// request with HTTP 400 before it reached the model.
enum EvaCloudContextProjection {
    static func sections(
        taskProjection: String,
        executiveState: String?,
        slashCommandState: String?,
        personalMemory: String?,
        evidence: EvaAuthorizedEvidenceContext,
        consent: EvaConsentPolicy?
    ) -> [EvaCloudContextSection] {
        var sections: [EvaCloudContextSection] = [
            EvaContextSectionFactory.planning(
                renderedOverview: taskProjection,
                executiveState: executiveState,
                slashCommandState: slashCommandState
            ),
        ]
        guard let consent else { return sections }
        if let personalMemory,
           consent.grants.contains(.personalMemory),
           let section = EvaContextSectionFactory.personalMemory(legacyBlock: personalMemory) {
            sections.append(section)
        }
        sections.append(contentsOf: sensitiveSections(evidence: evidence, consent: consent))
        return sections
    }

    private static func sensitiveSections(
        evidence: EvaAuthorizedEvidenceContext,
        consent: EvaConsentPolicy
    ) -> [EvaCloudContextSection] {
        guard evidence.availability == .ready else { return [] }
        let grants = Set(consent.grants)
        var values: [EvaCloudContextSection.Category: [EvaEvidenceEventPayload]] = [:]
        for event in evidence.events.prefix(24)
        where event.authorization == .authorized && event.allowedDestinations.contains(.eva) {
            guard let category = category(for: event.domain, grants: grants) else { continue }
            let isRedacted = event.redaction == .sensitiveSummary
            let display = event.evidence.first?.display
            values[category, default: []].append(EvaEvidenceEventPayload(
                reference: "LB-\(event.sourceID.uuidString.prefix(8).uppercased())",
                domain: event.domain,
                kind: event.kind,
                occurredAt: event.occurredAt,
                freshness: event.freshness.rawValue,
                source: isRedacted ? nil : (display?.isEmpty == false ? display : nil),
                value: isRedacted ? nil : event.numericValue
            ))
        }
        return [EvaCloudContextSection.Category.journal, .health, .lifeMoments].compactMap { category in
            guard let events = values[category] else { return nil }
            return EvaContextSectionFactory.evidence(category: category, events: events)
        }
    }

    private static func category(
        for domain: String,
        grants: Set<EvaConsentPolicy.Grant>
    ) -> EvaCloudContextSection.Category? {
        switch domain.lowercased() {
        case "journal": grants.contains(.journal) ? .journal : nil
        case "mood", "medication", "care", "hydration", "body", "workout", "sleep", "movement":
            grants.contains(.health) ? .health : nil
        case "lifemoment", "life_moment", "moment", "countdown":
            grants.contains(.lifeMoments) ? .lifeMoments : nil
        default: nil
        }
    }
}
