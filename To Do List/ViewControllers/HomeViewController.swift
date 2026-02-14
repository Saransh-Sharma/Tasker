//
//  HomeViewController.swift
//  To Do List
//
//  SwiftUI host for Home screen with backdrop/foredrop shell.
//

import UIKit
import SwiftUI
import Combine
import CoreData
import DGCharts
import FluentUI

final class HomeViewController: UIViewController, TaskRepositoryDependent, HomeViewControllerProtocol {

    // MARK: - Dependencies

    var taskRepository: TaskRepository!
    var viewModel: HomeViewModel!

    // MARK: - UI

    private var homeHostingController: UIHostingController<HomeBackdropForedropRootView>?

    // Tiny pie chart / nav XP state
    lazy var tinyPieChartView: PieChartView = { PieChartView() }()
    private var navigationPieChartView: PieChartView?
    private weak var navigationPieChartAnchorView: UIView?
    private let navigationPieChartSize: CGFloat = 136
    private let navigationPieChartTrailingInset: CGFloat = 10
    private let navigationPieChartZPosition: CGFloat = 999
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
        if taskRepository == nil {
            DependencyContainer.shared.inject(into: self)
        }

        if viewModel == nil {
            PresentationDependencyContainer.shared.inject(into: self)
        }

        // Safety fallback for development paths where presentation DI was skipped.
        if viewModel == nil,
           let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let taskRepo = CoreDataTaskRepository(container: appDelegate.persistentContainer, defaultProject: "Inbox")
            let projectRepo = CoreDataProjectRepository(container: appDelegate.persistentContainer)
            let coordinator = UseCaseCoordinator(taskRepository: taskRepo, projectRepository: projectRepo)
            viewModel = HomeViewModel(useCaseCoordinator: coordinator)
        }

        if taskRepository == nil,
           let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            taskRepository = CoreDataTaskRepository(container: appDelegate.persistentContainer, defaultProject: "Inbox")
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

        DependencyContainer.shared.inject(into: addTaskVC)
        PresentationDependencyContainer.shared.inject(into: addTaskVC)

        let navController = UINavigationController(rootViewController: addTaskVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    @objc func searchButtonTapped() {
        let searchVC = LGSearchViewController()
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
        guard let managedTask = resolveManagedTask(for: task) else {
            return
        }
        presentTaskDetailView(for: managedTask)
    }

    private func handleTaskReschedule(_ task: DomainTask) {
        guard let managedTask = resolveManagedTask(for: task) else {
            return
        }

        let rescheduleVC = RescheduleViewController(task: managedTask) { [weak self] selectedDate in
            guard let self else { return }
            self.viewModel?.rescheduleTask(task, to: selectedDate)
        }

        let navController = UINavigationController(rootViewController: rescheduleVC)
        present(navController, animated: true)
    }

    private func resolveManagedTask(for task: DomainTask) -> NTask? {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return nil
        }

        let idRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        idRequest.fetchLimit = 1
        idRequest.predicate = NSPredicate(format: "taskID == %@", task.id as CVarArg)
        if let exact = try? context.fetch(idRequest).first {
            return exact
        }

        let metadataRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        metadataRequest.fetchLimit = 30

        var predicates: [NSPredicate] = [
            NSPredicate(format: "name == %@", task.name),
            NSPredicate(format: "taskType == %d", task.type.rawValue),
            NSPredicate(format: "taskPriority == %d", task.priority.rawValue)
        ]

        if let dueDate = task.dueDate {
            let lowerBound = dueDate.addingTimeInterval(-180)
            let upperBound = dueDate.addingTimeInterval(180)
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate <= %@", lowerBound as NSDate, upperBound as NSDate))
        } else {
            predicates.append(NSPredicate(format: "dueDate == nil"))
        }

        metadataRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        metadataRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

        if let candidates = try? context.fetch(metadataRequest) {
            return bestCandidate(for: task, in: candidates)
        }

        return nil
    }

    private func bestCandidate(for task: DomainTask, in candidates: [NTask]) -> NTask? {
        guard !candidates.isEmpty else { return nil }

        var scored: [(NTask, Int)] = candidates.map { candidate in
            var score = 0
            if candidate.name == task.name { score += 4 }
            if candidate.isComplete == task.isComplete { score += 2 }
            if candidate.projectID == task.projectID { score += 4 }
            if candidate.taskType == task.type.rawValue { score += 2 }
            if candidate.taskPriority == task.priority.rawValue { score += 2 }

            switch (candidate.dueDate as Date?, task.dueDate) {
            case let (lhs?, rhs?) where abs(lhs.timeIntervalSince(rhs)) <= 180:
                score += 2
            case (nil, nil):
                score += 1
            default:
                break
            }

            return (candidate, score)
        }

        scored.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            let lhsDate = lhs.0.dateAdded as Date? ?? Date.distantPast
            let rhsDate = rhs.0.dateAdded as Date? ?? Date.distantPast
            return lhsDate > rhsDate
        }

        return scored.first?.0
    }

    private func presentTaskDetailView(for task: NTask) {
        let detailView = TaskDetailSheetView(
            task: task,
            projectNames: buildProjectChipData(),
            onDismiss: nil,
            onDelete: { [weak self] in
                guard let self else { return }
                task.managedObjectContext?.delete(task)
                try? task.managedObjectContext?.save()
                self.viewModel?.handleExternalMutation(reason: .deleted, repostEvent: true)
                self.presentedViewController?.dismiss(animated: true)
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

    private func buildProjectChipData() -> [String] {
        var projectNames: [String] = []
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]
            if let projects = try? context.fetch(request) {
                projectNames = projects.compactMap { $0.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        let inboxTitle = ProjectConstants.inboxProjectName
        projectNames.removeAll { $0.caseInsensitiveCompare(inboxTitle) == .orderedSame }
        projectNames.insert(inboxTitle, at: 0)

        var deduped: [String] = []
        var seen = Set<String>()
        for name in projectNames {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            deduped.append(name)
        }
        return deduped
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
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return 0
        }

        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let start = Calendar.current.startOfDay(for: targetDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? targetDate

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isComplete == YES"),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "dateCompleted >= %@ AND dateCompleted < %@", start as NSDate, end as NSDate),
                NSPredicate(format: "dateCompleted == nil AND dueDate >= %@ AND dueDate < %@", start as NSDate, end as NSDate)
            ])
        ])

        let tasks = (try? context.fetch(request)) ?? []
        return tasks.reduce(0) { partial, task in
            partial + TaskPriority(rawValue: task.taskPriority).scorePoints
        }
    }

    func priorityBreakdown(for date: Date) -> [Int32: Int] {
        var counts: [Int32: Int] = [1: 0, 2: 0, 3: 0, 4: 0]

        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return counts
        }

        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        guard let allTasks = try? context.fetch(request) else {
            return counts
        }

        let currentCalendar = Calendar.current
        for task in allTasks {
            guard task.isComplete else { continue }
            let referenceDate = (task.dateCompleted as Date?) ?? (task.dueDate as Date?)
            guard let ref = referenceDate, currentCalendar.isDate(ref, inSameDayAs: date) else { continue }
            let normalizedPriority = TaskPriorityConfig.normalizePriority(task.taskPriority)
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

        guard let repository = taskRepository else {
            applyScoreDisplay(0, for: targetDate)
            return
        }

        TaskScoringService.shared.calculateTotalScore(for: targetDate, using: repository) { [weak self] total in
            DispatchQueue.main.async {
                self?.applyScoreDisplay(total, for: targetDate)
            }
        }
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
        hostingController.view.backgroundColor = .clear
        hostingController.sizingOptions = .intrinsicContentSize
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
        let entries: [PieChartDataEntry] = [
            (Int32(1), "None"),
            (Int32(2), "Low"),
            (Int32(3), "High"),
            (Int32(4), "Max")
        ].compactMap { priorityRaw, label in
            let rawCount = Double(breakdown[priorityRaw] ?? 0)
            let weight = TaskPriorityConfig.chartWeightForPriority(priorityRaw)
            let weightedValue = rawCount * weight
            return weightedValue > 0 ? PieChartDataEntry(value: weightedValue, label: label) : nil
        }

        guard !entries.isEmpty else {
            // Show empty ring at score 0
            let emptyEntry = PieChartDataEntry(value: 1, label: "Empty")
            let emptySet = PieChartDataSet(entries: [emptyEntry], label: "")
            emptySet.drawIconsEnabled = false
            emptySet.drawValuesEnabled = false
            emptySet.sliceSpace = 0
            emptySet.colors = [todoColors.accentMuted.withAlphaComponent(0.3)]
            navPieChart.drawEntryLabelsEnabled = false
            navPieChart.data = PieChartData(dataSet: emptySet)
            return
        }

        var sliceColors: [UIColor] = []
        for entry in entries {
            switch entry.label {
            case "None":
                sliceColors.append(TaskPriorityConfig.Priority.none.color)
            case "Low":
                sliceColors.append(TaskPriorityConfig.Priority.low.color)
            case "High":
                sliceColors.append(TaskPriorityConfig.Priority.high.color)
            case "Max":
                sliceColors.append(TaskPriorityConfig.Priority.max.color)
            default:
                sliceColors.append(todoColors.accentMuted)
            }
        }

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

// MARK: - AddTaskViewControllerDelegate

extension HomeViewController: AddTaskViewControllerDelegate {
    func didAddTask(_ task: NTask) {
        viewModel?.handleExternalMutation(reason: .created, repostEvent: true)

        // Keep currently selected scope and date; let ViewModel reload pipeline settle.
        if let selected = viewModel?.selectedDate {
            dateForTheView = selected
        }
    }
}
