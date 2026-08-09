//
//  FoundationModelsEvidenceResponder.swift
//  AssistantCoreKit
//
//  Optional iOS 26 response layer for evidence-backed answers. Retrieval and
//  citation validation stay deterministic; the persona only shapes the voice.
//

import Foundation
import LifeBoardDomain
import SemanticMemoryKit

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedEvidenceObservation {
    let text: String
    let evidenceIDs: [String]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedEvidenceBackedAnswer {
    let summary: String
    let observations: [GeneratedEvidenceObservation]
    let confidence: Double
    let followUpPrompt: String
    let limitations: String?
}

@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsEvidenceResponder: EvidenceResponding {

    public init() {}

    public static var isModelAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public func respond(
        question: String,
        evidence: [EvidenceReference],
        persona: AssistantPersona,
        fallback: EvidenceBackedAnswer
    ) async throws -> EvidenceBackedAnswer? {
        let model = SystemLanguageModel.default
        guard model.availability == .available else { return nil }
        guard !evidence.isEmpty else { return nil }

        let evidenceIDs = Set(evidence.map(\.id))
        let evidenceBlock = evidence.enumerated().map { index, item in
            """
            Evidence \(index + 1)
            id: \(item.id)
            date: \(item.date.formatted(date: .abbreviated, time: .omitted))
            mood: \(item.mood ?? "unknown")
            snippet: \(item.snippet)
            """
        }
        .joined(separator: "\n\n")

        let session = LanguageModelSession(
            model: model,
            instructions: """
            \(persona.evidenceSystemPrompt)
            Every substantive observation must be supported by one or more evidenceIDs from the evidence list.
            If the evidence is weak, say so in limitations. Do not invent people, events, dates, moods, or causes.
            Keep the answer concise, warm, and specific. Never use clinical or diagnostic language.
            """
        )

        let response = try await session.respond(
            to: """
            User question:
            \(question)

            Retrieved journal evidence:
            \(evidenceBlock)

            Produce an evidence-backed answer. Use only evidenceIDs from the list.
            """,
            generating: GeneratedEvidenceBackedAnswer.self,
            options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 420)
        )

        let generated = response.content
        let observations = generated.observations.compactMap { observation -> EvidenceObservation? in
            let citedIDs = observation.evidenceIDs.filter { evidenceIDs.contains($0) }
            guard !observation.text.isEmpty, !citedIDs.isEmpty else { return nil }
            return EvidenceObservation(text: observation.text, evidenceIDs: citedIDs)
        }
        let citedIDs = Set(observations.flatMap(\.evidenceIDs))
        guard !citedIDs.isEmpty else { return nil }

        let citedEvidence = evidence.filter { citedIDs.contains($0.id) }
        let confidence = min(max(generated.confidence, 0), fallback.confidence)

        return EvidenceBackedAnswer(
            summary: generated.summary.isEmpty ? fallback.summary : generated.summary,
            observations: observations.isEmpty ? fallback.observations : observations,
            evidence: citedEvidence,
            confidence: confidence,
            followUpPrompt: generated.followUpPrompt.isEmpty ? fallback.followUpPrompt : generated.followUpPrompt,
            limitations: generated.limitations ?? fallback.limitations
        )
    }
}
#endif
