//
//  JournalAIExclusion.swift
//  JournalFoundation
//
//  Per-entry AI participation control. This is new shared contract (OffRecord
//  historically had no per-entry opt-out); both apps enforce it at three
//  independent gates: semantic-index ingest, reflection input, and assistant
//  evidence assembly.
//

import Foundation

public enum JournalAIExclusion: String, Codable, Sendable, CaseIterable, Hashable {
    /// Default: entry participates in semantic memory, reflection, and
    /// assistant evidence (subject to the host app's domain-level policies).
    case included
    /// Entry never enters semantic memory and is never cited as assistant
    /// evidence, but still counts toward weekly-reflection aggregates
    /// (mood trends, entry counts) without being quoted.
    case excludedFromAI
    /// Entry is invisible to every AI surface, including reflection.
    case excludedFromAIAndReflection

    /// May this entry be chunked, embedded, and stored in the semantic index?
    public var permitsSemanticIndexing: Bool { self == .included }

    /// May this entry be retrieved and quoted as assistant evidence?
    public var permitsAssistantEvidence: Bool { self == .included }

    /// May this entry contribute to weekly reflection at all?
    public var permitsReflection: Bool { self != .excludedFromAIAndReflection }

    /// May this entry be quoted (not just counted) in reflection output?
    public var permitsReflectionQuotes: Bool { self == .included }
}
