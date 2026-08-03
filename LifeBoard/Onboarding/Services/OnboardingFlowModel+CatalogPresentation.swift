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

    var canContinueHabitSetup: Bool {
        selectedStarterHabitTemplate != nil || createdHabits.isEmpty == false
    }

    /// The modules step accepts an empty selection — someone who only wants
    /// tasks and habits should not be made to pick a tracker to get past it.
    var availableModules: [OnboardingTrackableModule] {
        OnboardingModuleCatalog.all
    }

    var requestablePermissionKinds: [LifeBoardPermissionKind] {
        OnboardingModuleCatalog.requestablePermissions(for: selectedModuleIDs)
    }

    var pointOfUsePermissionKinds: [LifeBoardPermissionKind] {
        OnboardingModuleCatalog.pointOfUsePermissions(for: selectedModuleIDs)
    }

    var canGoBack: Bool {
        step != .success && previousStep(before: step) != nil
    }

    var focusTask: TaskDefinition? {
        guard let focusTaskID else { return nil }
        return createdTasks.first(where: { $0.id == focusTaskID })
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

        step = snapshot.step
        mode = snapshot.mode
        entryContext = snapshot.entryContext
        selectedGoal = snapshot.selectedGoal
        frictionProfile = snapshot.selectedGoal?.mappedFrictionProfile
        selectedLifeAreaIDs = Set(normalizedSelectedLifeAreaIDs)
        showAllLifeAreas = snapshot.showAllLifeAreas
        projectDrafts = normalizedProjectDrafts
        expandedProjectIDs = Set(snapshot.expandedProjectIDs)
        dayShape = snapshot.dayShape
        selectedModuleIDs = Set(snapshot.selectedModuleIDs)
        grantedPermissionKinds = Set(
            snapshot.grantedPermissionKinds.compactMap(LifeBoardPermissionKind.init(rawValue:))
        )
        selectedStarterHabitPreference = snapshot.selectedStarterHabitPreference
        selectedStarterHabitTemplateID = snapshot.selectedStarterHabitTemplateID
        evaProfileDraft = snapshot.evaProfileDraft
        selectedMascotID = workspacePreferencesStore.load().chiefOfStaffMascotID
        if selectedMascotID == .eva, snapshot.step == .welcome || snapshot.step == .guide {
            selectedMascotID = .yesman
        }
        evaPreparationState = snapshot.evaPreparationState
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
        successSummary = snapshot.successSummary
    }

    func resetForReplay() {
        step = .welcome
        mode = .guided
        entryContext = .freshFlow
        frictionProfile = nil
        selectedGoal = nil
        selectedLifeAreaIDs = []
        showAllLifeAreas = false
        projectDrafts = []
        dayShape = OnboardingDayShapeDraft()
        selectedModuleIDs = []
        grantedPermissionKinds = []
        selectedStarterHabitPreference = .positive
        selectedStarterHabitTemplateID = nil
        habitPreviewMarks = []
        didCompleteStarterHabitCheckIn = false
        evaProfileDraft = EvaProfileDraft()
        selectedMascotID = .yesman
        evaPreparationState = OnboardingEvaPreparationState()
        resolvedLifeAreas = []
        resolvedProjects = []
        createdHabits = []
        createdHabitTemplateMap = [:]
        habitTemplateStates = [:]
        createdTasks = []
        createdTaskTemplateMap = [:]
        taskTemplateStates = [:]
        focusTaskID = nil
        successSummary = nil
        expandedProjectIDs = []
        errorMessage = nil
        evaProgressObservationTask?.cancel()
        evaProgressObservationTask = nil
        stateStore.clearJourney()
    }

    func begin(mode: OnboardingMode) {
        self.mode = mode
        entryContext = .freshFlow
        selectedMascotID = .yesman
        applyDefaults(mode: mode, frictionProfile: frictionProfile)
        clearDownstreamState()
        step = .intent
        errorMessage = nil
        persistJourney()
    }

    func selectGoal(_ goal: OnboardingPrimaryGoal) {
        selectedGoal = goal
        // The intent now shapes more than the starter areas: it preselects the
        // modules on step six and, through them, the Home layout the user lands
        // on. Picking it is the single highest-leverage answer in the flow.
        frictionProfile = goal.mappedFrictionProfile
        let preferredIDs = goal.preferredLifeAreaIDs
        if preferredIDs.isEmpty == false {
            selectedLifeAreaIDs = Set(preferredIDs.prefix(3))
            projectDrafts = mergedProjectDrafts(for: Array(selectedLifeAreaIDs))
        }
        selectedModuleIDs = OnboardingModuleCatalog.recommended(for: goal)
            .filter { OnboardingModuleCatalog.module(id: $0) != nil }
        errorMessage = nil
        persistJourney()
    }

    func continueFromIntent() {
        guard canContinueGoal else {
            errorMessage = OnboardingCopy.Error.chooseGoal
            return
        }
        applyDefaults(mode: mode, frictionProfile: frictionProfile)
        step = .lifeAreas
        errorMessage = nil
        persistJourney()
    }
}
