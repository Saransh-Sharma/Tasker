//
//  LifeBoardJournalEvidenceService.swift
//  LifeBoard
//
//  Phase V journal parity: evidence-cited, risk-safe journal answers for
//  Eva, built on the shared AssistantCoreKit. Three independent gates run
//  before any journal content reaches a response:
//
//  1. `JournalPrivacyPolicy.permitsJournalEvidenceForEva` — the user's
//     journal-wide switch.
//  2. Per-entry `JournalAIExclusion` — excluded entries never enter the
//     semantic index (ingest gate) and are re-checked here at assembly.
//  3. `SensitiveDomainPolicy` — high-risk content suppresses analysis and
//     yields supportive, non-clinical copy only.
//
//  The language model (FoundationModels when available and enabled) only
//  phrases retrieved evidence; retrieval and citation validation stay
//  deterministic, with a model-free fallback always available.
//

import Foundation
import AssistantCoreKit
import JournalFoundation
import SemanticMemoryKit

extension AssistantPersona {
    /// Eva, LifeBoard's chief of staff.
    static let eva = AssistantPersona(
        id: "eva",
        name: "Eva",
        hostAppName: "LifeBoard",
        evidenceSystemPromptTemplate: "You are {name}, the user's chief of staff inside {app}. When answering about their journal, answer only from the provided evidence.",
        copy: PersonaCopyCatalog(
            welcome: "I'm Eva. Ask me about your days, or what I've noticed.",
            insufficientData: "I don't have enough journal context yet. Keep capturing and I'll get more useful.",
            noticedPrefix: "From your journal, ",
            watchingSuffix: " I'll keep an eye on this with you.",
            exclusionRespected: "I don't have anything on that.",
            riskSafeSupport: "That sounds heavy. I'm here with you. It might also help to talk to someone you trust."
        )
    )
}

struct LifeBoardJournalEvidenceService {

    let derivedIndex: any JournalDerivedIndexRepository
    let snapshotProvider: @Sendable () async throws -> [JournalEntrySnapshot]
    let permitsJournalEvidenceForEva: @Sendable () -> Bool
    var persona: AssistantPersona = .eva
    var sensitivePolicy: SensitiveDomainPolicy = .standard

    /// Evidence-cited answer for a journal question, or the persona's
    /// refusal copy when gates deny access.
    func answer(question: String) async -> EvidenceBackedAnswer {
        // Gate 1: journal-wide Eva permission.
        guard permitsJournalEvidenceForEva() else {
            return EvidenceBackedAnswer(
                summary: persona.copy.exclusionRespected,
                observations: [],
                evidence: [],
                confidence: 0,
                followUpPrompt: nil,
                limitations: "Journal evidence is turned off for Eva in Journal privacy settings."
            )
        }

        // Retrieval (the semantic index already excludes opted-out entries).
        let journalReferences = (try? await derivedIndex.search(query: question, limit: 12)) ?? []

        // Gate 2: per-entry exclusion re-checked at assembly (defense in
        // depth against a stale index).
        let snapshots = (try? await snapshotProvider()) ?? []
        let exclusionByID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0.aiExclusion) })
        let permitted = journalReferences.filter { reference in
            (exclusionByID[reference.entryID] ?? .included).permitsAssistantEvidence
        }

        let evidence = permitted.map { reference in
            SemanticMemoryKit.EvidenceReference(
                id: reference.id,
                entryID: reference.entryID,
                date: reference.date,
                mood: nil,
                snippet: reference.snippet,
                chunkText: reference.snippet,
                score: reference.score,
                matchReason: Self.matchReason(reference.matchReason)
            )
        }

        // Gate 3: risk-safe interception on the question surface.
        if Self.questionTouchesHighRisk(question) {
            return EvidenceBackedAnswer(
                summary: persona.copy.riskSafeSupport,
                observations: [],
                evidence: [],
                confidence: 0,
                followUpPrompt: nil,
                limitations: nil
            )
        }

        let fallback = DeterministicEvidenceAnswerBuilder.answer(
            question: question,
            evidence: evidence,
            persona: persona
        )

        #if canImport(FoundationModels)
        if V2FeatureFlags.evaFoundationModelsResponderEnabled, #available(iOS 26.0, macOS 26.0, *) {
            if let modelAnswer = try? await FoundationModelsEvidenceResponder().respond(
                question: question,
                evidence: evidence,
                persona: persona,
                fallback: fallback
            ) {
                return modelAnswer
            }
        }
        #endif
        return fallback
    }

    private static func matchReason(_ reason: JournalEvidenceReference.MatchReason) -> SemanticMemoryKit.EvidenceReference.MatchReason {
        switch reason {
        case .exact: return .exact
        case .meaning: return .meaning
        case .topic: return .entity
        case .recent: return .recent
        }
    }

    /// Conservative lexical screen for content that must route to support
    /// copy instead of analysis. Matches the reflection safety ladder's
    /// highRiskExcluded intent without attempting diagnosis.
    static func questionTouchesHighRisk(_ question: String) -> Bool {
        let lower = question.lowercased()
        let markers = [
            "kill myself", "suicide", "self harm", "self-harm", "hurt myself",
            "end my life", "want to die", "no reason to live",
        ]
        return markers.contains { lower.contains($0) }
    }
}
