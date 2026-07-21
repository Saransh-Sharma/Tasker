//
//  LifeBoardJournalSnapshotAdapter.swift
//  LifeBoard
//
//  Adapts LifeBoard's journal persistence onto the shared
//  `JournalSnapshotProviding` seam so JournalKit engines (semantic memory,
//  reflection, knowledge graph) consume storage-agnostic snapshots.
//

import Foundation
import JournalFoundation

extension LifeBoardJournalBlockValue {
    var journalBlockSnapshot: JournalBlockSnapshot {
        let kind: JournalBlockSnapshot.Kind
        switch self.kind {
        case .text, .prompt: kind = .text
        case .voice: kind = .voiceTranscript
        case .photo: kind = .photo
        case .audio: kind = .audio
        case .mood: kind = .mood
        }
        return JournalBlockSnapshot(
            id: id,
            kind: kind,
            text: text,
            moodToken: mood.map(\.rawValue),
            attachmentID: mediaID,
            sortOrder: ordinal,
            createdAt: createdAt
        )
    }
}

extension LifeBoardJournalDayValue {
    /// The shared-engine view of this journal day.
    public var journalSnapshot: JournalSnapshot {
        JournalSnapshot(
            id: id,
            date: day,
            createdAt: createdAt,
            updatedAt: updatedAt,
            moodToken: latestMood.map(\.rawValue),
            isStarred: isStarred,
            blocks: blocks.map(\.journalBlockSnapshot),
            aiExclusion: aiExclusion
        )
    }
}

/// Fetches shared snapshots straight from the Phase II repository.
public struct LifeBoardJournalSnapshotAdapter: JournalSnapshotProviding {
    private let repository: any LifeBoardPhaseIIRepository

    public init(repository: any LifeBoardPhaseIIRepository) {
        self.repository = repository
    }

    public func snapshots(in interval: DateInterval) async throws -> [JournalSnapshot] {
        try await repository
            .fetchJournalDays(search: nil, starredOnly: false, mood: nil)
            .filter { interval.contains($0.day) }
            .sorted { $0.day < $1.day }
            .map(\.journalSnapshot)
    }

    public func snapshot(id: UUID) async throws -> JournalSnapshot? {
        try await repository
            .fetchJournalDays(search: nil, starredOnly: false, mood: nil)
            .first { $0.id == id }
            .map(\.journalSnapshot)
    }

    public func allSnapshotIDs() async throws -> [UUID] {
        try await repository
            .fetchJournalDays(search: nil, starredOnly: false, mood: nil)
            .map(\.id)
    }
}
