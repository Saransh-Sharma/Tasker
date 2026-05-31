//
//  HomeViewController.swift
//  LifeBoard
//
//  SwiftUI host for Home screen with backdrop/sunrise shell.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData

public enum HomeShellPhase: String, Equatable {
    case startup
    case interactive
}

public enum HomeScrollChromeState: String, Equatable {
    case nearTop
    case expanded
    case collapsed
    case idle
}

enum HomeAnalyticsSurfaceState: Equatable {
    case idle
    case placeholder
    case loading
    case ready
}

enum HomeSearchSurfaceState: Equatable {
    case idle
    case presenting
    case preparing
    case ready
}

@MainActor private var onboardingTaskDetailDismissBridgeKey: UInt8 = 0

final class HomeViewController: UIViewController, HomeViewControllerProtocol, PresentationDependencyContainerAware, UIAdaptivePresentationControllerDelegate {
    private static let bottomBarVerticalLift: CGFloat = 6

    // MARK: - Dependencies

    var viewModel: HomeViewModel!
    var presentationDependencyContainer: PresentationDependencyContainer?

    // MARK: - UI

    private var homeHostingController: UIHostingController<HomeHostRootView>?
    private var bottomBarHostingController: UIHostingController<HomeBottomBarContainer>?
    private var bottomBarBottomConstraint: NSLayoutConstraint?
    private var bottomBarHeightConstraint: NSLayoutConstraint?
    private weak var presentedCalendarScheduleController: UIViewController?
    private weak var presentedEvaChatController: UIViewController?
    private var shouldResetHomeAfterEvaChatDismissal = false
    private var insightsViewModel: InsightsViewModel?
    private let searchState = HomeSearchState()
    private let chromeStore = HomeChromeStore()
    private let tasksStore = HomeTasksStore()
    private let habitsStore = HomeHabitsStore()
    private let calendarStore = HomeCalendarStore()
    private let timelineStore = HomeTimelineStore()
    private let overlayStore = HomeOverlayStore()
    private let faceCoordinator = HomeFaceCoordinator()
    private let navigationCoordinator = HomeNavigationCoordinator()
    private let navigationEventAdapter = HomeNavigationEventAdapter()
    private let reloadCoordinator = HomeReloadCoordinator()
    private let reloadEventAdapter = HomeReloadEventAdapter()
    private let launchHarnessService = HomeLaunchHarnessService()
    private let uiTestWorkspaceSeeder = HomeUITestWorkspaceSeeder()

    // MARK: - State

    private let notificationCenter = NotificationCenter.default
    private var cancellables = Set<AnyCancellable>()
    private var pendingNotificationFocusTaskID: UUID?
    private var syncOutageBanner: UIView?
    private var syncOutageLabel: UILabel?
    private var currentLayoutClass: LifeBoardLayoutClass = .phone
    private let iPadShellState = HomeiPadShellState()
    private let homeChatAppManager = AppManager()
    private var iPadShellEpoch = 0
    private var didTrackLayoutClassAtLaunch = false
    private var didTrackIPadShellRendered = false
    private var hasMountedStableLayoutShell = false
    private var pendingIPadModalRequest: HomeiPadModalRequest?
    private let onboardingGuidanceModel = HomeOnboardingGuidanceModel()
    private var onboardingCoordinator: AppOnboardingCoordinator?
    private var isEmbeddedChatRuntimeEntered = false
    private var embeddedChatRuntimeGeneration = 0
    private var pendingExitChatTask: Task<Void, Never>?
    private var pendingInsightsLaunchRequest: InsightsLaunchRequest?
    private var pendingInsightsPreparationTask: Task<Void, Never>?
    private var pendingSearchPreparationTask: Task<Void, Never>?
    private var pendingSearchWarmupTask: Task<Void, Never>?
    private var pendingSearchMutationRefreshTask: Task<Void, Never>?
    private var pendingBackgroundSearchPrewarmTask: Task<Void, Never>?
    private var pendingBackgroundInsightsPrewarmTask: Task<Void, Never>?
    private let surfacePrewarmPolicy = HomeSurfacePrewarmPolicy()
    private var pendingOnboardingEvaluationTask: Task<Void, Never>?
    private var awaitsAnalyticsFirstInteractiveFrame = false
    private var retainedHomeSearchEngine: HomeSearchEngineAdapter?
    private var onboardingEvaluationSceneToken: Int = 1
    private var completedOnboardingEvaluationSceneToken: Int = 0
    private var lastAppliedHomeRenderTransaction: HomeRenderTransaction = .empty
    private var keyboardOverlapHeight: CGFloat = 0
    private var isEmbeddedChatPromptFocused = false


    // MARK: - Lifecycle

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()

