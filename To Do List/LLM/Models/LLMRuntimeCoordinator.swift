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
    private let currentModelKey = "currentModelName"
    private var observers: [NSObjectProtocol] = []
    private var inFlightPrewarmTask: Task<Void, Never>?
    private var inFlightPrewarmModelName: String?
    private var backgroundUnloadTask: Task<Void, Never>?
    private(set) var activeModelName: String?

    init(
        evaluator: LLMEvaluator? = nil,
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        prepareHandler: PrepareHandler? = nil,
        switchHandler: SwitchHandler? = nil,
        unloadHandler: UnloadHandler? = nil,
        backgroundUnloadDelayNanoseconds: UInt64 = 5 * 60 * 1_000_000_000,
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
    }

    func prewarmIfEligibleCurrentModel() async {
        guard V2FeatureFlags.llmChatPrewarmEnabled else { return }
        guard let currentModelName = defaults.string(forKey: currentModelKey), !currentModelName.isEmpty else { return }
        guard let model = ModelConfiguration.getModelByName(currentModelName), model.isPrewarmEligible() else { return }
        guard evaluator.loadedModelName != currentModelName else { return }
        guard activeModelName != currentModelName else { return }
        guard inFlightPrewarmModelName != currentModelName else { return }

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
                        "duration_ms": String(Int(Date().timeIntervalSince(startedAt) * 1_000))
                    ]
                )
            } catch is CancellationError {
                logWarning(
                    event: "chat_prewarm_cancelled",
                    message: "Cancelled in-flight prewarm due to newer model request",
                    fields: ["model_name": currentModelName]
                )
            } catch {
                logError(
                    event: "chat_prewarm_failed",
                    message: "Model prewarm failed",
                    fields: [
                        "model_name": currentModelName,
                        "error": error.localizedDescription
                    ]
                )
            }
            if self.inFlightPrewarmModelName == currentModelName {
                self.inFlightPrewarmModelName = nil
                self.inFlightPrewarmTask = nil
            }
        }
    }

    func ensureReady(modelName: String) async -> EnsureReadyResult {
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
        inFlightPrewarmTask?.cancel()
        inFlightPrewarmTask = nil
        inFlightPrewarmModelName = nil
        backgroundUnloadTask?.cancel()
        backgroundUnloadTask = nil
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
}
