import Foundation
import MLXLMCommon
import UIKit

@MainActor
final class LLMRuntimeCoordinator {
    struct EnsureReadyResult {
        let prewarmEligible: Bool
        let prewarmHit: Bool
        let ready: Bool
    }

    typealias PrepareHandler = @MainActor (String) async throws -> LLMEvaluator.PrepareResult
    typealias SwitchHandler = @MainActor (String) async throws -> Bool
    typealias UnloadHandler = @MainActor () -> Void

    @MainActor static let shared = LLMRuntimeCoordinator()

    let evaluator: LLMEvaluator

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let prepareHandler: PrepareHandler
    private let switchHandler: SwitchHandler
    private let unloadHandler: UnloadHandler
    private let backgroundUnloadDelayNanoseconds: UInt64
    private let idleUnloadDelayNanoseconds: UInt64
    private let currentModelKey = "currentModelName"
    private var observers: [NSObjectProtocol] = []
    private var inFlightPrewarmTask: Task<Void, Never>?
    private var inFlightPrewarmModelName: String?
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
        self.unloadHandler = unloadHandler ?? {
            runtimeEvaluator.unload()
        }
        self.backgroundUnloadDelayNanoseconds = backgroundUnloadDelayNanoseconds
        self.idleUnloadDelayNanoseconds = idleUnloadDelayNanoseconds

        if registerLifecycleObservers {
            self.registerLifecycleObservers()
        }
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        inFlightPrewarmTask?.cancel()
        backgroundUnloadTask?.cancel()
        idleUnloadTask?.cancel()
    }

    func prewarmIfEligibleCurrentModel(trigger: String = "unknown") async {
        guard V2FeatureFlags.llmChatPrewarmMode != .disabled else { return }
        guard let currentModelName = defaults.string(forKey: currentModelKey), !currentModelName.isEmpty else { return }
        guard let model = ModelConfiguration.getModelByName(currentModelName), model.isPrewarmEligible() else { return }
        guard evaluator.loadedModelName != currentModelName else { return }
        guard activeModelName != currentModelName else { return }
        guard inFlightPrewarmModelName != currentModelName else { return }

        cancelIdleUnload()
        inFlightPrewarmTask?.cancel()
        inFlightPrewarmModelName = currentModelName

        inFlightPrewarmTask = Task { @MainActor in
            let startedAt = Date()
            do {
                _ = try await self.prepareHandler(currentModelName)
                self.activeModelName = currentModelName
                logWarning(
                    event: "chat_prewarm_completed",
                    message: "Completed model prewarm for chat",
                    fields: [
                        "model_name": currentModelName,
                        "duration_ms": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
                        "trigger": trigger
                    ]
                )
            } catch is CancellationError {
                logWarning(
                    event: "chat_prewarm_cancelled",
                    message: "Cancelled in-flight prewarm due to newer model request",
                    fields: [
                        "model_name": currentModelName,
                        "trigger": trigger
                    ]
                )
            } catch {
                logError(
                    event: "chat_prewarm_failed",
                    message: "Model prewarm failed",
                    fields: [
                        "model_name": currentModelName,
                        "error": error.localizedDescription,
                        "trigger": trigger
                    ]
                )
            }
            if self.inFlightPrewarmModelName == currentModelName {
                self.inFlightPrewarmModelName = nil
                self.inFlightPrewarmTask = nil
            }
        }
    }

    func prepareCurrentModelIfConfigured(trigger: String) async {
        guard let currentModelName = defaults.string(forKey: currentModelKey),
              currentModelName.isEmpty == false else {
            return
        }
        guard let model = ModelConfiguration.getModelByName(currentModelName) else { return }

        switch V2FeatureFlags.llmChatPrewarmMode {
        case .disabled:
            return
        case .adaptiveOnDemand:
            guard model.isPrewarmEligible() else { return }
            await prewarmIfEligibleCurrentModel(trigger: trigger)
        case .eager:
            let startedAt = Date()
            let result = await ensureReady(modelName: currentModelName)
            logWarning(
                event: "chat_eager_prepare_completed",
                message: "Completed eager model prepare for chat",
                fields: [
                    "model_name": currentModelName,
                    "ready": result.ready ? "true" : "false",
                    "duration_ms": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
                    "trigger": trigger
                ]
            )
        }
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
            unload(reason: "idle_timeout")
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
            self.unload(reason: "idle_timeout")
        }
        logWarning(
            event: "chat_idle_unload_scheduled",
            message: "Scheduled idle unload for chat runtime",
            fields: ["delay_seconds": String(format: "%.1f", clampedDelay)]
        )
    }

    func ensureReady(modelName: String) async -> EnsureReadyResult {
        cancelIdleUnload()
        let prewarmEligible = ModelConfiguration.getModelByName(modelName)?.isPrewarmEligible() ?? false
        let prewarmHit = evaluator.loadedModelName == modelName

        if let inFlightPrewarmTask, inFlightPrewarmModelName == modelName {
            await inFlightPrewarmTask.value
            return EnsureReadyResult(
                prewarmEligible: prewarmEligible,
                prewarmHit: prewarmHit,
                ready: evaluator.loadedModelName == modelName
            )
        }

        if inFlightPrewarmModelName != nil && inFlightPrewarmModelName != modelName {
            inFlightPrewarmTask?.cancel()
            inFlightPrewarmTask = nil
            inFlightPrewarmModelName = nil
        }

        do {
            _ = try await prepareHandler(modelName)
            activeModelName = modelName
            return EnsureReadyResult(prewarmEligible: prewarmEligible, prewarmHit: prewarmHit, ready: true)
        } catch {
            logError(
                event: "chat_model_prepare_failed",
                message: "Failed to prepare selected model before generation",
                fields: [
                    "model_name": modelName,
                    "error": error.localizedDescription
                ]
            )
            return EnsureReadyResult(prewarmEligible: prewarmEligible, prewarmHit: prewarmHit, ready: false)
        }
    }

    func switchModelIfNeeded(modelName: String) async -> Bool {
        cancelIdleUnload()
        if evaluator.loadedModelName == modelName {
            activeModelName = modelName
            return true
        }

        if inFlightPrewarmModelName != nil && inFlightPrewarmModelName != modelName {
            inFlightPrewarmTask?.cancel()
            inFlightPrewarmTask = nil
            inFlightPrewarmModelName = nil
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

    func unload(reason: String) {
        cancelGenerationIfActive(reason: "unload_\(reason)")
        inFlightPrewarmTask?.cancel()
        inFlightPrewarmTask = nil
        inFlightPrewarmModelName = nil
        backgroundUnloadTask?.cancel()
        backgroundUnloadTask = nil
        cancelIdleUnload()
        unloadHandler()
        activeModelName = nil
        logWarning(
            event: "chat_model_unloaded",
            message: "Unloaded chat model from runtime coordinator",
            fields: ["reason": reason]
        )
    }

    private func registerLifecycleObservers() {
        let memoryWarningObserver = notificationCenter.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.unload(reason: "memory_warning")
            }
        }
        observers.append(memoryWarningObserver)

        let thermalObserver = notificationCenter.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
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

    private func handleThermalStateChange() {
        switch ProcessInfo.processInfo.thermalState {
        case .serious:
            unload(reason: "thermal_serious")
        case .critical:
            unload(reason: "thermal_critical")
        default:
            break
        }
    }

    private func scheduleBackgroundUnload() {
        backgroundUnloadTask?.cancel()
        cancelIdleUnload()
        backgroundUnloadTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: backgroundUnloadDelayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self.unload(reason: "background_timeout")
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
}
