import XCTest
import UIKit
@testable import To_Do_List

@MainActor
final class LLMRuntimeCoordinatorTests: XCTestCase {
    private var originalPrewarmFlag: Bool = true

    override func setUp() {
        super.setUp()
        originalPrewarmFlag = V2FeatureFlags.llmChatPrewarmEnabled
    }

    override func tearDown() {
        V2FeatureFlags.llmChatPrewarmEnabled = originalPrewarmFlag
        super.tearDown()
    }

    func testNoPrewarmWhenFeatureFlagDisabled() async {
        V2FeatureFlags.llmChatPrewarmEnabled = false
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
        V2FeatureFlags.llmChatPrewarmEnabled = true
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
        try? await Task.sleep(nanoseconds: 50_000_000)
        await coordinator.prewarmIfEligibleCurrentModel()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(prepareCallCount, 1)
    }

    func testSwitchModelCancelsInflightPrewarm() async {
        V2FeatureFlags.llmChatPrewarmEnabled = true
        let defaults = UserDefaults(suiteName: "LLMRuntimeCoordinatorTests.Cancel.\(UUID().uuidString)")!
        defaults.set("mlx-community/Qwen3-0.6B-4bit", forKey: "currentModelName")

        var prewarmCancelled = false
        var switchedModelName: String?

        let coordinator = LLMRuntimeCoordinator(
            defaults: defaults,
            prepareHandler: { modelName in
                if modelName == "mlx-community/Qwen3-0.6B-4bit" {
                    do {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
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
        try? await Task.sleep(nanoseconds: 50_000_000)
        _ = await coordinator.switchModelIfNeeded(modelName: "mlx-community/Llama-3.2-1B-Instruct-4bit")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(prewarmCancelled)
        XCTAssertEqual(switchedModelName, "mlx-community/Llama-3.2-1B-Instruct-4bit")
        XCTAssertEqual(coordinator.activeModelName, "mlx-community/Llama-3.2-1B-Instruct-4bit")
    }

    func testMemoryWarningNotificationTriggersUnload() async {
        let center = NotificationCenter()
        var unloadCount = 0

        let coordinator = LLMRuntimeCoordinator(
            notificationCenter: center,
            unloadHandler: {
                unloadCount += 1
            },
            registerLifecycleObservers: true
        )

        center.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        try? await Task.sleep(nanoseconds: 50_000_000)

        _ = coordinator
        XCTAssertEqual(unloadCount, 1)
    }

    func testBackgroundUnloadCancelledWhenForegrounded() async {
        let center = NotificationCenter()
        var unloadCount = 0

        let coordinator = LLMRuntimeCoordinator(
            notificationCenter: center,
            unloadHandler: {
                unloadCount += 1
            },
            backgroundUnloadDelayNanoseconds: 60_000_000,
            registerLifecycleObservers: true
        )

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try? await Task.sleep(nanoseconds: 20_000_000)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try? await Task.sleep(nanoseconds: 80_000_000)

        _ = coordinator
        XCTAssertEqual(unloadCount, 0)
    }

    func testBackgroundUnloadTriggersAfterDelay() async {
        let center = NotificationCenter()
        var unloadCount = 0

        let coordinator = LLMRuntimeCoordinator(
            notificationCenter: center,
            unloadHandler: {
                unloadCount += 1
            },
            backgroundUnloadDelayNanoseconds: 40_000_000,
            registerLifecycleObservers: true
        )

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try? await Task.sleep(nanoseconds: 90_000_000)

        _ = coordinator
        XCTAssertEqual(unloadCount, 1)
    }
}
