//
//  HomeViewController.swift
//  To Do List
//
//  SwiftUI host for Home screen with backdrop/foredrop shell.
//

import UIKit
import SwiftUI
import Combine
import DGCharts

private final class SnackbarPassthroughContainerView: UIView {
    weak var interactiveView: UIView?

    /// Executes point.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let interactiveView else { return false }
        let converted = convert(point, to: interactiveView)
        return interactiveView.point(inside: converted, with: event)
    }
}

private struct QueuedSnackbarPresentation {
    let snackbar: TaskerSnackbar
    let token: UUID
    let preferredHeight: CGFloat?
    let source: String
}

final class HomeViewController: UIViewController, HomeViewControllerProtocol, HomeAnalyticsViewModelsInjectable, PresentationDependencyContainerAware {

    // MARK: - Dependencies

    var viewModel: HomeViewModel!
    var chartCardViewModel: ChartCardViewModel!
    var radarChartCardViewModel: RadarChartCardViewModel!
    var presentationDependencyContainer: PresentationDependencyContainer?

    // MARK: - UI

    private var homeHostingController: UIHostingController<HomeBackdropForedropRootView>?

    // Tiny pie chart / nav XP state
    lazy var tinyPieChartView: PieChartView = { PieChartView() }()
    private var navigationPieChartView: PieChartView?
    private weak var navigationPieChartAnchorView: UIView?
    private let navigationPieChartSize: CGFloat = 136
    private let navigationPieChartTrailingInset: CGFloat = 10
    private let navigationPieChartZPosition: CGFloat = 999
    private let isNavigationPieChartEnabled = false
    private var shouldShowNavigationPieChart = false
    private var foredropSettingsButtonGlobalFrame: CGRect = .null
    private var navigationPieChartCenterXConstraint: NSLayoutConstraint?

    // MARK: - State

    private let notificationCenter = NotificationCenter.default
    private var cancellables = Set<AnyCancellable>()
    private var pendingCreateRetryRequests: [UUID: CreateTaskDefinitionRequest] = [:]
    private var pendingCreateStartedAtByTaskID: [UUID: Date] = [:]
    private var activeSnackbarContainerView: SnackbarPassthroughContainerView?
    private var activeSnackbarHostController: UIHostingController<TaskerSnackbar>?
    private var activeSnackbarHeightConstraint: NSLayoutConstraint?
    private var activeSnackbarCleanupWorkItem: DispatchWorkItem?
    private var activeSnackbarToken: UUID?
    private var queuedSnackbarPresentation: QueuedSnackbarPresentation?
    private let standardTaskCreatedSnackbarHeight: CGFloat = 72
    private var pendingChartRefreshWorkItem: DispatchWorkItem?
    private let chartRefreshDebounceSeconds: TimeInterval = 0.12

    var shouldHideData = false
    var dateForTheView = Date.today()
    var todoColors: TaskerColorTokens = TaskerThemeManager.shared.currentTheme.tokens.color

    // MARK: - Lifecycle

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()

        injectDependenciesIfNeeded()
        configureNavigationBar()
        bindTheme()
        bindViewModel()
        mountHomeShell()
        observeMutations()
        observeAssistantChatRequests()
        observeTaskCreateOptimisticStart()
        observeTaskCreatedForSnackbar()
        observeTaskCreateRollbackForRetry()

