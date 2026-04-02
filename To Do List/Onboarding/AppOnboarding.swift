import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation

extension Notification.Name {
    static let taskerStartOnboardingRequested = Notification.Name("TaskerStartOnboardingRequested")
}

enum AppOnboardingAccessibilityID {
    static let flow = "onboarding.flow"
    static let welcome = "onboarding.welcome"
    static let welcomeHeroVideo = "onboarding.welcome.heroVideo"
    static let welcomeIntroOverlay = "onboarding.welcome.introOverlay"
    static let welcomeIntroTitleCard = "onboarding.welcome.introTitleCard"
    static let welcomeIntroContinue = "onboarding.welcome.introContinue"
    static let welcomeReady = "onboarding.welcome.ready"
    static let blocker = "onboarding.blocker"
    static let lifeAreas = "onboarding.lifeAreas"
    static let projects = "onboarding.projects"
    static let habits = "onboarding.habits"
    static let firstTask = "onboarding.firstTask"
    static let focusRoom = "onboarding.focusRoom"
    static let success = "onboarding.success"
    static let skipButton = "onboarding.skipButton"
    static let frictionHelper = "onboarding.friction.helper"
    static let startRecommended = "onboarding.cta.startRecommended"
    static let customize = "onboarding.cta.customize"
    static let continueFromBlocker = "onboarding.cta.continueFromBlocker"
    static let skipBlocker = "onboarding.cta.skipBlocker"
    static let useAreas = "onboarding.cta.useAreas"
    static let useProjects = "onboarding.cta.useProjects"
    static let useHabits = "onboarding.cta.useHabits"
    static let customHabit = "onboarding.cta.customHabit"
    static let customTask = "onboarding.cta.customTask"
    static let goFinishTask = "onboarding.cta.goFinishTask"
    static let focusPrimary = "onboarding.cta.focusPrimary"
    static let markComplete = "onboarding.cta.markComplete"
    static let startNow = "onboarding.cta.startNow"
    static let breakDown = "onboarding.cta.breakDown"
    static let goHome = "onboarding.cta.goHome"
    static let breakdownNext = "onboarding.cta.breakdownNext"
    static let prompt = "onboarding.prompt"
    static let promptStart = "onboarding.prompt.start"
    static let promptDismiss = "onboarding.prompt.dismiss"

    static func lifeArea(_ id: String) -> String { "onboarding.lifeArea.\(id)" }
    static func taskTemplate(_ id: String) -> String { "onboarding.taskTemplate.\(id)" }
    static func habitTemplate(_ id: String) -> String { "onboarding.habitTemplate.\(id)" }
}

func onboardingLogLine(event: String, message: String? = nil, fields: [String: String] = [:]) -> String {
    var parts = ["event=\(event)"]
    if let message, message.isEmpty == false {
        parts.append("message=\(message)")
    }
    if fields.isEmpty == false {
        let serializedFields = fields
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        parts.append(serializedFields)
    }
    return parts.joined(separator: " | ")
}

func logOnboardingInfo(event: String, message: String? = nil, fields: [String: String] = [:]) {
    logInfo(onboardingLogLine(event: event, message: message, fields: fields))
}

func logOnboardingError(event: String, message: String? = nil, fields: [String: String] = [:]) {
    logError(onboardingLogLine(event: event, message: message, fields: fields))
}

enum OnboardingOutcome: String, Codable, Equatable {
    case completed
    case skippedAfterWelcome
}

enum OnboardingStep: Int, CaseIterable, Codable {
    case welcome = 0
    case lifeAreas = 1
    case projects = 2
    case habits = 3
    case firstTask = 4
    case focusRoom = 5
    case blocker = 6

    static let orderedFlow: [OnboardingStep] = [
        .welcome,
        .blocker,
        .lifeAreas,
        .projects,
        .firstTask,
        .habits,
        .focusRoom
    ]

    var progressIndex: Int {
        Self.orderedFlow.firstIndex(of: self).map { $0 + 1 } ?? 1
    }

    var progressLabel: String {
        "Step \(progressIndex) of \(Self.orderedFlow.count)"
    }

    var eyebrowTitle: String {
        switch self {
        case .welcome:
            return "Setup"
        case .blocker:
            return "Setup"
        case .lifeAreas:
            return "Areas"
        case .projects:
            return "Projects"
        case .habits:
            return "Habits"
        case .firstTask:
            return "First win"
        case .focusRoom:
            return "Finish"
        }
    }

    var accessibilitySummary: String {
        switch self {
        case .welcome:
            return "Welcome. Step 1 of 7."
        case .blocker:
            return "Choose your blocker. Step 2 of 7."
        case .lifeAreas:
            return "Choose life areas. Step 3 of 7."
        case .projects:
            return "Confirm starter projects. Step 4 of 7."
        case .firstTask:
            return "Pick your first tiny task. Step 5 of 7."
        case .habits:
            return "Add a starter habit. Step 6 of 7."
        case .focusRoom:
            return "Finish your first win. Step 7 of 7."
        }
    }
}

enum OnboardingFrictionProfile: String, CaseIterable, Codable, Identifiable {
    case starting
    case choosing
    case remembering
    case finishing
    case overwhelmed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starting:
            return "Getting started"
        case .choosing:
            return "Too many options"
        case .remembering:
            return "Keeping track"
        case .finishing:
            return "Following through"
        case .overwhelmed:
            return "Too much at once"
        }
    }

    var symbolName: String {
        switch self {
        case .starting:
            return "sparkles"
        case .choosing:
            return "slider.horizontal.3"
        case .remembering:
            return "bookmark"
        case .finishing:
            return "flag"
        case .overwhelmed:
            return "circle.grid.2x2"
        }
    }

    var helperCopy: String {
        switch self {
        case .starting:
            return "We’ll narrow things to the easiest place to begin."
        case .choosing:
            return "We’ll keep decisions light and use good defaults."
        case .remembering:
            return "We’ll bring the next step back when it matters."
        case .finishing:
            return "We’ll favor steps with a clear finish line."
        case .overwhelmed:
            return "We’ll keep the setup light and low-pressure."
        }
    }
}

enum OnboardingMode: String, Codable, Equatable {
    case guided
    case custom
}

enum OnboardingEntryContext: String, Codable, Equatable {
    case freshFlow
    case establishedWorkspace
}

enum OnboardingTaskTemplateState: Equatable {
    case idle
    case creating
    case created(UUID)
    case failed(String)
}

enum OnboardingHabitTemplateState: Equatable {
    case idle
    case creating
    case created(UUID)
    case failed(String)
}

enum OnboardingReminderPromptState: Equatable {
    case hidden
    case prompt
    case openSettings
}

enum WelcomeIntroPhase: Int, Equatable {
    case introVideoOnly
    case introTitleReveal
    case introSubtitleReveal
    case introCardHold
    case introCTAReady
    case transitionToWelcome
    case welcomeReady

    var showsIntroOverlay: Bool {
        self != .welcomeReady
    }

    var showsIntroCard: Bool {
        rawValue >= Self.introTitleReveal.rawValue && rawValue <= Self.transitionToWelcome.rawValue
    }

    var showsTitle: Bool {
        rawValue >= Self.introTitleReveal.rawValue
    }

    var showsSubtitle: Bool {
        rawValue >= Self.introSubtitleReveal.rawValue
    }

    var showsIntroCTA: Bool {
        self == .introCTAReady
    }

    var showsWelcomeChrome: Bool {
        rawValue >= Self.transitionToWelcome.rawValue
    }

    var backdropBlurOpacity: Double {
        switch self {
        case .transitionToWelcome:
            return 0.52
        case .welcomeReady:
            return 0.58
        default:
            return 0
        }
    }

    var backdropDimOpacity: Double {
        switch self {
        case .transitionToWelcome:
            return 0.18
        case .welcomeReady:
            return 0.32
        default:
            return 0
        }
    }

    var videoGrainAmount: Int {
        switch self {
        case .introVideoOnly,
             .introTitleReveal,
             .introSubtitleReveal,
             .introCardHold,
             .introCTAReady:
            return 25
        case .transitionToWelcome, .welcomeReady:
            return 100
        }
    }

    var introCardOpacity: Double {
        switch self {
        case .introTitleReveal, .introSubtitleReveal, .introCardHold, .introCTAReady:
            return 1
        case .transitionToWelcome:
            return 0
        default:
            return 0
        }
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

struct AppOnboardingSummary: Codable, Equatable {
    let lifeAreaCount: Int
    let projectCount: Int
    let createdHabitCount: Int
    let createdHabitTitles: [String]
    let createdTaskCount: Int
    let completedTaskCount: Int
    let completedTaskTitle: String?
    let nextTaskTitle: String?
    let promptReminderAfterSuccess: Bool

    init(
        lifeAreaCount: Int,
        projectCount: Int,
        createdHabitCount: Int = 0,
        createdHabitTitles: [String] = [],
        createdTaskCount: Int,
        completedTaskCount: Int,
        completedTaskTitle: String?,
        nextTaskTitle: String?,
        promptReminderAfterSuccess: Bool
    ) {
        self.lifeAreaCount = lifeAreaCount
        self.projectCount = projectCount
        self.createdHabitCount = createdHabitCount
        self.createdHabitTitles = createdHabitTitles
        self.createdTaskCount = createdTaskCount
        self.completedTaskCount = completedTaskCount
        self.completedTaskTitle = completedTaskTitle
        self.nextTaskTitle = nextTaskTitle
        self.promptReminderAfterSuccess = promptReminderAfterSuccess
    }
}

extension AppOnboardingSummary {
    private enum CodingKeys: String, CodingKey {
        case lifeAreaCount
        case projectCount
        case createdHabitCount
        case createdHabitTitles
        case createdTaskCount
        case completedTaskCount
        case completedTaskTitle
        case nextTaskTitle
        case promptReminderAfterSuccess
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lifeAreaCount = try container.decode(Int.self, forKey: .lifeAreaCount)
        projectCount = try container.decode(Int.self, forKey: .projectCount)
        createdHabitCount = try container.decodeIfPresent(Int.self, forKey: .createdHabitCount) ?? 0
        createdHabitTitles = try container.decodeIfPresent([String].self, forKey: .createdHabitTitles) ?? []
        createdTaskCount = try container.decode(Int.self, forKey: .createdTaskCount)
        completedTaskCount = try container.decode(Int.self, forKey: .completedTaskCount)
        completedTaskTitle = try container.decodeIfPresent(String.self, forKey: .completedTaskTitle)
        nextTaskTitle = try container.decodeIfPresent(String.self, forKey: .nextTaskTitle)
        promptReminderAfterSuccess = try container.decode(Bool.self, forKey: .promptReminderAfterSuccess)
    }
}

struct OnboardingBreakdownStep: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isSelected: Bool

    init(id: UUID = UUID(), title: String, isSelected: Bool = false) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
    }
}

struct OnboardingProjectDraft: Identifiable, Codable, Equatable {
    let id: UUID
    let lifeAreaTemplateID: String
    var templateID: String
    var name: String
    var summary: String
    var suggestionTemplateIDs: [String]
    var suggestionIndex: Int
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        lifeAreaTemplateID: String,
        templateID: String,
        name: String,
        summary: String,
        suggestionTemplateIDs: [String],
        suggestionIndex: Int,
        isSelected: Bool = true
    ) {
        self.id = id
        self.lifeAreaTemplateID = lifeAreaTemplateID
        self.templateID = templateID
        self.name = name
        self.summary = summary
        self.suggestionTemplateIDs = suggestionTemplateIDs
        self.suggestionIndex = suggestionIndex
        self.isSelected = isSelected
    }
}

struct ResolvedLifeAreaSelection: Codable, Equatable {
    let templateID: String
    let lifeArea: LifeArea
    let reusedExisting: Bool
}

struct ResolvedProjectSelection: Codable, Equatable {
    let draft: OnboardingProjectDraft
    let project: Project
    let reusedExisting: Bool
}

struct OnboardingJourneySnapshot: Codable, Equatable {
    var schemaVersion: Int = 3
    var step: OnboardingStep
    var mode: OnboardingMode
    var entryContext: OnboardingEntryContext = .freshFlow
    var frictionProfile: OnboardingFrictionProfile?
    var selectedLifeAreaIDs: [String]
    var showAllLifeAreas: Bool
    var projectDrafts: [OnboardingProjectDraft]
    var expandedProjectIDs: [UUID] = []
    var resolvedLifeAreas: [ResolvedLifeAreaSelection]
    var resolvedProjects: [ResolvedProjectSelection]
    var createdHabits: [HabitDefinitionRecord] = []
    var createdHabitTemplateMap: [String: UUID] = [:]
    var createdTasks: [TaskDefinition]
    var createdTaskTemplateMap: [String: UUID]
    var focusTaskID: UUID?
    var parentFocusTaskID: UUID?
    var focusStartedAt: Date?
    var focusIsActive: Bool
    var successSummary: AppOnboardingSummary?
    var hasSeenSuccess: Bool
    var reminderPromptDismissed: Bool = false
}

extension OnboardingJourneySnapshot {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case step
        case mode
        case entryContext
        case frictionProfile
        case selectedLifeAreaIDs
        case showAllLifeAreas
        case projectDrafts
        case expandedProjectIDs
        case resolvedLifeAreas
        case resolvedProjects
        case createdHabits
        case createdHabitTemplateMap
        case createdTasks
        case createdTaskTemplateMap
        case focusTaskID
        case parentFocusTaskID
        case focusStartedAt
        case focusIsActive
        case successSummary
        case hasSeenSuccess
        case reminderPromptDismissed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 2
        step = try container.decode(OnboardingStep.self, forKey: .step)
        mode = try container.decode(OnboardingMode.self, forKey: .mode)
        entryContext = try container.decodeIfPresent(OnboardingEntryContext.self, forKey: .entryContext) ?? .freshFlow
        frictionProfile = try container.decodeIfPresent(OnboardingFrictionProfile.self, forKey: .frictionProfile)
        selectedLifeAreaIDs = try container.decode([String].self, forKey: .selectedLifeAreaIDs)
        showAllLifeAreas = try container.decode(Bool.self, forKey: .showAllLifeAreas)
        projectDrafts = try container.decode([OnboardingProjectDraft].self, forKey: .projectDrafts)
        expandedProjectIDs = try container.decodeIfPresent([UUID].self, forKey: .expandedProjectIDs) ?? []
        resolvedLifeAreas = try container.decode([ResolvedLifeAreaSelection].self, forKey: .resolvedLifeAreas)
        resolvedProjects = try container.decode([ResolvedProjectSelection].self, forKey: .resolvedProjects)
        createdHabits = try container.decodeIfPresent([HabitDefinitionRecord].self, forKey: .createdHabits) ?? []
        createdHabitTemplateMap = try container.decodeIfPresent([String: UUID].self, forKey: .createdHabitTemplateMap) ?? [:]
        createdTasks = try container.decode([TaskDefinition].self, forKey: .createdTasks)
        createdTaskTemplateMap = try container.decode([String: UUID].self, forKey: .createdTaskTemplateMap)
        focusTaskID = try container.decodeIfPresent(UUID.self, forKey: .focusTaskID)
        parentFocusTaskID = try container.decodeIfPresent(UUID.self, forKey: .parentFocusTaskID)
        focusStartedAt = try container.decodeIfPresent(Date.self, forKey: .focusStartedAt)
        focusIsActive = try container.decode(Bool.self, forKey: .focusIsActive)
        successSummary = try container.decodeIfPresent(AppOnboardingSummary.self, forKey: .successSummary)
        hasSeenSuccess = try container.decode(Bool.self, forKey: .hasSeenSuccess)
        reminderPromptDismissed = try container.decodeIfPresent(Bool.self, forKey: .reminderPromptDismissed) ?? false
    }
}

struct AppOnboardingState: Codable, Equatable {
    static let currentVersion = 1

    var outcome: OnboardingOutcome?
    var completedVersion: Int?
    var establishedWorkspacePromptDismissedVersion: Int?
    var journeySnapshot: OnboardingJourneySnapshot?

    var hasHandledCurrentVersion: Bool {
        completedVersion == Self.currentVersion && outcome != nil
    }
}

enum PendingOnboardingPresentation: Equatable {
    case prompt(snapshot: OnboardingWorkspaceSnapshot)
    case fullFlow(source: String)

    var priority: Int {
        switch self {
        case .prompt:
            return 1
        case .fullFlow:
            return 2
        }
    }

    var analyticsLabel: String {
        switch self {
        case .prompt:
            return "prompt"
        case .fullFlow:
            return "full_flow"
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
        state.journeySnapshot = nil
        save(state)
    }

    func markEstablishedWorkspacePromptDismissed(version: Int = AppOnboardingState.currentVersion) {
        var state = load()
        state.establishedWorkspacePromptDismissedVersion = version
        save(state)
    }

    func storeJourney(_ snapshot: OnboardingJourneySnapshot?) {
        var state = load()
        state.journeySnapshot = snapshot
        save(state)
    }

    func clearJourney() {
        var state = load()
        state.journeySnapshot = nil
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
    let reason: String
    let durationMinutes: Int
    let priority: TaskPriority
    let type: TaskType
    let energy: TaskEnergy
    let category: TaskCategory
    let context: TaskContext
    let dueDateIntent: AddTaskPrefillDueIntent
    let isQuickWin: Bool
    let clearDoneState: Bool
    let recommendedProfiles: Set<OnboardingFrictionProfile>

    func makePrefill(project: Project) -> AddTaskPrefillTemplate {
        AddTaskPrefillTemplate(
            title: title,
            details: nil,
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: project.lifeAreaID,
            priority: priority,
            type: type,
            dueDateIntent: dueDateIntent,
            estimatedDuration: TimeInterval(durationMinutes * 60),
            energy: energy,
            category: category,
            context: context,
            showMoreDetails: false,
            showAdvancedPlanning: false
        )
    }

    func makeRequest(project: Project) -> CreateTaskDefinitionRequest {
        CreateTaskDefinitionRequest(
            title: title,
            details: nil,
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: project.lifeAreaID,
            dueDate: dueDateIntent.resolvedDate(),
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            estimatedDuration: TimeInterval(durationMinutes * 60),
            createdAt: Date()
        )
    }
}

struct StarterHabitTemplate: Identifiable, Equatable {
    let id: String
    let lifeAreaTemplateID: String
    let projectTemplateID: String?
    let title: String
    let reason: String
    let kind: HabitKind
    let trackingMode: HabitTrackingMode
    let cadence: HabitCadenceDraft
    let icon: HabitIconMetadata
    let notes: String?
    let recommendedProfiles: Set<OnboardingFrictionProfile>

    var isPositive: Bool {
        kind == .positive
    }

    func makePrefill(lifeAreaID: UUID, projectID: UUID?) -> AddHabitPrefillTemplate {
        AddHabitPrefillTemplate(
            title: title,
            notes: notes,
            lifeAreaID: lifeAreaID,
            projectID: projectID,
            kind: kind == .positive ? .positive : .negative,
            trackingMode: trackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly,
            cadence: cadence,
            iconSymbolName: icon.symbolName
        )
    }

    func makeRequest(lifeAreaID: UUID, projectID: UUID?) -> CreateHabitRequest {
        CreateHabitRequest(
            title: title,
            lifeAreaID: lifeAreaID,
            projectID: projectID,
            kind: kind,
            trackingMode: trackingMode,
            icon: icon,
            targetConfig: HabitTargetConfig(notes: notes, targetCountPerDay: 1),
            metricConfig: HabitMetricConfig(unitLabel: nil, showNotesOnCompletion: notes != nil),
            cadence: cadence
        )
    }
}

struct StarterProjectTemplate: Identifiable, Equatable {
    let id: String
    let lifeAreaTemplateID: String
    let name: String
    let summary: String
    let aliases: [String]
    let taskTemplates: [StarterTaskTemplate]
}

struct StarterLifeAreaTemplate: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let colorHex: String
    let aliases: [String]
    let projects: [StarterProjectTemplate]
}

enum StarterWorkspaceCatalog {
    static let coreLifeAreaIDs = ["work-career", "life-admin", "health-self"]
    static let optionalLifeAreaIDs = ["relationships", "learning-growth", "creativity-fun", "money"]

    private static let legacyLifeAreaIDMap: [String: String] = [
        "career": "work-career",
        "home": "life-admin",
        "health": "health-self",
        "learning": "learning-growth",
        "money": "money"
    ]

    private static let legacyProjectIDMap: [String: String] = [
        "career-ship": "work-ship",
        "career-followups": "work-followups",
        "career-admin": "work-admin",
        "home-reset": "life-home-reset",
        "home-laundry": "life-home-reset",
        "home-errands": "life-errands",
        "health-meal": "health-meals"
    ]

    private static let legacyTaskIDMap: [String: String] = [
        "task-home-laundry-basket": "task-home-reset-five",
        "task-learning-read-page": "task-health-reflect-page",
        "task-learning-read-takeaway": "task-health-reflect-takeaway"
    ]

    private static let legacyHabitIDMap: [String: String] = [
        "habit-home-laundry": "habit-home-reset",
        "habit-learning-page": "habit-health-read-page"
    ]

    private static let defaultProjectByFriction: [OnboardingFrictionProfile: [String: String]] = [
        .starting: [
            "work-career": "work-ship",
            "life-admin": "life-home-reset",
            "health-self": "health-move"
        ],
        .choosing: [
            "work-career": "work-followups",
            "life-admin": "life-bills-money",
            "health-self": "health-meals"
        ],
        .remembering: [
            "work-career": "work-followups",
            "life-admin": "life-appointments-paperwork",
            "health-self": "health-sleep"
        ],
        .finishing: [
            "work-career": "work-ship",
            "life-admin": "life-home-reset",
            "health-self": "health-recovery"
        ],
        .overwhelmed: [
            "work-career": "work-admin",
            "life-admin": "life-home-reset",
            "health-self": "health-recovery"
        ]
    ]

    private static let primaryTaskIDByFriction: [OnboardingFrictionProfile: String] = [
        .starting: "task-career-ship-draft",
        .choosing: "task-money-bills-date",
        .remembering: "task-life-appointments-calendar",
        .finishing: "task-home-reset-surface",
        .overwhelmed: "task-home-reset-five"
    ]

    private static let primaryHabitIDByFriction: [OnboardingFrictionProfile: String] = [
        .starting: "habit-health-water",
        .choosing: "habit-career-plan",
        .remembering: "habit-life-appointments-check",
        .finishing: "habit-work-must-move",
        .overwhelmed: "habit-health-reset-after-work"
    ]

