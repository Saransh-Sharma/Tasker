import Foundation
import MLXLMCommon
import UIKit

@MainActor
final class LLMRuntimeCoordinator {
    struct EnsureReadyResult {
        let prewarmEligible: Bool
        let prewarmHit: Bool
        let ready: Bool
        let resolvedModelName: String
        let failureMessage: String?
    }

    typealias PrepareHandler = @MainActor (String) async throws -> LLMEvaluator.PrepareResult
    typealias SwitchHandler = @MainActor (String) async throws -> Bool
    typealias UnloadHandler = @MainActor (String) async -> Void
    typealias CompatibilityProvider = @MainActor (String) -> LLMModelCompatibilityResult?

    @MainActor static let shared = LLMRuntimeCoordinator()

    let evaluator: LLMEvaluator

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let prepareHandler: PrepareHandler
    private let switchHandler: SwitchHandler
    private let unloadHandler: UnloadHandler
    private let compatibilityProvider: CompatibilityProvider
    private let backgroundUnloadDelayNanoseconds: UInt64
    private let idleUnloadDelayNanoseconds: UInt64

    private var observers: [NSObjectProtocol] = []
    private var inFlightPrewarmTask: Task<Void, Never>?
    private var inFlightPrewarmModelName: String?
    private var deferredPrewarmTask: Task<Void, Never>?
    private var deferredPrewarmRequestKey: String?
    private var backgroundUnloadTask: Task<Void, Never>?
    private var idleUnloadTask: Task<Void, Never>?
    private var activeSessionReasons: Set<String> = []

    private(set) var activeModelName: String?

    init(
        evaluator: LLMEvaluator? = nil,
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        prepareHandler: PrepareHandler? = nil,
        switchHandler: SwitchHandler? = nil,
        unloadHandler: UnloadHandler? = nil,
        compatibilityProvider: CompatibilityProvider? = nil,
        backgroundUnloadDelayNanoseconds: UInt64 = 5 * 60 * 1_000_000_000,
        idleUnloadDelayNanoseconds: UInt64 = 20 * 1_000_000_000,
        registerLifecycleObservers: Bool = true
    ) {
        let runtimeEvaluator = evaluator ?? LLMEvaluator()
        self.evaluator = runtimeEvaluator
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.prepareHandler = prepareHandler ?? { modelName in
            try await runtimeEvaluator.prepare(modelName: modelName)
        }
        self.switchHandler = switchHandler ?? { modelName in
            guard let model = ModelConfiguration.getModelByName(modelName) else {
                return false
            }
            await runtimeEvaluator.switchModel(model)
            return true
        }
        self.unloadHandler = unloadHandler ?? { _ in
            await runtimeEvaluator.unloadNow()
        }
        self.compatibilityProvider = compatibilityProvider ?? { modelName in
            LLMRuntimeSupportMatrix.compatibility(for: modelName)
        }
        self.backgroundUnloadDelayNanoseconds = backgroundUnloadDelayNanoseconds
        self.idleUnloadDelayNanoseconds = idleUnloadDelayNanoseconds

        if registerLifecycleObservers {
            installLifecycleObservers()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            for observer in observers {
                notificationCenter.removeObserver(observer)
            }
            inFlightPrewarmTask?.cancel()
            deferredPrewarmTask?.cancel()
            backgroundUnloadTask?.cancel()
            idleUnloadTask?.cancel()
        }
    }

