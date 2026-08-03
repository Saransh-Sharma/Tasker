import Foundation

extension OnboardingJourneySnapshot {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case step
        case mode
        case entryContext
        case selectedGoal
        case selectedLifeAreaIDs
        case showAllLifeAreas
        case projectDrafts
        case expandedProjectIDs
        case resolvedLifeAreas
        case resolvedProjects
        case dayShape
        case selectedModuleIDs
        case selectedStarterHabitPreference
        case selectedStarterHabitTemplateID
        case createdHabits
        case createdHabitTemplateMap
        case createdTasks
        case createdTaskTemplateMap
        case focusTaskID
        case grantedPermissionKinds
        case evaProfileDraft
        case evaPreparationState
        case successSummary
        case hasSeenSuccess
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 5
        // A snapshot written by an older build can name a step that no longer
        // exists. Restarting at the beginning is the honest recovery; throwing
        // would strand the user in a flow that never re-presents.
        step = (try? container.decode(OnboardingStep.self, forKey: .step)) ?? .welcome
        mode = try container.decode(OnboardingMode.self, forKey: .mode)
        entryContext = try container.decodeIfPresent(OnboardingEntryContext.self, forKey: .entryContext) ?? .freshFlow
        selectedGoal = try container.decodeIfPresent(OnboardingPrimaryGoal.self, forKey: .selectedGoal)
        selectedLifeAreaIDs = try container.decodeIfPresent([String].self, forKey: .selectedLifeAreaIDs) ?? []
        showAllLifeAreas = try container.decodeIfPresent(Bool.self, forKey: .showAllLifeAreas) ?? false
        projectDrafts = try container.decodeIfPresent([OnboardingProjectDraft].self, forKey: .projectDrafts) ?? []
        expandedProjectIDs = try container.decodeIfPresent([UUID].self, forKey: .expandedProjectIDs) ?? []
        resolvedLifeAreas = try container.decodeIfPresent([ResolvedLifeAreaSelection].self, forKey: .resolvedLifeAreas) ?? []
        resolvedProjects = try container.decodeIfPresent([ResolvedProjectSelection].self, forKey: .resolvedProjects) ?? []
        dayShape = try container.decodeIfPresent(OnboardingDayShapeDraft.self, forKey: .dayShape) ?? OnboardingDayShapeDraft()
        selectedModuleIDs = try container.decodeIfPresent([String].self, forKey: .selectedModuleIDs) ?? []
        selectedStarterHabitPreference = try container.decodeIfPresent(OnboardingStarterHabitPreference.self, forKey: .selectedStarterHabitPreference) ?? .positive
        selectedStarterHabitTemplateID = try container.decodeIfPresent(String.self, forKey: .selectedStarterHabitTemplateID)
        createdHabits = try container.decodeIfPresent([HabitDefinitionRecord].self, forKey: .createdHabits) ?? []
        createdHabitTemplateMap = try container.decodeIfPresent([String: UUID].self, forKey: .createdHabitTemplateMap) ?? [:]
        createdTasks = try container.decodeIfPresent([TaskDefinition].self, forKey: .createdTasks) ?? []
        createdTaskTemplateMap = try container.decodeIfPresent([String: UUID].self, forKey: .createdTaskTemplateMap) ?? [:]
        focusTaskID = try container.decodeIfPresent(UUID.self, forKey: .focusTaskID)
        grantedPermissionKinds = try container.decodeIfPresent([String].self, forKey: .grantedPermissionKinds) ?? []
        evaProfileDraft = try container.decodeIfPresent(EvaProfileDraft.self, forKey: .evaProfileDraft) ?? EvaProfileDraft()
        evaPreparationState = try container.decodeIfPresent(OnboardingEvaPreparationState.self, forKey: .evaPreparationState) ?? OnboardingEvaPreparationState()
        successSummary = try container.decodeIfPresent(AppOnboardingSummary.self, forKey: .successSummary)
        hasSeenSuccess = try container.decodeIfPresent(Bool.self, forKey: .hasSeenSuccess) ?? false
    }
}
