import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension AppOnboardingJourneyView {
    var painStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Pain.title,
                subtitle: OnboardingCopy.Pain.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.pain)

            VStack(alignment: .leading, spacing: spacing.s12) {
                ForEach(OnboardingPainPoint.allCases) { painPoint in
                    OnboardingChecklistRow(
                        title: painPoint.title,
                        symbolName: painPoint.symbolName,
                        isSelected: viewModel.selectedPainPoints.contains(painPoint)
                    ) {
                        feedbackController.selection()
                        viewModel.togglePainPoint(painPoint)
                    }
                }
            }
        }
    }

    var evaValueStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.EvaValue.title,
                subtitle: OnboardingCopy.EvaValue.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.evaValue)

            OnboardingMascotCarousel(
                selectedID: viewModel.selectedMascotID,
                personas: AssistantMascotPersona.all,
                onSelect: { id in
                    feedbackController.selection()
                    viewModel.selectChiefOfStaffMascot(id)
                }
            )
            .frame(height: layoutClass.isPad ? 430 : 340)

            OnboardingSelectionSummaryCard(
                title: "\(viewModel.selectedMascotPersona.displayName) is your Chief of Staff",
                message: "Pick the voice that will help protect your day, surface the next decision, and keep momentum visible.",
                mascotPlacement: .onboardingEvaValue
            )
        }
    }

    var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: OnboardingCopy.LifeAreas.title,
                subtitle: OnboardingCopy.LifeAreas.subtitle,
                detail: "\(viewModel.selectedLifeAreaIDs.count) selected"
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.lifeAreas)

            if viewModel.allowsShowAllAreas, viewModel.showAllLifeAreas == false, StarterWorkspaceCatalog.orderedLifeAreas(for: viewModel.frictionProfile).count > viewModel.visibleLifeAreas.count {
                Button {
                    feedbackController.light()
                    viewModel.showAllAreas()
                } label: {
                    Label("Show more areas", systemImage: "square.grid.2x2")
                }
                .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
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
                        accessibilityID: AppOnboardingAccessibilityID.lifeArea(area.id),
                        isSelected: viewModel.selectedLifeAreaIDs.contains(area.id)
                    ) {
                        feedbackController.selection()
                        viewModel.toggleLifeArea(area.id)
                    }
                }
            }
        }
    }

    var habitSetupStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.HabitSetup.title,
                subtitle: OnboardingCopy.HabitSetup.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.habitSetup)

            VStack(spacing: spacing.s12) {
                ForEach(OnboardingStarterHabitPreference.allCases, id: \.rawValue) { preference in
                    OnboardingSelectableDetailCard(
                        title: preference.title,
                        subtitle: preference.subtitle,
                        isSelected: viewModel.selectedStarterHabitPreference == preference
                    ) {
                        feedbackController.selection()
                        viewModel.chooseStarterHabitPreference(preference)
                    }
                }
            }

            customHabitButton

            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Suggestions")
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)

                ForEach(viewModel.filteredHabitSuggestions.prefix(4)) { template in
                    OnboardingHabitRecommendationCard(
                        template: template,
                        projectName: onboardingProjectName(for: template),
                        state: viewModel.selectedStarterHabitTemplateID == template.id ? .created(viewModel.createdHabitTemplateMap[template.id] ?? UUID()) : .idle,
                        isGuidanceHighlighted: viewModel.selectedStarterHabitTemplateID == template.id,
                        isSelectionEnabled: true,
                        onAdd: {
                            feedbackController.selection()
                            viewModel.chooseStarterHabitTemplate(template)
                        }
                    )
                }
            }
        }
    }

    var customHabitButton: some View {
        Button {
            guard let prefill = onboardingHabitPrefill() else {
                viewModel.errorMessage = OnboardingCopy.Error.customHabitFailed
                return
            }
            let opened = onOpenCustomHabitComposer(prefill)
            if opened == false {
                viewModel.errorMessage = OnboardingCopy.Error.customHabitFailed
            }
        } label: {
            OnboardingInlineActionRow(
                title: "Create custom habit",
                subtitle: "Use your own wording, cadence, and project.",
                systemImage: "plus.circle.fill",
                mascotPlacement: .habitStreakWin
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.customHabit)
        .accessibilityLabel("Create custom habit")
    }

    var streakPreviewStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Streak.title,
                subtitle: OnboardingCopy.Streak.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.streakPreview)

            if let presentation = viewModel.starterHabitBoardPresentation {
                OnboardingHabitStreakPreviewCard(presentation: presentation)
            }
        }
    }

    var evaStyleStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.EvaStyle.title,
                subtitle: OnboardingCopy.EvaStyle.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.evaStyle)

            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Working style")
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: spacing.s12)], spacing: spacing.s12) {
                    ForEach(EvaWorkingStyleID.allCases) { style in
                        OnboardingFilterChip(
                            title: style.title,
                            isSelected: viewModel.evaProfileDraft.selectedWorkingStyleIDs.contains(style.rawValue)
                        ) {
                            viewModel.toggleEvaWorkingStyle(style.rawValue)
                        }
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.workingStyle(style.id))
                    }
                }
            }

            OnboardingCustomEntryRow(
                placeholder: "Add your own working style",
                text: $customWorkingStyle,
                actionTitle: "Add style",
                focus: $focusedInputField,
                focusID: .workingStyle,
                onAdd: {
                    viewModel.addCustomEvaWorkingStyle(customWorkingStyle)
                    customWorkingStyle = ""
                    focusedInputField = nil
                }
            )
        }
    }

    var workBlockersStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.WorkBlockers.title,
                subtitle: OnboardingCopy.WorkBlockers.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.workBlockers)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: spacing.s12)], spacing: spacing.s12) {
                ForEach(EvaMomentumBlockerID.allCases) { blocker in
                    OnboardingFilterChip(
                        title: blocker.title,
                        isSelected: viewModel.evaProfileDraft.selectedMomentumBlockerIDs.contains(blocker.rawValue)
                    ) {
                        viewModel.toggleEvaMomentumBlocker(blocker.rawValue)
                    }
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.momentumBlocker(blocker.id))
                }
            }

            OnboardingCustomEntryRow(
                placeholder: "Add your own blocker",
                text: $customWorkBlocker,
                actionTitle: "Add blocker",
                focus: $focusedInputField,
                focusID: .workBlocker,
                onAdd: {
                    viewModel.addCustomEvaMomentumBlocker(customWorkBlocker)
                    customWorkBlocker = ""
                    focusedInputField = nil
                }
            )
        }
    }

    var weeklyOutcomesStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.WeeklyOutcomes.title,
                subtitle: OnboardingCopy.WeeklyOutcomes.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.weeklyOutcomes)

            ForEach(0..<visibleOutcomeCount, id: \.self) { index in
                TextField(
                    weeklyOutcomePlaceholder(at: index),
                    text: Binding(
                        get: { outcomeDrafts.indices.contains(index) ? outcomeDrafts[index] : "" },
                        set: { updateOutcomeDraft(at: index, text: $0) }
                    )
                )
                .textFieldStyle(.plain)
                .lifeboardFont(.body)
                .foregroundStyle(OnboardingTheme.textPrimary)
                .submitLabel(.done)
                .focused($focusedInputField, equals: .outcome(index))
                .id(OnboardingInputField.outcome(index))
                .accessibilityIdentifier(AppOnboardingAccessibilityID.weeklyOutcomeField(index))
                .padding(spacing.s16)
                .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
                )
            }

            if visibleOutcomeCount < 3 {
                Button {
                    feedbackController.light()
                    ensureOutcomeDraftCapacity(visibleOutcomeCount)
                    visibleOutcomeCount += 1
                    focusedInputField = .outcome(visibleOutcomeCount - 1)
                } label: {
                    Label("Add outcome", systemImage: "plus.circle")
                        .lifeboardFont(.buttonSmall)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.weeklyOutcomeAdd)
            }
        }
    }

    var processingStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Processing.title,
                subtitle: OnboardingCopy.Processing.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.processing)

            VStack(alignment: .leading, spacing: spacing.s12) {
                Label("Life areas and projects mapped", systemImage: "checkmark.circle.fill")
                Label("Starter habit prepared", systemImage: "repeat.circle.fill")
                Label("First task ready to start", systemImage: "bolt.circle.fill")
                Label("\(viewModel.selectedMascotPersona.displayName) keeps preparing while you continue", systemImage: "brain.head.profile")
            }
            .lifeboardFont(.body)
            .foregroundStyle(OnboardingTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(spacing.s20)
            .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
            )

            if viewModel.evaPreparationState.phase == .waitingForCellularConsent {
                OnboardingSelectionSummaryCard(
                    title: "Mobile data check",
                    message: "\(viewModel.selectedMascotPersona.displayName) needs your approval before using cellular data. You can defer and keep moving.",
                    mascotPlacement: .onboardingNotificationPermission
                )
            } else {
                OnboardingEvaStatusCard(state: viewModel.evaPreparationState, assistantName: viewModel.selectedMascotPersona.displayName)
            }
        }
        .task(id: viewModel.step) {
            await viewModel.runProcessingIfNeeded()
        }
    }

    var firstTaskStep: some View {
        return VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.FirstTask.title,
                subtitle: OnboardingCopy.FirstTask.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.firstTask)

            if let task = viewModel.starterTask {
                OnboardingTaskPreviewCard(
                    task: task,
                    projectName: viewModel.resolvedProjects.first(where: { $0.project.id == task.projectID })?.project.name ?? task.projectName ?? "Project"
                )
            }

            customTaskButton

            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Suggestions")
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)

                ForEach(viewModel.taskSuggestions.prefix(4)) { template in
                    OnboardingTaskRecommendationCard(
                        template: template,
                        state: viewModel.taskTemplateStates[template.id] ?? .idle,
                        isGuidanceHighlighted: viewModel.createdTaskTemplateMap[template.id] != nil,
                        showsIdleBadge: false,
                        accessibilityIdentifier: template.id == viewModel.taskSuggestions.first?.id
                            ? AppOnboardingAccessibilityID.primaryTaskAction
                            : AppOnboardingAccessibilityID.taskTemplate(template.id),
                        onAdd: {
                            feedbackController.selection()
                            Task { await viewModel.addSuggestedTask(template) }
                        },
                        onEdit: {
                            if let taskID = viewModel.createdTaskTemplateMap[template.id],
                               let task = viewModel.createdTasks.first(where: { $0.id == taskID }) {
                                _ = onEditTask(task)
                            }
                        }
                    )
                }
            }
        }
    }

    var customTaskButton: some View {
        Button {
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
                viewModel.errorMessage = OnboardingCopy.Error.customTaskFailed
            }
        } label: {
            OnboardingInlineActionRow(
                title: "Create my own task",
                subtitle: "Write the exact task you want to do today.",
                systemImage: "plus.circle.fill",
                mascotPlacement: .onboardingCaptureSetup
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.customTask)
        .accessibilityLabel("Create my own first task")
    }
}
