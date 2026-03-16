import SwiftUI
import UIKit
import Combine
import CoreHaptics

extension Notification.Name {
    static let taskerStartOnboardingRequested = Notification.Name("TaskerStartOnboardingRequested")
}

private func onboardingLogLine(event: String, message: String? = nil, fields: [String: String] = [:]) -> String {
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

enum OnboardingStep: Int, CaseIterable, Codable {
    case welcome
    case lifeAreas
    case projects
    case firstTask
    case focusRoom

    var progressIndex: Int { rawValue + 1 }

    var progressLabel: String {
        "Step \(progressIndex) of \(Self.allCases.count)"
    }

    var progressSubtitle: String {
        switch self {
        case .welcome:
            return "A quick real setup"
        case .lifeAreas:
            return "Choose your starting areas"
        case .projects:
            return "Confirm starter projects"
        case .firstTask:
            return "Pick one tiny task"
        case .focusRoom:
            return "Complete your first win"
        }
    }

    var accessibilitySummary: String {
        switch self {
        case .welcome:
            return "Welcome. Step 1 of 5."
        case .lifeAreas:
            return "Choose life areas. Step 2 of 5."
        case .projects:
            return "Confirm starter projects. Step 3 of 5."
        case .firstTask:
            return "Pick your first tiny task. Step 4 of 5."
        case .focusRoom:
            return "Focus room. Step 5 of 5."
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
            return "Starting"
        case .choosing:
            return "Choosing"
        case .remembering:
            return "Remembering"
        case .finishing:
            return "Finishing"
        case .overwhelmed:
            return "Overwhelmed"
        }
    }

    var helperCopy: String {
        switch self {
        case .starting:
            return "We’ll suggest the easiest possible first step."
        case .choosing:
            return "We’ll reduce options and recommend a default path."
        case .remembering:
            return "We’ll help you bring things back at the right time."
        case .finishing:
            return "We’ll bias toward tasks with clear done-states."
        case .overwhelmed:
            return "We’ll keep your first setup extra small."
        }
    }
}

enum OnboardingMode: String, Codable, Equatable {
    case guided
    case custom
}

enum OnboardingTaskTemplateState: Equatable {
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
    let createdTaskCount: Int
    let completedTaskCount: Int
    let completedTaskTitle: String?
    let nextTaskTitle: String?
    let promptReminderAfterSuccess: Bool
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
    var schemaVersion: Int = 2
    var step: OnboardingStep
    var mode: OnboardingMode
    var frictionProfile: OnboardingFrictionProfile?
    var selectedLifeAreaIDs: [String]
    var showAllLifeAreas: Bool
    var projectDrafts: [OnboardingProjectDraft]
    var expandedProjectIDs: [UUID] = []
    var resolvedLifeAreas: [ResolvedLifeAreaSelection]
    var resolvedProjects: [ResolvedProjectSelection]
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
    case prompt
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
                            reason: "You get an instant physical win and a visible done-state.",
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
                            reason: "It removes the hard part: starting from closed.",
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
                            reason: "A single message can restart stalled work fast.",
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

    static func lifeAreaTemplate(id: String) -> StarterLifeAreaTemplate? {
        allLifeAreas.first(where: { $0.id == id })
    }

    static func projectTemplate(id: String) -> StarterProjectTemplate? {
        allLifeAreas
            .flatMap(\.projects)
            .first(where: { $0.id == id })
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
        mode: OnboardingMode
    ) -> [OnboardingProjectDraft] {
        selectedLifeAreaIDs.compactMap(lifeAreaTemplate(id:)).flatMap { area in
            let templateIDs = area.projects.map(\.id)
            let initial = Array(area.projects.prefix(2))
            return initial.enumerated().map { index, project in
                OnboardingProjectDraft(
                    lifeAreaTemplateID: area.id,
                    templateID: project.id,
                    name: project.name,
                    summary: project.summary,
                    suggestionTemplateIDs: templateIDs,
                    suggestionIndex: index,
                    isSelected: mode == .guided || initial.count == 1 || index < 2
                )
            }
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
    private let fetchTask: (UUID) async throws -> TaskDefinition?
    private let createLifeArea: (StarterLifeAreaTemplate) async throws -> LifeArea
    private let createProject: (OnboardingProjectDraft, LifeArea) async throws -> Project
    private let createTask: (CreateTaskDefinitionRequest) async throws -> TaskDefinition
    private let setTaskCompletion: (UUID, Bool) async throws -> TaskDefinition

    @Published var step: OnboardingStep = .welcome
    @Published var mode: OnboardingMode = .guided
    @Published var frictionProfile: OnboardingFrictionProfile?
    @Published var selectedLifeAreaIDs: Set<String> = []
    @Published var showAllLifeAreas = false
    @Published var projectDrafts: [OnboardingProjectDraft] = []
    @Published var expandedProjectIDs: Set<UUID> = []
    @Published var reminderPromptDismissed = false
    @Published private(set) var resolvedLifeAreas: [ResolvedLifeAreaSelection] = []
    @Published private(set) var resolvedProjects: [ResolvedProjectSelection] = []
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
        fetchTask: @escaping (UUID) async throws -> TaskDefinition? = { _ in nil },
        createLifeArea: @escaping (StarterLifeAreaTemplate) async throws -> LifeArea = { template in
            LifeArea(name: template.name, color: template.colorHex, icon: template.icon)
        },
        createProject: @escaping (OnboardingProjectDraft, LifeArea) async throws -> Project = { draft, lifeArea in
            Project(lifeAreaID: lifeArea.id, name: draft.name, projectDescription: draft.summary)
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
        self.fetchTask = fetchTask
        self.createLifeArea = createLifeArea
        self.createProject = createProject
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
        projectDrafts.filter(\.isSelected)
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
            step = .welcome
            successSummary = nil
            persistJourney()
            return
        }

        step = snapshot.step
        mode = snapshot.mode
        frictionProfile = snapshot.frictionProfile
        selectedLifeAreaIDs = Set(snapshot.selectedLifeAreaIDs)
        showAllLifeAreas = snapshot.showAllLifeAreas
        projectDrafts = snapshot.projectDrafts
        expandedProjectIDs = Set(snapshot.expandedProjectIDs)
        reminderPromptDismissed = snapshot.reminderPromptDismissed
        resolvedLifeAreas = snapshot.resolvedLifeAreas
        resolvedProjects = snapshot.resolvedProjects
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
            Task { [weak self] in
                await self?.refreshReminderPromptState()
            }
        }
    }

    func resetForReplay() {
        step = .welcome
        mode = .guided
        frictionProfile = nil
        showAllLifeAreas = false
        resolvedLifeAreas = []
        resolvedProjects = []
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
        applyDefaults(mode: .guided, frictionProfile: nil)
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
            clearTasksAndFocus()
            step = .firstTask
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
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

        switch step {
        case .welcome:
            break
        case .lifeAreas:
            step = .welcome
        case .projects:
            step = .lifeAreas
        case .firstTask:
            step = .projects
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
            let drafts = existingByArea[areaID]?.filter(\.isSelected) ?? []
            if drafts.isEmpty {
                merged.append(contentsOf: StarterWorkspaceCatalog.defaultProjectDrafts(for: [areaID], mode: mode))
            } else {
                merged.append(contentsOf: Array(drafts.prefix(2)))
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

    private func buildSummary(completedTask: TaskDefinition) -> AppOnboardingSummary {
        let completedCount = createdTasks.filter(\.isComplete).count
        let nextTaskTitle = nextOpenTask?.title
        return AppOnboardingSummary(
            lifeAreaCount: resolvedLifeAreas.count,
            projectCount: resolvedProjects.count,
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
            frictionProfile: frictionProfile,
            selectedLifeAreaIDs: StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile)
                .map(\.id)
                .filter { selectedLifeAreaIDs.contains($0) },
            showAllLifeAreas: showAllLifeAreas,
            projectDrafts: projectDrafts,
            expandedProjectIDs: Array(expandedProjectIDs),
            resolvedLifeAreas: resolvedLifeAreas,
            resolvedProjects: resolvedProjects,
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
final class AppOnboardingCoordinator: NSObject {
    private weak var homeViewController: HomeViewController?
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
        self.homeViewController = homeViewController
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
            case .promptOnly:
                self.enqueuePresentation(.prompt)
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
                    "blocked_by_presented_controller": String(homeViewController?.presentedViewController != nil)
                ]
            )
        }

        drainPendingPresentationIfPossible()
    }

    @discardableResult
    private func attemptPresentation(_ presentation: PendingOnboardingPresentation, source: String) -> Bool {
        let presented: Bool
        switch presentation {
        case .prompt:
            presented = presentPromptIfPossible()
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

    private func presentPromptIfPossible() -> Bool {
        guard promptHost == nil else { return false }
        guard let homeViewController, homeViewController.presentedViewController == nil else { return false }

        let controller = UIHostingController(
            rootView: AnyView(
                AppOnboardingPromptSheetView(
                    onStart: { [weak self] in
                        self?.dismissPrompt(animated: true) {
                            self?.enqueuePresentation(.fullFlow(source: "prompt_opt_in"))
                        }
                    },
                    onNotNow: { [weak self] in
                        self?.stateStore.markEstablishedWorkspacePromptDismissed()
                        self?.dismissPrompt(animated: true, completion: nil)
                    }
                )
                .taskerLayoutClass(homeViewController.currentOnboardingLayoutClass)
            )
        )
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 30
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
        guard onboardingHost == nil else { return false }
        guard let homeViewController, homeViewController.presentedViewController == nil else { return false }

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
            onEditTask: { [weak self] task in
                self?.presentTaskEditor(task: task) ?? false
            },
            onDismissFlow: { [weak self] in
                self?.dismissFullFlow(animated: true)
            }
        )
        .taskerLayoutClass(homeViewController.currentOnboardingLayoutClass)

        let controller = UIHostingController(rootView: AnyView(rootView))
        controller.modalPresentationStyle = .fullScreen
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

    private func presentCustomTaskComposer(prefill: AddTaskPrefillTemplate) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = homeViewController?.makeOnboardingAddTaskController(
            prefill: prefill,
            onTaskCreated: { [weak self] taskID in
                Task { @MainActor [weak self] in
                    await self?.viewModel.registerCustomCreatedTask(taskID: taskID)
                }
            }
        ) else { return false }
        onboardingHost.present(controller, animated: true)
        return true
    }

    private func presentTaskEditor(task: TaskDefinition) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = homeViewController?.makeOnboardingTaskDetailController(
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
        homeViewController?.presentedViewController != nil
    }
}

struct AppOnboardingJourneyView: View {
    @ObservedObject var viewModel: OnboardingFlowModel
    let feedbackController: OnboardingFeedbackController
    let onOpenCustomTaskComposer: (AddTaskPrefillTemplate) -> Bool
    let onEditTask: (TaskDefinition) -> Bool
    let onDismissFlow: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @State private var renamingProjectIDs: Set<UUID> = []
    @State private var hasPlayedSuccess = false

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var horizontalPadding: CGFloat {
        layoutClass.isPad ? 32 : spacing.screenHorizontal
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
                .frame(maxWidth: layoutClass.isPad ? 760 : .infinity, alignment: .leading)
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
        .interactiveDismissDisabled(true)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.gentle, value: viewModel.step)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.gentle, value: viewModel.successSummary != nil)
        .onAppear {
            feedbackController.prepare()
        }
        .onChange(of: viewModel.successSummary != nil) { _, isShowingSuccess in
            guard isShowingSuccess, hasPlayedSuccess == false else { return }
            hasPlayedSuccess = true
            feedbackController.successSignature()
        }
        .accessibilityIdentifier("onboarding.flow")
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
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
                    .buttonStyle(.plain)
                }

                Spacer()

                if viewModel.step == .welcome {
                    Button("Skip") {
                        feedbackController.light()
                        Task {
                            await viewModel.skipToFocusRoom()
                        }
                    }
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.skipButton")
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.step.progressLabel)
                        .font(.tasker(.headline))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                    Text(viewModel.step.progressSubtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }

                Spacer()

                Capsule()
                    .fill(OnboardingTheme.accent.opacity(0.08))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(OnboardingTheme.accent.opacity(0.85))
                                .frame(width: proxy.size.width * (CGFloat(viewModel.step.progressIndex) / CGFloat(OnboardingStep.allCases.count)))
                        }
                    }
                    .frame(width: layoutClass.isPad ? 170 : 120, height: 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Onboarding progress")
                    .accessibilityValue(viewModel.step.accessibilitySummary)
            }
            .padding(.horizontal, spacing.s16)
            .padding(.vertical, spacing.s12)
            .onboardingGlassPanel(cornerRadius: 26)
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch viewModel.step {
        case .welcome:
            welcomeStep
        case .lifeAreas:
            lifeAreasStep
                .accessibilityIdentifier("onboarding.lifeAreas")
        case .projects:
            projectsStep
                .accessibilityIdentifier("onboarding.projects")
        case .firstTask:
            firstTaskStep
                .accessibilityIdentifier("onboarding.firstTask")
        case .focusRoom:
            focusRoomStep
                .accessibilityIdentifier("onboarding.focusRoom")
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                OnboardingHeroAccent(title: "Let’s get you one small win.", subtitle: "In about 2 minutes, Tasker will set up a few starting areas, suggest one tiny task, and help you finish it today.")

                Text("No fake tutorial. Everything you do here is real.")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(OnboardingTheme.textPrimary)

                VStack(alignment: .leading, spacing: spacing.s12) {
                    Text("What gets in your way most often?")
                        .font(.tasker(.headline))
                        .foregroundStyle(OnboardingTheme.textPrimary)

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            ForEach(OnboardingFrictionProfile.allCases) { profile in
                                OnboardingChoiceChip(
                                    title: profile.title,
                                    isSelected: viewModel.frictionProfile == profile,
                                    allowsMultiline: true
                                ) {
                                    feedbackController.selection()
                                    viewModel.selectFriction(profile)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        ViewThatFits(in: .vertical) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: spacing.s8) {
                                    ForEach(OnboardingFrictionProfile.allCases) { profile in
                                        OnboardingChoiceChip(
                                            title: profile.title,
                                            isSelected: viewModel.frictionProfile == profile
                                        ) {
                                            feedbackController.selection()
                                            viewModel.selectFriction(profile)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            VStack(alignment: .leading, spacing: spacing.s8) {
                                ForEach(OnboardingFrictionProfile.allCases) { profile in
                                    OnboardingChoiceChip(
                                        title: profile.title,
                                        isSelected: viewModel.frictionProfile == profile
                                    ) {
                                        feedbackController.selection()
                                        viewModel.selectFriction(profile)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    if let profile = viewModel.frictionProfile {
                        Text(profile.helperCopy)
                            .font(.tasker(.caption1))
                            .foregroundStyle(OnboardingTheme.textPrimary)
                    }

                    Text("Optional. This helps Tasker suggest a better first setup.")
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
            }
            .accessibilityIdentifier("onboarding.welcome")
        }
    }

    private var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: "Pick 1–3 parts of life to start with.",
                subtitle: viewModel.frictionProfile == .overwhelmed
                    ? "We preselected a calmer starting set. Change it if you want. You can change everything later."
                    : "We preselected a few good starting places. Change them if you want."
            )

            if viewModel.allowsShowAllAreas, viewModel.showAllLifeAreas == false, StarterWorkspaceCatalog.orderedLifeAreas(for: viewModel.frictionProfile).count > viewModel.visibleLifeAreas.count {
                Button("Show all areas") {
                    feedbackController.light()
                    viewModel.showAllAreas()
                }
                .font(.tasker(.buttonSmall))
                .foregroundStyle(OnboardingTheme.success)
                .buttonStyle(.plain)
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
                    .accessibilityIdentifier("onboarding.lifeArea.\(area.id)")
                }
            }

            Text("You can change this later.")
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .padding(.bottom, spacing.s16)
        }
    }

    private var projectsStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: "We suggested a few starter projects.",
                subtitle: "Keep them, rename them, or swap them. You can change all of this later."
            )

            ForEach(viewModel.selectedLifeAreas) { area in
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Text(area.name)
                        .font(.tasker(.headline))
                        .foregroundStyle(OnboardingTheme.textPrimary)

                    let drafts = viewModel.projectDrafts.filter { $0.lifeAreaTemplateID == area.id }
                    ForEach(drafts) { draft in
                        OnboardingProjectDraftCard(
                            draft: draft,
                            colorHex: area.colorHex,
                            icon: area.icon,
                            mode: viewModel.mode,
                            isExpanded: viewModel.expandedProjectIDs.contains(draft.id),
                            isRenaming: renamingProjectIDs.contains(draft.id),
                            nameBinding: Binding(
                                get: {
                                    viewModel.projectDrafts.first(where: { $0.id == draft.id })?.name ?? draft.name
                                },
                                set: { viewModel.renameProjectDraft(draft.id, to: $0) }
                            ),
                            onToggleSelection: {
                                feedbackController.selection()
                                viewModel.toggleProjectDraft(draft.id)
                            },
                            onToggleExpanded: {
                                feedbackController.light()
                                viewModel.toggleProjectEditExpansion(draft.id)
                            },
                            onRename: {
                                feedbackController.light()
                                if viewModel.expandedProjectIDs.contains(draft.id) == false {
                                    viewModel.toggleProjectEditExpansion(draft.id)
                                }
                                if renamingProjectIDs.contains(draft.id) {
                                    renamingProjectIDs.remove(draft.id)
                                } else {
                                    renamingProjectIDs.insert(draft.id)
                                }
                            },
                            onSwap: {
                                feedbackController.light()
                                viewModel.cycleProjectSuggestion(draft.id)
                            }
                        )
                    }
                }
            }
        }
    }

    private var firstTaskStep: some View {
        let highlightedPrimaryTemplateID = TaskerCTABezelResolver.highlightedOnboardingTemplateID(
            primarySuggestionIDs: viewModel.primaryTaskSuggestions.map(\.id),
            taskTemplateStates: viewModel.taskTemplateStates
        )

        return VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: "Pick one tiny task you can actually finish today.",
                subtitle: "Start with something that takes 2 minutes or less."
            )

            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Best first wins")
                    .font(.tasker(.headline))
                    .foregroundStyle(OnboardingTheme.textPrimary)

                ForEach(viewModel.primaryTaskSuggestions) { template in
                    OnboardingTaskRecommendationCard(
                        template: template,
                        state: viewModel.taskTemplateStates[template.id] ?? .idle,
                        isGuidanceHighlighted: template.id == highlightedPrimaryTemplateID,
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
                    .accessibilityIdentifier("onboarding.taskTemplate.\(template.id)")
                }
            }

            if viewModel.secondaryTaskSuggestions.isEmpty == false {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Text("More ideas")
                        .font(.tasker(.headline))
                        .foregroundStyle(OnboardingTheme.textPrimary)

                    ForEach(viewModel.secondaryTaskSuggestions) { template in
                        OnboardingTaskRecommendationCard(
                            template: template,
                            state: viewModel.taskTemplateStates[template.id] ?? .idle,
                            isGuidanceHighlighted: false,
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
                        .accessibilityIdentifier("onboarding.taskTemplate.\(template.id)")
                    }
                }
            }

            Button("Write my own instead") {
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
            }
            .font(.tasker(.buttonSmall))
            .foregroundStyle(OnboardingTheme.accent)
            .buttonStyle(.plain)
        }
    }

    private var focusRoomStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: "Finish this now.",
                subtitle: "One real completion unlocks your starting momentum."
            )

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
            OnboardingSuccessHero(completedTaskTitle: summary.completedTaskTitle)
                .accessibilityIdentifier("onboarding.success")

            LazyVGrid(
                columns: [GridItem(.flexible(minimum: 120), spacing: spacing.s12), GridItem(.flexible(minimum: 120), spacing: spacing.s12)],
                spacing: spacing.s12
            ) {
                OnboardingMetricCard(value: "\(summary.lifeAreaCount)", label: "life areas ready")
                OnboardingMetricCard(value: "\(summary.projectCount)", label: "projects in place")
                OnboardingMetricCard(value: "\(summary.completedTaskCount)", label: "tasks completed")
                OnboardingMetricCard(value: summary.nextTaskTitle == nil ? "0" : "1", label: "next task waiting")
            }
            .padding(.vertical, spacing.s8)
            .padding(.horizontal, spacing.s8)
            .onboardingGlassPanel(cornerRadius: 28)

            VStack(alignment: .leading, spacing: spacing.s12) {
                OnboardingRevealCard(title: "Focus Now", message: "Tasker will keep surfacing the next easiest win.")
                OnboardingRevealCard(title: "XP and momentum", message: "Small wins earn XP. Progress matters more than perfection.")
                OnboardingRevealCard(title: "AI coach", message: "Feeling stuck again? Ask your AI coach to break down, plan, or rewrite your next task.")
                OnboardingRevealCard(title: "Analytics later", message: "After a few more completions, Tasker will start showing patterns in your consistency and momentum.")
            }

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

            Text("You can reset this guided setup later from Settings without losing your data.")
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.textSecondary)
        }
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

    @ViewBuilder
    private var bottomDock: some View {
        VStack(spacing: spacing.s8) {
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
                        Text("Go to my Home")
                            .frame(maxWidth: .infinity)
                    }
                    .onboardingPrimaryButton()
                    .accessibilityIdentifier("onboarding.cta.goHome")

                    if viewModel.nextOpenTask != nil {
                        Button("Ask your AI coach to break this down") {
                            feedbackController.light()
                            Task { await viewModel.breakDownNextTask() }
                        }
                        .font(.tasker(.buttonSmall))
                        .foregroundStyle(OnboardingTheme.accent)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.cta.breakdownNext")
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
                            Text("Start with recommended setup")
                                .frame(maxWidth: .infinity)
                        }
                        .onboardingPrimaryButton()
                        .accessibilityIdentifier("onboarding.cta.startRecommended")

                        Button("Customize instead") {
                            feedbackController.light()
                            viewModel.begin(mode: .custom)
                        }
                        .font(.tasker(.buttonSmall))
                        .foregroundStyle(OnboardingTheme.accent)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.cta.customize")
                    }
                case .lifeAreas:
                    Button {
                        feedbackController.medium()
                        Task { await viewModel.continueFromLifeAreas() }
                    } label: {
                        Text(viewModel.isWorking ? "Setting up your areas…" : "Use these areas")
                            .frame(maxWidth: .infinity)
                    }
                    .onboardingPrimaryButton(disabled: viewModel.canContinueLifeAreas == false || viewModel.isWorking)
                    .accessibilityIdentifier("onboarding.cta.useAreas")
                case .projects:
                    Button {
                        feedbackController.medium()
                        Task { await viewModel.continueFromProjects() }
                    } label: {
                        Text(viewModel.isWorking ? "Setting up your projects…" : "Use these projects")
                            .frame(maxWidth: .infinity)
                    }
                    .onboardingPrimaryButton(disabled: viewModel.canContinueProjects == false || viewModel.isWorking)
                    .accessibilityIdentifier("onboarding.cta.useProjects")
                case .firstTask:
                    Button {
                        feedbackController.medium()
                        viewModel.continueToFocus()
                    } label: {
                        Text("Go finish this task")
                            .frame(maxWidth: .infinity)
                    }
                    .onboardingPrimaryButton(disabled: viewModel.canContinueToFocus == false || viewModel.isWorking)
                    .accessibilityIdentifier("onboarding.cta.goFinishTask")
                case .focusRoom:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, spacing.s8)
        .padding(.bottom, max(spacing.s8, 8))
        .background(
            Color.clear
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                }
                .onboardingGlassPanel(cornerRadius: 30, shadowOpacity: 0.06)
                .ignoresSafeArea(edges: .bottom)
        )
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
                OnboardingHeroAccent(
                    title: "Let’s shape what you already have into a calmer starting point.",
                    subtitle: "Tasker can reuse matching life areas and projects, suggest one tiny task, and guide you to one real completion."
                )

                Text("No duplicate clutter. No fake setup. Just one clearer starting path.")
                    .font(.tasker(.body))
                    .foregroundStyle(OnboardingTheme.textSecondary)

                VStack(spacing: spacing.s12) {
                    Button {
                        onStart()
                    } label: {
                        Text("Start with recommended setup")
                            .frame(maxWidth: .infinity)
                    }
                    .onboardingPrimaryButton()
                    .accessibilityIdentifier("onboarding.prompt.start")

                    Button("Not now") {
                        onNotNow()
                    }
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(OnboardingTheme.accent)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.prompt.dismiss")
                }
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 40, 560), alignment: .leading)
            .padding(spacing.s20)
            .onboardingGlassPanel(cornerRadius: 30)
            .padding(.horizontal, spacing.screenHorizontal)
        }
        .interactiveDismissDisabled(true)
        .accessibilityIdentifier("onboarding.prompt")
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
    static let surface = Color.tasker(.surfacePrimary).opacity(0.92)
    static let surfaceMuted = Color.tasker(.surfaceSecondary).opacity(0.88)
    static let border = Color.tasker(.borderDefault)
    static let textPrimary = Color.tasker(.textPrimary)
    static let textSecondary = Color.tasker(.textSecondary)
    static let accent = Color.tasker(.brandSecondary)
    static let accentSecondary = Color.tasker(.brandHighlight)
    static let success = Color.tasker(.statusSuccess)
    static let danger = Color.tasker(.statusDanger)
}

