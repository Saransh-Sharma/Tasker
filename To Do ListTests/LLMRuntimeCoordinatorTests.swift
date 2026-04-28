import XCTest
import UIKit
import MLXLMCommon
@testable import To_Do_List

@MainActor
final class LLMRuntimeCoordinatorTests: XCTestCase {
    private let qwenPointSixName = "mlx-community/Qwen3-0.6B-4bit"
    private var originalPrewarmMode: LLMChatPrewarmMode = .adaptiveOnDemand
    private var originalDeferPrewarmFlag: Bool = true

    override func setUp() {
        super.setUp()
        originalPrewarmMode = V2FeatureFlags.llmChatPrewarmMode
        originalDeferPrewarmFlag = V2FeatureFlags.iPadPerfDeferLLMPrewarmV2Enabled
    }

    override func tearDown() {
        V2FeatureFlags.llmChatPrewarmMode = originalPrewarmMode
        V2FeatureFlags.iPadPerfDeferLLMPrewarmV2Enabled = originalDeferPrewarmFlag
        super.tearDown()
    }

    private func configureInstalledCurrentModel(
        _ modelName: String,
        defaults: UserDefaults
    ) {
        LLMPersistedModelSelection.persistInstalledModels([modelName], defaults: defaults)
        defaults.set(modelName, forKey: LLMPersistedModelSelection.currentModelKey)
    }

    func testNoPrewarmWhenFeatureFlagDisabled() async {
        V2FeatureFlags.llmChatPrewarmMode = .disabled
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Disabled.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)

        var prepareCallCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { _ in
                prepareCallCount += 1
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        await coordinator.prewarmIfEligibleCurrentModel()
        XCTAssertEqual(prepareCallCount, 0)
    }

