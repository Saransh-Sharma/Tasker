import Foundation

/// Everything needed to resume a partly-finished setup.
///
/// Schema 5 drops the fields that backed removed steps — friction profile, pain
/// points, the focus-room timer, the streak preview, and the scripted Home demo —
/// and adds the day shape and module selection the new flow collects.
struct OnboardingJourneySnapshot: Codable, Equatable {
    var schemaVersion: Int = 5
    var step: OnboardingStep
    var mode: OnboardingMode
    var entryContext: OnboardingEntryContext = .freshFlow
    var selectedGoal: OnboardingPrimaryGoal?
    var selectedLifeAreaIDs: [String]
    var showAllLifeAreas: Bool
    var projectDrafts: [OnboardingProjectDraft]
    var expandedProjectIDs: [UUID] = []
    var resolvedLifeAreas: [ResolvedLifeAreaSelection]
    var resolvedProjects: [ResolvedProjectSelection]
    var dayShape: OnboardingDayShapeDraft = OnboardingDayShapeDraft()
    var selectedModuleIDs: [String] = []
    var selectedStarterHabitPreference: OnboardingStarterHabitPreference = .positive
    var selectedStarterHabitTemplateID: String?
    var createdHabits: [HabitDefinitionRecord] = []
    var createdHabitTemplateMap: [String: UUID] = [:]
    var createdTasks: [TaskDefinition]
    var createdTaskTemplateMap: [String: UUID]
    var focusTaskID: UUID?
    var grantedPermissionKinds: [String] = []
    var evaProfileDraft: EvaProfileDraft = EvaProfileDraft()
    var evaPreparationState: OnboardingEvaPreparationState = OnboardingEvaPreparationState()
    var successSummary: AppOnboardingSummary?
    var hasSeenSuccess: Bool
}
