import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension OnboardingFlowModel {
    /// "Skip" still leaves a usable workspace behind rather than an empty one:
    /// it resolves the default areas, projects, habit, and task, then jumps to
    /// the end. A skipped setup should not mean a dead Home screen.
    func skipToEnd() async {
        mode = .guided
        errorMessage = nil
        if selectedGoal == nil {
            selectedGoal = .dailyExecution
        }
        if frictionProfile == nil {
            frictionProfile = selectedGoal?.mappedFrictionProfile
        }
        if selectedModuleIDs.isEmpty {
            selectedModuleIDs = OnboardingModuleCatalog.recommended(for: selectedGoal)
                .filter { OnboardingModuleCatalog.module(id: $0) != nil }
        }

        if selectedLifeAreaIDs.isEmpty {
            let selection = defaultLifeAreaSelectionIDs()
            selectedLifeAreaIDs = Set(selection)
        }

        if projectDrafts.isEmpty || selectedProjectDrafts.isEmpty {
            projectDrafts = mergedProjectDrafts(for: selectedLifeAreas.map(\.id))
        }

        let shouldResolveLifeAreas = step == .welcome || step == .intent || step == .guide || step == .lifeAreas || resolvedLifeAreas.isEmpty
        if shouldResolveLifeAreas {
            await continueFromLifeAreas()
            guard errorMessage == nil else { return }
        }

        let shouldResolveProjects = resolvedProjects.isEmpty
        if shouldResolveProjects {
            if selectedProjectDrafts.isEmpty {
                projectDrafts = mergedProjectDrafts(for: selectedLifeAreas.map(\.id))
            }
            do {
                try await resolveProjectsFromDrafts()
                clearHabitsAndTasks()
                persistJourney()
            } catch {
                errorMessage = error.localizedDescription
            }
            guard errorMessage == nil else { return }
        }

        if selectedStarterHabitTemplateID == nil {
            selectedStarterHabitTemplateID = selectedStarterHabitTemplate?.id
        }

        if let existingTask = createdTasks.first(where: { $0.isComplete == false }) ?? createdTasks.first {
            focusTaskID = existingTask.id
            step = .permissions
            persistJourney()
            return
        }

        if let template = selectedStarterHabitTemplate,
           createdHabits.isEmpty,
           createdHabitTemplateMap[template.id] == nil {
            await addSuggestedHabit(template)
            guard errorMessage == nil else { return }
        }

        guard let firstTemplate = primaryTaskSuggestions.first ?? taskSuggestions.first,
              let resolvedProject = resolvedProjects.first(where: { $0.draft.templateID == firstTemplate.projectTemplateID }) ?? resolvedProjects.first
        else {
            errorMessage = OnboardingCopy.Error.starterTaskFailed
            return
        }

        do {
            let createdTask = try await createTask(firstTemplate.makeRequest(project: resolvedProject.project))
            upsertCreatedTask(createdTask)
            createdTaskTemplateMap[firstTemplate.id] = createdTask.id
            taskTemplateStates[firstTemplate.id] = .created(createdTask.id)
            focusTaskID = createdTask.id
            step = .permissions
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goBack() {
        errorMessage = nil
        if step == .success {
            successSummary = nil
            step = .permissions
            persistJourney()
            return
        }

        if let previous = previousStep(before: step) {
            step = previous
        }
        persistJourney()
    }

    func applyDefaults(mode: OnboardingMode, frictionProfile: OnboardingFrictionProfile?) {
        let selection = defaultLifeAreaSelectionIDs(mode: mode, frictionProfile: frictionProfile)
        selectedLifeAreaIDs = Set(selection)
        projectDrafts = StarterWorkspaceCatalog.defaultProjectDrafts(
            for: selection,
            frictionProfile: frictionProfile,
            mode: mode
        )
        expandedProjectIDs = []
        showAllLifeAreas = false
        if selectedStarterHabitTemplateID == nil {
            selectedStarterHabitTemplateID = selectedStarterHabitTemplate?.id
        }
    }

    func clearDownstreamState() {
        clearProjectsAndTasks()
        errorMessage = nil
    }

    func clearProjectsAndTasks() {
        resolvedProjects = []
        clearHabitsAndTasks()
    }

    func clearHabitsAndTasks() {
        createdHabits = []
        createdHabitTemplateMap = [:]
        habitTemplateStates = [:]
        habitPreviewMarks = []
        didCompleteStarterHabitCheckIn = false
        clearTasksAndFocus()
    }

    func clearTasksAndFocus() {
        createdTasks = []
        createdTaskTemplateMap = [:]
        taskTemplateStates = [:]
        focusTaskID = nil
        successSummary = nil
        expandedProjectIDs = []
    }

    func mergedProjectDrafts(for selectedTemplateIDs: [String]) -> [OnboardingProjectDraft] {
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

    func upsertCreatedTask(_ task: TaskDefinition) {
        if let index = createdTasks.firstIndex(where: { $0.id == task.id }) {
            createdTasks[index] = task
        } else {
            createdTasks.append(task)
        }
    }

    func upsertCreatedHabit(_ habit: HabitDefinitionRecord) {
        if let index = createdHabits.firstIndex(where: { $0.id == habit.id }) {
            createdHabits[index] = habit
        } else {
            createdHabits.append(habit)
        }
    }

    func buildSummary(completedTask: TaskDefinition) -> AppOnboardingSummary {
        let completedCount = createdTasks.filter(\.isComplete).count
        let habitMetrics = starterHabitBoardPresentation?.metrics
        let nextTaskTitle = createdTasks.first(where: { $0.isComplete == false })?.title
        return AppOnboardingSummary(
            lifeAreaCount: resolvedLifeAreas.count,
            projectCount: resolvedProjects.count,
            createdHabitCount: createdHabits.count,
            createdHabitTitles: createdHabits.map(\.title),
            createdHabitCurrentStreak: habitMetrics?.currentStreak ?? 0,
            createdHabitBestStreak: habitMetrics?.bestStreak ?? 0,
            createdTaskCount: createdTasks.count,
            completedTaskCount: completedCount,
            completedTaskTitle: completedTask.title,
            nextTaskTitle: nextTaskTitle,
            evaState: evaPreparationState
        )
    }

    func persistJourney() {
        let snapshot = OnboardingJourneySnapshot(
            step: step,
            mode: mode,
            entryContext: entryContext,
            selectedGoal: selectedGoal,
            selectedLifeAreaIDs: StarterWorkspaceCatalog.orderedLifeAreas(for: frictionProfile)
                .map(\.id)
                .filter { selectedLifeAreaIDs.contains($0) },
            showAllLifeAreas: showAllLifeAreas,
            projectDrafts: projectDrafts,
            expandedProjectIDs: Array(expandedProjectIDs),
            resolvedLifeAreas: resolvedLifeAreas,
            resolvedProjects: resolvedProjects,
            dayShape: dayShape,
            selectedModuleIDs: Array(selectedModuleIDs),
            selectedStarterHabitPreference: selectedStarterHabitPreference,
            selectedStarterHabitTemplateID: selectedStarterHabitTemplateID,
            createdHabits: createdHabits,
            createdHabitTemplateMap: createdHabitTemplateMap,
            createdTasks: createdTasks,
            createdTaskTemplateMap: createdTaskTemplateMap,
            focusTaskID: focusTaskID,
            grantedPermissionKinds: grantedPermissionKinds.map(\.rawValue),
            evaProfileDraft: evaProfileDraft,
            evaPreparationState: evaPreparationState,
            successSummary: successSummary,
            hasSeenSuccess: step == .success
        )
        stateStore.storeJourney(snapshot)
    }

    func defaultLifeAreaSelectionIDs(
        mode: OnboardingMode? = nil,
        frictionProfile: OnboardingFrictionProfile? = nil
    ) -> [String] {
        if let selectedGoal {
            let ids = selectedGoal.preferredLifeAreaIDs
            if ids.isEmpty == false {
                return Array(ids.prefix(3))
            }
        }
        return StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: frictionProfile ?? self.frictionProfile, mode: mode ?? self.mode)
    }

    func resolveProjectsFromDrafts() async throws {
        let existingProjects = try await fetchProjects().filter { $0.isArchived == false }
        let lifeAreasByTemplate = Dictionary(uniqueKeysWithValues: resolvedLifeAreas.map { ($0.templateID, $0.lifeArea) })
        var selections: [ResolvedProjectSelection] = []
        for draft in selectedProjectDrafts {
            guard let lifeArea = lifeAreasByTemplate[draft.lifeAreaTemplateID] else { continue }
            if let existing = StarterWorkspaceCatalog.matchingProject(for: draft, lifeAreaID: lifeArea.id, in: existingProjects + selections.map(\.project)) {
                selections.append(ResolvedProjectSelection(draft: draft, project: existing, reusedExisting: true))
            } else {
                let created = try await createProject(draft, lifeArea)
                selections.append(ResolvedProjectSelection(draft: draft, project: created, reusedExisting: false))
            }
        }
        resolvedProjects = selections
    }

    func performHabitAction(
        _ action: HabitOccurrenceAction,
        habit: HabitDefinitionRecord,
        resultingMarkState: HabitDayState
    ) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await resolveHabitOccurrence(habit.id, action, Date())
            habitPreviewMarks = updatePreviewMarks(with: resultingMarkState)
            didCompleteStarterHabitCheckIn = true
            step = .success
            persistJourney()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePreviewMarks(with state: HabitDayState) -> [HabitDayMark] {
        let today = Calendar.current.startOfDay(for: Date())
        let remaining = habitPreviewMarks.filter { Calendar.current.isDate($0.date, inSameDayAs: today) == false }
        return remaining + [HabitDayMark(date: today, state: state)]
    }

    func requestCalendarAccessIfNeeded() async -> Bool {
        guard let calendarService else { return false }
        let action = calendarService.accessAction()
        switch action {
        case .noneNeeded:
            return true
        case .requestPermission:
            return await withCheckedContinuation { continuation in
                calendarService.requestAccess(source: "onboarding") { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .openSystemSettings, .unavailable:
            return false
        }
    }

    func fetchAuthorizationStatus(
        using notificationService: NotificationServiceProtocol
    ) async -> LifeBoardNotificationAuthorizationStatus {
        await withCheckedContinuation { continuation in
            notificationService.fetchAuthorizationStatus { status in
                continuation.resume(returning: status)
            }
        }
    }

    func requestNotificationPermission(
        using notificationService: NotificationServiceProtocol
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            notificationService.requestPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func persistSelectedMascot() {
        workspacePreferencesStore.update { preferences in
            preferences.chiefOfStaffMascotID = selectedMascotID
        }
    }

    func startEvaPreparationInBackgroundIfNeeded() {
        Task { @MainActor [weak self] in
            await self?.prepareEvaInBackgroundIfNeeded()
        }
    }

    func prepareEvaInBackgroundIfNeeded() async {
        guard isEvaBackgroundPreparationEnabled else { return }
        guard evaPreparationState.phase == .idle || evaPreparationState.phase == .failed else { return }

        guard let recommendedModelName = recommendedEvaModelName() else {
            deferEvaPreparationForUnsupportedRuntime()
            return
        }
        evaPreparationState.selectedModelName = recommendedModelName

        switch await detectNetworkClass() {
        case .cellular:
            if evaPreparationState.cellularConsentGranted {
                await startEvaPreparation(modelName: recommendedModelName)
            } else {
                evaPreparationState.phase = .waitingForCellularConsent
                evaPreparationState.statusMessage = "Waiting for your approval to use mobile data."
            }
        case .wifi:
            await startEvaPreparation(modelName: recommendedModelName)
        case .unavailable:
            evaPreparationState.phase = .deferred
            evaPreparationState.statusMessage = "Waiting for Wi-Fi"
        }
    }

    func approveEvaCellularDownload() async {
        evaPreparationState.cellularConsentGranted = true
        guard let modelName = evaPreparationState.selectedModelName ?? recommendedEvaModelName() else {
            deferEvaPreparationForUnsupportedRuntime()
            return
        }
        await startEvaPreparation(modelName: modelName)
    }

    func deferEvaDownload() {
        evaPreparationState.phase = .deferred
        evaPreparationState.statusMessage = "You can keep going. Your assistant will wait for Wi-Fi."
        persistJourney()
    }
}