        updateDailyScore(for: dateForTheView)
    }

    /// Executes viewDidLayoutSubviews.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if navigationPieChartView != nil {
            layoutNavigationPieChart()
        }
    }

    /// Executes viewDidAppear.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ensureNavigationPieChartAsRightItem()
        layoutNavigationPieChart()
    }

    /// Executes viewDidDisappear.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if navigationController?.topViewController !== self {
            removeNavigationPieChartOverlay(resetChartState: true)
            teardownSnackbarPresenter()
        }
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    // MARK: - Setup

    /// Executes injectDependenciesIfNeeded.
    private func injectDependenciesIfNeeded() {
        guard viewModel != nil else {
            fatalError("HomeViewController requires injected HomeViewModel")
        }
        guard chartCardViewModel != nil else {
            fatalError("HomeViewController requires injected ChartCardViewModel")
        }
        guard radarChartCardViewModel != nil else {
            fatalError("HomeViewController requires injected RadarChartCardViewModel")
        }
        guard presentationDependencyContainer != nil else {
            fatalError("HomeViewController requires injected PresentationDependencyContainer")
        }
    }

    /// Executes configureNavigationBar.
    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: todoColors.accentOnPrimary]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = false

        // Pie chart on the right
        ensureNavigationPieChartAsRightItem()

        // Date header with XP as title view
        updateNavigationDateHeader()
    }

    /// Executes bindTheme.
    private func bindTheme() {
        TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }

    /// Executes bindViewModel.
    private func bindViewModel() {
        guard let viewModel else { return }

        viewModel.$selectedDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedDate in
                self?.dateForTheView = selectedDate
                self?.updateDailyScore(for: selectedDate)
            }
            .store(in: &cancellables)

        viewModel.$dailyScore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] score in
                guard let self else { return }
                if Calendar.current.isDateInToday(self.dateForTheView) {
                    self.applyScoreDisplay(score, for: self.dateForTheView)
                }
            }
            .store(in: &cancellables)

        viewModel.$progressState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNavigationDateHeader()
            }
            .store(in: &cancellables)

        if !viewModel.focusEngineEnabled {
            viewModel.loadTodayTasks()
        }

        viewModel.loadProjects()
        viewModel.loadTodayTasks()
    }

    /// Executes mountHomeShell.
    private func mountHomeShell() {
        guard let viewModel else { return }

        let root = HomeBackdropForedropRootView(
            viewModel: viewModel,
            chartCardViewModel: chartCardViewModel,
            radarChartCardViewModel: radarChartCardViewModel,
            onTaskTap: { [weak self] task in
                self?.handleTaskTap(task)
            },
            onToggleComplete: { [weak self] task in
                self?.viewModel?.toggleTaskCompletion(task)
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
            onAddTask: { [weak self] in
                self?.AddTaskAction()
            },
            onOpenSearch: { [weak self] in
                self?.searchButtonTapped()
            },
            onOpenChat: { [weak self] in
                self?.chatButtonTapped()
            },
            onOpenProjectCreator: { [weak self] in
                self?.openProjectCreator()
            },
            onOpenSettings: { [weak self] in
                self?.onMenuButtonTapped()
            },
            onSettingsButtonFrameChange: { [weak self] frame in
                guard let self else { return }
                if self.foredropSettingsButtonGlobalFrame.integral == frame.integral {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.foredropSettingsButtonGlobalFrame = frame
                    self.layoutNavigationPieChart()
                }
            }
        )

        let hostingController = UIHostingController(rootView: root)
        homeHostingController?.willMove(toParent: nil)
        homeHostingController?.view.removeFromSuperview()
        homeHostingController?.removeFromParent()

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
    }

    /// Executes observeMutations.
    private func observeMutations() {
        notificationCenter.addObserver(
            self,
            selector: #selector(homeTaskMutationReceived(_:)),
            name: .homeTaskMutation,
            object: nil
        )
    }

    /// Executes observeAssistantChatRequests.
    private func observeAssistantChatRequests() {
        notificationCenter.addObserver(
            self,
            selector: #selector(assistantOpenChatRequested(_:)),
            name: .assistantOpenChatRequested,
            object: nil
        )
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
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
        let sheet = AddTaskSheetView(viewModel: vm)
        let hostingVC = UIHostingController(rootView: sheet)
        hostingVC.modalPresentationStyle = .pageSheet
        if let sheetController = hostingVC.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(hostingVC, animated: true)
    }

    @objc private func openProjectCreator() {
        let controller = NewProjectViewController()
        let navController = UINavigationController(rootViewController: controller)
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        presentationDependencyContainer.inject(into: controller)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    /// Executes searchButtonTapped.
    @objc func searchButtonTapped() {
        let searchVC = LGSearchViewController()
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        presentationDependencyContainer.inject(into: searchVC)
        searchVC.modalPresentationStyle = .fullScreen
        searchVC.modalTransitionStyle = .crossDissolve
        present(searchVC, animated: true)
    }

    /// Executes chatButtonTapped.
    @objc func chatButtonTapped() {
        let chatHostVC = ChatHostViewController()
        let navController = UINavigationController(rootViewController: chatHostVC)
        navController.modalPresentationStyle = .fullScreen
        navController.navigationBar.prefersLargeTitles = false
        present(navController, animated: true)
    }

    /// Executes assistantOpenChatRequested.
    @objc private func assistantOpenChatRequested(_ notification: Notification) {
        guard presentedViewController == nil else { return }
        chatButtonTapped()
    }

    // MARK: - Task Routing

    /// Executes handleTaskTap.
    private func handleTaskTap(_ task: TaskDefinition) {
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

        let alert = UIAlertController(
            title: "Delete recurring task?",
            message: "Choose whether to delete only this task or every task in the series.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete This Task", style: .destructive) { _ in
            viewModel.deleteTask(taskID: task.id, scope: .single) { _ in }
        })
        alert.addAction(UIAlertAction(title: "Delete Entire Series", style: .destructive) { _ in
            viewModel.deleteTask(taskID: task.id, scope: .series) { _ in }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    /// Executes presentTaskDetailView.
    private func presentTaskDetailView(for task: TaskDefinition) {
        let detailView = TaskDetailSheetView(
            task: task,
            projects: viewModel?.projects ?? [],
            onUpdate: { [weak self] taskID, request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.updateTask(taskID: taskID, request: request, completion: completion)
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
                viewModel.setTaskCompletion(taskID: taskID, to: isComplete, completion: completion)
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
                viewModel.deleteTask(taskID: taskID, scope: scope, completion: completion)
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
                viewModel.rescheduleTask(taskID: taskID, to: date, completion: completion)
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
                viewModel.loadTaskDetailMetadata(projectID: projectID, completion: completion)
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
                viewModel.loadTaskChildren(parentTaskID: parentTaskID, completion: completion)
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
                viewModel.createTaskDefinition(request: request, completion: completion)
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
                viewModel.createTagForTaskDetail(name: name, completion: completion)
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
                viewModel.createProjectForTaskDetail(name: name, completion: completion)
            }
        )

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(hostingController, animated: true)
    }

    // MARK: - Chart Refresh Contract

    /// Executes refreshChartsAfterTaskCompletion.
    func refreshChartsAfterTaskCompletion() {
        refreshChartsAfterTaskMutation(reason: .completed)
    }

    /// Executes refreshChartsAfterTaskMutation.
    func refreshChartsAfterTaskMutation(reason: HomeTaskMutationEvent? = nil) {
        if let reason {
            logDebug("🎯 HomeViewController chart refresh reason=\(reason.rawValue)")
        }

        updateTinyPieChartData()
        refreshNavigationPieChart()
        updateDailyScore(for: dateForTheView)
    }

    @objc private func homeTaskMutationReceived(_ notification: Notification) {
        let reasonRaw = notification.userInfo?["reason"] as? String
        let reason = reasonRaw.flatMap(HomeTaskMutationEvent.init(rawValue:))

        pendingChartRefreshWorkItem?.cancel()
        let refreshWorkItem = DispatchWorkItem { [weak self] in
            self?.refreshChartsAfterTaskMutation(reason: reason)
        }
        pendingChartRefreshWorkItem = refreshWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + chartRefreshDebounceSeconds, execute: refreshWorkItem)
    }

    // MARK: - Score / Tiny Pie

    /// Executes calculateTodaysScore.
    func calculateTodaysScore() -> Int {
        let targetDate = dateForTheView
        let doneTasks = viewModel?.completedTasks ?? []
        let calendar = Calendar.current
        return doneTasks.reduce(0) { partial, task in
            let referenceDate = task.dateCompleted ?? task.dueDate
            guard let referenceDate, calendar.isDate(referenceDate, inSameDayAs: targetDate) else {
                return partial
            }
            return partial + task.priority.scorePoints
        }
    }

    /// Executes priorityBreakdown.
    func priorityBreakdown(for date: Date) -> [Int32: Int] {
        var counts: [Int32: Int] = [1: 0, 2: 0, 3: 0, 4: 0]

        let completedTasks = viewModel?.completedTasks ?? []
        let currentCalendar = Calendar.current
        for task in completedTasks {
            let referenceDate = task.dateCompleted ?? task.dueDate
            guard let referenceDate, currentCalendar.isDate(referenceDate, inSameDayAs: date) else { continue }
            let normalizedPriority = TaskPriorityConfig.normalizePriority(Int32(task.priority.rawValue))
            counts[normalizedPriority, default: 0] += 1
        }

        return counts
    }

    /// Executes updateDailyScore.
    func updateDailyScore(for date: Date? = nil) {
        let targetDate = date ?? dateForTheView

        if let viewModel, Calendar.current.isDateInToday(targetDate) {
            applyScoreDisplay(viewModel.dailyScore, for: targetDate)
            return
        }

        applyScoreDisplay(calculateTodaysScore(), for: targetDate)
    }

    /// Executes applyScoreDisplay.
    private func applyScoreDisplay(_ score: Int, for date: Date) {
        // Always show the nav pie chart (even at score 0 with empty ring)
        ensureNavigationPieChartAsRightItem()

        tinyPieChartView.centerAttributedText = setTinyPieChartScoreText(
            pieChartView: tinyPieChartView,
            scoreOverride: score
        )

        if let navChart = navigationPieChartView {
            navChart.centerAttributedText = setTinyPieChartScoreText(
                pieChartView: navChart,
                scoreOverride: score
            )
            buildNavigationPieChartData(for: date)
        }

        // Update date header when date changes
        updateNavigationDateHeader()
    }

    // MARK: - Nav Pie UI

    /// Executes setNavigationPieChartVisible.
    private func setNavigationPieChartVisible(_ isVisible: Bool) {
        shouldShowNavigationPieChart = isVisible

        if isVisible {
            ensureNavigationPieChartAsRightItem()
            navigationPieChartAnchorView?.isHidden = false
            navigationPieChartView?.isHidden = false
            navigationPieChartView?.alpha = 1
            return
        }

        navigationItem.rightBarButtonItem = nil
        removeNavigationPieChartOverlay(resetChartState: true)
    }

    /// Executes ensureNavigationPieChartAsRightItem.
    private func ensureNavigationPieChartAsRightItem() {
        guard isNavigationPieChartEnabled else {
            navigationItem.rightBarButtonItem = nil
            removeNavigationPieChartOverlay(resetChartState: true)
            return
        }

        guard let navigationController else { return }
        navigationItem.rightBarButtonItem = nil

        if let container = navigationPieChartAnchorView,
           navigationPieChartView != nil,
           container.superview === navigationController.view {
            layoutNavigationPieChart()
            return
        }

        removeNavigationPieChartOverlay(resetChartState: true)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.clipsToBounds = false
        container.accessibilityIdentifier = "home.navXpPieChart.container"
        container.layer.zPosition = navigationPieChartZPosition
        navigationController.view.addSubview(container)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: navigationPieChartSize),
            container.heightAnchor.constraint(equalToConstant: navigationPieChartSize),
            container.centerYAnchor.constraint(equalTo: navigationController.navigationBar.centerYAnchor)
        ])
        let centerXConstraint = container.centerXAnchor.constraint(
            equalTo: navigationController.view.leadingAnchor,
            constant: defaultNavigationPieChartCenterX(in: navigationController)
        )
        navigationPieChartCenterXConstraint = centerXConstraint
        centerXConstraint.isActive = true

        let buttonProxy = UIView()
        buttonProxy.translatesAutoresizingMaskIntoConstraints = false
        buttonProxy.backgroundColor = .clear
        buttonProxy.isUserInteractionEnabled = false
        buttonProxy.accessibilityIdentifier = "home.navXpPieChart.button"
        container.addSubview(buttonProxy)

        let pieChart = PieChartView()
        pieChart.translatesAutoresizingMaskIntoConstraints = false
        pieChart.backgroundColor = .clear
        pieChart.accessibilityIdentifier = "home.navXpPieChart"
        pieChart.accessibilityLabel = "XP chart"
        setupPieChartView(pieChartView: pieChart)

        container.addSubview(pieChart)

        NSLayoutConstraint.activate([
            buttonProxy.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            buttonProxy.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonProxy.topAnchor.constraint(equalTo: container.topAnchor),
            buttonProxy.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pieChart.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pieChart.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pieChart.topAnchor.constraint(equalTo: container.topAnchor),
            pieChart.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        navigationPieChartView = pieChart
        navigationPieChartAnchorView = container

        buildNavigationPieChartData(for: dateForTheView)
        layoutNavigationPieChart()
    }

    /// Executes updateNavigationDateHeader.
    private func updateNavigationDateHeader() {
        let dateView = HomeDateHeaderView(
            date: dateForTheView,
            progressState: viewModel?.progressState ?? .empty,
            accentOnPrimaryColor: todoColors.accentOnPrimary
        )
        let hostingController = UIHostingController(rootView: dateView)
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.sizingOptions = UIHostingControllerSizingOptions.intrinsicContentSize
        hostingController.view.sizeToFit()
        navigationItem.titleView = hostingController.view
    }

    /// Executes layoutNavigationPieChart.
    private func layoutNavigationPieChart() {
        guard let pieChart = navigationPieChartView, let container = navigationPieChartAnchorView else { return }
        let didUpdateAlignment = updateNavigationPieChartHorizontalAlignment()
        if didUpdateAlignment {
            navigationController?.view.layoutIfNeeded()
        }
        container.layer.zPosition = navigationPieChartZPosition
        navigationController?.view.bringSubviewToFront(container)
        container.layoutIfNeeded()
        pieChart.layoutIfNeeded()
        setTinyChartShadow(chartView: pieChart)
    }

    /// Executes removeNavigationPieChartOverlay.
    private func removeNavigationPieChartOverlay(resetChartState: Bool) {
        navigationPieChartAnchorView?.removeFromSuperview()
        if resetChartState {
            navigationPieChartView = nil
            navigationPieChartAnchorView = nil
            navigationPieChartCenterXConstraint = nil
        }
    }

    /// Executes defaultNavigationPieChartCenterX.
    private func defaultNavigationPieChartCenterX(in navigationController: UINavigationController) -> CGFloat {
        let fallbackByNavBar = navigationController.navigationBar.frame.maxX - navigationPieChartTrailingInset - (navigationPieChartSize / 2)
        guard let navigationView = navigationController.view else {
            return max(fallbackByNavBar, navigationPieChartSize / 2)
        }
        if fallbackByNavBar > 0 {
            return fallbackByNavBar
        }
        return navigationView.bounds.width - navigationView.safeAreaInsets.right - navigationPieChartTrailingInset - (navigationPieChartSize / 2)
    }

    /// Executes updateNavigationPieChartHorizontalAlignment.
    @discardableResult
    private func updateNavigationPieChartHorizontalAlignment() -> Bool {
        guard let navigationController,
              let centerXConstraint = navigationPieChartCenterXConstraint,
              let navigationView = navigationController.view,
              navigationView.bounds.width > 0 else { return false }

        let targetCenterX: CGFloat
        if !foredropSettingsButtonGlobalFrame.isNull, !foredropSettingsButtonGlobalFrame.isEmpty {
            let settingsFrameInNavigationView = navigationView.convert(foredropSettingsButtonGlobalFrame, from: nil)
            targetCenterX = settingsFrameInNavigationView.midX
        } else {
            targetCenterX = defaultNavigationPieChartCenterX(in: navigationController)
        }

        let minCenterX = navigationView.safeAreaInsets.left + (navigationPieChartSize / 2)
        let maxCenterX = max(minCenterX, navigationView.bounds.width - navigationView.safeAreaInsets.right - (navigationPieChartSize / 2))
        let clampedCenterX = min(max(targetCenterX, minCenterX), maxCenterX)
        guard abs(centerXConstraint.constant - clampedCenterX) > 0.5 else { return false }
        centerXConstraint.constant = clampedCenterX
        return true
    }

    /// Executes buildNavigationPieChartData.
    private func buildNavigationPieChartData(for date: Date) {
        guard let navPieChart = navigationPieChartView else { return }

        let breakdown = priorityBreakdown(for: date)

        // Build entries with priority info for color mapping (no labels to prevent rendering)
        typealias PriorityEntry = (entry: PieChartDataEntry, priority: Int32)
        let priorityEntries: [PriorityEntry] = [Int32(1), Int32(2), Int32(3), Int32(4)].compactMap { priorityRaw in
            let rawCount = Double(breakdown[priorityRaw] ?? 0)
            let weight = TaskPriorityConfig.chartWeightForPriority(priorityRaw)
            let weightedValue = rawCount * weight
            // Note: No label to prevent any text from rendering
            guard weightedValue > 0 else { return nil }
            return PriorityEntry(entry: PieChartDataEntry(value: weightedValue), priority: priorityRaw)
        }

        guard !priorityEntries.isEmpty else {
            // Show empty ring at score 0
            let emptyEntry = PieChartDataEntry(value: 1)
            let emptySet = PieChartDataSet(entries: [emptyEntry], label: "")
            emptySet.drawIconsEnabled = false
            emptySet.drawValuesEnabled = false
            emptySet.sliceSpace = 0
            emptySet.colors = [todoColors.accentMuted.withAlphaComponent(0.3)]
            navPieChart.drawEntryLabelsEnabled = false
            navPieChart.data = PieChartData(dataSet: emptySet)
            return
        }

        // Map colors using priority values directly
        var sliceColors: [UIColor] = []
        for priorityEntry in priorityEntries {
            switch priorityEntry.priority {
            case 1:
                sliceColors.append(TaskPriorityConfig.Priority.none.color)
            case 2:
                sliceColors.append(TaskPriorityConfig.Priority.low.color)
            case 3:
                sliceColors.append(TaskPriorityConfig.Priority.high.color)
            case 4:
                sliceColors.append(TaskPriorityConfig.Priority.max.color)
            default:
                sliceColors.append(todoColors.accentMuted)
            }
        }

        let entries = priorityEntries.map { $0.entry }
        let set = PieChartDataSet(entries: entries, label: "")
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.sliceSpace = 2
        set.colors = sliceColors

        navPieChart.drawEntryLabelsEnabled = false
        navPieChart.data = PieChartData(dataSet: set)
    }

    /// Executes refreshNavigationPieChart.
    func refreshNavigationPieChart() {
        buildNavigationPieChartData(for: dateForTheView)
        navigationPieChartView?.animate(xAxisDuration: 0.3, easingOption: .easeOutBack)
    }

    /// Executes reloadTinyPicChartWithAnimation.
    @objc func reloadTinyPicChartWithAnimation() {
        refreshNavigationPieChart()
    }

    // MARK: - Theme

    /// Executes applyTheme.
    private func applyTheme() {
        todoColors = TaskerThemeManager.shared.currentTheme.tokens.color

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: todoColors.accentOnPrimary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        ensureNavigationPieChartAsRightItem()
        layoutNavigationPieChart()
        updateNavigationDateHeader()
    }

    /// Executes setFont.
    func setFont(fontSize: CGFloat, fontweight: UIFont.Weight = .regular, fontDesign: UIFontDescriptor.SystemDesign = .default) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: fontSize, weight: fontweight).fontDescriptor
        if let designed = descriptor.withDesign(fontDesign) {
            return UIFont(descriptor: designed, size: fontSize)
        }
        return UIFont.systemFont(ofSize: fontSize, weight: fontweight)
    }
}

