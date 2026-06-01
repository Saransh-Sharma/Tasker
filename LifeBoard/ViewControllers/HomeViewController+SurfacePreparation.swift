//
//  HomeViewController+SurfacePreparation.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


extension HomeViewController {
    func bindRenderPipeline() {
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

    var isUsingIPadNativeShell: Bool {
        currentLayoutClass.isPad && V2FeatureFlags.iPadNativeShellEnabled
    }

    func calendarScheduleSelectedDateBinding() -> Binding<Date> {
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
    func refreshLayoutClassIfNeeded() {
        let nextLayoutClass = LifeBoardLayoutResolver.classify(view: view)
        guard nextLayoutClass != currentLayoutClass || homeHostingController == nil else { return }
        currentLayoutClass = nextLayoutClass
        mountHomeShell()
    }

    var hasStableLayoutMetrics: Bool {
        let metrics = LifeBoardLayoutResolver.metrics(for: view)
        return metrics.width > 1 && metrics.height > 1
    }

    func scheduleInsightsPreparationIfNeeded() {
        guard faceCoordinator.insightsViewModel == nil else {
            faceCoordinator.insightsViewModel?.onAppear()
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

    func scheduleOnboardingEvaluationIfNeeded() {
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

    func handleInsightsLaunchRequest(_ request: InsightsLaunchRequest?) {
        guard let request else { return }
        pendingInsightsLaunchRequest = request
        if faceCoordinator.activeFace == .analytics {
            scheduleInsightsPreparationIfNeeded()
            applyPendingInsightsLaunchRequestIfNeeded()
            return
        }
        openAnalytics(source: "launch_request", launchDefaultInsights: false)
    }

    func applyPendingInsightsLaunchRequestIfNeeded() {
        guard let request = pendingInsightsLaunchRequest else { return }
        guard let insightsViewModel = faceCoordinator.insightsViewModel else { return }
        pendingInsightsLaunchRequest = nil
        insightsViewModel.selectTab(request.targetTab)
        insightsViewModel.highlightAchievement(request.highlightedAchievementKey)
    }

    func trackFaceSelection(_ activeFace: HomeSunriseFace) {
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

    func setEmbeddedChatRuntimeVisible(_ isVisible: Bool, trigger: String) {
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

    func openSchedule(source: String) {
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

    func unwindActiveFaceForIPadDestination(source: String) {
        guard faceCoordinator.activeFace != .tasks else { return }
        returnToTasks(source: source)
    }

    func openAnalytics(source: String, launchDefaultInsights: Bool) {
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

    static func duration(nanoseconds: UInt64) -> Duration {
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

    func closeAnalytics(source: String) {
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

    func toggleInsights(source: String) {
        if faceCoordinator.activeFace == .analytics {
            closeAnalytics(source: source)
        } else {
            openAnalytics(source: source, launchDefaultInsights: true)
        }
    }

    func openSearch(source: String) {
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

    func closeSearch(source: String) {
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
        faceCoordinator.setActiveFace(faceCoordinator.returnFaceAfterSearch())
        faceCoordinator.setSearchSurfaceState(.idle)
        viewModel.trackHomeInteraction(
            action: "home_search_flip_close",
            metadata: ["source": source]
        )
    }

    func toggleSearch(source: String) {
        if faceCoordinator.activeFace == .search {
            closeSearch(source: source)
        } else {
            openSearch(source: source)
        }
    }

    func openChat(source: String) {
        presentEvaChatScreen(source: source)
    }

    func presentEvaChatScreen(source: String) {
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

    func closeChat(source: String) {
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

    func returnToTasks(source: String) {
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

    func handleTaskListChromeStateChange(_ state: HomeScrollChromeState) {
        faceCoordinator.bottomBarState.handleChromeStateChange(state)
    }

    func scheduleSearchPreparation() {
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

    func emitAnalyticsFirstInteractiveFrameIfNeeded() {
        guard awaitsAnalyticsFirstInteractiveFrame else { return }
        guard faceCoordinator.activeFace == .analytics else { return }
        guard faceCoordinator.analyticsSurfaceState == .ready else { return }
        awaitsAnalyticsFirstInteractiveFrame = false
        LifeBoardPerformanceTrace.event("HomeAnalyticsFirstInteractiveFrame")
    }

    func scheduleBackgroundSurfacePrewarmIfNeeded() {
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

    func cancelBackgroundSurfacePrewarm() {
        cancelBackgroundSearchPrewarm()
        cancelBackgroundInsightsPrewarm()
    }

    func cancelBackgroundSearchPrewarm() {
        pendingBackgroundSearchPrewarmTask?.cancel()
        pendingBackgroundSearchPrewarmTask = nil
    }

    func cancelBackgroundInsightsPrewarm() {
        pendingBackgroundInsightsPrewarmTask?.cancel()
        pendingBackgroundInsightsPrewarmTask = nil
    }

    @discardableResult
    func prepareInsightsViewModelIfNeeded() -> InsightsViewModel {
        if let existing = faceCoordinator.insightsViewModel {
            insightsViewModel = existing
            return existing
        }

        let resolvedViewModel = viewModel.makeInsightsViewModel()
        insightsViewModel = resolvedViewModel
        faceCoordinator.insightsViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func resolveHomeSearchEngine() -> HomeSearchEngineAdapter {
        if let retainedHomeSearchEngine {
            return retainedHomeSearchEngine
        }
        let engine = HomeSearchEngineAdapter(viewModel: viewModel.makeHomeSearchViewModel())
        retainedHomeSearchEngine = engine
        return engine
    }

    func scheduleInitialSearchWarmupIfNeeded() {
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

    func handleSearchMutationRevision() {
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

}