    static let allLifeAreas: [StarterLifeAreaTemplate] = [
        area(
            id: "work-career",
            name: "Work & Career",
            subtitle: "Ship work, close loops, and stay ahead of drift",
            icon: "briefcase.fill",
            colorHex: "#B1205F",
            aliases: ["work", "career", "job", "office", "professional"],
            projects: [
                project(
                    id: "work-ship",
                    lifeAreaID: "work-career",
                    name: "Ship something",
                    summary: "Keep the next visible output moving.",
                    aliases: ["ship one thing", "deliverable", "work output"],
                    tasks: [
                        task(
                            id: "task-career-ship-draft",
                            projectID: "work-ship",
                            title: "Open the draft and write 3 lines",
                            reason: "It removes the hard part: getting started.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.starting]
                        ),
                        task(
                            id: "task-work-ship-bullet",
                            projectID: "work-ship",
                            title: "Write the first bullet of the spec",
                            reason: "A small visible output makes the next pass easier.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.finishing]
                        ),
                        task(
                            id: "task-work-ship-stub",
                            projectID: "work-ship",
                            title: "Rename the file and create the document stub",
                            reason: "This creates a place for the work to land.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.starting, .choosing]
                        )
                    ]
                ),
                project(
                    id: "work-followups",
                    lifeAreaID: "work-career",
                    name: "Follow-ups",
                    summary: "Keep important loose ends from disappearing.",
                    aliases: ["followups", "follow up", "replies"],
                    tasks: [
                        task(
                            id: "task-career-followups-note",
                            projectID: "work-followups",
                            title: "Write the name of one person to follow up with",
                            reason: "Capture first, decide the full message second.",
                            minutes: 1,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .phone,
                            recommendedProfiles: [.remembering]
                        ),
                        task(
                            id: "task-career-ship-message",
                            projectID: "work-followups",
                            title: "Send one unblocker message",
                            reason: "One message can restart stalled work fast.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .phone,
                            recommendedProfiles: [.choosing, .finishing]
                        ),
                        task(
                            id: "task-work-followups-reply",
                            projectID: "work-followups",
                            title: "Reply to one pending thread",
                            reason: "A single reply closes a real loop.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.remembering]
                        )
                    ]
                ),
                project(
                    id: "work-meetings",
                    lifeAreaID: "work-career",
                    name: "Meetings & decisions",
                    summary: "Turn meetings into next actions, not memory burden.",
                    aliases: ["meetings", "decisions", "agendas"],
                    tasks: [
                        task(
                            id: "task-work-meetings-agenda",
                            projectID: "work-meetings",
                            title: "Write one agenda point for today's meeting",
                            reason: "One agenda note keeps the meeting from becoming drift.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .meeting
                        ),
                        task(
                            id: "task-work-meetings-decision",
                            projectID: "work-meetings",
                            title: "Capture one decision from the last meeting",
                            reason: "Writing it down stops the decision from dissolving.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .work,
                            context: .computer
                        ),
                        task(
                            id: "task-work-meetings-next-action",
                            projectID: "work-meetings",
                            title: "Write one next action from the call",
                            reason: "A meeting only helps when it becomes action.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .work,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "work-admin",
                    lifeAreaID: "work-career",
                    name: "Work admin",
                    summary: "Reduce drag from small but persistent work chores.",
                    aliases: ["work admin reset", "admin", "ops", "cleanup"],
                    tasks: [
                        task(
                            id: "task-career-admin-email",
                            projectID: "work-admin",
                            title: "Archive one stale thread",
                            reason: "It closes a loop with almost no setup cost.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-work-admin-downloads",
                            projectID: "work-admin",
                            title: "Clean one desktop/downloads item",
                            reason: "A tiny cleanup lowers the visual tax immediately.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-work-admin-title",
                            projectID: "work-admin",
                            title: "Update one task title so it is actionable",
                            reason: "Clear wording makes the next step easier to trust.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .work,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "work-growth",
                    lifeAreaID: "work-career",
                    name: "Career growth",
                    summary: "Keep long-term growth visible without turning it into homework.",
                    aliases: ["growth", "career growth", "skills"],
                    tasks: [
                        task(
                            id: "task-work-growth-idea",
                            projectID: "work-growth",
                            title: "Save one growth idea",
                            reason: "Capturing one idea keeps it from vanishing.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-work-growth-gap",
                            projectID: "work-growth",
                            title: "Write one note about a skill gap",
                            reason: "Naming it makes future practice easier to choose.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-work-growth-open-resource",
                            projectID: "work-growth",
                            title: "Open one saved learning resource",
                            reason: "Re-entry counts even when you only open the tab.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        )
                    ]
                )
            ]
        ),
        area(
            id: "life-admin",
            name: "Life & Admin",
            subtitle: "Home, errands, paperwork, and money without the background stress",
            icon: "house.fill",
            colorHex: "#5C6AC4",
            aliases: ["life", "admin", "home", "paperwork", "errands", "personal admin"],
            projects: [
                project(
                    id: "life-home-reset",
                    lifeAreaID: "life-admin",
                    name: "Home reset",
                    summary: "Quick wins that make your space easier to re-enter.",
                    aliases: ["home reset", "reset", "tidy", "cleanup"],
                    tasks: [
                        task(
                            id: "task-home-reset-five",
                            projectID: "life-home-reset",
                            title: "Put away 5 things",
                            reason: "It is concrete, finite, and hard to overthink.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .maintenance,
                            context: .home,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-home-reset-surface",
                            projectID: "life-home-reset",
                            title: "Clear one surface",
                            reason: "One visible patch of calm counts immediately.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .maintenance,
                            context: .home,
                            recommendedProfiles: [.finishing]
                        ),
                        task(
                            id: "task-life-home-reset-trash",
                            projectID: "life-home-reset",
                            title: "Throw away obvious trash for 2 minutes",
                            reason: "A short sweep makes the room easier to re-enter.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .maintenance,
                            context: .home,
                            recommendedProfiles: [.starting]
                        )
                    ]
                ),
                project(
                    id: "life-appointments-paperwork",
                    lifeAreaID: "life-admin",
                    name: "Appointments & paperwork",
                    summary: "Track appointments, forms, and admin before they become stress.",
                    aliases: ["appointments", "paperwork", "forms", "admin"],
                    tasks: [
                        task(
                            id: "task-life-appointments-book",
                            projectID: "life-appointments-paperwork",
                            title: "Book one appointment",
                            reason: "Booking is often the only real blocker.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .phone
                        ),
                        task(
                            id: "task-life-appointments-calendar",
                            projectID: "life-appointments-paperwork",
                            title: "Add one appointment to calendar",
                            reason: "Putting it where you will see it prevents it from vanishing again.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .phone,
                            recommendedProfiles: [.remembering]
                        ),
                        task(
                            id: "task-life-appointments-document",
                            projectID: "life-appointments-paperwork",
                            title: "Photograph one document",
                            reason: "Capturing the document now lowers later friction.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .phone
                        ),
                        task(
                            id: "task-life-appointments-form",
                            projectID: "life-appointments-paperwork",
                            title: "Fill one field on a form",
                            reason: "A tiny slice keeps the admin loop moving.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "life-errands",
                    lifeAreaID: "life-admin",
                    name: "Errands & shopping",
                    summary: "Move outside-the-house loose ends forward.",
                    aliases: ["errands", "shopping", "pickup", "store"],
                    tasks: [
                        task(
                            id: "task-home-errands-note",
                            projectID: "life-errands",
                            title: "Write one errand in one place",
                            reason: "This gets it out of your head before it vanishes again.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .errands
                        ),
                        task(
                            id: "task-life-errands-group",
                            projectID: "life-errands",
                            title: "Group two errands into one trip",
                            reason: "Bundling lowers the activation cost later.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .errands
                        ),
                        task(
                            id: "task-life-errands-hours",
                            projectID: "life-errands",
                            title: "Check store hours for one stop",
                            reason: "Knowing the constraint turns it into a real plan.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "life-bills-money",
                    lifeAreaID: "life-admin",
                    name: "Bills & money check-ins",
                    summary: "Remove uncertainty around bills and basic money upkeep.",
                    aliases: ["bills", "money", "finance", "due dates"],
                    tasks: [
                        task(
                            id: "task-money-bills-date",
                            projectID: "life-bills-money",
                            title: "Open one bill and check the due date",
                            reason: "Knowing the date is a real win and lowers dread.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer,
                            recommendedProfiles: [.choosing]
                        ),
                        task(
                            id: "task-life-bills-reminder",
                            projectID: "life-bills-money",
                            title: "Add one due date to reminders",
                            reason: "One reminder is enough to stop carrying it in your head.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        ),
                        task(
                            id: "task-life-bills-charge",
                            projectID: "life-bills-money",
                            title: "Check one recent charge",
                            reason: "One quick glance reduces uncertainty fast.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "life-digital-reset",
                    lifeAreaID: "life-admin",
                    name: "Digital reset",
                    summary: "Reduce digital clutter that silently taxes attention.",
                    aliases: ["digital reset", "inbox", "files", "cleanup"],
                    tasks: [
                        task(
                            id: "task-life-digital-unsubscribe",
                            projectID: "life-digital-reset",
                            title: "Unsubscribe from one email",
                            reason: "Removing one future interruption is a real win.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer
                        ),
                        task(
                            id: "task-life-digital-rename",
                            projectID: "life-digital-reset",
                            title: "Rename one file so it is searchable",
                            reason: "Future-you benefits from one clean label.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer
                        ),
                        task(
                            id: "task-life-digital-delete",
                            projectID: "life-digital-reset",
                            title: "Delete one useless screenshot batch",
                            reason: "A tiny cleanup cuts visual noise quickly.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "health-self",
            name: "Health & Self",
            subtitle: "Protect energy, movement, sleep, and recovery without pressure",
            icon: "heart.fill",
            colorHex: "#293A18",
            aliases: ["health", "self", "wellness", "energy", "recovery", "body"],
            projects: [
                project(
                    id: "health-move",
                    lifeAreaID: "health-self",
                    name: "Move your body",
                    summary: "Small movement that gets the day unstuck.",
                    aliases: ["movement", "exercise", "workout"],
                    tasks: [
                        task(
                            id: "task-health-move-clothes",
                            projectID: "health-move",
                            title: "Put on workout clothes",
                            reason: "It is small enough to begin and makes the next move easier.",
                            minutes: 1,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .home
                        ),
                        task(
                            id: "task-health-move-water",
                            projectID: "health-move",
                            title: "Fill your water bottle",
                            reason: "It gives you an instant win with a clear done state.",
                            minutes: 1,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .home
                        ),
                        task(
                            id: "task-health-move-walk",
                            projectID: "health-move",
                            title: "Walk for 10 minutes",
                            reason: "A good backup option when you want a little more movement.",
                            minutes: 10,
                            type: .morning,
                            energy: .medium,
                            category: .health,
                            context: .outdoor
                        )
                    ]
                ),
                project(
                    id: "health-sleep",
                    lifeAreaID: "health-self",
                    name: "Sleep wind-down",
                    summary: "Tiny cues that make stopping easier later.",
                    aliases: ["sleep", "rest", "bedtime"],
                    tasks: [
                        task(
                            id: "task-health-sleep-charge",
                            projectID: "health-sleep",
                            title: "Put your phone on the charger",
                            reason: "One visible action can mark the start of winding down.",
                            minutes: 1,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .home,
                            recommendedProfiles: [.remembering]
                        ),
                        task(
                            id: "task-health-sleep-night-mode",
                            projectID: "health-sleep",
                            title: "Turn on night mode",
                            reason: "A small cue makes the later stop easier.",
                            minutes: 1,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .phone
                        ),
                        task(
                            id: "task-health-sleep-tomorrow",
                            projectID: "health-sleep",
                            title: "Set out what you need for tomorrow morning",
                            reason: "Lowering tomorrow's startup cost also helps you stop tonight.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "health-meals",
                    lifeAreaID: "health-self",
                    name: "Meal reset",
                    summary: "Reduce food friction before it gets loud.",
                    aliases: ["food", "meals", "nutrition"],
                    tasks: [
                        task(
                            id: "task-health-meal-snack",
                            projectID: "health-meals",
                            title: "Put one easy snack where you can see it",
                            reason: "This lowers the energy needed to make the next decent choice.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .home
                        ),
                        task(
                            id: "task-health-meal-list",
                            projectID: "health-meals",
                            title: "Write one meal idea for tonight",
                            reason: "One concrete choice beats carrying the whole problem around.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .anywhere,
                            recommendedProfiles: [.choosing]
                        ),
                        task(
                            id: "task-health-meal-prep",
                            projectID: "health-meals",
                            title: "Prep one simple ingredient",
                            reason: "One small prep step lowers the cost of the whole meal later.",
                            minutes: 5,
                            type: .upcoming,
                            energy: .low,
                            category: .health,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "health-recovery",
                    lifeAreaID: "health-self",
                    name: "Recovery & calm",
                    summary: "Make rest and reset visible instead of optional.",
                    aliases: ["recovery", "calm", "rest", "reset"],
                    tasks: [
                        task(
                            id: "task-health-recovery-reset",
                            projectID: "health-recovery",
                            title: "Sit down for a 2-minute reset",
                            reason: "A tiny pause is enough to interrupt the spiral.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .home,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-health-recovery-outside",
                            projectID: "health-recovery",
                            title: "Step outside for 5 minutes",
                            reason: "A short reset can change the whole feel of the next hour.",
                            minutes: 5,
                            type: .upcoming,
                            energy: .low,
                            category: .health,
                            context: .outdoor
                        ),
                        task(
                            id: "task-health-recovery-breaths",
                            projectID: "health-recovery",
                            title: "Fill your glass and take 5 breaths",
                            reason: "It is concrete, finite, and calming.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .health,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "health-reflect",
                    lifeAreaID: "health-self",
                    name: "Read & reflect",
                    summary: "A light self-renewal loop for people who need mental reset, not just productivity.",
                    aliases: ["read", "reflect", "renewal"],
                    tasks: [
                        task(
                            id: "task-health-reflect-page",
                            projectID: "health-reflect",
                            title: "Read 1 page",
                            reason: "A tiny reading dose is easier to keep than waiting for the perfect block.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-health-reflect-takeaway",
                            projectID: "health-reflect",
                            title: "Write 1 takeaway from yesterday",
                            reason: "One sentence closes the loop on the day.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-health-reflect-idea",
                            projectID: "health-reflect",
                            title: "Save one idea you do not want to lose",
                            reason: "Capturing the idea is enough for today.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "relationships",
            name: "Relationships",
            subtitle: "Keep important people from slipping into the background",
            icon: "person.2.fill",
            colorHex: "#A53E6D",
            aliases: ["relationships", "friends", "family", "social"],
            projects: [
                project(
                    id: "relationships-partner-family",
                    lifeAreaID: "relationships",
                    name: "Partner / family",
                    summary: "Keep close relationships visible in a low-pressure way.",
                    aliases: ["partner", "family", "home people"],
                    tasks: [
                        task(
                            id: "task-relationships-family-text",
                            projectID: "relationships-partner-family",
                            title: "Send one check-in text",
                            reason: "One small touch counts.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-family-calendar",
                            projectID: "relationships-partner-family",
                            title: "Add one family date to calendar",
                            reason: "Putting it on the calendar keeps it real.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-family-question",
                            projectID: "relationships-partner-family",
                            title: "Write one thing you want to ask about",
                            reason: "A prompt makes the next conversation easier.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .anywhere
                        )
                    ]
                ),
                project(
                    id: "relationships-friends",
                    lifeAreaID: "relationships",
                    name: "Friends",
                    summary: "Keep friendship maintenance light and visible.",
                    aliases: ["friends", "friendships"],
                    tasks: [
                        task(
                            id: "task-relationships-friends-reply",
                            projectID: "relationships-friends",
                            title: "Reply to one personal message",
                            reason: "One reply keeps the thread alive.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-friends-plan",
                            projectID: "relationships-friends",
                            title: "Suggest one plan to a friend",
                            reason: "A specific suggestion is easier to act on than a vague intention.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-friends-list",
                            projectID: "relationships-friends",
                            title: "Write down one friend to check in with",
                            reason: "One name gives you a clear next move.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .anywhere
                        )
                    ]
                ),
                project(
                    id: "relationships-social-plans",
                    lifeAreaID: "relationships",
                    name: "Social plans",
                    summary: "Turn vague social intentions into one small plan.",
                    aliases: ["social plans", "weekend plans", "hangouts"],
                    tasks: [
                        task(
                            id: "task-relationships-social-idea",
                            projectID: "relationships-social-plans",
                            title: "Write one idea for the weekend",
                            reason: "One idea is enough to get plans unstuck.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .anywhere
                        ),
                        task(
                            id: "task-relationships-social-invite",
                            projectID: "relationships-social-plans",
                            title: "Text one invite",
                            reason: "The send matters more than the perfect wording.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-social-place",
                            projectID: "relationships-social-plans",
                            title: "Pick one time and place",
                            reason: "Specific plans are easier to finish.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "learning-growth",
            name: "Learning & Growth",
            subtitle: "Study, practice, and keep growth visible without turning it into homework",
            icon: "book.fill",
            colorHex: "#9E5F0A",
            aliases: ["learning", "growth", "study", "practice"],
            projects: [
                project(
                    id: "learning-read",
                    lifeAreaID: "learning-growth",
                    name: "Read and capture",
                    summary: "Turn a small reading moment into something retained.",
                    aliases: ["read", "reading", "capture"],
                    tasks: [
                        task(
                            id: "task-learning-read-page",
                            projectID: "learning-read",
                            title: "Open the book and read 1 page",
                            reason: "The commitment is tiny, but it still counts as re-entry.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-learning-read-takeaway",
                            projectID: "learning-read",
                            title: "Write 1 takeaway from yesterday",
                            reason: "One sentence closes the loop on previous effort.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-learning-read-save",
                            projectID: "learning-read",
                            title: "Save one idea you want to revisit",
                            reason: "Capturing the idea counts as progress.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "learning-study",
                    lifeAreaID: "learning-growth",
                    name: "Study session",
                    summary: "Short, bounded study bursts.",
                    aliases: ["study session", "course", "class"],
                    tasks: [
                        task(
                            id: "task-learning-study-open",
                            projectID: "learning-study",
                            title: "Open the study doc",
                            reason: "Opening the material is often the actual activation barrier.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-learning-study-question",
                            projectID: "learning-study",
                            title: "Write one question you want to answer",
                            reason: "A question gives the study block shape immediately.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "learning-practice",
                    lifeAreaID: "learning-growth",
                    name: "Practice block",
                    summary: "Build repetition without needing a huge block of time.",
                    aliases: ["practice", "reps", "drills"],
                    tasks: [
                        task(
                            id: "task-learning-practice-minute",
                            projectID: "learning-practice",
                            title: "Do one 2-minute practice round",
                            reason: "You only need enough momentum to begin.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-learning-practice-step",
                            projectID: "learning-practice",
                            title: "Write the next tiny thing to practice",
                            reason: "The next rep is easier when it is already named.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        )
                    ]
                )
            ]
        ),
        area(
            id: "creativity-fun",
            name: "Creativity & Fun",
            subtitle: "Make room for hobbies, play, and expression",
            icon: "paintpalette.fill",
            colorHex: "#D97706",
            aliases: ["creativity", "fun", "hobby", "creative"],
            projects: [
                project(
                    id: "creativity-writing",
                    lifeAreaID: "creativity-fun",
                    name: "Personal writing",
                    summary: "Keep creative output warm with tiny starts.",
                    aliases: ["writing", "journal", "notes"],
                    tasks: [
                        task(
                            id: "task-creativity-writing-lines",
                            projectID: "creativity-writing",
                            title: "Write 2 lines",
                            reason: "A tiny opening sentence is enough for re-entry.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .creative,
                            context: .anywhere
                        ),
                        task(
                            id: "task-creativity-writing-title",
                            projectID: "creativity-writing",
                            title: "Open the note and title the idea",
                            reason: "Naming the idea lowers the cost of coming back.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "creativity-hobby",
                    lifeAreaID: "creativity-fun",
                    name: "Hobby practice",
                    summary: "Keep the hobby visible without demanding a full session.",
                    aliases: ["hobby", "practice", "creative practice"],
                    tasks: [
                        task(
                            id: "task-creativity-hobby-materials",
                            projectID: "creativity-hobby",
                            title: "Put the materials where you can reach them",
                            reason: "Reducing setup friction makes the hobby more likely to happen.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .home
                        ),
                        task(
                            id: "task-creativity-hobby-five",
                            projectID: "creativity-hobby",
                            title: "Do 5 minutes of practice",
                            reason: "A short block keeps the loop alive.",
                            minutes: 5,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "creativity-weekend",
                    lifeAreaID: "creativity-fun",
                    name: "Weekend ideas",
                    summary: "Capture fun before the week consumes it.",
                    aliases: ["weekend", "fun plans", "ideas"],
                    tasks: [
                        task(
                            id: "task-creativity-weekend-idea",
                            projectID: "creativity-weekend",
                            title: "Write one fun idea for this week",
                            reason: "A single idea gives the week more shape.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .anywhere
                        ),
                        task(
                            id: "task-creativity-weekend-save",
                            projectID: "creativity-weekend",
                            title: "Save one place or event to try",
                            reason: "Saving it now keeps it from dissolving.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "money",
            name: "Money",
            subtitle: "Give money its own lane when you want deeper visibility",
            icon: "dollarsign.circle.fill",
            colorHex: "#2E8B57",
            aliases: ["finance", "finances", "budget"],
            projects: [
                project(
                    id: "money-bills",
                    lifeAreaID: "money",
                    name: "Bills this week",
                    summary: "Remove uncertainty before it starts compounding.",
                    aliases: ["bills", "payments", "due dates"],
                    tasks: [
                        task(
                            id: "task-money-standalone-bills-date",
                            projectID: "money-bills",
                            title: "Open one bill and check the due date",
                            reason: "Knowing the date lowers dread immediately.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer
                        ),
                        task(
                            id: "task-money-standalone-reminder",
                            projectID: "money-bills",
                            title: "Add one due date to reminders",
                            reason: "One reminder removes the need to hold it in memory.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "money-budget",
                    lifeAreaID: "money",
                    name: "Budget reset",
                    summary: "Lightweight money awareness without a full planning session.",
                    aliases: ["budget", "spending", "plan"],
                    tasks: [
                        task(
                            id: "task-money-budget-receipt",
                            projectID: "money-budget",
                            title: "Move one receipt into one place",
                            reason: "Organizing one input is easier than fixing the whole system.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        ),
                        task(
                            id: "task-money-budget-charge",
                            projectID: "money-budget",
                            title: "Check one recent charge",
                            reason: "One quick review reduces uncertainty fast.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "money-errands",
                    lifeAreaID: "money",
                    name: "Financial errands",
                    summary: "Small admin that prevents surprise problems later.",
                    aliases: ["financial errands", "bank", "paperwork"],
                    tasks: [
                        task(
                            id: "task-money-errands-note",
                            projectID: "money-errands",
                            title: "Write the one money errand you need",
                            reason: "Capturing it now keeps it from turning into background stress.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .anywhere
                        ),
                        task(
                            id: "task-money-errands-hours",
                            projectID: "money-errands",
                            title: "Check the hours for one money errand",
                            reason: "Knowing the constraint makes it easier to finish.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        )
                    ]
                )
            ]
        )
    ]

    static let allHabitTemplates: [StarterHabitTemplate] = [
        positiveHabit(
            id: "habit-career-plan",
            lifeAreaID: "work-career",
            projectID: "work-ship",
            title: "Choose tomorrow's first work step",
            reason: "Deciding before you stop makes tomorrow easier to begin.",
            cadence: .daily(hour: 17, minute: 30),
            symbol: "briefcase.fill",
            categoryKey: "work",
            notes: "Keep it to one specific next step.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-work-must-move",
            lifeAreaID: "work-career",
            projectID: "work-ship",
            title: "End the day by naming one \"must move\" item",
            reason: "One named item keeps tomorrow from starting blank.",
            cadence: .daily(hour: 17, minute: 45),
            symbol: "flag.fill",
            categoryKey: "work",
            notes: "Pick one thing, not a full list.",
            recommendedProfiles: [.finishing]
        ),
        positiveHabit(
            id: "habit-career-followups",
            lifeAreaID: "work-career",
            projectID: "work-followups",
            title: "Check follow-ups every weekday",
            reason: "A light weekday sweep keeps important threads from disappearing.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 16, minute: 0),
            symbol: "tray.full.fill",
            categoryKey: "work",
            notes: "You are maintaining visibility, not clearing everything.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-work-waiting-on",
            lifeAreaID: "work-career",
            projectID: "work-followups",
            title: "Review waiting-on items before signing off",
            reason: "One short pass keeps important loose ends visible.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 17, minute: 0),
            symbol: "clock.badge.checkmark.fill",
            categoryKey: "work",
            notes: "A short review is enough.",
            recommendedProfiles: [.remembering, .finishing]
        ),

        positiveHabit(
            id: "habit-home-reset",
            lifeAreaID: "life-admin",
            projectID: "life-home-reset",
            title: "Do a 2-minute home reset",
            reason: "Short resets lower the cost of coming back to your space later.",
            cadence: .daily(hour: 20, minute: 0),
            symbol: "house.fill",
            categoryKey: "life",
            notes: "Stop after two minutes even if more is possible.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-life-surface",
            lifeAreaID: "life-admin",
            projectID: "life-home-reset",
            title: "Reset one visible surface every evening",
            reason: "One visible patch of calm is easier to sustain than a full cleanup.",
            cadence: .daily(hour: 20, minute: 30),
            symbol: "sparkles",
            categoryKey: "life",
            notes: "Pick just one surface.",
            recommendedProfiles: [.finishing]
        ),
        positiveHabit(
            id: "habit-life-appointments-check",
            lifeAreaID: "life-admin",
            projectID: "life-appointments-paperwork",
            title: "Check appointments twice a week",
            reason: "A light review is enough to keep appointments from surprising you.",
            cadence: .weekly(daysOfWeek: [2, 5], hour: 18, minute: 0),
            symbol: "calendar.badge.clock",
            categoryKey: "life",
            notes: "Check what is coming, not everything at once.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-life-paperwork-capture",
            lifeAreaID: "life-admin",
            projectID: "life-appointments-paperwork",
            title: "Put paperwork in one capture place",
            reason: "One place lowers the mental cost of admin.",
            cadence: .weekly(daysOfWeek: [2, 4, 6], hour: 18, minute: 30),
            symbol: "tray.and.arrow.down.fill",
            categoryKey: "life",
            notes: "Do not sort it yet.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-life-errands-review",
            lifeAreaID: "life-admin",
            projectID: "life-errands",
            title: "Review errands before leaving home",
            reason: "A quick glance makes the trip more useful.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6, 7], hour: 9, minute: 0),
            symbol: "car.fill",
            categoryKey: "life",
            notes: "Check only when it helps.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-life-bill-check",
            lifeAreaID: "life-admin",
            projectID: "life-bills-money",
            title: "Friday bill check",
            reason: "One weekly glance removes uncertainty without turning into a finance project.",
            cadence: .weekly(daysOfWeek: [6], hour: 11, minute: 0),
            symbol: "creditcard.fill",
            categoryKey: "life",
            notes: "This is about awareness, not perfection.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-money-check",
            lifeAreaID: "life-admin",
            projectID: "life-bills-money",
            title: "Weekly account glance",
            reason: "A short weekly glance is easier to keep than a full budget session.",
            cadence: .weekly(daysOfWeek: [6], hour: 12, minute: 0),
            symbol: "dollarsign.circle.fill",
            categoryKey: "life",
            notes: "You are checking in, not judging.",
            recommendedProfiles: [.choosing, .remembering]
        ),
        positiveHabit(
            id: "habit-life-digital-cleanup",
            lifeAreaID: "life-admin",
            projectID: "life-digital-reset",
            title: "5-minute inbox cleanup once a week",
            reason: "One short cleanup keeps digital clutter from silently growing.",
            cadence: .weekly(daysOfWeek: [7], hour: 18, minute: 0),
            symbol: "envelope.badge.fill",
            categoryKey: "life",
            notes: "Five minutes is enough.",
            recommendedProfiles: [.overwhelmed]
        ),

        positiveHabit(
            id: "habit-health-water",
            lifeAreaID: "health-self",
            projectID: "health-move",
            title: "Drink water after you wake up",
            reason: "It is easy to remember, takes seconds, and creates a clean start signal.",
            cadence: .daily(hour: 8, minute: 0),
            symbol: "drop.fill",
            categoryKey: "health",
            notes: "Use a tiny win that helps the next healthy choice happen.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-move-five",
            lifeAreaID: "health-self",
            projectID: "health-move",
            title: "Move for 5 minutes each morning",
            reason: "A tiny movement block is easier to keep than a full routine.",
            cadence: .daily(hour: 8, minute: 30),
            symbol: "figure.walk",
            categoryKey: "health",
            notes: "Five minutes is enough.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-charge",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Put your phone on the charger before bed",
            reason: "A visible bedtime cue is easier to keep than a full evening routine.",
            cadence: .daily(hour: 21, minute: 30),
            symbol: "bed.double.fill",
            categoryKey: "health",
            notes: "Make the stop signal obvious.",
            recommendedProfiles: [.remembering]
        ),
        negativeHabit(
            id: "habit-health-no-phone-bed",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Keep your phone out of bed",
            reason: "This supports better wind-down without asking for a perfect night.",
            cadence: .daily(hour: 22, minute: 0),
            symbol: "moon.zzz.fill",
            categoryKey: "health",
            notes: "Recovery matters more than streak perfection.",
            recommendedProfiles: [.remembering, .overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-same-wind-down",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Start wind-down at the same time each night",
            reason: "A consistent cue makes stopping easier later.",
            cadence: .daily(hour: 21, minute: 0),
            symbol: "moon.stars.fill",
            categoryKey: "health",
            notes: "It does not have to be perfect.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-health-lunch",
            lifeAreaID: "health-self",
            projectID: "health-meals",
            title: "Decide lunch before noon",
            reason: "One small decision lowers food friction before it gets loud.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 11, minute: 0),
            symbol: "fork.knife",
            categoryKey: "health",
            notes: "A rough decision counts.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-health-snack",
            lifeAreaID: "health-self",
            projectID: "health-meals",
            title: "Eat one protein-first snack daily",
            reason: "A small reliable snack lowers the cost of better food choices.",
            cadence: .daily(hour: 15, minute: 0),
            symbol: "leaf.fill",
            categoryKey: "health",
            notes: "Keep it simple.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-health-reset-after-work",
            lifeAreaID: "health-self",
            projectID: "health-recovery",
            title: "Do a 2-minute reset after work",
            reason: "A short reset creates recovery without demanding a full routine.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 18, minute: 0),
            symbol: "figure.mind.and.body",
            categoryKey: "health",
            notes: "Two minutes is enough to count.",
            recommendedProfiles: [.overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-check-energy",
            lifeAreaID: "health-self",
            projectID: "health-recovery",
            title: "Check energy before taking on more",
            reason: "A quick check helps you stop borrowing from later.",
            cadence: .daily(hour: 14, minute: 0),
            symbol: "bolt.heart.fill",
            categoryKey: "health",
            notes: "Pause before saying yes.",
            recommendedProfiles: [.overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-read-page",
            lifeAreaID: "health-self",
            projectID: "health-reflect",
            title: "Read one page each evening",
            reason: "A tiny daily dose is easier to keep than waiting for a deep session.",
            cadence: .daily(hour: 20, minute: 30),
            symbol: "book.fill",
            categoryKey: "health",
            notes: "Stop after one page if that is all you have today.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-takeaway",
            lifeAreaID: "health-self",
            projectID: "health-reflect",
            title: "Capture one takeaway before bed",
            reason: "One takeaway helps the day feel finished.",
            cadence: .daily(hour: 21, minute: 15),
            symbol: "text.quote",
            categoryKey: "health",
            notes: "One sentence is enough.",
            recommendedProfiles: [.finishing]
        ),

        positiveHabit(
            id: "habit-relationships-check-in",
            lifeAreaID: "relationships",
            projectID: "relationships-friends",
            title: "Check in with one person each week",
            reason: "One short check-in keeps relationships from drifting into the background.",
            cadence: .weekly(daysOfWeek: [7], hour: 16, minute: 0),
            symbol: "person.crop.circle.badge.plus",
            categoryKey: "relationships",
            notes: "One person is enough.",
            recommendedProfiles: []
        ),
        positiveHabit(
            id: "habit-learning-capture",
            lifeAreaID: "learning-growth",
            projectID: "learning-read",
            title: "Capture one thing you learned",
            reason: "A small capture helps learning stick.",
            cadence: .daily(hour: 20, minute: 0),
            symbol: "graduationcap.fill",
            categoryKey: "learning",
            notes: "One idea is enough.",
            recommendedProfiles: []
        ),
        positiveHabit(
            id: "habit-creativity-make",
            lifeAreaID: "creativity-fun",
            projectID: "creativity-hobby",
            title: "Make something for 10 minutes twice a week",
            reason: "A short playful block is easier to keep than waiting for a perfect creative window.",
            cadence: .weekly(daysOfWeek: [3, 7], hour: 19, minute: 0),
            symbol: "paintbrush.pointed.fill",
            categoryKey: "creativity",
            notes: "Stop at ten minutes if you want.",
            recommendedProfiles: []
        ),
        positiveHabit(
            id: "habit-money-glance",
            lifeAreaID: "money",
            projectID: "money-budget",
            title: "Weekly account glance",
            reason: "A short check-in keeps money visible without turning it into a project.",
            cadence: .weekly(daysOfWeek: [7], hour: 12, minute: 0),
            symbol: "banknote.fill",
            categoryKey: "money",
            notes: "Awareness beats avoidance.",
            recommendedProfiles: []
        )
    ]

    static func normalizeLifeAreaTemplateID(_ id: String) -> String {
        legacyLifeAreaIDMap[id] ?? id
    }

    static func normalizeProjectTemplateID(_ id: String) -> String {
        legacyProjectIDMap[id] ?? id
    }

    static func normalizeTaskTemplateID(_ id: String) -> String {
        legacyTaskIDMap[id] ?? id
    }

    static func normalizeHabitTemplateID(_ id: String) -> String {
        legacyHabitIDMap[id] ?? id
    }

    static func normalizedProjectDraft(_ draft: OnboardingProjectDraft) -> OnboardingProjectDraft {
        let normalizedAreaID = normalizeLifeAreaTemplateID(draft.lifeAreaTemplateID)
        let normalizedTemplateID = normalizeProjectTemplateID(draft.templateID)
        let normalizedSuggestions = draft.suggestionTemplateIDs
            .map(normalizeProjectTemplateID)
            .reduce(into: [String]()) { partialResult, id in
                guard partialResult.contains(id) == false else { return }
                partialResult.append(id)
            }
        let matchedIndex = normalizedSuggestions.firstIndex(of: normalizedTemplateID) ?? 0
        let template = projectTemplate(id: normalizedTemplateID)
        return OnboardingProjectDraft(
            id: draft.id,
            lifeAreaTemplateID: normalizedAreaID,
            templateID: normalizedTemplateID,
            name: draft.name.isEmpty ? (template?.name ?? draft.name) : draft.name,
            summary: draft.summary.isEmpty ? (template?.summary ?? draft.summary) : draft.summary,
            suggestionTemplateIDs: normalizedSuggestions,
            suggestionIndex: matchedIndex,
            isSelected: draft.isSelected
        )
    }

    static func normalizedLifeAreaSelection(_ selection: ResolvedLifeAreaSelection) -> ResolvedLifeAreaSelection {
        ResolvedLifeAreaSelection(
            templateID: normalizeLifeAreaTemplateID(selection.templateID),
            lifeArea: selection.lifeArea,
            reusedExisting: selection.reusedExisting
        )
    }

    static func normalizedProjectSelection(_ selection: ResolvedProjectSelection) -> ResolvedProjectSelection {
        ResolvedProjectSelection(
            draft: normalizedProjectDraft(selection.draft),
            project: selection.project,
            reusedExisting: selection.reusedExisting
        )
    }

    static func normalizedTaskTemplateMap(_ map: [String: UUID]) -> [String: UUID] {
        map.reduce(into: [:]) { partialResult, entry in
            partialResult[normalizeTaskTemplateID(entry.key)] = entry.value
        }
    }

    static func normalizedHabitTemplateMap(_ map: [String: UUID]) -> [String: UUID] {
        map.reduce(into: [:]) { partialResult, entry in
            partialResult[normalizeHabitTemplateID(entry.key)] = entry.value
        }
    }

    static func lifeAreaTemplate(id: String) -> StarterLifeAreaTemplate? {
        let normalizedID = normalizeLifeAreaTemplateID(id)
        return allLifeAreas.first(where: { $0.id == normalizedID })
    }

    static func projectTemplate(id: String) -> StarterProjectTemplate? {
        let normalizedID = normalizeProjectTemplateID(id)
        return allLifeAreas
            .flatMap(\.projects)
            .first(where: { $0.id == normalizedID })
    }

    static func habitTemplate(id: String) -> StarterHabitTemplate? {
        let normalizedID = normalizeHabitTemplateID(id)
        return allHabitTemplates.first(where: { $0.id == normalizedID })
    }

    static func defaultLifeAreaSelectionIDs(
        for frictionProfile: OnboardingFrictionProfile?,
        mode: OnboardingMode
    ) -> [String] {
        let guided: [String]
        switch frictionProfile {
        case .starting:
            guided = ["work-career", "health-self", "life-admin"]
        case .choosing:
            guided = ["work-career", "life-admin", "health-self"]
        case .remembering:
            guided = ["life-admin", "work-career", "health-self"]
        case .finishing:
            guided = ["work-career", "life-admin", "health-self"]
        case .overwhelmed:
            guided = ["life-admin", "health-self", "work-career"]
        case .none:
            guided = ["work-career", "life-admin", "health-self"]
        }

        if mode == .custom {
            return Array(guided.prefix(1))
        }
        return guided
    }

    static func orderedLifeAreas(for frictionProfile: OnboardingFrictionProfile?) -> [StarterLifeAreaTemplate] {
        let coreIDs = defaultLifeAreaSelectionIDs(for: frictionProfile, mode: .guided)
        return (coreIDs + optionalLifeAreaIDs).compactMap(lifeAreaTemplate(id:))
    }

    static func visibleLifeAreas(
        for frictionProfile: OnboardingFrictionProfile?,
        showAll: Bool
    ) -> [StarterLifeAreaTemplate] {
        let ordered = orderedLifeAreas(for: frictionProfile)
        guard showAll == false else { return ordered }
        return Array(ordered.prefix(coreLifeAreaIDs.count))
    }

    static func defaultProjectDrafts(
        for selectedLifeAreaIDs: [String],
        mode: OnboardingMode
    ) -> [OnboardingProjectDraft] {
        defaultProjectDrafts(for: selectedLifeAreaIDs, frictionProfile: nil, mode: mode)
    }

    static func defaultProjectDrafts(
        for selectedLifeAreaIDs: [String],
        frictionProfile: OnboardingFrictionProfile?,
        mode _: OnboardingMode
    ) -> [OnboardingProjectDraft] {
        selectedLifeAreaIDs.compactMap { selectedID in
            guard let area = lifeAreaTemplate(id: selectedID) else { return nil }
            let preferredProjectID = frictionProfile.flatMap { defaultProjectByFriction[$0]?[area.id] }
            let project = preferredProjectID.flatMap(projectTemplate(id:)) ?? area.projects.first
            guard let project else { return nil }
            let suggestionIDs = area.projects.map(\.id)
            let suggestionIndex = suggestionIDs.firstIndex(of: project.id) ?? 0
            return OnboardingProjectDraft(
                lifeAreaTemplateID: area.id,
                templateID: project.id,
                name: project.name,
                summary: project.summary,
                suggestionTemplateIDs: suggestionIDs,
                suggestionIndex: suggestionIndex,
                isSelected: true
            )
        }
    }

    static func taskSuggestions(
        for projects: [ResolvedProjectSelection],
        frictionProfile: OnboardingFrictionProfile?
    ) -> [StarterTaskTemplate] {
        projects
            .flatMap { project in
                projectTemplate(id: project.draft.templateID)?.taskTemplates ?? []
            }
            .sorted { lhs, rhs in
                score(task: lhs, frictionProfile: frictionProfile) > score(task: rhs, frictionProfile: frictionProfile)
            }
    }

    static func habitSuggestions(
        for projects: [ResolvedProjectSelection],
        frictionProfile: OnboardingFrictionProfile?
    ) -> [StarterHabitTemplate] {
        let selectedAreaIDs = Set(projects.map { normalizeLifeAreaTemplateID($0.draft.lifeAreaTemplateID) })
        let selectedProjectTemplateIDs = Set(projects.map { normalizeProjectTemplateID($0.draft.templateID) })
        let ranked = allHabitTemplates
            .filter { selectedAreaIDs.contains($0.lifeAreaTemplateID) }
            .filter { template in
                guard template.isPositive == false else { return true }
                guard let projectTemplateID = template.projectTemplateID else { return false }
                return selectedProjectTemplateIDs.contains(projectTemplateID)
            }
            .sorted { lhs, rhs in
                score(habit: lhs, selectedProjectTemplateIDs: selectedProjectTemplateIDs, frictionProfile: frictionProfile)
                    > score(habit: rhs, selectedProjectTemplateIDs: selectedProjectTemplateIDs, frictionProfile: frictionProfile)
            }

        let positives = ranked.filter(\.isPositive)
        let negatives = ranked.filter { $0.isPositive == false }
        var ordered: [StarterHabitTemplate] = Array(positives.prefix(5))
        if let firstNegative = negatives.first {
            ordered.append(firstNegative)
        }
        return ordered
    }

    static func defaultFallbackTaskTemplate(for projectTemplateID: String) -> StarterTaskTemplate {
        StarterTaskTemplate(
            id: "fallback-\(normalizeProjectTemplateID(projectTemplateID))",
            projectTemplateID: normalizeProjectTemplateID(projectTemplateID),
            title: "Open this project and pick one next step",
            reason: "A tiny orienting action still counts as motion.",
            durationMinutes: 2,
            priority: .low,
            type: .morning,
            energy: .low,
            category: .general,
            context: .anywhere,
            dueDateIntent: .today,
            isQuickWin: true,
            clearDoneState: true,
            recommendedProfiles: []
        )
    }

    static func matchingLifeArea(
        for template: StarterLifeAreaTemplate,
        in existing: [LifeArea]
    ) -> LifeArea? {
        let candidateNames = Set(([template.name] + template.aliases).map(normalizedName))
        return existing.first(where: { candidateNames.contains(normalizedName($0.name)) })
    }

    static func matchingProject(
        for draft: OnboardingProjectDraft,
        lifeAreaID: UUID?,
        in existing: [Project]
    ) -> Project? {
        let normalizedDraft = normalizedProjectDraft(draft)
        let template = projectTemplate(id: normalizedDraft.templateID)
        let candidateNames = Set(
            ([normalizedDraft.name] + (template?.aliases ?? []) + [template?.name].compactMap { $0 })
                .map(normalizedName)
        )
        let candidates = existing.filter { candidateNames.contains(normalizedName($0.name)) }
        if let preferred = candidates.first(where: { $0.lifeAreaID == lifeAreaID }) {
            return preferred
        }
        return candidates.first
    }

    static func normalizedName(_ name: String) -> String {
        let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(filtered).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func isCustomLifeArea(_ lifeArea: LifeArea) -> Bool {
        lifeArea.isArchived == false && normalizedName(lifeArea.name) != "general"
    }

    static func isCustomProject(_ project: Project) -> Bool {
        project.isArchived == false && project.isInbox == false && project.isDefault == false
    }

    private static func score(task: StarterTaskTemplate, frictionProfile: OnboardingFrictionProfile?) -> Int {
        var score = 0
        score += task.isQuickWin ? 40 : 18
        score += task.clearDoneState ? 22 : 0
        score += task.durationMinutes <= 5 ? 10 : 0
        if let frictionProfile, task.recommendedProfiles.contains(frictionProfile) {
            score += 18
        }
        if let frictionProfile, primaryTaskIDByFriction[frictionProfile] == task.id {
            score += 120
        }
        switch task.context {
        case .computer, .phone, .home, .anywhere:
            score += 4
        default:
            break
        }
        return score
    }

    private static func score(
        habit: StarterHabitTemplate,
        selectedProjectTemplateIDs: Set<String>,
        frictionProfile: OnboardingFrictionProfile?
    ) -> Int {
        var score = habit.isPositive ? 55 : 22
        if let projectTemplateID = habit.projectTemplateID,
           selectedProjectTemplateIDs.contains(projectTemplateID) {
            score += 18
        }
        if let frictionProfile, habit.recommendedProfiles.contains(frictionProfile) {
            score += 14
        }
        if let frictionProfile, primaryHabitIDByFriction[frictionProfile] == habit.id {
            score += 120
        }
        switch habit.cadence {
        case .daily:
            score += 8
        case .weekly:
            score += 4
        }
        if habit.reason.localizedCaseInsensitiveContains("easy")
            || habit.reason.localizedCaseInsensitiveContains("seconds")
            || habit.reason.localizedCaseInsensitiveContains("tiny")
            || habit.reason.localizedCaseInsensitiveContains("short") {
            score += 6
        }
        return score
    }

    private static func area(
        id: String,
        name: String,
        subtitle: String,
        icon: String,
        colorHex: String,
        aliases: [String],
        projects: [StarterProjectTemplate]
    ) -> StarterLifeAreaTemplate {
        StarterLifeAreaTemplate(
            id: id,
            name: name,
            subtitle: subtitle,
            icon: icon,
            colorHex: colorHex,
            aliases: aliases,
            projects: projects
        )
    }

    private static func project(
        id: String,
        lifeAreaID: String,
        name: String,
        summary: String,
        aliases: [String],
        tasks: [StarterTaskTemplate]
    ) -> StarterProjectTemplate {
        StarterProjectTemplate(
            id: id,
            lifeAreaTemplateID: lifeAreaID,
            name: name,
            summary: summary,
            aliases: aliases,
            taskTemplates: tasks
        )
    }

    private static func task(
        id: String,
        projectID: String,
        title: String,
        reason: String,
        minutes: Int,
        priority: TaskPriority = .low,
        type: TaskType,
        energy: TaskEnergy,
        category: TaskCategory,
        context: TaskContext,
        dueDateIntent: AddTaskPrefillDueIntent = .today,
        isQuickWin: Bool? = nil,
        clearDoneState: Bool = true,
        recommendedProfiles: [OnboardingFrictionProfile] = []
    ) -> StarterTaskTemplate {
        StarterTaskTemplate(
            id: id,
            projectTemplateID: projectID,
            title: title,
            reason: reason,
            durationMinutes: minutes,
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            dueDateIntent: dueDateIntent,
            isQuickWin: isQuickWin ?? (minutes <= 5),
            clearDoneState: clearDoneState,
            recommendedProfiles: Set(recommendedProfiles)
        )
    }

    private static func positiveHabit(
        id: String,
        lifeAreaID: String,
        projectID: String?,
        title: String,
        reason: String,
        cadence: HabitCadenceDraft,
        symbol: String,
        categoryKey: String,
        notes: String?,
        recommendedProfiles: [OnboardingFrictionProfile]
    ) -> StarterHabitTemplate {
        StarterHabitTemplate(
            id: id,
            lifeAreaTemplateID: lifeAreaID,
            projectTemplateID: projectID,
            title: title,
            reason: reason,
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: cadence,
            icon: HabitIconMetadata(symbolName: symbol, categoryKey: categoryKey),
            notes: notes,
            recommendedProfiles: Set(recommendedProfiles)
        )
    }

    private static func negativeHabit(
        id: String,
        lifeAreaID: String,
        projectID: String?,
        title: String,
        reason: String,
        cadence: HabitCadenceDraft,
        symbol: String,
        categoryKey: String,
        notes: String?,
        recommendedProfiles: [OnboardingFrictionProfile]
    ) -> StarterHabitTemplate {
        StarterHabitTemplate(
            id: id,
            lifeAreaTemplateID: lifeAreaID,
            projectTemplateID: projectID,
            title: title,
            reason: reason,
            kind: .negative,
            trackingMode: .dailyCheckIn,
            cadence: cadence,
            icon: HabitIconMetadata(symbolName: symbol, categoryKey: categoryKey),
            notes: notes,
            recommendedProfiles: Set(recommendedProfiles)
        )
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
            async let lifeAreasTask = fetchLifeAreas()
            async let projectsTask = fetchProjects()
            async let tasksTask = fetchTasks()
            let lifeAreas = try await lifeAreasTask
            let projects = try await projectsTask
            let tasks = try await tasksTask
            snapshot = OnboardingWorkspaceSnapshot(
                customLifeAreaCount: lifeAreas.filter(StarterWorkspaceCatalog.isCustomLifeArea).count,
                customProjectCount: projects.filter(StarterWorkspaceCatalog.isCustomProject).count,
                taskCount: tasks.count
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
            title: "Your first tiny win is ready",
            message: "Finish \"\(task.title)\" to lock in the first-session momentum loop."
        )
    }

    func showHabitGuide(habit: HabitDefinitionRecord) {
        state = State(
            taskID: habit.id,
            title: "Your starter habit is ready",
            message: "\"\(habit.title)\" will show up on Home so tomorrow feels easier to start."
        )
    }

    func clear() {
        state = nil
    }
}

@MainActor
final class OnboardingFeedbackController {
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let successGenerator = UINotificationFeedbackGenerator()
    private var hapticEngine: CHHapticEngine?

    func prepare() {
        selectionGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
        successGenerator.prepare()
        prepareEngineIfNeeded()
    }

    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func light() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    func medium() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    func successSignature() {
        guard playSuccessPattern() == false else { return }
        successGenerator.notificationOccurred(.success)
        successGenerator.prepare()
    }

    private func prepareEngineIfNeeded() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if hapticEngine == nil {
            hapticEngine = try? CHHapticEngine()
            try? hapticEngine?.start()
        }
    }

    private func playSuccessPattern() -> Bool {
        prepareEngineIfNeeded()
        guard let hapticEngine else { return false }
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.12
            )
        ]
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }
}

@MainActor
final class OnboardingFlowModel: ObservableObject {
    private let stateStore: AppOnboardingStateStore
    private let notificationService: NotificationServiceProtocol?
    private let fetchLifeAreas: () async throws -> [LifeArea]
    private let fetchProjects: () async throws -> [Project]
    private let fetchHabit: (UUID) async throws -> HabitDefinitionRecord?
    private let fetchTask: (UUID) async throws -> TaskDefinition?
    private let createLifeArea: (StarterLifeAreaTemplate) async throws -> LifeArea
    private let createProject: (OnboardingProjectDraft, LifeArea) async throws -> Project
    private let createHabit: (CreateHabitRequest) async throws -> HabitDefinitionRecord
    private let createTask: (CreateTaskDefinitionRequest) async throws -> TaskDefinition
    private let setTaskCompletion: (UUID, Bool) async throws -> TaskDefinition

    @Published var step: OnboardingStep = .welcome
    @Published var mode: OnboardingMode = .guided
    @Published private(set) var entryContext: OnboardingEntryContext = .freshFlow
    @Published var frictionProfile: OnboardingFrictionProfile?
    @Published var selectedLifeAreaIDs: Set<String> = []
    @Published var showAllLifeAreas = false
    @Published var projectDrafts: [OnboardingProjectDraft] = []
    @Published var expandedProjectIDs: Set<UUID> = []
    @Published var reminderPromptDismissed = false
    @Published private(set) var resolvedLifeAreas: [ResolvedLifeAreaSelection] = []
    @Published private(set) var resolvedProjects: [ResolvedProjectSelection] = []
    @Published private(set) var createdHabits: [HabitDefinitionRecord] = []
    @Published private(set) var createdHabitTemplateMap: [String: UUID] = [:]
    @Published private(set) var habitTemplateStates: [String: OnboardingHabitTemplateState] = [:]
    @Published private(set) var createdTasks: [TaskDefinition] = []
    @Published private(set) var createdTaskTemplateMap: [String: UUID] = [:]
    @Published private(set) var taskTemplateStates: [String: OnboardingTaskTemplateState] = [:]
    @Published private(set) var focusTaskID: UUID?
    @Published private(set) var parentFocusTaskID: UUID?
    @Published private(set) var focusStartedAt: Date?
    @Published private(set) var focusIsActive = false
    @Published private(set) var successSummary: AppOnboardingSummary?
    @Published var reminderPromptState: OnboardingReminderPromptState = .hidden
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var breakdownSteps: [OnboardingBreakdownStep] = []
    @Published var breakdownSheetPresented = false
    @Published var breakdownIsLoading = false
    @Published var breakdownRouteBanner: String?

    private var lastReminderPromptState: OnboardingReminderPromptState = .hidden

    init(
        stateStore: AppOnboardingStateStore = .shared,
        notificationService: NotificationServiceProtocol? = nil,
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
        }
    ) {
        self.stateStore = stateStore
        self.notificationService = notificationService
        self.fetchLifeAreas = fetchLifeAreas
        self.fetchProjects = fetchProjects
        self.fetchHabit = fetchHabit
        self.fetchTask = fetchTask
        self.createLifeArea = createLifeArea
        self.createProject = createProject
        self.createHabit = createHabit
        self.createTask = createTask
        self.setTaskCompletion = setTaskCompletion
        applyDefaults(mode: .guided, frictionProfile: nil)
    }

    var visibleLifeAreas: [StarterLifeAreaTemplate] {
        StarterWorkspaceCatalog.visibleLifeAreas(for: frictionProfile, showAll: showAllLifeAreas)
    }

    var selectedLifeAreas: [StarterLifeAreaTemplate] {
        StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile)
            .filter { selectedLifeAreaIDs.contains($0.id) }
    }

    var selectedProjectDrafts: [OnboardingProjectDraft] {
        Dictionary(grouping: projectDrafts.filter(\.isSelected), by: \.lifeAreaTemplateID)
            .values
            .compactMap { drafts in
                drafts.first
            }
            .sorted { lhs, rhs in
                let orderedAreaIDs = StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile).map(\.id)
                let lhsIndex = orderedAreaIDs.firstIndex(of: lhs.lifeAreaTemplateID) ?? 0
                let rhsIndex = orderedAreaIDs.firstIndex(of: rhs.lifeAreaTemplateID) ?? 0
                return lhsIndex < rhsIndex
            }
    }

    var primaryTaskSuggestions: [StarterTaskTemplate] {
        Array(taskSuggestions.prefix(2))
    }

    var secondaryTaskSuggestions: [StarterTaskTemplate] {
        Array(taskSuggestions.dropFirst(2).prefix(4))
    }

    var taskSuggestions: [StarterTaskTemplate] {
        let sourceProjects = resolvedProjects.isEmpty
            ? selectedProjectDrafts.compactMap { draft in
                StarterWorkspaceCatalog.projectTemplate(id: draft.templateID).map { _ in
                    ResolvedProjectSelection(
                        draft: draft,
                        project: Project(name: draft.name),
                        reusedExisting: false
                    )
                }
            }
            : resolvedProjects
        return StarterWorkspaceCatalog.taskSuggestions(for: sourceProjects, frictionProfile: frictionProfile)
    }

    var habitSuggestions: [StarterHabitTemplate] {
        let sourceProjects = resolvedProjects.isEmpty
            ? selectedProjectDrafts.compactMap { draft in
                StarterWorkspaceCatalog.projectTemplate(id: draft.templateID).map { _ in
                    ResolvedProjectSelection(
                        draft: draft,
                        project: Project(lifeAreaID: resolvedLifeAreas.first(where: { $0.templateID == draft.lifeAreaTemplateID })?.lifeArea.id, name: draft.name),
                        reusedExisting: false
                    )
                }
            }
            : resolvedProjects
        return StarterWorkspaceCatalog.habitSuggestions(for: sourceProjects, frictionProfile: frictionProfile)
    }

    var primaryHabitSuggestions: [StarterHabitTemplate] {
        Array(habitSuggestions.filter(\.isPositive).prefix(1))
    }

    var secondaryHabitSuggestions: [StarterHabitTemplate] {
        Array(habitSuggestions.filter(\.isPositive).dropFirst(primaryHabitSuggestions.count).prefix(4))
    }

    var negativeHabitSuggestion: StarterHabitTemplate? {
        habitSuggestions.first(where: { $0.isPositive == false })
    }

    var canAddMoreHabits: Bool {
        createdHabits.count < 2
    }

    var canContinueLifeAreas: Bool {
        (1...3).contains(selectedLifeAreaIDs.count)
    }

    var canContinueProjects: Bool {
        selectedProjectDrafts.isEmpty == false
    }

    var canContinueToFocus: Bool {
        createdTasks.isEmpty == false
    }

    var canGoBack: Bool {
        successSummary == nil && step != .welcome
    }

    var focusTask: TaskDefinition? {
        guard let focusTaskID else { return nil }
        return createdTasks.first(where: { $0.id == focusTaskID })
    }

    var parentFocusTask: TaskDefinition? {
        guard let parentFocusTaskID else { return nil }
        return createdTasks.first(where: { $0.id == parentFocusTaskID })
    }

    var nextOpenTask: TaskDefinition? {
        if let parentFocusTask, parentFocusTask.isComplete == false {
            return parentFocusTask
        }
        return createdTasks.first(where: { task in
            task.isComplete == false && task.id != focusTaskID
        })
    }

    var preferredComposerProject: Project? {
        if let firstResolved = resolvedProjects.first {
            return firstResolved.project
        }
        return nil
    }

    var allowsShowAllAreas: Bool {
        StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile).count > StarterWorkspaceCatalog.coreLifeAreaIDs.count
    }

    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        guard let index = OnboardingStep.orderedFlow.firstIndex(of: step),
              index + 1 < OnboardingStep.orderedFlow.count else {
            return nil
        }
        return OnboardingStep.orderedFlow[index + 1]
    }

    private func previousStep(before step: OnboardingStep) -> OnboardingStep? {
        guard let index = OnboardingStep.orderedFlow.firstIndex(of: step),
              index > 0 else {
            return nil
        }
        return OnboardingStep.orderedFlow[index - 1]
    }

    func prepareForPresentation(snapshot: OnboardingJourneySnapshot?) {
        errorMessage = nil
        reminderPromptState = .hidden
        lastReminderPromptState = .hidden
        breakdownSheetPresented = false
        breakdownSteps = []
        breakdownIsLoading = false
        breakdownRouteBanner = nil

        guard let snapshot else {
            applyDefaults(mode: .guided, frictionProfile: frictionProfile)
            entryContext = .freshFlow
            step = .welcome
            successSummary = nil
            persistJourney()
            return
        }

        let normalizedSelectedLifeAreaIDs = snapshot.selectedLifeAreaIDs.map(StarterWorkspaceCatalog.normalizeLifeAreaTemplateID)
        let normalizedProjectDrafts = snapshot.projectDrafts.map(StarterWorkspaceCatalog.normalizedProjectDraft)
        let normalizedResolvedLifeAreas = snapshot.resolvedLifeAreas.map(StarterWorkspaceCatalog.normalizedLifeAreaSelection)
        let normalizedResolvedProjects = snapshot.resolvedProjects.map(StarterWorkspaceCatalog.normalizedProjectSelection)
        let normalizedHabitTemplateMap = StarterWorkspaceCatalog.normalizedHabitTemplateMap(snapshot.createdHabitTemplateMap)
        let normalizedTaskTemplateMap = StarterWorkspaceCatalog.normalizedTaskTemplateMap(snapshot.createdTaskTemplateMap)

        step = snapshot.step
        mode = snapshot.mode
        entryContext = snapshot.entryContext
        frictionProfile = snapshot.frictionProfile
        selectedLifeAreaIDs = Set(normalizedSelectedLifeAreaIDs)
        showAllLifeAreas = snapshot.showAllLifeAreas
        projectDrafts = normalizedProjectDrafts
        expandedProjectIDs = Set(snapshot.expandedProjectIDs)
        reminderPromptDismissed = snapshot.reminderPromptDismissed
        resolvedLifeAreas = normalizedResolvedLifeAreas
        resolvedProjects = normalizedResolvedProjects
        createdHabits = snapshot.createdHabits
        createdHabitTemplateMap = normalizedHabitTemplateMap
        habitTemplateStates = normalizedHabitTemplateMap.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = .created(entry.value)
        }
        createdTasks = snapshot.createdTasks
        createdTaskTemplateMap = normalizedTaskTemplateMap
        taskTemplateStates = normalizedTaskTemplateMap.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = .created(entry.value)
        }
        focusTaskID = snapshot.focusTaskID
        parentFocusTaskID = snapshot.parentFocusTaskID
        focusStartedAt = snapshot.focusStartedAt
        focusIsActive = snapshot.focusIsActive
        successSummary = snapshot.successSummary
        if snapshot.hasSeenSuccess {
            notificationService?.fetchAuthorizationStatus { [weak self] status in
                self?.applyReminderPromptState(for: status)
            }
        }
    }

    func resetForReplay() {
        step = .welcome
        mode = .guided
        entryContext = .freshFlow
        frictionProfile = nil
        selectedLifeAreaIDs = []
        showAllLifeAreas = false
        projectDrafts = []
        resolvedLifeAreas = []
        resolvedProjects = []
        createdHabits = []
        createdHabitTemplateMap = [:]
        habitTemplateStates = [:]
        createdTasks = []
        createdTaskTemplateMap = [:]
        taskTemplateStates = [:]
        focusTaskID = nil
        parentFocusTaskID = nil
        focusStartedAt = nil
        focusIsActive = false
        successSummary = nil
        reminderPromptState = .hidden
        reminderPromptDismissed = false
        expandedProjectIDs = []
        lastReminderPromptState = .hidden
        breakdownSteps = []
        breakdownSheetPresented = false
        breakdownIsLoading = false
        breakdownRouteBanner = nil
        errorMessage = nil
        stateStore.clearJourney()
    }

    func selectFriction(_ profile: OnboardingFrictionProfile) {
        let nextProfile = frictionProfile == profile ? nil : profile
        frictionProfile = nextProfile
        if let nextProfile {
            logOnboardingInfo(event: "friction_type_selected", fields: ["profile": nextProfile.rawValue])
        }
        if step == .blocker, entryContext == .freshFlow {
            applyDefaults(mode: mode, frictionProfile: frictionProfile)
            clearDownstreamState()
        }
        persistJourney()
    }

    func begin(mode: OnboardingMode) {
        self.mode = mode
        entryContext = .freshFlow
        applyDefaults(mode: mode, frictionProfile: frictionProfile)
        clearDownstreamState()
        step = .blocker
        errorMessage = nil
        persistJourney()
    }

    func continueFromBlocker() {
        step = .lifeAreas
        errorMessage = nil
        persistJourney()
    }

    func skipBlocker() {
        frictionProfile = nil
        if entryContext == .freshFlow {
            applyDefaults(mode: mode, frictionProfile: nil)
            clearDownstreamState()
        }
        continueFromBlocker()
    }

    func toggleLifeArea(_ templateID: String) {
        if selectedLifeAreaIDs.contains(templateID) {
            selectedLifeAreaIDs.remove(templateID)
        } else if selectedLifeAreaIDs.count < 3 {
            selectedLifeAreaIDs.insert(templateID)
        }

        var nextDrafts = projectDrafts.filter { selectedLifeAreaIDs.contains($0.lifeAreaTemplateID) }
        let existingAreaIDs = Set(nextDrafts.map(\.lifeAreaTemplateID))
        let selectedIDsInOrder = StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile)
            .map(\.id)
            .filter { selectedLifeAreaIDs.contains($0) }
        let missingAreas = selectedIDsInOrder.filter { existingAreaIDs.contains($0) == false }
        nextDrafts.append(
            contentsOf: StarterWorkspaceCatalog.defaultProjectDrafts(
                for: missingAreas,
                frictionProfile: frictionProfile,
                mode: mode
            )
        )
        projectDrafts = nextDrafts
        errorMessage = nil
        persistJourney()
    }

    func showAllAreas() {
        showAllLifeAreas = true
        persistJourney()
    }

    func continueFromLifeAreas() async {
        guard canContinueLifeAreas else {
            errorMessage = "Pick 1 to 3 life areas to continue."
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let existingLifeAreas = try await fetchLifeAreas().filter { $0.isArchived == false }
            var selections: [ResolvedLifeAreaSelection] = []
            for template in selectedLifeAreas {
                if let existing = StarterWorkspaceCatalog.matchingLifeArea(for: template, in: existingLifeAreas + selections.map(\.lifeArea)) {
                    selections.append(
                        ResolvedLifeAreaSelection(templateID: template.id, lifeArea: existing, reusedExisting: true)
                    )
                } else {
                    let created = try await createLifeArea(template)
                    selections.append(
                        ResolvedLifeAreaSelection(templateID: template.id, lifeArea: created, reusedExisting: false)
                    )
                }
            }
            resolvedLifeAreas = selections
            projectDrafts = mergedProjectDrafts(for: selections.map(\.templateID))
            clearProjectsAndTasks()
            step = .projects
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleProjectDraft(_ draftID: UUID) {
        guard let index = projectDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        projectDrafts[index].isSelected.toggle()
        errorMessage = nil
        persistJourney()
    }

    func toggleProjectEditExpansion(_ draftID: UUID) {
        if expandedProjectIDs.contains(draftID) {
            expandedProjectIDs.remove(draftID)
        } else {
            expandedProjectIDs.insert(draftID)
            logOnboardingInfo(event: "project_edit_expanded", fields: ["draft_id": draftID.uuidString])
        }
        persistJourney()
    }

    func renameProjectDraft(_ draftID: UUID, to name: String) {
        guard let index = projectDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        projectDrafts[index].name = name
        persistJourney()
    }

    func cycleProjectSuggestion(_ draftID: UUID) {
        guard let index = projectDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        var draft = projectDrafts[index]
        guard draft.suggestionTemplateIDs.isEmpty == false else { return }
        draft.suggestionIndex = (draft.suggestionIndex + 1) % draft.suggestionTemplateIDs.count
        draft.templateID = draft.suggestionTemplateIDs[draft.suggestionIndex]
        if let template = StarterWorkspaceCatalog.projectTemplate(id: draft.templateID) {
            draft.name = template.name
            draft.summary = template.summary
        }
        projectDrafts[index] = draft
        persistJourney()
    }

    func selectProjectSuggestion(_ draftID: UUID, templateID: String) {
        guard let index = projectDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        guard let templateIndex = projectDrafts[index].suggestionTemplateIDs.firstIndex(of: templateID) else { return }
        var draft = projectDrafts[index]
        draft.templateID = templateID
        draft.suggestionIndex = templateIndex
        if let template = StarterWorkspaceCatalog.projectTemplate(id: templateID) {
            draft.name = template.name
            draft.summary = template.summary
        }
        projectDrafts[index] = draft
        persistJourney()
    }

    func continueFromProjects() async {
        guard canContinueProjects else {
            errorMessage = "Keep at least one starter project to continue."
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let existingProjects = try await fetchProjects().filter { $0.isArchived == false }
            let lifeAreasByTemplate = Dictionary(uniqueKeysWithValues: resolvedLifeAreas.map { ($0.templateID, $0.lifeArea) })
            var selections: [ResolvedProjectSelection] = []
            for draft in selectedProjectDrafts {
                guard let lifeArea = lifeAreasByTemplate[draft.lifeAreaTemplateID] else { continue }
                if let existing = StarterWorkspaceCatalog.matchingProject(for: draft, lifeAreaID: lifeArea.id, in: existingProjects + selections.map(\.project)) {
                    selections.append(
                        ResolvedProjectSelection(draft: draft, project: existing, reusedExisting: true)
                    )
                } else {
                    let created = try await createProject(draft, lifeArea)
                    selections.append(
                        ResolvedProjectSelection(draft: draft, project: created, reusedExisting: false)
                    )
                }
            }
            resolvedProjects = selections
            clearHabitsAndTasks()
            step = .firstTask
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareEstablishedWorkspaceEntry() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let existingLifeAreas = try await fetchLifeAreas().filter { $0.isArchived == false }
            let existingProjects = try await fetchProjects().filter { $0.isArchived == false && $0.isInbox == false && $0.isDefault == false }

            let matchedAreas = StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile)
                .compactMap { template -> ResolvedLifeAreaSelection? in
                    guard let existing = StarterWorkspaceCatalog.matchingLifeArea(for: template, in: existingLifeAreas) else {
                        return nil
                    }
                    return ResolvedLifeAreaSelection(templateID: template.id, lifeArea: existing, reusedExisting: true)
                }

            let selectedAreas = Array(matchedAreas.prefix(3))
            guard selectedAreas.isEmpty == false else {
                step = .welcome
                persistJourney()
                return
            }

            let selectedAreaIDs = selectedAreas.map(\.templateID)
            let resolvedProjectSelections: [ResolvedProjectSelection] = selectedAreas.compactMap { selection in
                guard let areaTemplate = StarterWorkspaceCatalog.lifeAreaTemplate(id: selection.templateID) else { return nil }
                let defaultDraft = StarterWorkspaceCatalog.defaultProjectDrafts(
                    for: [selection.templateID],
                    frictionProfile: frictionProfile,
                    mode: .guided
                ).first
                let candidates = existingProjects.filter { $0.lifeAreaID == selection.lifeArea.id }
                let fallbackProject = candidates.first
                let matchedProject = defaultDraft.flatMap { draft in
                    StarterWorkspaceCatalog.matchingProject(for: draft, lifeAreaID: selection.lifeArea.id, in: candidates)
                } ?? fallbackProject
                guard let project = matchedProject else { return nil }

                let matchedTemplateID = areaTemplate.projects.first(where: { template in
                    let candidateNames = Set(([template.name] + template.aliases).map(StarterWorkspaceCatalog.normalizedName))
                    return candidateNames.contains(StarterWorkspaceCatalog.normalizedName(project.name))
                })?.id ?? areaTemplate.projects.first?.id ?? defaultDraft?.templateID ?? ""
                guard matchedTemplateID.isEmpty == false else { return nil }

                let template = StarterWorkspaceCatalog.projectTemplate(id: matchedTemplateID)
                let draft = OnboardingProjectDraft(
                    lifeAreaTemplateID: selection.templateID,
                    templateID: matchedTemplateID,
                    name: project.name,
                    summary: template?.summary ?? project.projectDescription ?? "Starter project",
                    suggestionTemplateIDs: areaTemplate.projects.map(\.id),
                    suggestionIndex: max(0, areaTemplate.projects.firstIndex(where: { $0.id == matchedTemplateID }) ?? 0),
                    isSelected: true
                )
                return ResolvedProjectSelection(draft: draft, project: project, reusedExisting: true)
            }

            mode = .guided
            entryContext = .establishedWorkspace
            selectedLifeAreaIDs = Set(selectedAreaIDs)
            showAllLifeAreas = false
            resolvedLifeAreas = selectedAreas
            projectDrafts = resolvedProjectSelections.map(\.draft)
            resolvedProjects = resolvedProjectSelections
            createdHabits = []
            createdHabitTemplateMap = [:]
            habitTemplateStates = [:]
            clearTasksAndFocus()
            step = .blocker
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSuggestedHabit(_ template: StarterHabitTemplate) async {
        if case .creating = habitTemplateStates[template.id] {
            return
        }
        if case .created = habitTemplateStates[template.id] {
            return
        }
        guard canAddMoreHabits else {
            errorMessage = "Keep the starter setup light. Add up to two habits for now."
            return
        }
        guard let resolvedLifeArea = resolvedLifeAreas.first(where: { $0.templateID == template.lifeAreaTemplateID }) else {
            habitTemplateStates[template.id] = .failed("Tasker could not find that life area.")
            return
        }

        habitTemplateStates[template.id] = .creating
        errorMessage = nil
        defer { if case .creating = habitTemplateStates[template.id] { habitTemplateStates[template.id] = .idle } }

        let projectID = template.projectTemplateID.flatMap { projectTemplateID in
            resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.id
        }

        do {
            let createdHabit = try await createHabit(template.makeRequest(lifeAreaID: resolvedLifeArea.lifeArea.id, projectID: projectID))
            upsertCreatedHabit(createdHabit)
            createdHabitTemplateMap[template.id] = createdHabit.id
            habitTemplateStates[template.id] = .created(createdHabit.id)
            persistJourney()
        } catch {
            let message = error.localizedDescription
            habitTemplateStates[template.id] = .failed(message)
            errorMessage = message
        }
    }

    func registerCustomCreatedHabit(habitID: UUID) async {
        do {
            guard let habit = try await fetchHabit(habitID) else { return }
            upsertCreatedHabit(habit)
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func continueFromHabits() {
        step = .focusRoom
        errorMessage = nil
        persistJourney()
    }

    func addSuggestedTask(_ template: StarterTaskTemplate) async {
        if case .creating = taskTemplateStates[template.id] {
            return
        }
        if case .created = taskTemplateStates[template.id] {
            return
        }

        taskTemplateStates[template.id] = .creating
        errorMessage = nil
        defer { if case .creating = taskTemplateStates[template.id] { taskTemplateStates[template.id] = .idle } }

        guard let resolvedProject = resolvedProjects.first(where: { $0.draft.templateID == template.projectTemplateID }) else {
            taskTemplateStates[template.id] = .failed("Tasker could not find that project.")
            return
        }

        do {
            let createdTask = try await createTask(template.makeRequest(project: resolvedProject.project))
            upsertCreatedTask(createdTask)
            createdTaskTemplateMap[template.id] = createdTask.id
            taskTemplateStates[template.id] = .created(createdTask.id)
            if focusTaskID == nil {
                focusTaskID = createdTask.id
            }
            persistJourney()
        } catch {
            let message = error.localizedDescription
            taskTemplateStates[template.id] = .failed(message)
            errorMessage = message
        }
    }

    func registerCustomCreatedTask(taskID: UUID) async {
        do {
            guard let task = try await fetchTask(taskID) else { return }
            upsertCreatedTask(task)
            if focusTaskID == nil {
                focusTaskID = task.id
            }
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshCreatedTask(taskID: UUID) async {
        do {
            guard let task = try await fetchTask(taskID) else {
                createdTasks.removeAll(where: { $0.id == taskID })
                createdTaskTemplateMap = createdTaskTemplateMap.filter { $0.value != taskID }
                if focusTaskID == taskID {
                    focusTaskID = createdTasks.first(where: { $0.isComplete == false })?.id
                    if focusTaskID == nil {
                        step = .firstTask
                    }
                }
                persistJourney()
                return
            }
            upsertCreatedTask(task)
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func continueFromFirstTask() {
        guard canContinueToFocus else { return }
        focusTaskID = createdTasks.first(where: { $0.isComplete == false })?.id ?? createdTasks.first?.id
        step = .habits
        errorMessage = nil
        persistJourney()
    }

    func startFocusNow() {
        focusIsActive = true
        if focusStartedAt == nil {
            focusStartedAt = Date()
        }
        logOnboardingInfo(event: "focus_mode_started")
        persistJourney()
    }

    func completeFocusTask() async {
        guard let focusTaskID else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let completed = try await setTaskCompletion(focusTaskID, true)
            upsertCreatedTask(completed)
            focusIsActive = false
            focusStartedAt = nil
            successSummary = buildSummary(completedTask: completed)
            await refreshReminderPromptState()
            successSummary = buildSummary(completedTask: completed)
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateBreakdownSuggestions() async {
        guard let focusTask else { return }
        logOnboardingInfo(event: "ai_breakdown_used")
        let service = TaskBreakdownService.shared
        let immediate = service.immediateHeuristicSteps(
            taskTitle: focusTask.title,
            taskDetails: focusTask.details,
            projectName: projectName(for: focusTask)
        )
        breakdownSteps = immediate.steps.enumerated().map { index, step in
            OnboardingBreakdownStep(title: step, isSelected: index == 0)
        }
        breakdownRouteBanner = immediate.routeBanner
        breakdownSheetPresented = true
        breakdownIsLoading = true

        let refined = await service.refine(
            taskTitle: focusTask.title,
            taskDetails: focusTask.details,
            projectName: projectName(for: focusTask)
        )
        let selectedTitles = Set(breakdownSteps.filter(\.isSelected).map { StarterWorkspaceCatalog.normalizedName($0.title) })
        breakdownSteps = refined.steps.enumerated().map { index, step in
            let normalized = StarterWorkspaceCatalog.normalizedName(step)
            return OnboardingBreakdownStep(
                title: step,
                isSelected: selectedTitles.contains(normalized) || (selectedTitles.isEmpty && index == 0)
            )
        }
        breakdownRouteBanner = refined.routeBanner ?? breakdownRouteBanner
        breakdownIsLoading = false
    }

    func toggleBreakdownStep(_ stepID: UUID) {
        guard let index = breakdownSteps.firstIndex(where: { $0.id == stepID }) else { return }
        breakdownSteps[index].isSelected.toggle()
    }

    func applySelectedBreakdownSteps() async {
        guard let focusTask, let project = project(for: focusTask) else { return }
        let selected = breakdownSteps.filter(\.isSelected)
        guard selected.isEmpty == false else {
            errorMessage = "Select at least one smaller step."
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            var createdChildren: [TaskDefinition] = []
            for item in selected {
                let request = CreateTaskDefinitionRequest(
                    title: item.title,
                    details: nil,
                    projectID: project.id,
                    projectName: project.name,
                    lifeAreaID: project.lifeAreaID,
                    dueDate: focusTask.dueDate ?? DatePreset.today.resolvedDueDate(),
                    parentTaskID: focusTask.id,
                    priority: .low,
                    type: focusTask.type,
                    energy: .low,
                    category: focusTask.category,
                    context: focusTask.context,
                    estimatedDuration: 60,
                    createdAt: Date()
                )
                let child = try await createTask(request)
                createdChildren.append(child)
                upsertCreatedTask(child)
            }

            parentFocusTaskID = focusTask.id
            focusTaskID = createdChildren.first?.id
            focusStartedAt = nil
            focusIsActive = false
            breakdownSheetPresented = false
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func breakDownNextTask() async {
        guard let nextOpenTask else { return }
        focusTaskID = nextOpenTask.id
        successSummary = nil
        step = .focusRoom
        persistJourney()
        await generateBreakdownSuggestions()
    }

    func continueWithNextTask() {
        guard let nextOpenTask else { return }
        focusTaskID = nextOpenTask.id
        focusIsActive = false
        focusStartedAt = nil
        successSummary = nil
        step = .focusRoom
        persistJourney()
    }

    func refreshReminderPromptState() async {
        guard successSummary != nil, let notificationService else {
            reminderPromptState = .hidden
            persistJourney()
            return
        }
        if reminderPromptDismissed {
            reminderPromptState = .hidden
            persistJourney()
            return
        }

        let status = await notificationService.fetchAuthorizationStatusAsync()
        applyReminderPromptState(for: status)
    }

    func handleReminderPrimaryAction() async {
        guard reminderPromptState == .prompt, let notificationService else { return }
        let granted = await notificationService.requestPermissionAsync()
        logOnboardingInfo(
            event: "reminder_prompt_accepted",
            fields: ["granted": String(granted)]
        )
        await refreshReminderPromptState()
    }

    func dismissReminderPrompt() {
        reminderPromptDismissed = true
        reminderPromptState = .hidden
        logOnboardingInfo(event: "reminder_prompt_declined")
        persistJourney()
    }

    private func applyReminderPromptState(for status: TaskerNotificationAuthorizationStatus) {
        switch status {
        case .notDetermined:
            reminderPromptState = .prompt
        case .denied:
            reminderPromptState = .openSettings
        case .authorized, .provisional, .ephemeral:
            reminderPromptState = .hidden
        }

        if reminderPromptState != .hidden, reminderPromptState != lastReminderPromptState {
            logOnboardingInfo(
                event: "reminder_prompt_shown",
                fields: ["state": String(describing: reminderPromptState)]
            )
        }
        lastReminderPromptState = reminderPromptState
        persistJourney()
    }

    func finishOnboarding() {
        stateStore.markHandled(outcome: .completed)
    }

    func skipToFocusRoom() async {
        mode = .guided
        applyDefaults(mode: .guided, frictionProfile: frictionProfile)
        await continueFromLifeAreas()
        guard errorMessage == nil else { return }
        await continueFromProjects()
        guard errorMessage == nil else { return }
        guard let firstTemplate = primaryTaskSuggestions.first ?? taskSuggestions.first,
              let resolvedProject = resolvedProjects.first(where: { $0.draft.templateID == firstTemplate.projectTemplateID })
        else {
            errorMessage = "Tasker could not build a starter task right now."
            return
        }

        do {
            let createdTask = try await createTask(firstTemplate.makeRequest(project: resolvedProject.project))
            upsertCreatedTask(createdTask)
            createdTaskTemplateMap[firstTemplate.id] = createdTask.id
            taskTemplateStates[firstTemplate.id] = .created(createdTask.id)
            focusTaskID = createdTask.id
            step = .focusRoom
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goBack() {
        errorMessage = nil
        if successSummary != nil {
            successSummary = nil
            step = .focusRoom
            persistJourney()
            return
        }

        if let previous = previousStep(before: step) {
            step = previous
        }
        persistJourney()
    }

    private func applyDefaults(mode: OnboardingMode, frictionProfile: OnboardingFrictionProfile?) {
        let selection = StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: frictionProfile, mode: mode)
        selectedLifeAreaIDs = Set(selection)
        projectDrafts = StarterWorkspaceCatalog.defaultProjectDrafts(
            for: selection,
            frictionProfile: frictionProfile,
            mode: mode
        )
        expandedProjectIDs = []
        reminderPromptDismissed = false
        showAllLifeAreas = false
    }

    private func clearDownstreamState() {
        clearProjectsAndTasks()
        errorMessage = nil
    }

    private func clearProjectsAndTasks() {
        resolvedProjects = []
        clearHabitsAndTasks()
    }

    private func clearHabitsAndTasks() {
        createdHabits = []
        createdHabitTemplateMap = [:]
        habitTemplateStates = [:]
        clearTasksAndFocus()
    }

    private func clearTasksAndFocus() {
        createdTasks = []
        createdTaskTemplateMap = [:]
        taskTemplateStates = [:]
        focusTaskID = nil
        parentFocusTaskID = nil
        focusStartedAt = nil
        focusIsActive = false
        successSummary = nil
        reminderPromptState = .hidden
        reminderPromptDismissed = false
        expandedProjectIDs = []
        lastReminderPromptState = .hidden
        breakdownSteps = []
        breakdownSheetPresented = false
        breakdownIsLoading = false
        breakdownRouteBanner = nil
    }

    private func mergedProjectDrafts(for selectedTemplateIDs: [String]) -> [OnboardingProjectDraft] {
        let orderedSelections = StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile)
            .map(\.id)
            .filter { selectedTemplateIDs.contains($0) }
        let existingByArea = Dictionary(grouping: projectDrafts, by: \.lifeAreaTemplateID)
        var merged: [OnboardingProjectDraft] = []
        for areaID in orderedSelections {
            let draft = existingByArea[areaID]?.first(where: { $0.isSelected }) ?? existingByArea[areaID]?.first
            if let draft {
                merged.append(draft)
            } else {
                merged.append(
                    contentsOf: StarterWorkspaceCatalog.defaultProjectDrafts(
                        for: [areaID],
                        frictionProfile: frictionProfile,
                        mode: mode
                    )
                )
            }
        }
        return merged
    }

    private func upsertCreatedTask(_ task: TaskDefinition) {
        if let index = createdTasks.firstIndex(where: { $0.id == task.id }) {
            createdTasks[index] = task
        } else {
            createdTasks.append(task)
        }
    }

    private func upsertCreatedHabit(_ habit: HabitDefinitionRecord) {
        if let index = createdHabits.firstIndex(where: { $0.id == habit.id }) {
            createdHabits[index] = habit
        } else {
            createdHabits.append(habit)
        }
    }

    private func buildSummary(completedTask: TaskDefinition) -> AppOnboardingSummary {
        let completedCount = createdTasks.filter(\.isComplete).count
        let nextTaskTitle = nextOpenTask?.title
        return AppOnboardingSummary(
            lifeAreaCount: resolvedLifeAreas.count,
            projectCount: resolvedProjects.count,
            createdHabitCount: createdHabits.count,
            createdHabitTitles: createdHabits.map(\.title),
            createdTaskCount: createdTasks.count,
            completedTaskCount: completedCount,
            completedTaskTitle: completedTask.title,
            nextTaskTitle: nextTaskTitle,
            promptReminderAfterSuccess: reminderPromptState != .hidden
        )
    }

    private func persistJourney() {
        let snapshot = OnboardingJourneySnapshot(
            step: step,
            mode: mode,
            entryContext: entryContext,
            frictionProfile: frictionProfile,
            selectedLifeAreaIDs: StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile)
                .map(\.id)
                .filter { selectedLifeAreaIDs.contains($0) },
            showAllLifeAreas: showAllLifeAreas,
            projectDrafts: projectDrafts,
            expandedProjectIDs: Array(expandedProjectIDs),
            resolvedLifeAreas: resolvedLifeAreas,
            resolvedProjects: resolvedProjects,
            createdHabits: createdHabits,
            createdHabitTemplateMap: createdHabitTemplateMap,
            createdTasks: createdTasks,
            createdTaskTemplateMap: createdTaskTemplateMap,
            focusTaskID: focusTaskID,
            parentFocusTaskID: parentFocusTaskID,
            focusStartedAt: focusStartedAt,
            focusIsActive: focusIsActive,
            successSummary: successSummary,
            hasSeenSuccess: successSummary != nil,
            reminderPromptDismissed: reminderPromptDismissed
        )
        stateStore.storeJourney(snapshot)
    }

    private func project(for task: TaskDefinition) -> Project? {
        resolvedProjects.first(where: { $0.project.id == task.projectID })?.project
    }

    private func projectName(for task: TaskDefinition) -> String? {
        project(for: task)?.name ?? task.projectName
    }
}

@MainActor
protocol AppOnboardingHostAdapter: AnyObject {
    var currentOnboardingLayoutClass: TaskerLayoutClass { get }
    var presentedViewController: UIViewController? { get }

    func prepareForOnboardingHomeGuidance()
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?)
    func makeOnboardingAddTaskController(
        prefill: AddTaskPrefillTemplate,
        onTaskCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController?
    func makeOnboardingAddHabitController(
        prefill: AddHabitPrefillTemplate,
        onHabitCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController?
    func makeOnboardingTaskDetailController(
        task: TaskDefinition,
        onDismiss: @escaping () -> Void
    ) -> UIViewController?
}

extension HomeViewController: AppOnboardingHostAdapter {}

@MainActor
final class AppOnboardingCoordinator: NSObject {
    private weak var hostAdapter: (UIViewController & AppOnboardingHostAdapter)?
    private let presentationDependencyContainer: PresentationDependencyContainer
    private let guidanceModel: HomeOnboardingGuidanceModel
    private let stateStore: AppOnboardingStateStore
    private let eligibilityService: OnboardingEligibilityService
    private let notificationCenter: NotificationCenter
    private let feedbackController = OnboardingFeedbackController()

    private lazy var viewModel = OnboardingFlowModel(
        stateStore: stateStore,
        notificationService: EnhancedDependencyContainer.shared.notificationService,
        fetchLifeAreas: { [weak self] in
            guard let self else { return [] }
            return try await self.presentationDependencyContainer.coordinator.lifeAreaRepository.fetchAllAsync()
        },
        fetchProjects: { [weak self] in
            guard let self else { return [] }
            return try await self.presentationDependencyContainer.coordinator.projectRepository.fetchAllProjectsAsync()
        },
        fetchHabit: { [weak self] habitID in
            guard let self else { return nil }
            let habits = try await self.presentationDependencyContainer.coordinator.manageHabits.listAsync()
            return habits.first(where: { $0.id == habitID })
        },
        fetchTask: { [weak self] taskID in
            guard let self else { return nil }
            return try await self.presentationDependencyContainer.coordinator.taskDefinitionRepository.fetchTaskDefinitionAsync(id: taskID)
        },
        createLifeArea: { [weak self] template in
            guard let self else { return LifeArea(name: template.name, color: template.colorHex, icon: template.icon) }
            return try await self.presentationDependencyContainer.coordinator.manageLifeAreas.createAsync(
                name: template.name,
                color: template.colorHex,
                icon: template.icon
            )
        },
        createProject: { [weak self] draft, lifeArea in
            guard let self else { return Project(lifeAreaID: lifeArea.id, name: draft.name, projectDescription: draft.summary) }
            return try await self.presentationDependencyContainer.coordinator.manageProjects.createProjectAsync(
                request: CreateProjectRequest(
                    name: draft.name,
                    description: draft.summary,
                    lifeAreaID: lifeArea.id
                )
            )
        },
        createHabit: { [weak self] request in
            guard let self else {
                return HabitDefinitionRecord(
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
            }
            return try await self.presentationDependencyContainer.coordinator.createHabit.executeAsync(request: request)
        },
        createTask: { [weak self] request in
            guard let self else { return request.toTaskDefinition(projectName: request.projectName) }
            return try await self.presentationDependencyContainer.coordinator.createTaskDefinition.executeAsync(request: request)
        },
        setTaskCompletion: { [weak self] taskID, isComplete in
            guard let self else {
                var task = TaskDefinition(id: taskID, title: "Task")
                task.isComplete = isComplete
                task.dateCompleted = isComplete ? Date() : nil
                return task
            }
            return try await self.presentationDependencyContainer.coordinator.completeTaskDefinition.setCompletionAsync(taskID: taskID, to: isComplete)
        }
    )

    private var onboardingHost: UIHostingController<AnyView>?
    private var promptHost: UIHostingController<AnyView>?
    private var hasEvaluatedLaunch = false
    private var presentationQueue = OnboardingPresentationQueue()
    private var pendingPresentationWasBlocked = false

    init?(
        homeViewController: HomeViewController,
        presentationDependencyContainer: PresentationDependencyContainer?,
        guidanceModel: HomeOnboardingGuidanceModel,
        stateStore: AppOnboardingStateStore = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        guard let presentationDependencyContainer else { return nil }
        guard presentationDependencyContainer.isConfiguredForRuntime else { return nil }
        self.hostAdapter = homeViewController
        self.presentationDependencyContainer = presentationDependencyContainer
        self.guidanceModel = guidanceModel
        self.stateStore = stateStore
        self.notificationCenter = notificationCenter
        self.eligibilityService = OnboardingEligibilityService(
            stateStore: stateStore,
            lifeAreaRepository: presentationDependencyContainer.coordinator.lifeAreaRepository,
            projectRepository: presentationDependencyContainer.coordinator.projectRepository,
            taskRepository: presentationDependencyContainer.coordinator.taskDefinitionRepository
        )
        super.init()
    }

    func evaluateLaunchIfNeeded() {
        guard hasEvaluatedLaunch == false else { return }
        hasEvaluatedLaunch = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let state = self.stateStore.load()
            if state.hasHandledCurrentVersion == false, state.journeySnapshot != nil {
                self.enqueuePresentation(.fullFlow(source: "resume"))
                return
            }
            switch await self.eligibilityService.evaluate() {
            case .fullFlow:
                self.enqueuePresentation(.fullFlow(source: "launch_auto"))
            case .promptOnly(let snapshot):
                self.enqueuePresentation(.prompt(snapshot: snapshot))
            case .suppressed:
                break
            }
        }
    }

    func restartOnboarding() {
        stateStore.clear()
        viewModel.resetForReplay()
        guidanceModel.clear()
        presentationQueue = OnboardingPresentationQueue()
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
        let currentPending = presentationQueue.pending

        if currentPending == presentation,
           previousPending != presentation,
           isPresentationBlocked() {
            pendingPresentationWasBlocked = true
            logOnboardingInfo(
                event: "onboarding_presentation_queued",
                message: "Queued onboarding presentation until the host is free",
                fields: [
                    "presentation": presentation.analyticsLabel,
                    "blocked_by_presented_controller": String(hostAdapter?.presentedViewController != nil)
                ]
            )
        }

        drainPendingPresentationIfPossible()
    }

    @discardableResult
    private func attemptPresentation(_ presentation: PendingOnboardingPresentation, source: String) -> Bool {
        let presented: Bool
        switch presentation {
        case .prompt(let snapshot):
            presented = presentPromptIfPossible(snapshot: snapshot)
        case .fullFlow(let sourceLabel):
            presented = presentFullFlowIfPossible(source: sourceLabel)
        }

        if presented, pendingPresentationWasBlocked {
            pendingPresentationWasBlocked = false
            logOnboardingInfo(
                event: "onboarding_presentation_drained",
                message: "Presented queued onboarding surface",
                fields: [
                    "presentation": presentation.analyticsLabel,
                    "source": source
                ]
            )
        }
        return presented
    }

    private func presentPromptIfPossible(snapshot: OnboardingWorkspaceSnapshot) -> Bool {
        guard promptHost == nil else { return false }
        guard let hostAdapter, hostAdapter.presentedViewController == nil else { return false }

        let controller = UIHostingController(
            rootView: AnyView(
                AppOnboardingPromptSheetView(
                    snapshot: snapshot,
                    onStart: { [weak self] in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            await self.viewModel.prepareEstablishedWorkspaceEntry()
                            self.dismissPrompt(animated: true) {
                                self.enqueuePresentation(.fullFlow(source: "prompt_opt_in"))
                            }
                        }
                    },
                    onNotNow: { [weak self] in
                        self?.stateStore.markEstablishedWorkspacePromptDismissed()
                        self?.dismissPrompt(animated: true, completion: nil)
                    }
                )
                .taskerLayoutClass(hostAdapter.currentOnboardingLayoutClass)
            )
        )
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 30
        }
        promptHost = controller
        hostAdapter.present(controller, animated: true, completion: nil)
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
        guard onboardingHost == nil else { return false }
        guard let hostAdapter, hostAdapter.presentedViewController == nil else { return false }

        feedbackController.prepare()
        viewModel.prepareForPresentation(snapshot: stateStore.load().journeySnapshot)
        logOnboardingInfo(
            event: "onboarding_started",
            message: "Started ADHD-first onboarding flow",
            fields: ["source": source]
        )

        let rootView = AppOnboardingJourneyView(
            viewModel: viewModel,
            feedbackController: feedbackController,
            onOpenCustomTaskComposer: { [weak self] prefill in
                self?.presentCustomTaskComposer(prefill: prefill) ?? false
            },
            onOpenCustomHabitComposer: { [weak self] prefill in
                self?.presentCustomHabitComposer(prefill: prefill) ?? false
            },
            onEditTask: { [weak self] task in
                self?.presentTaskEditor(task: task) ?? false
            },
            onDismissFlow: { [weak self] in
                guard let self else { return }
                if self.viewModel.successSummary != nil,
                   let createdHabit = self.viewModel.createdHabits.first {
                    self.guidanceModel.showHabitGuide(habit: createdHabit)
                }
                self.dismissFullFlow(animated: true)
            }
        )
        .taskerLayoutClass(hostAdapter.currentOnboardingLayoutClass)

        let controller = UIHostingController(rootView: AnyView(rootView))
        controller.modalPresentationStyle = .fullScreen
        onboardingHost = controller
        hostAdapter.present(controller, animated: true, completion: nil)
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

    private func presentCustomTaskComposer(prefill: AddTaskPrefillTemplate) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = hostAdapter?.makeOnboardingAddTaskController(
            prefill: prefill,
            onTaskCreated: { [weak self] taskID in
                Task { @MainActor [weak self] in
                    await self?.viewModel.registerCustomCreatedTask(taskID: taskID)
                }
            },
            onDismissWithoutTask: nil
        ) else { return false }
        onboardingHost.present(controller, animated: true)
        return true
    }

    private func presentCustomHabitComposer(prefill: AddHabitPrefillTemplate) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = hostAdapter?.makeOnboardingAddHabitController(
            prefill: prefill,
            onHabitCreated: { [weak self] habitID in
                Task { @MainActor [weak self] in
                    await self?.viewModel.registerCustomCreatedHabit(habitID: habitID)
                }
            },
            onDismissWithoutTask: nil
        ) else { return false }
        onboardingHost.present(controller, animated: true)
        return true
    }

    private func presentTaskEditor(task: TaskDefinition) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = hostAdapter?.makeOnboardingTaskDetailController(
            task: task,
            onDismiss: { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.viewModel.refreshCreatedTask(taskID: task.id)
                }
            }
        ) else { return false }
        onboardingHost.present(controller, animated: true)
        return true
    }

    private func isPresentationBlocked() -> Bool {
        hostAdapter?.presentedViewController != nil
    }
}

struct AppOnboardingJourneyView: View {
    @ObservedObject var viewModel: OnboardingFlowModel
    let feedbackController: OnboardingFeedbackController
    let onOpenCustomTaskComposer: (AddTaskPrefillTemplate) -> Bool
    let onOpenCustomHabitComposer: (AddHabitPrefillTemplate) -> Bool
    let onEditTask: (TaskDefinition) -> Bool
    let onDismissFlow: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @State private var projectOptionsAreaID: String?
    @State private var showsMoreIdeas = false
    @State private var showsMoreHabitIdeas = false
    @State private var hasPlayedSuccess = false
    @State private var welcomeIntroPhase: WelcomeIntroPhase = .welcomeReady
    @State private var hasCompletedWelcomeIntro = false
    @State private var welcomeIntroRunID = UUID()

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var horizontalPadding: CGFloat {
        layoutClass.isPad ? 32 : spacing.screenHorizontal
    }

    private var contentWidth: CGFloat {
        layoutClass.isPad ? 1120 : .infinity
    }

    private var isEstablishedWorkspaceEntry: Bool {
        viewModel.entryContext == .establishedWorkspace
    }

    private var habitsTitle: String {
        isEstablishedWorkspaceEntry
            ? "Add one habit for tomorrow"
            : "Add one habit for tomorrow"
    }

    private var habitsSubtitle: String {
        isEstablishedWorkspaceEntry
            ? "Pick one now, or add one later."
            : "Pick one now, or add one later."
    }

    private var shouldShowWelcomeExperience: Bool {
        viewModel.successSummary == nil && viewModel.step == .welcome
    }

    private var isWelcomeIntroActive: Bool {
        shouldShowWelcomeExperience && welcomeIntroPhase.showsIntroOverlay
    }

    private var shouldShowWelcomeChrome: Bool {
        shouldShowWelcomeExperience && welcomeIntroPhase.showsWelcomeChrome
    }

    private var shouldShowBottomDock: Bool {
        guard isWelcomeIntroActive == false else { return false }
        return viewModel.successSummary != nil || viewModel.step != .focusRoom || viewModel.errorMessage != nil
    }

    private var onboardingBackdropMode: OnboardingCinematicBackdrop.Mode {
        if shouldShowWelcomeExperience {
            return .intro(welcomeIntroPhase)
        }
        return .steady
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            contentLayer
                .allowsHitTesting(isWelcomeIntroActive == false)

            if isWelcomeIntroActive {
                OnboardingWelcomeCinematicOverlay(
                    phase: welcomeIntroPhase,
                    onContinue: continueFromWelcomeIntro
                )
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeIntroOverlay)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if shouldShowBottomDock {
                bottomDock
            }
        }
        .sheet(isPresented: $viewModel.breakdownSheetPresented) {
            breakdownSheet
        }
        .sheet(
            isPresented: Binding(
                get: { projectOptionsAreaID != nil },
                set: { isPresented in
                    if isPresented == false {
                        projectOptionsAreaID = nil
                    }
                }
            )
        ) {
            if let areaID = projectOptionsAreaID,
               let area = StarterWorkspaceCatalog.lifeAreaTemplate(id: areaID),
               let draft = viewModel.projectDrafts.first(where: { $0.lifeAreaTemplateID == areaID }) {
                projectOptionsSheet(area: area, draft: draft)
            }
        }
        .interactiveDismissDisabled(true)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: viewModel.step)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: viewModel.successSummary != nil)
        .onAppear {
            feedbackController.prepare()
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.step) { _, _ in
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.successSummary != nil) { _, _ in
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.successSummary != nil) { _, isShowingSuccess in
            guard isShowingSuccess, hasPlayedSuccess == false else { return }
            hasPlayedSuccess = true
            feedbackController.successSignature()
        }
        .task(id: welcomeIntroRunID) {
            await runWelcomeIntroSequenceIfNeeded()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.flow)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        OnboardingCinematicBackdrop(
            mode: onboardingBackdropMode,
            includeWelcomeAccessibilityMarkers: shouldShowWelcomeExperience
        )
    }

    @ViewBuilder
    private var contentLayer: some View {
        if let summary = viewModel.successSummary {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing.sectionGap) {
                    successView(summary: summary)
                }
                .frame(maxWidth: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, spacing.s16)
                .padding(.bottom, 120)
            }
        } else if shouldShowWelcomeExperience {
            welcomeExperienceContent
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing.sectionGap) {
                    stepHeader
                    stepBody
                }
                .frame(maxWidth: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, spacing.s16)
                .padding(.bottom, 120)
            }
        }
    }

    private var welcomeExperienceContent: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            if shouldShowWelcomeChrome {
                stepHeader
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: spacing.s20)

            welcomeStep
                .frame(maxWidth: layoutClass.isPad ? 620 : .infinity)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, spacing.s16)
        .padding(.bottom, 120)
    }

    private func scheduleWelcomeIntroIfNeeded() {
        guard shouldShowWelcomeExperience else {
            welcomeIntroPhase = .welcomeReady
            return
        }

        if hasCompletedWelcomeIntro {
            welcomeIntroPhase = .welcomeReady
        } else {
            welcomeIntroRunID = UUID()
        }
    }

    private func runWelcomeIntroSequenceIfNeeded() async {
        guard shouldShowWelcomeExperience, hasCompletedWelcomeIntro == false else { return }

        if reduceMotion {
            await MainActor.run {
                welcomeIntroPhase = .introVideoOnly
            }

            guard await sleepIfNeeded(milliseconds: 2500) else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.36)) {
                    welcomeIntroPhase = .introCardHold
                }
            }

            guard await sleepIfNeeded(milliseconds: 2000) else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.24)) {
                    welcomeIntroPhase = .introCTAReady
                }
            }
            return
        }

        await MainActor.run {
            welcomeIntroPhase = .introVideoOnly
        }

        guard await sleepIfNeeded(milliseconds: 2500) else { return }

        await MainActor.run {
            withAnimation(.timingCurve(0.16, 0.92, 0.24, 1, duration: 1.15)) {
                welcomeIntroPhase = .introTitleReveal
            }
        }

        guard await sleepIfNeeded(milliseconds: 550) else { return }

        await MainActor.run {
            withAnimation(.timingCurve(0.16, 0.92, 0.24, 1, duration: 1.15)) {
                welcomeIntroPhase = .introSubtitleReveal
            }
        }

        guard await sleepIfNeeded(milliseconds: 1350) else { return }

        await MainActor.run {
            welcomeIntroPhase = .introCardHold
        }

        guard await sleepIfNeeded(milliseconds: 2000) else { return }

        await MainActor.run {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)) {
                welcomeIntroPhase = .introCTAReady
            }
        }
    }

    private func continueFromWelcomeIntro() {
        guard shouldShowWelcomeExperience,
              hasCompletedWelcomeIntro == false,
              welcomeIntroPhase == .introCTAReady
        else { return }

        feedbackController.medium()

        Task {
            await MainActor.run {
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)) {
                    welcomeIntroPhase = .transitionToWelcome
                }
            }

            guard await sleepIfNeeded(milliseconds: reduceMotion ? 200 : 500) else { return }

            await MainActor.run {
                welcomeIntroPhase = .welcomeReady
                hasCompletedWelcomeIntro = true
            }
        }
    }

    private func sleepIfNeeded(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
            return Task.isCancelled == false
        } catch {
            return false
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HStack(alignment: .center, spacing: spacing.s12) {
                if viewModel.canGoBack {
                    Button {
                        feedbackController.light()
                        viewModel.goBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.tasker(.buttonSmall))
                            .foregroundStyle(OnboardingTheme.textPrimary)
                    }
                    .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textPrimary)
                }

                Spacer()

                if viewModel.step == .welcome, welcomeIntroPhase == .welcomeReady {
                    Button("Skip") {
                        feedbackController.light()
                        Task {
                            await viewModel.skipToFocusRoom()
                        }
                    }
                    .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textSecondary)
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.skipButton)
                }
            }

            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .center, spacing: spacing.s12) {
                    OnboardingEyebrowLabel(title: viewModel.step.eyebrowTitle)
                    Spacer(minLength: spacing.s12)
                    Text(viewModel.step.progressLabel)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }

                Capsule()
                    .fill(OnboardingTheme.headerAccent.opacity(0.08))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(OnboardingTheme.headerAccent.opacity(0.9))
                                .frame(width: proxy.size.width * (CGFloat(viewModel.step.progressIndex) / CGFloat(OnboardingStep.orderedFlow.count)))
                        }
                    }
                    .frame(height: 7)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Onboarding progress")
                    .accessibilityValue(viewModel.step.accessibilitySummary)
            }
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch viewModel.step {
        case .welcome:
            welcomeStep
        case .blocker:
            blockerStep
                .accessibilityIdentifier(AppOnboardingAccessibilityID.blocker)
        case .lifeAreas:
            lifeAreasStep
                .accessibilityIdentifier(AppOnboardingAccessibilityID.lifeAreas)
        case .projects:
            projectsStep
                .accessibilityIdentifier(AppOnboardingAccessibilityID.projects)
        case .habits:
            habitsStep
                .accessibilityIdentifier(AppOnboardingAccessibilityID.habits)
        case .firstTask:
            firstTaskStep
                .accessibilityIdentifier(AppOnboardingAccessibilityID.firstTask)
        case .focusRoom:
            focusRoomStep
                .accessibilityIdentifier(AppOnboardingAccessibilityID.focusRoom)
        }
    }

    private var welcomeStep: some View {
        let baseCard = OnboardingWelcomeValueStack()
            .opacity(shouldShowWelcomeChrome ? 1 : 0)
            .offset(y: welcomeIntroPhase == .transitionToWelcome ? 10 : 0)
            .animation(reduceMotion ? .none : .timingCurve(0.16, 1, 0.3, 1, duration: 0.5), value: welcomeIntroPhase)

        return Group {
            if welcomeIntroPhase == .welcomeReady {
                ZStack {
                    baseCard
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.welcome)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeReady)
            } else {
                baseCard
            }
        }
    }

    private var blockerStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: "What usually gets in your way?",
                subtitle: "We’ll tailor the setup to help with it."
            )

            OnboardingFrictionSelector(
                selectedProfile: viewModel.frictionProfile,
                onSelect: { profile in
                    feedbackController.selection()
                    viewModel.selectFriction(profile)
                }
            )
        }
    }

    private var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: "Choose where to start",
                subtitle: "Pick up to 3 areas to focus on first.",
                detail: "\(viewModel.selectedLifeAreaIDs.count) selected"
            )

            if viewModel.allowsShowAllAreas, viewModel.showAllLifeAreas == false, StarterWorkspaceCatalog.orderedLifeAreas(for: viewModel.frictionProfile).count > viewModel.visibleLifeAreas.count {
                Button {
                    feedbackController.light()
                    viewModel.showAllAreas()
                } label: {
                    Label("Show more areas", systemImage: "square.grid.2x2")
                }
                .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 220 : 156), spacing: spacing.s12)],
                spacing: spacing.s12
            ) {
                ForEach(viewModel.visibleLifeAreas) { area in
                    OnboardingSelectableCard(
                        title: area.name,
                        subtitle: area.subtitle,
                        icon: area.icon,
                        colorHex: area.colorHex,
                        isSelected: viewModel.selectedLifeAreaIDs.contains(area.id)
                    ) {
                        feedbackController.selection()
                        viewModel.toggleLifeArea(area.id)
                    }
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.lifeArea(area.id))
                }
            }
        }
    }

    private var projectsStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: "Your first projects",
                subtitle: "We matched one project to each area. Change only what feels off."
            )

            ForEach(viewModel.selectedLifeAreas, id: \.id) { area in
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Text(area.name)
                        .font(.tasker(.headline))
                        .foregroundStyle(OnboardingTheme.textPrimary)

                    if let featuredDraft = viewModel.projectDrafts.first(where: { $0.lifeAreaTemplateID == area.id }) {
                        OnboardingProjectDraftCard(
                            draft: featuredDraft,
                            colorHex: area.colorHex,
                            icon: area.icon,
                            onChange: {
                                feedbackController.light()
                                projectOptionsAreaID = area.id
                            },
                            actionTitle: "Change"
                        )
                    }
                }
            }
        }
    }

    private var habitsStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: habitsTitle,
                subtitle: habitsSubtitle,
                detail: viewModel.createdHabits.isEmpty ? nil : "\(viewModel.createdHabits.count) added"
            )

            if let primaryTemplate = viewModel.primaryHabitSuggestions.first {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Text("Recommended")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(OnboardingTheme.textPrimary)

                    OnboardingHabitRecommendationCard(
                        template: primaryTemplate,
                        projectName: onboardingProjectName(for: primaryTemplate),
                        state: viewModel.habitTemplateStates[primaryTemplate.id] ?? .idle,
                        isGuidanceHighlighted: true,
                        isSelectionEnabled: viewModel.canAddMoreHabits || viewModel.createdHabitTemplateMap[primaryTemplate.id] != nil,
                        onAdd: {
                            feedbackController.light()
                            Task { await viewModel.addSuggestedHabit(primaryTemplate) }
                        }
                    )
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.habitTemplate(primaryTemplate.id))
                }
            } else {
                OnboardingSelectionSummaryCard(
                    title: "Keep the setup light",
                    message: "Skip the starter habit for now and add your own when it feels useful."
                )
            }

            if viewModel.secondaryHabitSuggestions.isEmpty == false || viewModel.negativeHabitSuggestion != nil {
                DisclosureGroup(isExpanded: $showsMoreHabitIdeas) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        ForEach(viewModel.secondaryHabitSuggestions) { template in
                            OnboardingHabitRecommendationCard(
                                template: template,
                                projectName: onboardingProjectName(for: template),
                                state: viewModel.habitTemplateStates[template.id] ?? .idle,
                                isGuidanceHighlighted: false,
                                isSelectionEnabled: viewModel.canAddMoreHabits || viewModel.createdHabitTemplateMap[template.id] != nil,
                                onAdd: {
                                    feedbackController.light()
                                    Task { await viewModel.addSuggestedHabit(template) }
                                }
                            )
                            .accessibilityIdentifier(AppOnboardingAccessibilityID.habitTemplate(template.id))
                        }

                        if let negativeTemplate = viewModel.negativeHabitSuggestion {
                            OnboardingHabitRecommendationCard(
                                template: negativeTemplate,
                                projectName: onboardingProjectName(for: negativeTemplate),
                                state: viewModel.habitTemplateStates[negativeTemplate.id] ?? .idle,
                                isGuidanceHighlighted: false,
                                isSelectionEnabled: viewModel.canAddMoreHabits || viewModel.createdHabitTemplateMap[negativeTemplate.id] != nil,
                                onAdd: {
                                    feedbackController.light()
                                    Task { await viewModel.addSuggestedHabit(negativeTemplate) }
                                }
                            )
                            .accessibilityIdentifier(AppOnboardingAccessibilityID.habitTemplate(negativeTemplate.id))
                        }
                    }
                    .padding(.top, spacing.s8)
                } label: {
                    Text("More ideas")
                }
                .padding(spacing.s16)
                .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
                )
            }

            Button {
                guard let prefill = onboardingHabitPrefill() else {
                    viewModel.errorMessage = "Tasker could not open the habit composer right now."
                    return
                }
                let opened = onOpenCustomHabitComposer(prefill)
                if opened == false {
                    viewModel.errorMessage = "Tasker could not open the habit composer right now."
                }
            } label: {
                HStack(spacing: spacing.s12) {
                    Image(systemName: "repeat.circle")
                        .foregroundStyle(OnboardingTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create my own habit")
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(OnboardingTheme.textPrimary)
                        Text("Start with a habit that already fits your day.")
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .padding(spacing.s16)
                .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AppOnboardingAccessibilityID.customHabit)
            .accessibilityLabel("Create my own habit")
        }
    }

    private var firstTaskStep: some View {
        let highlightedPrimaryTemplateID = TaskerCTABezelResolver.highlightedOnboardingTemplateID(
            primarySuggestionIDs: viewModel.primaryTaskSuggestions.map(\.id),
            taskTemplateStates: viewModel.taskTemplateStates
        )

        return VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: "Pick one small win for today",
                subtitle: "Start with something you can finish in two minutes or less."
            )

            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Recommended")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(OnboardingTheme.textPrimary)

                ForEach(Array(viewModel.primaryTaskSuggestions.prefix(1))) { template in
                    OnboardingTaskRecommendationCard(
                        template: template,
                        state: viewModel.taskTemplateStates[template.id] ?? .idle,
                        isGuidanceHighlighted: template.id == highlightedPrimaryTemplateID,
                        showsIdleBadge: false,
                        onAdd: {
                            feedbackController.light()
                            Task { await viewModel.addSuggestedTask(template) }
                        },
                        onEdit: {
                            guard let taskID = viewModel.createdTaskTemplateMap[template.id],
                                  let task = viewModel.createdTasks.first(where: { $0.id == taskID })
                            else { return }
                            _ = onEditTask(task)
                        }
                    )
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.taskTemplate(template.id))
                }
            }

