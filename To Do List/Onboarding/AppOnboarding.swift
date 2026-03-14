import SwiftUI
import UIKit
import Combine

extension Notification.Name {
    static let taskerStartOnboardingRequested = Notification.Name("TaskerStartOnboardingRequested")
}

private func onboardingLogLine(event: String, message: String? = nil, fields: [String: String] = [:]) -> String {
    var parts = ["event=\(event)"]
    if let message, !message.isEmpty {
        parts.append("message=\(message)")
    }
    if !fields.isEmpty {
        let serializedFields = fields
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        parts.append(serializedFields)
    }
    return parts.joined(separator: " | ")
}

private func logOnboardingInfo(event: String, message: String? = nil, fields: [String: String] = [:]) {
    logInfo(onboardingLogLine(event: event, message: message, fields: fields))
}

private func logOnboardingError(event: String, message: String? = nil, fields: [String: String] = [:]) {
    logError(onboardingLogLine(event: event, message: message, fields: fields))
}

enum OnboardingOutcome: String, Codable, Equatable {
    case completed
    case skippedAfterWelcome
}

struct AppOnboardingState: Codable, Equatable {
    static let currentVersion = 1

    var outcome: OnboardingOutcome?
    var completedVersion: Int?
    var establishedWorkspacePromptDismissedVersion: Int?

    var hasHandledCurrentVersion: Bool {
        completedVersion == Self.currentVersion && outcome != nil
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case lifeAreas
    case projects
    case tasks
    case completeTask
    case finish

    var progressIndex: Int {
        rawValue + 1
    }

    var progressLabel: String {
        "Step \(progressIndex) of \(Self.allCases.count)"
    }
}

struct OnboardingWorkspaceSnapshot: Equatable {
    let customLifeAreaCount: Int
    let customProjectCount: Int
    let taskCount: Int

    var isEffectivelyEmpty: Bool {
        customLifeAreaCount == 0 && customProjectCount == 0 && taskCount < 3
    }
}

enum OnboardingEligibility: Equatable {
    case fullFlow(OnboardingWorkspaceSnapshot)
    case promptOnly(OnboardingWorkspaceSnapshot)
    case suppressed
}

final class AppOnboardingStateStore {
    static let shared = AppOnboardingStateStore()

    private let userDefaults: UserDefaults
    private let key = "app_onboarding_state_v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppOnboardingState {
        guard let data = userDefaults.data(forKey: key),
              let state = try? JSONDecoder().decode(AppOnboardingState.self, from: data) else {
            return AppOnboardingState()
        }
        return state
    }

    func markHandled(outcome: OnboardingOutcome, version: Int = AppOnboardingState.currentVersion) {
        var state = load()
        state.outcome = outcome
        state.completedVersion = version
        save(state)
    }

    func markEstablishedWorkspacePromptDismissed(version: Int = AppOnboardingState.currentVersion) {
        var state = load()
        state.establishedWorkspacePromptDismissedVersion = version
        save(state)
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }

    private func save(_ state: AppOnboardingState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: key)
    }
}

struct StarterTaskTemplate: Identifiable, Equatable {
    let id: String
    let projectTemplateID: String
    let title: String
    let details: String
    let durationMinutes: Int
    let priority: TaskPriority
    let type: TaskType
    let energy: TaskEnergy

    func makePrefill(project: Project) -> AddTaskPrefillTemplate {
        AddTaskPrefillTemplate(
            title: title,
            details: details,
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: project.lifeAreaID,
            priority: priority,
            type: type,
            dueDateIntent: .today,
            estimatedDuration: TimeInterval(durationMinutes * 60),
            energy: energy,
            category: .general,
            context: .anywhere,
            showMoreDetails: true
        )
    }
}

struct StarterProjectTemplate: Identifiable, Equatable {
    let id: String
    let lifeAreaTemplateID: String
    let name: String
    let summary: String
    let taskTemplates: [StarterTaskTemplate]
}

struct StarterLifeAreaTemplate: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let colorHex: String
    let projects: [StarterProjectTemplate]
}

struct ResolvedLifeAreaSelection: Equatable {
    let template: StarterLifeAreaTemplate
    let lifeArea: LifeArea
    let reusedExisting: Bool
}

struct ResolvedProjectSelection: Equatable {
    let template: StarterProjectTemplate
    let project: Project
    let reusedExisting: Bool
}

struct AppOnboardingSummary: Equatable {
    let lifeAreaCount: Int
    let projectCount: Int
    let createdTaskCount: Int
    let completedTaskTitle: String?
}

enum PendingOnboardingPresentation: Equatable {
    case prompt
    case fullFlow(source: String)
    case completion(summary: AppOnboardingSummary)

    var priority: Int {
        switch self {
        case .prompt:
            return 1
        case .fullFlow:
            return 2
        case .completion:
            return 3
        }
    }

    var analyticsLabel: String {
        switch self {
        case .prompt:
            return "prompt"
        case .fullFlow:
            return "full_flow"
        case .completion:
            return "completion"
        }
    }
}

struct OnboardingPresentationQueue: Equatable {
    private(set) var pending: PendingOnboardingPresentation?

    mutating func enqueue(_ presentation: PendingOnboardingPresentation) {
        guard let pending else {
            self.pending = presentation
            return
        }
        if presentation.priority >= pending.priority {
            self.pending = presentation
        }
    }

    mutating func markPresented(_ presentation: PendingOnboardingPresentation) {
        guard pending == presentation else { return }
        pending = nil
    }
}

struct OnboardingCompletionTrackingState: Equatable {
    var highlightedTaskID: UUID?
    var acceptableTaskIDs: Set<UUID> = []

    func acceptsCompletion(reason: String?, taskID: UUID) -> Bool {
        reason == "completed" && acceptableTaskIDs.contains(taskID)
    }
}

