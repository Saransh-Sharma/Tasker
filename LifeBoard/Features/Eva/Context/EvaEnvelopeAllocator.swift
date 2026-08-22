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
            let originalRecordCount = recordCount(in: payload)
            var candidate = sectionWithBudgetMetadata(
                section,
                payload: payload,
                originalIDs: originalIDs,
                originalRecordCount: originalRecordCount
            )
            var cost = encodedCost(candidate)
            while cost > remaining, payload.dropLowestPriorityRecord() {
                candidate = sectionWithBudgetMetadata(
                    section,
                    payload: payload,
                    originalIDs: originalIDs,
                    originalRecordCount: originalRecordCount
                )
                cost = encodedCost(candidate)
            }
            guard cost <= remaining, payload != .null else { continue }
            remaining -= cost
            admitted.append(candidate)
        }
        return EvaContextEnvelope(sections: admitted).ordered()
    }

    private static func sectionWithBudgetMetadata(
        _ section: EvaCloudContextSection,
        payload: EvaJSONValue,
        originalIDs: [String],
        originalRecordCount: Int
    ) -> EvaCloudContextSection {
        let includedIDs = sourceIDs(in: payload)
        let includedRecordCount = recordCount(in: payload)
        let partial = includedIDs.count < originalIDs.count
            || includedRecordCount < originalRecordCount
        let originalMetadata = section.metadata
        let partialReasons = Array(Set(
            (originalMetadata?.partialReasons ?? [])
                + (partial ? ["encodedEnvelopeBudget"] : [])
        )).sorted()
        return EvaCloudContextSection(
            category: section.category,
            payload: payload,
            metadata: EvaContextSectionMetadata(
                availability: partial ? "partial" : (originalMetadata?.availability ?? "complete"),
                availableCount: originalMetadata?.availableCount
                    ?? (originalRecordCount == 0 ? nil : originalRecordCount),
                includedCount: partial
                    ? (includedRecordCount == 0 ? nil : includedRecordCount)
                    : (originalMetadata?.includedCount ?? (includedRecordCount == 0 ? nil : includedRecordCount)),
                partialReasons: partialReasons,
                sourceIDs: includedIDs.isEmpty ? (originalMetadata?.sourceIDs ?? []) : includedIDs,
                selectionReasons: originalMetadata?.selectionReasons ?? ["routeBaseline"],
                freshnessAt: originalMetadata?.freshnessAt
            )
        )
    }

    private static func priority(_ category: EvaCloudContextSection.Category) -> Int {
        switch category {
        case .planning: 0
        case .capacity, .calendar: 1
        case .goals, .habits, .personalMemory, .knowledge: 2
        case .dayLoop, .retrospective: 3
        case .journal, .health, .lifeMoments: 4
        }
    }

    private static func encodedCost(_ payload: EvaJSONValue) -> Int {
        (try? JSONEncoder.evaCloud.encode(payload).count) ?? Int.max
    }

    private static func encodedCost(_ section: EvaCloudContextSection) -> Int {
        (try? JSONEncoder.evaCloud.encode(section).count) ?? Int.max
    }

    private static func recordCount(in value: EvaJSONValue) -> Int {
        switch value {
        case .array(let values):
            return values.count
        case .object(let object):
            return ["tasks", "calendar", "events", "records", "projects", "lifeAreas"]
                .reduce(into: 0) { count, key in
                    if case .array(let values) = object[key] { count += values.count }
                }
        default:
            return 0
        }
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