            if viewModel.secondaryTaskSuggestions.isEmpty == false {
                DisclosureGroup(isExpanded: $showsMoreIdeas) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        ForEach(viewModel.secondaryTaskSuggestions) { template in
                            OnboardingTaskRecommendationCard(
                                template: template,
                                state: viewModel.taskTemplateStates[template.id] ?? .idle,
                                isGuidanceHighlighted: false,
                                showsIdleBadge: false,
                                onAdd: {
                                    feedbackController.light()
                                    Task { await viewModel.addSuggestedTask(template) }
                                },
                                onEdit: {
                                    guard let taskID = viewModel.createdTaskTemplateMap[template.id],
                                          let task = viewModel.createdTasks.first(where: { $0.id == taskID })
                                    else { return }
                                    _ = onEditTask(task)
                                }
                            )
                            .accessibilityIdentifier(AppOnboardingAccessibilityID.taskTemplate(template.id))
                        }
                    }
                    .padding(.top, spacing.s8)
                } label: {
                    Text("More ideas")
                }
                .padding(spacing.s16)
                .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
                )
            }

            Button {
                guard let project = viewModel.preferredComposerProject else { return }
                let opened = onOpenCustomTaskComposer(
                    AddTaskPrefillTemplate(
                        title: "",
                        details: nil,
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: project.lifeAreaID,
                        priority: .low,
                        type: .morning,
                        dueDateIntent: .today,
                        estimatedDuration: nil,
                        energy: .low,
                        category: .general,
                        context: .anywhere,
                        showMoreDetails: false,
                        showAdvancedPlanning: false
                    )
                )
                if opened == false {
                    viewModel.errorMessage = "Tasker could not open the task composer right now."
                }
            } label: {
                HStack(spacing: spacing.s12) {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(OnboardingTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create my own first task")
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(OnboardingTheme.textPrimary)
                        Text("Write the exact first task you want to start with.")
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .padding(spacing.s16)
                .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AppOnboardingAccessibilityID.customTask)
            .accessibilityLabel("Create my own first task")
        }
    }

    private var focusRoomStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            if let parent = viewModel.parentFocusTask {
                HStack(spacing: spacing.s8) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(OnboardingTheme.textSecondary)
                    Text("From: \(parent.title)")
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(OnboardingTheme.surfaceMuted, in: Capsule())
            }

            if let task = viewModel.focusTask {
                OnboardingFocusHeroCard(
                    task: task,
                    projectName: viewModel.resolvedProjects.first(where: { $0.project.id == task.projectID })?.project.name ?? task.projectName ?? "Project",
                    xpAward: XPCalculationEngine.completionXPIfCompletedNow(
                        priorityRaw: task.priority.rawValue,
                        estimatedDuration: task.estimatedDuration,
                        dueDate: task.dueDate,
                        dailyEarnedSoFar: 0,
                        isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled
                    ).awardedXP,
                    isActive: viewModel.focusIsActive,
                    startedAt: viewModel.focusStartedAt,
                    onPrimary: {
                        if viewModel.focusIsActive {
                            Task { await viewModel.completeFocusTask() }
                        } else {
                            feedbackController.medium()
                            viewModel.startFocusNow()
                        }
                    },
                    onBreakDown: {
                        feedbackController.light()
                        Task { await viewModel.generateBreakdownSuggestions() }
                    }
                )
            }
        }
    }

    private func successView(summary: AppOnboardingSummary) -> some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSuccessHero()
                .accessibilityIdentifier(AppOnboardingAccessibilityID.success)

            OnboardingSuccessSummaryCard(
                areaNames: viewModel.resolvedLifeAreas.map(\.lifeArea.name),
                projectNames: viewModel.resolvedProjects.map(\.project.name),
                habitTitles: summary.createdHabitTitles,
                completedTaskTitle: summary.completedTaskTitle
            )

            if viewModel.reminderPromptState != .hidden {
                OnboardingReminderCard(
                    state: viewModel.reminderPromptState,
                    onPrimary: {
                        switch viewModel.reminderPromptState {
                        case .prompt:
                            Task { await viewModel.handleReminderPrimaryAction() }
                        case .openSettings:
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        case .hidden:
                            break
                        }
                    },
                    onSecondary: {
                        viewModel.dismissReminderPrompt()
                    }
                )
            }
        }
    }

    private func onboardingProjectName(for template: StarterHabitTemplate) -> String? {
        guard let projectTemplateID = template.projectTemplateID else { return nil }
        return viewModel.resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.name
    }

    private func onboardingHabitPrefill() -> AddHabitPrefillTemplate? {
        if let template = viewModel.primaryHabitSuggestions.first,
           let resolvedLifeArea = viewModel.resolvedLifeAreas.first(where: { $0.templateID == template.lifeAreaTemplateID }) {
            let projectID = template.projectTemplateID.flatMap { projectTemplateID in
                viewModel.resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.id
            }
            return template.makePrefill(lifeAreaID: resolvedLifeArea.lifeArea.id, projectID: projectID)
        }

        guard let lifeArea = viewModel.resolvedLifeAreas.first?.lifeArea else { return nil }
        let projectID = viewModel.resolvedProjects.first?.project.id
        return AddHabitPrefillTemplate(
            title: "",
            lifeAreaID: lifeArea.id,
            projectID: projectID
        )
    }

    private var breakdownSheet: some View {
        NavigationStack {
            List {
                if let banner = viewModel.breakdownRouteBanner, banner.isEmpty == false {
                    Section {
                        Text(banner)
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    }
                }

                Section("Ask your AI coach") {
                    ForEach(viewModel.breakdownSteps) { step in
                        Button {
                            viewModel.toggleBreakdownStep(step.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: step.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(step.isSelected ? OnboardingTheme.accent : OnboardingTheme.textSecondary)
                                Text(step.title)
                                    .foregroundStyle(OnboardingTheme.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.breakdownIsLoading {
                    Section {
                        ProgressView("Refining steps…")
                            .tint(OnboardingTheme.accent)
                    }
                }
            }
            .navigationTitle("AI coach")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.breakdownSheetPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add selected") {
                        Task { await viewModel.applySelectedBreakdownSteps() }
                    }
                }
            }
        }
    }

    private func projectOptionsSheet(area: StarterLifeAreaTemplate, draft: OnboardingProjectDraft) -> some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draft.suggestionTemplateIDs, id: \.self) { templateID in
                        if let template = StarterWorkspaceCatalog.projectTemplate(id: templateID) {
                            Button {
                                feedbackController.selection()
                                viewModel.selectProjectSuggestion(draft.id, templateID: templateID)
                                projectOptionsAreaID = nil
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(uiColor: UIColor(taskerHex: area.colorHex)).opacity(0.14))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: area.icon)
                                            .foregroundStyle(Color(uiColor: UIColor(taskerHex: area.colorHex)))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.tasker(.bodyEmphasis))
                                            .foregroundStyle(OnboardingTheme.textPrimary)
                                        Text(template.summary)
                                            .font(.tasker(.caption1))
                                            .foregroundStyle(OnboardingTheme.textSecondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    if draft.templateID == templateID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(OnboardingTheme.accent)
                                    } else {
                                        Text("Choose")
                                            .font(.tasker(.caption1))
                                            .foregroundStyle(OnboardingTheme.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text("Pick the option that feels easiest to keep.")
                }
            }
            .navigationTitle("Choose a project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        projectOptionsAreaID = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var bottomDock: some View {
        let dockContent = VStack(spacing: spacing.s12) {
            if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
                Text(errorMessage)
                    .font(.tasker(.caption1))
                    .foregroundStyle(OnboardingTheme.danger)
                    .multilineTextAlignment(.center)
            }

            if viewModel.successSummary != nil {
                VStack(spacing: spacing.s8) {
                    Button {
                        feedbackController.medium()
                        viewModel.finishOnboarding()
                        onDismissFlow()
                    } label: {
                        Text("Open home")
                            .frame(maxWidth: .infinity)
                    }
                    .onboardingPrimaryButton()
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.goHome)

                    if viewModel.nextOpenTask != nil {
                        Button("What’s next") {
                            feedbackController.light()
                            viewModel.continueWithNextTask()
                        }
                        .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.breakdownNext)
                    }
                }
            } else {
                switch viewModel.step {
                case .welcome:
                    VStack(spacing: spacing.s8) {
                        Button {
                            feedbackController.medium()
                            viewModel.begin(mode: .guided)
                        } label: {
                            Text("Set up Tasker")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton()
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.startRecommended)

                        Button("Customize it") {
                            feedbackController.light()
                            viewModel.begin(mode: .custom)
                        }
                        .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.customize)
                    }
                case .blocker:
                    VStack(spacing: spacing.s8) {
                        Button {
                            feedbackController.medium()
                            viewModel.continueFromBlocker()
                        } label: {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton()
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.continueFromBlocker)

                        Button("Skip for now") {
                            feedbackController.light()
                            viewModel.skipBlocker()
                        }
                        .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.skipBlocker)
                    }
                case .lifeAreas:
                    VStack(spacing: spacing.s8) {
                        Text("You can change these later.")
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button {
                            feedbackController.medium()
                            Task { await viewModel.continueFromLifeAreas() }
                        } label: {
                            Text(viewModel.isWorking ? "Setting up your areas…" : "Use these areas")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton(disabled: viewModel.canContinueLifeAreas == false || viewModel.isWorking)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.useAreas)
                    }
                case .projects:
                    VStack(spacing: spacing.s8) {
                        Text("You can refine everything later.")
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button {
                            feedbackController.medium()
                            Task { await viewModel.continueFromProjects() }
                        } label: {
                            Text(viewModel.isWorking ? "Setting up your projects…" : "Use these projects")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton(disabled: viewModel.canContinueProjects == false || viewModel.isWorking)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.useProjects)
                    }
                case .habits:
                    VStack(spacing: spacing.s8) {
                        Text(viewModel.createdHabits.isEmpty ? "You can add habits later too." : "Your habits will start showing up on Home.")
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button {
                            feedbackController.medium()
                            viewModel.continueFromHabits()
                        } label: {
                            Text("Finish setup")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton()
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.useHabits)
                    }
                case .firstTask:
                    VStack(spacing: spacing.s8) {
                        Button {
                            feedbackController.medium()
                            viewModel.continueFromFirstTask()
                        } label: {
                            Text(viewModel.canContinueToFocus ? "Continue with this first win" : "Choose a first win")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton(disabled: viewModel.canContinueToFocus == false || viewModel.isWorking)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.goFinishTask)
                    }
                case .focusRoom:
                    EmptyView()
                }
            }
        }

        let fillOpacity = shouldShowWelcomeExperience ? 0.72 : 0.82

        return dockContent
            .padding(14)
            .taskerPremiumSurface(
                cornerRadius: 30,
                fillColor: OnboardingTheme.surfaceElevated.opacity(fillOpacity),
                strokeColor: OnboardingTheme.borderSoft.opacity(0.82),
                accentColor: OnboardingTheme.accentSecondary,
                level: .e2,
                useNativeGlass: true
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.top, spacing.s12)
            .padding(.bottom, max(spacing.s8, 8))
    }
}

