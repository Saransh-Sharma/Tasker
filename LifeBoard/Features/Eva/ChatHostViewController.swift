//
//  ChatHostViewController.swift
//  LifeBoard
//
//  Hosts the SwiftUI EVA activation and chat UI for the local-LLM feature.
//

import Combine
import LifeBoardDomain
import SwiftData
import SwiftUI
import UIKit

private struct ChatTaskDetailMetadataState: Sendable {
    var projects: [Project]
    var sections: [ProjectSectionDefinition]
}

private struct ChatTaskDetailRelationshipMetadataState: Sendable {
    var lifeAreas: [LifeArea]
    var tags: [TagDefinition]
    var availableTasks: [TaskDefinition]
}

/// UIKit wrapper that embeds the SwiftUI LLM module.
extension Notification.Name {
    static let toggleChatHistory = Notification.Name("toggleChatHistory")
    static let requestEvaChatSettings = Notification.Name("requestEvaChatSettings")
    static let requestEvaChatNewThread = Notification.Name("requestEvaChatNewThread")
}

@MainActor
class ChatHostViewController: UIViewController, CompositionRootAware, UseCaseCoordinatorInjectable {
    var presentationDependencyContainer: CompositionRoot?
    var useCaseCoordinator: UseCaseCoordinator!
    var onDismissToHome: (() -> Void)?

    private let appManager = AppManager()
    private let llmEvaluator = LLMRuntimeCoordinator.shared.evaluator
    private lazy var activationCoordinator = EvaActivationCoordinator(appManager: appManager)

