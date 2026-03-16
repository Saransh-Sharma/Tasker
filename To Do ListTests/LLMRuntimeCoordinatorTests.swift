import XCTest
import UIKit
@testable import To_Do_List

@MainActor
final class LLMRuntimeCoordinatorTests: XCTestCase {
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

    func testNoPrewarmWhenFeatureFlagDisabled() async {
        V2FeatureFlags.llmChatPrewarmMode = .disabled
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Disabled.\(UUID().uuidString)")!
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

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
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

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

    func testSwitchModelCancelsInflightPrewarm() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Cancel.\(UUID().uuidString)")!
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

        var prewarmCancelled = false
        var switchedModelName: String?

        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { modelName in
                if modelName == "mlx-community/Qwen3-0.6B-4bit" {
                    do {
                        try await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000)
                    } catch is CancellationError {
                        prewarmCancelled = true
                        throw CancellationError()
                    } catch {
                        throw error
                    }
                }
                return LLMEvaluator.PrepareResult(wasAlreadyLoaded: false)
            },
            switchHandler: { modelName in
                switchedModelName = modelName
                return true
            },
            registerLifecycleObservers: false
        )

        await coordinator.prewarmIfEligibleCurrentModel()
        try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
        _ = await coordinator.switchModelIfNeeded(modelName: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(prewarmCancelled)
        XCTAssertEqual(switchedModelName, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertEqual(coordinator.activeModelName, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
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
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")
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

    func testPromptFocusPrewarmHonorsRequestedDelay() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Deferred.\(UUID().uuidString)")!
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

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

    func testDeferredChatEntryPrewarmCancelsBeforeExecution() async {
        V2FeatureFlags.llmChatPrewarmMode = .adaptiveOnDemand
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.DeferredCancel.\(UUID().uuidString)")!
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

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
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

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
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

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