struct AppOnboardingPromptSheetView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    let snapshot: OnboardingWorkspaceSnapshot
    let onStart: () -> Void
    let onNotNow: () -> Void

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ZStack {
            AppOnboardingBackground()
                .ignoresSafeArea()

            Group {
                if layoutClass.isPad {
                    HStack(alignment: .top, spacing: spacing.s20) {
                        OnboardingPromptValueCard(snapshot: snapshot)
                            .frame(width: 290, alignment: .leading)
                        promptActionCard
                    }
                } else {
                    VStack(alignment: .leading, spacing: spacing.sectionGap) {
                        OnboardingPromptValueCard(snapshot: snapshot)
                        promptActionCard
                    }
                }
            }
            .taskerReadableContent(maxWidth: 760, alignment: .center)
            .padding(spacing.s20)
            .onboardingHeroPanel(cornerRadius: 32)
            .padding(.horizontal, spacing.screenHorizontal)
        }
        .interactiveDismissDisabled(true)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.prompt)
    }

    private var promptActionCard: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            Text("What Tasker will reuse")
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(OnboardingTheme.textPrimary)
            OnboardingChecklistCard(items: [
                "Keep the areas and projects that already fit.",
                "Suggest one light habit only if it improves tomorrow.",
                "Guide you into one small completion without duplicate clutter.",
                "Leave your existing setup intact while you review the next layer."
            ])

            VStack(spacing: spacing.s12) {
                Button {
                    onStart()
                } label: {
                    Text("Review matched setup")
                        .frame(maxWidth: .infinity)
                }
                .onboardingPrimaryButton()
                .accessibilityIdentifier(AppOnboardingAccessibilityID.promptStart)

                Button("Not now") {
                    onNotNow()
                }
                .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.promptDismiss)
            }
        }
    }
}