enum StarterWorkspaceCatalog {
    static let allLifeAreas: [StarterLifeAreaTemplate] = [
        StarterLifeAreaTemplate(
            id: "health",
            name: "Health",
            subtitle: "Energy, movement, and recovery",
            icon: "heart.fill",
            colorHex: "#22C55E",
            projects: [
                StarterProjectTemplate(
                    id: "health-move",
                    lifeAreaTemplateID: "health",
                    name: "Move your body",
                    summary: "Quick wins for energy and momentum.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-health-move-1",
                            projectTemplateID: "health-move",
                            title: "Walk for 10 minutes",
                            details: "Keep it tiny. Shoes on, outside, one short lap.",
                            durationMinutes: 10,
                            priority: .low,
                            type: .morning,
                            energy: .low
                        ),
                        StarterTaskTemplate(
                            id: "task-health-move-2",
                            projectTemplateID: "health-move",
                            title: "Lay out workout clothes",
                            details: "Make the next session frictionless before you forget.",
                            durationMinutes: 5,
                            priority: .low,
                            type: .morning,
                            energy: .low
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "health-reset",
                    lifeAreaTemplateID: "health",
                    name: "Meal reset",
                    summary: "Simple routines that keep the day stable.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-health-reset-1",
                            projectTemplateID: "health-reset",
                            title: "Refill water bottle",
                            details: "Set yourself up for the next few hours.",
                            durationMinutes: 3,
                            priority: .low,
                            type: .morning,
                            energy: .low
                        )
                    ]
                )
            ]
        ),
        StarterLifeAreaTemplate(
            id: "career",
            name: "Career",
            subtitle: "Ship work without drowning in it",
            icon: "briefcase.fill",
            colorHex: "#3B82F6",
            projects: [
                StarterProjectTemplate(
                    id: "career-ship",
                    lifeAreaTemplateID: "career",
                    name: "Ship one thing",
                    summary: "A focused lane for the next visible win.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-career-ship-1",
                            projectTemplateID: "career-ship",
                            title: "Write the first rough draft",
                            details: "Fifteen messy minutes beats waiting for clarity.",
                            durationMinutes: 15,
                            priority: .low,
                            type: .morning,
                            energy: .medium
                        ),
                        StarterTaskTemplate(
                            id: "task-career-ship-2",
                            projectTemplateID: "career-ship",
                            title: "Send one unblocker message",
                            details: "Ask the question that keeps the work moving.",
                            durationMinutes: 5,
                            priority: .low,
                            type: .morning,
                            energy: .low
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "career-admin",
                    lifeAreaTemplateID: "career",
                    name: "Work admin reset",
                    summary: "Small cleanup so work feels lighter.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-career-admin-1",
                            projectTemplateID: "career-admin",
                            title: "Archive or reply to one email thread",
                            details: "Pick one open loop and close it.",
                            durationMinutes: 8,
                            priority: .low,
                            type: .morning,
                            energy: .low
                        )
                    ]
                )
            ]
        ),
        StarterLifeAreaTemplate(
            id: "home",
            name: "Home",
            subtitle: "Keep your space calm and usable",
            icon: "house.fill",
            colorHex: "#F59E0B",
            projects: [
                StarterProjectTemplate(
                    id: "home-reset",
                    lifeAreaTemplateID: "home",
                    name: "Home reset",
                    summary: "Tiny resets that remove visual drag.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-home-reset-1",
                            projectTemplateID: "home-reset",
                            title: "Clear one surface",
                            details: "Desk, counter, or bedside table. One surface is enough.",
                            durationMinutes: 10,
                            priority: .low,
                            type: .evening,
                            energy: .low
                        ),
                        StarterTaskTemplate(
                            id: "task-home-reset-2",
                            projectTemplateID: "home-reset",
                            title: "Put away five things",
                            details: "Fast enough that you can do it right now.",
                            durationMinutes: 5,
                            priority: .low,
                            type: .evening,
                            energy: .low
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "home-errands",
                    lifeAreaTemplateID: "home",
                    name: "Errands",
                    summary: "The outside-the-house stuff you keep carrying.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-home-errands-1",
                            projectTemplateID: "home-errands",
                            title: "Write the one errand you keep forgetting",
                            details: "Capture it now so it stops taking up headspace.",
                            durationMinutes: 4,
                            priority: .low,
                            type: .morning,
                            energy: .low
                        )
                    ]
                )
            ]
        ),
        StarterLifeAreaTemplate(
            id: "learning",
            name: "Learning",
            subtitle: "Study, read, and make it stick",
            icon: "book.fill",
            colorHex: "#8B5CF6",
            projects: [
                StarterProjectTemplate(
                    id: "learning-sprint",
                    lifeAreaTemplateID: "learning",
                    name: "Study sprint",
                    summary: "Keep learning in short, winnable sessions.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-learning-sprint-1",
                            projectTemplateID: "learning-sprint",
                            title: "Study for 15 focused minutes",
                            details: "Timer on. Stop while energy is still good.",
                            durationMinutes: 15,
                            priority: .low,
                            type: .morning,
                            energy: .medium
                        )
                    ]
                )
            ]
        ),
        StarterLifeAreaTemplate(
            id: "money",
            name: "Money",
            subtitle: "Bills, budgeting, and fewer surprise fires",
            icon: "dollarsign.circle.fill",
            colorHex: "#14B8A6",
            projects: [
                StarterProjectTemplate(
                    id: "money-bills",
                    lifeAreaTemplateID: "money",
                    name: "Bills and budget",
                    summary: "Simple maintenance so money feels handled.",
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-money-bills-1",
                            projectTemplateID: "money-bills",
                            title: "Check one upcoming bill",
                            details: "Confirm due date and remove uncertainty.",
                            durationMinutes: 6,
                            priority: .low,
                            type: .morning,
                            energy: .low
                        )
                    ]
                )
            ]
        )
    ]

    static func defaultLifeAreaSelectionIDs() -> Set<String> {
        Set(allLifeAreas.prefix(3).map(\.id))
    }

    static func projectTemplates(for lifeAreaIDs: Set<String>) -> [StarterProjectTemplate] {
        allLifeAreas
            .filter { lifeAreaIDs.contains($0.id) }
            .flatMap(\.projects)
    }

    static func defaultProjectSelectionIDs(for lifeAreaIDs: Set<String>) -> Set<String> {
        let starterProjects = allLifeAreas
            .filter { lifeAreaIDs.contains($0.id) }
            .compactMap { $0.projects.first?.id }
        return Set(starterProjects.prefix(3))
    }

    static func resolveLifeAreaSelections(
        selected: [StarterLifeAreaTemplate],
        existing: [LifeArea]
    ) -> [(template: StarterLifeAreaTemplate, existing: LifeArea?)] {
        var existingByName: [String: LifeArea] = [:]
        for lifeArea in existing {
            existingByName[normalizedName(lifeArea.name)] = lifeArea
        }
        return selected.map { template in
            (template, existingByName[normalizedName(template.name)])
        }
    }

    static func resolveProjectSelections(
        selected: [StarterProjectTemplate],
        existing: [Project],
        lifeAreasByTemplateID: [String: LifeArea]
    ) -> [(template: StarterProjectTemplate, existing: Project?, lifeArea: LifeArea)] {
        var existingByName: [String: Project] = [:]
        for project in existing {
            existingByName[normalizedName(project.name)] = project
        }
        return selected.compactMap { template in
            guard let lifeArea = lifeAreasByTemplateID[template.lifeAreaTemplateID] else { return nil }
            return (template, existingByName[normalizedName(template.name)], lifeArea)
        }
    }

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isCustomLifeArea(_ lifeArea: LifeArea) -> Bool {
        lifeArea.isArchived == false && normalizedName(lifeArea.name) != "general"
    }

    static func isCustomProject(_ project: Project) -> Bool {
        project.isArchived == false && project.isInbox == false && project.isDefault == false
    }
}