        injectDependenciesIfNeeded()
        navigationCoordinator.delegate = self
        navigationEventAdapter.delegate = self
        reloadCoordinator.delegate = self
        reloadEventAdapter.delegate = self
        bindTheme()
        bindViewModel()
        bindRenderPipeline()
        mountHomeShell()
        navigationEventAdapter.start()
        reloadEventAdapter.start()
        observeTaskCreatedForSnackbar()
        observeIPadShellTelemetry()
        observeOnboardingRequests()
        observeKeyboardFrameChanges()
        applyTheme()
        refreshPersistentSyncOutageBanner()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (self: Self, _) in
                self.refreshLayoutClassIfNeeded()
            }
        }
        onboardingCoordinator = AppOnboardingCoordinator(
            homeViewController: self,
            presentationDependencyContainer: presentationDependencyContainer,
            guidanceModel: onboardingGuidanceModel
        )
    }

    /// Executes viewWillAppear.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    /// Executes viewDidAppear.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resetHomeSelectionAfterEvaChatDismissalIfNeeded()
        if let pendingRoute = LifeBoardNotificationRouteBus.shared.consumePendingRoute() {
            navigationCoordinator.handle(.notificationRoute(pendingRoute))
        }
        navigationCoordinator.handle(.pendingShortcutHandoff)
        navigationCoordinator.handle(.uiTestInjectedRoute)
        navigationCoordinator.handle(.uiTestOpenSettings)
        navigationCoordinator.handle(.pendingWidgetActionCommand)
        navigationCoordinator.handle(.pendingIPadModalRequest)
        launchHarnessService.seedUITestWorkspacesIfNeeded(
            seeders: HomeLaunchHarnessWorkspaceSeeders(
                establishedSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestEstablishedWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        completion: completion
                    )
                },
                searchSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestSearchWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        viewModel: self.viewModel,
                        completion: completion
                    )
                },
                rescueSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestRescueWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        viewModel: self.viewModel,
                        completion: completion
                    )
                },
                focusSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestFocusWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        completion: completion
                    )
                },
                habitBoardSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestHabitBoardWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        completion: completion
                    )
                },
                quietTrackingSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestQuietTrackingWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        completion: completion
                    )
                },
                fullTimelineSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestFullTimelineWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        viewModel: self.viewModel,
                        completion: completion
                    )
                }
            )
        ) { [weak self] in
            self?.viewModel.loadTodayTasks()
            self?.scheduleOnboardingEvaluationIfNeeded()
        }
    }

    /// Executes viewDidLayoutSubviews.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshLayoutClassIfNeeded()
        refreshLayoutMetrics()
        updateInteractivePhaseIfNeeded()
        mountBottomBarOverlayIfNeeded(animated: false)
        updateBottomBarBottomConstraint(animated: false)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        refreshLayoutMetrics()
        updateBottomBarBottomConstraint(animated: false)
    }

    /// Executes viewWillDisappear.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    deinit {
        pendingInsightsPreparationTask?.cancel()
        pendingSearchPreparationTask?.cancel()
        pendingSearchWarmupTask?.cancel()
        pendingSearchMutationRefreshTask?.cancel()
        pendingBackgroundSearchPrewarmTask?.cancel()
        pendingBackgroundInsightsPrewarmTask?.cancel()
        pendingOnboardingEvaluationTask?.cancel()
        pendingExitChatTask?.cancel()
        let navigationEventAdapter = navigationEventAdapter
        let reloadEventAdapter = reloadEventAdapter
        let reloadCoordinator = reloadCoordinator
        Task { @MainActor in
            navigationEventAdapter.stop()
            reloadEventAdapter.stop()
            reloadCoordinator.cancelPendingReloads()
        }
        cancellables.removeAll()
        retainedHomeSearchEngine = nil
    }

    // MARK: - Setup

    /// Executes injectDependenciesIfNeeded.
    private func injectDependenciesIfNeeded() {
        guard viewModel != nil else {
            fatalError("HomeViewController requires injected HomeViewModel")
        }
        guard presentationDependencyContainer != nil else {
            fatalError("HomeViewController requires injected PresentationDependencyContainer")
        }
    }

    /// Executes bindTheme.
    private func bindTheme() {
        LifeBoardThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }

    /// Executes bindViewModel.
    private func bindViewModel() {
        // HomeViewModel performs initial data loading in its initializer.
        // Keep this hook for future bindings, but avoid duplicate startup fetches.
    }

    private func bindRenderPipeline() {
        viewModel.$homeRenderTransaction
            .receive(on: RunLoop.main)
            .sink { [weak self] transaction in
                self?.applyHomeRenderTransaction(transaction)
            }
            .store(in: &cancellables)

        onboardingGuidanceModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyOverlayState(self.viewModel.homeRenderTransaction.overlay)
            }
            .store(in: &cancellables)

        viewModel.$insightsLaunchRequest
            .receive(on: RunLoop.main)
            .sink { [weak self] request in
                self?.handleInsightsLaunchRequest(request)
            }
            .store(in: &cancellables)

        faceCoordinator.$activeFace
            .receive(on: RunLoop.main)
            .sink { [weak self] activeFace in
                self?.trackFaceSelection(activeFace)
                switch activeFace {
                case .tasks:
                    self?.scheduleOnboardingEvaluationIfNeeded()
                    self?.scheduleBackgroundSurfacePrewarmIfNeeded()
                case .schedule:
                    self?.cancelBackgroundSearchPrewarm()
                    self?.cancelBackgroundSurfacePrewarm()
                case .analytics:
                    self?.cancelBackgroundSearchPrewarm()
                case .search:
                    self?.cancelBackgroundSurfacePrewarm()
                case .chat:
                    self?.cancelBackgroundSearchPrewarm()
                    self?.cancelBackgroundSurfacePrewarm()
                }
                self?.setEmbeddedChatRuntimeVisible(activeFace == .chat, trigger: "home_chat_face")
                if activeFace != .chat {
                    self?.isEmbeddedChatPromptFocused = false
                }
                self?.refreshLayoutMetrics()
                self?.mountBottomBarOverlayIfNeeded(animated: true)
            }
            .store(in: &cancellables)

        faceCoordinator.$shellPhase
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.mountBottomBarOverlayIfNeeded(animated: true)
                self?.scheduleOnboardingEvaluationIfNeeded()
                self?.scheduleBackgroundSurfacePrewarmIfNeeded()
            }
            .store(in: &cancellables)

        faceCoordinator.$searchMutationRevision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSearchMutationRevision()
            }
            .store(in: &cancellables)
    }

    private var isUsingIPadNativeShell: Bool {
        currentLayoutClass.isPad && V2FeatureFlags.iPadNativeShellEnabled
    }

    private func calendarScheduleSelectedDateBinding() -> Binding<Date> {
        Binding(
            get: { [weak self] in
                self?.viewModel?.selectedDate ?? Date()
            },
            set: { [weak self] date in
                self?.viewModel?.selectDate(date, source: .datePicker)
            }
        )
    }

    /// Executes refreshLayoutClassIfNeeded.
    private func refreshLayoutClassIfNeeded() {
        let nextLayoutClass = LifeBoardLayoutResolver.classify(view: view)
        guard nextLayoutClass != currentLayoutClass || homeHostingController == nil else { return }
        currentLayoutClass = nextLayoutClass
        mountHomeShell()
    }

    private var hasStableLayoutMetrics: Bool {
        let metrics = LifeBoardLayoutResolver.metrics(for: view)
        return metrics.width > 1 && metrics.height > 1
    }

    private func scheduleInsightsPreparationIfNeeded() {
        guard faceCoordinator.insightsViewModel == nil else {
            faceCoordinator.setAnalyticsSurfaceState(.ready)
            emitAnalyticsFirstInteractiveFrameIfNeeded()
            applyPendingInsightsLaunchRequestIfNeeded()
            return
        }

        pendingInsightsPreparationTask?.cancel()
        faceCoordinator.setAnalyticsSurfaceState(.placeholder)

        let interval = LifeBoardPerformanceTrace.begin("HomeInsightsFirstMount")
        pendingInsightsPreparationTask = Task { @MainActor [weak self] in
            defer {
                LifeBoardPerformanceTrace.end(interval)
                self?.pendingInsightsPreparationTask = nil
            }
            guard let self else { return }

            LifeBoardPerformanceTrace.event("HomeAnalyticsPlaceholderShown")
            await Task.yield()
            guard Task.isCancelled == false, self.faceCoordinator.activeFace == .analytics else { return }

            self.faceCoordinator.setAnalyticsSurfaceState(.loading)
            _ = self.prepareInsightsViewModelIfNeeded()
            guard Task.isCancelled == false else { return }

            self.faceCoordinator.setAnalyticsSurfaceState(.ready)
            LifeBoardPerformanceTrace.event("HomeAnalyticsReady")
            self.emitAnalyticsFirstInteractiveFrameIfNeeded()
            self.applyPendingInsightsLaunchRequestIfNeeded()
        }
    }

    private func scheduleOnboardingEvaluationIfNeeded() {
        guard isViewLoaded, view.window != nil else { return }
        guard faceCoordinator.shellPhase == .interactive else { return }
        guard faceCoordinator.activeFace == .tasks else { return }
        guard presentedViewController == nil else { return }
        guard onboardingEvaluationSceneToken > completedOnboardingEvaluationSceneToken else { return }
        guard pendingOnboardingEvaluationTask == nil else { return }

        let sceneToken = onboardingEvaluationSceneToken
        pendingOnboardingEvaluationTask = Task { @MainActor [weak self] in
            await self?.runOnboardingEvaluationAfterDelay(sceneToken: sceneToken)
        }
    }

    private func handleInsightsLaunchRequest(_ request: InsightsLaunchRequest?) {
        guard let request else { return }
        pendingInsightsLaunchRequest = request
        if faceCoordinator.activeFace == .analytics {
            scheduleInsightsPreparationIfNeeded()
            applyPendingInsightsLaunchRequestIfNeeded()
            return
        }
        openAnalytics(source: "launch_request", launchDefaultInsights: false)
    }

    private func applyPendingInsightsLaunchRequestIfNeeded() {
        guard let request = pendingInsightsLaunchRequest else { return }
        guard let insightsViewModel = faceCoordinator.insightsViewModel else { return }
        pendingInsightsLaunchRequest = nil
        insightsViewModel.selectTab(request.targetTab)
        insightsViewModel.highlightAchievement(request.highlightedAchievementKey)
    }

    private func trackFaceSelection(_ activeFace: HomeSunriseFace) {
        let faceName: String
        switch activeFace {
        case .tasks:
            faceName = "tasks"
        case .schedule:
            faceName = "schedule"
        case .analytics:
            faceName = "analytics"
        case .search:
            faceName = "search"
        case .chat:
            faceName = "chat"
        }
        logDebug("HOME_RENDER face=\(faceName) phase=\(faceCoordinator.shellPhase.rawValue)")
    }

    private func setEmbeddedChatRuntimeVisible(_ isVisible: Bool, trigger: String) {
        embeddedChatRuntimeGeneration &+= 1
        let generation = embeddedChatRuntimeGeneration

        if isVisible {
            let hadPendingExit = pendingExitChatTask != nil
            pendingExitChatTask?.cancel()
            pendingExitChatTask = nil
            if isEmbeddedChatRuntimeEntered, hadPendingExit {
                LLMRuntimeCoordinator.shared.enterChatScreen(trigger: trigger)
                return
            }
            guard isEmbeddedChatRuntimeEntered == false else { return }
            isEmbeddedChatRuntimeEntered = true
            LLMRuntimeCoordinator.shared.enterChatScreen(trigger: trigger)
        } else {
            guard isEmbeddedChatRuntimeEntered else { return }
            pendingExitChatTask?.cancel()
            pendingExitChatTask = Task { @MainActor [weak self] in
                guard Task.isCancelled == false else { return }
                await LLMRuntimeCoordinator.shared.exitChatScreen(reason: "home_chat_face_exit")
                guard Task.isCancelled == false else { return }
                guard let self, self.embeddedChatRuntimeGeneration == generation else { return }
                self.isEmbeddedChatRuntimeEntered = false
                self.pendingExitChatTask = nil
            }
        }
    }

    private func openSchedule(source: String) {
        if isUsingIPadNativeShell {
            unwindActiveFaceForIPadDestination(source: source)
            iPadShellState.destination = .schedule
            return
        }
        guard faceCoordinator.activeFace != .schedule else { return }
        cancelBackgroundSearchPrewarm()
        cancelBackgroundSurfacePrewarm()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil
        if faceCoordinator.activeFace == .search {
            pendingSearchPreparationTask?.cancel()
            pendingSearchWarmupTask?.cancel()
            pendingSearchMutationRefreshTask?.cancel()
            searchState.releaseResources()
            retainedHomeSearchEngine = nil
            viewModel.releaseHomeSearchViewModel()
            faceCoordinator.setSearchSurfaceState(.idle)
        }
        LifeBoardPerformanceTrace.event("HomeFaceSwitch")
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "home_schedule_open",
            message: "Opening schedule surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.schedule)
        viewModel.trackHomeInteraction(
            action: "home_schedule_flip_open",
            metadata: ["source": source]
        )
    }

    private func unwindActiveFaceForIPadDestination(source: String) {
        guard faceCoordinator.activeFace != .tasks else { return }
        returnToTasks(source: source)
    }

    private func openAnalytics(source: String, launchDefaultInsights: Bool) {
        guard faceCoordinator.activeFace != .analytics else { return }
        cancelBackgroundSearchPrewarm()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil
        awaitsAnalyticsFirstInteractiveFrame = true
        LifeBoardPerformanceTrace.event("HomeFaceSwitch")
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "home_insights_open",
            message: "Opening insights surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.analytics)
        faceCoordinator.setAnalyticsSurfaceState(faceCoordinator.insightsViewModel == nil ? .placeholder : .ready)
        if launchDefaultInsights {
            viewModel.launchInsights(.default)
        }
        viewModel.trackHomeInteraction(
            action: "home_insights_flip_open",
            metadata: ["source": source]
        )
        scheduleInsightsPreparationIfNeeded()
    }

    private static func duration(nanoseconds: UInt64) -> Duration {
        .nanoseconds(Int64(min(nanoseconds, UInt64(Int64.max))))
    }

    @MainActor
    func runOnboardingEvaluationAfterDelay(
        sceneToken: Int,
        sleepNanoseconds: UInt64 = 2_000_000_000,
        retry: (@MainActor () -> Void)? = nil
    ) async {
        let clear = { [weak self] in
            self?.pendingOnboardingEvaluationTask = nil
        }
        defer { clear() }

        do {
            try await Task.sleep(for: Self.duration(nanoseconds: sleepNanoseconds))
        } catch {
            return
        }

        guard Task.isCancelled == false else { return }
        let retryEvaluation = retry ?? { [weak self] in
            self?.scheduleOnboardingEvaluationIfNeeded()
        }

        guard sceneToken == self.onboardingEvaluationSceneToken else {
            retryEvaluation()
            return
        }
        guard self.isViewLoaded, self.view.window != nil else {
            retryEvaluation()
            return
        }
        guard self.faceCoordinator.shellPhase == .interactive else {
            retryEvaluation()
            return
        }
        guard self.faceCoordinator.activeFace == .tasks else {
            retryEvaluation()
            return
        }
        guard self.presentedViewController == nil else {
            retryEvaluation()
            return
        }

        let interval = LifeBoardPerformanceTrace.begin("HomeOnboardingLaunchEval")
        self.onboardingCoordinator?.evaluateLaunchIfNeeded()
        self.onboardingCoordinator?.drainPendingPresentationIfPossible()
        LifeBoardPerformanceTrace.end(interval)
        self.completedOnboardingEvaluationSceneToken = sceneToken
    }

    private func closeAnalytics(source: String) {
        guard faceCoordinator.activeFace == .analytics else { return }
        if faceCoordinator.insightsViewModel == nil {
            pendingInsightsPreparationTask?.cancel()
        }
        awaitsAnalyticsFirstInteractiveFrame = false
        LifeBoardPerformanceTrace.event("HomeFaceSwitch")
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "home_insights_close",
            message: "Closing insights surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.tasks)
        faceCoordinator.setAnalyticsSurfaceState(.idle)
        viewModel.trackHomeInteraction(
            action: "home_insights_flip_close",
            metadata: ["source": source]
        )
    }

    private func toggleInsights(source: String) {
        if faceCoordinator.activeFace == .analytics {
            closeAnalytics(source: source)
        } else {
            openAnalytics(source: source, launchDefaultInsights: true)
        }
    }

    private func openSearch(source: String) {
        guard faceCoordinator.activeFace != .search else { return }
        cancelBackgroundSurfacePrewarm()
        pendingSearchPreparationTask?.cancel()
        pendingSearchWarmupTask?.cancel()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil
        LifeBoardPerformanceTrace.event("HomeFaceSwitch")
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "home_search_open",
            message: "Opening search surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.search)
        faceCoordinator.setSearchSurfaceState(.presenting)
        LifeBoardPerformanceTrace.event("HomeSearchTapped")
        viewModel.trackHomeInteraction(
            action: "home_search_flip_open",
            metadata: ["source": source]
        )
        scheduleSearchPreparation()
    }

    private func closeSearch(source: String) {
        guard faceCoordinator.activeFace == .search else { return }
        pendingSearchPreparationTask?.cancel()
        pendingSearchWarmupTask?.cancel()
        pendingSearchMutationRefreshTask?.cancel()
        LifeBoardPerformanceTrace.event("HomeFaceSwitch")
        searchState.releaseResources()
        retainedHomeSearchEngine = nil
        viewModel.releaseHomeSearchViewModel()
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "home_search_close",
            message: "Closing search surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.tasks)
        faceCoordinator.setSearchSurfaceState(.idle)
        viewModel.trackHomeInteraction(
            action: "home_search_flip_close",
            metadata: ["source": source]
        )
    }

    private func toggleSearch(source: String) {
        if faceCoordinator.activeFace == .search {
            closeSearch(source: source)
        } else {
            openSearch(source: source)
        }
    }

    private func openChat(source: String) {
        presentEvaChatScreen(source: source)
    }

    private func presentEvaChatScreen(source: String) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .chat
            return
        }

        if presentedEvaChatController != nil,
           presentedViewController === presentedEvaChatController {
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.presentEvaChatScreen(source: source)
            }
            return
        }

        cancelBackgroundSearchPrewarm()
        cancelBackgroundSurfacePrewarm()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil

        if faceCoordinator.activeFace == .search {
            pendingSearchPreparationTask?.cancel()
            pendingSearchWarmupTask?.cancel()
            pendingSearchMutationRefreshTask?.cancel()
            searchState.releaseResources()
            retainedHomeSearchEngine = nil
            viewModel.releaseHomeSearchViewModel()
            faceCoordinator.setSearchSurfaceState(.idle)
        }

        if faceCoordinator.activeFace == .chat {
            faceCoordinator.setActiveFace(.tasks)
        }
        isEmbeddedChatPromptFocused = false
        setEmbeddedChatRuntimeVisible(false, trigger: "dedicated_chat_screen")

        let chatHostVC = ChatHostViewController()
        if let presentationDependencyContainer {
            _ = presentationDependencyContainer.tryInject(into: chatHostVC)
        }
        chatHostVC.onDismissToHome = { [weak self] in
            self?.resetHomeSelectionAfterEvaChatDismissal()
        }
        let navController = UINavigationController(rootViewController: chatHostVC)
        navController.modalPresentationStyle = .fullScreen
        navController.navigationBar.prefersLargeTitles = false
        presentedEvaChatController = navController
        shouldResetHomeAfterEvaChatDismissal = true
        navController.presentationController?.delegate = self

        LifeBoardMemoryDiagnostics.checkpoint(
            event: "home_chat_open",
            message: "Opening Eva chat screen",
            fields: ["source": source]
        )
        viewModel.trackHomeInteraction(
            action: "home_chat_screen_open",
            metadata: ["source": source]
        )
        present(navController, animated: true)
    }

    private func closeChat(source: String) {
        guard faceCoordinator.activeFace == .chat else { return }
        LifeBoardPerformanceTrace.event("HomeFaceSwitch")
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "home_chat_close",
            message: "Closing Eva chat surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.tasks)
        viewModel.trackHomeInteraction(
            action: "home_chat_flip_close",
            metadata: ["source": source]
        )
    }

    private func returnToTasks(source: String) {
        switch faceCoordinator.activeFace {
        case .tasks:
            faceCoordinator.bottomBarState.select(.home)
        case .schedule:
            LifeBoardPerformanceTrace.event("HomeFaceSwitch")
            faceCoordinator.setActiveFace(.tasks)
            viewModel.trackHomeInteraction(
                action: "home_schedule_flip_close",
                metadata: ["source": source]
            )
        case .analytics:
            closeAnalytics(source: source)
        case .search:
            closeSearch(source: source)
        case .chat:
            closeChat(source: source)
        }
    }

    private func handleTaskListChromeStateChange(_ state: HomeScrollChromeState) {
        faceCoordinator.bottomBarState.handleChromeStateChange(state)
    }

    private func scheduleSearchPreparation() {
        let interval = LifeBoardPerformanceTrace.begin("HomeSearchSurface")
        pendingSearchPreparationTask = Task { @MainActor [weak self] in
            defer {
                LifeBoardPerformanceTrace.end(interval)
                self?.pendingSearchPreparationTask = nil
            }
            guard let self else { return }

            await Task.yield()
            guard Task.isCancelled == false, self.faceCoordinator.activeFace == .search else { return }

            LifeBoardPerformanceTrace.event("HomeSearchSurfaceVisible")
            self.faceCoordinator.setSearchSurfaceState(.preparing)
            self.searchState.configureIfNeeded(
                makeEngine: {
                    self.resolveHomeSearchEngine()
                },
                dataRevisionProvider: {
                    self.viewModel.currentDataRevision
                }
            )
            LifeBoardPerformanceTrace.event("HomeSearchConfigured")
            guard Task.isCancelled == false, self.faceCoordinator.activeFace == .search else { return }

            self.faceCoordinator.setSearchSurfaceState(.ready)
            LifeBoardPerformanceTrace.event("HomeSearchSurfaceReady")
            LifeBoardPerformanceTrace.event("HomeSearchFirstInteractiveFrame")
            self.scheduleInitialSearchWarmupIfNeeded()
        }
    }

    private func emitAnalyticsFirstInteractiveFrameIfNeeded() {
        guard awaitsAnalyticsFirstInteractiveFrame else { return }
        guard faceCoordinator.activeFace == .analytics else { return }
        guard faceCoordinator.analyticsSurfaceState == .ready else { return }
        awaitsAnalyticsFirstInteractiveFrame = false
        LifeBoardPerformanceTrace.event("HomeAnalyticsFirstInteractiveFrame")
    }

    private func scheduleBackgroundSurfacePrewarmIfNeeded() {
        guard faceCoordinator.shellPhase == .interactive else { return }
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            cancelBackgroundSurfacePrewarm()
            return
        }
        guard faceCoordinator.activeFace == .tasks else { return }
        guard surfacePrewarmPolicy.isEligible(surface: .homeBackgroundSurfaces) else {
            cancelBackgroundSurfacePrewarm()
            return
        }

        if pendingBackgroundSearchPrewarmTask == nil {
            pendingBackgroundSearchPrewarmTask = Task(priority: .utility) { @MainActor [weak self] in
                defer { self?.pendingBackgroundSearchPrewarmTask = nil }
                do {
                    try await Task.sleep(for: .milliseconds(800))
                } catch {
                    return
                }
                guard let self, Task.isCancelled == false else { return }
                guard self.faceCoordinator.activeFace == .tasks else { return }
                guard self.surfacePrewarmPolicy.isEligible(surface: .search) else { return }
                self.searchState.configureIfNeeded(
                    makeEngine: {
                        self.resolveHomeSearchEngine()
                    },
                    dataRevisionProvider: {
                        self.viewModel.currentDataRevision
                    }
                )
                LifeBoardPerformanceTrace.event("HomeSearchSurfaceReady")
            }
        }

        if pendingBackgroundInsightsPrewarmTask == nil {
            pendingBackgroundInsightsPrewarmTask = Task(priority: .utility) { @MainActor [weak self] in
                defer { self?.pendingBackgroundInsightsPrewarmTask = nil }
                do {
                    try await Task.sleep(for: .milliseconds(1_500))
                } catch {
                    return
                }
                guard let self, Task.isCancelled == false else { return }
                guard self.faceCoordinator.activeFace == .tasks else { return }
                guard self.surfacePrewarmPolicy.isEligible(surface: .insights) else { return }
                let resolvedViewModel = self.prepareInsightsViewModelIfNeeded()
                resolvedViewModel.onAppear()
            }
        }
    }

    private func cancelBackgroundSurfacePrewarm() {
        cancelBackgroundSearchPrewarm()
        cancelBackgroundInsightsPrewarm()
    }

    private func cancelBackgroundSearchPrewarm() {
        pendingBackgroundSearchPrewarmTask?.cancel()
        pendingBackgroundSearchPrewarmTask = nil
    }

    private func cancelBackgroundInsightsPrewarm() {
        pendingBackgroundInsightsPrewarmTask?.cancel()
        pendingBackgroundInsightsPrewarmTask = nil
    }

    @discardableResult
    private func prepareInsightsViewModelIfNeeded() -> InsightsViewModel {
        if let existing = faceCoordinator.insightsViewModel {
            insightsViewModel = existing
            return existing
        }

        let resolvedViewModel = viewModel.makeInsightsViewModel()
        insightsViewModel = resolvedViewModel
        faceCoordinator.insightsViewModel = resolvedViewModel
        return resolvedViewModel
    }

    private func resolveHomeSearchEngine() -> HomeSearchEngineAdapter {
        if let retainedHomeSearchEngine {
            return retainedHomeSearchEngine
        }
        let engine = HomeSearchEngineAdapter(viewModel: viewModel.makeHomeSearchViewModel())
        retainedHomeSearchEngine = engine
        return engine
    }

    private func scheduleInitialSearchWarmupIfNeeded() {
        pendingSearchWarmupTask?.cancel()
        pendingSearchWarmupTask = Task { @MainActor [weak self] in
            defer { self?.pendingSearchWarmupTask = nil }
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard let self, Task.isCancelled == false else { return }
            guard self.faceCoordinator.activeFace == .search else { return }
            guard self.faceCoordinator.searchSurfaceState == .ready else { return }
            self.searchState.activate()
        }
    }

    private func handleSearchMutationRevision() {
        searchState.markDataMutated()
        guard faceCoordinator.activeFace == .search, faceCoordinator.searchSurfaceState == .ready else { return }

        pendingSearchMutationRefreshTask?.cancel()
        pendingSearchMutationRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            guard Task.isCancelled == false,
                  self.faceCoordinator.activeFace == .search,
                  self.faceCoordinator.searchSurfaceState == .ready else {
                return
            }
            self.searchState.refresh(immediate: true)
        }
    }

    private func computeHomeLayoutMetrics() -> HomeLayoutMetrics {
        let safeAreaInsets = view.safeAreaInsets
        let width = view.bounds.width
        let height = view.bounds.height
        let tokens = LifeBoardThemeManager.shared.tokens(for: currentLayoutClass)
        let spacing = tokens.spacing
        let shouldShowBottomBar = currentLayoutClass == .phone
            && faceCoordinator.shellPhase == .interactive
            && overlayStore.snapshot.replanState.suppressesBottomBar == false
        let bottomOverlayObstruction = currentLayoutClass == .phone
            ? (shouldShowBottomBar ? resolvedBottomBarHostHeight() : 0)
            : 0
        let taskListBottomInset = currentLayoutClass == .phone
            ? bottomOverlayObstruction + spacing.s16
            : spacing.s24
        let isChatBottomBarConcealed = isBottomBarConcealedForChatInput
        let chatComposerBottomInset = HomeBottomBarVisibilityPolicy.chatComposerClearance(
            layoutClass: currentLayoutClass,
            bottomOverlayObstruction: bottomOverlayObstruction,
            keyboardOverlapHeight: keyboardOverlapHeight,
            isBottomBarConcealed: isChatBottomBarConcealed,
            idleSpacing: spacing.s40,
            idleExtraSpacing: spacing.s24,
            keyboardSpacing: spacing.s16,
            regularSpacing: spacing.s24
        )
        let insightsViewportHeight = min(max(height * 0.66, 560), max(560, height - 150))

        return HomeLayoutMetrics(
            width: width,
            height: height,
            safeAreaTop: safeAreaInsets.top,
            safeAreaBottom: safeAreaInsets.bottom,
            keyboardOverlapHeight: keyboardOverlapHeight,
            backdropGradientHeight: height + safeAreaInsets.top + safeAreaInsets.bottom,
            taskListBottomInset: taskListBottomInset,
            chatComposerBottomInset: chatComposerBottomInset,
            insightsViewportHeight: insightsViewportHeight
        )
    }

    private func refreshLayoutMetrics() {
        faceCoordinator.setLayoutMetrics(computeHomeLayoutMetrics())
    }

    private func configureSafeAreaRegions(for hostingController: UIHostingController<HomeHostRootView>) {
        hostingController.safeAreaRegions = currentLayoutClass == .phone ? .container : .all
    }

    private func observeKeyboardFrameChanges() {
        notificationCenter.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleKeyboardFrameChange(notification)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setKeyboardOverlapHeight(0)
            }
            .store(in: &cancellables)
    }

    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard currentLayoutClass == .phone else {
            setKeyboardOverlapHeight(0)
            return
        }

        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let overlapHeight = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        let adjustedOverlapHeight = max(0, overlapHeight - view.safeAreaInsets.bottom)
        setKeyboardOverlapHeight(adjustedOverlapHeight)
    }

    private func setKeyboardOverlapHeight(_ newValue: CGFloat) {
        let sanitizedValue = max(0, newValue)
        guard abs(keyboardOverlapHeight - sanitizedValue) > 0.5 else { return }
        keyboardOverlapHeight = sanitizedValue
        refreshLayoutMetrics()
        mountBottomBarOverlayIfNeeded(animated: true)
        updateBottomBarBottomConstraint(animated: true)
    }

    private var isBottomBarConcealedForChatInput: Bool {
        HomeBottomBarVisibilityPolicy.shouldConcealBottomBar(
            activeFace: faceCoordinator.activeFace,
            isPromptFocused: isEmbeddedChatPromptFocused,
            keyboardOverlapHeight: keyboardOverlapHeight
        )
    }

    private func setEmbeddedChatPromptFocused(_ isFocused: Bool) {
        guard isEmbeddedChatPromptFocused != isFocused else {
            refreshLayoutMetrics()
            mountBottomBarOverlayIfNeeded(animated: true)
            updateBottomBarBottomConstraint(animated: true)
            return
        }
        isEmbeddedChatPromptFocused = isFocused
        refreshLayoutMetrics()
        mountBottomBarOverlayIfNeeded(animated: true)
        updateBottomBarBottomConstraint(animated: true)
    }

    private func updateInteractivePhaseIfNeeded() {
        let layoutMetrics = faceCoordinator.layoutMetrics
        let tasksState = tasksStore.snapshot
        if faceCoordinator.shellPhase == .startup,
           layoutMetrics.isReady,
           tasksState.hasCommittedInitialContent {
            faceCoordinator.setShellPhase(.interactive)
        }
    }

    private func applyHomeRenderTransaction(_ transaction: HomeRenderTransaction) {
        guard transaction != lastAppliedHomeRenderTransaction else { return }

        let changedSliceCount = transaction.changedSliceCount(comparedTo: lastAppliedHomeRenderTransaction)
        let interval = LifeBoardPerformanceTrace.begin("HomeRenderTransactionCommit")
        defer {
            LifeBoardPerformanceTrace.event("HomeRenderSliceCommits", value: changedSliceCount)
            LifeBoardPerformanceTrace.end(interval)
            lastAppliedHomeRenderTransaction = transaction
        }

        if transaction.chrome != lastAppliedHomeRenderTransaction.chrome {
            chromeStore.apply(transaction.chrome)
        }
        if transaction.tasks != lastAppliedHomeRenderTransaction.tasks {
            tasksStore.apply(transaction.tasks)
            updateInteractivePhaseIfNeeded()
        }
        if transaction.habits != lastAppliedHomeRenderTransaction.habits {
            habitsStore.apply(transaction.habits)
            LifeBoardPerformanceTrace.event("home.render.habitsCommitted")
        }
        if transaction.calendar != lastAppliedHomeRenderTransaction.calendar {
            calendarStore.apply(transaction.calendar)
            LifeBoardPerformanceTrace.event("home.render.calendarCommitted")
        }
        if transaction.timeline != lastAppliedHomeRenderTransaction.timeline {
            timelineStore.apply(transaction.timeline)
            LifeBoardPerformanceTrace.event("home.render.timelineCommitted")
        }
        if transaction.overlay != lastAppliedHomeRenderTransaction.overlay {
            applyOverlayState(transaction.overlay)
        }
    }

    private func applyOverlayState(_ state: HomeOverlayState) {
        overlayStore.apply(
            HomeOverlaySnapshot(
                guidanceState: onboardingGuidanceModel.state,
                focusWhyPresented: state.focusWhyPresented,
                triagePresented: state.triagePresented,
                triageScope: state.triageScope,
                triageQueueLoading: state.triageQueueLoading,
                triageQueueErrorMessage: state.triageQueueErrorMessage,
                triageQueue: state.triageQueue,
                rescuePresented: state.rescuePresented,
                rescuePlan: state.rescuePlan,
                lastBatchRunID: state.lastBatchRunID,
                lastXPResult: state.lastXPResult,
                replanState: state.replanState
            )
        )
        mountBottomBarOverlayIfNeeded(animated: true)
    }

    private func mountBottomBarOverlayIfNeeded(animated: Bool = true) {
        let shouldShowBottomBar = currentLayoutClass == .phone
            && faceCoordinator.shellPhase == .interactive
            && overlayStore.snapshot.replanState.suppressesBottomBar == false
        if shouldShowBottomBar == false {
            if let bottomBarHostingController {
                bottomBarHostingController.willMove(toParent: nil)
                bottomBarHostingController.view.removeFromSuperview()
                bottomBarHostingController.removeFromParent()
                self.bottomBarHostingController = nil
                bottomBarBottomConstraint = nil
                bottomBarHeightConstraint = nil
            }
            return
        }

        let root = makeBottomBarRoot()
        if let bottomBarHostingController {
            bottomBarHostingController.rootView = root
            applyBottomBarConcealmentState()
            updateBottomBarHeightConstraint()
            updateBottomBarBottomConstraint(animated: animated)
            return
        }

        let hostingController = UIHostingController(rootView: root)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        bottomBarHostingController = hostingController
        addChild(hostingController)
        view.addSubview(hostingController.view)
        let bottomConstraint = hostingController.view.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: resolvedBottomBarDownshift()
        )
        let heightConstraint = hostingController.view.heightAnchor.constraint(equalToConstant: resolvedBottomBarHostHeight())
        bottomBarBottomConstraint = bottomConstraint
        bottomBarHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            heightConstraint
        ])
        hostingController.didMove(toParent: self)
        applyBottomBarConcealmentState()
        updateBottomBarBottomConstraint(animated: false)
    }

    private func applyBottomBarConcealmentState() {
        guard let bottomBarHostingController else { return }
        let isConcealed = isBottomBarConcealedForChatInput
        bottomBarHostingController.view.alpha = isConcealed ? 0 : 1
        bottomBarHostingController.view.isUserInteractionEnabled = !isConcealed
        bottomBarHostingController.view.accessibilityElementsHidden = isConcealed
    }

    private func resolvedBottomBarHostHeight() -> CGFloat {
        guard currentLayoutClass == .phone else { return 0 }
        return HomeBottomBarVisibilityPolicy.phoneDockHostHeight
    }

    private func updateBottomBarHeightConstraint() {
        guard let bottomBarHeightConstraint else { return }
        let height = resolvedBottomBarHostHeight()
        guard abs(bottomBarHeightConstraint.constant - height) > 0.5 else { return }
        bottomBarHeightConstraint.constant = height
    }

    private func makeBottomBarRoot() -> HomeBottomBarContainer {
        HomeBottomBarContainer(
            state: faceCoordinator.bottomBarState,
            shellPhase: faceCoordinator.shellPhase,
            isConcealed: isBottomBarConcealedForChatInput,
            onHome: { [weak self] in
                self?.returnToTasks(source: "bottom_bar_home")
            },
            onCalendar: { [weak self] in
                self?.openSchedule(source: "bottom_bar_schedule")
            },
            onChartsToggle: { [weak self] in
                self?.toggleInsights(source: "bottom_bar_analytics")
            },
            onSearch: { [weak self] in
                self?.toggleSearch(source: "bottom_bar_search")
            },
            onChat: { [weak self] in
                self?.openChat(source: "bottom_bar_chat")
            },
            onCreate: { [weak self] in
                if self?.isUsingIPadNativeShell == true {
                    if self?.currentLayoutClass == .padExpanded {
                        self?.iPadShellState.destination = .addTask
                    } else {
                        self?.presentAddTaskSheetForPadFallback()
                    }
                } else {
                    self?.AddTaskAction()
                }
            },
            layoutClass: currentLayoutClass
        )
    }

    private func resolvedBottomBarDownshift() -> CGFloat {
        guard currentLayoutClass == .phone else { return 0 }
        let restingDownshift = HomeBottomBarVisibilityPolicy.restingDockDownshift(
            safeAreaBottom: view.safeAreaInsets.bottom,
            verticalLift: Self.bottomBarVerticalLift
        )
        guard isBottomBarConcealedForChatInput else { return restingDownshift }

        let tokens = LifeBoardThemeManager.shared.tokens(for: currentLayoutClass)
        return restingDownshift + resolvedBottomBarHostHeight() + tokens.spacing.s16
    }

    private func updateBottomBarBottomConstraint(animated: Bool = true) {
        guard let bottomBarBottomConstraint else { return }
        let downshift = resolvedBottomBarDownshift()
        guard abs(bottomBarBottomConstraint.constant - downshift) > 0.5 else { return }
        bottomBarBottomConstraint.constant = downshift
        guard animated else {
            view.layoutIfNeeded()
            return
        }
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            self.view.layoutIfNeeded()
        }
    }

    /// Executes mountHomeShell.
    private func mountHomeShell() {
        let interval = LifeBoardPerformanceTrace.begin("HomeShellMount")
        defer { LifeBoardPerformanceTrace.end(interval) }

        guard self.viewModel != nil else { return }
        guard hasMountedStableLayoutShell || hasStableLayoutMetrics else { return }

        currentLayoutClass = LifeBoardLayoutResolver.classify(view: view)
        if hasStableLayoutMetrics {
            hasMountedStableLayoutShell = true
            trackLayoutClassAtLaunchIfNeeded()
        }
        let existingHostingController = homeHostingController
        if existingHostingController != nil {
            iPadShellEpoch += 1
        }
        let root: HomeHostRootView

        if currentLayoutClass.isPad && V2FeatureFlags.iPadNativeShellEnabled {
            root = HomeHostRootView(
                layoutClass: currentLayoutClass,
                phoneRoot: nil,
                iPadRoot: makeIPadSplitRoot(layoutClass: currentLayoutClass)
            )
            trackIPadShellRenderedIfNeeded()
        } else {
            let homeRoot = makeHomeBackdropRoot(layoutClass: currentLayoutClass, forcedFace: nil)
            root = HomeHostRootView(
                layoutClass: currentLayoutClass,
                phoneRoot: homeRoot,
                iPadRoot: nil
            )
        }

        if let existingHostingController {
            if currentLayoutClass.isPad && V2FeatureFlags.iPadNativeShellEnabled {
                logWarning(
                    event: "ipadPrimarySurfaceShellEpochReset",
                    message: "Reset the iPad primary surface shell epoch after rebuilding the hosted root",
                    fields: [
                        "layout_class": currentLayoutClass.rawValue,
                        "shell_epoch": String(iPadShellEpoch)
                    ]
                )
            }
            configureSafeAreaRegions(for: existingHostingController)
            existingHostingController.rootView = root
            refreshLayoutMetrics()
            updateInteractivePhaseIfNeeded()
            mountBottomBarOverlayIfNeeded(animated: false)
            return
        }

        let hostingController = UIHostingController(rootView: root)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        configureSafeAreaRegions(for: hostingController)

        homeHostingController = hostingController
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
        refreshLayoutMetrics()
        updateInteractivePhaseIfNeeded()
        mountBottomBarOverlayIfNeeded(animated: false)
    }

    /// Executes makeHomeBackdropRoot.
    private func makeHomeBackdropRoot(
        layoutClass: LifeBoardLayoutClass,
        forcedFace: Binding<HomeSunriseFace>?
    ) -> SunriseAppShellView {
        SunriseAppShellView(
            viewModel: viewModel,
            chromeStore: chromeStore,
            tasksStore: tasksStore,
            habitsStore: habitsStore,
            calendarStore: calendarStore,
            timelineStore: timelineStore,
            calendarIntegrationService: presentationDependencyContainer?.coordinator.calendarIntegrationService,
            chatAppManager: homeChatAppManager,
            overlayStore: overlayStore,
            faceCoordinator: faceCoordinator,
            searchState: searchState,
            layoutClass: layoutClass,
            forcedFace: forcedFace,
            onTaskTap: { [weak self] task in
                self?.handleTaskTap(task)
            },
            onToggleComplete: { [weak self] task in
                self?.viewModel?.toggleTaskCompletion(task)
            },
            onTimelineAnchorTap: { [weak self] anchor in
                self?.presentTimelineAnchorDetail(for: anchor)
            },
            onDeleteTask: { [weak self] task in
                self?.handleTaskDeleteRequested(task)
            },
            onRescheduleTask: { [weak self] task in
                self?.handleTaskReschedule(task)
            },
            onReorderCustomProjects: { [weak self] projectIDs in
                self?.viewModel?.setCustomProjectOrder(projectIDs)
            },
            onAddTask: { [weak self] suggestedDate in
                self?.presentAddTaskFlow(suggestedDate: suggestedDate)
            },
            onOpenChat: { [weak self] in
                self?.openChat(source: "home_chat_button")
            },
            onOpenProjectCreator: { [weak self] in
                self?.openProjectCreator()
            },
            onOpenSettings: { [weak self] in
                if self?.isUsingIPadNativeShell == true {
                    self?.iPadShellState.destination = .settings
                } else {
                    self?.onMenuButtonTapped()
                }
            },
            onOpenWeeklyPlanner: { [weak self] in
                self?.presentWeeklyPlanner()
            },
            onOpenWeeklyReview: { [weak self] in
                self?.presentWeeklyReview()
            },
            onRetryWeeklySummary: { [weak self] in
                self?.viewModel?.refreshWeeklySummaryNow()
            },
            onOpenAnalytics: { [weak self] source, launchDefaultInsights in
                self?.openAnalytics(source: source, launchDefaultInsights: launchDefaultInsights)
            },
            onCloseAnalytics: { [weak self] source in
                self?.closeAnalytics(source: source)
            },
            onOpenSearch: { [weak self] source in
                self?.openSearch(source: source)
            },
            onCloseSearch: { [weak self] source in
                self?.closeSearch(source: source)
            },
            onReturnToTasks: { [weak self] source in
                self?.returnToTasks(source: source)
            },
            onTaskListScrollChromeStateChange: { [weak self] state in
                self?.handleTaskListChromeStateChange(state)
            },
            onStartFocus: { [weak self] task in
                self?.startFocusFlow(task: task, source: "focus_strip")
            },
            onRequestCalendarPermission: { [weak self] in
                self?.viewModel?.requestCalendarPermission(openSystemSettings: {
                    guard let url = URL(string: UIApplication.openSettingsURLString),
                          UIApplication.shared.canOpenURL(url) else { return }
                    UIApplication.shared.open(url)
                })
            },
            onOpenCalendarChooser: { [weak self] in
                self?.presentCalendarChooser()
            },
            onOpenCalendarSchedule: { [weak self] in
                guard let self else { return }
                self.openSchedule(source: "home_calendar")
            },
            onRetryCalendarContext: { [weak self] in
                self?.viewModel?.refreshCalendarContext(reason: "home_calendar_retry")
            },
            onPerformChatDayTaskAction: { [weak self] action, card, completion in
                self?.performEmbeddedChatDayTaskAction(action, card: card, completion: completion)
            },
            onPerformChatDayHabitAction: { [weak self] action, card, completion in
                self?.performEmbeddedChatDayHabitAction(action, card: card, completion: completion)
            },
            onChatPromptFocusChange: { [weak self] isFocused in
                self?.setEmbeddedChatPromptFocused(isFocused)
            }
        )
    }

    /// Executes makeIPadSplitRoot.
    private func makeIPadSplitRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        let root = SunriseiPadSplitShellView(
            layoutClass: layoutClass,
            shellState: iPadShellState,
            shellEpoch: iPadShellEpoch,
            homeSurface: { [weak self] forcedFace in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(
                    self.makeHomeBackdropRoot(layoutClass: layoutClass, forcedFace: forcedFace)
                        .lifeboardLayoutClass(layoutClass)
                )
            },
            addTaskSurface: { [weak self] in
                self?.makeAddTaskInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            scheduleSurface: { [weak self] in
                self?.makeCalendarScheduleInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            settingsSurface: { [weak self] in
                self?.makeSettingsInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            lifeManagementSurface: { [weak self] in
                self?.makeLifeManagementInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            projectsSurface: { [weak self] in
                self?.makeProjectManagementInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            chatSurface: { [weak self] in
                self?.makeChatInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            modelsSurface: { [weak self] in
                self?.makeModelsInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            inspectorSurface: { [weak self] task in
                self?.makeTaskInspectorRoot(task, layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            onOpenTaskDetailSheet: { [weak self] task in
                self?.presentTaskDetailView(for: task)
            }
        )
        return AnyView(root.lifeboardLayoutClass(layoutClass))
    }

    private func makeAddTaskInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Add Task unavailable").font(.lifeboard(.body)))
        }
        let viewModel = presentationDependencyContainer.makeNewAddTaskViewModel()
        return AnyView(
            SunriseAddTaskSheetView(
                viewModel: viewModel,
                onTaskCreated: { [weak self] _ in
                    self?.iPadShellState.destination = .tasks
                },
                onDismissWithoutTask: { [weak self] in
                    self?.iPadShellState.destination = .tasks
                }
            )
            .lifeboardLayoutClass(layoutClass)
            .accessibilityIdentifier("home.ipad.detail.addTask")
        )
    }

    private func makeCalendarScheduleInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else {
            return AnyView(Text("Schedule unavailable").font(.lifeboard(.body)))
        }
        return AnyView(
            SunriseScheduleScreen(
                service: service,
                weekStartsOn: service.weekStartsOn,
                presentationMode: .embedded,
                selectedDate: calendarScheduleSelectedDateBinding()
            )
            .lifeboardLayoutClass(layoutClass)
        )
    }

    private func makeSettingsInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let calendarService = presentationDependencyContainer?.coordinator.calendarIntegrationService else {
            return AnyView(Text("Settings unavailable").font(.lifeboard(.body)))
        }
        return AnyView(
            HomeiPadSettingsContainer(
                onNavigateToLifeManagement: { [weak self] in
                    self?.iPadShellState.destination = .lifeManagement
                },
                onNavigateToChats: { [weak self] in
                    self?.iPadShellState.destination = .chat
                },
                onNavigateToModels: { [weak self] in
                    self?.iPadShellState.destination = .models
                },
                onRestartOnboarding: {
                    NotificationCenter.default.post(name: .lifeboardStartOnboardingRequested, object: nil)
                },
                calendarIntegrationService: calendarService,
                onOpenCalendarChooser: { [weak self] in
                    self?.presentCalendarChooser()
                }
            )
            .lifeboardLayoutClass(layoutClass)
        )
    }

    private func makeLifeManagementInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Life Management unavailable").font(.lifeboard(.body)))
        }
        let vm = presentationDependencyContainer.makeLifeManagementViewModel()
        return AnyView(
            LifeManagementView(viewModel: vm)
                .lifeboardLayoutClass(layoutClass)
        )
    }

    private func makeProjectManagementInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Projects unavailable").font(.lifeboard(.body)))
        }
        let vm = presentationDependencyContainer.makeProjectManagementViewModel()
        return AnyView(
            SunriseProjectManagementView(viewModel: vm)
                .lifeboardLayoutClass(layoutClass)
        )
    }

    private func makeChatInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let container = LLMDataController.shared else {
            return AnyView(
                LLMStoreUnavailableView()
                    .lifeboardLayoutClass(layoutClass)
            )
        }

        return AnyView(
            ChatContainerView(
                onOpenTaskDetail: { [weak self] task in
                    self?.handleTaskTap(task)
                },
                onPerformDayTaskAction: { [weak self] action, card, completion in
                    self?.performEmbeddedChatDayTaskAction(action, card: card, completion: completion)
                },
                onPerformDayHabitAction: { [weak self] action, card, completion in
                    self?.performEmbeddedChatDayHabitAction(action, card: card, completion: completion)
                }
            )
            .environmentObject(homeChatAppManager)
            .environment(LLMRuntimeCoordinator.shared.evaluator)
            .modelContainer(container)
            .lifeboardLayoutClass(layoutClass)
        )
    }

    private func makeModelsInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        AnyView(
            NavigationStack {
                ModelsSettingsView()
                    .environmentObject(homeChatAppManager)
                    .environment(LLMRuntimeCoordinator.shared.evaluator)
            }
            .lifeboardLayoutClass(layoutClass)
        )
    }

    private func makeTaskInspectorRoot(_ task: TaskDefinition, layoutClass: LifeBoardLayoutClass) -> AnyView {
        AnyView(
            makeTaskDetailView(for: task, containerMode: .inspector)
                .lifeboardLayoutClass(layoutClass)
        )
    }

    private func trackLayoutClassAtLaunchIfNeeded() {
        guard didTrackLayoutClassAtLaunch == false else { return }
        didTrackLayoutClassAtLaunch = true
        viewModel?.trackHomeInteraction(
            action: "layout_class_at_launch_stable",
            metadata: [
                "layout_class": currentLayoutClass.rawValue,
                "is_ipad_native_shell_enabled": isUsingIPadNativeShell
            ]
        )
    }

    private func trackIPadShellRenderedIfNeeded() {
        guard didTrackIPadShellRendered == false else { return }
        guard currentLayoutClass.isPad else { return }
        didTrackIPadShellRendered = true
        viewModel?.trackHomeInteraction(
            action: "ipad_shell_rendered",
            metadata: [
                "layout_class": currentLayoutClass.rawValue
            ]
        )
    }

    private func observeIPadShellTelemetry() {
        iPadShellState.$destination
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] destination in
                guard let self else { return }
                guard self.currentLayoutClass.isPad else { return }
                self.viewModel?.trackHomeInteraction(
                    action: "ipad_destination_switch",
                    metadata: [
                        "layout_class": self.currentLayoutClass.rawValue,
                        "destination": destination.rawValue
                    ]
                )
            }
            .store(in: &cancellables)

        iPadShellState.$selectedTask
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedTask in
                guard let self else { return }
                guard self.currentLayoutClass == .padExpanded else { return }
                guard selectedTask != nil else { return }
                self.viewModel?.trackHomeInteraction(
                    action: "ipad_inspector_open",
                    metadata: [
                        "layout_class": self.currentLayoutClass.rawValue
                    ]
                )
            }
            .store(in: &cancellables)

        iPadShellState.$modalRequest
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] request in
                guard let self else { return }
                guard self.currentLayoutClass.isPad else { return }
                self.iPadShellState.modalRequest = nil
                self.pendingIPadModalRequest = request
                self.processPendingIPadModalRequest()
            }
            .store(in: &cancellables)
    }

    private func processPendingIPadModalRequest() {
        guard isUsingIPadNativeShell else {
            pendingIPadModalRequest = nil
            resetPendingIPadModalWaitState()
            return
        }
        guard let request = pendingIPadModalRequest else {
            resetPendingIPadModalWaitState()
            return
        }
        if let blockingController = presentedViewController {
            if let presentationController = blockingController.presentationController {
                presentationController.delegate = self
            } else {
                viewModel?.trackHomeInteraction(
                    action: "ipad_modal_request_waiting_for_presented_controller",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
            }
            return
        }

        resetPendingIPadModalWaitState()
        pendingIPadModalRequest = nil
        switch request {
        case .addTask:
            viewModel?.trackHomeInteraction(
                action: "ipad_modal_request_presented",
                metadata: ["layout_class": currentLayoutClass.rawValue]
            )
            presentAddTaskSheetForPadFallback()
        }
    }

    private func resetPendingIPadModalWaitState() {
        if let presentationController = presentedViewController?.presentationController,
           presentationController.delegate === self {
            presentationController.delegate = nil
        }
    }

    private func refreshPersistentSyncOutageBanner() {
        if AppDelegate.isWriteClosed {
            showPersistentSyncOutageBanner(
                message: "Sync unavailable, read-only mode. Recover from iCloud to resume edits."
            )
        } else {
            hidePersistentSyncOutageBanner()
        }
    }

    private func showPersistentSyncOutageBanner(message: String) {
        if syncOutageBanner == nil {
            let banner = UIView()
            banner.translatesAutoresizingMaskIntoConstraints = false
            banner.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
            banner.layer.cornerRadius = 10
            banner.layer.masksToBounds = true

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .label
            label.numberOfLines = 2
            label.textAlignment = .center

            banner.addSubview(label)
            view.addSubview(banner)

            let topConstraint = banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
            let leadingConstraint = banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
            let trailingConstraint = banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
            let heightConstraint = banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)

            NSLayoutConstraint.activate([
                topConstraint,
                leadingConstraint,
                trailingConstraint,
                heightConstraint,
                label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
                label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -8)
            ])

            syncOutageBanner = banner
            syncOutageLabel = label
        }

        syncOutageLabel?.text = message
        syncOutageBanner?.isHidden = false
        syncOutageBanner?.alpha = 1
    }

    private func hidePersistentSyncOutageBanner() {
        syncOutageBanner?.isHidden = true
        syncOutageBanner?.alpha = 0
    }

    private func consumeUITestInjectedRouteIfNeeded() {
        launchHarnessService.consumeUITestInjectedRouteIfNeeded { [weak self] route in
            self?.navigationCoordinator.handle(.notificationRoute(route))
        }
    }

    private func consumeUITestOpenSettingsIfNeeded() {
        launchHarnessService.consumeUITestOpenSettingsIfNeeded(
            canOpenSettings: { [weak self] in
                self?.presentedViewController == nil
            }
        ) { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            self.onMenuButtonTapped()
        }
    }

    var currentOnboardingLayoutClass: LifeBoardLayoutClass {
        currentLayoutClass
    }

    func prepareForOnboardingHomeGuidance() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
    }

    func makeOnboardingAddTaskController(
        prefill: AddTaskPrefillTemplate,
        onTaskCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let presentationDependencyContainer else {
            return nil
        }
        let viewModel = presentationDependencyContainer.makeNewAddTaskViewModel()
        viewModel.applyPrefill(prefill)
        let sheet = SunriseAddTaskSheetView(
            viewModel: viewModel,
            onTaskCreated: onTaskCreated,
            onDismissWithoutTask: onDismissWithoutTask
        )
        let hostingController = UIHostingController(rootView: AnyView(sheet.lifeboardLayoutClass(currentLayoutClass)))
        hostingController.modalPresentationStyle = .pageSheet
        if let sheetController = hostingController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        return hostingController
    }

    func makeOnboardingAddHabitController(
        prefill: AddHabitPrefillTemplate,
        onHabitCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let presentationDependencyContainer else {
            return nil
        }
        let habitViewModel = presentationDependencyContainer.makeNewAddHabitViewModel()
        habitViewModel.applyPrefill(prefill)
        let sheet = SunriseAddHabitSheetView(
            viewModel: habitViewModel,
            onHabitCreated: onHabitCreated,
            onDismissWithoutHabit: onDismissWithoutTask
        )
        let hostingController = UIHostingController(rootView: AnyView(sheet.lifeboardLayoutClass(currentLayoutClass)))
        hostingController.modalPresentationStyle = .pageSheet
        if let sheetController = hostingController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        return hostingController
    }

    func makeOnboardingTaskDetailController(
        task: TaskDefinition,
        onDismiss: @escaping () -> Void
    ) -> UIViewController? {
        let detailView = makeTaskDetailView(for: task, containerMode: .sheet)
        let hostingController = UIHostingController(rootView: AnyView(detailView.lifeboardLayoutClass(currentLayoutClass)))
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas

        if isUsingIPadNativeShell {
            switch currentLayoutClass {
            case .padCompact, .padRegular, .padExpanded:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
            case .phone:
                hostingController.modalPresentationStyle = .pageSheet
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        let dismissBridge = OnboardingTaskDetailDismissBridge(onDismiss: onDismiss)
        hostingController.presentationController?.delegate = dismissBridge
        objc_setAssociatedObject(
            hostingController,
            &onboardingTaskDetailDismissBridgeKey,
            dismissBridge,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return hostingController
    }

    // MARK: - Navigation Actions

    /// Executes onMenuButtonTapped.
    @objc func onMenuButtonTapped() {
        let settingsVC = SettingsPageViewController()
        settingsVC.presentationDependencyContainer = presentationDependencyContainer
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.navigationBar.prefersLargeTitles = false
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navController, animated: true)
    }

    /// Executes AddTaskAction.
    @objc func AddTaskAction() {
        presentAddTaskFlow(suggestedDate: nil)
    }

    private func presentAddTaskFlow(suggestedDate: Date?) {
        if isUsingIPadNativeShell,
           currentLayoutClass == .padExpanded,
           suggestedDate == nil {
            iPadShellState.destination = .addTask
            return
        }

        if isUsingIPadNativeShell {
            presentAddTaskSheetForPadFallback(suggestedDate: suggestedDate)
            return
        }

        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
        applyTimelineSuggestedDate(suggestedDate, to: vm)
        let sheet = SunriseAddTaskSheetView(viewModel: vm)
        let hostingVC = UIHostingController(rootView: sheet)
        hostingVC.modalPresentationStyle = .pageSheet
        if let sheetController = hostingVC.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        let interval = LifeBoardPerformanceTrace.begin("AddTaskSheetOpen")
        present(hostingVC, animated: true) {
            LifeBoardPerformanceTrace.end(interval)
        }
    }

    private func presentAddTaskSheetForPadFallback(suggestedDate: Date? = nil) {
        guard isUsingIPadNativeShell else {
            presentAddTaskFlow(suggestedDate: suggestedDate)
            return
        }
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
        applyTimelineSuggestedDate(suggestedDate, to: vm)
        let sheet = SunriseAddTaskSheetView(viewModel: vm)
        let hostingVC = UIHostingController(rootView: sheet.lifeboardLayoutClass(currentLayoutClass))
        hostingVC.modalPresentationStyle = .formSheet
        hostingVC.preferredContentSize = CGSize(width: 540, height: 620)
        if let sheetController = hostingVC.sheetPresentationController {
            sheetController.detents = [.large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        viewModel?.trackHomeInteraction(
            action: "ipad_fallback_sheet_presented",
            metadata: [
                "layout_class": currentLayoutClass.rawValue,
                "surface": "add_task"
            ]
        )
        let interval = LifeBoardPerformanceTrace.begin("AddTaskSheetOpen")
        present(hostingVC, animated: true) {
            LifeBoardPerformanceTrace.end(interval)
        }
    }

    private func applyTimelineSuggestedDate(_ suggestedDate: Date?, to viewModel: AddTaskViewModel) {
        guard let suggestedDate else { return }
        viewModel.applyPrefill(
            AddTaskPrefillTemplate(
                title: "",
                dueDateIntent: .exact(suggestedDate),
                expandedSections: [.schedule],
                showMoreDetails: true
            )
        )
    }

    @objc private func openProjectCreator() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        if isUsingIPadNativeShell {
            iPadShellState.destination = .projects
            return
        }

        let viewModel = presentationDependencyContainer.makeProjectManagementViewModel()
        let rootView = SunriseProjectManagementView(viewModel: viewModel)
            .lifeboardLayoutClass(currentLayoutClass)
        let controller = UIHostingController(rootView: rootView)
        controller.title = "Projects"

        let navController = UINavigationController(rootViewController: controller)
        navController.navigationBar.prefersLargeTitles = false
        navController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(navController, animated: true)
    }

    @MainActor
    private func presentWeeklyPlanner() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }

        let weeklySummary = viewModel?.weeklySummary
        let referenceDate = weeklySummary?.weekStartDate ?? Date()
        let plannerPresentation = weeklySummary?.plannerPresentation ?? .thisWeek

        let plannerView = SunriseWeeklyPlannerView(
            viewModel: presentationDependencyContainer.makeWeeklyPlannerViewModel(
                referenceDate: referenceDate,
                plannerPresentation: plannerPresentation
            ),
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        .lifeboardLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: plannerView)
        hostingController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(hostingController, animated: true)
    }

    @MainActor
    private func presentWeeklyReview() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }

        let referenceDate = viewModel?.weeklySummary?.weekStartDate ?? Date()

        let reviewView = SunriseWeeklyReviewView(
            viewModel: presentationDependencyContainer.makeWeeklyReviewViewModel(referenceDate: referenceDate),
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            },
            onCompleted: { [weak self] message in
                self?.dismiss(animated: true) {
                    self?.viewModel?.refreshAfterWeeklyReviewCompletion()
                    self?.showHomeSnackbar(message: message)
                }
            }
        )
        .lifeboardLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: reviewView)
        hostingController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(hostingController, animated: true)
    }

    /// Executes searchButtonTapped.
    @objc func searchButtonTapped() {
        let presentSearch = { [weak self] in
            guard let self else { return }
            self.openSearch(source: "navigation_search_button")
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .search
            }
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                presentSearch()
            }
        } else {
            presentSearch()
        }
    }

    /// Executes chatButtonTapped.
    @objc func chatButtonTapped() {
        presentEvaChatScreen(source: "sunrise_chat_button")
    }

    private func resetHomeSelectionAfterEvaChatDismissalIfNeeded() {
        guard shouldResetHomeAfterEvaChatDismissal else { return }
        guard presentedViewController == nil else { return }
        resetHomeSelectionAfterEvaChatDismissal()
    }

    private func resetHomeSelectionAfterEvaChatDismissal() {
        shouldResetHomeAfterEvaChatDismissal = false
        presentedEvaChatController = nil
        faceCoordinator.setActiveFace(.tasks)
        faceCoordinator.bottomBarState.select(.home)
    }

    private func performEmbeddedChatDayTaskAction(
        _ action: EvaDayTaskAction,
        card: EvaDayTaskCard,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard let viewModel else {
            completion(.failure(embeddedChatError(code: 1, message: "Home view model unavailable")))
            return
        }

        switch action {
        case .done:
            viewModel.setTaskCompletion(taskID: card.taskID, to: true) { result in
                completion(result.map { _ in })
            }
        case .reopen:
            viewModel.setTaskCompletion(taskID: card.taskID, to: false) { result in
                completion(result.map { _ in })
            }
        case .tomorrow:
            let calendar = Calendar.current
            let baseDay = calendar.startOfDay(for: Date())
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseDay) else {
                completion(.failure(embeddedChatError(code: 2, message: "Could not compute tomorrow")))
                return
            }
            viewModel.rescheduleTask(taskID: card.taskID, to: tomorrow) { result in
                completion(result.map { _ in })
            }
        case .open:
            handleTaskTap(card.taskSnapshot)
            completion(.success(()))
        }
    }

    private func performEmbeddedChatDayHabitAction(
        _ action: EvaDayHabitAction,
        card: EvaDayHabitCard,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        if action == .open {
            handleHabitDetailDeepLink(habitID: card.habitID)
            completion(.success(()))
            return
        }

        guard let coordinator = presentationDependencyContainer?.coordinator else {
            completion(.failure(embeddedChatError(code: 3, message: "Coordinator unavailable")))
            return
        }

        let habitAction: HabitOccurrenceAction
        switch action {
        case .done:
            habitAction = .complete
        case .skip:
            habitAction = .skip
        case .stayedClean:
            habitAction = .abstained
        case .lapsed, .logLapse:
            habitAction = .lapsed
        case .open:
            handleHabitDetailDeepLink(habitID: card.habitID)
            completion(.success(()))
            return
        }

        coordinator.resolveHabitOccurrence.execute(
            habitID: card.habitID,
            action: habitAction,
            on: card.dueAt ?? Date()
        ) { [weak self] result in
            Task { @MainActor in
                if case .success = result {
                    self?.viewModel?.refreshCurrentScopeContent(source: "eva_chat_habit_action")
                }
                completion(result)
            }
        }
    }

    private func embeddedChatError(code: Int, message: String) -> NSError {
        NSError(
            domain: "HomeEmbeddedEvaChat",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    // MARK: - Task Routing

    /// Executes handleTaskTap.
    private func handleTaskTap(_ task: TaskDefinition) {
        if isUsingIPadNativeShell, currentLayoutClass == .padExpanded {
            iPadShellState.selectedTask = task
            return
        }
        presentTaskDetailView(for: task)
    }

    /// Executes handleTaskReschedule.
    private func handleTaskReschedule(_ task: TaskDefinition) {
        let rescheduleVC = RescheduleViewController(
            taskTitle: task.title,
            currentDueDate: task.dueDate
        ) { [weak self] (selectedDate: Date) in
            guard let self else { return }
            self.viewModel?.rescheduleTask(task, to: selectedDate)
        }

        let navController = UINavigationController(rootViewController: rescheduleVC)
        present(navController, animated: true)
    }

    /// Executes handleTaskDeleteRequested.
    private func handleTaskDeleteRequested(_ task: TaskDefinition) {
        guard let viewModel else { return }
        guard task.recurrenceSeriesID != nil else {
            viewModel.deleteTask(taskID: task.id) { _ in }
            return
        }

        presentRecurringTaskDeleteConfirmation(
            taskTitle: task.title,
            onDeleteSingle: { [viewModel] in
                viewModel.deleteTask(taskID: task.id, scope: .single) { _ in }
            },
            onDeleteSeries: { [viewModel] in
                viewModel.deleteTask(taskID: task.id, scope: .series) { _ in }
            }
        )
    }

    private func presentRecurringTaskDeleteConfirmation(
        taskTitle: String,
        onDeleteSingle: @escaping () -> Void,
        onDeleteSeries: @escaping () -> Void
    ) {
        let confirmationView = SunriseRecurringTaskDeleteConfirmationView(
            taskTitle: taskTitle,
            onDeleteSingle: onDeleteSingle,
            onDeleteSeries: onDeleteSeries
        )
        .lifeboardLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: confirmationView)
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
        }

        present(hostingController, animated: true)
    }

    private func presentTimelineAnchorDetail(for anchor: TimelineAnchorItem) {
        guard let selection = TimelineAnchorSelection(anchorID: anchor.id) else { return }
        viewModel?.trackHomeInteraction(
            action: "home_timeline_anchor_edit_opened",
            metadata: ["anchor": selection.rawValue, "layout_class": currentLayoutClass.rawValue]
        )

        let detailView = TimelineAnchorDetailSheetView(selection: selection)
        let hostingController = UIHostingController(rootView: detailView.lifeboardLayoutClass(currentLayoutClass))
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas

        if isUsingIPadNativeShell {
            hostingController.modalPresentationStyle = .formSheet
            hostingController.preferredContentSize = CGSize(width: 540, height: 520)
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        present(hostingController, animated: true)
    }

    /// Executes presentTaskDetailView.
    private func presentTaskDetailView(for task: TaskDefinition) {
        let detailView = makeTaskDetailView(for: task, containerMode: .sheet)

        let hostingController = UIHostingController(rootView: detailView.lifeboardLayoutClass(currentLayoutClass))
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if isUsingIPadNativeShell {
            switch currentLayoutClass {
            case .padCompact:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                viewModel?.trackHomeInteraction(
                    action: "ipad_task_detail_fallback_formsheet",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
                viewModel?.trackHomeInteraction(
                    action: "ipad_fallback_sheet_presented",
                    metadata: ["layout_class": currentLayoutClass.rawValue, "surface": "task_detail_formsheet"]
                )
            case .padRegular:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
                viewModel?.trackHomeInteraction(
                    action: "ipad_task_detail_fallback_formsheet",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
                viewModel?.trackHomeInteraction(
                    action: "ipad_fallback_sheet_presented",
                    metadata: ["layout_class": currentLayoutClass.rawValue, "surface": "task_detail_formsheet"]
                )
            case .padExpanded:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
            case .phone:
                hostingController.modalPresentationStyle = .pageSheet
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        let interval = LifeBoardPerformanceTrace.begin("TaskDetailOpen")
        present(hostingController, animated: true) {
            LifeBoardPerformanceTrace.end(interval)
        }
    }

    /// Executes makeTaskDetailView.
    private func makeTaskDetailView(
        for task: TaskDefinition,
        containerMode: TaskDetailContainerMode
    ) -> SunriseTaskDetailScreen {
        SunriseTaskDetailScreen(
            task: task,
            projects: viewModel?.projects ?? [],
            todayXPSoFar: {
                guard let viewModel else { return nil }
                return viewModel.progressState.earnedXP
            }(),
            isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
            containerMode: containerMode,
            onUpdate: { [weak self] taskID, request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.updateTask(taskID: taskID, request: request) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onSetCompletion: { [weak self] taskID, isComplete, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.setTaskCompletion(taskID: taskID, to: isComplete) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onDelete: { [weak self] taskID, scope, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.deleteTask(taskID: taskID, scope: scope) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onReschedule: { [weak self] taskID, date, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.rescheduleTask(taskID: taskID, to: date) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadMetadata: { [weak self] projectID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskDetailMetadata(projectID: projectID) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadRelationshipMetadata: { [weak self] projectID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 9,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskDetailRelationshipMetadata(projectID: projectID) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadChildren: { [weak self] parentTaskID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskChildren(parentTaskID: parentTaskID) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onCreateTask: { [weak self] request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 7,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createTaskDefinition(request: request) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onCreateTag: { [weak self] name, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 8,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createTagForTaskDetail(name: name) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onCreateProject: { [weak self] name, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 9,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createProjectForTaskDetail(name: name) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onSaveReflectionNote: { [weak self] note, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.saveReflectionNote(note) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadTaskFitHint: { [weak self] task, completion in
                Task { @MainActor [weak self] in
                    guard let self, let service = self.presentationDependencyContainer?.coordinator.calendarIntegrationService else {
                        completion(.unknown)
                        return
                    }
                    completion(service.taskFitHint(for: task))
                }
            }
        )
    }

    private func presentCalendarChooser() {
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else { return }
        let chooser = EventKitCalendarChooserContainerView(
            service: service,
            initialSelectedCalendarIDs: service.snapshot.selectedCalendarIDs,
            onCommit: { selectedIDs in
                service.updateSelectedCalendarIDs(selectedIDs)
            }
        )
        let host = UIHostingController(rootView: AnyView(chooser.lifeboardLayoutClass(currentLayoutClass)))
        host.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        host.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if let sheet = host.sheetPresentationController {
            let detents: [UISheetPresentationController.Detent] = [.medium(), .large()]
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
        }
        present(host, animated: true)
    }

    private func presentCalendarSchedule() {
        if isUsingIPadNativeShell {
            unwindActiveFaceForIPadDestination(source: "calendar_schedule_modal")
            iPadShellState.destination = .schedule
            return
        }
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else { return }
        let view = SunriseScheduleScreen(
            service: service,
            weekStartsOn: service.weekStartsOn,
            presentationMode: .modal,
            selectedDate: calendarScheduleSelectedDateBinding()
        )
        let host = UIHostingController(rootView: AnyView(view.lifeboardLayoutClass(currentLayoutClass)))
        host.modalPresentationStyle = currentLayoutClass.isPad
            ? UIModalPresentationStyle.pageSheet
            : UIModalPresentationStyle.fullScreen
        host.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if currentLayoutClass.isPad, let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
        }
        presentedCalendarScheduleController = host
        host.presentationController?.delegate = self
        present(host, animated: true)
    }

    private func handleFocusDeepLink() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        let preferredTask = viewModel?.focusTasks.first
            ?? viewModel?.morningTasks.first(where: { !$0.isComplete })
            ?? viewModel?.eveningTasks.first(where: { !$0.isComplete })
        startFocusFlow(task: preferredTask, source: "deeplink")
    }

    private func handleChatDeepLink(prompt: String?) {
        let launchRequest = EvaChatLaunchRequest(prompt: prompt)
        do {
            try EvaChatLaunchRequestStore.shared.submit(launchRequest)
        } catch {
            logError(
                event: "shortcut_chat_launch_request_store_failed",
                message: "Failed to persist Eva chat launch request",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }

        routeToChatSurface()
    }

    private func routeToChatSurface() {
        if isUsingIPadNativeShell {
            let routeToChat = { [weak self] in
                self?.iPadShellState.destination = .chat
            }

            if presentedViewController != nil {
                dismiss(animated: true) {
                    routeToChat()
                }
                return
            }

            routeToChat()
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.presentEvaChatScreen(source: "deeplink_chat")
            }
            return
        }

        presentEvaChatScreen(source: "deeplink_chat")
    }

    private func consumePendingShortcutHandoffIfNeeded() {
        if let action = PendingShortcutLaunchActionStore.shared.consumePendingAction() {
            handlePendingShortcutLaunchAction(action)
        }
        if let signal = ShortcutMutationSignalStore.shared.consumePendingSignal() {
            handlePendingShortcutMutationSignal(signal)
        }
    }

    private func handlePendingShortcutLaunchAction(_ action: PendingShortcutLaunchAction) {
        switch action.kind {
        case .askEva:
            handleChatDeepLink(prompt: action.prompt)
        case .startFocus:
            handleFocusDeepLink()
        }
    }

    private func handlePendingShortcutMutationSignal(_ signal: ShortcutMutationSignal) {
        switch signal.kind {
        case .taskCreated:
            faceCoordinator.recordSearchMutation()
            viewModel?.handleExternalMutation(reason: .created)
        }
    }

    private func handleHomeDeepLink(notice: String? = nil) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        viewModel?.setQuickView(.today)
        if let notice, notice.isEmpty == false {
            showHomeSnackbar(message: notice)
        }
    }

    private func handleInsightsDeepLink() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .analytics
        }
        viewModel?.launchInsights(.default)
    }

    private func handleTaskScopeDeepLink(scope: String, projectID: UUID?) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        switch scope {
        case "upcoming":
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.upcoming)
        case "overdue":
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.overdue)
        case "project":
            guard let projectID else {
                viewModel?.clearProjectFilters()
                viewModel?.setQuickView(.today)
                return
            }
            viewModel?.setQuickView(.today)
            viewModel?.setProjectFilters([projectID])
        default:
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.today)
        }
    }

    private func handleTaskDetailDeepLink(taskID: UUID) {
        viewModel?.setQuickView(.today)
        pendingNotificationFocusTaskID = taskID
        resolveAndPresentTaskDetail(taskID: taskID)
    }

    private func handleHabitBoardDeepLink() {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(name: .lifeboardPresentHabitBoard, object: nil)
        }
    }

    private func handleHabitLibraryDeepLink() {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(name: .lifeboardPresentHabitLibrary, object: nil)
        }
    }

    private func handleHabitDetailDeepLink(habitID: UUID) {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(
                name: .lifeboardPresentHabitDetail,
                object: nil,
                userInfo: ["habitID": habitID.uuidString]
            )
        }
    }

    private func routeToHabitDeepLinkDestination(_ completion: @escaping () -> Void) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        viewModel?.setQuickView(.today)

        if presentedViewController != nil {
            dismiss(animated: true) {
                Task { @MainActor in
                    completion()
                }
            }
            return
        }

        Task { @MainActor in
            completion()
        }
    }

    private func handleQuickAddDeepLink() {
        if isUsingIPadNativeShell {
            if presentedViewController != nil {
                dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    if self.currentLayoutClass == .padExpanded {
                        self.iPadShellState.destination = .addTask
                    } else {
                        self.presentAddTaskSheetForPadFallback()
                    }
                }
                return
            }
            if currentLayoutClass == .padExpanded {
                iPadShellState.destination = .addTask
            } else {
                presentAddTaskSheetForPadFallback()
            }
            return
        }
        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.AddTaskAction()
            }
            return
        }
        AddTaskAction()
    }

    private func handleCalendarScheduleDeepLink() {
        if isUsingIPadNativeShell {
            let routeToSchedule = { [weak self] in
                self?.iPadShellState.destination = .schedule
            }
            if presentedViewController != nil {
                dismiss(animated: true) {
                    routeToSchedule()
                }
                return
            }
            routeToSchedule()
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.openSchedule(source: "deeplink_schedule")
            }
            return
        }
        openSchedule(source: "deeplink_schedule")
    }

    private func handleCalendarChooserDeepLink() {
        let openChooser = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .schedule
            }
            self.presentCalendarChooser()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openChooser()
            }
            return
        }
        openChooser()
    }

    private func handleWeeklyPlannerDeepLink() {
        let openPlanner = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .tasks
            }
            self.viewModel?.setQuickView(.today)
            self.presentWeeklyPlanner()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openPlanner()
            }
            return
        }

        openPlanner()
    }

    private func handleWeeklyReviewDeepLink() {
        let openReview = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .tasks
            }
            self.viewModel?.setQuickView(.today)
            self.presentWeeklyReview()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openReview()
            }
            return
        }

        openReview()
    }

    private func processPendingWidgetActionCommand() {
        guard V2FeatureFlags.interactiveTaskWidgetsEnabled else { return }
        guard AppDelegate.isWriteClosed == false else { return }
        guard let command = TaskListWidgetActionCommand.loadPending() else { return }

        if command.expiresAt <= Date() {
            TaskListWidgetActionCommand.clearPending()
            return
        }

        processWidgetActionCommand(command, attemptsRemaining: 2)
    }

    private func processWidgetActionCommand(_ command: TaskListWidgetActionCommand, attemptsRemaining: Int) {
        guard let viewModel else { return }

        guard let task = viewModel.taskSnapshot(for: command.taskID) else {
            guard attemptsRemaining > 0 else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            viewModel.loadTodayTasks()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.processWidgetActionCommand(command, attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        switch command.action {
        case .complete:
            guard task.isComplete == false else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            viewModel.setTaskCompletion(taskID: task.id, to: true) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
            viewModel.setQuickView(.today)

        case .defer15m, .defer60m:
            guard task.isComplete == false else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            let deferMinutes = command.action == .defer15m ? 15 : 60
            let idempotenceThreshold = command.createdAt.addingTimeInterval(TimeInterval(max(deferMinutes - 1, 1) * 60))
            if let dueDate = task.dueDate, dueDate >= idempotenceThreshold {
                TaskListWidgetActionCommand.clearPending()
                return
            }

            let requestedDate = Date().addingTimeInterval(TimeInterval(deferMinutes * 60))
            let clampedDate = min(requestedDate, Date().addingTimeInterval(24 * 60 * 60))
            viewModel.rescheduleTask(taskID: task.id, to: clampedDate) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
            viewModel.setQuickView(.today)
        }
    }

    private func startFocusFlow(task: TaskDefinition?, source: String) {
        guard let viewModel else { return }
        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.startFocusFlow(task: task, source: source)
            }
            return
        }

        viewModel.startFocusSession(taskID: task?.id) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let session):
                    self.presentFocusTimer(task: task, session: session, source: source)
                case .failure(let error):
                    if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                        self.resumeActiveFocusSession(source: source)
                    } else {
                        logWarning(
                            event: "focus_session_start_failed",
                            message: "Failed to start focus session",
                            fields: [
                                "source": source,
                                "error": error.localizedDescription
                            ]
                        )
                    }
                }
            }
        }
    }

    private func resumeActiveFocusSession(source: String) {
        viewModel?.fetchActiveFocusSession { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let session):
                    guard let session else {
                        self.viewModel?.setQuickView(.today)
                        logWarning(
                            event: "focus_session_resume_missing",
                            message: "Expected an active focus session to resume, but none was found",
                            fields: ["source": source]
                        )
                        return
                    }

                    let task = self.resolveTaskForFocusSession(taskID: session.taskID)
                    self.presentFocusTimer(task: task, session: session, source: "\(source)_resume")
                case .failure(let error):
                    self.viewModel?.setQuickView(.today)
                    logWarning(
                        event: "focus_session_resume_failed",
                        message: "Failed to resume active focus session",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }
    }

    private func resolveTaskForFocusSession(taskID: UUID?) -> TaskDefinition? {
        guard let taskID else { return nil }
        var candidates: [TaskDefinition] = []
        candidates.append(contentsOf: viewModel?.focusTasks ?? [])
        candidates.append(contentsOf: viewModel?.morningTasks ?? [])
        candidates.append(contentsOf: viewModel?.eveningTasks ?? [])
        candidates.append(contentsOf: viewModel?.overdueTasks ?? [])
        return candidates.first(where: { $0.id == taskID })
    }

    private func presentFocusTimer(task: TaskDefinition?, session: FocusSessionDefinition, source: String) {
        let timerView = SunriseFocusTimerView(
            taskTitle: task?.title,
            taskPriority: task?.priority.displayName,
            targetDurationSeconds: session.targetDurationSeconds,
            onComplete: { [weak self] _ in
                self?.dismiss(animated: true) {
                    self?.finishFocusSession(sessionID: session.id, source: source)
                }
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true) {
                    self?.finishFocusSession(sessionID: session.id, source: "\(source)_cancel")
                }
            }
        )
        let host = UIHostingController(rootView: timerView)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }

    private func finishFocusSession(sessionID: UUID, source: String) {
        viewModel?.endFocusSession(sessionID: sessionID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let focusResult):
                    self.presentFocusSummary(focusResult)
                    self.viewModel?.trackHomeInteraction(
                        action: "focus_session_finished",
                        metadata: [
                            "source": source,
                            "duration_seconds": focusResult.session.durationSeconds,
                            "awarded_xp": focusResult.xpResult?.awardedXP ?? 0
                        ]
                    )
                case .failure(let error):
                    logWarning(
                        event: "focus_session_end_failed",
                        message: "Failed to end focus session",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }
    }

    private func presentFocusSummary(_ result: FocusSessionResult) {
        guard let viewModel else { return }
        let summaryView = SunriseFocusSessionSummaryView(
            durationSeconds: result.session.durationSeconds,
            xpAwarded: result.xpResult?.awardedXP ?? result.session.xpAwarded,
            dailyXPSoFar: result.xpResult?.dailyXPSoFar ?? viewModel.dailyScore,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            },
            onContinueMomentum: { [weak self] in
                self?.viewModel?.setQuickView(.today)
                self?.dismiss(animated: true)
            }
        )
        let host = UIHostingController(rootView: summaryView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(host, animated: true)
    }

    private func handleNotificationRoute(_ route: LifeBoardNotificationRoute) {
        guard viewModel != nil else { return }
        navigationCoordinator.handle(.notificationRoute(route))
    }

    private func resolveAndPresentTaskDetail(taskID: UUID, attemptsRemaining: Int = 2) {
        if let task = viewModel?.taskSnapshot(for: taskID) {
            if isUsingIPadNativeShell {
                iPadShellState.destination = .tasks
                if currentLayoutClass == .padExpanded {
                    iPadShellState.selectedTask = task
                } else {
                    presentTaskDetailView(for: task)
                }
            } else {
                presentTaskDetailView(for: task)
            }
            return
        }
        guard attemptsRemaining > 0 else { return }
        viewModel?.loadTodayTasks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.resolveAndPresentTaskDetail(taskID: taskID, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func presentDailySummaryModal(kind: LifeBoardDailySummaryKind, dateStamp: String?) {
        guard let viewModel else { return }

        let presentSummary: @Sendable (DailySummaryModalData) -> Void = { [weak self] summary in
            Task { @MainActor in
            guard let self else { return }
            let dismissSummary: (@escaping () -> Void) -> Void = { [weak self] completion in
                self?.dismiss(animated: true) {
                    self?.scheduleOnboardingEvaluationIfNeeded()
                    self?.onboardingCoordinator?.drainPendingPresentationIfPossible()
                    completion()
                }
            }

            let summaryView = DailySummaryModalView(
                summary: summary,
                onDismiss: {
                    dismissSummary {}
                },
                onStartToday: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_today", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_today", success: true, error: nil)
                    dismissSummary {}
                },
                onCompleteMorningRoutine: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "complete_morning_routine", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.completeMorningRoutine { result in
                        let succeeded: Bool
                        let errorDescription: String?
                        switch result {
                        case .success:
                            succeeded = true
                            errorDescription = nil
                        case .failure(let error):
                            succeeded = false
                            errorDescription = error.localizedDescription
                        }
                        Task { @MainActor in
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "complete_morning_routine",
                                success: succeeded,
                                errorDescription: errorDescription
                            )
                        }
                    }
                    dismissSummary {}
                },
                onStartTriage: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_triage", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.startTriage(scope: .visible)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_triage", success: true, error: nil)
                    dismissSummary {}
                },
                onRescueOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "rescue_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "rescue_overdue", success: true, error: nil)
                    dismissSummary {}
                },
                onAddTask: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "add_task", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.trackDailySummaryActionResult(cta: "add_task", success: true, error: nil)
                    dismissSummary {
                        self.AddTaskAction()
                    }
                },
                onPlanTomorrow: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "plan_tomorrow", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.performEndOfDayCleanup { result in
                        let succeeded: Bool
                        let errorDescription: String?
                        switch result {
                        case .success:
                            succeeded = true
                            errorDescription = nil
                        case .failure(let error):
                            succeeded = false
                            errorDescription = error.localizedDescription
                        }
                        Task { @MainActor in
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "plan_tomorrow",
                                success: succeeded,
                                errorDescription: errorDescription
                            )
                        }
                    }
                    dismissSummary {}
                },
                onReviewDone: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "review_done", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.done)
                    self.viewModel.trackDailySummaryActionResult(cta: "review_done", success: true, error: nil)
                    dismissSummary {}
                },
                onRescheduleOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "reschedule_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.rescheduleOverdueTasks { result in
                        let succeeded: Bool
                        let errorDescription: String?
                        switch result {
                        case .success:
                            succeeded = true
                            errorDescription = nil
                        case .failure(let error):
                            succeeded = false
                            errorDescription = error.localizedDescription
                        }
                        Task { @MainActor in
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "reschedule_overdue",
                                success: succeeded,
                                errorDescription: errorDescription
                            )
                        }
                    }
                    dismissSummary {}
                },
                onOpenRescue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "open_rescue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "open_rescue", success: true, error: nil)
                    dismissSummary {}
                }
            )

            let hostingController = UIHostingController(rootView: summaryView)
            hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
            hostingController.view.accessibilityIdentifier = "home.dailySummaryModal"
            hostingController.modalPresentationStyle = .pageSheet
            hostingController.presentationController?.delegate = self

            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }

            self.present(hostingController, animated: true)
            }
        }

        viewModel.loadDailySummaryModal(kind: kind, dateStamp: dateStamp) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .failure:
                    presentSummary(self.fallbackDailySummary(kind: kind, dateStamp: dateStamp))
                case .success(let summary):
                    presentSummary(summary)
                }
            }
        }
    }

    private func presentReflectPlanFlow(preferredReflectionDate: Date?) {
        guard let viewModel else { return }

        let reflectPlanViewModel = PresentationDependencyContainer.shared.makeDailyReflectPlanViewModel(
            preferredReflectionDate: preferredReflectionDate,
            analyticsTracker: { [weak self] action, metadata in
                self?.viewModel?.trackHomeInteraction(
                    action: action,
                    metadata: metadata.reduce(into: [String: Any]()) { partialResult, item in
                        partialResult[item.key] = item.value
                    }
                )
            },
            onComplete: { [weak self] result in
                self?.viewModel?.refreshAfterDailyReflectPlanSave(planningDate: result.target.planningDate)
                self?.dismiss(animated: true)
            }
        )

        let hostingController = UIHostingController(
            rootView: SunriseReflectPlanScreen(
                viewModel: reflectPlanViewModel,
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
        )

        if traitCollection.horizontalSizeClass == .compact {
            hostingController.modalPresentationStyle = .fullScreen
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }

        present(hostingController, animated: true)
        viewModel.trackHomeInteraction(
            action: "reflection_opened",
            metadata: ["source": "notification_nightly"]
        )
    }

    private func fallbackDailySummary(kind: LifeBoardDailySummaryKind, dateStamp: String?) -> DailySummaryModalData {
        let date = fallbackSummaryDate(from: dateStamp)
        switch kind {
        case .morning:
            return .morning(
                MorningPlanSummary(
                    date: date,
                    openTodayCount: 0,
                    highPriorityCount: 0,
                    overdueCount: 0,
                    potentialXP: 0,
                    focusTasks: [],
                    blockedCount: 0,
                    longTaskCount: 0,
                    morningPlannedCount: 0,
                    eveningPlannedCount: 0
                )
            )
        case .nightly:
            return .nightly(
                NightlyRetrospectiveSummary(
                    date: date,
                    completedCount: 0,
                    totalCount: 0,
                    xpEarned: 0,
                    completionRate: 0,
                    streakCount: 0,
                    biggestWins: [],
                    carryOverDueTodayCount: 0,
                    carryOverOverdueCount: 0,
                    tomorrowPreview: [],
                    morningCompletedCount: 0,
                    eveningCompletedCount: 0
                )
            )
        }
    }

    private func dateFromStamp(_ stamp: String?) -> Date? {
        guard let stamp, stamp.isEmpty == false else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        return formatter.date(from: stamp)
    }

    private func fallbackSummaryDate(from dateStamp: String?) -> Date {
        guard let dateStamp, dateStamp.count == 8 else { return Date() }
        var components = DateComponents()
        components.year = Int(dateStamp.prefix(4))
        components.month = Int(dateStamp.dropFirst(4).prefix(2))
        components.day = Int(dateStamp.suffix(2))
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Insights Refresh Contract

    /// Executes refreshInsightsAfterTaskCompletion.
    func refreshInsightsAfterTaskCompletion() {
        refreshInsightsAfterTaskMutation(reason: .completed)
    }

    /// Executes refreshInsightsAfterTaskMutation.
    func refreshInsightsAfterTaskMutation(reason: HomeTaskMutationEvent? = nil) {
        if let reason {
            logDebug("🎯 HomeViewController insights refresh reason=\(reason.rawValue)")
        }
        insightsViewModel?.refresh()
        faceCoordinator.insightsViewModel?.refresh()
    }

    // MARK: - Theme

    /// Executes applyTheme.
    private func applyTheme() {
        view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
    }
}

extension HomeViewController: HomeNavigationCoordinatorDelegate {
    func homeNavigationShowTasksDestination() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
    }

    func homeNavigationSetQuickView(_ quickView: HomeQuickView) {
        viewModel?.setQuickView(quickView)
    }

    func homeNavigationSetPendingNotificationFocusTaskID(_ taskID: UUID?) {
        pendingNotificationFocusTaskID = taskID
    }

    func homeNavigationResolveAndPresentTaskDetail(taskID: UUID) {
        guard viewModel != nil else { return }
        resolveAndPresentTaskDetail(taskID: taskID)
    }

    func homeNavigationOpenFocus() {
        guard viewModel != nil else { return }
        handleFocusDeepLink()
    }

    func homeNavigationOpenChat(prompt: String?) {
        guard viewModel != nil else { return }
        handleChatDeepLink(prompt: prompt)
    }

    func homeNavigationOpenHome(notice: String?) {
        guard viewModel != nil else { return }
        handleHomeDeepLink(notice: notice)
    }

    func homeNavigationOpenInsights() {
        guard viewModel != nil else { return }
        handleInsightsDeepLink()
    }

    func homeNavigationOpenTaskScope(scope: String, projectID: UUID?) {
        guard viewModel != nil else { return }
        handleTaskScopeDeepLink(scope: scope, projectID: projectID)
    }

    func homeNavigationOpenHabitBoard() {
        guard viewModel != nil else { return }
        handleHabitBoardDeepLink()
    }

    func homeNavigationOpenHabitLibrary() {
        guard viewModel != nil else { return }
        handleHabitLibraryDeepLink()
    }

    func homeNavigationOpenHabitDetail(habitID: UUID) {
        guard viewModel != nil else { return }
        handleHabitDetailDeepLink(habitID: habitID)
    }

    func homeNavigationOpenQuickAdd() {
        guard viewModel != nil else { return }
        handleQuickAddDeepLink()
    }

    func homeNavigationOpenCalendarSchedule() {
        guard viewModel != nil else { return }
        handleCalendarScheduleDeepLink()
    }

    func homeNavigationOpenCalendarChooser() {
        guard viewModel != nil else { return }
        handleCalendarChooserDeepLink()
    }

    func homeNavigationOpenWeeklyPlanner() {
        guard viewModel != nil else { return }
        handleWeeklyPlannerDeepLink()
    }

    func homeNavigationOpenWeeklyReview() {
        guard viewModel != nil else { return }
        handleWeeklyReviewDeepLink()
    }

    func homeNavigationProcessWidgetActionCommand() {
        guard viewModel != nil else { return }
        processPendingWidgetActionCommand()
    }

    func homeNavigationConsumePendingShortcutHandoff() {
        guard viewModel != nil else { return }
        consumePendingShortcutHandoffIfNeeded()
    }

    func homeNavigationConsumeUITestInjectedRoute() {
        guard viewModel != nil else { return }
        consumeUITestInjectedRouteIfNeeded()
    }

    func homeNavigationConsumeUITestOpenSettings() {
        consumeUITestOpenSettingsIfNeeded()
    }

    func homeNavigationProcessPendingIPadModalRequest() {
        guard viewModel != nil else { return }
        processPendingIPadModalRequest()
    }

    func homeNavigationPresentDailySummary(kind: LifeBoardDailySummaryKind, dateStamp: String?) {
        guard viewModel != nil else { return }
        presentDailySummaryModal(kind: kind, dateStamp: dateStamp)
    }

    func homeNavigationPresentReflectPlan(preferredReflectionDate: Date?) {
        guard viewModel != nil else { return }
        presentReflectPlanFlow(preferredReflectionDate: preferredReflectionDate)
    }

    func homeNavigationDate(from stamp: String?) -> Date? {
        dateFromStamp(stamp)
    }
}