    private var hostingController: UIHostingController<AnyView>!
    private var themeCancellable: AnyCancellable?
    private var activationCoordinatorCancellable: AnyCancellable?
    private var cachedProjects: [Project] = [Project.createInbox()]
    private var currentLayoutClass: LayoutClass = .phone
    private let activationTitleView = EvaActivationNavigationTitleView()
    private let chatTitleView = EvaChatNavigationTitleView()
    private var chatNavigationChromeState = EvaChatNavigationChromeState.empty
    private lazy var leadingBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: EvaActivationNavigationLeadingActionStyle.back.iconName),
        style: .plain,
        target: self,
        action: #selector(onBackTapped)
    )
    private lazy var historyBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "clock.arrow.circlepath") ?? UIImage(systemName: "clock"),
        style: .plain,
        target: self,
        action: #selector(onHistoryTapped)
    )
    private lazy var settingsBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "gearshape"),
        style: .plain,
        target: self,
        action: #selector(onSettingsTapped)
    )
    private lazy var newChatBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "plus.message"),
        style: .plain,
        target: self,
        action: #selector(onNewChatTapped)
    )

    private var resolvedUseCaseCoordinator: UseCaseCoordinator? {
        if let useCaseCoordinator {
            return useCaseCoordinator
        }

        if presentationDependencyContainer == nil,
           CompositionRoot.shared.isConfiguredForRuntime {
            presentationDependencyContainer = CompositionRoot.shared
        }

        guard let presentationDependencyContainer,
              presentationDependencyContainer.isConfiguredForRuntime else {
            return nil
        }

        return presentationDependencyContainer.coordinator
    }

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()
        resolveDependenciesIfNeeded()

        if LLMDataController.isDegradedModeActive {
            logWarning(
                event: "llm_data_controller_degraded_mode_active",
                message: "LLM chat storage is running in degraded mode",
                fields: ["reason": LLMDataController.degradedModeReason ?? "unknown"]
            )
        }

        let themeColors = ThemeStore.shared.currentTheme.tokens.color
        view.backgroundColor = themeColors.bgCanvas

        currentLayoutClass = LayoutResolver.classify(view: view)
        hostingController = UIHostingController(rootView: makeRootView(layoutClass: currentLayoutClass))
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = themeColors.bgCanvas
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)

        setupNavigationBar()
        bindActivationCoordinator()
        updateNavigationBarChrome()

        themeCancellable = ThemeStore.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (self: Self, _) in
                self.refreshLayoutClassIfNeeded()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshLayoutClassIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.enterChatScreen(trigger: "chat_host_visible")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let isDefinitiveExit = isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true
        guard isDefinitiveExit else { return }
        Task { @MainActor in
            await LLMRuntimeCoordinator.shared.exitChatScreen(reason: "chat_host_exit")
        }
    }

    private func resolveDependenciesIfNeeded() {
        if presentationDependencyContainer == nil,
           CompositionRoot.shared.isConfiguredForRuntime {
            presentationDependencyContainer = CompositionRoot.shared
        }

        if useCaseCoordinator == nil,
           let presentationDependencyContainer,
           presentationDependencyContainer.isConfiguredForRuntime {
            useCaseCoordinator = presentationDependencyContainer.coordinator
        }
    }

    private func makeRootView(layoutClass: LayoutClass) -> AnyView {
        let rootView = LLMStoreContainerHost { [weak self] container in
            guard let self else {
                return AnyView(EmptyView())
            }
            return AnyView(
                EvaActivationRootView(
                    coordinator: self.activationCoordinator,
                    onDismiss: { [weak self] in
                        self?.dismiss(animated: true)
                    },
                    onNavigationChromeChange: { [weak self] state in
                        self?.updateChatNavigationChrome(state)
                    },
                    onOpenTaskDetail: { [weak self] task in
                        self?.presentTaskDetailSheet(for: task)
                    },
                    onOpenHabitDetail: { [weak self] habitID in
                        self?.presentHabitDetailSheet(for: habitID)
                    },
                    onPerformDayTaskAction: { [weak self] action, card, completion in
                        self?.performDayTaskAction(action, card: card, completion: completion)
                    },
                    onPerformDayHabitAction: { [weak self] action, card, completion in
                        self?.performDayHabitAction(action, card: card, completion: completion)
                    }
                )
                .environmentObject(self.appManager)
                .environment(self.llmEvaluator)
                .modelContainer(container)
            )
        }

        return AnyView(rootView.lifeBoardUIKitHostEnvironment(for: layoutClass))
    }

    private func refreshLayoutClassIfNeeded() {
        let nextLayoutClass = LayoutResolver.classify(view: view)
        guard nextLayoutClass != currentLayoutClass else { return }
        currentLayoutClass = nextLayoutClass
        hostingController.rootView = makeRootView(layoutClass: nextLayoutClass)
        updateNavigationBarChrome()
    }

    // MARK: - Navigation Bar Setup

    /// Executes setupNavigationBar.
    private func setupNavigationBar() {
        applyActivationNavigationAppearance()
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        historyBarButtonItem.accessibilityLabel = "History"
        historyBarButtonItem.accessibilityIdentifier = "chat.header.history"
        settingsBarButtonItem.accessibilityLabel = "Settings"
        settingsBarButtonItem.accessibilityIdentifier = "chat.header.settings"
        newChatBarButtonItem.accessibilityLabel = "New chat"
        newChatBarButtonItem.accessibilityIdentifier = "chat.header.new_chat"
    }

    @objc private func onBackTapped() {
        activationCoordinator.handleLeadingNavigation { [weak self] in
            self?.dismissToHome()
        }
    }

    private func dismissToHome() {
        if let navigationController,
           navigationController.presentingViewController != nil {
            let onDismissToHome = onDismissToHome
            navigationController.dismiss(animated: true) {
                onDismissToHome?()
            }
            return
        }

        if presentingViewController != nil {
            let onDismissToHome = onDismissToHome
            dismiss(animated: true) {
                onDismissToHome?()
            }
            return
        }

        if let navigationController,
           navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
        }
    }

    @objc private func onHistoryTapped() {
        NotificationCenter.default.post(name: .toggleChatHistory, object: nil)
    }

    @objc private func onSettingsTapped() {
        NotificationCenter.default.post(name: .requestEvaChatSettings, object: nil)
    }

    @objc private func onNewChatTapped() {
        NotificationCenter.default.post(name: .requestEvaChatNewThread, object: nil)
    }

    // MARK: - Task Detail Presentation

    @discardableResult
    private func presentTaskDetailSheet(for task: TaskDefinition) -> Bool {
        guard let coordinator = resolvedUseCaseCoordinator else {
            logWarning(
                event: "chat_task_detail_unavailable",
                message: "Skipped task detail from chat because dependencies were unavailable",
                fields: ["task_id": task.id.uuidString]
            )
            showTaskDetailUnavailableAlert()
            return false
        }

        loadProjectsIfNeeded(coordinator: coordinator) { [weak self] projects in
            guard let self else { return }
            self.resolveTodayXPSoFar(coordinator: coordinator) { todayXPSoFar in
                let detailView = TaskDetailScreen(
                    task: task,
                    projects: projects,
                    todayXPSoFar: todayXPSoFar,
                    isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                    onUpdate: { [weak self] _, request, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.updateTaskDefinition.execute(request: request) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                },
                onSetCompletion: { [weak self] taskID, isComplete, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.completeTaskDefinition.setCompletion(taskID: taskID, to: isComplete) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                },
                onDelete: { [weak self] taskID, scope, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.deleteTaskDefinition.execute(taskID: taskID, scope: scope) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                },
                onReschedule: { [weak self] taskID, date, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.rescheduleTaskDefinition.execute(taskID: taskID, newDate: date) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                },
                onLoadMetadata: { [weak self] projectID, completion in
                    self?.loadTaskDetailMetadata(projectID: projectID, completion: completion)
                },
                onLoadRelationshipMetadata: { [weak self] projectID, completion in
                    self?.loadTaskDetailRelationshipMetadata(projectID: projectID, completion: completion)
                },
                onLoadChildren: { [weak self] parentTaskID, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 6,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.getTaskChildren.execute(parentTaskID: parentTaskID) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                },
                onCreateTask: { [weak self] request, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 7,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.createTaskDefinition.execute(request: request) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                },
                onCreateTag: { [weak self] name, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 8,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.manageTags.create(name: name, color: nil, icon: nil) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                },
                    onCreateProject: { [weak self] name, completion in
                    guard let self, let coordinator = self.resolvedUseCaseCoordinator else {
                        completion(.failure(NSError(
                            domain: "ChatHostViewController",
                            code: 9,
                            userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
                        )))
                        return
                    }
                    coordinator.manageProjects.createProject(request: CreateProjectRequest(name: name)) { result in
                        DispatchQueue.main.async {
                            completion(result.mapError { $0 as Error })
                        }
                    }
                    }
                )

                let layoutClass = LayoutResolver.classify(view: self.view)
                let hostingController = UIHostingController(rootView: detailView.lifeBoardUIKitHostEnvironment(for: layoutClass))
                hostingController.view.backgroundColor = ThemeStore.shared.currentTheme.tokens.color.bgCanvas
                hostingController.modalPresentationStyle = .pageSheet

                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.preferredCornerRadius = ThemeStore.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = true
                }

                self.present(hostingController, animated: true)
            }
        }
        return true
    }

    private func showTaskDetailUnavailableAlert() {
        presentSunriseUnavailableSheet(
            title: "Task details unavailable",
            message: "Could not open task details from chat right now. Please try again from Home."
        )
    }

    private func presentHabitDetailSheet(for habitID: UUID) {
        guard let coordinator = resolvedUseCaseCoordinator else {
            showHabitDetailUnavailableAlert()
            return
        }

        coordinator.getHabitLibrary.execute(habitID: habitID, includeArchived: true) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .failure:
                    self.showHabitDetailUnavailableAlert()
                case .success(let row):
                    guard let row else {
                        self.showHabitDetailUnavailableAlert()
                        return
                    }

                    guard let presentationDependencyContainer = self.presentationDependencyContainer,
                          presentationDependencyContainer.isConfiguredForRuntime else {
                        self.showHabitDetailUnavailableAlert()
                        return
                    }

                    let detailView = HabitDetailScreen(
                        viewModel: presentationDependencyContainer.makeHabitDetailViewModel(row: row),
                        onMutation: {}
                    )
                    let layoutClass = LayoutResolver.classify(view: self.view)
                    let hostingController = UIHostingController(rootView: detailView.lifeBoardUIKitHostEnvironment(for: layoutClass))
                    hostingController.view.backgroundColor = ThemeStore.shared.currentTheme.tokens.color.bgCanvas
                    hostingController.modalPresentationStyle = .pageSheet

                    if let sheet = hostingController.sheetPresentationController {
                        sheet.detents = [.medium(), .large()]
                        sheet.preferredCornerRadius = ThemeStore.shared.currentTheme.tokens.corner.modal
                        sheet.prefersScrollingExpandsWhenScrolledToEdge = true
                    }

                    self.present(hostingController, animated: true)
                }
            }
        }
    }

    private func showHabitDetailUnavailableAlert() {
        presentSunriseUnavailableSheet(
            title: "Habit details unavailable",
            message: "Could not open habit details from chat right now. Please try again from Home."
        )
    }

    private func presentSunriseUnavailableSheet(title: String, message: String) {
        let sheetView = ChatUnavailableSheet(title: title, message: message)
            .lifeBoardUIKitHostEnvironment(for: currentLayoutClass)
        let hostingController = UIHostingController(rootView: sheetView)
        hostingController.view.backgroundColor = ThemeStore.shared.currentTheme.tokens.color.bgCanvas
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = ThemeStore.shared.currentTheme.tokens.corner.modal
        }

        present(hostingController, animated: true)
    }

    private func performDayTaskAction(
        _ action: EvaDayTaskAction,
        card: EvaDayTaskCard,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard let coordinator = resolvedUseCaseCoordinator else {
            completion(.failure(NSError(
                domain: "ChatHostViewController",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
            )))
            return
        }

        switch action {
        case .done:
            coordinator.completeTaskDefinition.setCompletion(taskID: card.taskID, to: true) { result in
                DispatchQueue.main.async { completion(result.map { _ in }) }
            }
        case .reopen:
            coordinator.completeTaskDefinition.setCompletion(taskID: card.taskID, to: false) { result in
                DispatchQueue.main.async { completion(result.map { _ in }) }
            }
        case .tomorrow:
            let calendar = Calendar.current
            let baseDay = calendar.startOfDay(for: Date())
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseDay) else {
                completion(.failure(NSError(
                    domain: "ChatHostViewController",
                    code: 13,
                    userInfo: [NSLocalizedDescriptionKey: "Could not compute tomorrow"]
                )))
                return
            }
            coordinator.rescheduleTaskDefinition.execute(taskID: card.taskID, newDate: tomorrow) { result in
                DispatchQueue.main.async { completion(result.map { _ in }) }
            }
        case .open:
            if presentTaskDetailSheet(for: card.taskSnapshot) {
                completion(.success(()))
            } else {
                completion(.failure(NSError(
                    domain: "ChatHostViewController",
                    code: 14,
                    userInfo: [NSLocalizedDescriptionKey: "Could not open task details"]
                )))
            }
        }
    }

    private func performDayHabitAction(
        _ action: EvaDayHabitAction,
        card: EvaDayHabitCard,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard let coordinator = resolvedUseCaseCoordinator else {
            completion(.failure(NSError(
                domain: "ChatHostViewController",
                code: 14,
                userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
            )))
            return
        }

        let habitAction: HabitOccurrenceAction?
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
            presentHabitDetailSheet(for: card.habitID)
            completion(.success(()))
            return
        }

        coordinator.resolveHabitOccurrence.execute(
            habitID: card.habitID,
            action: habitAction ?? .complete,
            on: card.dueAt ?? Date()
        ) { result in
            Task { @MainActor in completion(result) }
        }
    }

    private func loadProjectsIfNeeded(
        coordinator: UseCaseCoordinator,
        completion: @escaping @MainActor @Sendable ([Project]) -> Void
        ) {
            coordinator.manageProjects.getAllProjects { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let projectsWithStats):
                    let projects = projectsWithStats.map(\.project)
                    if projects.isEmpty {
                        let fallback = [Project.createInbox()]
                        self?.cachedProjects = fallback
                        completion(fallback)
                    } else {
                        self?.cachedProjects = projects
                        completion(projects)
                    }
                case .failure:
                    completion(self?.cachedProjects ?? [Project.createInbox()])
                }
            }
        }
    }

    private func resolveTodayXPSoFar(
        coordinator: UseCaseCoordinator,
        completion: @escaping @MainActor @Sendable (Int?) -> Void
    ) {
        guard V2FeatureFlags.gamificationV2Enabled else {
            completion(0)
            return
        }
        coordinator.gamificationEngine.fetchTodayXP { result in
            DispatchQueue.main.async {
                let resolvedXP = (try? result.get()).map { max(0, $0) }
                completion(resolvedXP)
            }
        }
    }

    private func loadTaskDetailMetadata(
        projectID: UUID,
        completion: @escaping @MainActor @Sendable (Result<TaskDetailMetadataPayload, Error>) -> Void
    ) {
        guard let coordinator = resolvedUseCaseCoordinator else {
            completion(.failure(NSError(
                domain: "ChatHostViewController",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
            )))
            return
        }

        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(ChatTaskDetailMetadataState(
            projects: cachedProjects,
            sections: []
        ))

        group.enter()
        coordinator.manageProjects.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let projectsWithStats):
                accumulator.update { state in
                    state.projects = projectsWithStats.map(\.project)
                }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        coordinator.manageSections.list(projectID: projectID) { result in
            defer { group.leave() }
            switch result {
            case .success(let sections):
                accumulator.update { state in
                    state.sections = sections
                }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.notify(queue: .main) {
            let result = accumulator.result().map { state in
                TaskDetailMetadataPayload(
                    projects: state.projects,
                    sections: state.sections
                )
            }
            Task { @MainActor in
                completion(result)
            }
        }
    }

    private func loadTaskDetailRelationshipMetadata(
        projectID: UUID,
        completion: @escaping @MainActor @Sendable (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void
    ) {
        guard let coordinator = resolvedUseCaseCoordinator else {
            completion(.failure(NSError(
                domain: "ChatHostViewController",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Coordinator unavailable"]
            )))
            return
        }

        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(ChatTaskDetailRelationshipMetadataState(
            lifeAreas: [],
            tags: [],
            availableTasks: []
        ))

        group.enter()
        coordinator.manageLifeAreas.list { result in
            defer { group.leave() }
            switch result {
            case .success(let lifeAreas):
                accumulator.update { state in
                    state.lifeAreas = lifeAreas
                }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        coordinator.manageTags.list { result in
            defer { group.leave() }
            switch result {
            case .success(let tags):
                accumulator.update { state in
                    state.tags = tags
                }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        coordinator.getTasks.getTasksForProject(projectID, includeCompleted: false) { result in
            defer { group.leave() }
            switch result {
            case .success(let projectTasks):
                accumulator.update { state in
                    state.availableTasks = projectTasks.tasks
                }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.notify(queue: .main) {
            let result = accumulator.result().map { state in
                TaskDetailRelationshipMetadataPayload(
                    lifeAreas: state.lifeAreas,
                    tags: state.tags,
                    availableTasks: state.availableTasks
                )
            }
            Task { @MainActor in
                completion(result)
            }
        }
    }

    // MARK: - Theme Handling

    /// Executes applyTheme.
    private func applyTheme() {
        let themeColors = ThemeStore.shared.currentTheme.tokens.color
        view.backgroundColor = themeColors.bgCanvas
        updateNavigationBarChrome()
    }

    private func applyActivationNavigationAppearance() {
        let themeColors = ThemeStore.shared.currentTheme.tokens.color
        let onAccent = themeColors.accentOnPrimary

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themeColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: onAccent]
        appearance.largeTitleTextAttributes = [.foregroundColor: onAccent]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        leadingBarButtonItem.tintColor = onAccent
        historyBarButtonItem.tintColor = onAccent
        settingsBarButtonItem.tintColor = onAccent
        newChatBarButtonItem.tintColor = onAccent
    }

    /// Dynamic, not baked: UIKit resolves this appearance itself, and six light hexes painted a near-white bar over a dark chat.
    private func applyCompletedChatNavigationAppearance() {
        let navBackground = UIColor.lifeboardDynamic(lightHex: "#FFFDFC", darkHex: "#1C2338").withAlphaComponent(0.82)
        let navText = UIColor.lifeboardDynamic(lightHex: "#071B52", darkHex: "#F4EBDD")
        let navMuted = UIColor.lifeboardDynamic(lightHex: "#48607F", darkHex: "#C6BBA8")
        let navAccent = UIColor.lifeboardDynamic(lightHex: "#6842FF", darkHex: "#B9A5FF")
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        appearance.backgroundColor = navBackground
        appearance.shadowColor = UIColor.lifeboardDynamic(lightHex: "#DDE3EE", darkHex: "#4D526D").withAlphaComponent(0.58)
        appearance.titleTextAttributes = [.foregroundColor: navText]
        appearance.largeTitleTextAttributes = [.foregroundColor: navText]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        leadingBarButtonItem.tintColor = navMuted
        historyBarButtonItem.tintColor = navMuted
        settingsBarButtonItem.tintColor = navMuted
        newChatBarButtonItem.tintColor = navAccent
    }

    private func bindActivationCoordinator() {
        activationCoordinatorCancellable = activationCoordinator.$state
            .combineLatest(activationCoordinator.$identitySnapshot)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNavigationBarChrome()
            }
    }

    private func updateNavigationBarChrome() {
        let themeColors = ThemeStore.shared.currentTheme.tokens.color
        let chrome = activationCoordinator.navigationChrome

        leadingBarButtonItem.image = UIImage(systemName: chrome.leadingActionStyle.iconName)
        leadingBarButtonItem.accessibilityLabel = chrome.leadingActionStyle.accessibilityLabel
        navigationItem.leftBarButtonItem = leadingBarButtonItem

        if activationCoordinator.state.stage == .completed {
            applyCompletedChatNavigationAppearance()
            navigationItem.title = nil
            chatTitleView.preferredWidth = navigationTitleWidth
            chatTitleView.configure(
                title: chatNavigationChromeState.title,
                subtitle: chatNavigationChromeState.subtitle,
                titleColor: UIColor.lifeboardDynamic(lightHex: "#071B52", darkHex: "#F4EBDD"),
                subtitleColor: UIColor.lifeboardDynamic(lightHex: "#48607F", darkHex: "#C6BBA8")
            )
            chatTitleView.frame = CGRect(
                x: 0,
                y: 0,
                width: navigationTitleWidth,
                height: 38
            )
            navigationItem.titleView = chatTitleView
            navigationItem.rightBarButtonItems = normalChatNavigationItems
            return
        }

        applyActivationNavigationAppearance()
        navigationItem.title = nil
        activationTitleView.preferredWidth = navigationTitleWidth
        activationTitleView.configure(
            title: chrome.screenTitle,
            progressFraction: chrome.showsProgress ? chrome.progressFraction : nil,
            progressAccessibilityValue: chrome.progressAccessibilityValue,
            titleColor: themeColors.accentOnPrimary,
            trackColor: themeColors.accentOnPrimary.withAlphaComponent(0.22),
            fillColor: themeColors.accentOnPrimary.withAlphaComponent(0.96)
        )
        activationTitleView.frame = CGRect(
            x: 0,
            y: 0,
            width: navigationTitleWidth,
            height: chrome.showsProgress ? 42 : 24
        )
        navigationItem.titleView = activationTitleView
        navigationItem.rightBarButtonItems = chrome.showsTrailingHistoryButton ? [historyBarButtonItem] : nil
    }

    private var normalChatNavigationItems: [UIBarButtonItem]? {
        guard chatNavigationChromeState.showsUtilityActions else { return nil }
        var items: [UIBarButtonItem] = [settingsBarButtonItem]
        if chatNavigationChromeState.showsHistoryAction {
            items.append(historyBarButtonItem)
        }
        if chatNavigationChromeState.showsNewChatAction {
            items.append(newChatBarButtonItem)
        }
        return items
    }

    private func updateChatNavigationChrome(_ state: EvaChatNavigationChromeState) {
        chatNavigationChromeState = state
        updateNavigationBarChrome()
    }

    private var navigationTitleWidth: CGFloat {
        let maxWidth = view.bounds.width - 152
        let preferredWidth: CGFloat = currentLayoutClass.isPad ? 340 : 232
        return max(160, min(maxWidth, preferredWidth))
    }

    deinit {
        // Deinit is synchronous; these main-actor-owned UIKit subscriptions cannot be hopped.
        MainActor.assumeIsolated {
            themeCancellable?.cancel()
            activationCoordinatorCancellable?.cancel()
        }
    }
}

private struct ChatUnavailableSheet: View {
    let title: String
    let message: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lifeboard.bgCanvas.ignoresSafeArea()

                VStack(alignment: .leading, spacing: ClayLayoutMetrics.lg) {
                    GlassCard(
                        cornerRadius: RadiusTokens.largeCard,
                        fill: reduceTransparency ? Color.lifeboard.surfacePrimary : ClayColorTokens.glassStrong.opacity(0.86),
                        usesMaterialBackground: reduceTransparency == false
                    ) {
                        VStack(alignment: .leading, spacing: ClayLayoutMetrics.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .lifeboardFont(.display)
                                .foregroundColor(Color.lifeboard.statusWarning)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: ClayLayoutMetrics.xs) {
                                Text(title)
                                    .font(.lifeboard(.title3))
                                    .foregroundColor(Color.lifeboard.textPrimary)

                                Text(message)
                                    .font(.lifeboard(.body))
                                    .foregroundColor(Color.lifeboard.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(ClayLayoutMetrics.lg)
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .font(.lifeboard(.body))
                    .foregroundColor(.lifeboard(.accentOnPrimary))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        LinearGradient(
                            colors: [ClayColorTokens.violetFill, ClayColorTokens.violetFillDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat.unavailable.done")
                }
                .padding(ClayLayoutMetrics.lg)
                .frame(maxWidth: 560)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("chat.unavailable.close")
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

private final class EvaActivationNavigationTitleView: UIView {
    private let titleLabel = UILabel()
    private let progressTrackView = UIView()
    private let progressFillView = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?

    var preferredWidth: CGFloat = 232 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: preferredWidth, height: progressTrackView.isHidden ? 24 : 42)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        progressFraction: CGFloat?,
        progressAccessibilityValue: String?,
        titleColor: UIColor,
        trackColor: UIColor,
        fillColor: UIColor
    ) {
        titleLabel.text = title
        titleLabel.textColor = titleColor
        progressTrackView.backgroundColor = trackColor
        progressFillView.backgroundColor = fillColor

        let clampedProgress = max(0, min(progressFraction ?? 0, 1))
        progressTrackView.isHidden = progressFraction == nil
        progressTrackView.accessibilityValue = progressAccessibilityValue

        progressWidthConstraint?.isActive = false
        progressWidthConstraint = progressFillView.widthAnchor.constraint(
            equalTo: progressTrackView.widthAnchor,
            multiplier: clampedProgress
        )
        progressWidthConstraint?.isActive = true

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setup() {
        isAccessibilityElement = false

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityIdentifier = "eva.activation.nav.title"

        progressTrackView.layer.cornerRadius = 2
        progressTrackView.clipsToBounds = true
        progressTrackView.isAccessibilityElement = true
        progressTrackView.accessibilityIdentifier = "eva.activation.nav.progress"
        progressTrackView.accessibilityLabel = "Onboarding progress"

        progressFillView.layer.cornerRadius = 2
        progressFillView.clipsToBounds = true

        [titleLabel, progressTrackView, progressFillView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(titleLabel)
        addSubview(progressTrackView)
        progressTrackView.addSubview(progressFillView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            progressTrackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),
            progressTrackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            progressTrackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            progressTrackView.heightAnchor.constraint(equalToConstant: 4),
            progressTrackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressFillView.leadingAnchor.constraint(equalTo: progressTrackView.leadingAnchor),
            progressFillView.topAnchor.constraint(equalTo: progressTrackView.topAnchor),
            progressFillView.bottomAnchor.constraint(equalTo: progressTrackView.bottomAnchor)
        ])

        progressWidthConstraint = progressFillView.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint?.isActive = true
    }
}

struct LLMStoreUnavailableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .lifeboardFont(.title1)
                .foregroundColor(.lifeboard(.statusWarning))
            Text("Assistant storage unavailable")
                .font(.headline)
                .foregroundColor(.lifeboard(.textPrimary))
            Text("Restart the app to retry LLM storage initialization.")
                .font(.subheadline)
                .foregroundColor(.lifeboard(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lifeboard(.bgCanvas))
    }
}

struct LLMStoreLoadingView: View {
    var onAppear: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Preparing Eva")
                .font(.headline)
                .foregroundColor(.lifeboard(.textPrimary))
            Text("Your private on-device conversation is loading.")
                .font(.subheadline)
                .foregroundColor(.lifeboard(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lifeboard(.bgCanvas))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eva.store.loading")
        .onAppear { onAppear?() }
    }
}

/// Reusable asynchronous boundary for every surface that embeds Eva.
///
/// The closure returns `AnyView` deliberately: callers cannot accidentally
/// recreate a conditional type containing the loading, failure, and full chat
/// hierarchies.
struct LLMStoreContainerHost: View {
    @StateObject private var bootstrap = LLMStoreBootstrap.shared
    private let onLoadingAppear: (() -> Void)?
    private let content: (ModelContainer) -> AnyView

    init(
        onLoadingAppear: (() -> Void)? = nil,
        content: @escaping (ModelContainer) -> AnyView
    ) {
        self.onLoadingAppear = onLoadingAppear
        self.content = content
    }

    var body: some View {
        currentView
            .task {
                _ = await bootstrap.load()
            }
    }

    private var currentView: AnyView {
        switch bootstrap.state {
        case .ready(let container), .degraded(let container?, _):
            content(container)
        case .degraded(nil, _):
            AnyView(LLMStoreUnavailableView())
        case .idle, .loading:
            AnyView(LLMStoreLoadingView(onAppear: onLoadingAppear))
        }
    }
}

private final class EvaChatNavigationTitleView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    var preferredWidth: CGFloat = 232 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: preferredWidth, height: 38)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        subtitle: String,
        titleColor: UIColor,
        subtitleColor: UIColor
    ) {
        titleLabel.text = title
        titleLabel.textColor = titleColor
        subtitleLabel.text = subtitle
        subtitleLabel.textColor = subtitleColor
        accessibilityLabel = title
        accessibilityValue = subtitle

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setup() {
        isAccessibilityElement = true
        accessibilityIdentifier = "chat.nav.title"

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.isAccessibilityElement = false

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.8
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.isAccessibilityElement = false

        [titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }
}

// MARK: - SwiftUI chat container

struct ChatContainerView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.modelContext) private var modelContext

    var presentationMode: ChatPresentationMode = .normal
    var promptFocusRequestID: UInt64 = 0
    var onActivationChatEvent: ((EvaActivationChatEvent) -> Void)? = nil
    var onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)? = nil
    var onComposerFocusChange: ((Bool) -> Void)? = nil
    var onOpenTaskDetail: (TaskDefinition) -> Void
    var onOpenHabitDetail: ((UUID) -> Void)? = nil
    var onOpenRecordFromCard: ((EvaRecordReference) -> Void)? = nil
    var onOpenNavigationTargetFromCard: ((EvaNavigationTarget) -> Void)? = nil
    var onPerformDayTaskAction: EvaDayTaskActionHandler? = nil
    var onPerformDayHabitAction: EvaDayHabitActionHandler? = nil

    @State private var currentThread: Thread? = nil
    @FocusState private var isPromptFocused: Bool
    @State private var showChats = false
    @State private var showSettings = false

    private var useIPadSplitChatLayout: Bool {
        if case .activation(let config) = presentationMode, config.hideUtilityActions {
            return false
        }
        return V2FeatureFlags.iPadNativeShellEnabled
            && (layoutClass == .padRegular || layoutClass == .padExpanded)
    }

    var body: some View {
        Group {
            if useIPadSplitChatLayout {
                NavigationSplitView {
                    ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                        .environmentObject(appManager)
                } detail: {
                    ChatView(
                        currentThread: $currentThread,
                        isPromptFocused: $isPromptFocused,
                        showChats: .constant(false),
                        showSettings: $showSettings,
                        presentationMode: presentationMode,
                        onActivationChatEvent: onActivationChatEvent,
                        onOpenTaskDetail: onOpenTaskDetail,
                        onOpenHabitDetail: onOpenHabitDetail,
                        onOpenRecordFromCard: onOpenRecordFromCard,
                        onOpenNavigationTargetFromCard: onOpenNavigationTargetFromCard,
                        onPerformDayTaskAction: onPerformDayTaskAction,
                        onPerformDayHabitAction: onPerformDayHabitAction,
                        showsHistoryAction: false,
                        promptFocusRequestID: promptFocusRequestID,
                        storageDegradedReason: LLMDataController.isDegradedModeActive
                            ? LLMDataController.degradedModeReason ?? "unknown"
                            : nil,
                        onNavigationChromeChange: onNavigationChromeChange,
                        onComposerFocusChange: onComposerFocusChange
                    )
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                ChatView(
                    currentThread: $currentThread,
                    isPromptFocused: $isPromptFocused,
                    showChats: $showChats,
                    showSettings: $showSettings,
                    presentationMode: presentationMode,
                    onActivationChatEvent: onActivationChatEvent,
                    onOpenTaskDetail: onOpenTaskDetail,
                    onOpenHabitDetail: onOpenHabitDetail,
                    onOpenRecordFromCard: onOpenRecordFromCard,
                    onOpenNavigationTargetFromCard: onOpenNavigationTargetFromCard,
                    onPerformDayTaskAction: onPerformDayTaskAction,
                    onPerformDayHabitAction: onPerformDayHabitAction,
                    showsHistoryAction: true,
                    promptFocusRequestID: promptFocusRequestID,
                    storageDegradedReason: LLMDataController.isDegradedModeActive
                        ? LLMDataController.degradedModeReason ?? "unknown"
                        : nil,
                    onNavigationChromeChange: onNavigationChromeChange,
                    onComposerFocusChange: onComposerFocusChange
                )
            }
        }
        .environmentObject(appManager)
        .environment(llm)
        .background(Color.lifeboard(.bgCanvas))
        .if(useIPadSplitChatLayout) { base in
            base.accessibilityIdentifier("home.ipad.detail.chat")
        }
        .if(useIPadSplitChatLayout == false) { base in
            base.sheet(isPresented: $showChats) {
                ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                    .environmentObject(appManager)
                    #if os(iOS)
                    .presentationDragIndicator(.hidden)
                    .presentationDetents(layoutClass == .phone ? [.medium, .large] : [.large])
                    .presentationBackground(Color.lifeboard(.bgElevated))
                    .presentationCornerRadius(Theme.CornerRadius.modal)
                    #endif
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChatHistory)) { _ in
            if useIPadSplitChatLayout == false {
                showChats.toggle()
            }
        }
        .task {
            openReadmeScreenshotThreadIfNeeded()
        }
    }

    @MainActor
    private func openReadmeScreenshotThreadIfNeeded() {
        guard currentThread == nil,
              ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_README_LIFE_OS_TOUR") else {
            return
        }
        var descriptor = FetchDescriptor<Thread>(
            predicate: #Predicate<Thread> { thread in
                thread.title == "Launch day rescue plan"
            }
        )
        descriptor.fetchLimit = 1
        currentThread = try? modelContext.fetch(descriptor).first
    }
}
