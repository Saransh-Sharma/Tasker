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

@MainActor var onboardingTaskDetailDismissBridgeKey: UInt8 = 0

final class HomeViewController: UIViewController, HomeViewControllerProtocol, PresentationDependencyContainerAware, UIAdaptivePresentationControllerDelegate {
    static let bottomBarVerticalLift: CGFloat = 6

    // MARK: - Dependencies

    var viewModel: HomeViewModel!
    var presentationDependencyContainer: PresentationDependencyContainer?

    // MARK: - UI

    var homeHostingController: UIHostingController<HomeHostRootView>?
    var bottomBarHostingController: UIHostingController<HomeBottomBarContainer>?
    var bottomBarBottomConstraint: NSLayoutConstraint?
    var bottomBarHeightConstraint: NSLayoutConstraint?
    weak var presentedCalendarScheduleController: UIViewController?
    weak var presentedEvaChatController: UIViewController?
    var shouldResetHomeAfterEvaChatDismissal = false
    var insightsViewModel: InsightsViewModel?
    let searchState = HomeSearchState()
    let chromeStore = HomeChromeStore()
    let tasksStore = HomeTasksStore()
    let habitsStore = HomeHabitsStore()
    let calendarStore = HomeCalendarStore()
    let timelineStore = HomeTimelineStore()
    let overlayStore = HomeOverlayStore()
    let faceCoordinator = HomeFaceCoordinator()
    let navigationCoordinator = HomeNavigationCoordinator()
    let navigationEventAdapter = HomeNavigationEventAdapter()
    let reloadCoordinator = HomeReloadCoordinator()
    let reloadEventAdapter = HomeReloadEventAdapter()
    let launchHarnessService = HomeLaunchHarnessService()
    let uiTestWorkspaceSeeder = HomeUITestWorkspaceSeeder()

    // MARK: - State

    let notificationCenter = NotificationCenter.default
    var cancellables = Set<AnyCancellable>()
    var pendingNotificationFocusTaskID: UUID?
    var syncOutageBanner: UIView?
    var syncOutageLabel: UILabel?
    var currentLayoutClass: LifeBoardLayoutClass = .phone
    let iPadShellState = HomeiPadShellState()
    let homeChatAppManager = AppManager()
    var iPadShellEpoch = 0
    var didTrackLayoutClassAtLaunch = false
    var didTrackIPadShellRendered = false
    var hasMountedStableLayoutShell = false
    var pendingIPadModalRequest: HomeiPadModalRequest?
    let onboardingGuidanceModel = HomeOnboardingGuidanceModel()
    var onboardingCoordinator: AppOnboardingCoordinator?
    var isEmbeddedChatRuntimeEntered = false
    var embeddedChatRuntimeGeneration = 0
    var pendingExitChatTask: Task<Void, Never>?
    var pendingInsightsLaunchRequest: InsightsLaunchRequest?
    var pendingInsightsPreparationTask: Task<Void, Never>?
    var pendingSearchPreparationTask: Task<Void, Never>?
    var pendingSearchWarmupTask: Task<Void, Never>?
    var pendingSearchMutationRefreshTask: Task<Void, Never>?
    var pendingBackgroundSearchPrewarmTask: Task<Void, Never>?
    var pendingBackgroundInsightsPrewarmTask: Task<Void, Never>?
    var pendingIPadModalPreviousPresentationDelegate: UIAdaptivePresentationControllerDelegate?
    var currentSnackbarViewController: UIViewController?
    var currentSnackbarDismissWorkItem: DispatchWorkItem?
    let surfacePrewarmPolicy = HomeSurfacePrewarmPolicy()
    var pendingOnboardingEvaluationTask: Task<Void, Never>?
    var awaitsAnalyticsFirstInteractiveFrame = false
    var retainedHomeSearchEngine: HomeSearchEngineAdapter?
    var onboardingEvaluationSceneToken: Int = 1
    var completedOnboardingEvaluationSceneToken: Int = 0
    var lastAppliedHomeRenderTransaction: HomeRenderTransaction = .empty
    var keyboardOverlapHeight: CGFloat = 0
    var isEmbeddedChatPromptFocused = false


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
                reflectPlanSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedUITestReflectPlanWorkspaceIfNeeded(
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
                },
                appStoreScreenshotSeed: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.uiTestWorkspaceSeeder.seedAppStoreScreenshotWorkspaceIfNeeded(
                        presentationDependencyContainer: self.presentationDependencyContainer,
                        viewModel: self.viewModel,
                        completion: completion
                    )
                }
            )
        ) { [weak self] in
            guard let self else { return }
            self.viewModel.invalidateTaskCaches()
            self.viewModel.loadTasksForSelectedDate()
            self.navigationCoordinator.handle(.uiTestInjectedRoute)
            self.scheduleOnboardingEvaluationIfNeeded()
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
    func injectDependenciesIfNeeded() {
        guard viewModel != nil else {
            fatalError("HomeViewController requires injected HomeViewModel")
        }
        guard presentationDependencyContainer != nil else {
            fatalError("HomeViewController requires injected PresentationDependencyContainer")
        }
    }

    /// Executes bindTheme.
    func bindTheme() {
        LifeBoardThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }

    /// Executes bindViewModel.
    func bindViewModel() {
        // HomeViewModel performs initial data loading in its initializer.
        // Keep this hook for future bindings, but avoid duplicate startup fetches.
    }

}
