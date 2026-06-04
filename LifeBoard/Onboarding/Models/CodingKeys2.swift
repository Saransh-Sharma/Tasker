import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension OnboardingJourneySnapshot {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case step
        case mode
        case entryContext
        case frictionProfile
        case selectedGoal
        case selectedPainPoints
        case selectedLifeAreaIDs
        case showAllLifeAreas
        case projectDrafts
        case expandedProjectIDs
        case resolvedLifeAreas
        case resolvedProjects
        case selectedStarterHabitPreference
        case selectedStarterHabitTemplateID
        case createdHabits
        case createdHabitTemplateMap
        case createdTasks
        case createdTaskTemplateMap
        case focusTaskID
        case parentFocusTaskID
        case focusStartedAt
        case focusIsActive
        case habitPreviewMarks
        case didCompleteStarterHabitCheckIn
        case evaProfileDraft
        case evaPreparationState
        case didCompleteHomeDemoTask
        case didCompleteHomeDemoHabit
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
        selectedGoal = try container.decodeIfPresent(OnboardingPrimaryGoal.self, forKey: .selectedGoal)
        selectedPainPoints = try container.decodeIfPresent([OnboardingPainPoint].self, forKey: .selectedPainPoints) ?? []
        selectedLifeAreaIDs = try container.decode([String].self, forKey: .selectedLifeAreaIDs)
        showAllLifeAreas = try container.decode(Bool.self, forKey: .showAllLifeAreas)
        projectDrafts = try container.decode([OnboardingProjectDraft].self, forKey: .projectDrafts)
        expandedProjectIDs = try container.decodeIfPresent([UUID].self, forKey: .expandedProjectIDs) ?? []
        resolvedLifeAreas = try container.decode([ResolvedLifeAreaSelection].self, forKey: .resolvedLifeAreas)
        resolvedProjects = try container.decode([ResolvedProjectSelection].self, forKey: .resolvedProjects)
        selectedStarterHabitPreference = try container.decodeIfPresent(OnboardingStarterHabitPreference.self, forKey: .selectedStarterHabitPreference) ?? .positive
        selectedStarterHabitTemplateID = try container.decodeIfPresent(String.self, forKey: .selectedStarterHabitTemplateID)
        createdHabits = try container.decodeIfPresent([HabitDefinitionRecord].self, forKey: .createdHabits) ?? []
        createdHabitTemplateMap = try container.decodeIfPresent([String: UUID].self, forKey: .createdHabitTemplateMap) ?? [:]
        createdTasks = try container.decode([TaskDefinition].self, forKey: .createdTasks)
        createdTaskTemplateMap = try container.decode([String: UUID].self, forKey: .createdTaskTemplateMap)
        focusTaskID = try container.decodeIfPresent(UUID.self, forKey: .focusTaskID)
        parentFocusTaskID = try container.decodeIfPresent(UUID.self, forKey: .parentFocusTaskID)
        focusStartedAt = try container.decodeIfPresent(Date.self, forKey: .focusStartedAt)
        focusIsActive = try container.decode(Bool.self, forKey: .focusIsActive)
        habitPreviewMarks = try container.decodeIfPresent([HabitDayMark].self, forKey: .habitPreviewMarks) ?? []
        didCompleteStarterHabitCheckIn = try container.decodeIfPresent(Bool.self, forKey: .didCompleteStarterHabitCheckIn) ?? false
        evaProfileDraft = try container.decodeIfPresent(EvaProfileDraft.self, forKey: .evaProfileDraft) ?? EvaProfileDraft()
        evaPreparationState = try container.decodeIfPresent(OnboardingEvaPreparationState.self, forKey: .evaPreparationState) ?? OnboardingEvaPreparationState()
        didCompleteHomeDemoTask = try container.decodeIfPresent(Bool.self, forKey: .didCompleteHomeDemoTask) ?? false
        didCompleteHomeDemoHabit = try container.decodeIfPresent(Bool.self, forKey: .didCompleteHomeDemoHabit) ?? false
        successSummary = try container.decodeIfPresent(AppOnboardingSummary.self, forKey: .successSummary)
        hasSeenSuccess = try container.decode(Bool.self, forKey: .hasSeenSuccess)
        reminderPromptDismissed = try container.decodeIfPresent(Bool.self, forKey: .reminderPromptDismissed) ?? false
    }
}
