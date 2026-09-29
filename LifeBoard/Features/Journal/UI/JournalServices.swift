import AVFAudio
import CoreSpotlight
import Foundation
import LifeBoardDomain
import LocalAuthentication
import LifeBoardPersistence
import Observation
import PhotosUI
import LifeBoardDomain
import Speech
import SwiftUI
import LifeBoardTranscription
import UIKit
import UniformTypeIdentifiers
import LifeBoardContracts

enum JournalInsightService {
    static func makeSnapshot(days: [JournalDayValue], now: Date = Date(), calendar: Calendar = .current) -> JournalInsightSnapshot {
        let written = days.filter { !$0.blocks.isEmpty }
        guard !written.isEmpty else { return .empty }
        let words = written.reduce(0) { partial, day in
            partial + day.displayText.split(whereSeparator: \.isWhitespace).count
        }
        let moods = written.flatMap(\.blocks).compactMap(\.mood).filter { $0 != .none }
        let dominant = Dictionary(grouping: moods, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        let energies = written.flatMap(\.blocks).compactMap(\.energy)
        let averageEnergy = energies.isEmpty ? nil : Double(energies.reduce(0, +)) / Double(energies.count)
        // No streak: a journal is not a chain to keep unbroken (PRD: no
        // pressure, no shame). Days and words are the honest measures.
        return .init(
            daysWritten: written.count,
            totalWords: words,
            dominantMood: dominant,
            averageEnergy: averageEnergy,
            evidenceDayIDs: Array(written.prefix(7).map(\.id))
        )
    }
}

struct JournalIndexingService: Sendable {
    private let derivedIndex: (any JournalDerivedIndexRepository)?
    private let derivedPipeline: JournalDerivedPipelineCoordinator?

    init(
        repository: any PhaseIIRepository,
        derivedIndex: (any JournalDerivedIndexRepository)? = nil,
        derivedPipeline: JournalDerivedPipelineCoordinator? = nil
    ) {
        if let derivedIndex {
            self.derivedIndex = derivedIndex
            self.derivedPipeline = derivedPipeline
            return
        }
        let semantic = SemanticJournalDerivedIndexRepository(
            snapshotProvider: {
                try await repository
                    .fetchJournalDays(search: nil, starredOnly: false, mood: nil)
                    .map(JournalEntrySnapshot.init(day:))
            }
        )
        self.derivedIndex = semantic
        self.derivedPipeline = (repository as? CoreDataLifeBoardPhaseIIRepository)?
            .makeJournalDerivedPipeline(derivedIndex: semantic)
    }

    func upsert(_ day: JournalDayValue) async throws {
        let snapshot = JournalEntrySnapshot(day: day)
        if let derivedPipeline {
            try await derivedPipeline.processCommitted(snapshot)
        } else if let derivedIndex {
            try await derivedIndex.upsert(entry: snapshot)
        }
        await JournalSpotlightIndexer.index(day)
    }

    func remove(dayID: UUID) async throws {
        if let derivedPipeline {
            try await derivedPipeline.processDeletion(entryID: dayID)
        } else if let derivedIndex {
            try await derivedIndex.remove(entryID: dayID)
        }
        await JournalSpotlightIndexer.remove(dayID: dayID)
    }
}

/// Journal days are not in Spotlight.
///
/// Each day used to be indexed as "Journal — <date>" with the description
/// "Private journal day": no words to find it by, a result that only said a
/// private journal exists, and one that showed on the lock-screen search of
/// anyone holding the phone. Saving a day now clears whatever an earlier
/// build indexed instead of adding to it.
enum JournalSpotlightIndexer {
    static let legacyDomainIdentifier = "com.lifeboard.private-journal"

    static func index(_ day: JournalDayValue) async {
        try? await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [legacyDomainIdentifier])
    }

    static func remove(dayID: UUID) async {
        try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["lifeboard-journal-\(dayID.uuidString)"])
    }
}

/// Rules for correcting a saved journal text block.
enum JournalBlockTextEdit {
    /// The block with new text, or nil when there is nothing to save (empty, or
    /// unchanged apart from surrounding whitespace).
    static func apply(_ text: String, to block: JournalBlockValue, now: Date = Date()) -> JournalBlockValue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard block.kind == .text, trimmed.isEmpty == false, trimmed != block.text else { return nil }
        var updated = block
        updated.text = trimmed
        updated.updatedAt = now
        return updated
    }

    /// "9:41 AM", or "9:41 AM · edited" once the words changed after writing —
    /// a journal should not quietly rewrite its own history.
    static func timestampLabel(for block: JournalBlockValue) -> String {
        let time = block.createdAt.formatted(date: .omitted, time: .shortened)
        return block.updatedAt > block.createdAt && block.kind == .text
            ? "\(time) · edited"
            : time
    }
}

struct JournalBlockTextEditor: View {
    let initialText: String
    let onSave: (String) async -> Bool
    @State private var text: String
    @State private var isSaving = false
    @State private var saveFailed = false
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(initialText: String, onSave: @escaping (String) async -> Bool) {
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    private var canSave: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty == false && trimmed != initialText
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .keyboardBar(isFocused: $isFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("journal.block.editor")
                .navigationTitle("Edit entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.disabled(isSaving)
                            .keyboardShortcut(.cancelAction)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            isSaving = true
                            Task { @MainActor in
                                let saved = await onSave(text)
                                isSaving = false
                                saveFailed = !saved
                                if saved { dismiss() }
                            }
                        }
                        .disabled(canSave == false || isSaving)
                        .accessibilityIdentifier("journal.block.editor.save")
                    }
                }
                .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(text != initialText || isSaving)
        .alert("Couldn’t save edit", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your words are kept. Try saving again.")
        }
    }
}