extension HomeViewController: HomeNavigationEventAdapterDelegate {
    func homeNavigationEventAdapter(
        _ adapter: HomeNavigationEventAdapter,
        didReceive intent: HomeNavigationIntent
    ) {
        navigationCoordinator.handle(intent)
    }
}

extension HomeViewController: HomeReloadCoordinatorDelegate, HomeReloadEventAdapterDelegate {
    func homeReloadEventAdapter(
        _ adapter: HomeReloadEventAdapter,
        didReceive event: HomeReloadEvent
    ) {
        if case .appDidBecomeActive = event {
            onboardingEvaluationSceneToken &+= 1
            navigationCoordinator.handle(.pendingShortcutHandoff)
            scheduleOnboardingEvaluationIfNeeded()
        }
        reloadCoordinator.handle(event)
    }

    func homeReloadCoordinatorDidReceiveTaskMutation(_ mutation: HomeTaskMutationReloadEvent) {
        LifeBoardPerformanceTrace.event("HomeTaskMutationReloadEvent")
        if let reason = mutation.reason {
            logDebug("HOME_RELOAD_COORDINATOR mutation reason=\(reason.rawValue) source=\(mutation.source ?? "unknown")")
        }
    }

    func homeReloadCoordinatorRecordSearchMutation() {
        faceCoordinator.recordSearchMutation()
    }

