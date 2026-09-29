import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

/// Pure derivations backing the chat slash-command pickers.
///
/// Lifted out of `ChatView` so the view type stays small — same pattern as
/// `TrackSectionCopy` in `LifeBoardTrackFoundationViews.swift`. Every entry point
/// is a `static func` over explicit inputs, so nothing here reads view state.
enum ChatSlashSuggestionCatalog {
    static func commandSuggestions(
        prompt: String,
        transcriptSnapshot: ChatTranscriptSnapshot,
        recents: [SlashCommandID]
    ) -> [SlashCommandDescriptor] {
        var suggestions: [SlashCommandDescriptor] = []
        var seen = Set<SlashCommandID>()

        let contextual = contextualCommandIDs(
            prompt: prompt,
            transcriptSnapshot: transcriptSnapshot
        )
        for commandID in contextual {
            guard seen.insert(commandID).inserted else { continue }
            suggestions.append(SlashCommandCatalog.descriptor(for: commandID))
            if suggestions.count >= 3 {
                return suggestions
            }
        }

        for commandID in recents {
            guard seen.insert(commandID).inserted else { continue }
            suggestions.append(SlashCommandCatalog.descriptor(for: commandID))
            if suggestions.count >= 3 {
                return suggestions
            }
        }

        for descriptor in SlashCommandCatalog.descriptors.sorted(by: { $0.id.popularityRank < $1.id.popularityRank }) {
            guard seen.insert(descriptor.id).inserted else { continue }
            suggestions.append(descriptor)
            if suggestions.count >= 3 {
                break
            }
        }

        return suggestions
    }

    static func contextualCommandIDs(
        prompt: String,
        transcriptSnapshot: ChatTranscriptSnapshot
    ) -> [SlashCommandID] {
        let hintText = contextualHintText(prompt: prompt, transcriptSnapshot: transcriptSnapshot)
        guard hintText.isEmpty == false else { return [] }

        var ordered: [SlashCommandID] = []
        func append(_ commandID: SlashCommandID, when condition: Bool) {
            guard condition else { return }
            guard ordered.contains(commandID) == false else { return }
            ordered.append(commandID)
        }

        append(.overdue, when: hintText.contains("overdue") || hintText.contains("late"))
        append(.today, when: hintText.contains("today"))
        append(.tomorrow, when: hintText.contains("tomorrow"))
        append(.week, when: hintText.contains("week"))
        append(.month, when: hintText.contains("month"))
        append(.project, when: hintText.contains("project") || hintText.contains("inbox"))
        append(.area, when: hintText.contains("life area") || hintText.contains("area"))
        append(.recent, when: hintText.contains("recent") || hintText.contains("last 2 weeks") || hintText.contains("last two weeks"))
        append(.clear, when: hintText.contains("clear chat") || hintText.contains("reset chat"))

        return ordered
    }

    static func contextualHintText(
        prompt: String,
        transcriptSnapshot: ChatTranscriptSnapshot
    ) -> String {
        var fragments: [String] = []
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.isEmpty == false {
            fragments.append(trimmedPrompt.lowercased())
        }
        fragments.append(contentsOf: transcriptSnapshot.recentUserMessageFragments)
        return fragments.joined(separator: " ")
    }

    static func recentPickerCommands(recents: [SlashCommandID]) -> [SlashCommandDescriptor] {
        var unique = Set<SlashCommandID>()
        return recents.prefix(3).compactMap { commandID in
            guard unique.insert(commandID).inserted else { return nil }
            return SlashCommandCatalog.descriptor(for: commandID)
        }
    }

    static func popularPickerCommands(recents: [SlashCommandID]) -> [SlashCommandDescriptor] {
        let recentSet = Set(recents)
        return SlashCommandCatalog.descriptors
            .filter { recentSet.contains($0.id) == false }
            .sorted { $0.id.popularityRank < $1.id.popularityRank }
            .prefix(5)
            .map { $0 }
    }

    static func allPickerCommands(
        query: String,
        recents: [SlashCommandID]
    ) -> [SlashCommandDescriptor] {
        SlashCommandCatalog.filteredDescriptors(query: query, recents: recents, limit: 8)
    }

    static func pickerQuery(fromPrompt promptText: String) -> String {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return "" }
        let raw = String(trimmed.dropFirst())
        return raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
    }
}