final class OnboardingEligibilityService {
    private let stateStore: AppOnboardingStateStore
    private let launchArguments: Set<String>
    private let fetchLifeAreas: () async throws -> [LifeArea]
    private let fetchProjects: () async throws -> [Project]
    private let fetchTasks: () async throws -> [TaskDefinition]

    init(
        stateStore: AppOnboardingStateStore = .shared,
        launchArguments: [String] = ProcessInfo.processInfo.arguments,
        fetchLifeAreas: @escaping () async throws -> [LifeArea],
        fetchProjects: @escaping () async throws -> [Project],
        fetchTasks: @escaping () async throws -> [TaskDefinition]
    ) {
        self.stateStore = stateStore
        self.launchArguments = Set(launchArguments)
        self.fetchLifeAreas = fetchLifeAreas
        self.fetchProjects = fetchProjects
        self.fetchTasks = fetchTasks
    }

    convenience init(
        stateStore: AppOnboardingStateStore = .shared,
        lifeAreaRepository: LifeAreaRepositoryProtocol?,
        projectRepository: ProjectRepositoryProtocol?,
        taskRepository: TaskDefinitionRepositoryProtocol?,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.init(
            stateStore: stateStore,
            launchArguments: launchArguments,
            fetchLifeAreas: {
                guard let lifeAreaRepository else { return [] }
                return try await lifeAreaRepository.fetchAllAsync()
            },
            fetchProjects: {
                guard let projectRepository else { return [] }
                return try await projectRepository.fetchAllProjectsAsync()
            },
            fetchTasks: {
                guard let taskRepository else { return [] }
                return try await taskRepository.fetchAllAsync()
            }
        )
    }

    func evaluate(version: Int = AppOnboardingState.currentVersion) async -> OnboardingEligibility {
        if launchArguments.contains("-SKIP_ONBOARDING") {
            return .suppressed
        }

        let state = stateStore.load()
        if state.completedVersion == version {
            return .suppressed
        }

        let snapshot: OnboardingWorkspaceSnapshot
        do {
            async let lifeAreas = fetchLifeAreas()
            async let projects = fetchProjects()
            async let tasks = fetchTasks()

            let resolvedLifeAreas = try await lifeAreas
            let resolvedProjects = try await projects
            let resolvedTasks = try await tasks

            snapshot = OnboardingWorkspaceSnapshot(
                customLifeAreaCount: resolvedLifeAreas.filter(StarterWorkspaceCatalog.isCustomLifeArea).count,
                customProjectCount: resolvedProjects.filter(StarterWorkspaceCatalog.isCustomProject).count,
                taskCount: resolvedTasks.count
            )
        } catch {
            logOnboardingError(
                event: "onboarding_eligibility_failed",
                message: "Failed to inspect workspace for onboarding eligibility",
                fields: ["error": error.localizedDescription]
            )
            return .suppressed
        }

        if snapshot.isEffectivelyEmpty {
            return .fullFlow(snapshot)
        }

        if state.establishedWorkspacePromptDismissedVersion == version {
            return .suppressed
        }

        return .promptOnly(snapshot)
    }
}

@MainActor
final class HomeOnboardingGuidanceModel: ObservableObject {
    struct State: Equatable {
        let taskID: UUID
        let title: String
        let message: String
    }

    @Published private(set) var state: State?

    func showCompletionGuide(task: TaskDefinition) {
        state = State(
            taskID: task.id,
            title: "Finish your first win",
            message: "Tap the checkbox on \"\(task.title)\", or finish the other starter task, so you can feel the XP and streak loop for real."
        )
    }

    func clear() {
        state = nil
    }
}

@MainActor
final class AppOnboardingFlowViewModel: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var selectedLifeAreaIDs: Set<String>
    @Published var selectedProjectIDs: Set<String>
    @Published private(set) var resolvedLifeAreas: [ResolvedLifeAreaSelection] = []
    @Published private(set) var resolvedProjects: [ResolvedProjectSelection] = []
    @Published private(set) var createdTaskTemplateIDs: [String: UUID] = [:]
    @Published private(set) var createdTaskIDs: [UUID] = []
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var reusedLifeAreaCount = 0
    @Published private(set) var reusedProjectCount = 0

    let catalog: [StarterLifeAreaTemplate]

    init(catalog: [StarterLifeAreaTemplate] = StarterWorkspaceCatalog.allLifeAreas) {
        self.catalog = catalog
        let selectedLifeAreaIDs = StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs()
        self.selectedLifeAreaIDs = selectedLifeAreaIDs
        self.selectedProjectIDs = StarterWorkspaceCatalog.defaultProjectSelectionIDs(for: selectedLifeAreaIDs)
    }

    var selectedLifeAreas: [StarterLifeAreaTemplate] {
        catalog.filter { selectedLifeAreaIDs.contains($0.id) }
    }

    var availableProjectTemplates: [StarterProjectTemplate] {
        StarterWorkspaceCatalog.projectTemplates(for: selectedLifeAreaIDs)
    }

    var selectedProjectTemplates: [StarterProjectTemplate] {
        availableProjectTemplates.filter { selectedProjectIDs.contains($0.id) }
    }

    var taskSuggestions: [StarterTaskTemplate] {
        let sourceProjects = resolvedProjects.isEmpty ? selectedProjectTemplates : resolvedProjects.map(\.template)
        return sourceProjects.flatMap(\.taskTemplates)
    }

    var canContinueLifeAreas: Bool {
        (2...3).contains(selectedLifeAreaIDs.count)
    }

    var canContinueProjects: Bool {
        selectedProjectIDs.count >= 2
    }

    var hasCreatedRequiredTasks: Bool {
        createdTaskIDs.count >= 2
    }

    var nextTaskTemplateToCreate: StarterTaskTemplate? {
        taskSuggestions.first(where: { createdTaskTemplateIDs[$0.id] == nil })
    }

    func toggleLifeArea(_ templateID: String) {
        if selectedLifeAreaIDs.contains(templateID) {
            selectedLifeAreaIDs.remove(templateID)
        } else if selectedLifeAreaIDs.count < 3 {
            selectedLifeAreaIDs.insert(templateID)
        }

        let validProjectIDs = Set(availableProjectTemplates.map(\.id))
        selectedProjectIDs = selectedProjectIDs.intersection(validProjectIDs)

        let defaults = StarterWorkspaceCatalog.defaultProjectSelectionIDs(for: selectedLifeAreaIDs)
        for projectID in defaults where selectedProjectIDs.count < 3 {
            selectedProjectIDs.insert(projectID)
        }
    }

    func toggleProject(_ templateID: String) {
        if selectedProjectIDs.contains(templateID) {
            selectedProjectIDs.remove(templateID)
        } else {
            selectedProjectIDs.insert(templateID)
        }
    }

    func moveToLifeAreas() {
        step = .lifeAreas
        errorMessage = nil
    }

    func applyResolvedLifeAreas(_ selections: [ResolvedLifeAreaSelection]) {
        resolvedLifeAreas = selections
        reusedLifeAreaCount = selections.filter(\.reusedExisting).count
        step = .projects
        errorMessage = nil
    }

    func applyResolvedProjects(_ selections: [ResolvedProjectSelection]) {
        resolvedProjects = selections
        reusedProjectCount = selections.filter(\.reusedExisting).count
        step = .tasks
        errorMessage = nil
    }

    func registerCreatedTask(templateID: String, taskID: UUID) {
        createdTaskTemplateIDs[templateID] = taskID
        if createdTaskIDs.contains(taskID) == false {
            createdTaskIDs.append(taskID)
        }
        errorMessage = nil
    }

    func resetForReplay() {
        step = .welcome
        selectedLifeAreaIDs = StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs()
        selectedProjectIDs = StarterWorkspaceCatalog.defaultProjectSelectionIDs(for: selectedLifeAreaIDs)
        resolvedLifeAreas = []
        resolvedProjects = []
        createdTaskTemplateIDs = [:]
        createdTaskIDs = []
        isWorking = false
        errorMessage = nil
        reusedLifeAreaCount = 0
        reusedProjectCount = 0
    }
}

