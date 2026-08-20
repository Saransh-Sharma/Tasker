import Foundation

/// One encoded-envelope allocator for Cloud context. It reserves the fixed
/// prompt/output portions first, then admits whole records by product priority.
/// It never slices JSON text or identifiers.
enum EvaEnvelopeAllocator {
    static func allocate(
        _ sections: [EvaCloudContextSection],
        budget: EvaContextBudget
    ) -> [EvaCloudContextSection] {
        guard budget.isCloud else { return sections }
        let reservedTokens = budget.systemPromptTokens + budget.reservedOutputTokens
            + budget.slashContextTokens + budget.executiveContextTokens
        let availableTokens = max(256, budget.inputTokens - reservedTokens)
        let characterLimit = LLMTokenBudgetEstimator.estimatedCharacterBudget(for: availableTokens)
        var remaining = characterLimit
        var admitted: [EvaCloudContextSection] = []

        for section in sections.sorted(by: { priority($0.category) < priority($1.category) }) {
            var payload = section.payload
            let originalIDs = sourceIDs(in: payload)
            var cost = encodedCost(payload)
            while cost > remaining, payload.dropLowestPriorityRecord() {
                cost = encodedCost(payload)
            }
            guard cost <= remaining, payload != .null else { continue }
            remaining -= cost
            let includedIDs = sourceIDs(in: payload)
            let partial = includedIDs.count < originalIDs.count
            admitted.append(EvaCloudContextSection(
                category: section.category,
                payload: payload,
                metadata: EvaContextSectionMetadata(
                    availability: partial ? "partial" : "complete",
                    availableCount: originalIDs.isEmpty ? nil : originalIDs.count,
                    includedCount: includedIDs.isEmpty ? nil : includedIDs.count,
                    partialReasons: partial ? ["encodedEnvelopeBudget"] : [],
                    sourceIDs: includedIDs
                )
            ))
        }
        return EvaContextEnvelope(sections: admitted).ordered()
    }

    private static func priority(_ category: EvaCloudContextSection.Category) -> Int {
        switch category {
        case .planning: 0
        case .capacity, .calendar: 1
        case .goals, .habits, .personalMemory: 2
        case .dayLoop, .retrospective: 3
        case .journal, .health, .lifeMoments: 4
        }
    }

    private static func encodedCost(_ payload: EvaJSONValue) -> Int {
        (try? JSONEncoder.evaCloud.encode(payload).count) ?? Int.max
    }

    private static func sourceIDs(in value: EvaJSONValue) -> [String] {
        var values = Set<String>()
        func visit(_ value: EvaJSONValue) {
            switch value {
            case .object(let object):
                for key in ["id", "reference"] {
                    if case .string(let id) = object[key] { values.insert(id) }
                }
                object.values.forEach(visit)
            case .array(let array): array.forEach(visit)
            default: break
            }
        }
        visit(value)
        return values.sorted()
    }
}

private extension EvaJSONValue {
    /// Removes one complete lowest-priority record. Arrays are emitted in
    /// descending retention order by their projectors, so the tail goes first.
    mutating func dropLowestPriorityRecord() -> Bool {
        switch self {
        case .array(var values):
            guard values.isEmpty == false else { return false }
            values.removeLast()
            self = .array(values)
            return true
        case .object(var object):
            let keys = ["tasks", "calendar", "events", "records", "projects", "lifeAreas"]
            for key in keys {
                guard case .array(var values) = object[key], values.isEmpty == false else { continue }
                values.removeLast()
                object[key] = .array(values)
                self = .object(object)
                return true
            }
            return false
        default:
            return false
        }
    }
}