struct HomeOnboardingGuidanceBanner: View {
    let state: HomeOnboardingGuidanceModel.State

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(OnboardingTheme.accent)
            VStack(alignment: .leading, spacing: 6) {
                Text(state.title)
                    .font(.tasker(.headline))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Text(state.message)
                    .font(.tasker(.caption1))
                    .foregroundStyle(OnboardingTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(OnboardingTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
        .accessibilityIdentifier("home.onboarding.guide")
    }
}

@MainActor
private enum OnboardingTheme {
    static let canvas = Color.tasker(.bgCanvas)
    static let canvasSecondary = Color.tasker(.bgCanvasSecondary)
    static let canvasElevated = Color.tasker(.bgElevated)
    static let surface = Color.tasker(.surfacePrimary).opacity(0.92)
    static let surfaceElevated = Color.tasker(.surfacePrimary).opacity(0.98)
    static let surfaceMuted = Color.tasker(.surfaceSecondary).opacity(0.88)
    static let borderSoft = Color.tasker(.borderSubtle)
    static let border = Color.tasker(.borderDefault)
    static let textPrimary = Color.tasker(.textPrimary)
    static let textSecondary = Color.tasker(.textSecondary)
    static let textTertiary = Color.tasker(.textTertiary)
    static let accent = Color.tasker(.brandSecondary)
    static let accentSecondary = Color.tasker(.brandHighlight)
    static let headerAccent = Color.tasker(.brandHighlight)
    static let success = Color.tasker(.statusSuccess)
    static let danger = Color.tasker(.statusDanger)
}

private struct AppOnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                OnboardingTheme.canvas.opacity(0.98),
                OnboardingTheme.canvasSecondary.opacity(0.99),
                OnboardingTheme.canvasElevated.opacity(0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(OnboardingTheme.accent.opacity(0.035))
                .frame(width: 320, height: 220)
                .blur(radius: 56)
                .offset(x: -96, y: -84)
        }
    }
}