    func homeReloadCoordinatorRefreshInsights(reason: HomeTaskMutationEvent?) {
        refreshInsightsAfterTaskMutation(reason: reason)
    }

    func homeReloadCoordinatorRefreshPersistentSyncMode() {
        refreshPersistentSyncOutageBanner()
    }

    func homeReloadCoordinatorRefreshWeeklySummary() {
        viewModel?.refreshWeeklySummaryNow()
    }

    func homeReloadCoordinatorRefreshCalendarContext(reason: String) {
        presentationDependencyContainer?.coordinator.calendarIntegrationService.refreshContext(reason: reason)
    }
}

// MARK: - Snackbar Support

extension HomeViewController {
    /// Executes observeTaskCreatedForSnackbar.
    func observeTaskCreatedForSnackbar() {
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
            .receive(on: RunLoop.main)
            .compactMap { $0.object as? TaskDefinition }
            .sink { [weak self] createdTask in
                self?.showTaskCreatedSnackbar(for: createdTask)
            }
            .store(in: &cancellables)
    }

    private func observeOnboardingRequests() {
        notificationCenter.publisher(for: .lifeboardStartOnboardingRequested)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.onboardingCoordinator?.restartOnboarding()
                self?.onboardingCoordinator?.drainPendingPresentationIfPossible()
            }
            .store(in: &cancellables)
    }

    /// Executes showTaskCreatedSnackbar.
    private func showTaskCreatedSnackbar(for task: TaskDefinition) {
        let taskID = task.id
        showHomeSnackbar(
            data: SnackbarData(
                message: "Task added.",
                actions: [
                    SnackbarAction(title: "Undo") { [weak self] in
                        self?.viewModel?.deleteTask(taskID: taskID) { _ in }
                    }
                ]
            )
        )
    }

    private func showHomeSnackbar(message: String) {
        showHomeSnackbar(data: SnackbarData(message: message, actions: []))
    }

    private func showHomeSnackbar(data: SnackbarData) {
        guard homeHostingController != nil else { return }

        let snackbar = LifeBoardSnackbar(data: data, onDismiss: {})
        let snackbarVC = UIHostingController(rootView: snackbar)
        snackbarVC.view.backgroundColor = .clear
        snackbarVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(snackbarVC)
        view.addSubview(snackbarVC.view)
        NSLayoutConstraint.activate([
            snackbarVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            snackbarVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            snackbarVC.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
        snackbarVC.didMove(toParent: self)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            snackbarVC.willMove(toParent: nil)
            snackbarVC.view.removeFromSuperview()
            snackbarVC.removeFromParent()
        }
    }
}

