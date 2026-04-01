import SwiftUI
import UIKit
import Combine
import CoreHaptics

extension Notification.Name {
    static let taskerStartOnboardingRequested = Notification.Name("TaskerStartOnboardingRequested")
}

enum AppOnboardingAccessibilityID {
    static let flow = "onboarding.flow"
    static let welcome = "onboarding.welcome"
    static let lifeAreas = "onboarding.lifeAreas"
    static let projects = "onboarding.projects"
    static let habits = "onboarding.habits"
    static let firstTask = "onboarding.firstTask"
    static let focusRoom = "onboarding.focusRoom"
    static let success = "onboarding.success"
    static let skipButton = "onboarding.skipButton"
    static let startRecommended = "onboarding.cta.startRecommended"
    static let customize = "onboarding.cta.customize"
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
    case welcome
    case lifeAreas
    case projects
    case habits
    case firstTask
    case focusRoom

    var progressIndex: Int { rawValue + 1 }

    var progressLabel: String {
        "Step \(progressIndex) of \(Self.allCases.count)"
    }

    var progressSubtitle: String {
        switch self {
        case .welcome:
            return "Start with a setup you can keep."
        case .lifeAreas:
            return "Choose your starting areas"
        case .projects:
            return "Confirm your starter projects"
        case .habits:
            return "Add one rhythm that makes tomorrow easier."
        case .firstTask:
            return "Pick one tiny task you can finish today."
        case .focusRoom:
            return "Finish your first win"
        }
    }