private struct OnboardingSectionHeader: View {
    let title: String
    let subtitle: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.tasker(.title2))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                if let detail, detail.isEmpty == false {
                    Text(detail)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
            }

            Text(subtitle)
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingEyebrowLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.tasker(.caption2))
            .foregroundStyle(OnboardingTheme.accent)
            .tracking(0.8)
    }
}

private struct OnboardingTrustRow: View {
    let items: [(String, String)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 6) {
                        Image(systemName: item.0)
                        Text(item.1)
                    }
                    .font(.tasker(.caption2))
                    .foregroundStyle(OnboardingTheme.textSecondary)

                    if index < items.count - 1 {
                        Text("·")
                            .font(.tasker(.caption2))
                            .foregroundStyle(OnboardingTheme.textTertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    pill(icon: item.0, title: item.1)
                }
            }
        }
    }

    private func pill(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.tasker(.caption2))
        .foregroundStyle(OnboardingTheme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OnboardingTheme.surfaceElevated.opacity(0.88), in: Capsule())
        .overlay(
            Capsule()
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}

private struct OnboardingWelcomeValueStack: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Get your day back under control.")
                .font(.tasker(.display))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tasker cuts through the noise and gives you a clear place to start.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingTrustRow(items: [
                ("sparkles.rectangle.stack", "Real setup"),
                ("clock", "~2 min"),
                ("arrow.uturn.backward.circle", "Easy to change later")
            ])
        }
        .padding(24)
        .taskerPremiumSurface(
            cornerRadius: 32,
            fillColor: OnboardingTheme.surfaceElevated.opacity(0.74),
            strokeColor: OnboardingTheme.borderSoft.opacity(0.82),
            accentColor: OnboardingTheme.accentSecondary,
            level: .e3,
            useNativeGlass: true
        )
    }
}

