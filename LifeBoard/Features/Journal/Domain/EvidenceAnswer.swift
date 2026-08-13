//
//  EvidenceAnswer.swift
//  AssistantCoreKit
//
//  Persona-neutral evidence-backed answers. Retrieval and citation
//  validation stay deterministic; any language model only phrases the
//  provided evidence.
//

import Foundation
import LifeBoardDomain

public struct EvidenceBackedAnswer: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let summary: String
    public let observations: [EvidenceObservation]
    public let evidence: [EvidenceReference]
    public let confidence: Double
    public let followUpPrompt: String?
    public let limitations: String?

    public init(
        summary: String,
        observations: [EvidenceObservation],
        evidence: [EvidenceReference],
        confidence: Double,
        followUpPrompt: String?,
        limitations: String?
    ) {
        self.summary = summary
        self.observations = observations
        self.evidence = evidence
        self.confidence = confidence
        self.followUpPrompt = followUpPrompt
        self.limitations = limitations
    }
}

/// Host apps plug their own inference here: OffRecord and LifeBoard both get
/// the iOS 26 FoundationModels implementation for free; LifeBoard can bridge
/// its MLX pipeline behind the same seam.
public protocol EvidenceResponding: Sendable {
    /// Returns nil when the responder cannot improve on the deterministic
    /// fallback (model unavailable, empty evidence, no valid citations).
    func respond(
        question: String,
        evidence: [EvidenceReference],
        persona: LifeBoardDomain.AssistantPersona,
        fallback: EvidenceBackedAnswer
    ) async throws -> EvidenceBackedAnswer?
}

/// Deterministic, model-free answer assembly: surfaces the strongest
/// evidence as observations with citations. Always available; used as the
/// fallback input for model-backed responders and as the degraded state.
public enum DeterministicEvidenceAnswerBuilder {
    public static func answer(
        question: String,
        evidence: [EvidenceReference],
        persona: LifeBoardDomain.AssistantPersona
    ) -> EvidenceBackedAnswer {
        guard !evidence.isEmpty else {
            return EvidenceBackedAnswer(
                summary: persona.copy.insufficientData,
                observations: [],
                evidence: [],
                confidence: 0,
                followUpPrompt: nil,
                limitations: nil
            )
        }

        let top = Array(evidence.prefix(3))
        let observations = top.map { item in
            EvidenceObservation(
                text: "\(item.date.formatted(date: .abbreviated, time: .omitted)): \(item.snippet)",
                evidenceIDs: [item.id]
            )
        }
        let confidence = min(0.72, 0.3 + Double(evidence.count) * 0.07)
        return EvidenceBackedAnswer(
            summary: persona.noticed("\(evidence.count == 1 ? "one entry relates" : "\(evidence.count) entries relate") to this."),
            observations: observations,
            evidence: top,
            confidence: confidence,
            followUpPrompt: nil,
            limitations: evidence.count < 3 ? "Only a few related entries were found." : nil
        )
    }
}