private struct AppOnboardingBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [OnboardingTheme.canvas, OnboardingTheme.canvasSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(OnboardingTheme.accent.opacity(drift ? 0.12 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 24)
                .offset(x: drift ? -120 : -80, y: -220)

            Circle()
                .fill(OnboardingTheme.accentSecondary.opacity(drift ? 0.12 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 28)
                .offset(x: drift ? 120 : 90, y: 280)
        }
        .onAppear {
            guard reduceMotion == false else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

private struct OnboardingSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tasker(.display))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingHeroAccent: View {
    let title: String
    let subtitle: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(OnboardingTheme.accent.opacity(glow ? 0.25 : 0.16))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Relief first")
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.accent)
                }
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
        .padding(20)
        .onboardingGlassPanel(cornerRadius: 30)
        .onAppear {
            guard reduceMotion == false else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

private struct OnboardingChoiceChip: View {
    let title: String
    let isSelected: Bool
    let allowsMultiline: Bool
    let action: () -> Void

    init(title: String, isSelected: Bool, allowsMultiline: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.allowsMultiline = allowsMultiline
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(OnboardingTheme.accent)
                }
                Text(title)
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(isSelected ? OnboardingTheme.textPrimary : OnboardingTheme.textSecondary)
                    .lineLimit(allowsMultiline ? 2 : 1)
                    .fixedSize(horizontal: allowsMultiline == false, vertical: allowsMultiline)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isSelected ? OnboardingTheme.accent.opacity(0.16) : OnboardingTheme.surfaceMuted, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? OnboardingTheme.accent.opacity(0.85) : OnboardingTheme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
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
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.textSecondary)
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

                Text(isSelected ? "Selected" : "Tap to select")
                    .font(.tasker(.caption2))
                    .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.textSecondary.opacity(0.8))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? OnboardingTheme.accent.opacity(0.16) : OnboardingTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? OnboardingTheme.accent.opacity(0.95) : OnboardingTheme.border, lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected && reduceMotion == false ? 1.015 : 1)
            .shadow(color: isSelected ? OnboardingTheme.accent.opacity(0.14) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(subtitle)
        .animation(reduceMotion ? .none : TaskerAnimation.stateChange, value: isSelected)
    }
}

