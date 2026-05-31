//
//  HomeViewController+RenderPipeline.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


extension HomeViewController {
    func computeHomeLayoutMetrics() -> HomeLayoutMetrics {
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

    func refreshLayoutMetrics() {
        faceCoordinator.setLayoutMetrics(computeHomeLayoutMetrics())
    }

    func configureSafeAreaRegions(for hostingController: UIHostingController<HomeHostRootView>) {
        hostingController.safeAreaRegions = currentLayoutClass == .phone ? .container : .all
    }

    func updateInteractivePhaseIfNeeded() {
        let layoutMetrics = faceCoordinator.layoutMetrics
        let tasksState = tasksStore.snapshot
        if faceCoordinator.shellPhase == .startup,
           layoutMetrics.isReady,
           tasksState.hasCommittedInitialContent {
            faceCoordinator.setShellPhase(.interactive)
        }
    }

    func applyHomeRenderTransaction(_ transaction: HomeRenderTransaction) {
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

    func applyOverlayState(_ state: HomeOverlayState) {
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

    func mountBottomBarOverlayIfNeeded(animated: Bool = true) {
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

    func applyBottomBarConcealmentState() {
        guard let bottomBarHostingController else { return }
        let isConcealed = isBottomBarConcealedForChatInput
        bottomBarHostingController.view.alpha = isConcealed ? 0 : 1
        bottomBarHostingController.view.isUserInteractionEnabled = !isConcealed
        bottomBarHostingController.view.accessibilityElementsHidden = isConcealed
    }

    func resolvedBottomBarHostHeight() -> CGFloat {
        guard currentLayoutClass == .phone else { return 0 }
        return HomeBottomBarVisibilityPolicy.phoneDockHostHeight
    }

    func updateBottomBarHeightConstraint() {
        guard let bottomBarHeightConstraint else { return }
        let height = resolvedBottomBarHostHeight()
        guard abs(bottomBarHeightConstraint.constant - height) > 0.5 else { return }
        bottomBarHeightConstraint.constant = height
    }

    func makeBottomBarRoot() -> HomeBottomBarContainer {
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

    func resolvedBottomBarDownshift() -> CGFloat {
        guard currentLayoutClass == .phone else { return 0 }
        let restingDownshift = HomeBottomBarVisibilityPolicy.restingDockDownshift(
            safeAreaBottom: view.safeAreaInsets.bottom,
            verticalLift: Self.bottomBarVerticalLift
        )
        guard isBottomBarConcealedForChatInput else { return restingDownshift }

        let tokens = LifeBoardThemeManager.shared.tokens(for: currentLayoutClass)
        return restingDownshift + resolvedBottomBarHostHeight() + tokens.spacing.s16
    }

    func updateBottomBarBottomConstraint(animated: Bool = true) {
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
    func mountHomeShell() {
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
    func makeHomeBackdropRoot(
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
    func makeIPadSplitRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
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

    func makeAddTaskInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
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

    func makeCalendarScheduleInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
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

    func makeSettingsInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
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

    func makeLifeManagementInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Life Management unavailable").font(.lifeboard(.body)))
        }
        let vm = presentationDependencyContainer.makeLifeManagementViewModel()
        return AnyView(
            LifeManagementView(viewModel: vm)
                .lifeboardLayoutClass(layoutClass)
        )
    }

    func makeProjectManagementInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Projects unavailable").font(.lifeboard(.body)))
        }
        let vm = presentationDependencyContainer.makeProjectManagementViewModel()
        return AnyView(
            SunriseProjectManagementView(viewModel: vm)
                .lifeboardLayoutClass(layoutClass)
        )
    }

    func makeChatInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
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

    func makeModelsInspectorRoot(layoutClass: LifeBoardLayoutClass) -> AnyView {
        AnyView(
            NavigationStack {
                ModelsSettingsView()
                    .environmentObject(homeChatAppManager)
                    .environment(LLMRuntimeCoordinator.shared.evaluator)
            }
            .lifeboardLayoutClass(layoutClass)
        )
    }

    func makeTaskInspectorRoot(_ task: TaskDefinition, layoutClass: LifeBoardLayoutClass) -> AnyView {
        AnyView(
            makeTaskDetailView(for: task, containerMode: .inspector)
                .lifeboardLayoutClass(layoutClass)
        )
    }

    func trackLayoutClassAtLaunchIfNeeded() {
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

    func trackIPadShellRenderedIfNeeded() {
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

    func observeIPadShellTelemetry() {
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

}
