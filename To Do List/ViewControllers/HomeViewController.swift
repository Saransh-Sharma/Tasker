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
import FluentUI

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
    private var pendingChartRefreshWorkItem: DispatchWorkItem?
    private let chartRefreshDebounceSeconds: TimeInterval = 0.12

    var shouldHideData = false
    var dateForTheView = Date.today()
    var todoColors: TaskerColorTokens = TaskerThemeManager.shared.currentTheme.tokens.color

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        injectDependenciesIfNeeded()
        configureNavigationBar()
        bindTheme()
        bindViewModel()
        mountHomeShell()
        observeMutations()

        updateDailyScore(for: dateForTheView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if navigationPieChartView != nil {
            layoutNavigationPieChart()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ensureNavigationPieChartAsRightItem()
        layoutNavigationPieChart()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if navigationController?.topViewController !== self {
            removeNavigationPieChartOverlay(resetChartState: true)
        }
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    // MARK: - Setup

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

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: todoColors.accentOnPrimary]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = false

        navigationItem.fluentConfiguration.customNavigationBarColor = todoColors.accentPrimary
        navigationItem.fluentConfiguration.navigationBarStyle = .custom

        // Pie chart on the right
        ensureNavigationPieChartAsRightItem()

        // Date header with XP as title view
        updateNavigationDateHeader()
    }

    private func bindTheme() {
        TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }

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
                self?.viewModel?.deleteTask(task)
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

    private func observeMutations() {
        notificationCenter.addObserver(
            self,
            selector: #selector(homeTaskMutationReceived(_:)),
            name: .homeTaskMutation,
            object: nil
        )
    }

    // MARK: - Navigation Actions

    @objc func onMenuButtonTapped() {
        let settingsVC = SettingsPageViewController()
        settingsVC.presentationDependencyContainer = presentationDependencyContainer
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.navigationBar.prefersLargeTitles = false

        let controller = DrawerController(sourceView: view, sourceRect: .zero, presentationDirection: .fromLeading)
        controller.contentController = navController
        controller.preferredContentSize.width = 350
        controller.resizingBehavior = .dismiss

        present(controller, animated: true)
    }

    @objc func AddTaskAction() {
        let addTaskVC = AddTaskViewController()
        addTaskVC.delegate = self
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        presentationDependencyContainer.inject(into: addTaskVC)

        let navController = UINavigationController(rootViewController: addTaskVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
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

    @objc func chatButtonTapped() {
        let chatHostVC = ChatHostViewController()
        let navController = NavigationController(rootViewController: chatHostVC)
        navController.modalPresentationStyle = .fullScreen
        navController.navigationBar.prefersLargeTitles = false
        present(navController, animated: true)
    }

    // MARK: - Task Routing

    private func handleTaskTap(_ task: DomainTask) {
        presentTaskDetailView(for: task)
    }

    private func handleTaskReschedule(_ task: DomainTask) {
        let rescheduleVC = RescheduleViewController(
            taskTitle: task.name,
            currentDueDate: task.dueDate
        ) { [weak self] (selectedDate: Date) in
            guard let self else { return }
            self.viewModel?.rescheduleTask(task, to: selectedDate)
        }

        let navController = UINavigationController(rootViewController: rescheduleVC)
        present(navController, animated: true)
    }

    private func presentTaskDetailView(for task: DomainTask) {
        let detailView = TaskDetailSheetView(
            task: task,
            projects: viewModel?.projects ?? [],
            onUpdate: { [weak self] request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.updateTask(taskID: task.id, request: request, completion: completion)
            },
            onSetCompletion: { [weak self] isComplete, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.setTaskCompletion(taskID: task.id, to: isComplete, completion: completion)
            },
            onDelete: { [weak self] completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.deleteTask(taskID: task.id, completion: completion)
            },
            onReschedule: { [weak self] date, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.rescheduleTask(taskID: task.id, to: date, completion: completion)
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

    func refreshChartsAfterTaskCompletion() {
        refreshChartsAfterTaskMutation(reason: .completed)
    }

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

    func updateDailyScore(for date: Date? = nil) {
        let targetDate = date ?? dateForTheView

        if let viewModel, Calendar.current.isDateInToday(targetDate) {
            applyScoreDisplay(viewModel.dailyScore, for: targetDate)
            return
        }

        applyScoreDisplay(calculateTodaysScore(), for: targetDate)
    }

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

    private func removeNavigationPieChartOverlay(resetChartState: Bool) {
        navigationPieChartAnchorView?.removeFromSuperview()
        if resetChartState {
            navigationPieChartView = nil
            navigationPieChartAnchorView = nil
            navigationPieChartCenterXConstraint = nil
        }
    }

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

    func refreshNavigationPieChart() {
        buildNavigationPieChartData(for: dateForTheView)
        navigationPieChartView?.animate(xAxisDuration: 0.3, easingOption: .easeOutBack)
    }

    @objc func reloadTinyPicChartWithAnimation() {
        refreshNavigationPieChart()
    }

    // MARK: - Theme

    private func applyTheme() {
        todoColors = TaskerThemeManager.shared.currentTheme.tokens.color

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: todoColors.accentOnPrimary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        navigationItem.fluentConfiguration.customNavigationBarColor = todoColors.accentPrimary
        navigationItem.fluentConfiguration.navigationBarStyle = .custom

        ensureNavigationPieChartAsRightItem()
        layoutNavigationPieChart()
        updateNavigationDateHeader()
    }

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

    init(taskTitle: String, currentDueDate: Date?, onDateSelected: @escaping (Date) -> Void) {
        self.taskTitle = taskTitle
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
        datePicker.date = currentDueDate ?? Date()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

// MARK: - AddTaskViewControllerDelegate

extension HomeViewController: AddTaskViewControllerDelegate {
    func didCreateTask() {
        viewModel?.handleExternalMutation(reason: .created, repostEvent: true)

        // Keep currently selected scope and date; let ViewModel reload pipeline settle.
        if let selected = viewModel?.selectedDate {
            dateForTheView = selected
        }
    }
}
