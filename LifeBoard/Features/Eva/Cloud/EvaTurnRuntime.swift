import Foundation
import MLXLMCommon

/// Immutable routing, consent, policy, and budget facts for one EVA turn.
/// Resolve this before context assembly and pass the same value through request
/// creation and output persistence; no downstream stage may pick a provider.
struct EvaTurnRuntime: Sendable {
    enum Provider: String, Codable, Equatable, Sendable {
        case cloud
        case offline
    }

    enum ContextRenderMode: Sendable {
        case richCloud
        case compactOffline
    }

    enum OutputProcessingPolicy: Sendable {
        case cloudValidated
        case mlxSanitized
    }

    struct TimeoutPolicy: Sendable, Equatable {
        let firstByteSeconds: TimeInterval
        let inactivitySeconds: TimeInterval
        let resourceSeconds: TimeInterval
    }

    let provider: Provider
    let modelName: String
    let route: EvaCloudRoute
    let configurationVersion: Int?
    let contractVersion: Int
    let consentRevision: Int?
    let grants: Set<EvaConsentPolicy.Grant>
    let creditReady: Bool
    let contextBudget: EvaContextBudget
    let contextRenderMode: ContextRenderMode
    let outputProcessingPolicy: OutputProcessingPolicy
    let timeoutPolicy: TimeoutPolicy

    var usesCloud: Bool { provider == .cloud }

    @MainActor
    static func resolve(
        localModelName: String?,
        offlineModel: ModelConfiguration,
        route: EvaCloudRoute = .chat,
        defaults: UserDefaults = .standard
    ) throws -> EvaTurnRuntime {
        switch EvaProviderRouter.Preference.resolvedStoredPreference(defaults: defaults) {
        case .cloud, .automatic:
            let account = EvaCloudAccountState.shared
            if let error = account.readinessError(route: route) { throw error }
            guard let configuration = account.configuration,
                  let policy = configuration.routes[route],
                  policy.enabled,
                  let consent = account.consent else {
                throw EvaProviderError.unavailable(String(localized: "Cloud EVA configuration is not ready."))
            }
            let creditReady = policy.billable == false || (account.quota?.remaining ?? account.credits?.balance ?? 0) > 0
            guard creditReady else { throw EvaProviderError.creditsExhausted(account.credits) }
            return EvaTurnRuntime(
                provider: .cloud,
                modelName: EvaModelSelection.cloudSentinel,
                route: route,
                configurationVersion: configuration.version,
                contractVersion: EvaInferenceRequest.negotiatedContractVersion(
                    advertised: configuration.contractVersions
                ),
                consentRevision: consent.revision,
                grants: Set(consent.grants),
                creditReady: creditReady,
                contextBudget: .cloud(
                    inputTokenCap: policy.inputTokenCap,
                    outputTokenCap: policy.outputTokenCap
                ),
                contextRenderMode: .richCloud,
                outputProcessingPolicy: .cloudValidated,
                timeoutPolicy: .init(firstByteSeconds: 20, inactivitySeconds: 25, resourceSeconds: 75)
            )
        case .offline:
            guard let localModelName,
                  let model = ModelConfiguration.getModelByName(localModelName) else {
                throw EvaProviderError.unavailable(
                    String(localized: "Install an Offline EVA model in Settings before selecting Offline EVA.")
                )
            }
            return EvaTurnRuntime(
                provider: .offline,
                modelName: localModelName,
                route: route,
                configurationVersion: nil,
                contractVersion: 0,
                consentRevision: nil,
                grants: [],
                creditReady: true,
                contextBudget: .offline(model: model),
                contextRenderMode: .compactOffline,
                outputProcessingPolicy: .mlxSanitized,
                timeoutPolicy: .init(firstByteSeconds: 0, inactivitySeconds: 0, resourceSeconds: 0)
            )
        }
    }

    @MainActor
    static func resolveChat(
        localModelName: String?,
        offlineModel: ModelConfiguration,
        reportFailure: (String) -> Void
    ) -> EvaTurnRuntime? {
        do {
            return try resolve(localModelName: localModelName, offlineModel: offlineModel)
        } catch {
            reportFailure(error.localizedDescription)
            return nil
        }
    }

