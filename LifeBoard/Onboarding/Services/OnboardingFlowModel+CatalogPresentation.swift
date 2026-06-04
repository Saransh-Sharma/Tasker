import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension OnboardingFlowModel {
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

    var selectedMascotPersona: AssistantMascotPersona {
        AssistantMascotPersona.persona(for: selectedMascotID)
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

    var filteredHabitSuggestions: [StarterHabitTemplate] {
        switch selectedStarterHabitPreference {
        case .positive:
            return habitSuggestions.filter { $0.kind == .positive }
        case .negativeDailyCheckIn:
            return habitSuggestions.filter { $0.kind == .negative && $0.trackingMode == .dailyCheckIn }
        }
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

    var selectedStarterHabitTemplate: StarterHabitTemplate? {
        if let selectedStarterHabitTemplateID,
           let matched = habitSuggestions.first(where: { $0.id == selectedStarterHabitTemplateID }) {
            return matched
        }
        return filteredHabitSuggestions.first ?? primaryHabitSuggestions.first ?? negativeHabitSuggestion
    }

    var starterHabit: HabitDefinitionRecord? {
        guard let selectedStarterHabitTemplate else {
            return createdHabits.first
        }
        if let habitID = createdHabitTemplateMap[selectedStarterHabitTemplate.id] {
            return createdHabits.first(where: { $0.id == habitID })
        }
        return createdHabits.first
    }

    var starterTask: TaskDefinition? {
        if let focusTaskID {
            return createdTasks.first(where: { $0.id == focusTaskID }) ?? createdTasks.first
        }
        return createdTasks.first
    }

    var starterHabitBoardPresentation: HabitBoardRowPresentation? {
        guard let template = selectedStarterHabitTemplate else { return nil }
        let marks = habitPreviewMarks
        let cells = HabitBoardPresentationBuilder.buildCells(
            marks: marks,
            cadence: template.cadence,
            referenceDate: Date(),
            dayCount: 14
        )
        let metrics = HabitBoardPresentationBuilder.metrics(for: cells)
        let family = HabitColorFamily.family(
            for: template.isPositive ? HabitColorFamily.green.canonicalHex : HabitColorFamily.coral.canonicalHex,
            fallback: template.isPositive ? .green : .coral
        )
        return HabitBoardRowPresentation(
            habitID: starterHabit?.id ?? UUID(),
            title: starterHabit?.title ?? template.title,
            iconSymbolName: template.icon.symbolName,
            accentHex: family.canonicalHex,
            colorFamily: family,
            currentStreak: metrics.currentStreak,
            bestStreak: metrics.bestStreak,
            cells: cells,
            metrics: metrics
        )
    }

    var canAddMoreHabits: Bool {
        createdHabits.count < 2
    }

    var canContinueLifeAreas: Bool {
        (1...3).contains(selectedLifeAreaIDs.count)
    }

    var canContinueGoal: Bool {
        selectedGoal != nil
    }

    var canContinuePain: Bool {
        selectedPainPoints.isEmpty == false
    }

    var canContinueHabitSetup: Bool {
        selectedStarterHabitTemplate != nil || createdHabits.isEmpty == false
    }

    var canContinueToFocus: Bool {
        createdTasks.isEmpty == false
    }

    var canGoBack: Bool {
        step != .success && previousStep(before: step) != nil
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

    func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        guard let index = OnboardingStep.orderedFlow.firstIndex(of: step),
              index + 1 < OnboardingStep.orderedFlow.count else {
            return nil
        }
        return OnboardingStep.orderedFlow[index + 1]
    }

    func previousStep(before step: OnboardingStep) -> OnboardingStep? {
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
            selectedMascotID = .yesman
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

        step = snapshot.step.normalizedForCurrentFlow
        mode = snapshot.mode
        entryContext = snapshot.entryContext
        frictionProfile = snapshot.frictionProfile
        selectedGoal = snapshot.selectedGoal
        selectedPainPoints = Set(snapshot.selectedPainPoints)
        selectedLifeAreaIDs = Set(normalizedSelectedLifeAreaIDs)
        showAllLifeAreas = snapshot.showAllLifeAreas
        projectDrafts = normalizedProjectDrafts
        expandedProjectIDs = Set(snapshot.expandedProjectIDs)
        reminderPromptDismissed = snapshot.reminderPromptDismissed
        selectedStarterHabitPreference = snapshot.selectedStarterHabitPreference
        selectedStarterHabitTemplateID = snapshot.selectedStarterHabitTemplateID
        habitPreviewMarks = snapshot.habitPreviewMarks
        didCompleteStarterHabitCheckIn = snapshot.didCompleteStarterHabitCheckIn
        evaProfileDraft = snapshot.evaProfileDraft
        selectedMascotID = workspacePreferencesStore.load().chiefOfStaffMascotID
        if selectedMascotID == .eva, snapshot.step == .welcome || snapshot.step == .evaValue {
            selectedMascotID = .yesman
        }
        evaPreparationState = snapshot.evaPreparationState
        didCompleteHomeDemoTask = snapshot.didCompleteHomeDemoTask
        didCompleteHomeDemoHabit = snapshot.didCompleteHomeDemoHabit
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
        if snapshot.hasSeenSuccess, step == .success {
            notificationService?.fetchAuthorizationStatus { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.applyReminderPromptState(for: status)
                }
            }
        }
    }

    func resetForReplay() {
        step = .welcome
        mode = .guided
        entryContext = .freshFlow
        frictionProfile = nil
        selectedGoal = nil
        selectedPainPoints = []
        selectedLifeAreaIDs = []
        showAllLifeAreas = false
        projectDrafts = []
        selectedStarterHabitPreference = .positive
        selectedStarterHabitTemplateID = nil
        habitPreviewMarks = []
        didCompleteStarterHabitCheckIn = false
        evaProfileDraft = EvaProfileDraft()
        selectedMascotID = .yesman
        evaPreparationState = OnboardingEvaPreparationState()
        didCompleteHomeDemoTask = false
        didCompleteHomeDemoHabit = false
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
        hasStartedProcessing = false
        errorMessage = nil
        evaProgressObservationTask?.cancel()
        evaProgressObservationTask = nil
        stateStore.clearJourney()
    }

    func selectFriction(_ profile: OnboardingFrictionProfile) {
        let nextProfile = frictionProfile == profile ? nil : profile
        frictionProfile = nextProfile
        if let nextProfile {
            logOnboardingInfo(event: "friction_type_selected", fields: ["profile": nextProfile.rawValue])
        }
        persistJourney()
    }

    func begin(mode: OnboardingMode) {
        self.mode = mode
        entryContext = .freshFlow
        selectedMascotID = .yesman
        applyDefaults(mode: mode, frictionProfile: frictionProfile)
        clearDownstreamState()
        step = .goal
        errorMessage = nil
        persistJourney()
    }

    func selectGoal(_ goal: OnboardingPrimaryGoal) {
        selectedGoal = goal
        let preferredIDs = goal.preferredLifeAreaIDs
        if preferredIDs.isEmpty == false {
            selectedLifeAreaIDs = Set(preferredIDs.prefix(3))
            projectDrafts = mergedProjectDrafts(for: Array(selectedLifeAreaIDs))
        }
        errorMessage = nil
        persistJourney()
    }

    func continueFromGoal() {
        guard canContinueGoal else {
            errorMessage = OnboardingCopy.Error.chooseGoal
            return
        }
        step = .pain
        errorMessage = nil
        persistJourney()
    }

    func togglePainPoint(_ painPoint: OnboardingPainPoint) {
        if selectedPainPoints.contains(painPoint) {
            selectedPainPoints.remove(painPoint)
        } else {
            selectedPainPoints.insert(painPoint)
        }
        frictionProfile = derivedFrictionProfile()
        if entryContext == .freshFlow {
            applyDefaults(mode: mode, frictionProfile: frictionProfile)
        }
        errorMessage = nil
        persistJourney()
    }
}
