//
//  AssistantPersona.swift
//  JournalFoundation
//
//  Parameterized assistant identity. OffRecord passes Friday; LifeBoard
//  passes Eva. Engines and responders never hardcode a persona name —
//  every user-facing string and system prompt flows through this value.
//

import Foundation

/// Voice and copy for one assistant persona. Templates keep the wording
/// per-app while the engines stay shared.
public struct PersonaCopyCatalog: Hashable, Codable, Sendable {
    /// First-run greeting, e.g. "I'm Friday. Tell me what you're carrying…".
    public var welcome: String
    /// Shown when there is not enough journal data to answer usefully.
    public var insufficientData: String
    /// Prefix for surfaced observations, e.g.
    /// "I'm noticing this from your entries so far: ".
    public var noticedPrefix: String
    /// Suffix for ongoing-pattern observations, e.g.
    /// " I'll keep watching this with you."
    public var watchingSuffix: String
    /// Reply when the only relevant evidence is excluded from AI —
    /// the assistant must behave as if the entry does not exist.
    public var exclusionRespected: String
    /// Supportive, non-clinical reply used when `SensitiveDomainPolicy`
    /// suppresses normal answering for high-risk content.
    public var riskSafeSupport: String

    public init(
        welcome: String,
        insufficientData: String,
        noticedPrefix: String,
        watchingSuffix: String,
        exclusionRespected: String,
        riskSafeSupport: String
    ) {
        self.welcome = welcome
        self.insufficientData = insufficientData
        self.noticedPrefix = noticedPrefix
        self.watchingSuffix = watchingSuffix
        self.exclusionRespected = exclusionRespected
        self.riskSafeSupport = riskSafeSupport
    }
}

public struct AssistantPersona: Hashable, Codable, Sendable {
    /// Stable identifier, e.g. "friday", "eva".
    public var id: String
    /// Display name used in prompts and copy, e.g. "Friday", "Eva".
    public var name: String
    /// Host app name for disclosures, e.g. "OffRecord", "LifeBoard".
    public var hostAppName: String
    /// Evidence-answering system prompt with `{name}` / `{app}` placeholders.
    /// The retrieval and citation validation stay deterministic; the language
    /// model only phrases the provided evidence.
    public var evidenceSystemPromptTemplate: String
    public var copy: PersonaCopyCatalog

    public init(
        id: String,
        name: String,
        hostAppName: String,
        evidenceSystemPromptTemplate: String,
        copy: PersonaCopyCatalog
    ) {
        self.id = id
        self.name = name
        self.hostAppName = hostAppName
        self.evidenceSystemPromptTemplate = evidenceSystemPromptTemplate
        self.copy = copy
    }

    /// The resolved evidence-answering system prompt.
    public var evidenceSystemPrompt: String {
        evidenceSystemPromptTemplate
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{app}", with: hostAppName)
    }

    public func noticed(_ text: String) -> String {
        copy.noticedPrefix + text
    }

    public func watching(_ text: String) -> String {
        text + copy.watchingSuffix
    }
}