    func enterChatScreen(trigger: String) {
        acquireSession(reason: "chat_host_visible")
        TaskerMemoryDiagnostics.checkpoint(
            event: "llm_chat_entry",
            message: "Entering chat surface",
            fields: ["trigger": trigger]
        )
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            Task {
                await appDelegate.activateSemanticRetrievalIfNeeded(trigger: trigger)
            }
        }
        requestChatEntryPrewarm(trigger: trigger, delaySeconds: 0)
    }

    func primeSelectedModelForChatEntry(trigger: String = "chat_entry") async {
        guard V2FeatureFlags.llmChatPrewarmMode != .disabled else { return }
        guard let modelName = normalizedCurrentModelName(), !modelName.isEmpty else { return }
        guard let model = ModelConfiguration.getModelByName(modelName) else { return }
        guard compatibilityProvider(model.name)?.canActivate == true else {
            logWarning(
                event: "chat_prewarm_skipped_unsupported_model",
                message: "Skipped model prewarm because the selected model is unsupported by the current runtime",
                fields: ["model_name": modelName, "trigger": trigger]
            )
            return
        }
        guard canPrimeOnChatEntry(model: model) else { return }
        guard evaluator.loadedModelName != modelName else {
            activeModelName = modelName
            return
        }

        let requestKey = "\(modelName)|\(trigger)"
        if inFlightPrewarmModelName == modelName {
            return
        }

        cancelIdleUnload()
        cancelBackgroundUnload()
        startPrewarm(modelName: modelName, trigger: trigger, requestKey: requestKey)
    }

    func exitChatScreen(reason: String) async {
        cancelDeferredPrewarm(reason: "exit_\(reason)")
        cancelBackgroundUnload()
        cancelIdleUnload()
        activeSessionReasons.removeAll()
        cancelGenerationIfActive(reason: reason)
        cancelInFlightPrewarm(reason: "exit_\(reason)")
        await unload(reason: reason)
    }

    func prewarmIfEligibleCurrentModel(trigger: String = "unknown") async {
        guard V2FeatureFlags.llmChatPrewarmMode != .disabled else { return }
        guard let currentModelName = normalizedCurrentModelName(), !currentModelName.isEmpty else { return }
        guard let model = ModelConfiguration.getModelByName(currentModelName) else { return }
        guard compatibilityProvider(model.name)?.canActivate == true else {
            logWarning(
                event: "chat_prewarm_skipped_unsupported_model",
                message: "Skipped current model prewarm because the runtime does not support it",
                fields: ["model_name": currentModelName, "trigger": trigger]
            )
            return
        }
        guard canPrimeOnChatEntry(model: model) else { return }
        guard evaluator.loadedModelName != currentModelName, activeModelName != currentModelName else {
            activeModelName = currentModelName
            return
        }

        cancelIdleUnload()
        startPrewarm(
            modelName: currentModelName,
            trigger: trigger,
            requestKey: "\(currentModelName)|\(trigger)"
        )
    }

    func requestChatEntryPrewarm(trigger: String, delaySeconds: TimeInterval = 0.5) {
        guard V2FeatureFlags.llmChatPrewarmMode != .disabled else { return }
        guard let modelName = normalizedCurrentModelName(), !modelName.isEmpty else { return }

        let requestKey = "\(modelName)|\(trigger)"
        if deferredPrewarmRequestKey == requestKey || inFlightPrewarmModelName == modelName {
            return
        }

        cancelDeferredPrewarm(reason: "chat_entry_rescheduled")
        cancelIdleUnload()

        if delaySeconds <= 0 {
            deferredPrewarmRequestKey = requestKey
            deferredPrewarmTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                guard self.deferredPrewarmRequestKey == requestKey else { return }
                self.deferredPrewarmRequestKey = nil
                self.deferredPrewarmTask = nil
                await self.primeSelectedModelForChatEntry(trigger: trigger)
            }
            return
        }

        let delayNanoseconds = UInt64(max(0, delaySeconds) * 1_000_000_000)
        deferredPrewarmRequestKey = requestKey
        deferredPrewarmTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                self.deferredPrewarmTask = nil
                return
            }
            guard !Task.isCancelled else { return }
            guard self.deferredPrewarmRequestKey == requestKey else { return }
            self.deferredPrewarmRequestKey = nil
            self.deferredPrewarmTask = nil
            await self.primeSelectedModelForChatEntry(trigger: trigger)
        }
    }

    func cancelDeferredPrewarm(reason: String) {
        guard deferredPrewarmTask != nil else { return }
        deferredPrewarmTask?.cancel()
        deferredPrewarmTask = nil
        deferredPrewarmRequestKey = nil
        logWarning(
            event: "llm_prewarm_cancelled",
            message: "Cancelled deferred LLM chat prewarm",
            fields: ["reason": reason]
        )
    }

    func prepareCurrentModelIfConfigured(trigger: String) async {
        guard let currentModelName = normalizedCurrentModelName(), !currentModelName.isEmpty else { return }
        guard V2FeatureFlags.llmChatPrewarmMode != .disabled else { return }

        let startedAt = Date()
        let result = await ensureReady(modelName: currentModelName)
        logWarning(
            event: "chat_prepare_current_model_completed",
            message: "Prepared configured chat model",
            fields: [
                "model_name": currentModelName,
                "ready": result.ready ? "true" : "false",
                "duration_ms": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
                "trigger": trigger
            ]
        )
    }

    func acquireSession(reason: String) {
        let inserted = activeSessionReasons.insert(reason).inserted
        cancelBackgroundUnload()
        cancelIdleUnload()
        if inserted {
            logWarning(
                event: "chat_session_acquired",
                message: "Acquired active chat runtime session",
                fields: [
                    "reason": reason,
                    "session_count": String(activeSessionReasons.count)
                ]
            )
        }
    }

    private func normalizedCurrentModelName() -> String? {
        LLMPersistedModelSelection.normalize(defaults: defaults).currentModelName
    }

    func releaseSession(reason: String) {
        let removed = activeSessionReasons.remove(reason) != nil
        guard removed else { return }
        logWarning(
            event: "chat_session_released",
            message: "Released active chat runtime session",
            fields: [
                "reason": reason,
                "session_count": String(activeSessionReasons.count)
            ]
        )
        guard activeSessionReasons.isEmpty else { return }
        scheduleIdleUnload(after: TimeInterval(idleUnloadDelayNanoseconds) / 1_000_000_000)
    }

    func cancelGenerationIfActive(reason: String) {
        let shouldCancelEvaluator = evaluator.running ||
            evaluator.runtimePhase == .preparing ||
            evaluator.runtimePhase == .thinking ||
            evaluator.runtimePhase == .answering ||
            evaluator.runtimePhase == .stopping
        if shouldCancelEvaluator {
            evaluator.cancelGeneration(reason: reason)
        }

        if activeSessionReasons.remove("chat_generation") != nil {
            logWarning(
                event: "chat_generation_session_forced_release",
                message: "Force-released chat generation session during runtime cancellation",
                fields: [
                    "reason": reason,
                    "session_count": String(activeSessionReasons.count)
                ]
            )
            if activeSessionReasons.isEmpty {
                scheduleIdleUnload(after: TimeInterval(idleUnloadDelayNanoseconds) / 1_000_000_000)
            }
        }
    }

    func scheduleIdleUnload(after seconds: TimeInterval) {
        guard activeSessionReasons.isEmpty else { return }
        guard evaluator.loadedModelName != nil || activeModelName != nil else { return }
        cancelIdleUnload()

        let clampedDelay = max(0, seconds)
        let delayNanoseconds = UInt64(clampedDelay * 1_000_000_000)
        if delayNanoseconds == 0 {
            Task { @MainActor in
                await self.unload(reason: "idle_timeout")
            }
            return
        }

        idleUnloadTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard self.activeSessionReasons.isEmpty else { return }
            self.cancelGenerationIfActive(reason: "idle_timeout")
            await self.unload(reason: "idle_timeout")
        }
        logWarning(
            event: "chat_idle_unload_scheduled",
            message: "Scheduled idle unload for chat runtime",
            fields: ["delay_seconds": String(format: "%.1f", clampedDelay)]
        )
    }

    func ensureReady(modelName: String) async -> EnsureReadyResult {
        cancelIdleUnload()
        guard let compatibility = compatibilityProvider(modelName) else {
            return EnsureReadyResult(
                prewarmEligible: false,
                prewarmHit: false,
                ready: false,
                resolvedModelName: modelName,
                failureMessage: nil
            )
        }
        guard compatibility.canActivate else {
            logWarning(
                event: "chat_model_prepare_skipped_unsupported_runtime",
                message: "Skipped model prepare because the current runtime does not support the selected catalog entry",
                fields: [
                    "model_name": modelName,
                    "reason": compatibility.statusReason ?? "unsupported_runtime"
                ]
            )
            if let fallbackModelName = preferredFallbackModelName(afterPrepareFailureFor: modelName),
               fallbackModelName != modelName {
                do {
                    _ = try await prepareHandler(fallbackModelName)
                    activeModelName = fallbackModelName
                    defaults.set(fallbackModelName, forKey: LLMPersistedModelSelection.currentModelKey)
                    logWarning(
                        event: "chat_model_prepare_fallback_succeeded",
                        message: "Prepared fallback local model after selected model was unsupported",
                        fields: [
                            "failed_model_name": modelName,
                            "fallback_model_name": fallbackModelName
                        ]
                    )
                    return EnsureReadyResult(
                        prewarmEligible: ModelConfiguration.getModelByName(fallbackModelName).map { canPrimeOnChatEntry(model: $0) } ?? false,
                        prewarmHit: evaluator.loadedModelName == fallbackModelName,
                        ready: true,
                        resolvedModelName: fallbackModelName,
                        failureMessage: nil
                    )
                } catch {
                    logError(
                        event: "chat_model_prepare_fallback_failed",
                        message: "Failed to prepare fallback local model after selected model was unsupported",
                        fields: [
                            "failed_model_name": modelName,
                            "fallback_model_name": fallbackModelName,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
            return EnsureReadyResult(
                prewarmEligible: false,
                prewarmHit: false,
                ready: false,
                resolvedModelName: modelName,
                failureMessage: compatibility.prepareFailureMessage
            )
        }
        let prewarmEligible = ModelConfiguration.getModelByName(modelName).map { model in
            canPrimeOnChatEntry(model: model)
        } ?? false
        let prewarmHit = evaluator.loadedModelName == modelName

        if let inFlightPrewarmTask, inFlightPrewarmModelName == modelName {
            await inFlightPrewarmTask.value
            return EnsureReadyResult(
                prewarmEligible: prewarmEligible,
                prewarmHit: prewarmHit,
                ready: evaluator.loadedModelName == modelName || activeModelName == modelName,
                resolvedModelName: modelName,
                failureMessage: nil
            )
        }

        if inFlightPrewarmModelName != nil && inFlightPrewarmModelName != modelName {
            cancelInFlightPrewarm(reason: "ensure_ready_switch")
        }

        do {
            _ = try await prepareHandler(modelName)
            activeModelName = modelName
            return EnsureReadyResult(
                prewarmEligible: prewarmEligible,
                prewarmHit: prewarmHit,
                ready: true,
                resolvedModelName: modelName,
                failureMessage: nil
            )
        } catch {
            logError(
                event: "chat_model_prepare_failed",
                message: "Failed to prepare selected model before generation",
                fields: [
                    "model_name": modelName,
                    "error": error.localizedDescription
                ]
            )
            if let fallbackModelName = preferredFallbackModelName(afterPrepareFailureFor: modelName),
               fallbackModelName != modelName {
                do {
                    _ = try await prepareHandler(fallbackModelName)
                    activeModelName = fallbackModelName
                    defaults.set(fallbackModelName, forKey: LLMPersistedModelSelection.currentModelKey)
                    logWarning(
                        event: "chat_model_prepare_fallback_succeeded",
                        message: "Prepared fallback local model after selected model failed to load",
                        fields: [
                            "failed_model_name": modelName,
                            "fallback_model_name": fallbackModelName
                        ]
                    )
                    return EnsureReadyResult(
                        prewarmEligible: ModelConfiguration.getModelByName(fallbackModelName).map { canPrimeOnChatEntry(model: $0) } ?? false,
                        prewarmHit: evaluator.loadedModelName == fallbackModelName,
                        ready: true,
                        resolvedModelName: fallbackModelName,
                        failureMessage: nil
                    )
                } catch {
                    logError(
                        event: "chat_model_prepare_fallback_failed",
                        message: "Failed to prepare fallback local model after selected model failed",
                        fields: [
                            "failed_model_name": modelName,
                            "fallback_model_name": fallbackModelName,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
            return EnsureReadyResult(
                prewarmEligible: prewarmEligible,
                prewarmHit: prewarmHit,
                ready: false,
                resolvedModelName: modelName,
                failureMessage: failureMessage(for: error)
            )
        }
    }

    func switchModelIfNeeded(modelName: String) async -> Bool {
        cancelIdleUnload()
        guard let compatibility = compatibilityProvider(modelName), compatibility.canActivate else {
            logWarning(
                event: "chat_model_switch_skipped_unsupported_runtime",
                message: "Skipped model switch because the current runtime does not support the selected catalog entry",
                fields: [
                    "model_name": modelName,
                    "reason": compatibilityProvider(modelName)?.statusReason ?? "unknown_compatibility"
                ]
            )
            return false
        }
        if evaluator.loadedModelName == modelName {
            activeModelName = modelName
            return true
        }

        if inFlightPrewarmModelName != nil && inFlightPrewarmModelName != modelName {
            cancelInFlightPrewarm(reason: "switch_model")
        }

        do {
            let switched = try await switchHandler(modelName)
            if switched {
                activeModelName = modelName
            }
            return switched
        } catch {
            logError(
                event: "chat_model_switch_failed",
                message: "Failed to switch active model in runtime coordinator",
                fields: [
                    "model_name": modelName,
                    "error": error.localizedDescription
                ]
            )
            return false
        }
    }

    func unload(reason: String) async {
        cancelDeferredPrewarm(reason: "unload_\(reason)")
        cancelInFlightPrewarm(reason: "unload_\(reason)")
        cancelBackgroundUnload()
        cancelIdleUnload()
        await unloadHandler(reason)
        activeModelName = nil
        TaskerMemoryDiagnostics.checkpoint(
            event: "llm_runtime_unloaded",
            message: "Unloaded LLM runtime resources",
            fields: ["reason": reason]
        )
        logWarning(
            event: "chat_model_unloaded",
            message: "Unloaded chat model from runtime coordinator",
            fields: ["reason": reason]
        )
    }

    private func installLifecycleObservers() {
        let memoryWarningObserver = notificationCenter.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.unload(reason: "memory_warning")
            }
        }
        observers.append(memoryWarningObserver)

        let thermalObserver = notificationCenter.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleThermalStateChange()
            }
        }
        observers.append(thermalObserver)

        let backgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleBackgroundUnload()
            }
        }
        observers.append(backgroundObserver)

        let foregroundObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancelBackgroundUnload()
            }
        }
        observers.append(foregroundObserver)
    }

    private func startPrewarm(modelName: String, trigger: String, requestKey: String) {
        guard evaluator.loadedModelName != modelName else {
            activeModelName = modelName
            return
        }

        if inFlightPrewarmModelName == modelName {
            return
        }

        cancelInFlightPrewarm(reason: "prewarm_rescheduled")
        inFlightPrewarmModelName = modelName
        inFlightPrewarmTask = Task { @MainActor in
            let startedAt = Date()
            defer {
                if self.inFlightPrewarmModelName == modelName {
                    self.inFlightPrewarmModelName = nil
                    self.inFlightPrewarmTask = nil
                }
            }

            do {
                _ = try await self.prepareHandler(modelName)
                self.activeModelName = modelName
                logWarning(
                    event: "chat_prewarm_completed",
                    message: "Completed model prewarm for chat",
                    fields: [
                        "model_name": modelName,
                        "duration_ms": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
                        "trigger": trigger,
                        "request_key": requestKey
                    ]
                )
            } catch is CancellationError {
                logWarning(
                    event: "chat_prewarm_cancelled",
                    message: "Cancelled in-flight prewarm due to newer model request",
                    fields: [
                        "model_name": modelName,
                        "trigger": trigger,
                        "request_key": requestKey
                    ]
                )
            } catch {
                logError(
                    event: "chat_prewarm_failed",
                    message: "Model prewarm failed",
                    fields: [
                        "model_name": modelName,
                        "error": error.localizedDescription,
                        "trigger": trigger,
                        "request_key": requestKey
                    ]
                )
            }
        }
    }

    private func cancelInFlightPrewarm(reason: String) {
        guard inFlightPrewarmTask != nil else { return }
        inFlightPrewarmTask?.cancel()
        inFlightPrewarmTask = nil
        inFlightPrewarmModelName = nil
        logWarning(
            event: "chat_prewarm_cancelled",
            message: "Cancelled in-flight chat prewarm",
            fields: ["reason": reason]
        )
    }

    private func handleThermalStateChange() async {
        switch ProcessInfo.processInfo.thermalState {
        case .serious:
            await unload(reason: "thermal_serious")
        case .critical:
            await unload(reason: "thermal_critical")
        default:
            break
        }
    }

    private func scheduleBackgroundUnload() {
        backgroundUnloadTask?.cancel()
        cancelIdleUnload()
        cancelDeferredPrewarm(reason: "app_backgrounded")
        backgroundUnloadTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: backgroundUnloadDelayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self.unload(reason: "background_timeout")
        }
    }

    private func cancelBackgroundUnload() {
        backgroundUnloadTask?.cancel()
        backgroundUnloadTask = nil
    }

    private func cancelIdleUnload() {
        idleUnloadTask?.cancel()
        idleUnloadTask = nil
    }

    private func canPrimeOnChatEntry(model: ModelConfiguration) -> Bool {
        guard compatibilityProvider(model.name)?.canActivate == true else {
            return false
        }
        guard isThermalStateBelowSerious(ProcessInfo.processInfo.thermalState) else {
            return false
        }
        guard let modelSize = model.modelSize else {
            return false
        }
        // Avoid prewarming when more than two independent sessions already hold runtime state.
        if activeSessionReasons.count > 2 {
            return false
        }
        let physicalMemoryGB = Decimal(Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)
        // OptiQ models have lower memory overhead, so they can use a slightly larger share of RAM.
        let budgetMultiplier = model == .qwen_3_5_0_8b_optiq_4bit ? Decimal(string: "0.7")! : Decimal(string: "0.6")!
        let budget = physicalMemoryGB * budgetMultiplier
        return modelSize <= budget
    }

    private func isThermalStateBelowSerious(_ thermalState: ProcessInfo.ThermalState) -> Bool {
        switch thermalState {
        case .nominal, .fair:
            return true
        case .serious, .critical:
            return false
        @unknown default:
            return false
        }
    }

    private func preferredFallbackModelName(afterPrepareFailureFor modelName: String) -> String? {
        let normalizedState = LLMPersistedModelSelection.normalize(defaults: defaults)
        let installedSet = Set(normalizedState.installedModels)
        let defaultModelName = ModelConfiguration.defaultModel.name
        guard modelName != defaultModelName else { return nil }
        guard installedSet.contains(defaultModelName) else { return nil }
        guard compatibilityProvider(defaultModelName)?.canActivate == true else {
            return nil
        }
        return defaultModelName
    }

    private func failureMessage(for error: Error) -> String? {
        if case let LLMEvaluatorError.unsupportedRuntime(_, message) = error {
            return message
        }
        return "Model failed to prepare. Please switch models or retry."
    }
}
