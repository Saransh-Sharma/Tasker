import XCTest
import UIKit
import CoreData
@testable import LifeBoard

final class HomeViewControllerLifecycleTests: XCTestCase {
    func testStoryboardInstantiatedHomeViewControllerDeallocatesWithoutInjectedDependencies() throws {
        weak var weakController: HomeViewController?
        let storyboard = try XCTUnwrap(mainStoryboard())

        autoreleasepool {
            let controller = storyboard.instantiateViewController(withIdentifier: "homeScreen") as? HomeViewController

            XCTAssertNotNil(controller)
            weakController = controller
        }

        XCTAssertNil(weakController)
    }

    func testDeferredHomeAttachShowsBootstrapFailureWhenInjectionFails() {
        let sceneDelegate = SceneDelegate()
        sceneDelegate.window = UIWindow()

        let result = sceneDelegate.makeDeferredHomeRootController(
            bootstrapState: .ready(makeBootstrapContainer()),
            failureMessage: "Injected failure",
            instantiateHomeViewController: { HomeViewController() },
            tryInject: { _ in false }
        )

        XCTAssertNil(result)
        XCTAssertTrue(sceneDelegate.window?.rootViewController is BootstrapFailureViewController)
    }

    func testLaunchSplashAssetsResolveFromMainBundle() throws {
        let bundle = try XCTUnwrap(mainStoryboardBundle())

        XCTAssertNotNil(
            UIImage(named: "LifeBoardSplashIcon", in: bundle, compatibleWith: nil)
        )
        XCTAssertNotNil(
            UIColor(named: "LaunchCanvas", in: bundle, compatibleWith: nil)
        )
    }

    func testLaunchSplashCoverScaleOverfillsPortraitAndLandscapeViewports() {
        let portraitSize = CGSize(width: 393, height: 852)
        let landscapeSize = CGSize(width: 852, height: 393)

        XCTAssertGreaterThanOrEqual(
            LifeBoardLaunchSplashMetrics.iconSide
                * LifeBoardLaunchSplashMetrics.coverScale(for: portraitSize),
            max(portraitSize.width, portraitSize.height)
                * LifeBoardLaunchSplashMetrics.coverOverscan
        )
        XCTAssertGreaterThanOrEqual(
            LifeBoardLaunchSplashMetrics.iconSide
                * LifeBoardLaunchSplashMetrics.coverScale(for: landscapeSize),
            max(landscapeSize.width, landscapeSize.height)
                * LifeBoardLaunchSplashMetrics.coverOverscan
        )
    }

    @MainActor
    func testHomeReloadEventAdapterEmitsTypedTaskMutationEvents() {
        let center = NotificationCenter()
        let adapter = HomeReloadEventAdapter(notificationCenter: center)
        let delegate = HomeReloadEventRecorder()
        let eventExpectation = expectation(description: "reload event")
        delegate.onEvent = { eventExpectation.fulfill() }
        adapter.delegate = delegate
        adapter.start()
        defer { adapter.stop() }

        let taskID = UUID()
        center.post(
            name: .homeTaskMutation,
            object: nil,
            userInfo: HomeTaskMutationPayload(
                reason: .completed,
                source: "unit_test",
                taskID: taskID
            ).userInfo
        )
        wait(for: [eventExpectation], timeout: 1.0)

        XCTAssertEqual(delegate.taskMutationEvents.count, 1)
        XCTAssertEqual(delegate.taskMutationEvents.first?.reason, .completed)
        XCTAssertEqual(delegate.taskMutationEvents.first?.source, "unit_test")
        XCTAssertEqual(delegate.taskMutationEvents.first?.taskID, taskID)
    }

