import Foundation

enum EvaMemoryMapper {
    static func mergeIntoLocalStore(
        draft: EvaProfileDraft,
        existing: LLMPersonalMemoryStoreV1
    ) -> LLMPersonalMemoryStoreV1 {
        var merged = existing

        let preferenceEntries =
            draft.selectedWorkingStyleIDs.compactMap { EvaWorkingStyleID(rawValue: $0)?.memoryText }
            + normalizedFreeform(draft.customWorkingStyleNote)
        let routineEntries =
            draft.selectedMomentumBlockerIDs.compactMap { EvaMomentumBlockerID(rawValue: $0)?.memoryText }
            + normalizedFreeform(draft.customMomentumNote)
        let goalEntries = draft.goals.flatMap(normalizeGoal)

        merged.setEntries(
            mergeSection(newEntries: preferenceEntries, into: existing.preferences),
            for: .preferences
        )
        merged.setEntries(
            mergeSection(newEntries: routineEntries, into: existing.routines),
            for: .routines
        )
        merged.setEntries(
            mergeSection(newEntries: goalEntries, into: existing.currentGoals),
            for: .currentGoals
        )

        return merged
    }

    private static func mergeSection(
        newEntries: [String],
        into existing: [LLMPersonalMemoryEntry]
    ) -> [LLMPersonalMemoryEntry] {
        let normalizedNew = newEntries.compactMap(normalizeText)
        var seen = Set<String>()
        var merged: [LLMPersonalMemoryEntry] = []

        for text in normalizedNew {
            let key = text.lowercased()
            guard seen.insert(key).inserted else { continue }
            merged.append(LLMPersonalMemoryEntry(text: text))
        }

        for entry in existing {
            guard let text = normalizeText(entry.text) else { continue }
            let key = text.lowercased()
            guard seen.insert(key).inserted else { continue }
            merged.append(LLMPersonalMemoryEntry(id: entry.id, text: text))
        }

        return Array(merged.prefix(LLMPersonalMemoryStoreV1.maxEntriesPerSection))
    }

    private static func normalizedFreeform(_ note: String?) -> [String] {
        guard let text = normalizeText(note) else { return [] }
        return [text]
    }

    private static func normalizeGoal(_ goal: String) -> [String] {
        guard let text = normalizeText(goal) else { return [] }
        return [text]
    }

    private static func normalizeText(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.isEmpty == false else { return nil }
        return String(collapsed.prefix(LLMPersonalMemoryStoreV1.maxEntryCharacters))
    }
}