@MainActor
final class AppOnboardingCoordinator: NSObject {
    private weak var homeViewController: HomeViewController?
    private let presentationDependencyContainer: PresentationDependencyContainer
    private let guidanceModel: HomeOnboardingGuidanceModel
    private let stateStore: AppOnboardingStateStore
    private let eligibilityService: OnboardingEligibilityService
    private let notificationCenter: NotificationCenter

    private let viewModel = AppOnboardingFlowViewModel()
    private var onboardingHost: UIHostingController<AnyView>?
    private var promptHost: UIHostingController<AnyView>?
    private var completionHost: UIHostingController<AnyView>?
    private var completionObserver: AnyCancellable?
    private var completionPollingTask: Task<Void, Never>?
    private var hasEvaluatedLaunch = false
    private var presentationQueue = OnboardingPresentationQueue()
    private var completionTracking = OnboardingCompletionTrackingState()
    private var completionPresentationRetryCount = 0
    private var pendingPresentationWasBlocked = false
    private var isHandlingCompletionTarget = false
    private var completionStepActivatedAt: Date?

    init?(
        homeViewController: HomeViewController,
        presentationDependencyContainer: PresentationDependencyContainer?,
        guidanceModel: HomeOnboardingGuidanceModel,
        stateStore: AppOnboardingStateStore = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        guard let presentationDependencyContainer else { return nil }
        guard presentationDependencyContainer.isConfiguredForRuntime else { return nil }

        self.homeViewController = homeViewController
        self.presentationDependencyContainer = presentationDependencyContainer
        self.guidanceModel = guidanceModel
        self.stateStore = stateStore
        self.notificationCenter = notificationCenter
        self.eligibilityService = OnboardingEligibilityService(
            stateStore: stateStore,
            lifeAreaRepository: EnhancedDependencyContainer.shared.lifeAreaRepository,
            projectRepository: EnhancedDependencyContainer.shared.projectRepository,
            taskRepository: EnhancedDependencyContainer.shared.taskDefinitionRepository
        )
        super.init()
    }

