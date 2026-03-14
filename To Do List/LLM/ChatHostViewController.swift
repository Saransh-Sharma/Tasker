//
//  ChatHostViewController.swift
//  To Do List
//
//  Hosts the SwiftUI chat/onboarding UI for the local-LLM feature.
//  If no model is installed, shows onboarding to guide download. Otherwise presents Chat UI.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

/// UIKit wrapper that embeds the SwiftUI LLM module.
extension Notification.Name {
    static let toggleChatHistory = Notification.Name("toggleChatHistory")
}

class ChatHostViewController: UIViewController, PresentationDependencyContainerAware, UseCaseCoordinatorInjectable {
    var presentationDependencyContainer: PresentationDependencyContainer?
    var useCaseCoordinator: UseCaseCoordinator!

    private let appManager = AppManager()
    private let llmEvaluator = LLMRuntimeCoordinator.shared.evaluator
    private let container: ModelContainer? = LLMDataController.shared

    private var hostingController: UIHostingController<AnyView>!
    private var themeCancellable: AnyCancellable?
    private var cachedProjects: [Project] = [Project.createInbox()]
    private var currentLayoutClass: TaskerLayoutClass = .phone

    private var resolvedUseCaseCoordinator: UseCaseCoordinator? {
        if let useCaseCoordinator {
            return useCaseCoordinator
        }

        if presentationDependencyContainer == nil,
           PresentationDependencyContainer.shared.isConfiguredForRuntime {
            presentationDependencyContainer = PresentationDependencyContainer.shared
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

        let themeColors = TaskerThemeManager.shared.currentTheme.tokens.color
        view.backgroundColor = themeColors.bgCanvas

        currentLayoutClass = TaskerLayoutResolver.classify(view: view)
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

        themeCancellable = TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshLayoutClassIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshLayoutClassIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.acquireSession(reason: "chat_host_visible")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "chat_host_will_disappear")
            LLMRuntimeCoordinator.shared.cancelGenerationIfActive(reason: "chat_host_will_disappear")
            LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_host_visible")
        }
    }

    private func resolveDependenciesIfNeeded() {
        if presentationDependencyContainer == nil,
           PresentationDependencyContainer.shared.isConfiguredForRuntime {
            presentationDependencyContainer = PresentationDependencyContainer.shared
        }

        if useCaseCoordinator == nil,
           let presentationDependencyContainer,
           presentationDependencyContainer.isConfiguredForRuntime {
            useCaseCoordinator = presentationDependencyContainer.coordinator
        }
    }

    private func makeRootView(layoutClass: TaskerLayoutClass) -> AnyView {
        let rootView: AnyView
        if let container {
            rootView = AnyView(
                ChatContainerView(onOpenTaskDetail: { [weak self] task in
                    self?.presentTaskDetailSheet(for: task)
                })
                .environmentObject(appManager)
                .environment(llmEvaluator)
                .modelContainer(container)
            )
        } else {
            rootView = AnyView(LLMStoreUnavailableView())
        }

        return AnyView(rootView.taskerLayoutClass(layoutClass))
    }

    private func refreshLayoutClassIfNeeded() {
        let nextLayoutClass = TaskerLayoutResolver.classify(view: view)
        guard nextLayoutClass != currentLayoutClass else { return }
        currentLayoutClass = nextLayoutClass
        hostingController.rootView = makeRootView(layoutClass: nextLayoutClass)
    }

    // MARK: - Navigation Bar Setup

    /// Executes setupNavigationBar.
    private func setupNavigationBar() {
        title = "Eva"

        let themeColors = TaskerThemeManager.shared.currentTheme.tokens.color
        let onAccent = themeColors.accentOnPrimary

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themeColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: onAccent]
        appearance.largeTitleTextAttributes = [.foregroundColor: onAccent]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = false

        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(onBackTapped)
        )
        backButton.tintColor = onAccent
        backButton.accessibilityLabel = "Back"
        navigationItem.leftBarButtonItem = backButton

        let historyButton = UIBarButtonItem(
            image: UIImage(systemName: "text.below.folder"),
            style: .plain,
            target: self,
            action: #selector(onHistoryTapped)
        )
        historyButton.tintColor = onAccent
        historyButton.accessibilityLabel = "History"
        navigationItem.rightBarButtonItem = historyButton
    }

    @objc private func onBackTapped() {
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "chat_host_back")
            LLMRuntimeCoordinator.shared.cancelGenerationIfActive(reason: "chat_host_back")
            LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_host_visible")
        }
        dismiss(animated: true)
    }

    @objc private func onHistoryTapped() {
        NotificationCenter.default.post(name: .toggleChatHistory, object: nil)
    }

    // MARK: - Task Detail Presentation

    private func presentTaskDetailSheet(for task: TaskDefinition) {
        guard let coordinator = resolvedUseCaseCoordinator else {
            logWarning(
                event: "chat_task_detail_unavailable",
                message: "Skipped task detail from chat because dependencies were unavailable",
                fields: ["task_id": task.id.uuidString]
            )
            showTaskDetailUnavailableAlert()
            return
        }

        loadProjectsIfNeeded(coordinator: coordinator) { [weak self] projects in
            guard let self else { return }
            self.resolveTodayXPSoFar(coordinator: coordinator) { todayXPSoFar in
                let detailView = TaskDetailSheetView(
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

                let layoutClass = TaskerLayoutResolver.classify(view: self.view)
                let hostingController = UIHostingController(rootView: detailView.taskerLayoutClass(layoutClass))
                hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
                hostingController.modalPresentationStyle = .pageSheet

                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = true
                }

                self.present(hostingController, animated: true)
            }
        }
    }

    private func showTaskDetailUnavailableAlert() {
        let alert = UIAlertController(
            title: "Task details unavailable",
            message: "Could not open task details from chat right now. Please try again from Home.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func loadProjectsIfNeeded(
        coordinator: UseCaseCoordinator,
        completion: @escaping ([Project]) -> Void
    ) {
        coordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
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
        completion: @escaping (Int?) -> Void
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
        completion: @escaping (Result<TaskDetailMetadataPayload, Error>) -> Void
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
        let lock = NSLock()
        var firstError: Error?

        var loadedProjects: [Project] = cachedProjects
        var loadedSections: [TaskerProjectSection] = []

        func record(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        coordinator.manageProjects.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let projectsWithStats):
                loadedProjects = projectsWithStats.map(\.project)
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        coordinator.manageSections.list(projectID: projectID) { result in
            defer { group.leave() }
            switch result {
            case .success(let sections):
                loadedSections = sections
            case .failure(let error):
                record(error)
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(TaskDetailMetadataPayload(
                projects: loadedProjects,
                sections: loadedSections
            )))
        }
    }

    private func loadTaskDetailRelationshipMetadata(
        projectID: UUID,
        completion: @escaping (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void
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
        let lock = NSLock()
        var firstError: Error?

        var loadedLifeAreas: [LifeArea] = []
        var loadedTags: [TagDefinition] = []
        var availableTasks: [TaskDefinition] = []

        func record(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        coordinator.manageLifeAreas.list { result in
            defer { group.leave() }
            switch result {
            case .success(let lifeAreas):
                loadedLifeAreas = lifeAreas
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        coordinator.manageTags.list { result in
            defer { group.leave() }
            switch result {
            case .success(let tags):
                loadedTags = tags
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        coordinator.getTasks.getTasksForProject(projectID, includeCompleted: false) { result in
            defer { group.leave() }
            switch result {
            case .success(let projectTasks):
                availableTasks = projectTasks.tasks
            case .failure(let error):
                record(error)
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(TaskDetailRelationshipMetadataPayload(
                lifeAreas: loadedLifeAreas,
                tags: loadedTags,
                availableTasks: availableTasks
            )))
        }
    }

    // MARK: - Theme Handling

    /// Executes applyTheme.
    private func applyTheme() {
        let themeColors = TaskerThemeManager.shared.currentTheme.tokens.color
        view.backgroundColor = themeColors.bgCanvas
        let onAccent = themeColors.accentOnPrimary

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themeColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: onAccent]
        appearance.largeTitleTextAttributes = [.foregroundColor: onAccent]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationItem.leftBarButtonItem?.tintColor = onAccent
        navigationItem.rightBarButtonItem?.tintColor = onAccent
    }

    deinit {
        themeCancellable?.cancel()
    }
}

struct LLMStoreUnavailableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.orange)
            Text("Assistant storage unavailable")
                .font(.headline)
                .foregroundColor(.tasker(.textPrimary))
            Text("Restart the app to retry LLM storage initialization.")
                .font(.subheadline)
                .foregroundColor(.tasker(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tasker(.bgCanvas))
    }
}

// MARK: - SwiftUI container deciding between onboarding and chat

struct ChatContainerView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.taskerLayoutClass) private var layoutClass

    var onOpenTaskDetail: (TaskDefinition) -> Void

    @State private var currentThread: Thread? = nil
    @FocusState private var isPromptFocused: Bool
    @State private var showChats = false
    @State private var showSettings = false
    @State private var showOnboarding = true

    private var useIPadSplitChatLayout: Bool {
        V2FeatureFlags.iPadNativeShellEnabled
            && (layoutClass == .padRegular || layoutClass == .padExpanded)
    }

    var body: some View {
        Group {
            if appManager.installedModels.isEmpty {
                OnboardingView(showOnboarding: $showOnboarding)
                    .onChange(of: appManager.installedModels) { _, _ in
                        showOnboarding = false
                    }
            } else {
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
                            onOpenTaskDetail: onOpenTaskDetail
                        )
                    }
                    .navigationSplitViewStyle(.balanced)
                } else {
                    ChatView(
                        currentThread: $currentThread,
                        isPromptFocused: $isPromptFocused,
                        showChats: $showChats,
                        showSettings: $showSettings,
                        onOpenTaskDetail: onOpenTaskDetail
                    )
                }
            }
        }
        .accessibilityIdentifier("home.ipad.detail.chat")
        .environmentObject(appManager)
        .environment(llm)
        .background(Color.tasker(.bgCanvas))
        .if(useIPadSplitChatLayout == false) { base in
            base.sheet(isPresented: $showChats) {
                ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                    .environmentObject(appManager)
                    #if os(iOS)
                    .presentationDragIndicator(.hidden)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.medium, .large] : [.large])
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.modal)
                #endif
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChatHistory)) { _ in
            if useIPadSplitChatLayout == false {
                showChats.toggle()
            }
        }
    }
}