    /// Consent and signed policy are request authority. If either changes while
    /// context is being assembled, fail the turn and resolve a new snapshot.
    @MainActor
    func validateCurrentAuthority() throws {
        guard usesCloud else { return }
        let account = EvaCloudAccountState.shared
        guard account.configuration?.version == configurationVersion,
              account.consent?.revision == consentRevision,
              account.consent.map({ Set($0.grants) }) == grants else {
            throw EvaProviderError.unavailable(
                String(localized: "EVA privacy or routing settings changed. Please send this message again.")
            )
        }
        if let error = account.readinessError(route: route) { throw error }
    }

    func contextSections(
        compactProjection: String,
        executiveState: String?,
        slashCommandState: String?,
        personalMemory: String?,
        evidence: EvaAuthorizedEvidenceContext,
        userQuery: String
    ) async -> [EvaCloudContextSection] {
        guard contextRenderMode == .richCloud else { return [] }
        let consent = EvaConsentPolicy(
            schemaVersion: 1,
            revision: consentRevision ?? 0,
            grants: Array(grants),
            updatedAt: .distantPast
        )
        let habitSignals = await EvaHabitContextResolver.today()
        let sections = await EvaTurnContextAssembler.sections(
            budget: contextBudget,
            compactProjection: compactProjection,
            executiveState: executiveState,
            slashCommandState: slashCommandState,
            personalMemory: personalMemory,
            habitSignals: habitSignals,
            evidence: evidence,
            consent: consent,
            route: route,
            userQuery: userQuery
        )
        let exclusions = EvaContextExclusionStore.load()
        return sections.map { exclusions.filtering($0.forContract(contractVersion)) }
    }

    /// Adds the route's adaptive baseline around any caller-supplied section.
    /// Explicit context wins per category (for example a planner's exact task
    /// roster or Journal's already-authorized evidence), while the shared path
    /// contributes capacity, calendar, goals, and habits where the route allows.
    func enrichedContextSections(
        explicit: [EvaCloudContextSection],
        userQuery: String
    ) async -> [EvaCloudContextSection] {
        let adaptive = await contextSections(
            compactProjection: "",
            executiveState: nil,
            slashCommandState: nil,
            personalMemory: nil,
            evidence: .notProvided,
            userQuery: userQuery
        )
        var byCategory = Dictionary(uniqueKeysWithValues: adaptive.map { ($0.category, $0) })
        let exclusions = EvaContextExclusionStore.load()
        for section in explicit {
            byCategory[section.category] = exclusions.filtering(section.forContract(contractVersion))
        }
        return EvaContextEnvelope(sections: Array(byCategory.values)).ordered()
    }

    func cloudDisplayText(from output: String) -> String? {
        guard outputProcessingPolicy == .cloudValidated else { return nil }
        let normalized = EvaCloudOutputNormalizer.normalize(output)
        return normalized.hasPrefix("Failed:")
            ? String(normalized.dropFirst("Failed:".count)).trimmingCharacters(in: .whitespaces)
            : normalized
    }
}

private enum EvaHabitContextResolver {
    static func today(now: Date = Date()) async -> [LifeBoardHabitSignal] {
        guard let repository = LLMContextRepositoryFactory.habitRuntimeReadRepository else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return await withCheckedContinuation { continuation in
            repository.fetchSignals(start: start, end: end) { result in
                continuation.resume(returning: ((try? result.get()) ?? []).map {
                    LifeBoardHabitSignal(summary: $0, referenceDate: now)
                })
            }
        }
    }
}

enum EvaCloudOutputNormalizer {
    static func normalize(_ output: String) -> String {
        output
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
enum EvaCloudChatOutputDelivery {
    static func deliver(
        output: String,
        runtime: EvaTurnRuntime,
        isCurrent: Bool,
        send: (String, String?) -> Void
    ) -> Bool {
        guard runtime.outputProcessingPolicy == .cloudValidated else { return false }
        guard isCurrent else { return true }
        let text = runtime.cloudDisplayText(from: output)
        let usableText = text.flatMap { $0.isEmpty ? nil : $0 }
        send(
            usableText ?? String(localized: "Cloud EVA returned an empty response. Please try again."),
            usableText == nil ? nil : runtime.modelName
        )
        return true
    }
}