    @MainActor
    func testHomeNavigationEventAdapterParsesTypedDeepLinks() {
        let center = NotificationCenter()
        let adapter = HomeNavigationEventAdapter(notificationCenter: center)
        let delegate = HomeNavigationEventRecorder()
        let expectedEvents = expectation(description: "navigation events")
        expectedEvents.expectedFulfillmentCount = 4
        delegate.onIntent = { expectedEvents.fulfill() }
        adapter.delegate = delegate
        adapter.start()
        defer { adapter.stop() }

        let taskID = UUID()
        let projectID = UUID()
        let habitID = UUID()
        center.post(name: .lifeboardOpenChatDeepLink, object: nil, userInfo: ["prompt": "  plan day  "])
        center.post(
            name: .lifeboardOpenTaskScopeDeepLink,
            object: nil,
            userInfo: ["scope": "UPCOMING", "projectID": projectID.uuidString]
        )
        center.post(name: .lifeboardOpenTaskDetailDeepLink, object: nil, userInfo: ["taskID": taskID.uuidString])
        center.post(name: .lifeboardOpenHabitDetailDeepLink, object: nil, userInfo: ["habitID": habitID.uuidString])

        wait(for: [expectedEvents], timeout: 1.0)

        XCTAssertEqual(delegate.intents, [
            .chatDeepLink(prompt: "plan day"),
            .taskScopeDeepLink(scope: "upcoming", projectID: projectID),
            .taskDetailDeepLink(taskID: taskID),
            .habitDetailDeepLink(habitID: habitID)
        ])
    }

    @MainActor
    func testHomeNavigationEventAdapterIgnoresInvalidIDs() {
        let center = NotificationCenter()
        let adapter = HomeNavigationEventAdapter(notificationCenter: center)
        let delegate = HomeNavigationEventRecorder()
        let noEvent = expectation(description: "invalid ids do not emit")
        noEvent.isInverted = true
        delegate.onIntent = { noEvent.fulfill() }
        adapter.delegate = delegate
        adapter.start()
        defer { adapter.stop() }

        center.post(name: .lifeboardOpenTaskDetailDeepLink, object: nil, userInfo: ["taskID": "not-a-uuid"])
        center.post(name: .lifeboardOpenHabitDetailDeepLink, object: nil, userInfo: ["habitID": "not-a-uuid"])

        wait(for: [noEvent], timeout: 0.1)
        XCTAssertTrue(delegate.intents.isEmpty)
    }

    @MainActor
    func testHomeNavigationEventAdapterParsesNotificationRoutePayload() {
        let center = NotificationCenter()
        let adapter = HomeNavigationEventAdapter(notificationCenter: center)
        let delegate = HomeNavigationEventRecorder()
        let eventExpectation = expectation(description: "route event")
        delegate.onIntent = { eventExpectation.fulfill() }
        adapter.delegate = delegate
        adapter.start()
        defer { adapter.stop() }

        let taskID = UUID()
        center.post(
            name: LifeBoardNotificationRouteBus.routeDidChange,
            object: nil,
            userInfo: ["payload": LifeBoardNotificationRoute.taskDetail(taskID: taskID).payload]
        )

        wait(for: [eventExpectation], timeout: 1.0)
        XCTAssertEqual(delegate.intents, [.notificationRoute(.taskDetail(taskID: taskID))])
    }

    @MainActor
    func testHomeReloadEventAdapterMapsLifecycleAndDomainEvents() {
        let center = NotificationCenter()
        let adapter = HomeReloadEventAdapter(notificationCenter: center)
        let delegate = HomeReloadEventRecorder()
        let expectedEvents = expectation(description: "reload lifecycle events")
        expectedEvents.expectedFulfillmentCount = 6
        delegate.onEvent = { expectedEvents.fulfill() }
        adapter.delegate = delegate
        adapter.start()
        defer { adapter.stop() }

        center.post(name: .lifeboardPersistentSyncModeDidChange, object: nil)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        center.post(name: UIApplication.significantTimeChangeNotification, object: nil)
        center.post(name: LifeBoardWorkspacePreferencesStore.didChangeNotification, object: nil)
        center.post(name: .homeHabitMutation, object: nil)
        center.post(name: .gamificationLedgerDidMutate, object: nil)

        wait(for: [expectedEvents], timeout: 1.0)

        XCTAssertEqual(delegate.eventNames, [
            "persistentSyncModeChanged",
            "appDidBecomeActive",
            "significantTimeChanged",
            "workspacePreferencesChanged",
            "homeHabitMutation",
            "gamificationLedgerMutation"
        ])
    }

    @MainActor
    func testHomeReloadCoordinatorMapsNonTaskEventsToDelegateEffects() {
        let spy = HomeReloadCoordinatorLifecycleSpy()
        let coordinator = HomeReloadCoordinator(delegate: spy)

        coordinator.handle(.persistentSyncModeChanged)
        coordinator.handle(.appDidBecomeActive)
        coordinator.handle(.significantTimeChanged)
        coordinator.handle(.workspacePreferencesChanged)
        coordinator.handle(.homeHabitMutation)
        coordinator.handle(.gamificationLedgerMutation)

        XCTAssertEqual(spy.persistentSyncRefreshCount, 1)
        XCTAssertEqual(spy.weeklySummaryRefreshCount, 5)
        XCTAssertEqual(spy.calendarRefreshReasons, [
            "app_did_become_active",
            "significant_time_change",
            "workspace_preferences_changed",
            "home_habit_mutation"
        ])
    }