    func evaluateLaunchIfNeeded() {
        guard hasEvaluatedLaunch == false else { return }
        hasEvaluatedLaunch = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch await eligibilityService.evaluate() {
            case .fullFlow:
                enqueuePresentation(.fullFlow(source: "launch_auto"))
            case .promptOnly:
                enqueuePresentation(.prompt)
            case .suppressed:
                break
            }
        }
    }

    func restartOnboarding() {
        stateStore.clear()
        viewModel.resetForReplay()
        guidanceModel.clear()
        completionTracking = OnboardingCompletionTrackingState()
        completionPresentationRetryCount = 0
        presentationQueue = OnboardingPresentationQueue()
        pendingPresentationWasBlocked = false
        isHandlingCompletionTarget = false
        completionStepActivatedAt = nil
        cancelCompletionObservation()
        logOnboardingInfo(
            event: "onboarding_restart_requested",
            message: "User requested onboarding replay from settings"
        )
        enqueuePresentation(.fullFlow(source: "settings_replay"))
    }

    func drainPendingPresentationIfPossible() {
        guard let pending = presentationQueue.pending else { return }
        if attemptPresentation(pending, source: "drain") {
            presentationQueue.markPresented(pending)
        }
    }

    private func enqueuePresentation(_ presentation: PendingOnboardingPresentation) {
        let previousPending = presentationQueue.pending
        presentationQueue.enqueue(presentation)
        let activePending = presentationQueue.pending

        if activePending == presentation,
           shouldLogQueuedPresentation(previous: previousPending, current: presentation),
           isPresentationBlocked() {
            pendingPresentationWasBlocked = true
            logOnboardingInfo(
                event: "onboarding_presentation_queued",
                message: "Queued onboarding presentation until the host is free",
                fields: [
                    "presentation": presentation.analyticsLabel,
                    "blocked_by_presented_controller": String(homeViewController?.presentedViewController != nil)
                ]
            )
        }

        drainPendingPresentationIfPossible()
    }

    private func shouldLogQueuedPresentation(
        previous: PendingOnboardingPresentation?,
        current: PendingOnboardingPresentation
    ) -> Bool {
        guard previous != current else { return false }
        if let previous, previous.priority > current.priority {
            return false
        }
        return true
    }

    @discardableResult
    private func attemptPresentation(_ presentation: PendingOnboardingPresentation, source: String) -> Bool {
        let presented: Bool
        switch presentation {
        case .prompt:
            presented = presentPromptIfPossible()
        case .fullFlow(let origin):
            presented = presentFullFlowIfPossible(source: origin)
        case .completion(let summary):
            presented = presentCompletionIfPossible(summary: summary)
        }

        if presented {
            if pendingPresentationWasBlocked {
                pendingPresentationWasBlocked = false
                logOnboardingInfo(
                    event: "onboarding_presentation_drained",
                    message: "Presented a queued onboarding surface",
                    fields: [
                        "presentation": presentation.analyticsLabel,
                        "source": source
                    ]
                )
            }
        }

        return presented
    }

    private func isPresentationBlocked() -> Bool {
        homeViewController?.presentedViewController != nil
    }

    private func presentPromptIfPossible() -> Bool {
        guard promptHost == nil else { return false }
        guard let homeViewController, homeViewController.presentedViewController == nil else { return false }

        logOnboardingInfo(
            event: "onboarding_started",
            message: "Presented onboarding prompt for established workspace",
            fields: ["mode": "prompt_only"]
        )

        let root = AnyView(
            AppOnboardingPromptSheetView(
                onStart: { [weak self] in
                    self?.dismissPrompt(animated: true) {
                        self?.enqueuePresentation(.fullFlow(source: "prompt_opt_in"))
                    }
                },
                onNotNow: { [weak self] in
                    guard let self else { return }
                    self.stateStore.markEstablishedWorkspacePromptDismissed()
                    logOnboardingInfo(
                        event: "onboarding_prompt_dismissed",
                        message: "User dismissed onboarding prompt for established workspace"
                    )
                    self.dismissPrompt(animated: true, completion: nil)
                }
            )
            .taskerLayoutClass(homeViewController.currentOnboardingLayoutClass)
        )

        let controller: UIHostingController<AnyView> = UIHostingController(rootView: root)
        controller.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [UISheetPresentationController.Detent.medium()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 28
        }
        promptHost = controller
        homeViewController.present(controller, animated: true)
        return true
    }

    private func dismissPrompt(animated: Bool, completion: (() -> Void)?) {
        guard let promptHost else {
            completion?()
            return
        }
        self.promptHost = nil
        promptHost.dismiss(animated: animated, completion: completion)
    }

    private func presentFullFlowIfPossible(source: String) -> Bool {
        dismissPrompt(animated: false, completion: nil)
        guidanceModel.clear()

        guard onboardingHost == nil else { return false }
        guard let homeViewController, homeViewController.presentedViewController == nil else { return false }

        viewModel.resetForReplay()
        logOnboardingInfo(
            event: "onboarding_started",
            message: "Started guided onboarding flow",
            fields: ["source": source]
        )

        let root = AnyView(
            AppOnboardingJourneyView(
                viewModel: viewModel,
                onSkip: { [weak self] in
                    self?.handleWelcomeSkipped()
                },
                onContinueWelcome: { [weak self] in
                    self?.viewModel.moveToLifeAreas()
                    self?.logStepCompleted(.welcome)
                },
                onContinueLifeAreas: { [weak self] in
                    self?.resolveLifeAreas()
                },
                onContinueProjects: { [weak self] in
                    self?.resolveProjects()
                },
                onCreateTaskTemplate: { [weak self] template in
                    self?.openAddTaskSheet(for: template)
                },
                onContinueToHome: { [weak self] in
                    self?.prepareCompletionStep()
                }
            )
            .taskerLayoutClass(homeViewController.currentOnboardingLayoutClass)
        )

        let controller: UIHostingController<AnyView> = UIHostingController(rootView: root)
        controller.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        onboardingHost = controller
        homeViewController.present(controller, animated: true)
        return true
    }

    private func dismissFullFlow(animated: Bool, completion: (() -> Void)? = nil) {
        guard let onboardingHost else {
            completion?()
            return
        }
        self.onboardingHost = nil
        onboardingHost.dismiss(animated: animated, completion: completion)
    }

    private func handleWelcomeSkipped() {
        stateStore.markHandled(outcome: .skippedAfterWelcome)
        logOnboardingInfo(
            event: "onboarding_skipped",
            message: "User skipped onboarding from the welcome step"
        )
        dismissFullFlow(animated: true)
    }

    private func resolveLifeAreas() {
        viewModel.isWorking = true
        viewModel.errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let templates = viewModel.selectedLifeAreas
                let existingLifeAreas = try await self.fetchExistingLifeAreas()
                let plans = StarterWorkspaceCatalog.resolveLifeAreaSelections(
                    selected: templates,
                    existing: existingLifeAreas.filter { !$0.isArchived }
                )

                var resolved: [ResolvedLifeAreaSelection] = []
                for plan in plans {
                    if let existing = plan.existing {
                        resolved.append(ResolvedLifeAreaSelection(template: plan.template, lifeArea: existing, reusedExisting: true))
                    } else {
                        let created = try await presentationDependencyContainer.coordinator.manageLifeAreas.createAsync(
                            name: plan.template.name,
                            color: plan.template.colorHex,
                            icon: plan.template.icon
                        )
                        resolved.append(ResolvedLifeAreaSelection(template: plan.template, lifeArea: created, reusedExisting: false))
                    }
                }

                viewModel.applyResolvedLifeAreas(resolved)
                viewModel.isWorking = false
                logStepCompleted(.lifeAreas)
            } catch {
                viewModel.isWorking = false
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func resolveProjects() {
        viewModel.isWorking = true
        viewModel.errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let lifeAreasByTemplateID = Dictionary(uniqueKeysWithValues: viewModel.resolvedLifeAreas.map {
                    ($0.template.id, $0.lifeArea)
                })
                let existingProjects = try await EnhancedDependencyContainer.shared.projectRepository.fetchAllProjectsAsync()
                let plans = StarterWorkspaceCatalog.resolveProjectSelections(
                    selected: viewModel.selectedProjectTemplates,
                    existing: existingProjects,
                    lifeAreasByTemplateID: lifeAreasByTemplateID
                )

                var resolved: [ResolvedProjectSelection] = []
                for plan in plans {
                    if let existing = plan.existing {
                        resolved.append(ResolvedProjectSelection(template: plan.template, project: existing, reusedExisting: true))
                    } else {
                        let created = try await presentationDependencyContainer.coordinator.manageProjects.createProjectAsync(
                            request: CreateProjectRequest(
                                name: plan.template.name,
                                description: plan.template.summary,
                                lifeAreaID: plan.lifeArea.id
                            )
                        )
                        resolved.append(ResolvedProjectSelection(template: plan.template, project: created, reusedExisting: false))
                    }
                }

                viewModel.applyResolvedProjects(resolved)
                viewModel.isWorking = false
                logStepCompleted(.projects)
            } catch {
                viewModel.isWorking = false
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func openAddTaskSheet(for template: StarterTaskTemplate) {
        guard let onboardingHost,
              onboardingHost.presentedViewController == nil,
              let resolvedProject = viewModel.resolvedProjects.first(where: { $0.template.id == template.projectTemplateID }) else {
            return
        }

        let controller = homeViewController?.makeOnboardingAddTaskController(
            prefill: template.makePrefill(project: resolvedProject.project),
            onTaskCreated: { [weak self] taskID in
                Task { @MainActor [weak self] in
                    self?.viewModel.registerCreatedTask(templateID: template.id, taskID: taskID)
                }
            }
        )

        guard let controller else { return }
        onboardingHost.present(controller, animated: true)
    }

    private func prepareCompletionStep() {
        guard viewModel.hasCreatedRequiredTasks else { return }
        viewModel.isWorking = true
        viewModel.errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let targetTask = try await resolveCompletionTargetTask() else {
                    viewModel.isWorking = false
                    viewModel.errorMessage = "Create two tasks first so Tasker has something to guide you through."
                    return
                }

                completionTracking = OnboardingCompletionTrackingState(
                    highlightedTaskID: targetTask.id,
                    acceptableTaskIDs: Set(viewModel.createdTaskIDs)
                )
                isHandlingCompletionTarget = false
                completionStepActivatedAt = Date()
                guidanceModel.showCompletionGuide(task: targetTask)
                homeViewController?.prepareForOnboardingHomeGuidance()
                observeCompletionTarget()
                viewModel.isWorking = false
                logStepCompleted(.tasks)

                dismissFullFlow(animated: true)
            } catch {
                viewModel.isWorking = false
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func observeCompletionTarget() {
        cancelCompletionObservation()
        completionObserver = notificationCenter.publisher(for: .homeTaskMutation)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let reason = notification.userInfo?["reason"] as? String
                guard let taskIDRaw = notification.userInfo?["taskID"] as? String,
                      let taskID = UUID(uuidString: taskIDRaw),
                      reason == "completed" else {
                    return
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard await self.shouldAcceptCompletion(taskID: taskID) else { return }
                    self.handleCompletionTargetFinished(taskID: taskID)
                }
            }
        completionPollingTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard Task.isCancelled == false else { return }
                await self?.pollForCompletedOnboardingTask()
            }
        }
    }

    private func handleCompletionTargetFinished(taskID: UUID) {
        guard isHandlingCompletionTarget == false else { return }
        guard completionTracking.acceptableTaskIDs.contains(taskID) else { return }

        isHandlingCompletionTarget = true
        cancelCompletionObservation()
        guidanceModel.clear()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let completedTask = try? await self.fetchTask(id: taskID)
            let highlightedTaskID = completionTracking.highlightedTaskID
            let summary = AppOnboardingSummary(
                lifeAreaCount: viewModel.resolvedLifeAreas.count,
                projectCount: viewModel.resolvedProjects.count,
                createdTaskCount: viewModel.createdTaskIDs.count,
                completedTaskTitle: completedTask?.title
            )
            stateStore.markHandled(outcome: .completed)
            logStepCompleted(.completeTask)
            logOnboardingInfo(
                event: "onboarding_completed",
                message: "User completed guided onboarding",
                fields: [
                    "completed_task_id": taskID.uuidString,
                    "highlighted_task_id": highlightedTaskID?.uuidString ?? "none",
                    "used_highlighted_task": String(taskID == highlightedTaskID)
                ]
            )
            completionTracking = OnboardingCompletionTrackingState()
            completionStepActivatedAt = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                self.enqueuePresentation(.completion(summary: summary))
            }
        }
    }

    private func cancelCompletionObservation() {
        completionObserver?.cancel()
        completionObserver = nil
        completionPollingTask?.cancel()
        completionPollingTask = nil
    }

    private func pollForCompletedOnboardingTask() async {
        guard isHandlingCompletionTarget == false else { return }

        for taskID in completionTracking.acceptableTaskIDs {
            guard let task = try? await fetchTask(id: taskID), task.isComplete else {
                continue
            }
            handleCompletionTargetFinished(taskID: taskID)
            return
        }

        guard let fallbackTask = try? await fetchEligibleFallbackCompletedTask() else { return }
        handleCompletionTargetFinished(taskID: fallbackTask.id)
    }

    private func shouldAcceptCompletion(taskID: UUID) async -> Bool {
        if completionTracking.acceptsCompletion(reason: "completed", taskID: taskID) {
            return true
        }
        guard let task = try? await fetchTask(id: taskID) else { return false }
        return isEligibleFallbackCompletion(task)
    }

    private func fetchEligibleFallbackCompletedTask() async throws -> TaskDefinition? {
        guard let repository = EnhancedDependencyContainer.shared.taskDefinitionRepository else { return nil }
        let tasks = try await repository.fetchAllAsync()
        return tasks.first(where: isEligibleFallbackCompletion)
    }

    private func isEligibleFallbackCompletion(_ task: TaskDefinition) -> Bool {
        guard task.isComplete else { return false }
        guard let completedAt = task.dateCompleted else { return false }
        guard let activatedAt = completionStepActivatedAt else { return false }

        let starterProjectIDs = Set(viewModel.resolvedProjects.map(\.project.id))
        guard starterProjectIDs.contains(task.projectID) else { return false }

        return completedAt >= activatedAt.addingTimeInterval(-2)
    }

    private func presentCompletionIfPossible(summary: AppOnboardingSummary) -> Bool {
        guard completionHost == nil else { return false }
        guard let homeViewController else { return false }
        guard homeViewController.presentedViewController == nil else {
            pendingPresentationWasBlocked = true
            completionPresentationRetryCount += 1
            logOnboardingInfo(
                event: "onboarding_completion_recap_retry_scheduled",
                message: "Delayed onboarding recap because another controller is active",
                fields: ["retry_count": String(completionPresentationRetryCount)]
            )
            return false
        }

        let root = AnyView(
            AppOnboardingCompletionView(
                summary: summary,
                onDone: { [weak self] in
                    self?.completionHost?.dismiss(animated: true)
                    self?.completionHost = nil
                }
            )
            .taskerLayoutClass(homeViewController.currentOnboardingLayoutClass)
        )

        let controller: UIHostingController<AnyView> = UIHostingController(rootView: root)
        controller.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        completionHost = controller
        homeViewController.present(controller, animated: true)
        logOnboardingInfo(
            event: "onboarding_completion_recap_presented",
            message: "Presented onboarding completion recap",
            fields: ["retry_count": String(completionPresentationRetryCount)]
        )
        completionPresentationRetryCount = 0
        return true
    }

    private func resolveCompletionTargetTask() async throws -> TaskDefinition? {
        guard let taskRepository = EnhancedDependencyContainer.shared.taskDefinitionRepository else { return nil }
        for taskID in viewModel.createdTaskIDs {
            if let task = try await taskRepository.fetchTaskDefinitionAsync(id: taskID),
               task.isComplete == false {
                return task
            }
        }
        return nil
    }

    private func fetchExistingLifeAreas() async throws -> [LifeArea] {
        guard let repository = EnhancedDependencyContainer.shared.lifeAreaRepository else { return [] }
        return try await repository.fetchAllAsync()
    }

    private func fetchTask(id: UUID) async throws -> TaskDefinition? {
        guard let repository = EnhancedDependencyContainer.shared.taskDefinitionRepository else { return nil }
        return try await repository.fetchTaskDefinitionAsync(id: id)
    }

    private func logStepCompleted(_ step: OnboardingStep) {
        logOnboardingInfo(
            event: "onboarding_step_completed",
            message: "User completed an onboarding step",
            fields: [
                "step": "\(step.progressIndex)",
                "step_id": String(describing: step)
            ]
        )
    }
}