    var eyebrowTitle: String {
        switch self {
        case .welcome:
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

    var outcomeLabel: String {
        switch self {
        case .welcome:
            return "Tasker will set up a few core areas, suggest one small first task, and help you finish it."
        case .lifeAreas:
            return "Pick 1–3 areas to start with. We preselected a few good options."
        case .projects:
            return "Tasker matched one starter project to each area. Adjust only what feels off."
        case .habits:
            return "Add one gentle habit now, or keep moving and come back later."
        case .firstTask:
            return "Start with something that should take two minutes or less."
        case .focusRoom:
            return "This should only take a moment."
        }
    }

    var accessibilitySummary: String {
        switch self {
        case .welcome:
            return "Welcome. Step 1 of 6."
        case .lifeAreas:
            return "Choose life areas. Step 2 of 6."
        case .projects:
            return "Confirm starter projects. Step 3 of 6."
        case .habits:
            return "Add starter habits. Step 4 of 6."
        case .firstTask:
            return "Pick your first tiny task. Step 5 of 6."
        case .focusRoom:
            return "Finish your first win. Step 6 of 6."
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

    var helperCopy: String {
        switch self {
        case .starting:
            return "Tasker will narrow things to the easiest place to begin."
        case .choosing:
            return "Tasker will cut decisions down and pick sensible defaults."
        case .remembering:
            return "Tasker will bring the next step back when it matters."
        case .finishing:
            return "Tasker will favor steps with an obvious finish line."
        case .overwhelmed:
            return "Tasker will keep the setup light and low-pressure."
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
            dueDateIntent: .today,
            estimatedDuration: TimeInterval(durationMinutes * 60),
            energy: energy,
            category: .general,
            context: .anywhere,
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
            dueDate: DatePreset.today.resolvedDueDate(),
            priority: priority,
            type: type,
            energy: energy,
            category: .general,
            context: .anywhere,
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
    static let allLifeAreas: [StarterLifeAreaTemplate] = [
        StarterLifeAreaTemplate(
            id: "health",
            name: "Health",
            subtitle: "Energy, movement, and recovery",
            icon: "heart.fill",
            colorHex: "#293A18",
            aliases: ["wellness", "fitness", "body"],
            projects: [
                StarterProjectTemplate(
                    id: "health-move",
                    lifeAreaTemplateID: "health",
                    name: "Move your body",
                    summary: "Small movement that gets the day unstuck.",
                    aliases: ["movement", "exercise", "workout"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-health-move-clothes",
                            projectTemplateID: "health-move",
                            title: "Put on workout clothes",
                            reason: "It is small enough to begin and makes the next move easier.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.starting, .overwhelmed]
                        ),
                        StarterTaskTemplate(
                            id: "task-health-move-water",
                            projectTemplateID: "health-move",
                            title: "Fill your water bottle",
                            reason: "It gives you an instant win with a clear done state.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.starting, .remembering]
                        ),
                        StarterTaskTemplate(
                            id: "task-health-move-walk",
                            projectTemplateID: "health-move",
                            title: "Walk for 10 minutes",
                            reason: "A good backup option when you want a little more movement.",
                            durationMinutes: 10,
                            priority: .low,
                            type: .morning,
                            energy: .medium,
                            clearDoneState: true,
                            recommendedProfiles: []
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "health-meal",
                    lifeAreaTemplateID: "health",
                    name: "Meal reset",
                    summary: "Reduce food friction before it gets loud.",
                    aliases: ["food", "meals", "nutrition"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-health-meal-snack",
                            projectTemplateID: "health-meal",
                            title: "Put one easy snack where you can see it",
                            reason: "This lowers the energy needed to make the next decent choice.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.overwhelmed, .remembering]
                        ),
                        StarterTaskTemplate(
                            id: "task-health-meal-list",
                            projectTemplateID: "health-meal",
                            title: "Write one meal idea for tonight",
                            reason: "One concrete choice beats carrying the whole problem around.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.choosing]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "health-sleep",
                    lifeAreaTemplateID: "health",
                    name: "Sleep wind-down",
                    summary: "Tiny cues that make stopping easier later.",
                    aliases: ["sleep", "rest", "bedtime"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-health-sleep-charge",
                            projectTemplateID: "health-sleep",
                            title: "Put your phone on the charger",
                            reason: "One visible action can mark the start of winding down.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .evening,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.remembering, .finishing]
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
            colorHex: "#B1205F",
            aliases: ["work", "job", "business"],
            projects: [
                StarterProjectTemplate(
                    id: "career-ship",
                    lifeAreaTemplateID: "career",
                    name: "Ship one thing",
                    summary: "Keep the next visible output moving.",
                    aliases: ["shipping", "deliverable", "work output"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-career-ship-draft",
                            projectTemplateID: "career-ship",
                            title: "Open the draft and write 3 lines",
                            reason: "It removes the hard part: getting started.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.starting, .overwhelmed]
                        ),
                        StarterTaskTemplate(
                            id: "task-career-ship-message",
                            projectTemplateID: "career-ship",
                            title: "Send one unblocker message",
                            reason: "One message can restart stalled work fast.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.finishing, .choosing]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "career-admin",
                    lifeAreaTemplateID: "career",
                    name: "Work admin reset",
                    summary: "Reduce drag from tiny work chores.",
                    aliases: ["admin", "ops", "cleanup"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-career-admin-email",
                            projectTemplateID: "career-admin",
                            title: "Archive one stale thread",
                            reason: "It closes a loop with almost no setup cost.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.finishing, .remembering]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "career-followups",
                    lifeAreaTemplateID: "career",
                    name: "Follow-ups",
                    summary: "Keep important loose ends from disappearing.",
                    aliases: ["followups", "follow up", "replies"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-career-followups-note",
                            projectTemplateID: "career-followups",
                            title: "Write the name of one person to follow up with",
                            reason: "Capture first, decide the full message second.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.remembering, .overwhelmed]
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
            colorHex: "#FEBF2B",
            aliases: ["household", "space", "apartment"],
            projects: [
                StarterProjectTemplate(
                    id: "home-reset",
                    lifeAreaTemplateID: "home",
                    name: "Home reset",
                    summary: "Quick wins that make your environment easier to re-enter.",
                    aliases: ["reset", "tidy", "cleanup"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-home-reset-five",
                            projectTemplateID: "home-reset",
                            title: "Put away 5 things",
                            reason: "It is concrete, finite, and hard to overthink.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .evening,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.starting, .overwhelmed]
                        ),
                        StarterTaskTemplate(
                            id: "task-home-reset-surface",
                            projectTemplateID: "home-reset",
                            title: "Clear one surface",
                            reason: "One visible patch of calm counts immediately.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .evening,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.finishing, .choosing]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "home-laundry",
                    lifeAreaTemplateID: "home",
                    name: "Laundry / clothes",
                    summary: "Prevent clothes from becoming ambient stress.",
                    aliases: ["laundry", "clothes", "wardrobe"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-home-laundry-basket",
                            projectTemplateID: "home-laundry",
                            title: "Put clothes in one basket",
                            reason: "Gathering counts. Sorting can happen later.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .evening,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.overwhelmed, .remembering]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "home-errands",
                    lifeAreaTemplateID: "home",
                    name: "Errands",
                    summary: "Move one outside-the-house loose end forward.",
                    aliases: ["shopping", "pickup", "store"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-home-errands-note",
                            projectTemplateID: "home-errands",
                            title: "Write one errand in one place",
                            reason: "This gets it out of your head before it vanishes again.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.remembering]
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
            colorHex: "#9E5F0A",
            aliases: ["study", "reading", "practice"],
            projects: [
                StarterProjectTemplate(
                    id: "learning-read",
                    lifeAreaTemplateID: "learning",
                    name: "Read and capture",
                    summary: "Turn a small reading moment into something retained.",
                    aliases: ["read", "reading", "capture"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-learning-read-page",
                            projectTemplateID: "learning-read",
                            title: "Open the book and read 1 page",
                            reason: "The commitment is tiny, but it still counts as re-entry.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.starting, .overwhelmed]
                        ),
                        StarterTaskTemplate(
                            id: "task-learning-read-takeaway",
                            projectTemplateID: "learning-read",
                            title: "Write 1 takeaway from yesterday",
                            reason: "One sentence closes the loop on previous effort.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.finishing]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "learning-study",
                    lifeAreaTemplateID: "learning",
                    name: "Study session",
                    summary: "Short, bounded study bursts.",
                    aliases: ["study session", "course", "class"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-learning-study-open",
                            projectTemplateID: "learning-study",
                            title: "Open the study doc",
                            reason: "Opening the material is often the actual activation barrier.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.starting]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "learning-practice",
                    lifeAreaTemplateID: "learning",
                    name: "Practice block",
                    summary: "Build repetition without needing a huge block of time.",
                    aliases: ["practice", "reps", "drills"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-learning-practice-minute",
                            projectTemplateID: "learning-practice",
                            title: "Do one 2-minute practice round",
                            reason: "You only need enough momentum to begin.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.choosing]
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
            colorHex: "#C11317",
            aliases: ["finance", "finances", "budget"],
            projects: [
                StarterProjectTemplate(
                    id: "money-bills",
                    lifeAreaTemplateID: "money",
                    name: "Bills this week",
                    summary: "Remove uncertainty before it starts compounding.",
                    aliases: ["bills", "payments", "due dates"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-money-bills-date",
                            projectTemplateID: "money-bills",
                            title: "Open one bill and check the due date",
                            reason: "Knowing the date is a real win and lowers dread.",
                            durationMinutes: 2,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.choosing, .overwhelmed]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "money-budget",
                    lifeAreaTemplateID: "money",
                    name: "Budget reset",
                    summary: "Lightweight money awareness without a full planning session.",
                    aliases: ["budget", "spending", "plan"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-money-budget-receipt",
                            projectTemplateID: "money-budget",
                            title: "Move one receipt into one place",
                            reason: "Organizing one input is easier than fixing the whole system.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.remembering]
                        )
                    ]
                ),
                StarterProjectTemplate(
                    id: "money-errands",
                    lifeAreaTemplateID: "money",
                    name: "Financial errands",
                    summary: "Small admin that prevents surprise problems later.",
                    aliases: ["financial errands", "bank", "paperwork"],
                    taskTemplates: [
                        StarterTaskTemplate(
                            id: "task-money-errands-note",
                            projectTemplateID: "money-errands",
                            title: "Write the one money errand you need",
                            reason: "Capturing it now keeps it from turning into background stress.",
                            durationMinutes: 1,
                            priority: .low,
                            type: .morning,
                            energy: .low,
                            clearDoneState: true,
                            recommendedProfiles: [.remembering, .overwhelmed]
                        )
                    ]
                )
            ]
        )
    ]

    static let allHabitTemplates: [StarterHabitTemplate] = [
        StarterHabitTemplate(
            id: "habit-health-water",
            lifeAreaTemplateID: "health",
            projectTemplateID: "health-move",
            title: "Drink water after you wake up",
            reason: "It is easy to remember, takes seconds, and creates a clean start signal.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(hour: 8, minute: 0),
            icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
            notes: "Use a tiny win that helps the next healthy choice happen.",
            recommendedProfiles: [.starting, .remembering, .overwhelmed]
        ),
        StarterHabitTemplate(
            id: "habit-health-charge",
            lifeAreaTemplateID: "health",
            projectTemplateID: "health-sleep",
            title: "Put your phone on the charger before bed",
            reason: "A visible bedtime cue is easier to keep than a full evening routine.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(hour: 21, minute: 30),
            icon: HabitIconMetadata(symbolName: "bed.double.fill", categoryKey: "health"),
            notes: "Make the stop signal obvious.",
            recommendedProfiles: [.remembering, .finishing]
        ),
        StarterHabitTemplate(
            id: "habit-health-no-phone-bed",
            lifeAreaTemplateID: "health",
            projectTemplateID: "health-sleep",
            title: "Keep your phone out of bed",
            reason: "This supports better wind-down without asking for a perfect night.",
            kind: .negative,
            trackingMode: .dailyCheckIn,
            cadence: .daily(hour: 22, minute: 0),
            icon: HabitIconMetadata(symbolName: "moon.zzz.fill", categoryKey: "health"),
            notes: "Recovery matters more than streak perfection.",
            recommendedProfiles: [.remembering, .overwhelmed]
        ),
        StarterHabitTemplate(
            id: "habit-career-plan",
            lifeAreaTemplateID: "career",
            projectTemplateID: "career-ship",
            title: "Choose tomorrow's first work step",
            reason: "Deciding before you stop makes tomorrow easier to begin.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(hour: 17, minute: 30),
            icon: HabitIconMetadata(symbolName: "briefcase.fill", categoryKey: "career"),
            notes: "Keep it to one specific next step.",
            recommendedProfiles: [.choosing, .finishing]
        ),
        StarterHabitTemplate(
            id: "habit-career-followups",
            lifeAreaTemplateID: "career",
            projectTemplateID: "career-followups",
            title: "Check follow-ups every weekday",
            reason: "A light weekday sweep keeps important threads from disappearing.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 16, minute: 0),
            icon: HabitIconMetadata(symbolName: "tray.full.fill", categoryKey: "career"),
            notes: "You are maintaining visibility, not clearing everything.",
            recommendedProfiles: [.remembering, .finishing]
        ),
        StarterHabitTemplate(
            id: "habit-home-reset",
            lifeAreaTemplateID: "home",
            projectTemplateID: "home-reset",
            title: "Do a 2-minute home reset",
            reason: "Short resets lower the cost of coming back to your space later.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(hour: 20, minute: 0),
            icon: HabitIconMetadata(symbolName: "house.fill", categoryKey: "home"),
            notes: "Stop after two minutes even if more is possible.",
            recommendedProfiles: [.starting, .overwhelmed]
        ),
        StarterHabitTemplate(
            id: "habit-home-laundry",
            lifeAreaTemplateID: "home",
            projectTemplateID: "home-laundry",
            title: "Put clothes in one basket each night",
            reason: "One small reset prevents tomorrow's clutter from starting louder.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(hour: 21, minute: 0),
            icon: HabitIconMetadata(symbolName: "tshirt.fill", categoryKey: "home"),
            notes: "Gathering counts. Sorting can stay separate.",
            recommendedProfiles: [.remembering, .overwhelmed]
        ),
        StarterHabitTemplate(
            id: "habit-money-check",
            lifeAreaTemplateID: "money",
            projectTemplateID: "money-budget",
            title: "Check your spending once a week",
            reason: "A short weekly glance is easier to keep than a full budget session.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .weekly(daysOfWeek: [6], hour: 11, minute: 0),
            icon: HabitIconMetadata(symbolName: "dollarsign.circle.fill", categoryKey: "money"),
            notes: "This is for awareness, not judgment.",
            recommendedProfiles: [.choosing, .remembering]
        ),
        StarterHabitTemplate(
            id: "habit-learning-page",
            lifeAreaTemplateID: "learning",
            projectTemplateID: "learning-practice",
            title: "Read one page",
            reason: "A tiny daily dose is easier to keep than waiting for a deep session.",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(hour: 19, minute: 0),
            icon: HabitIconMetadata(symbolName: "book.fill", categoryKey: "learning"),
            notes: "Stop after one page if that is all you have today.",
            recommendedProfiles: [.starting, .overwhelmed]
        )
    ]

    static func lifeAreaTemplate(id: String) -> StarterLifeAreaTemplate? {
        allLifeAreas.first(where: { $0.id == id })
    }

    static func projectTemplate(id: String) -> StarterProjectTemplate? {
        allLifeAreas
            .flatMap(\.projects)
            .first(where: { $0.id == id })
    }

    static func habitTemplate(id: String) -> StarterHabitTemplate? {
        allHabitTemplates.first(where: { $0.id == id })
    }

    static func defaultLifeAreaSelectionIDs(
        for frictionProfile: OnboardingFrictionProfile?,
        mode: OnboardingMode
    ) -> [String] {
        let guided: [String]
        switch frictionProfile {
        case .starting:
            guided = ["health", "career", "home"]
        case .choosing:
            guided = ["career", "home", "health"]
        case .remembering:
            guided = ["home", "career", "money"]
        case .finishing:
            guided = ["career", "home", "money"]
        case .overwhelmed:
            guided = ["home", "health"]
        case .none:
            guided = ["health", "career", "home"]
        }

        if mode == .custom {
            return Array(guided.prefix(1))
        }
        return guided
    }

    static func orderedLifeAreas(for frictionProfile: OnboardingFrictionProfile?) -> [StarterLifeAreaTemplate] {
        let preferredIDs: [String]
        switch frictionProfile {
        case .choosing:
            preferredIDs = ["career", "home", "health", "money", "learning"]
        case .remembering:
            preferredIDs = ["home", "career", "money", "health", "learning"]
        case .finishing:
            preferredIDs = ["career", "home", "money", "health", "learning"]
        case .overwhelmed:
            preferredIDs = ["home", "health", "career", "money", "learning"]
        case .starting:
            preferredIDs = ["health", "career", "home", "learning", "money"]
        case .none:
            preferredIDs = allLifeAreas.map(\.id)
        }

        return preferredIDs.compactMap(lifeAreaTemplate(id:))
    }

    static func visibleLifeAreas(
        for frictionProfile: OnboardingFrictionProfile?,
        showAll: Bool
    ) -> [StarterLifeAreaTemplate] {
        let ordered = orderedLifeAreas(for: frictionProfile)
        let shouldCollapse = frictionProfile == .choosing || frictionProfile == .overwhelmed
        guard shouldCollapse, showAll == false else { return ordered }
        return Array(ordered.prefix(4))
    }

    static func defaultProjectDrafts(
        for selectedLifeAreaIDs: [String],
        mode _: OnboardingMode
    ) -> [OnboardingProjectDraft] {
        var drafts: [OnboardingProjectDraft] = []
        for areaID in selectedLifeAreaIDs {
            guard let area = lifeAreaTemplate(id: areaID),
                  let project = area.projects.first
            else { continue }

            drafts.append(
                OnboardingProjectDraft(
                    lifeAreaTemplateID: area.id,
                    templateID: project.id,
                    name: project.name,
                    summary: project.summary,
                    suggestionTemplateIDs: area.projects.map(\.id),
                    suggestionIndex: 0,
                    isSelected: true
                )
            )
        }
        return drafts
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
        let selectedAreaIDs = Set(projects.map { $0.draft.lifeAreaTemplateID })
        let selectedProjectTemplateIDs = Set(projects.map { $0.draft.templateID })
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
            id: "fallback-\(projectTemplateID)",
            projectTemplateID: projectTemplateID,
            title: "Open this project and pick one next step",
            reason: "A tiny orienting action still counts as motion.",
            durationMinutes: 2,
            priority: .low,
            type: .morning,
            energy: .low,
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
        let template = projectTemplate(id: draft.templateID)
        let candidateNames = Set(([draft.name] + (template?.aliases ?? []) + [template?.name].compactMap { $0 }).map(normalizedName))
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
        score += task.durationMinutes <= 2 ? 40 : 18
        score += task.clearDoneState ? 25 : 0
        score += task.durationMinutes <= 5 ? 10 : 0
        if let frictionProfile, task.recommendedProfiles.contains(frictionProfile) {
            score += 15
        }
        switch frictionProfile {
        case .starting:
            score += task.durationMinutes <= 2 ? 8 : 0
        case .choosing:
            score += task.clearDoneState ? 8 : 0
        case .remembering:
            score += task.title.localizedCaseInsensitiveContains("write") ? 8 : 0
        case .finishing:
            score += task.title.localizedCaseInsensitiveContains("send") ? 6 : 0
            score += task.title.localizedCaseInsensitiveContains("clear") ? 6 : 0
        case .overwhelmed:
            score += task.durationMinutes <= 2 ? 10 : 0
        case .none:
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
        if let frictionProfile,
           habit.recommendedProfiles.contains(frictionProfile) {
            score += 14
        }
        switch habit.cadence {
        case .daily:
            score += 8
        case .weekly:
            score += 4
        }
        if habit.reason.localizedCaseInsensitiveContains("easy")
            || habit.reason.localizedCaseInsensitiveContains("seconds")
            || habit.reason.localizedCaseInsensitiveContains("tiny") {
            score += 6
        }
        return score
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
        frictionProfile == .choosing || frictionProfile == .overwhelmed
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

        step = snapshot.step
        mode = snapshot.mode
        entryContext = snapshot.entryContext
        frictionProfile = snapshot.frictionProfile
        selectedLifeAreaIDs = Set(snapshot.selectedLifeAreaIDs)
        showAllLifeAreas = snapshot.showAllLifeAreas
        projectDrafts = snapshot.projectDrafts
        expandedProjectIDs = Set(snapshot.expandedProjectIDs)
        reminderPromptDismissed = snapshot.reminderPromptDismissed
        resolvedLifeAreas = snapshot.resolvedLifeAreas
        resolvedProjects = snapshot.resolvedProjects
        createdHabits = snapshot.createdHabits
        createdHabitTemplateMap = snapshot.createdHabitTemplateMap
        habitTemplateStates = snapshot.createdHabitTemplateMap.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = .created(entry.value)
        }
        createdTasks = snapshot.createdTasks
        createdTaskTemplateMap = snapshot.createdTaskTemplateMap
        taskTemplateStates = snapshot.createdTaskTemplateMap.reduce(into: [:]) { partialResult, entry in
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
        if step == .welcome {
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
        step = .lifeAreas
        errorMessage = nil
        persistJourney()
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
        nextDrafts.append(contentsOf: StarterWorkspaceCatalog.defaultProjectDrafts(for: missingAreas, mode: mode))
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
            step = .habits
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
                let defaultDraft = StarterWorkspaceCatalog.defaultProjectDrafts(for: [selection.templateID], mode: .guided).first
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
            step = .habits
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
        step = .firstTask
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

    func continueToFocus() {
        guard canContinueToFocus else { return }
        focusTaskID = createdTasks.first(where: { $0.isComplete == false })?.id ?? createdTasks.first?.id
        step = .focusRoom
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
        continueFromHabits()
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

        switch step {
        case .welcome:
            break
        case .lifeAreas:
            step = .welcome
        case .projects:
            step = .lifeAreas
        case .habits:
            step = .projects
        case .firstTask:
            step = .habits
        case .focusRoom:
            step = .firstTask
        }
        persistJourney()
    }

    private func applyDefaults(mode: OnboardingMode, frictionProfile: OnboardingFrictionProfile?) {
        let selection = StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: frictionProfile, mode: mode)
        selectedLifeAreaIDs = Set(selection)
        projectDrafts = StarterWorkspaceCatalog.defaultProjectDrafts(for: selection, mode: mode)
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
                merged.append(contentsOf: StarterWorkspaceCatalog.defaultProjectDrafts(for: [areaID], mode: mode))
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
            ? "Your matched setup is ready for its first rhythm."
            : "Add one rhythm that makes tomorrow easier."
    }

    private var habitsSubtitle: String {
        isEstablishedWorkspaceEntry
            ? "Tasker matched your current areas and projects. Add one habit if it helps, then move into a real first win."
            : "Add one gentle habit now, or keep moving and come back later."
    }

    var body: some View {
        ZStack {
            AppOnboardingBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing.sectionGap) {
                    if let summary = viewModel.successSummary {
                        successView(summary: summary)
                    } else {
                        stepHeader
                        stepBody
                    }
                }
                .frame(maxWidth: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, spacing.s16)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.successSummary != nil || viewModel.step != .focusRoom || viewModel.errorMessage != nil {
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
        }
        .onChange(of: viewModel.successSummary != nil) { _, isShowingSuccess in
            guard isShowingSuccess, hasPlayedSuccess == false else { return }
            hasPlayedSuccess = true
            feedbackController.successSignature()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.flow)
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

                if viewModel.step == .welcome {
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
                    .fill(OnboardingTheme.accent.opacity(0.08))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(OnboardingTheme.accent.opacity(0.9))
                                .frame(width: proxy.size.width * (CGFloat(viewModel.step.progressIndex) / CGFloat(OnboardingStep.allCases.count)))
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
        Group {
            if layoutClass.isPad {
                HStack(alignment: .top, spacing: spacing.s20) {
                    OnboardingWelcomeValueStack()
                        .frame(maxWidth: 320, alignment: .leading)
                    welcomeCustomizationCard
                }
            } else {
                VStack(alignment: .leading, spacing: spacing.sectionGap) {
                    OnboardingWelcomeValueStack()
                    welcomeCustomizationCard
                }
            }
        }
        .accessibilityIdentifier(AppOnboardingAccessibilityID.welcome)
    }

    private var welcomeCustomizationCard: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            Text("What usually gets in your way?")
                .font(.tasker(.headline))
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text("Pick the blocker that sounds most familiar. Tasker will shape the setup around it.")
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.textSecondary)

            OnboardingFrictionSelector(
                selectedProfile: viewModel.frictionProfile,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                onSelect: { profile in
                    feedbackController.selection()
                    viewModel.selectFriction(profile)
                }
            )
        }
        .padding(spacing.s16)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }

    private var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: "Choose your starting areas",
                subtitle: "Pick 1–3 areas to start with. We preselected a few good options.",
                detail: "\(viewModel.selectedLifeAreaIDs.count) selected"
            )

            if viewModel.allowsShowAllAreas, viewModel.showAllLifeAreas == false, StarterWorkspaceCatalog.orderedLifeAreas(for: viewModel.frictionProfile).count > viewModel.visibleLifeAreas.count {
                Button {
                    feedbackController.light()
                    viewModel.showAllAreas()
                } label: {
                    Label("Browse all areas", systemImage: "square.grid.2x2")
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
                title: "Confirm your starter projects",
                subtitle: "Tasker matched one starter project to each area. Adjust only what feels off."
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
                        Text("Start with a habit that already fits your life.")
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
                title: "Pick one tiny task you can finish today.",
                subtitle: "Start with something that should take two minutes or less."
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

    @ViewBuilder
    private var bottomDock: some View {
        VStack(spacing: spacing.s12) {
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
                            Text("Start recommended setup")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton()
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.startRecommended)

                        Button("Customize setup") {
                            feedbackController.light()
                            viewModel.begin(mode: .custom)
                        }
                        .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.customize)
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
                            Text("Continue to first task")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton()
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.useHabits)
                    }
                case .firstTask:
                    VStack(spacing: spacing.s8) {
                        Button {
                            feedbackController.medium()
                            viewModel.continueToFocus()
                        } label: {
                            Text(viewModel.canContinueToFocus ? "Start this first win" : "Choose a first win")
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
        .padding(.horizontal, horizontalPadding)
        .padding(.top, spacing.s12)
        .padding(.bottom, max(spacing.s8, 8))
        .background(
            OnboardingTheme.canvas
                .opacity(0.98)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(OnboardingTheme.borderSoft.opacity(0.8))
                        .frame(height: 1)
                }
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
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
            Text("Start with a setup you can keep.")
                .font(.tasker(.display))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tasker will set up a few core areas, suggest one small first task, and help you finish it.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("You can add one starter habit too, so tomorrow feels easier without adding more overhead.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingTrustRow(items: [
                ("sparkles.rectangle.stack", "Real setup"),
                ("clock", "~2 min"),
                ("arrow.uturn.backward.circle", "Reversible")
            ])
        }
        .padding(22)
        .onboardingHeroPanel(cornerRadius: 32)
    }
}

private struct OnboardingFrictionSelector: View {
    let selectedProfile: OnboardingFrictionProfile?
    let isAccessibilitySize: Bool
    let onSelect: (OnboardingFrictionProfile) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    optionCards
                }
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    optionCards
                }
            }

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: selectedProfile == nil ? "sparkles" : "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selectedProfile == nil ? OnboardingTheme.textSecondary : OnboardingTheme.accent)

                Text(selectedProfile?.helperCopy ?? "Tasker will shape the setup around whichever blocker feels most familiar.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .lineLimit(isAccessibilitySize ? nil : 1)
                    .contentTransition(.opacity)
                    .id(selectedProfile?.id ?? "none")
            }
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .padding(.top, 2)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.2), value: selectedProfile)
        }
    }

    @ViewBuilder
    private var optionCards: some View {
        ForEach(OnboardingFrictionProfile.allCases) { profile in
            OnboardingFrictionOptionCard(
                title: profile.title,
                isSelected: selectedProfile == profile,
                action: {
                    onSelect(profile)
                }
            )
            .accessibilityHint(profile.helperCopy)
        }
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(isSelected ? OnboardingTheme.textPrimary : OnboardingTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.border)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                isSelected ? OnboardingTheme.accent.opacity(0.10) : OnboardingTheme.surfaceMuted,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? OnboardingTheme.accent.opacity(0.34) : OnboardingTheme.borderSoft, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(OnboardingPressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            .font(.tasker(.button))
            .foregroundStyle(Color.white)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(
                disabled ? OnboardingTheme.textSecondary.opacity(0.4) : OnboardingTheme.accent,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(disabled ? .clear : Color.white.opacity(0.14), lineWidth: 1)
            )
            .disabled(disabled)
            .buttonStyle(.plain)
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