extension HomeViewController {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if presentationController.presentedViewController === presentedCalendarScheduleController {
            presentedCalendarScheduleController = nil
            faceCoordinator.bottomBarState.select(faceCoordinator.activeFace.selectedBottomBarItem)
        } else if presentationController.presentedViewController === presentedEvaChatController {
            resetHomeSelectionAfterEvaChatDismissal()
        }
        resetPendingIPadModalWaitState()
        processPendingIPadModalRequest()
        scheduleOnboardingEvaluationIfNeeded()
        onboardingCoordinator?.drainPendingPresentationIfPossible()
    }
}

#if DEBUG
extension HomeViewController {
    func testingSetAnalyticsVisible(with insightsViewModel: InsightsViewModel?) {
        self.insightsViewModel = insightsViewModel
        faceCoordinator.insightsViewModel = insightsViewModel
        faceCoordinator.setActiveFace(.analytics)
        faceCoordinator.setAnalyticsSurfaceState(insightsViewModel == nil ? .placeholder : .ready)
    }

    func testingHandleInsightsLaunchRequest(_ request: InsightsLaunchRequest?) {
        handleInsightsLaunchRequest(request)
    }

    var testingPendingInsightsLaunchRequest: InsightsLaunchRequest? {
        pendingInsightsLaunchRequest
    }

    func testingSetPendingOnboardingEvaluationTask() {
        pendingOnboardingEvaluationTask = Task {}
    }

    var testingHasPendingOnboardingEvaluationTask: Bool {
        pendingOnboardingEvaluationTask != nil
    }

    func testingSetOnboardingEvaluationSceneToken(_ token: Int) {
        onboardingEvaluationSceneToken = token
    }
}
#endif