private enum OnboardingHeroMediaAsset {
    static let welcomeVideoName = "HeroWelcomeHighCompressMb"
}

private struct OnboardingWelcomeBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let phase: WelcomeIntroPhase

    var body: some View {
        ZStack {
            OnboardingHeroVideoView(
                videoName: OnboardingHeroMediaAsset.welcomeVideoName,
                accessibilityIdentifier: AppOnboardingAccessibilityID.welcomeHeroVideo
            )
            .ignoresSafeArea()

            Rectangle()
                .fill(Color.black.opacity(phase.backdropDimOpacity))
                .ignoresSafeArea()

            if reduceTransparency {
                Rectangle()
                    .fill(OnboardingTheme.canvas.opacity(phase.backdropBlurOpacity * 0.78))
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(phase.backdropBlurOpacity)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(phase.showsWelcomeChrome ? 0.32 : 0.08),
                    Color.clear,
                    Color.black.opacity(phase.showsWelcomeChrome ? 0.42 : 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct OnboardingWelcomeCinematicOverlay: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let phase: WelcomeIntroPhase
    let onContinue: () -> Void

    private var topInset: CGFloat {
        layoutClass.isPad ? 56 : 28
    }

    private var titleVisible: Bool {
        phase.showsTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            if phase.showsIntroCard {
                cinematicCard
                    .padding(.top, topInset)
                    .padding(.horizontal, layoutClass.isPad ? 56 : 24)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: -220).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }

            Spacer(minLength: 0)

            if phase.showsIntroCTA {
                Button {
                    onContinue()
                } label: {
                    Text("Get your days back under control")
                        .frame(maxWidth: .infinity)
                }
                .onboardingPrimaryButton()
                .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeIntroContinue)
                .padding(.horizontal, layoutClass.isPad ? 56 : 24)
                .padding(.bottom, layoutClass.isPad ? 32 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
    }

    private var cinematicCard: some View {
        VStack(spacing: 18) {
            OnboardingWelcomeIntroLine(
                text: "Welcome to Tasker",
                style: .display,
                isVisible: titleVisible,
                secondary: false
            )
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
        .padding(.vertical, 28)
        .frame(maxWidth: layoutClass.isPad ? 520 : 420)
        .taskerPremiumSurface(
            cornerRadius: 34,
            fillColor: reduceTransparency
                ? OnboardingTheme.surfaceElevated.opacity(0.94)
                : .clear,
            strokeColor: OnboardingTheme.borderSoft.opacity(0.8),
            accentColor: reduceTransparency ? OnboardingTheme.accentSecondary : .clear,
            level: .e3,
            useNativeGlass: true
        )
        .shadow(color: Color.black.opacity(0.14), radius: 32, y: 18)
        .scaleEffect(phase == .transitionToWelcome ? 0.98 : 1)
        .opacity(phase.introCardOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to Tasker.")
        .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeIntroTitleCard)
    }
}

private struct OnboardingWelcomeIntroLine: View {
    let text: String
    let style: TaskerTextStyle
    let isVisible: Bool
    let secondary: Bool

    var body: some View {
        Text(text)
            .font(.tasker(style))
            .foregroundStyle(secondary ? OnboardingTheme.textSecondary : OnboardingTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .blur(radius: isVisible ? 0 : 18)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 14)
            .animation(.timingCurve(0.16, 0.92, 0.24, 1, duration: 1.15), value: isVisible)
    }
}

private struct OnboardingWelcomeHeroSection: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let horizontalPadding: CGFloat

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let contentWidth = max(availableWidth, layoutClass.isPad ? 720 : 320)
        let heroWidth = layoutClass.isPad ? contentWidth : contentWidth + (horizontalPadding * 2)
        let heroHeight = OnboardingWelcomeHeroMetrics.height(
            for: heroWidth,
            isPad: layoutClass.isPad,
            dynamicTypeSize: dynamicTypeSize
        )

        return heroMedia
            .frame(height: heroHeight)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: OnboardingWelcomeHeroWidthPreferenceKey.self,
                            value: proxy.size.width
                        )
                }
            )
            .onPreferenceChange(OnboardingWelcomeHeroWidthPreferenceKey.self) { width in
                availableWidth = width
            }
            .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeHeroVideo)
            .padding(.horizontal, layoutClass.isPad ? 0 : -horizontalPadding)
    }

    @ViewBuilder
    private var heroMedia: some View {
        if reduceMotion {
            ZStack {
                LinearGradient(
                    colors: [
                        OnboardingTheme.surfaceElevated,
                        OnboardingTheme.accent.opacity(0.18),
                        OnboardingTheme.surfaceElevated
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
            }
        } else {
            OnboardingHeroVideoView(
                videoName: OnboardingHeroMediaAsset.welcomeVideoName,
                accessibilityIdentifier: AppOnboardingAccessibilityID.welcomeHeroVideo
            )
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.04),
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

private enum OnboardingWelcomeHeroMetrics {
    static func height(for width: CGFloat, isPad: Bool, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let minimumHeight: CGFloat = isPad ? 360 : 300
        let maximumHeight: CGFloat = isPad ? 620 : 460
        let aspectRatio: CGFloat = dynamicTypeSize.isAccessibilitySize
            ? (isPad ? 0.44 : 0.72)
            : (isPad ? 0.5 : 0.9)

        return min(max(width * aspectRatio, minimumHeight), maximumHeight)
    }
}

private struct OnboardingWelcomeHeroWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if os(iOS) || os(visionOS)
private struct OnboardingHeroVideoView: UIViewRepresentable {
    let videoName: String
    let accessibilityIdentifier: String

    func makeUIView(context: Context) -> OnboardingLoopingPlayerView {
        OnboardingLoopingPlayerView(
            videoName: videoName,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    func updateUIView(_ uiView: OnboardingLoopingPlayerView, context: Context) {
        uiView.accessibilityIdentifier = accessibilityIdentifier
        uiView.update(videoName: videoName)
    }
}

private final class OnboardingLoopingPlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private let player = AVQueuePlayer()
    private var playerLooper: AVPlayerLooper?
    private var currentVideoName: String?

    init(videoName: String, accessibilityIdentifier: String) {
        super.init(frame: .zero)
        self.accessibilityIdentifier = accessibilityIdentifier
        accessibilityLabel = "Welcome video"
        backgroundColor = .black
        isAccessibilityElement = true
        isUserInteractionEnabled = false

        layer.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill

        player.isMuted = true
        player.actionAtItemEnd = .none

        update(videoName: videoName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        player.pause()
        player.removeAllItems()
        playerLooper = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            player.pause()
        } else {
            player.play()
        }
    }

    func update(videoName: String) {
        guard currentVideoName != videoName else {
            if window != nil {
                player.play()
            }
            return
        }

        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            player.pause()
            player.removeAllItems()
            playerLooper = nil
            currentVideoName = nil
            assertionFailure("Missing onboarding hero asset: \(videoName).mp4")
            logWarning(
                event: "onboarding_missing_video_asset",
                message: "Missing bundled onboarding hero asset",
                fields: ["video_name": videoName]
            )
            return
        }

        currentVideoName = videoName
        let url = URL(fileURLWithPath: path)
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        player.removeAllItems()
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }
}
#endif

private struct OnboardingFrictionSelector: View {
    let selectedProfile: OnboardingFrictionProfile?
    let onSelect: (OnboardingFrictionProfile) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    var body: some View {
        let layout = OnboardingFrictionSelectorLayout.preferredLayout(
            for: availableWidth,
            dynamicTypeSize: dynamicTypeSize
        )
        VStack(alignment: .leading, spacing: 14) {
            if layout == .stacked {
                VStack(alignment: .leading, spacing: 10) {
                    optionCards
                }
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    optionCards
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: OnboardingFrictionSelectorWidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(OnboardingFrictionSelectorWidthPreferenceKey.self) { width in
            availableWidth = width
        }
    }

    @ViewBuilder
    private var optionCards: some View {
        let layout = OnboardingFrictionSelectorLayout.preferredLayout(
            for: availableWidth,
            dynamicTypeSize: dynamicTypeSize
        )

        ForEach(OnboardingFrictionProfile.allCases) { profile in
            OnboardingFrictionOptionCard(
                title: profile.title,
                symbolName: profile.symbolName,
                helperCopy: profile.helperCopy,
                isSelected: selectedProfile == profile,
                layout: layout,
                action: {
                    onSelect(profile)
                }
            )
            .accessibilityHint(profile.helperCopy)
        }
    }
}

enum OnboardingFrictionSelectorLayout: Equatable {
    case stacked
    case twoColumn

    static func preferredLayout(for availableWidth: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Self {
        if dynamicTypeSize.isAccessibilitySize || availableWidth < 500 {
            return .stacked
        }

        return .twoColumn
    }
}

private struct OnboardingFrictionSelectorWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct OnboardingPromptValueCard: View {
    let snapshot: OnboardingWorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start from what already fits.")
                .font(.tasker(.title2))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tasker can reuse what is already working, keep the setup clean, and guide you into one small win without replaying the whole intro.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                String.localizedStringWithFormat(
                    String(localized: "Already in place: %lld areas, %lld projects, %lld tasks"),
                    snapshot.customLifeAreaCount,
                    snapshot.customProjectCount,
                    snapshot.taskCount
                )
            )
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.textSecondary)
        }
    }
}

private struct OnboardingSelectionSummaryCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text(message)
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}

private struct OnboardingSplitSupportCard: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnboardingEyebrowLabel(title: "Why this step matters")
            Text(message)
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(OnboardingTheme.surfaceElevated.opacity(0.9), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }

    private var message: String {
        switch step {
        case .welcome:
            return "This is a real setup session. The goal is to make the app feel lighter before you ever hit Home."
        case .blocker:
            return "A quick blocker choice helps Tasker lower friction without turning setup into a questionnaire."
        case .lifeAreas:
            return "A smaller starter scope reduces drag. You are defining where Tasker should help first, not forever."
        case .projects:
            return "Starter projects are here to reduce blank-page friction. Keep the recommended path and change only what feels obviously wrong."
        case .habits:
            return "A starter habit should lower tomorrow's friction, not create a second onboarding checklist. One good rhythm is enough."
        case .firstTask:
            return "The first task matters more than the perfect task. Pick the option you can actually finish today."
        case .focusRoom:
            return "Momentum comes from one completion, not more planning. Finish the task in front of you."
        }
    }
}

