import Foundation
import MLXLMCommon

/// How much context a single EVA turn may carry.
///
/// This is the one place a budget is produced, and it exists because the two
/// runtimes are not comparable. Offline EVA runs a 0.6B–1.7B model on a phone
/// under thermal and memory pressure; its per-model `LLMTokenBudget` is correct
/// for it and is reproduced here untouched. Cloud EVA runs a frontier model
/// behind a Worker that already publishes, per route, exactly how much input it
/// will accept — `RoutePolicy.inputTokenCap`, 16 K for chat and 32 K for plan.
///
/// Before this type existed the cloud path silently inherited the offline
/// ceiling: a cloud-only account has no installed model, so the chat view fell
/// back to `ModelConfiguration.defaultModel` and capped a frontier model at
/// 1,536 input tokens, 360 of them for task context, over an 8-message window.
/// The published caps were decoded from the signed configuration and never read.
///
/// **Fails closed to the offline budget.** A missing signed configuration, a
/// disabled route, a revoked consent, an exhausted balance, or an unrecognized
/// provider all yield the small budget. Growing the prompt is only ever the
/// result of a positive, current confirmation that the request is cloud-bound —
/// handing a cloud-sized envelope to an on-device model is the one failure mode
/// that would exhaust memory on a phone.
struct EvaContextBudget: Sendable, Equatable {
    enum Provider: Sendable, Equatable {
        case cloud
        case offline
    }

    let provider: Provider
    let inputTokens: Int
    let reservedOutputTokens: Int
    let systemPromptTokens: Int
    let personalMemoryTokens: Int
    let executiveContextTokens: Int
    let taskContextTokens: Int
    let slashContextTokens: Int
    /// Offline clips history by message count. Cloud clips by tokens, because a
    /// fixed message count is a meaningless unit against a 16 K window.
    let historyMessageLimit: Int

    var isCloud: Bool { provider == .cloud }

    /// Section budgets are expressed in tokens; the projection builders measure
    /// characters.
    var taskContextCharacters: Int {
        LLMTokenBudgetEstimator.estimatedCharacterBudget(for: taskContextTokens)
    }

    var personalMemoryCharacters: Int {
        LLMTokenBudgetEstimator.estimatedCharacterBudget(for: personalMemoryTokens)
    }

    var executiveContextCharacters: Int {
        LLMTokenBudgetEstimator.estimatedCharacterBudget(for: executiveContextTokens)
    }

    /// The offline budget for a specific local model — today's behavior, verbatim.
    static func offline(model: ModelConfiguration) -> EvaContextBudget {
        let budget = model.tokenBudget
        return EvaContextBudget(
            provider: .offline,
            inputTokens: budget.inputTokens,
            reservedOutputTokens: budget.reservedOutputTokens,
            systemPromptTokens: budget.systemPromptTokens,
            personalMemoryTokens: budget.personalMemoryTokens,
            executiveContextTokens: budget.executiveContextTokens,
            taskContextTokens: budget.taskContextTokens,
            slashContextTokens: budget.slashContextTokens,
            historyMessageLimit: budget.historyMessageLimit
        )
    }

    /// Splits a route's published input cap across the sections of a turn.
    ///
    /// The shares are deliberately lopsided. Planning context is the section
    /// that changes answer quality, so it takes the majority; the persona and
    /// slash pins are near-fixed costs; history gets whatever is left, which is
    /// why it is clipped by tokens rather than by a message count.
    static func cloud(inputTokenCap: Int, outputTokenCap: Int) -> EvaContextBudget {
        let cap = max(1_024, inputTokenCap)
        return EvaContextBudget(
            provider: .cloud,
            inputTokens: cap,
            reservedOutputTokens: max(256, outputTokenCap),
            systemPromptTokens: min(1_200, cap / 8),
            personalMemoryTokens: min(1_500, cap / 8),
            executiveContextTokens: min(1_500, cap / 8),
            taskContextTokens: cap / 2,
            slashContextTokens: min(1_500, cap / 8),
            historyMessageLimit: 64
        )
    }

    /// Resolves the budget for one turn.
    ///
    /// `runtimeConfiguration` is the *verified* signed policy; passing nil is the
    /// honest representation of "we could not confirm what the server allows",
    /// and it deliberately produces the offline budget.
    static func resolve(
        route: EvaCloudRoute,
        modelName: String?,
        offlineModel: ModelConfiguration,
        runtimeConfiguration: EvaCloudRuntimeConfiguration?,
        cloudIsReady: Bool
    ) -> EvaContextBudget {
        guard EvaModelSelection.isCloud(modelName),
              cloudIsReady,
              let configuration = runtimeConfiguration,
              configuration.cloudState != .disabled,
              let policy = configuration.routes[route],
              policy.enabled else {
            return .offline(model: offlineModel)
        }
        return .cloud(inputTokenCap: policy.inputTokenCap, outputTokenCap: policy.outputTokenCap)
    }

    /// The budget for one chat turn, read from live cloud state.
    ///
    /// Call this *before* building the context, not after preparing the model.
    /// The provider decides how large the envelope may be, so discovering it
    /// later would size the projection against the wrong runtime — and on a
    /// fallback turn that would hand a cloud-sized payload to an on-device model.
    @MainActor
    static func resolveForChat(
        route: EvaCloudRoute = .chat,
        currentModelName: String?,
        offlineModel: ModelConfiguration
    ) -> EvaContextBudget {
        resolve(
            route: route,
            modelName: EvaModelSelection.resolve(currentModelName, route: route),
            offlineModel: offlineModel,
            runtimeConfiguration: EvaCloudAccountState.shared.configuration,
            cloudIsReady: EvaCloudAccountState.shared.canUseCloud(route: route)
        )
    }
}
