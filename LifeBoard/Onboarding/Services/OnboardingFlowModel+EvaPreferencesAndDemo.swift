import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension OnboardingFlowModel {
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
        step = .homeDemo
        persistJourney()
        await generateBreakdownSuggestions()
    }

    func continueWithNextTask() {
        guard let nextOpenTask else { return }
        focusTaskID = nextOpenTask.id
        focusIsActive = false
        focusStartedAt = nil
        successSummary = nil
        step = .homeDemo
        persistJourney()
    }

    func refreshReminderPromptState() async {
        guard step == .success, successSummary != nil, let notificationService else {
            reminderPromptState = .hidden
            persistJourney()
            return
        }
        if reminderPromptDismissed {
            reminderPromptState = .hidden
            persistJourney()
            return
        }

        let status = await fetchAuthorizationStatus(using: notificationService)
        applyReminderPromptState(for: status)
    }

    func handleReminderPrimaryAction() async {
        guard reminderPromptState == .prompt, let notificationService else { return }
        let granted = await requestNotificationPermission(using: notificationService)
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

    func continueFromEvaStyle() {
        guard evaProfileDraft.selectedWorkingStyleIDs.isEmpty == false else {
            errorMessage = OnboardingCopy.Error.chooseEvaPreference
            return
        }
        step = isAppStoreScreenshotOnboardingFlowEnabled ? .workBlockers : .firstTask
        errorMessage = nil
        persistJourney()
    }

    func toggleEvaWorkingStyle(_ id: String) {
        if let index = evaProfileDraft.selectedWorkingStyleIDs.firstIndex(of: id) {
            evaProfileDraft.selectedWorkingStyleIDs.remove(at: index)
        } else {
            evaProfileDraft.selectedWorkingStyleIDs.append(id)
        }
        persistJourney()
    }

    func addCustomEvaWorkingStyle(_ title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }
        if evaProfileDraft.selectedWorkingStyleIDs.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) == false {
            evaProfileDraft.selectedWorkingStyleIDs.append(normalized)
        }
        errorMessage = nil
        persistJourney()
    }

    func selectChiefOfStaffMascot(_ id: AssistantMascotID) {
        guard selectedMascotID != id else { return }
        selectedMascotID = id
        persistSelectedMascot()
        persistJourney()
    }

    func toggleEvaMomentumBlocker(_ id: String) {
        if let index = evaProfileDraft.selectedMomentumBlockerIDs.firstIndex(of: id) {
            evaProfileDraft.selectedMomentumBlockerIDs.remove(at: index)
        } else {
            evaProfileDraft.selectedMomentumBlockerIDs.append(id)
        }
        persistJourney()
    }

    func addCustomEvaMomentumBlocker(_ title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }
        if evaProfileDraft.selectedMomentumBlockerIDs.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) == false {
            evaProfileDraft.selectedMomentumBlockerIDs.append(normalized)
        }
        errorMessage = nil
        persistJourney()
    }

    func continueFromWorkBlockers() {
        guard evaProfileDraft.selectedMomentumBlockerIDs.isEmpty == false else {
            errorMessage = OnboardingCopy.Error.chooseEvaPreference
            return
        }
        step = isAppStoreScreenshotOnboardingFlowEnabled ? .weeklyOutcomes : .firstTask
        errorMessage = nil
        persistJourney()
    }

    func updateEvaGoal(at index: Int, text: String) {
        while evaProfileDraft.goals.count <= index {
            evaProfileDraft.goals.append("")
        }
        evaProfileDraft.goals[index] = text
        persistJourney()
    }

    func replaceEvaGoals(_ goals: [String]) {
        evaProfileDraft.goals = goals
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        errorMessage = nil
        persistJourney()
    }

    func continueFromWeeklyOutcomes() {
        replaceEvaGoals(evaProfileDraft.goals)
        guard evaProfileDraft.goals.isEmpty == false else {
            errorMessage = OnboardingCopy.Error.chooseEvaPreference
            return
        }
        step = .firstTask
        errorMessage = nil
        persistJourney()
    }

    func runProcessingIfNeeded() async {
        guard step == .processing, hasStartedProcessing == false else { return }
        hasStartedProcessing = true
        isWorking = true
        errorMessage = nil
        defer {
            isWorking = false
            persistJourney()
        }

        do {
            if resolvedLifeAreas.isEmpty {
                let existingLifeAreas = try await fetchLifeAreas().filter { $0.isArchived == false }
                var selections: [ResolvedLifeAreaSelection] = []
                for template in selectedLifeAreas {
                    if let existing = StarterWorkspaceCatalog.matchingLifeArea(for: template, in: existingLifeAreas + resolvedLifeAreas.map(\.lifeArea)) {
                        selections.append(ResolvedLifeAreaSelection(templateID: template.id, lifeArea: existing, reusedExisting: true))
                    } else {
                        let created = try await createLifeArea(template)
                        selections.append(ResolvedLifeAreaSelection(templateID: template.id, lifeArea: created, reusedExisting: false))
                    }
                }
                resolvedLifeAreas = selections
            }

            if resolvedProjects.isEmpty {
                try await resolveProjectsFromDrafts()
            }

            if let template = selectedStarterHabitTemplate,
               createdHabitTemplateMap[template.id] == nil,
               let resolvedLifeArea = resolvedLifeAreas.first(where: { $0.templateID == template.lifeAreaTemplateID }) {
                let projectID = template.projectTemplateID.flatMap { projectTemplateID in
                    resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.id
                }
                let createdHabit = try await createHabit(template.makeRequest(lifeAreaID: resolvedLifeArea.lifeArea.id, projectID: projectID))
                upsertCreatedHabit(createdHabit)
                createdHabitTemplateMap[template.id] = createdHabit.id
                habitTemplateStates[template.id] = .created(createdHabit.id)
            }

            if createdTasks.isEmpty,
               let firstTemplate = primaryTaskSuggestions.first ?? taskSuggestions.first,
               let resolvedProject = resolvedProjects.first(where: { $0.draft.templateID == firstTemplate.projectTemplateID }) ?? resolvedProjects.first {
                let createdTask = try await createTask(firstTemplate.makeRequest(project: resolvedProject.project))
                upsertCreatedTask(createdTask)
                createdTaskTemplateMap[firstTemplate.id] = createdTask.id
                taskTemplateStates[firstTemplate.id] = .created(createdTask.id)
                focusTaskID = createdTask.id
            }

            await prepareEvaInBackgroundIfNeeded()
            step = .firstTask
        } catch {
            errorMessage = error.localizedDescription
            hasStartedProcessing = false
        }
    }

    func continueFromFirstWinReview() {
        guard starterTask != nil else {
            errorMessage = OnboardingCopy.Error.firstTaskMissing
            return
        }
        step = .homeDemo
        errorMessage = nil
        persistJourney()
    }

    func markHomeDemoTaskDone() {
        didCompleteHomeDemoTask = true
        persistJourney()
    }

    func markHomeDemoHabitDone() {
        didCompleteHomeDemoHabit = true
        persistJourney()
    }

    func continueFromHomeDemo() {
        if isAppStoreScreenshotOnboardingFlowEnabled {
            reminderPromptState = .hidden
            step = .calendarPermission
            errorMessage = nil
            persistJourney()
            return
        }

        if didCompleteHomeDemoTask, let completedTask = createdTasks.first {
            var task = completedTask
            task.isComplete = true
            task.dateCompleted = task.dateCompleted ?? Date()
            upsertCreatedTask(task)
            successSummary = buildSummary(completedTask: task)
        } else if let task = createdTasks.first(where: \.isComplete) ?? createdTasks.first {
            successSummary = buildSummary(completedTask: task)
        }
        reminderPromptState = .hidden
        step = .success
        errorMessage = nil
        persistJourney()
    }

    func performStarterHabitPrimaryAction() async {
        guard let starterHabit else { return }
        let action: HabitOccurrenceAction = starterHabit.kind == .positive ? .complete : .abstained
        await performHabitAction(action, habit: starterHabit, resultingMarkState: .success)
    }

    func performStarterHabitSecondaryAction() async {
        guard let starterHabit else { return }
        let action: HabitOccurrenceAction
        let markState: HabitDayState

        switch starterHabit.kind {
        case .positive:
            action = .skip
            markState = .skipped
        case .negative:
            action = .lapsed
            markState = .failure
        }

        await performHabitAction(action, habit: starterHabit, resultingMarkState: markState)
    }

    func continueFromCalendarPermission(skipped: Bool = false) async {
        if let completedTask = createdTasks.first(where: \.isComplete) ?? createdTasks.first {
            successSummary = buildSummary(completedTask: completedTask)
        }
        step = .success
        errorMessage = nil
        persistJourney()
    }

    func continueFromNotificationPermission(skipped: Bool = false) async {
        if let completedTask = createdTasks.first(where: \.isComplete) ?? createdTasks.first {
            successSummary = buildSummary(completedTask: completedTask)
        }
        step = .success
        reminderPromptState = .hidden
        persistJourney()
    }

    func applyReminderPromptState(for status: LifeBoardNotificationAuthorizationStatus) {
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
        persistEvaActivationCompletion()
        stateStore.markHandled(outcome: .completed)
    }
}