private struct OnboardingChecklistCard: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OnboardingTheme.accent)
                    Text(item)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}

private struct OnboardingHeroAccent: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingEyebrowLabel(title: "Setup")

            HStack(spacing: 14) {
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.14))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.accent)
                    )
                Text("Relief first")
                    .font(.tasker(.caption1))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                Spacer()
            }

            Text(title)
                .font(.tasker(.display))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .onboardingHeroPanel(cornerRadius: 32)
    }
}

private struct OnboardingFrictionOptionCard: View {
    let title: String
    let symbolName: String
    let helperCopy: String
    let isSelected: Bool
    let layout: OnboardingFrictionSelectorLayout
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? OnboardingTheme.accent.opacity(0.14) : OnboardingTheme.surfaceElevated.opacity(0.92))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: symbolName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.textSecondary)
                                .contentTransition(.symbolEffect(.replace))
                        )

                    Text(title)
                        .font(.tasker(.buttonSmall))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(layout == .twoColumn ? 2 : nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Circle()
                            .fill(isSelected ? OnboardingTheme.accent : .clear)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? OnboardingTheme.accent : OnboardingTheme.border, lineWidth: 1.5)
                            )
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                if isSelected {
                    Text(helperCopy)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.frictionHelper)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, layout == .stacked ? 14 : 16)
            .padding(.vertical, layout == .stacked ? 14 : 16)
            .frame(
                maxWidth: .infinity,
                minHeight: layout == .twoColumn ? 86 : 74,
                alignment: .leading
            )
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(
                color: isSelected ? OnboardingTheme.accent.opacity(reduceMotion ? 0.0 : 0.10) : .clear,
                radius: isSelected ? 14 : 0,
                x: 0,
                y: isSelected ? 8 : 0
            )
        }
        .buttonStyle(OnboardingPressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: isSelected)
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(OnboardingTheme.surfaceMuted)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(OnboardingTheme.accent.opacity(0.10))
                }
            }
    }

    @ViewBuilder
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(isSelected ? OnboardingTheme.accent.opacity(0.20) : OnboardingTheme.borderSoft, lineWidth: isSelected ? 1.5 : 1)
    }
}

private struct OnboardingSelectableCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colorHex: String
    let isSelected: Bool
    let allowsMultiline: Bool = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: UIColor(taskerHex: colorHex)).opacity(isSelected ? 0.22 : 0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .foregroundStyle(Color(uiColor: UIColor(taskerHex: colorHex)))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(isSelected ? OnboardingTheme.accent : .clear)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? OnboardingTheme.accent : OnboardingTheme.border, lineWidth: 1.5)
                            )
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? OnboardingTheme.accent.opacity(0.10) : OnboardingTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? OnboardingTheme.accent.opacity(0.18) : OnboardingTheme.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(subtitle)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: isSelected)
    }
}

private struct OnboardingProjectDraftCard: View {
    let draft: OnboardingProjectDraft
    let colorHex: String
    let icon: String
    let onChange: () -> Void
    let actionTitle: String

    var body: some View {
        Button(action: onChange) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: UIColor(taskerHex: colorHex)).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .foregroundStyle(Color(uiColor: UIColor(taskerHex: colorHex)))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.name)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(OnboardingTheme.textPrimary)
                        Text(draft.summary)
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                HStack(spacing: 6) {
                    Text(actionTitle)
                        .font(.tasker(.buttonSmall))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)
            }
            .padding(18)
            .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingHabitRecommendationCard: View {
    let template: StarterHabitTemplate
    let projectName: String?
    let state: OnboardingHabitTemplateState
    let isGuidanceHighlighted: Bool
    let isSelectionEnabled: Bool
    let onAdd: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: template.icon.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconAccent)
                    .frame(width: 36, height: 36)
                    .background(iconAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(titleColor)
                    Text(template.reason)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                badge
                    .transition(.opacity)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    infoChip(ownershipLine)
                    infoChip(cadenceLine)
                    Spacer(minLength: 8)
                    actionButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        infoChip(ownershipLine)
                        infoChip(cadenceLine)
                    }
                    actionButton
                }
            }
        }
        .padding(12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: stateBorderWidth)
        )
        .animation(reduceMotion ? .none : .easeOut(duration: 0.25), value: state)
    }

    private var actionButton: some View {
        Group {
            switch state {
            case .created:
                EmptyView()
            default:
                Button {
                    onAdd()
                } label: {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .labelStyle(.titleAndIcon)
                        .font(.tasker(.buttonSmall))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(buttonBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(buttonBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(OnboardingPressScaleButtonStyle())
                .foregroundStyle(state == .creating || isSelectionEnabled == false ? OnboardingTheme.textSecondary : OnboardingTheme.textPrimary)
                .disabled(state == .creating || isSelectionEnabled == false)
            }
        }
    }

    private func infoChip(_ title: String) -> some View {
        Text(title)
            .font(.tasker(.caption2))
            .foregroundStyle(OnboardingTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(OnboardingTheme.surfaceMuted, in: Capsule())
    }

    private var ownershipLine: String {
        if let projectName, projectName.isEmpty == false {
            return "\(lifeAreaName) · \(projectName)"
        }
        return lifeAreaName
    }

    private var lifeAreaName: String {
        StarterWorkspaceCatalog.lifeAreaTemplate(id: template.lifeAreaTemplateID)?.name ?? "Habit"
    }

    private var cadenceLine: String {
        switch template.cadence {
        case .daily:
            return template.isPositive ? "Daily" : "Daily check-in"
        case .weekly(let daysOfWeek, _, _):
            return daysOfWeek.count > 1 ? "Weekdays" : "Weekly"
        }
    }

    private var buttonIcon: String {
        switch state {
        case .idle:
            return "plus"
        case .creating:
            return "hourglass"
        case .created:
            return "checkmark"
        case .failed:
            return "arrow.clockwise"
        }
    }

    private var buttonTitle: String {
        switch state {
        case .idle:
            return isSelectionEnabled ? "Add" : "Added 2"
        case .creating:
            return "Adding…"
        case .created:
            return "Added"
        case .failed:
            return isSelectionEnabled ? "Try again" : "Added 2"
        }
    }

    private var buttonBackground: Color {
        if isSelectionEnabled == false {
            return OnboardingTheme.surfaceMuted
        }
        switch state {
        case .creating:
            return OnboardingTheme.surfaceMuted
        case .failed:
            return OnboardingTheme.danger.opacity(0.10)
        default:
            return OnboardingTheme.accent.opacity(0.12)
        }
    }

    private var buttonBorder: Color {
        switch state {
        case .failed:
            return OnboardingTheme.danger.opacity(0.6)
        case .creating:
            return OnboardingTheme.borderSoft
        default:
            return isGuidanceHighlighted ? OnboardingTheme.accent.opacity(0.42) : OnboardingTheme.borderSoft
        }
    }

    private var titleColor: Color {
        switch state {
        case .failed:
            return OnboardingTheme.danger
        default:
            return OnboardingTheme.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.accent.opacity(0.10)
        case .failed:
            return OnboardingTheme.danger.opacity(0.08)
        default:
            return isSelectionEnabled ? OnboardingTheme.surface : OnboardingTheme.surfaceMuted
        }
    }

    private var borderColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.accent.opacity(0.28)
        case .failed:
            return OnboardingTheme.danger.opacity(0.7)
        default:
            return isSelectionEnabled ? OnboardingTheme.border : OnboardingTheme.borderSoft
        }
    }

    private var stateBorderWidth: CGFloat {
        switch state {
        case .created, .failed:
            return 1.5
        default:
            return 1
        }
    }

    private var iconAccent: Color {
        template.isPositive ? OnboardingTheme.accent : OnboardingTheme.textPrimary
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .created:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
        case .creating:
            OnboardingInlineBadge(title: "Saving", accent: OnboardingTheme.accent)
        case .failed:
            OnboardingInlineBadge(title: "Needs retry", accent: OnboardingTheme.danger)
        case .idle:
            OnboardingInlineBadge(
                title: template.isPositive ? "Recommended" : "Optional",
                accent: template.isPositive ? OnboardingTheme.accent : OnboardingTheme.textSecondary
            )
        }
    }
}

private struct OnboardingTaskRecommendationCard: View {
    let template: StarterTaskTemplate
    let state: OnboardingTaskTemplateState
    let isGuidanceHighlighted: Bool
    let showsIdleBadge: Bool
    let onAdd: () -> Void
    let onEdit: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(titleColor)
                    Text(template.reason)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                badge
                    .transition(.opacity)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    metaChip("\(template.durationMinutes) min")
                    metaChip("+\(XPCalculationEngine.completionXPIfCompletedNow(priorityRaw: template.priority.rawValue, estimatedDuration: TimeInterval(template.durationMinutes * 60), dueDate: DatePreset.today.resolvedDueDate(), dailyEarnedSoFar: 0, isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled).awardedXP) XP")
                    Spacer()
                    actionButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        metaChip("\(template.durationMinutes) min")
                        metaChip("+\(XPCalculationEngine.completionXPIfCompletedNow(priorityRaw: template.priority.rawValue, estimatedDuration: TimeInterval(template.durationMinutes * 60), dueDate: DatePreset.today.resolvedDueDate(), dailyEarnedSoFar: 0, isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled).awardedXP) XP")
                    }
                    actionButton
                }
            }
        }
        .padding(12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: stateBorderWidth)
        )
        .animation(reduceMotion ? .none : .easeOut(duration: 0.25), value: state)
    }

    private var actionButton: some View {
        Group {
            switch state {
            case .created:
                EmptyView()
            default:
                Button {
                    onAdd()
                } label: {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .labelStyle(.titleAndIcon)
                        .font(.tasker(.buttonSmall))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(buttonBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(buttonBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(OnboardingPressScaleButtonStyle())
                .foregroundStyle(state == .creating ? OnboardingTheme.textSecondary : OnboardingTheme.textPrimary)
                .disabled(state == .creating)
            }
        }
    }

    private var buttonIcon: String {
        switch state {
        case .idle:
            return "plus"
        case .creating:
            return "hourglass"
        case .created:
            return "checkmark"
        case .failed:
            return "arrow.clockwise"
        }
    }

    private var buttonBackground: Color {
        switch state {
        case .creating:
            return OnboardingTheme.surfaceMuted
        case .failed:
            return OnboardingTheme.danger.opacity(0.10)
        default:
            return OnboardingTheme.accent.opacity(0.12)
        }
    }

    private var buttonBorder: Color {
        switch state {
        case .failed:
            return OnboardingTheme.danger.opacity(0.6)
        case .creating:
            return OnboardingTheme.borderSoft
        default:
            return isGuidanceHighlighted ? OnboardingTheme.accent.opacity(0.42) : OnboardingTheme.borderSoft
        }
    }

    private var buttonTitle: String {
        switch state {
        case .idle:
            return "Choose"
        case .creating:
            return "Choosing…"
        case .created:
            return "Choose"
        case .failed:
            return "Try again"
        }
    }

    private var titleColor: Color {
        switch state {
        case .failed:
            return OnboardingTheme.danger
        default:
            return OnboardingTheme.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.accent.opacity(0.10)
        case .failed:
            return OnboardingTheme.danger.opacity(0.08)
        default:
            return OnboardingTheme.surface
        }
    }

    private var borderColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.accent.opacity(0.28)
        case .failed:
            return OnboardingTheme.danger.opacity(0.7)
        default:
            return OnboardingTheme.border
        }
    }

    private var stateBorderWidth: CGFloat {
        switch state {
        case .created, .failed:
            return 1.5
        default:
            return 1
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .created:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
        case .creating:
            OnboardingInlineBadge(title: "Saving", accent: OnboardingTheme.accent)
        case .failed:
            OnboardingInlineBadge(title: "Needs retry", accent: OnboardingTheme.danger)
        case .idle:
            if showsIdleBadge {
                OnboardingInlineBadge(title: "Recommended", accent: OnboardingTheme.accent)
            }
        }
    }

    private func metaChip(_ title: String) -> some View {
        Text(title)
            .font(.tasker(.caption2))
            .foregroundStyle(OnboardingTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(OnboardingTheme.surfaceMuted, in: Capsule())
    }
}

private struct OnboardingPressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && reduceMotion == false ? 0.98 : 1)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct OnboardingPrimaryCTAButtonStyle: ButtonStyle {
    let disabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return configuration.label
            .font(.tasker(.button))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 18)
            .background(
                disabled ? OnboardingTheme.textSecondary.opacity(0.4) : OnboardingTheme.accent,
                in: shape
            )
            .overlay(
                shape
                    .stroke(disabled ? .clear : Color.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && disabled == false && reduceMotion == false ? 0.98 : 1)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct OnboardingInlineBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.tasker(.caption2))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.opacity(0.10), in: Capsule())
    }
}

private struct OnboardingFocusHeroCard: View {
    let task: TaskDefinition
    let projectName: String
    let xpAward: Int
    let isActive: Bool
    let startedAt: Date?
    let onPrimary: () -> Void
    let onBreakDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Finish your first win")
                .font(.tasker(.title2))
                .foregroundStyle(OnboardingTheme.textPrimary)

            Text("This should only take a moment.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    pill(projectName, accent: OnboardingTheme.textSecondary)
                    pill(durationText, accent: OnboardingTheme.textSecondary)
                    pill("+\(xpAward) XP", accent: OnboardingTheme.textSecondary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        pill(projectName, accent: OnboardingTheme.textSecondary)
                        pill(durationText, accent: OnboardingTheme.textSecondary)
                    }
                    pill("+\(xpAward) XP", accent: OnboardingTheme.textSecondary)
                }
            }

            Text(task.title)
                .font(.tasker(.title1))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingFocusTimer(
                startedAt: startedAt,
                estimatedDuration: task.estimatedDuration,
                isActive: isActive
            )

            VStack(spacing: 10) {
                Button {
                    onPrimary()
                } label: {
                    Text(isActive ? "Mark complete" : "Start focus")
                        .frame(maxWidth: .infinity)
                }
                .onboardingPrimaryButton(disabled: task.isComplete)
                .accessibilityIdentifier(isActive ? AppOnboardingAccessibilityID.markComplete : AppOnboardingAccessibilityID.focusPrimary)
                .accessibilityLabel(isActive ? "Mark complete" : "Start focus")

                Button("Break this into smaller steps") {
                    onBreakDown()
                }
                .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textSecondary)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.breakDown)
            }
        }
        .padding(26)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
        .shadow(color: OnboardingTheme.accent.opacity(0.1), radius: 28, y: 10)
    }

    private var durationText: String {
        if let estimated = task.estimatedDuration {
            let minutes = max(1, Int(estimated / 60))
            return "\(minutes) min"
        }
        return "No timer"
    }

    private func pill(_ title: String, accent: Color) -> some View {
        Text(title)
            .font(.tasker(.caption2))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(OnboardingTheme.surfaceMuted, in: Capsule())
    }
}

private struct OnboardingFocusTimer: View {
    let startedAt: Date?
    let estimatedDuration: TimeInterval?
    let isActive: Bool

    var body: some View {
        Group {
            if isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    timerBody(valueText: formatted(max(0, Int(timeline.date.timeIntervalSince(startedAt ?? timeline.date)))))
                }
            } else if let startedAt {
                timerBody(valueText: formatted(max(0, Int(Date().timeIntervalSince(startedAt)))))
            } else {
                timerBody(valueText: estimateText)
            }
        }
    }

    private func timerBody(valueText: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(OnboardingTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(labelText)
                    .font(.tasker(.caption2))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                Text(valueText)
                    .font(.tasker(.title2))
                    .foregroundStyle(OnboardingTheme.textPrimary)
            }
            Spacer()
        }
        .padding(16)
        .background(OnboardingTheme.surfaceMuted.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var estimateText: String {
        guard let estimatedDuration, estimatedDuration > 0 else { return "No estimate" }
        let minutes = max(1, Int(estimatedDuration / 60))
        return "\(minutes) min"
    }

    private var labelText: String {
        if isActive {
            return "Time in focus"
        }
        if startedAt != nil {
            return "Focused for"
        }
        return "Suggested focus"
    }

    private func formatted(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

private struct OnboardingSuccessHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(OnboardingTheme.success.opacity(pulse ? 0.18 : 0.12))
                        .frame(width: 68, height: 68)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(OnboardingTheme.success)
                }
                Spacer()
            }

            Text("Your first win is complete.")
                .font(.tasker(.display))
                .foregroundStyle(OnboardingTheme.textPrimary)

            Text("You finished a real first task. Tasker now has enough structure to help you keep moving without rebuilding tomorrow.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .onboardingHeroPanel(cornerRadius: 32)
        .onAppear {
            guard reduceMotion == false else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct OnboardingSuccessSummaryCard: View {
    let areaNames: [String]
    let projectNames: [String]
    let habitTitles: [String]
    let completedTaskTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What’s now in place")
                .font(.tasker(.headline))
                .foregroundStyle(OnboardingTheme.textPrimary)

            VStack(alignment: .leading, spacing: 0) {
                OnboardingSuccessSummaryRow(
                    label: "Areas",
                    value: onboardingNaturalLanguageList(areaNames, fallback: "Your starting areas")
                )

                Divider()
                    .overlay(OnboardingTheme.borderSoft)
                    .padding(.vertical, 16)

                OnboardingSuccessSummaryRow(
                    label: "Projects",
                    value: onboardingNaturalLanguageList(projectNames, fallback: "Your starting projects")
                )

                Divider()
                    .overlay(OnboardingTheme.borderSoft)
                    .padding(.vertical, 16)

                if habitTitles.isEmpty == false {
                    OnboardingSuccessSummaryRow(
                        label: "Habits",
                        value: onboardingNaturalLanguageList(Array(habitTitles.prefix(2)), fallback: "Your starter habits")
                    )

                    Divider()
                        .overlay(OnboardingTheme.borderSoft)
                        .padding(.vertical, 16)
                }

                OnboardingSuccessSummaryRow(
                    label: "First win",
                    value: completedTaskTitle ?? "Your first task"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}

private struct OnboardingSuccessSummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.textSecondary)
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func onboardingNaturalLanguageList(_ items: [String], fallback: String) -> String {
    let cleanedItems = items
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.isEmpty == false }

    switch cleanedItems.count {
    case 0:
        return fallback
    case 1:
        return cleanedItems[0]
    case 2:
        return "\(cleanedItems[0]) and \(cleanedItems[1])"
    default:
        let head = cleanedItems.dropLast().joined(separator: ", ")
        return "\(head), and \(cleanedItems[cleanedItems.count - 1])"
    }
}

private struct OnboardingRevealCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tasker(.headline))
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text(message)
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
        }
        .padding(18)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}

private struct OnboardingReminderCard: View {
    let state: OnboardingReminderPromptState
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Want Tasker to bring this back at the right time?")
                .font(.tasker(.headline))
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text("You can keep going without reminders, or let Tasker quietly surface the next step when momentum drops.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Button(state == .openSettings ? "Open Settings" : "Enable gentle reminders") {
                        onPrimary()
                    }
                    .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)

                    Button("Not now") {
                        onSecondary()
                    }
                    .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button(state == .openSettings ? "Open Settings" : "Enable gentle reminders") {
                        onPrimary()
                    }
                    .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)

                    Button("Not now") {
                        onSecondary()
                    }
                    .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textSecondary)
                }
            }
        }
        .padding(18)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}

private extension View {
    func onboardingHeroPanel(cornerRadius: CGFloat) -> some View {
        background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.borderSoft.opacity(0.95), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, y: 8)
    }

    func onboardingGlassPanel(cornerRadius: CGFloat, shadowOpacity: Double = 0.06) -> some View {
        background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 14, y: 6)
    }

    func onboardingPrimaryButton(disabled: Bool = false) -> some View {
        self
            .disabled(disabled)
            .buttonStyle(OnboardingPrimaryCTAButtonStyle(disabled: disabled))
    }

    func onboardingSecondaryButtonStyle(accent: Color) -> some View {
        self
            .font(.tasker(.buttonSmall))
            .foregroundStyle(accent)
            .frame(minHeight: 44)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
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

extension HabitRepositoryProtocol {
    func fetchAllAsync() async throws -> [HabitDefinitionRecord] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAll { result in
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

extension CreateHabitUseCase {
    func executeAsync(request: CreateHabitRequest) async throws -> HabitDefinitionRecord {
        try await withCheckedThrowingContinuation { continuation in
            execute(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension ManageHabitsUseCase {
    func listAsync() async throws -> [HabitDefinitionRecord] {
        try await withCheckedThrowingContinuation { continuation in
            list { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension CompleteTaskDefinitionUseCase {
    func setCompletionAsync(taskID: UUID, to isComplete: Bool) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            setCompletion(taskID: taskID, to: isComplete) { result in
                continuation.resume(with: result)
            }
        }
    }
}

extension NotificationServiceProtocol {
    func fetchAuthorizationStatusAsync() async -> TaskerNotificationAuthorizationStatus {
        await withCheckedContinuation { continuation in
            fetchAuthorizationStatus { status in
                continuation.resume(returning: status)
            }
        }
    }

    func requestPermissionAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            requestPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