    @MainActor
    func testHomeLaunchHarnessRunsWorkspaceSeedersInOrder() {
        let service = HomeLaunchHarnessService()
        var order: [String] = []

        service.seedUITestWorkspacesIfNeeded(
            seeders: HomeLaunchHarnessWorkspaceSeeders(
                establishedSeed: { completion in order.append("established"); completion() },
                rescueSeed: { completion in order.append("rescue"); completion() },
                focusSeed: { completion in order.append("focus"); completion() },
                habitBoardSeed: { completion in order.append("habit"); completion() },
                quietTrackingSeed: { completion in order.append("quiet"); completion() }
            )
        ) {
            order.append("complete")
        }

        XCTAssertEqual(order, ["established", "rescue", "focus", "habit", "quiet", "complete"])
    }

    private func mainStoryboard() -> UIStoryboard? {
        guard let bundle = mainStoryboardBundle() else { return nil }
        return UIStoryboard(name: "Main", bundle: bundle)
    }

    private func mainStoryboardBundle() -> Bundle? {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        for bundle in bundles where bundle.path(forResource: "Main", ofType: "storyboardc") != nil {
            return bundle
        }
        return nil
    }

    private func makeBootstrapContainer() -> NSPersistentCloudKitContainer {
        NSPersistentCloudKitContainer(name: "HomeLifecycleTests", managedObjectModel: NSManagedObjectModel())
    }
}

@MainActor
private final class HomeReloadEventRecorder: HomeReloadEventAdapterDelegate {
    var taskMutationEvents: [HomeTaskMutationReloadEvent] = []
    var events: [HomeReloadEvent] = []
    var onEvent: (() -> Void)?

    var eventNames: [String] {
        events.map { event in
            switch event {
            case .taskMutation:
                return "taskMutation"
            case .persistentSyncModeChanged:
                return "persistentSyncModeChanged"
            case .appDidBecomeActive:
                return "appDidBecomeActive"
            case .significantTimeChanged:
                return "significantTimeChanged"
            case .workspacePreferencesChanged:
                return "workspacePreferencesChanged"
            case .homeHabitMutation:
                return "homeHabitMutation"
            case .gamificationLedgerMutation:
                return "gamificationLedgerMutation"
            }
        }
    }

    func homeReloadEventAdapter(
        _ adapter: HomeReloadEventAdapter,
        didReceive event: HomeReloadEvent
    ) {
        events.append(event)
        if case .taskMutation(let mutation) = event {
            taskMutationEvents.append(mutation)
        }
        onEvent?()
    }
}

@MainActor
private final class HomeNavigationEventRecorder: HomeNavigationEventAdapterDelegate {
    var intents: [HomeNavigationIntent] = []
    var onIntent: (() -> Void)?

    func homeNavigationEventAdapter(
        _ adapter: HomeNavigationEventAdapter,
        didReceive intent: HomeNavigationIntent
    ) {
        intents.append(intent)
        onIntent?()
    }
}

@MainActor
private final class HomeReloadCoordinatorLifecycleSpy: HomeReloadCoordinatorDelegate {
    var persistentSyncRefreshCount = 0
    var weeklySummaryRefreshCount = 0
    var calendarRefreshReasons: [String] = []

    func homeReloadCoordinatorDidReceiveTaskMutation(_ mutation: HomeTaskMutationReloadEvent) {}

    func homeReloadCoordinatorRecordSearchMutation() {}

    func homeReloadCoordinatorRefreshInsights(reason: HomeTaskMutationEvent?) {}

    func homeReloadCoordinatorRefreshPersistentSyncMode() {
        persistentSyncRefreshCount += 1
    }

    func homeReloadCoordinatorRefreshWeeklySummary() {
        weeklySummaryRefreshCount += 1
    }

    func homeReloadCoordinatorRefreshCalendarContext(reason: String) {
        calendarRefreshReasons.append(reason)
    }
}
