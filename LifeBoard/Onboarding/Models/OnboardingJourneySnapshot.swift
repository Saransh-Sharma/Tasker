import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingJourneySnapshot: Codable, Equatable {
    var schemaVersion: Int = 4
    var step: OnboardingStep
    var mode: OnboardingMode
    var entryContext: OnboardingEntryContext = .freshFlow
    var frictionProfile: OnboardingFrictionProfile?
    var selectedGoal: OnboardingPrimaryGoal?
    var selectedPainPoints: [OnboardingPainPoint] = []
    var selectedLifeAreaIDs: [String]
    var showAllLifeAreas: Bool
    var projectDrafts: [OnboardingProjectDraft]
    var expandedProjectIDs: [UUID] = []
    var resolvedLifeAreas: [ResolvedLifeAreaSelection]
    var resolvedProjects: [ResolvedProjectSelection]
    var selectedStarterHabitPreference: OnboardingStarterHabitPreference = .positive
    var selectedStarterHabitTemplateID: String?
    var createdHabits: [HabitDefinitionRecord] = []
    var createdHabitTemplateMap: [String: UUID] = [:]
    var createdTasks: [TaskDefinition]
    var createdTaskTemplateMap: [String: UUID]
    var focusTaskID: UUID?
    var parentFocusTaskID: UUID?
    var focusStartedAt: Date?
    var focusIsActive: Bool
    var habitPreviewMarks: [HabitDayMark] = []
    var didCompleteStarterHabitCheckIn: Bool = false
    var evaProfileDraft: EvaProfileDraft = EvaProfileDraft()
    var evaPreparationState: OnboardingEvaPreparationState = OnboardingEvaPreparationState()
    var didCompleteHomeDemoTask: Bool = false
    var didCompleteHomeDemoHabit: Bool = false
    var successSummary: AppOnboardingSummary?
    var hasSeenSuccess: Bool
    var reminderPromptDismissed: Bool = false
}
