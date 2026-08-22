import Foundation
import JournalFeature
import KnowledgeFeature
import LifeBoardDomain
import MLXLMCommon

enum EvaFeatureProviderRegistration {
    @MainActor
    static func install() {
        Task {
            await NoteAITextProviderRegistry.shared.register(EvaNoteAITextProvider())
            await EvidenceResponderRegistry.shared.register(EvaJournalEvidenceResponder())
        }
    }
}

struct EvaNoteAITextProvider: NoteAITextProviding {
    func generate(action: NoteAIAction, source: String) async throws -> String {
        let instruction = switch action {
        case .summarize: "Summarize the supplied note in a warm, precise paragraph."
        case .cleanUp: "Improve clarity and structure without adding facts. Return only the revised text."
        case .continueWriting: "Continue naturally with one concise paragraph. Do not invent specific facts."
        case .extractTasks: "List only concrete next actions already supported by the note, one per line."
        case .suggestTags: "Suggest up to five short tags, separated by commas."
        case .suggestLinks: "List concepts that would be useful to connect to other notes."
        }
        return try await EvaFeatureTextGenerator.generate(
            route: .knowledgeAnswer,
            profile: .knowledgeAnswer,
            prompt: """
            You are EVA inside LifeBoard Notes. Operate only on the note text explicitly supplied below.
            Never retrieve journal content and never add facts.

            Action: \(instruction)

            Note text:
            \(source)
            """,
            context: []
        )
    }
}

struct EvaJournalEvidenceResponder: EvidenceResponding {
    private struct GeneratedAnswer: Decodable {
        struct Observation: Decodable {
            let text: String
            let evidenceIDs: [String]
        }

        let summary: String
        let observations: [Observation]
        let confidence: Double
        let followUpPrompt: String?
        let limitations: String?
    }

    func respond(
        question: String,
        evidence: [LifeBoardDomain.EvidenceReference],
        persona: LifeBoardDomain.AssistantPersona,
        fallback: EvidenceBackedAnswer
    ) async throws -> EvidenceBackedAnswer? {
        guard evidence.isEmpty == false else { return nil }
        // Journal evidence has to arrive in the shared evidence shape, not a
        // bespoke one: the server validates every section against its category
        // schema, so a differently-shaped journal payload fails the whole
        // request. Mood and match reason ride in `kind` rather than being
        // dropped.
        let journalSection = EvaContextSectionFactory.evidence(
            category: .journal,
            events: evidence.map { item in
                EvaEvidenceEventPayload(
                    reference: item.id,
                    domain: "journal",
                    kind: item.mood.map { "entry/\($0)" } ?? "entry",
                    occurredAt: item.date,
                    freshness: item.matchReason.rawValue,
                    source: item.snippet,
                    value: nil
                )
            }
        )
        let output = try await EvaFeatureTextGenerator.generate(
            route: .journalAnswer,
            profile: .journalAnswer,
            prompt: """
            Question: \(question)

            Phrase an evidence-backed answer in \(persona.name)'s voice. Return one JSON object only:
            {"summary":"...","observations":[{"text":"...","evidenceIDs":["allowed-id"]}],"confidence":0.0,"followUpPrompt":null,"limitations":null}
            Every observation must cite one or more IDs from the supplied journal context. Do not invent events, people, dates, moods, or causes.
            """,
            context: journalSection.map { [$0] } ?? []
        )
        let candidate = Self.jsonObject(in: output)
        guard let data = candidate.data(using: .utf8),
              let generated = try? JSONDecoder.evaCloud.decode(GeneratedAnswer.self, from: data) else { return nil }

        let allowedIDs = Set(evidence.map(\.id))
        let observations = generated.observations.compactMap { item -> EvidenceObservation? in
            let cited = item.evidenceIDs.filter(allowedIDs.contains)
            guard item.text.isEmpty == false, cited.isEmpty == false else { return nil }
            return EvidenceObservation(text: item.text, evidenceIDs: cited)
        }
        let citedIDs = Set(observations.flatMap(\.evidenceIDs))
        guard citedIDs.isEmpty == false else { return nil }
        return EvidenceBackedAnswer(
            summary: generated.summary.isEmpty ? fallback.summary : generated.summary,
            observations: observations,
            evidence: evidence.filter { citedIDs.contains($0.id) },
            confidence: min(max(generated.confidence, 0), fallback.confidence),
            followUpPrompt: generated.followUpPrompt ?? fallback.followUpPrompt,
            limitations: generated.limitations ?? fallback.limitations
        )
    }

    private static func jsonObject(in output: String) -> String {
        let stripped = output
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = stripped.firstIndex(of: "{"),
              let last = stripped.lastIndex(of: "}"), first <= last else { return stripped }
        return String(stripped[first...last])
    }
}

@MainActor
private enum EvaFeatureTextGenerator {
    static func generate(
        route: EvaCloudRoute,
        profile: LLMGenerationProfile,
        prompt: String,
        context: [EvaCloudContextSection]
    ) async throws -> String {
        let modelRoute = AIChatModeRouter.route(for: .addTaskSuggestion)
        let selectedModel = modelRoute.selectedModelName
        let offlineModel = selectedModel.flatMap { ModelConfiguration.getModelByName($0) } ?? .defaultModel
        let runtime = try EvaTurnRuntime.resolve(
            localModelName: selectedModel,
            offlineModel: offlineModel,
            route: route
        )
        if runtime.usesCloud {
            try runtime.validateCurrentAuthority()
            let resolvedContext: [EvaCloudContextSection]
            switch route {
            case .journalAnswer, .knowledgeAnswer:
                // These editor-scoped routes operate only on the exact source
                // the feature supplied; broader retrieval would change a
                // transform/summarize request into an unintended cross-note read.
                resolvedContext = context.map { $0.forContract(runtime.contractVersion) }
            default:
                resolvedContext = await runtime.enrichedContextSections(
                    explicit: context,
                    userQuery: prompt
                )
            }
            let request = EvaInferenceRequest(
                requestId: UUID(),
                route: route,
                contractVersion: runtime.contractVersion,
                locale: Locale.current.identifier,
                timeZone: TimeZone.current.identifier,
                turnContext: runtime.contractVersion >= 4 ? .current(surface: surface(for: route)) : nil,
                messages: [.init(role: .user, content: prompt)],
                context: resolvedContext,
                userInstructions: nil,
                clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
                platform: EvaInstallationIdentity.platform,
                installationId: EvaInstallationIdentity.current,
                consentRevision: runtime.consentRevision ?? 0,
                providerCapabilities: .init(streaming: true, structuredOutput: true, spokenOutput: true)
            )
            return try await EvaCloudProvider().generate(request: request) { _ in }
        }

        let readiness = await EvaRuntimePreparation.ensureReady(runtime: runtime)
        guard readiness.ready else {
            throw EvaProviderError.unavailable(String(localized: "Offline EVA is not ready on this device."))
        }
        let thread = Thread()
        thread.messages = [Message(role: .user, content: prompt, thread: thread)]
        let output = await LLMRuntimeCoordinator.shared.evaluator.generate(
            modelName: readiness.resolvedModelName,
            thread: thread,
            systemPrompt: "Use only the content explicitly supplied in this request. Do not invent facts.",
            profile: profile,
            turnRuntime: runtime
        )
        guard output.hasPrefix("Failed:") == false else {
            throw EvaProviderError.unavailable(output)
        }
        return output
    }

    private static func surface(for route: EvaCloudRoute) -> EvaSurface {
        switch route {
        case .knowledgeAnswer: .knowledge
        case .journalAnswer: .journal
        default: .background
        }
    }
}
