import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension OnboardingFlowModel {
    func continueFromPain() {
        guard canContinuePain else {
            errorMessage = OnboardingCopy.Error.choosePain
            return
        }
        step = .evaValue
        errorMessage = nil
        persistJourney()
    }

    func continueFromEvaValue() {
        persistSelectedMascot()
        startEvaPreparationInBackgroundIfNeeded()
        step = .habitSetup
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
            errorMessage = OnboardingCopy.Error.chooseAreas
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
            try await resolveProjectsFromDrafts()
            createdHabits = []
            createdHabitTemplateMap = [:]
            habitTemplateStates = [:]
            createdTasks = []
            createdTaskTemplateMap = [:]
            taskTemplateStates = [:]
            focusTaskID = nil
            selectedStarterHabitTemplateID = selectedStarterHabitTemplateID ?? selectedStarterHabitTemplate?.id
            step = .evaValue
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
            selectedGoal = .wholeWeek
            selectedPainPoints = []
            selectedLifeAreaIDs = Set(selectedAreaIDs)
            showAllLifeAreas = false
            resolvedLifeAreas = selectedAreas
            projectDrafts = resolvedProjectSelections.map(\.draft)
            resolvedProjects = resolvedProjectSelections
            createdHabits = []
            createdHabitTemplateMap = [:]
            habitTemplateStates = [:]
            clearTasksAndFocus()
            selectedStarterHabitTemplateID = selectedStarterHabitTemplate?.id
            step = .goal
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
            habitTemplateStates[template.id] = .failed("LifeBoard could not find that life area.")
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

    func chooseStarterHabitPreference(_ preference: OnboardingStarterHabitPreference) {
        selectedStarterHabitPreference = preference
        if let current = selectedStarterHabitTemplate,
           current.kind == .negative,
           preference == .positive {
            selectedStarterHabitTemplateID = nil
        }
        if let current = selectedStarterHabitTemplate,
           current.kind == .positive,
           preference == .negativeDailyCheckIn {
            selectedStarterHabitTemplateID = nil
        }
        selectedStarterHabitTemplateID = selectedStarterHabitTemplate?.id
        habitPreviewMarks = []
        errorMessage = nil
        persistJourney()
    }

    func chooseStarterHabitTemplate(_ template: StarterHabitTemplate) {
        selectedStarterHabitTemplateID = template.id
        habitPreviewMarks = []
        errorMessage = nil
        persistJourney()
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

    func continueFromHabitSetup() async {
        guard canContinueHabitSetup else {
            errorMessage = OnboardingCopy.Error.chooseHabit
            return
        }
        if selectedStarterHabitTemplateID == nil {
            selectedStarterHabitTemplateID = selectedStarterHabitTemplate?.id
        }
        if let template = selectedStarterHabitTemplate,
           createdHabitTemplateMap[template.id] == nil,
           createdHabits.isEmpty {
            await addSuggestedHabit(template)
            guard errorMessage == nil else { return }
        }
        step = .firstTask
        errorMessage = nil
        persistJourney()
    }

    func continueFromStreakPreview() {
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
            taskTemplateStates[template.id] = .failed("LifeBoard could not find that project.")
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
        step = .homeDemo
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
            step = .success
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
}
