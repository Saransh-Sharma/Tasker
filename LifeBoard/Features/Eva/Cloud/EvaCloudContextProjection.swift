import Foundation

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
            .init(category: .planning, payload: .object([
                "taskProjection": .string(taskProjection),
                "executiveState": .string(executiveState ?? ""),
                "slashCommandState": .string(slashCommandState ?? ""),
            ])),
        ]
        guard let consent else { return sections }
        if let personalMemory, consent.grants.contains(.personalMemory) {
            sections.append(.init(category: .personalMemory, payload: .string(personalMemory)))
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
        var values: [EvaCloudContextSection.Category: [EvaJSONValue]] = [:]
        for event in evidence.events.prefix(24)
        where event.authorization == .authorized && event.allowedDestinations.contains(.eva) {
            guard let category = category(for: event.domain, grants: grants) else { continue }
            var object: [String: EvaJSONValue] = [
                "reference": .string("LB-\(event.sourceID.uuidString.prefix(8).uppercased())"),
                "domain": .string(event.domain),
                "kind": .string(event.kind),
                "occurredAt": .string(event.occurredAt.ISO8601Format()),
                "freshness": .string(event.freshness.rawValue),
            ]
            if event.redaction != .sensitiveSummary,
               let display = event.evidence.first?.display,
               !display.isEmpty {
                object["source"] = .string(display)
            }
            if event.redaction != .sensitiveSummary, let numericValue = event.numericValue {
                object["value"] = .number(numericValue)
            }
            values[category, default: []].append(.object(object))
        }
        return [EvaCloudContextSection.Category.journal, .health, .lifeMoments].compactMap { category in
            guard let events = values[category], !events.isEmpty else { return nil }
            return .init(category: category, payload: .array(events))
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