private struct OnboardingProjectDraftCard: View {
    let draft: OnboardingProjectDraft
    let colorHex: String
    let icon: String
    let mode: OnboardingMode
    let isExpanded: Bool
    let isRenaming: Bool
    let nameBinding: Binding<String>
    let onToggleSelection: () -> Void
    let onToggleExpanded: () -> Void
    let onRename: () -> Void
    let onSwap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: UIColor(taskerHex: colorHex)).opacity(draft.isSelected ? 0.18 : 0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .foregroundStyle(Color(uiColor: UIColor(taskerHex: colorHex)))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if mode == .custom || isRenaming {
                        TextField("Project name", text: nameBinding)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(OnboardingTheme.textPrimary)
                    } else {
                        Text(draft.name)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(OnboardingTheme.textPrimary)
                    }
                    Text(draft.summary)
                        .font(.tasker(.caption1))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(draft.isSelected ? OnboardingTheme.accent : OnboardingTheme.textSecondary)
            }

            if isExpanded {
                HStack(spacing: 16) {
                    Button(draft.isSelected ? "Remove" : "Keep") {
                        onToggleSelection()
                    }
                    .buttonStyle(.plain)
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(OnboardingTheme.accent)

                    Button(isRenaming ? "Done" : "Rename") {
                        onRename()
                    }
                    .buttonStyle(.plain)
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(OnboardingTheme.textSecondary)

                    Button("Swap") {
                        onSwap()
                    }
                    .buttonStyle(.plain)
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(OnboardingTheme.textSecondary)

                    Spacer()

                    Button("Close") {
                        onToggleExpanded()
                    }
                    .buttonStyle(.plain)
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                }
            } else {
                HStack {
                    Spacer()
                    Button("Edit") {
                        onToggleExpanded()
                    }
                    .buttonStyle(OnboardingPressScaleButtonStyle())
                    .font(.tasker(.buttonSmall))
                    .foregroundStyle(OnboardingTheme.accent)
                    .accessibilityLabel("Edit project")
                }
            }
        }
        .padding(14)
        .background(draft.isSelected ? OnboardingTheme.surface : OnboardingTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(draft.isSelected ? OnboardingTheme.accent.opacity(0.7) : OnboardingTheme.border, lineWidth: draft.isSelected ? 1.5 : 1)
        )
        .accessibilityElement(children: .contain)
        .animation(.easeOut(duration: 0.22), value: isExpanded)
    }
}