    func testRepeatedPrewarmSkipsAfterFirstActivation() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Repeated.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)

        var prepareCallCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { _ in
                prepareCallCount += 1
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        await coordinator.prewarmIfEligibleCurrentModel()
        try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
        await coordinator.prewarmIfEligibleCurrentModel()
        try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(prepareCallCount, 1)
    }

    func testPrewarmNormalizesRetiredCurrentModelBeforePreparing() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let suiteName = "LLMRuntimeCoordinatorTests.RetiredCurrent.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        LLMPersistedModelSelection.persistInstalledModels(
            [
                "unsupported/legacy-model",
                "mlx-community/Qwen3-0.6B-4bit"
            ],
            defaults: defaults
        )
        defaults.set("unsupported/legacy-model", forKey: LLMPersistedModelSelection.currentModelKey)

        var preparedModelNames: [String] = []
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { modelName in
                preparedModelNames.append(modelName)
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        await coordinator.prewarmIfEligibleCurrentModel()
        try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(preparedModelNames, ["mlx-community/Qwen3-0.6B-4bit"])
        XCTAssertEqual(defaults.string(forKey: LLMPersistedModelSelection.currentModelKey), "mlx-community/Qwen3-0.6B-4bit")
    }

    func testSwitchModelRejectsUnsupportedLegacyModelName() async {
        let evaluator = LLMEvaluator()
        let coordinator = LLMRuntimeCoordinator(
            evaluator: evaluator,
            registerLifecycleObservers: false
        )

        let switched = await coordinator.switchModelIfNeeded(modelName: "unsupported/legacy-model")

        XCTAssertFalse(switched)
        XCTAssertNil(coordinator.activeModelName)
        XCTAssertNil(evaluator.loadedModelName)
    }

    func testSwitchModelRejectsUnknownCompatibility() async {
        var switchedModelNames: [String] = []
        let coordinator = LLMRuntimeCoordinator(
            switchHandler: { modelName in
                switchedModelNames.append(modelName)
                return true
            },
            compatibilityProvider: { _ in nil },
            registerLifecycleObservers: false
        )

        let switched = await coordinator.switchModelIfNeeded(modelName: qwenPointSixName)

        XCTAssertFalse(switched)
        XCTAssertNil(coordinator.activeModelName)
        XCTAssertTrue(switchedModelNames.isEmpty)
    }

    func testSwitchModelSupportsQwen35TextCatalogEntry() async {
        var switchedModelNames: [String] = []
        let coordinator = LLMRuntimeCoordinator(
            switchHandler: { modelName in
                switchedModelNames.append(modelName)
                return true
            },
            registerLifecycleObservers: false
        )

        let switched = await coordinator.switchModelIfNeeded(modelName: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")

        XCTAssertTrue(switched)
        XCTAssertEqual(switchedModelNames, ["mlx-community/Qwen3.5-0.8B-OptiQ-4bit"])
        XCTAssertEqual(coordinator.activeModelName, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
    }

    func testEnsureReadySupportsQwen35TextCatalogEntry() async {
        var preparedModelNames: [String] = []
        let coordinator = LLMRuntimeCoordinator(
            prepareHandler: { modelName in
                preparedModelNames.append(modelName)
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        let result = await coordinator.ensureReady(modelName: "Jackrong/MLX-Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-4bit")

        XCTAssertTrue(result.ready)
        XCTAssertEqual(
            preparedModelNames,
            ["Jackrong/MLX-Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-4bit"]
        )
        XCTAssertEqual(
            result.resolvedModelName,
            "Jackrong/MLX-Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-4bit"
        )
    }

    func testEnsureReadyFallsBackToDefaultTextModelAfterPrepareFailure() async {
        let suiteName = "LLMRuntimeCoordinatorTests.Fallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        LLMPersistedModelSelection.persistInstalledModels(
            [
                "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
                qwenPointSixName
            ],
            defaults: defaults
        )
        defaults.set("mlx-community/Qwen3.5-0.8B-OptiQ-4bit", forKey: LLMPersistedModelSelection.currentModelKey)

        var preparedModelNames: [String] = []
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { modelName in
                preparedModelNames.append(modelName)
                if modelName == "mlx-community/Qwen3.5-0.8B-OptiQ-4bit" {
                    throw LLMEvaluatorError.modelNotFound(modelName)
                }
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            compatibilityProvider: { modelName in
                LLMModelCompatibilityResult(
                    modelName: modelName,
                    availability: .supported,
                    statusReason: nil
                )
            },
            registerLifecycleObservers: false
        )

        let result = await coordinator.ensureReady(modelName: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")

        XCTAssertTrue(result.ready)
        XCTAssertEqual(
            preparedModelNames,
            ["mlx-community/Qwen3.5-0.8B-OptiQ-4bit", qwenPointSixName]
        )
        XCTAssertEqual(result.resolvedModelName, qwenPointSixName)
        XCTAssertEqual(defaults.string(forKey: LLMPersistedModelSelection.currentModelKey), qwenPointSixName)
    }

    func testEnsureReadyFallsBackToDefaultTextModelWhenSelectedModelUnsupported() async {
        let suiteName = "LLMRuntimeCoordinatorTests.UnsupportedFallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let bonsaiName = ModelConfiguration.bonsai_1_7b_mlx_1bit.name
        LLMPersistedModelSelection.persistInstalledModels([bonsaiName, qwenPointSixName], defaults: defaults)
        defaults.set(bonsaiName, forKey: LLMPersistedModelSelection.currentModelKey)

        var preparedModelNames: [String] = []
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { modelName in
                preparedModelNames.append(modelName)
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            compatibilityProvider: { modelName in
                if modelName == bonsaiName {
                    return LLMModelCompatibilityResult(
                        modelName: modelName,
                        availability: .temporarilyUnavailable,
                        statusReason: "Bonsai 1-bit requires Prism-specific MLX kernels."
                    )
                }
                return LLMModelCompatibilityResult(
                    modelName: modelName,
                    availability: .supported,
                    statusReason: nil
                )
            },
            registerLifecycleObservers: false
        )

        let result = await coordinator.ensureReady(modelName: bonsaiName)

        XCTAssertTrue(result.ready)
        XCTAssertEqual(preparedModelNames, [qwenPointSixName])
        XCTAssertEqual(result.resolvedModelName, qwenPointSixName)
        XCTAssertEqual(defaults.string(forKey: LLMPersistedModelSelection.currentModelKey), qwenPointSixName)
    }

    func testMemoryWarningNotificationTriggersUnload() async {
        let center = NotificationCenter()
        var unloadCount = 0

        let coordinator = LLMRuntimeCoordinator(
            notificationCenter: center,
            unloadHandler: { _ in
                unloadCount += 1
            },
            registerLifecycleObservers: true
        )

        center.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        _ = coordinator
        XCTAssertEqual(unloadCount, 1)
    }

    func testBackgroundUnloadCancelledWhenForegrounded() async {
        let center = NotificationCenter()
        var unloadCount = 0

        let coordinator = LLMRuntimeCoordinator(
            notificationCenter: center,
            unloadHandler: { _ in
                unloadCount += 1
            },
            backgroundUnloadDelayNanoseconds: 60_000_000,
            registerLifecycleObservers: true
        )

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try? await _Concurrency.Task.sleep(nanoseconds: 20_000_000)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try? await _Concurrency.Task.sleep(nanoseconds: 80_000_000)

        _ = coordinator
        XCTAssertEqual(unloadCount, 0)
    }

    func testBackgroundUnloadTriggersAfterDelay() async {
        let center = NotificationCenter()
        var unloadCount = 0

        let coordinator = LLMRuntimeCoordinator(
            notificationCenter: center,
            unloadHandler: { _ in
                unloadCount += 1
            },
            backgroundUnloadDelayNanoseconds: 40_000_000,
            registerLifecycleObservers: true
        )

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try? await _Concurrency.Task.sleep(nanoseconds: 90_000_000)

        _ = coordinator
        XCTAssertEqual(unloadCount, 1)
    }

    func testReleaseSessionSchedulesIdleUnload() async {
        let center = NotificationCenter()
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Idle.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)
        V2FeatureFlags.llmChatPrewarmMode = .eager

        var unloadCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            notificationCenter: center,
            prepareHandler: { _ in LLMEvaluator.PrepareResult(wasAlreadyLoaded: false) },
            unloadHandler: { _ in
                unloadCount += 1
            },
            idleUnloadDelayNanoseconds: 40_000_000,
            registerLifecycleObservers: false
        )

        await coordinator.prepareCurrentModelIfConfigured(trigger: "test")
        coordinator.acquireSession(reason: "test_session")
        coordinator.releaseSession(reason: "test_session")

        try? await _Concurrency.Task.sleep(nanoseconds: 90_000_000)
        XCTAssertEqual(unloadCount, 1)
    }

    func testCancelGenerationIfActiveCancelsEvaluator() {
        let evaluator = LLMEvaluator()
        evaluator.running = true
        let coordinator = LLMRuntimeCoordinator(
            evaluator: evaluator,
            registerLifecycleObservers: false
        )
        coordinator.acquireSession(reason: "chat_generation")

        coordinator.cancelGenerationIfActive(reason: "unit_test")

        XCTAssertTrue(evaluator.cancelled)
        XCTAssertEqual(evaluator.runtimePhase, .stopping)
        _ = coordinator
    }

    func testCancelGenerationClearsThinkingWhenNotRunning() {
        let evaluator = LLMEvaluator()
        evaluator.running = false
        evaluator.isThinking = true
        evaluator.runtimePhase = .thinking

        evaluator.cancelGeneration(reason: "unit_test_not_running")

        XCTAssertTrue(evaluator.cancelled)
        XCTAssertFalse(evaluator.isThinking)
        XCTAssertEqual(evaluator.runtimePhase, .stopping)
    }

    func testBeginUserTurnClearsCancelledOutputStateWithoutUnloadingModel() {
        let evaluator = LLMEvaluator()
        evaluator.loadedModelName = qwenPointSixName
        evaluator.cancelled = true
        evaluator.output = "stale output"
        evaluator.stat = "stale stats"
        evaluator.thinkingTime = 1.5
        evaluator.lastGenerationTimedOut = true
        evaluator.lastTerminationReason = "user_cancel"
        evaluator.lastRawOutput = "raw"
        evaluator.lastGeneratedTokenCount = 12
        evaluator.lastVisibleCharacterCount = 8
        evaluator.lastSanitizedTemplateArtifacts = true

        evaluator.beginUserTurn(runID: UUID())

        XCTAssertFalse(evaluator.cancelled)
        XCTAssertEqual(evaluator.output, "")
        XCTAssertEqual(evaluator.stat, "")
        XCTAssertNil(evaluator.thinkingTime)
        XCTAssertFalse(evaluator.lastGenerationTimedOut)
        XCTAssertNil(evaluator.lastTerminationReason)
        XCTAssertEqual(evaluator.lastRawOutput, "")
        XCTAssertEqual(evaluator.lastGeneratedTokenCount, 0)
        XCTAssertEqual(evaluator.lastVisibleCharacterCount, 0)
        XCTAssertFalse(evaluator.lastSanitizedTemplateArtifacts)
        XCTAssertEqual(evaluator.loadedModelName, qwenPointSixName)
    }

    func testPromptFocusPrewarmHonorsRequestedDelay() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Deferred.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)

        var prepareCallCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { _ in
                prepareCallCount += 1
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        coordinator.requestChatEntryPrewarm(trigger: "unit_test", delaySeconds: 0.05)
        XCTAssertEqual(prepareCallCount, 0)
        try? await _Concurrency.Task.sleep(nanoseconds: 90_000_000)
        XCTAssertEqual(prepareCallCount, 1)
    }

    func testZeroDelayChatEntryPrewarmRunsImmediately() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.ZeroDelay.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)

        var prepareCallCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { _ in
                prepareCallCount += 1
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        coordinator.requestChatEntryPrewarm(trigger: "activation_first_chat", delaySeconds: 0)
        try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(prepareCallCount, 1)
    }

    func testDeferredChatEntryPrewarmCancelsBeforeExecution() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.DeferredCancel.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)

        var prepareCallCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { _ in
                prepareCallCount += 1
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        coordinator.requestChatEntryPrewarm(trigger: "unit_test_cancel", delaySeconds: 0.2)
        coordinator.cancelDeferredPrewarm(reason: "unit_test_cancelled")
        try? await _Concurrency.Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(prepareCallCount, 0)
    }

    func testDeferredChatEntryPrewarmDedupesMatchingRequests() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.DeferredDedup.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)

        var prepareCallCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { _ in
                prepareCallCount += 1
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        coordinator.requestChatEntryPrewarm(trigger: "prompt_focus", delaySeconds: 0.05)
        coordinator.requestChatEntryPrewarm(trigger: "prompt_focus", delaySeconds: 0.05)
        try? await _Concurrency.Task.sleep(nanoseconds: 90_000_000)
        XCTAssertEqual(prepareCallCount, 1)
    }

    func testEnterChatScreenTriggersImmediatePrewarm() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Entry.\(UUID().uuidString)")!
        configureInstalledCurrentModel(qwenPointSixName, defaults: defaults)

        var prepareCallCount = 0
        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { _ in
                prepareCallCount += 1
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            registerLifecycleObservers: false
        )

        coordinator.enterChatScreen(trigger: "unit_test_entry")
        try? await _Concurrency.Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(prepareCallCount, 1)
    }

    func testExitChatScreenUnloadsImmediately() async {
        let center = NotificationCenter()
        var unloadReasons: [String] = []

        let coordinator = LLMRuntimeCoordinator(
            notificationCenter: center,
            unloadHandler: { reason in
                unloadReasons.append(reason)
            },
            registerLifecycleObservers: false
        )

        coordinator.acquireSession(reason: "chat_host_visible")
        await coordinator.exitChatScreen(reason: "unit_test_exit")

        XCTAssertEqual(unloadReasons, ["unit_test_exit"])
    }
}
