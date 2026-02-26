//
//  HomeViewController.swift
//  To Do List
//
//  SwiftUI host for Home screen with backdrop/foredrop shell.
//

import UIKit
import SwiftUI
import Combine

final class HomeViewController: UIViewController, HomeViewControllerProtocol, HomeAnalyticsViewModelsInjectable, PresentationDependencyContainerAware {
    private static var hasConsumedUITestRoute = false

    // MARK: - Dependencies

    var viewModel: HomeViewModel!
    var chartCardViewModel: ChartCardViewModel!
    var radarChartCardViewModel: RadarChartCardViewModel!
    var presentationDependencyContainer: PresentationDependencyContainer?

    // MARK: - UI

    private var homeHostingController: UIHostingController<HomeBackdropForedropRootView>?

    // MARK: - State

    private let notificationCenter = NotificationCenter.default
    private var cancellables = Set<AnyCancellable>()
    private var pendingChartRefreshWorkItem: DispatchWorkItem?
    private let chartRefreshDebounceSeconds: TimeInterval = 0.12
    private var pendingNotificationFocusTaskID: UUID?


    // MARK: - Lifecycle

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()

        injectDependenciesIfNeeded()
        bindTheme()
        bindViewModel()
        mountHomeShell()
        observeMutations()
        observeNotificationRoutes()
        observeTaskCreatedForSnackbar()
        applyTheme()
    }

    /// Executes viewWillAppear.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    /// Executes viewDidAppear.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let pendingRoute = TaskerNotificationRouteBus.shared.consumePendingRoute() {
            handleNotificationRoute(pendingRoute)
        }
        consumeUITestInjectedRouteIfNeeded()
    }

    /// Executes viewWillDisappear.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
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
            }
        )

        let hostingController = UIHostingController(rootView: root)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
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

    /// Executes observeNotificationRoutes.
    private func observeNotificationRoutes() {
        NotificationCenter.default.publisher(for: TaskerNotificationRouteBus.routeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let payload = notification.userInfo?["payload"] as? String else { return }
                let route = TaskerNotificationRoute.from(payload: payload, fallbackTaskID: nil)
                self?.handleNotificationRoute(route)
                _ = TaskerNotificationRouteBus.shared.consumePendingRoute()
            }
            .store(in: &cancellables)
    }

    private func consumeUITestInjectedRouteIfNeeded() {
        guard Self.hasConsumedUITestRoute == false else { return }
        let prefix = "-TASKER_TEST_ROUTE:"
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else { return }
        let payload = String(argument.dropFirst(prefix.count))
        guard payload.isEmpty == false else { return }
        Self.hasConsumedUITestRoute = true
        let route = TaskerNotificationRoute.from(payload: payload, fallbackTaskID: nil)
        handleNotificationRoute(route)
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

    private func handleNotificationRoute(_ route: TaskerNotificationRoute) {
        guard let viewModel else { return }
        switch route {
        case .homeToday(let taskID):
            viewModel.setQuickView(.today)
            pendingNotificationFocusTaskID = taskID
        case .homeDone:
            viewModel.setQuickView(.done)
            pendingNotificationFocusTaskID = nil
        case .taskDetail(let taskID):
            viewModel.setQuickView(.today)
            pendingNotificationFocusTaskID = taskID
            resolveAndPresentTaskDetail(taskID: taskID)
        case .dailySummary(let kind, let dateStamp):
            presentDailySummaryModal(kind: kind, dateStamp: dateStamp)
        }
    }

    private func resolveAndPresentTaskDetail(taskID: UUID, attemptsRemaining: Int = 2) {
        if let task = viewModel?.taskSnapshot(for: taskID) {
            presentTaskDetailView(for: task)
            return
        }
        guard attemptsRemaining > 0 else { return }
        viewModel?.loadTodayTasks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.resolveAndPresentTaskDetail(taskID: taskID, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func presentDailySummaryModal(kind: TaskerDailySummaryKind, dateStamp: String?) {
        guard let viewModel else { return }

        let presentSummary: (DailySummaryModalData) -> Void = { [weak self] summary in
            guard let self else { return }
            let summaryView = DailySummaryModalView(
                summary: summary,
                onDismiss: { [weak self] in
                    self?.dismiss(animated: true)
                },
                onStartToday: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_today", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_today", success: true, error: nil)
                    self.dismiss(animated: true)
                },
                onCompleteMorningRoutine: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "complete_morning_routine", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.completeMorningRoutine { result in
                        switch result {
                        case .success:
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "complete_morning_routine",
                                success: true,
                                error: nil
                            )
                        case .failure(let error):
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "complete_morning_routine",
                                success: false,
                                error: error
                            )
                        }
                    }
                    self.dismiss(animated: true)
                },
                onStartTriage: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_triage", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.startTriage(scope: .visible)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_triage", success: true, error: nil)
                    self.dismiss(animated: true)
                },
                onRescueOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "rescue_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "rescue_overdue", success: true, error: nil)
                    self.dismiss(animated: true)
                },
                onAddTask: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "add_task", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.trackDailySummaryActionResult(cta: "add_task", success: true, error: nil)
                    self.dismiss(animated: true) {
                        self.AddTaskAction()
                    }
                },
                onPlanTomorrow: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "plan_tomorrow", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.performEndOfDayCleanup { result in
                        switch result {
                        case .success:
                            self.viewModel.trackDailySummaryActionResult(cta: "plan_tomorrow", success: true, error: nil)
                        case .failure(let error):
                            self.viewModel.trackDailySummaryActionResult(cta: "plan_tomorrow", success: false, error: error)
                        }
                    }
                    self.dismiss(animated: true)
                },
                onReviewDone: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "review_done", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.done)
                    self.viewModel.trackDailySummaryActionResult(cta: "review_done", success: true, error: nil)
                    self.dismiss(animated: true)
                },
                onRescheduleOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "reschedule_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.rescheduleOverdueTasks { result in
                        switch result {
                        case .success:
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "reschedule_overdue",
                                success: true,
                                error: nil
                            )
                        case .failure(let error):
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "reschedule_overdue",
                                success: false,
                                error: error
                            )
                        }
                    }
                    self.dismiss(animated: true)
                },
                onOpenRescue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "open_rescue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "open_rescue", success: true, error: nil)
                    self.dismiss(animated: true)
                }
            )

            let hostingController = UIHostingController(rootView: summaryView)
            hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
            hostingController.view.accessibilityIdentifier = "home.dailySummaryModal"
            hostingController.modalPresentationStyle = .pageSheet

            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }

            self.present(hostingController, animated: true)
        }

        viewModel.loadDailySummaryModal(kind: kind, dateStamp: dateStamp) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                presentSummary(self.fallbackDailySummary(kind: kind, dateStamp: dateStamp))
            case .success(let summary):
                presentSummary(summary)
            }
        }
    }

    private func fallbackDailySummary(kind: TaskerDailySummaryKind, dateStamp: String?) -> DailySummaryModalData {
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

    private func fallbackSummaryDate(from dateStamp: String?) -> Date {
        guard let dateStamp, dateStamp.count == 8 else { return Date() }
        var components = DateComponents()
        components.year = Int(dateStamp.prefix(4))
        components.month = Int(dateStamp.dropFirst(4).prefix(2))
        components.day = Int(dateStamp.suffix(2))
        return Calendar.current.date(from: components) ?? Date()
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

    // MARK: - Theme

    /// Executes applyTheme.
    private func applyTheme() {
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
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

    /// Executes showTaskCreatedSnackbar.
    private func showTaskCreatedSnackbar(for task: TaskDefinition) {
        guard let hostingController = homeHostingController else { return }

        let taskID = task.id
        let snackbar = TaskerSnackbar(
            data: SnackbarData(
                message: "Task added.",
                actions: [
                    SnackbarAction(title: "Undo") { [weak self] in
                        self?.viewModel?.deleteTask(taskID: taskID) { _ in }
                    }
                ]
            ),
            onDismiss: {}
        )

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

        // Auto-remove after snackbar's auto-dismiss (5s + 0.4s animation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            snackbarVC.willMove(toParent: nil)
            snackbarVC.view.removeFromSuperview()
            snackbarVC.removeFromParent()
        }
    }
}

private struct DailySummaryModalView: View {
    let summary: DailySummaryModalData
    let onDismiss: () -> Void
    let onStartToday: () -> Void
    let onCompleteMorningRoutine: () -> Void
    let onStartTriage: () -> Void
    let onRescueOverdue: () -> Void
    let onAddTask: () -> Void
    let onPlanTomorrow: () -> Void
    let onReviewDone: () -> Void
    let onRescheduleOverdue: () -> Void
    let onOpenRescue: () -> Void

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    @State private var heroMetricsAnimated = false

    var body: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .background(Color.tasker.strokeHairline)

            ScrollView {
                scrollableContent
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }

            Divider()
                .background(Color.tasker.strokeHairline)

            ctaBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Color.tasker.surfacePrimary)
        }
        .background(Color.tasker.bgCanvas)
        .accessibilityIdentifier("home.dailySummaryModal")
        .onAppear {
            guard heroMetricsAnimated == false else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                heroMetricsAnimated = true
            }
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        switch summary {
        case .morning(let value):
            morningContent(value)
        case .nightly(let value):
            nightlyContent(value)
        }
    }

    private var headerCard: some View {
        let title: String
        let subtitle: String
        switch summary {
        case .morning(let value):
            title = "Morning Plan"
            subtitle = headerDateText(value.date)
        case .nightly(let value):
            title = "Day Retrospective"
            subtitle = headerDateText(value.date)
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.tasker(.title3))
                        .foregroundColor(Color.tasker.textPrimary)
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                }
                Spacer(minLength: 8)
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            summaryHeroMetrics
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.tasker.surfaceSecondary)
        )
    }

    private var summaryHeroMetrics: some View {
        switch summary {
        case .morning(let value):
            return AnyView(
                HStack(spacing: 10) {
                    metricChip(
                        title: "Open",
                        value: "\(value.openTodayCount)",
                        id: "home.dailySummary.hero.openCount",
                        numericValue: value.openTodayCount
                    )
                    metricChip(
                        title: "High",
                        value: "\(value.highPriorityCount)",
                        id: "home.dailySummary.hero.highCount",
                        numericValue: value.highPriorityCount
                    )
                    metricChip(
                        title: "Overdue",
                        value: "\(value.overdueCount)",
                        id: "home.dailySummary.hero.overdueCount",
                        numericValue: value.overdueCount
                    )
                    metricChip(
                        title: "XP",
                        value: "\(value.potentialXP)",
                        id: "home.dailySummary.hero.potentialXP",
                        numericValue: value.potentialXP
                    )
                }
            )
        case .nightly(let value):
            return AnyView(
                HStack(spacing: 10) {
                    metricChip(title: "Done", value: "\(value.completedCount)/\(value.totalCount)", id: "home.dailySummary.hero.completed")
                    metricChip(
                        title: "XP",
                        value: "\(value.xpEarned)",
                        id: "home.dailySummary.hero.xp",
                        numericValue: value.xpEarned
                    )
                    metricChip(
                        title: "Rate",
                        value: "\(Int((value.completionRate * 100).rounded()))%",
                        id: "home.dailySummary.hero.rate",
                        numericValue: Int((value.completionRate * 100).rounded()),
                        numericSuffix: "%"
                    )
                    metricChip(
                        title: "Streak",
                        value: "\(value.streakCount)d",
                        id: "home.dailySummary.hero.streak",
                        numericValue: value.streakCount,
                        numericSuffix: "d"
                    )
                }
            )
        }
    }

    private func morningContent(_ summary: MorningPlanSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Focus Now") {
                if summary.focusTasks.isEmpty {
                    Text("No tasks queued. Capture one meaningful win.")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(summary.focusTasks) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Risk & Friction") {
                VStack(alignment: .leading, spacing: 8) {
                    riskLine(title: "Overdue tasks", value: summary.overdueCount)
                    riskLine(title: "Blocked tasks", value: summary.blockedCount)
                    riskLine(title: "Long tasks (60m+)", value: summary.longTaskCount)
                }
            }

            sectionCard(title: "Agenda Split") {
                HStack(spacing: 12) {
                    agendaPill(title: "Morning", value: summary.morningPlannedCount)
                    agendaPill(title: "Evening", value: summary.eveningPlannedCount)
                }
            }
        }
    }

    private func nightlyContent(_ summary: NightlyRetrospectiveSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Biggest Wins") {
                if summary.biggestWins.isEmpty {
                    Text("No completions today. Pick one tiny restart for tomorrow.")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(summary.biggestWins) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Carry-over") {
                VStack(alignment: .leading, spacing: 8) {
                    riskLine(title: "Open due today", value: summary.carryOverDueTodayCount)
                    riskLine(title: "Still overdue", value: summary.carryOverOverdueCount)
                }
            }

            sectionCard(title: "Tomorrow Preview") {
                if summary.tomorrowPreview.isEmpty {
                    Text("No tasks due tomorrow yet.")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(summary.tomorrowPreview) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Reflection Insight") {
                HStack(spacing: 12) {
                    agendaPill(title: "Morning Done", value: summary.morningCompletedCount)
                    agendaPill(title: "Evening Done", value: summary.eveningCompletedCount)
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.tasker.surfaceSecondary)
        )
    }

    private func taskRow(_ row: SummaryTaskRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(priorityColor(row.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    priorityBadge(row.priority)
                    if row.isOverdue {
                        statusBadge(
                            text: "Overdue",
                            foreground: Color.tasker.statusDanger,
                            background: Color.tasker.statusDanger.opacity(0.14)
                        )
                    }
                    if row.isBlocked {
                        statusBadge(
                            text: "Blocked",
                            foreground: Color.tasker.statusWarning,
                            background: Color.tasker.statusWarning.opacity(0.16)
                        )
                    }
                }
                HStack(spacing: 8) {
                    if let dueLabel = dueLabel(for: row) {
                        Text(dueLabel)
                            .font(.tasker(.caption2))
                            .foregroundColor(row.isOverdue ? Color.tasker.statusDanger : Color.tasker.textSecondary)
                    }
                    if let estimatedDuration = row.estimatedDuration {
                        Text(durationLabel(seconds: estimatedDuration))
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("home.dailySummary.taskRow.\(row.taskID.uuidString)")
    }

    private func riskLine(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.tasker(.bodyEmphasis))
                .foregroundColor(Color.tasker.textPrimary)
        }
    }

    private func agendaPill(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
            Text("\(value)")
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.tasker.surfacePrimary)
        )
    }

    private func metricChip(
        title: String,
        value: String,
        id: String,
        numericValue: Int? = nil,
        numericSuffix: String = ""
    ) -> some View {
        let displayedNumericValue = heroMetricsAnimated ? (numericValue ?? 0) : 0
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
            if numericValue != nil {
                Text("\(displayedNumericValue)\(numericSuffix)")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.5), value: displayedNumericValue)
            } else {
                Text(value)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.tasker.surfacePrimary)
        )
        .accessibilityIdentifier(id)
    }

    private var ctaBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch summary {
            case .morning(let value):
                Button("Start Today") { onStartToday() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.startToday")

                HStack(spacing: 10) {
                    Button("Complete Morning Routine") { onCompleteMorningRoutine() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.completeMorning")
                    Button("Start Triage") { onStartTriage() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.startTriage")
                }

                if value.overdueCount > 0 {
                    Button("Rescue Overdue") { onRescueOverdue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.rescueOverdue")
                }

                Button("Add Task") { onAddTask() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.addTask")

            case .nightly(let value):
                Button("Plan Tomorrow") { onPlanTomorrow() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.planTomorrow")

                Button("Review Done") { onReviewDone() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.reviewDone")

                if value.carryOverOverdueCount > 0 {
                    Button("Reschedule Overdue") { onRescheduleOverdue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.rescheduleOverdue")
                }

                if value.carryOverOverdueCount > 0 {
                    Button("Open Rescue") { onOpenRescue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.openRescue")
                }
            }
        }
    }

    private func dueLabel(for row: SummaryTaskRow) -> String? {
        guard let dueDate = row.dueDate else { return nil }
        return relativeFormatter.localizedString(for: dueDate, relativeTo: Date())
    }

    private func durationLabel(seconds: TimeInterval) -> String {
        let minutes = Int(round(seconds / 60))
        if minutes >= 60 {
            if minutes % 60 == 0 {
                return "\(minutes / 60)h"
            }
            return String(format: "%.1fh", Double(minutes) / 60.0)
        }
        return "\(minutes)m"
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        if priority == .max {
            return Color.tasker.statusDanger
        }
        if priority == .high {
            return Color.tasker.statusWarning
        }
        if priority == .low {
            return Color.tasker.accentPrimary
        }
        return Color.tasker.textTertiary
    }

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        statusBadge(
            text: priority.displayName,
            foreground: priorityColor(priority),
            background: priorityColor(priority).opacity(0.14)
        )
    }

    private func statusBadge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.tasker(.caption2))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(background)
            )
    }

    private func headerDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