struct AppOnboardingJourneyView: View {
    @ObservedObject var viewModel: AppOnboardingFlowViewModel
    @Environment(\.taskerLayoutClass) private var layoutClass

    let onSkip: () -> Void
    let onContinueWelcome: () -> Void
    let onContinueLifeAreas: () -> Void
    let onContinueProjects: () -> Void
    let onCreateTaskTemplate: (StarterTaskTemplate) -> Void
    let onContinueToHome: () -> Void

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ZStack {
            AppOnboardingBackground()
                .ignoresSafeArea()

            VStack(spacing: spacing.s16) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: spacing.sectionGap) {
                        stepContent
                    }
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.bottom, spacing.s24)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.statusDanger)
                        .padding(.horizontal, spacing.screenHorizontal)
                }

                footer
            }
            .padding(.top, spacing.s20)
            .padding(.bottom, spacing.s20)
        }
        .interactiveDismissDisabled(true)
        .animation(TaskerAnimation.gentle, value: viewModel.step)
        .accessibilityIdentifier("onboarding.flow")
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text("Guided momentum")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                    Text(viewModel.step.progressLabel)
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)
                }
                Spacer()
                if viewModel.step == .welcome {
                    Button("Skip") {
                        TaskerFeedback.light()
                        onSkip()
                    }
                    .font(.tasker(.buttonSmall))
                    .foregroundColor(Color.tasker.textSecondary)
                    .accessibilityIdentifier("onboarding.skipButton")
                }
            }

            ProgressView(value: Double(viewModel.step.progressIndex), total: Double(OnboardingStep.allCases.count))
                .tint(Color.tasker.accentPrimary)
                .accessibilityIdentifier("onboarding.progress")
        }
        .padding(.horizontal, spacing.screenHorizontal)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .welcome:
            welcomeStep
        case .lifeAreas:
            lifeAreasStep
        case .projects:
            projectsStep
        case .tasks:
            tasksStep
        case .completeTask, .finish:
            EmptyView()
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Set up the parts of life you actually move through.")
                    .font(.tasker(.display))
                    .foregroundColor(Color.tasker.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("In about two minutes, you'll create a few real life areas, add two tiny tasks, and complete one so the mechanics make sense immediately.")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("onboarding.welcome")

            HStack(spacing: spacing.s12) {
                onboardingMetricCard(icon: "clock.fill", title: "2 min", subtitle: "honest setup time")
                onboardingMetricCard(icon: "sparkles", title: "Real data", subtitle: "no tutorial mode")
                onboardingMetricCard(icon: "bolt.fill", title: "1 win", subtitle: "complete a task today")
            }

            TaskerCard {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Text("This teaches the loop Tasker is built for")
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)
                    onboardingBullet("Capture small tasks before they disappear.")
                    onboardingBullet("Give work a home with life areas and projects.")
                    onboardingBullet("Complete one action and watch the feedback loop kick in.")
                }
                .padding(spacing.s16)
            }
        }
    }

    private var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: "Pick 2 or 3 life areas",
                subtitle: "These become the buckets that keep tasks feeling anchored instead of random."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 220 : 156), spacing: spacing.s12)], spacing: spacing.s12) {
                ForEach(viewModel.catalog) { template in
                    OnboardingSelectableCard(
                        title: template.name,
                        subtitle: template.subtitle,
                        icon: template.icon,
                        colorHex: template.colorHex,
                        isSelected: viewModel.selectedLifeAreaIDs.contains(template.id),
                        badgeText: "\(template.projects.count) starter projects"
                    ) {
                        TaskerFeedback.selection()
                        viewModel.toggleLifeArea(template.id)
                    }
                    .accessibilityIdentifier("onboarding.lifeArea.\(template.id)")
                }
            }

            if viewModel.reusedLifeAreaCount > 0 {
                Text("We'll reuse anything you already named the same instead of making duplicates.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
            }
        }
    }

    private var projectsStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: "Choose a few starter projects",
                subtitle: "These are small lanes of work inside the life areas you just picked."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 220 : 164), spacing: spacing.s12)], spacing: spacing.s12) {
                ForEach(viewModel.availableProjectTemplates) { template in
                    let parent = viewModel.catalog.first(where: { $0.id == template.lifeAreaTemplateID })
                    OnboardingSelectableCard(
                        title: template.name,
                        subtitle: template.summary,
                        icon: parent?.icon ?? "folder.fill",
                        colorHex: parent?.colorHex ?? "#3B82F6",
                        isSelected: viewModel.selectedProjectIDs.contains(template.id),
                        badgeText: parent?.name ?? "Project"
                    ) {
                        TaskerFeedback.selection()
                        viewModel.toggleProject(template.id)
                    }
                    .accessibilityIdentifier("onboarding.project.\(template.id)")
                }
            }

            Text("At least two is enough. Tasker will use matching projects you already have.")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
        }
    }

    private var tasksStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: "Create two tiny tasks",
                subtitle: "These open in the real add-task flow, already scoped to today so you can finish one right away."
            )

            TaskerCard {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Text("\(viewModel.createdTaskIDs.count) of 2 created")
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)

                    ForEach(viewModel.taskSuggestions.prefix(4)) { template in
                        let isCreated = viewModel.createdTaskTemplateIDs[template.id] != nil
                        HStack(alignment: .top, spacing: spacing.s12) {
                            Image(systemName: isCreated ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isCreated ? Color.tasker.statusSuccess : Color.tasker.accentPrimary)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: spacing.s4) {
                                Text(template.title)
                                    .font(.tasker(.bodyEmphasis))
                                    .foregroundColor(Color.tasker.textPrimary)
                                Text(template.details)
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                                Text("\(template.durationMinutes) min")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.textTertiary)
                            }

                            Spacer()

                            Button(isCreated ? "Created" : "Use") {
                                guard !isCreated else { return }
                                TaskerFeedback.light()
                                onCreateTaskTemplate(template)
                            }
                            .font(.tasker(.buttonSmall))
                            .foregroundColor(isCreated ? Color.tasker.textTertiary : Color.tasker.accentPrimary)
                            .disabled(isCreated)
                            .accessibilityIdentifier("onboarding.taskTemplate.\(template.id)")
                        }
                    }
                }
                .padding(spacing.s16)
            }

            Text("You can edit anything in the sheet. The important part is learning the real create flow, not keeping our exact wording.")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch viewModel.step {
        case .welcome:
            primaryFooterButton(title: "Start guided setup", action: onContinueWelcome)
                .accessibilityIdentifier("onboarding.continueWelcome")
        case .lifeAreas:
            primaryFooterButton(
                title: viewModel.isWorking ? "Setting up..." : "Use these life areas",
                action: onContinueLifeAreas,
                disabled: viewModel.canContinueLifeAreas == false || viewModel.isWorking
            )
            .accessibilityIdentifier("onboarding.continueLifeAreas")
        case .projects:
            primaryFooterButton(
                title: viewModel.isWorking ? "Building projects..." : "Use these projects",
                action: onContinueProjects,
                disabled: viewModel.canContinueProjects == false || viewModel.isWorking
            )
            .accessibilityIdentifier("onboarding.continueProjects")
        case .tasks:
            primaryFooterButton(
                title: viewModel.hasCreatedRequiredTasks ? "Go to Home and complete either one" : "Create two tasks to continue",
                action: onContinueToHome,
                disabled: viewModel.hasCreatedRequiredTasks == false || viewModel.isWorking
            )
            .accessibilityIdentifier("onboarding.continueTasks")
        case .completeTask, .finish:
            EmptyView()
        }
    }

    private func primaryFooterButton(title: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            Text(title)
                .font(.tasker(.button))
                .frame(maxWidth: .infinity)
                .frame(minHeight: spacing.buttonHeight)
        }
        .buttonStyle(.plain)
        .foregroundColor(Color.tasker.textInverse)
        .background(disabled ? Color.tasker.textTertiary : Color.tasker.accentPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, spacing.screenHorizontal)
        .disabled(disabled)
    }

    private func onboardingMetricCard(icon: String, title: String, subtitle: String) -> some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.tasker.accentPrimary)
                Text(title)
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textPrimary)
                Text(subtitle)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .padding(spacing.s16)
        }
    }

    private func onboardingBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: spacing.s8) {
            Circle()
                .fill(Color.tasker.accentPrimary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AppOnboardingPromptSheetView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass

    let onStart: () -> Void
    let onNotNow: () -> Void

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ZStack {
            AppOnboardingBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                Text("Want a quick guided setup?")
                    .font(.tasker(.display))
                    .foregroundColor(Color.tasker.textPrimary)
                    .accessibilityIdentifier("onboarding.prompt.title")

                Text("Tasker can map your life areas, create a couple of starter tasks, and walk you through your first completion without touching anything you already made.")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textSecondary)

                VStack(spacing: spacing.s12) {
                    Button(action: onStart) {
                        Text("Start guided setup")
                            .font(.tasker(.button))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: spacing.buttonHeight)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.tasker.textInverse)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityIdentifier("onboarding.prompt.start")

                    Button(action: onNotNow) {
                        Text("Not now")
                            .font(.tasker(.buttonSmall))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, spacing.s12)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.tasker.textSecondary)
                    .accessibilityIdentifier("onboarding.prompt.dismiss")
                }
            }
            .padding(spacing.screenHorizontal)
        }
        .interactiveDismissDisabled(true)
        .accessibilityIdentifier("onboarding.prompt")
    }
}

