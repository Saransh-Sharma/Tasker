import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
final class OnboardingFlowModel: ObservableObject {


    let stateStore: AppOnboardingStateStore

    let notificationService: NotificationServiceProtocol?

    let calendarService: CalendarIntegrationService?

    let fetchLifeAreas: () async throws -> [LifeArea]

    let fetchProjects: () async throws -> [Project]

    let fetchHabit: (UUID) async throws -> HabitDefinitionRecord?

    let fetchTask: (UUID) async throws -> TaskDefinition?

    let createLifeArea: (StarterLifeAreaTemplate) async throws -> LifeArea

    let createProject: (OnboardingProjectDraft, LifeArea) async throws -> Project

    let createHabit: (CreateHabitRequest) async throws -> HabitDefinitionRecord

    let createTask: (CreateTaskDefinitionRequest) async throws -> TaskDefinition

    let setTaskCompletion: (UUID, Bool) async throws -> TaskDefinition

    let resolveHabitOccurrence: (UUID, HabitOccurrenceAction, Date) async throws -> Void

    let evaAppManager: AppManager

    let evaDefaults: UserDefaults

    let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore

    let isEvaBackgroundPreparationEnabled: Bool

    var isAppStoreScreenshotOnboardingFlowEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_EXPANDED_APP_STORE_ONBOARDING")
    }

    @Published var step: OnboardingStep = .welcome

    @Published var mode: OnboardingMode = .guided

    @Published var entryContext: OnboardingEntryContext = .freshFlow

    @Published var frictionProfile: OnboardingFrictionProfile?

    @Published var selectedGoal: OnboardingPrimaryGoal?

    @Published var selectedPainPoints: Set<OnboardingPainPoint> = []

    @Published var selectedLifeAreaIDs: Set<String> = []

    @Published var showAllLifeAreas = false

    @Published var projectDrafts: [OnboardingProjectDraft] = []

    @Published var expandedProjectIDs: Set<UUID> = []

    @Published var reminderPromptDismissed = false

    @Published var selectedStarterHabitPreference: OnboardingStarterHabitPreference = .positive

    @Published var selectedStarterHabitTemplateID: String?

    @Published var habitPreviewMarks: [HabitDayMark] = []

    @Published var didCompleteStarterHabitCheckIn = false

    @Published var evaProfileDraft = EvaProfileDraft()

    @Published var selectedMascotID: AssistantMascotID

    @Published var evaPreparationState = OnboardingEvaPreparationState()

    @Published var didCompleteHomeDemoTask = false

    @Published var didCompleteHomeDemoHabit = false

    @Published var resolvedLifeAreas: [ResolvedLifeAreaSelection] = []

    @Published var resolvedProjects: [ResolvedProjectSelection] = []

    @Published var createdHabits: [HabitDefinitionRecord] = []

    @Published var createdHabitTemplateMap: [String: UUID] = [:]

    @Published var habitTemplateStates: [String: OnboardingHabitTemplateState] = [:]

    @Published var createdTasks: [TaskDefinition] = []

    @Published var createdTaskTemplateMap: [String: UUID] = [:]

    @Published var taskTemplateStates: [String: OnboardingTaskTemplateState] = [:]

    @Published var focusTaskID: UUID?

    @Published var parentFocusTaskID: UUID?

    @Published var focusStartedAt: Date?

    @Published var focusIsActive = false

    @Published var successSummary: AppOnboardingSummary?

    @Published var reminderPromptState: OnboardingReminderPromptState = .hidden

    @Published var isWorking = false

    @Published var errorMessage: String?

    @Published var breakdownSteps: [OnboardingBreakdownStep] = []

    @Published var breakdownSheetPresented = false

    @Published var breakdownIsLoading = false

    @Published var breakdownRouteBanner: String?

    var lastReminderPromptState: OnboardingReminderPromptState = .hidden

    var evaProgressObservationTask: Task<Void, Never>?

    var hasStartedProcessing = false

    init(
        stateStore: AppOnboardingStateStore = .shared,
        notificationService: NotificationServiceProtocol? = nil,
        calendarService: CalendarIntegrationService? = nil,
        fetchLifeAreas: @escaping () async throws -> [LifeArea] = { [] },
        fetchProjects: @escaping () async throws -> [Project] = { [] },
        fetchHabit: @escaping (UUID) async throws -> HabitDefinitionRecord? = { _ in nil },
        fetchTask: @escaping (UUID) async throws -> TaskDefinition? = { _ in nil },
        createLifeArea: @escaping (StarterLifeAreaTemplate) async throws -> LifeArea = { template in
            LifeArea(name: template.name, color: template.colorHex, icon: template.icon)
        },
        createProject: @escaping (OnboardingProjectDraft, LifeArea) async throws -> Project = { draft, lifeArea in
            Project(lifeAreaID: lifeArea.id, name: draft.name, projectDescription: draft.summary)
        },
        createHabit: @escaping (CreateHabitRequest) async throws -> HabitDefinitionRecord = { request in
            HabitDefinitionRecord(
                id: request.id,
                lifeAreaID: request.lifeAreaID,
                projectID: request.projectID,
                title: request.title,
                habitType: CreateHabitUseCase.habitTypeString(kind: request.kind, trackingMode: request.trackingMode),
                kindRaw: request.kind.rawValue,
                trackingModeRaw: request.trackingMode.rawValue,
                iconSymbolName: request.icon.symbolName,
                iconCategoryKey: request.icon.categoryKey,
                targetConfigData: try? JSONEncoder().encode(request.targetConfig),
                metricConfigData: try? JSONEncoder().encode(request.metricConfig),
                createdAt: request.createdAt,
                updatedAt: request.createdAt
            )
        },
        createTask: @escaping (CreateTaskDefinitionRequest) async throws -> TaskDefinition = { request in
            request.toTaskDefinition(projectName: request.projectName)
        },
        setTaskCompletion: @escaping (UUID, Bool) async throws -> TaskDefinition = { taskID, isComplete in
            var task = TaskDefinition(id: taskID, title: "Task")
            task.isComplete = isComplete
            task.dateCompleted = isComplete ? Date() : nil
            return task
        },
        resolveHabitOccurrence: @escaping (UUID, HabitOccurrenceAction, Date) async throws -> Void = { _, _, _ in
        },
        evaAppManager: AppManager = AppManager(),
        evaDefaults: UserDefaults = .standard,
        workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared,
        isEvaBackgroundPreparationEnabled: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    ) {
        self.stateStore = stateStore
        self.notificationService = notificationService
        self.calendarService = calendarService
        self.fetchLifeAreas = fetchLifeAreas
        self.fetchProjects = fetchProjects
        self.fetchHabit = fetchHabit
        self.fetchTask = fetchTask
        self.createLifeArea = createLifeArea
        self.createProject = createProject
        self.createHabit = createHabit
        self.createTask = createTask
        self.setTaskCompletion = setTaskCompletion
        self.resolveHabitOccurrence = resolveHabitOccurrence
        self.evaAppManager = evaAppManager
        self.evaDefaults = evaDefaults
        self.workspacePreferencesStore = workspacePreferencesStore
        self.selectedMascotID = .yesman
        self.isEvaBackgroundPreparationEnabled = isEvaBackgroundPreparationEnabled
        applyDefaults(mode: .guided, frictionProfile: nil)
    }

    deinit {
        evaProgressObservationTask?.cancel()
    }
}
