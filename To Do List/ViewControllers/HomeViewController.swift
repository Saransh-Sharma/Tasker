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


    // MARK: - Lifecycle

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()

        injectDependenciesIfNeeded()
        bindTheme()
        bindViewModel()
        mountHomeShell()
        observeMutations()
        observeTaskCreatedForSnackbar()
        applyTheme()
    }

    /// Executes viewWillAppear.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
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