struct AppOnboardingCompletionView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass

    let summary: AppOnboardingSummary
    let onDone: () -> Void

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ZStack {
            AppOnboardingBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                Text("You’re live.")
                    .font(.tasker(.display))
                    .foregroundColor(Color.tasker.textPrimary)
                    .accessibilityIdentifier("onboarding.finish")

                Text(summary.completedTaskTitle.map { "You completed \"\($0)\" and felt the real loop: create, complete, reflect." } ?? "You completed your first guided task and felt the real loop: create, complete, reflect.")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textSecondary)

                HStack(spacing: spacing.s12) {
                    completionMetric(title: "\(summary.lifeAreaCount)", subtitle: "life areas")
                    completionMetric(title: "\(summary.projectCount)", subtitle: "projects")
                    completionMetric(title: "\(summary.createdTaskCount)", subtitle: "tasks created")
                }

                Text("Replay this any time from Settings if you want to re-orient without touching your existing data.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)

                Button(action: onDone) {
                    Text("Back to Home")
                        .font(.tasker(.button))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: spacing.buttonHeight)
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.tasker.textInverse)
                .background(Color.tasker.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("onboarding.finish.done")
            }
            .padding(spacing.screenHorizontal)
        }
        .interactiveDismissDisabled(true)
    }

    private func completionMetric(title: String, subtitle: String) -> some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(title)
                    .font(.tasker(.title1))
                    .foregroundColor(Color.tasker.textPrimary)
                Text(subtitle)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .padding(spacing.s16)
        }
    }
}