private struct OnboardingTaskRecommendationCard: View {
    let template: StarterTaskTemplate
    let state: OnboardingTaskTemplateState
    let isGuidanceHighlighted: Bool
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
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                Text("\(template.durationMinutes) min")
                    .font(.tasker(.caption2))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OnboardingTheme.surfaceMuted, in: Capsule())

                Text("+\(XPCalculationEngine.completionXPIfCompletedNow(priorityRaw: template.priority.rawValue, estimatedDuration: TimeInterval(template.durationMinutes * 60), dueDate: DatePreset.today.resolvedDueDate(), dailyEarnedSoFar: 0, isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled).awardedXP) XP")
                    .font(.tasker(.caption2))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OnboardingTheme.surfaceMuted, in: Capsule())

                Spacer()

                actionButton
            }
        }
        .padding(14)
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
                Button("Edit") {
                    onEdit()
                }
                .font(.tasker(.buttonSmall))
                .foregroundStyle(OnboardingTheme.accent)
                .buttonStyle(OnboardingPressScaleButtonStyle())
            default:
                Button {
                    onAdd()
                } label: {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .labelStyle(.titleAndIcon)
                        .font(.tasker(.buttonSmall))
                        .padding(.horizontal, guidanceUsesOuterShell ? 13 : 12)
                        .padding(.vertical, guidanceUsesOuterShell ? 9 : 8)
                        .background(buttonBackground, in: Capsule())
                        .overlay {
                            if guidanceUsesOuterShell == false {
                                Capsule()
                                    .stroke(buttonBorder, lineWidth: 1)
                            }
                        }
                }
                .taskerCTABezel(
                    style: .pill,
                    palette: .copper,
                    idleMotion: .slowLoop,
                    isEnabled: state != .creating,
                    isBusy: state == .creating,
                    isPrimarySuggestion: isGuidanceHighlighted
                )
                .buttonStyle(OnboardingPressScaleButtonStyle())
                .foregroundStyle(state == .creating ? OnboardingTheme.textSecondary : OnboardingTheme.accent)
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
        if guidanceUsesOuterShell {
            return OnboardingTheme.accent.opacity(0.16)
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
        if guidanceUsesOuterShell {
            return .clear
        }
        switch state {
        case .failed:
            return OnboardingTheme.danger.opacity(0.6)
        default:
            return OnboardingTheme.accent.opacity(0.3)
        }
    }

    private var guidanceUsesOuterShell: Bool {
        isGuidanceHighlighted && V2FeatureFlags.liquidMetalCTAEnabled && state != .creating
    }

    private var buttonTitle: String {
        switch state {
        case .idle:
            return "Add"
        case .creating:
            return "Adding…"
        case .created:
            return "Added"
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
            return OnboardingTheme.success.opacity(0.10)
        case .failed:
            return OnboardingTheme.danger.opacity(0.08)
        default:
            return OnboardingTheme.surface
        }
    }

    private var borderColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.success.opacity(0.7)
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
            OnboardingInlineBadge(title: "Added", accent: OnboardingTheme.success)
        case .creating:
            OnboardingInlineBadge(title: "Saving", accent: OnboardingTheme.accent)
        case .failed:
            OnboardingInlineBadge(title: "Needs retry", accent: OnboardingTheme.danger)
        case .idle:
            OnboardingInlineBadge(title: "Recommended", accent: OnboardingTheme.accent)
        }
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
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .stroke(OnboardingTheme.accent.opacity(0.10), lineWidth: 18)
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(OnboardingTheme.surface)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "bolt.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(task.isComplete ? OnboardingTheme.success : OnboardingTheme.accent)
                    )
            }
            .frame(maxWidth: .infinity)

            Text(task.title)
                .font(.tasker(.title2))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text("Recommended first win")
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                pill(projectName, accent: OnboardingTheme.textSecondary)
                pill(durationText, accent: OnboardingTheme.textSecondary)
                pill("+\(xpAward) XP", accent: OnboardingTheme.textSecondary)
                Spacer()
            }

            if isActive {
                OnboardingFocusTimer(startedAt: startedAt, estimatedDuration: task.estimatedDuration)
            }

            VStack(spacing: 10) {
                Button {
                    onPrimary()
                } label: {
                    Text(isActive ? "Mark complete" : "Start now")
                        .frame(maxWidth: .infinity)
                }
                .onboardingPrimaryButton(disabled: task.isComplete)
                .accessibilityIdentifier(isActive ? "onboarding.cta.markComplete" : "onboarding.cta.startNow")
                .accessibilityLabel(isActive ? "Mark complete" : "Start now")

                Button("Ask your AI coach to break this down") {
                    onBreakDown()
                }
                .font(.tasker(.buttonSmall))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.cta.breakDown")
            }
        }
        .padding(24)
        .background(OnboardingTheme.surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
        .shadow(color: OnboardingTheme.accent.opacity(0.12), radius: 24, y: 8)
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = max(0, Int(timeline.date.timeIntervalSince(startedAt ?? timeline.date)))
            HStack(spacing: 10) {
                if let estimatedDuration, estimatedDuration > 0 {
                    let progress = min(max(timeline.date.timeIntervalSince(startedAt ?? timeline.date) / estimatedDuration, 0), 1)
                    ZStack {
                        Circle()
                            .stroke(OnboardingTheme.surfaceMuted, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(OnboardingTheme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 34, height: 34)
                } else {
                    Image(systemName: "timer")
                        .foregroundStyle(OnboardingTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(estimatedDuration == nil ? "Elapsed time" : "Focus timer")
                        .font(.tasker(.caption2))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                    Text(formatted(elapsed))
                        .font(.tasker(.headline))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                }
                Spacer()
            }
            .padding(12)
            .background(OnboardingTheme.surfaceMuted.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func formatted(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

private struct OnboardingSuccessHero: View {
    let completedTaskTitle: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(OnboardingTheme.success.opacity(pulse ? 0.18 : 0.12))
                        .frame(width: 74, height: 74)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnboardingTheme.success)
                }
                Spacer()
                Text("Momentum unlocked")
                    .font(.tasker(.headline))
                    .foregroundStyle(OnboardingTheme.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(OnboardingTheme.success.opacity(0.12), in: Capsule())
                    .offset(y: pulse ? -4 : 0)
            }

            Text("Nice. You got your first real win.")
                .font(.tasker(.display))
                .foregroundStyle(OnboardingTheme.textPrimary)

            Text("You already did the hardest part: starting.")
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(OnboardingTheme.textPrimary)

            Text(completedTaskTitle.map { "You set up your starting structure and finished \"\($0)\". Tasker is ready to help you keep moving." } ?? "You set up your starting structure and finished your first task. Tasker is ready to help you keep moving.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)
        }
        .padding(24)
        .onboardingGlassPanel(cornerRadius: 32)
        .onAppear {
            guard reduceMotion == false else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct OnboardingMetricCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.tasker(.title1))
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text(label)
                .font(.tasker(.caption1))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OnboardingTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        .background(OnboardingTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
    }
}

private struct OnboardingReminderCard: View {
    let state: OnboardingReminderPromptState
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Want gentle reminders when momentum drops?")
                .font(.tasker(.headline))
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text("Tasker can bring things back at the right time, without asking before you’ve seen value.")
                .font(.tasker(.body))
                .foregroundStyle(OnboardingTheme.textSecondary)

            HStack(spacing: 12) {
                Button(state == .openSettings ? "Open Settings" : "Turn on reminders") {
                    onPrimary()
                }
                .buttonStyle(.plain)
                .font(.tasker(.buttonSmall))
                .foregroundStyle(OnboardingTheme.accent)

                Button("Not now") {
                    onSecondary()
                }
                .buttonStyle(.plain)
                .font(.tasker(.buttonSmall))
                .foregroundStyle(OnboardingTheme.textSecondary)
            }
        }
        .padding(18)
        .background(OnboardingTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
    }
}

private extension View {
    func onboardingGlassPanel(cornerRadius: CGFloat, shadowOpacity: Double = 0.06) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, y: 8)
    }

    func onboardingPrimaryButton(disabled: Bool = false) -> some View {
        self
            .font(.tasker(.button))
            .foregroundStyle(Color.white)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(disabled ? OnboardingTheme.textSecondary.opacity(0.4) : OnboardingTheme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .disabled(disabled)
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