private final class RescheduleViewController: UIViewController {
    private let taskTitle: String
    private let onDateSelected: (Date) -> Void
    private let datePicker = UIDatePicker()

    /// Initializes a new instance.
    init(taskTitle: String, currentDueDate: Date?, onDateSelected: @escaping (Date) -> Void) {
        self.taskTitle = taskTitle
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
        datePicker.date = currentDueDate ?? Date()
    }

    /// Initializes a new instance.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        title = "Reschedule"

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .inline
        view.addSubview(datePicker)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )

        NSLayoutConstraint.activate([
            datePicker.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        onDateSelected(datePicker.date)
        dismiss(animated: true)
    }
}

// MARK: - Snackbar Support

extension HomeViewController {
    /// Executes observeTaskCreateOptimisticStart.
    func observeTaskCreateOptimisticStart() {
        NotificationCenter.default.publisher(for: .taskCreationOptimistic)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let task = notification.object as? TaskDefinition else { return }
                guard let startedAt = notification.userInfo?["startedAt"] as? Date else { return }
                self.pendingCreateStartedAtByTaskID[task.id] = startedAt
            }
            .store(in: &cancellables)
    }

    /// Executes observeTaskCreatedForSnackbar.
    func observeTaskCreatedForSnackbar() {
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
            .receive(on: RunLoop.main)
            .compactMap { $0.object as? TaskDefinition }
            .sink { [weak self] createdTask in
                self?.pendingCreateRetryRequests.removeValue(forKey: createdTask.id)
                self?.showTaskCreatedSnackbar(for: createdTask)
            }
            .store(in: &cancellables)
    }

    /// Executes observeTaskCreateRollbackForRetry.
    func observeTaskCreateRollbackForRetry() {
        NotificationCenter.default.publisher(for: .taskCreationRollback)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let request = notification.userInfo?["request"] as? CreateTaskDefinitionRequest else { return }
                pendingCreateRetryRequests[request.id] = request
                if let task = notification.object as? TaskDefinition {
                    pendingCreateStartedAtByTaskID.removeValue(forKey: task.id)
                }
                let errorMessage = (notification.userInfo?["error"] as? String) ?? "Couldn't add task."
                showTaskCreateRollbackSnackbar(requestID: request.id, errorMessage: errorMessage)
            }
            .store(in: &cancellables)
    }

    /// Executes showTaskCreatedSnackbar.
    private func showTaskCreatedSnackbar(for task: TaskDefinition) {
        let startedAt = pendingCreateStartedAtByTaskID.removeValue(forKey: task.id)
        let durationMS = startedAt.map { Int(Date().timeIntervalSince($0) * 1_000) }
        logWarning(
            event: "task_create_to_toast_ms",
            message: "Task create snackbar rendered",
            fields: [
                "source": "home_task_created_snackbar",
                "was_optimistic": startedAt == nil ? "false" : "true",
                "reconcile_deferred": startedAt == nil ? "false" : "true",
                "duration_ms": durationMS.map(String.init) ?? "unknown"
            ]
        )

        let taskID = task.id
        let token = UUID()
        let snackbar = TaskerSnackbar(
            data: SnackbarData(
                message: "Task added.",
                actions: [
                    SnackbarAction(title: "Undo") { [weak self] in
                        self?.viewModel?.deleteTask(taskID: taskID) { _ in }
                    }
                ]
            ),
            onDismiss: { [weak self] in
                self?.clearActiveSnackbar(ifMatches: token)
            }
        )
        presentSnackbar(
            snackbar,
            token: token,
            preferredHeight: standardTaskCreatedSnackbarHeight,
            source: "task_created"
        )
    }

    /// Executes showTaskCreateRollbackSnackbar.
    private func showTaskCreateRollbackSnackbar(requestID: UUID, errorMessage: String) {
        let token = UUID()
        let snackbar = TaskerSnackbar(
            data: SnackbarData(
                message: errorMessage,
                actions: [
                    SnackbarAction(title: "Retry") { [weak self] in
                        self?.retryTaskCreation(requestID: requestID)
                    }
                ]
            ),
            onDismiss: { [weak self] in
                self?.clearActiveSnackbar(ifMatches: token)
            }
        )
        presentSnackbar(
            snackbar,
            token: token,
            source: "task_create_rollback"
        )
    }

    /// Executes retryTaskCreation.
    private func retryTaskCreation(requestID: UUID) {
        guard let request = pendingCreateRetryRequests[requestID] else { return }
        viewModel?.createTaskDefinition(request: request) { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                self.showTaskCreateRollbackSnackbar(requestID: requestID, errorMessage: error.localizedDescription)
            }
        }
    }

    /// Executes presentSnackbar.
    private func presentSnackbar(
        _ snackbar: TaskerSnackbar,
        token: UUID,
        preferredHeight: CGFloat? = nil,
        source: String
    ) {
        guard homeHostingController != nil else { return }
        if queueSnackbarPresentationIfNeeded(
            snackbar,
            token: token,
            preferredHeight: preferredHeight,
            source: source
        ) {
            return
        }
        presentSnackbarNow(
            snackbar,
            token: token,
            preferredHeight: preferredHeight,
            source: source,
            queuedForTransition: false
        )
    }

    private func queueSnackbarPresentationIfNeeded(
        _ snackbar: TaskerSnackbar,
        token: UUID,
        preferredHeight: CGFloat?,
        source: String
    ) -> Bool {
        guard let coordinator = snackbarDeferringTransitionCoordinator() else { return false }
        queuedSnackbarPresentation = QueuedSnackbarPresentation(
            snackbar: snackbar,
            token: token,
            preferredHeight: preferredHeight,
            source: source
        )

        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.flushQueuedSnackbarPresentation(trigger: "transition_completion")
        }
        DispatchQueue.main.async { [weak self] in
            self?.flushQueuedSnackbarPresentation(trigger: "next_turn_fallback")
        }
        return true
    }

    private func flushQueuedSnackbarPresentation(trigger: String) {
        guard let queued = queuedSnackbarPresentation else { return }
        guard snackbarDeferringTransitionCoordinator() == nil else { return }
        queuedSnackbarPresentation = nil
        presentSnackbarNow(
            queued.snackbar,
            token: queued.token,
            preferredHeight: queued.preferredHeight,
            source: queued.source,
            queuedForTransition: true,
            queueTrigger: trigger
        )
    }

    private func snackbarDeferringTransitionCoordinator() -> UIViewControllerTransitionCoordinator? {
        if let presented = presentedViewController,
           (presented.isBeingDismissed || presented.isBeingPresented),
           let coordinator = presented.transitionCoordinator {
            return coordinator
        }
        if let coordinator = transitionCoordinator {
            return coordinator
        }
        if let coordinator = navigationController?.transitionCoordinator {
            return coordinator
        }
        if (isBeingDismissed || isBeingPresented), let coordinator = transitionCoordinator {
            return coordinator
        }
        return nil
    }

    private func ensureSnackbarPresenter(
        initialSnackbar: TaskerSnackbar
    ) -> (SnackbarPassthroughContainerView, UIHostingController<TaskerSnackbar>) {
        if let container = activeSnackbarContainerView, let host = activeSnackbarHostController {
            return (container, host)
        }

        let passthroughContainer = SnackbarPassthroughContainerView()
        passthroughContainer.translatesAutoresizingMaskIntoConstraints = false
        passthroughContainer.backgroundColor = .clear

        let snackbarVC = UIHostingController(rootView: initialSnackbar)
        snackbarVC.view.backgroundColor = .clear
        snackbarVC.view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(passthroughContainer)
        NSLayoutConstraint.activate([
            passthroughContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            passthroughContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            passthroughContainer.topAnchor.constraint(equalTo: view.topAnchor),
            passthroughContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        addChild(snackbarVC)
        passthroughContainer.addSubview(snackbarVC.view)
        let heightConstraint = snackbarVC.view.heightAnchor.constraint(equalToConstant: standardTaskCreatedSnackbarHeight)
        NSLayoutConstraint.activate([
            snackbarVC.view.leadingAnchor.constraint(equalTo: passthroughContainer.leadingAnchor),
            snackbarVC.view.trailingAnchor.constraint(equalTo: passthroughContainer.trailingAnchor),
            snackbarVC.view.bottomAnchor.constraint(equalTo: passthroughContainer.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            heightConstraint
        ])
        snackbarVC.didMove(toParent: self)
        passthroughContainer.interactiveView = nil
        passthroughContainer.isHidden = true
        snackbarVC.view.isHidden = true

        activeSnackbarContainerView = passthroughContainer
        activeSnackbarHostController = snackbarVC
        activeSnackbarHeightConstraint = heightConstraint

        return (passthroughContainer, snackbarVC)
    }

    private func presentSnackbarNow(
        _ snackbar: TaskerSnackbar,
        token: UUID,
        preferredHeight: CGFloat?,
        source: String,
        queuedForTransition: Bool,
        queueTrigger: String? = nil
    ) {
        let presentStartedAt = Date()
        let (passthroughContainer, snackbarVC) = ensureSnackbarPresenter(initialSnackbar: snackbar)
        activeSnackbarToken = token
        activeSnackbarCleanupWorkItem?.cancel()

        // Replace the hosted SwiftUI view instead of rebuilding the UIKit container each time.
        snackbarVC.rootView = snackbar
        passthroughContainer.isHidden = false
        snackbarVC.view.isHidden = false
        passthroughContainer.interactiveView = snackbarVC.view
        view.bringSubviewToFront(passthroughContainer)

        let snackbarHeight: CGFloat
        if let preferredHeight {
            snackbarHeight = preferredHeight
        } else {
            let targetSize = CGSize(width: view.bounds.width, height: 1_024)
            let measuredHeight = snackbarVC.sizeThatFits(in: targetSize).height
            snackbarHeight = min(max(measuredHeight, 56), 220)
        }
        activeSnackbarHeightConstraint?.constant = min(max(snackbarHeight, 56), 220)

        passthroughContainer.layoutIfNeeded()
        let snackbarFrame = snackbarVC.view.convert(snackbarVC.view.bounds, to: view)
        let expectedMinimumY = view.bounds.height - (view.safeAreaInsets.bottom + 260)
        if snackbarFrame.minY < expectedMinimumY {
            logWarning(
                event: "task_create_snackbar_frame_exceeded",
                message: "Snackbar host expanded outside expected bottom envelope",
                fields: [
                    "min_y": String(format: "%.1f", snackbarFrame.minY),
                    "expected_min_y": String(format: "%.1f", expectedMinimumY),
                    "height": String(format: "%.1f", snackbarFrame.height)
                ]
            )
        }

        // Fallback cleanup in case onDismiss is skipped.
        activeSnackbarCleanupWorkItem?.cancel()
        let cleanupToken = token
        let cleanupWorkItem = DispatchWorkItem { [weak self] in
            self?.clearActiveSnackbar(ifMatches: cleanupToken)
        }
        activeSnackbarCleanupWorkItem = cleanupWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: cleanupWorkItem)

        let presentMS = Int(Date().timeIntervalSince(presentStartedAt) * 1_000)
        logWarning(
            event: "task_create_snackbar_present_ms",
            message: "Snackbar presentation completed",
            fields: [
                "source": source,
                "duration_ms": String(presentMS),
                "queued_for_transition": queuedForTransition ? "true" : "false",
                "queue_trigger": queueTrigger ?? "none"
            ]
        )
    }

    /// Executes clearActiveSnackbar.
    private func clearActiveSnackbar() {
        clearActiveSnackbar(ifMatches: nil)
    }

    private func clearActiveSnackbar(ifMatches token: UUID?) {
        if let token, activeSnackbarToken != token {
            return
        }
        activeSnackbarCleanupWorkItem?.cancel()
        activeSnackbarCleanupWorkItem = nil
        activeSnackbarToken = nil
        activeSnackbarContainerView?.interactiveView = nil
        activeSnackbarHostController?.view.isHidden = true
        activeSnackbarContainerView?.isHidden = true
    }

    private func teardownSnackbarPresenter() {
        clearActiveSnackbar()
        queuedSnackbarPresentation = nil

        if let hostController = activeSnackbarHostController {
            hostController.willMove(toParent: nil)
            hostController.view.removeFromSuperview()
            hostController.removeFromParent()
            activeSnackbarHostController = nil
        }
        activeSnackbarHeightConstraint = nil

        if let containerView = activeSnackbarContainerView {
            containerView.removeFromSuperview()
            activeSnackbarContainerView = nil
        }
    }
}