struct HomeOnboardingGuidanceBanner: View {
    let state: HomeOnboardingGuidanceModel.State

    var body: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Step 5 of 6")
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textSecondary)
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.tasker.accentPrimary)
                }

                Text(state.title)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                Text(state.message)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .padding(16)
        }
        .accessibilityIdentifier("home.onboarding.guide")
    }
}

private struct OnboardingSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tasker(.display))
                .foregroundColor(Color.tasker.textPrimary)
            Text(subtitle)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingSelectableCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colorHex: String
    let isSelected: Bool
    let badgeText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: UIColor(taskerHex: colorHex)).opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(uiColor: UIColor(taskerHex: colorHex)))
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textPrimary)
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(badgeText)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Capsule())
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.tasker.accentPrimary.opacity(0.08) : Color.tasker.surfacePrimary.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Color.tasker.accentPrimary : Color.tasker.strokeHairline, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

private struct AppOnboardingBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePrimary = false
    @State private var animateSecondary = false

    var body: some View {
        ZStack {
            Color.tasker(.bgCanvas)

            Circle()
                .fill(Color.tasker.accentPrimary.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 24)
                .offset(x: animatePrimary ? 110 : -90, y: animatePrimary ? -180 : -120)
                .animation(reduceMotion ? nil : TaskerAnimation.gentle.repeatForever(autoreverses: true), value: animatePrimary)

            Circle()
                .fill(Color.tasker.accentSecondaryMuted.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 18)
                .offset(x: animateSecondary ? -120 : 120, y: animateSecondary ? 220 : 140)
                .animation(reduceMotion ? nil : TaskerAnimation.snappy.repeatForever(autoreverses: true), value: animateSecondary)

            LinearGradient(
                colors: [
                    Color.tasker.surfacePrimary.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onAppear {
            animatePrimary = true
            animateSecondary = true
        }
    }
}

extension LifeAreaRepositoryProtocol {
    func fetchAllAsync() async throws -> [LifeArea] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension ProjectRepositoryProtocol {
    func fetchAllProjectsAsync() async throws -> [Project] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAllProjects { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension TaskDefinitionRepositoryProtocol {
    func fetchAllAsync() async throws -> [TaskDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchTaskDefinitionAsync(id: UUID) async throws -> TaskDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            fetchTaskDefinition(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension ManageLifeAreasUseCase {
    func createAsync(name: String, color: String?, icon: String?) async throws -> LifeArea {
        try await withCheckedThrowingContinuation { continuation in
            create(name: name, color: color, icon: icon) { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension ManageProjectsUseCase {
    func createProjectAsync(request: CreateProjectRequest) async throws -> Project {
        try await withCheckedThrowingContinuation { continuation in
            createProject(request: request) { result in
                switch result {
                case .success(let project):
                    continuation.resume(returning: project)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension CreateTaskDefinitionUseCase {
    func executeAsync(request: CreateTaskDefinitionRequest) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            execute(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }
}
