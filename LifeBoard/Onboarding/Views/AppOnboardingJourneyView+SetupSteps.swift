import SwiftUI

extension AppOnboardingJourneyView {
    var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            OnboardingSectionHeader(
                title: OnboardingCopy.LifeAreas.title,
                subtitle: OnboardingCopy.LifeAreas.subtitle,
                detail: "\(viewModel.selectedLifeAreaIDs.count) selected"
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.lifeAreas)

            if viewModel.allowsShowAllAreas,
               viewModel.showAllLifeAreas == false,
               StarterWorkspaceCatalog.orderedLifeAreas(for: viewModel.frictionProfile).count > viewModel.visibleLifeAreas.count {
                Button {
                    feedbackController.light()
                    viewModel.showAllAreas()
                } label: {
                    Label(OnboardingCopy.LifeAreas.showMore, systemImage: "square.grid.2x2")
                }
                .buttonStyle(.lifeBoardChip)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 220 : 156), spacing: spacing.s12)],
                spacing: spacing.s12
            ) {
                ForEach(Array(viewModel.visibleLifeAreas.enumerated()), id: \.element.id) { index, area in
                    OnboardingSelectableCard(
                        title: area.name,
                        subtitle: area.subtitle,
                        icon: area.icon,
                        colorHex: area.colorHex,
                        accessibilityID: AppOnboardingAccessibilityID.lifeArea(area.id),
                        isSelected: viewModel.selectedLifeAreaIDs.contains(area.id)
                    ) {
                        registerSelection()
                        viewModel.toggleLifeArea(area.id)
                    }
                    .cardEntrance(index: index)
                }
            }
        }
    }

    var guideStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(title: OnboardingCopy.Guide.title)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.evaValue)

            OnboardingMascotCarousel(
                selectedID: viewModel.selectedMascotID,
                personas: AssistantMascotPersona.all,
                onSelect: { id in
                    registerSelection()
                    viewModel.selectChiefOfStaffMascot(id)
                }
            )
            .frame(height: layoutClass.isPad ? 430 : 340)
        }
    }

    // MARK: - First win

    /// One habit and one task, in a single screen.
    ///
    /// These were two consecutive steps that each asked for one small thing; they
    /// read better together, and merging them is what made room for the day shape
    /// and module steps without lengthening the flow.
    var firstWinStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(title: OnboardingCopy.FirstWin.title)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.habitSetup)

            habitSection
            taskSection
        }
        .completionCelebration(isComplete: didCelebrateFirstWin, tint: currentVisualTheme.accent)
        .onChange(of: viewModel.starterTask?.id) { _, taskID in
            guard taskID != nil, viewModel.starterHabit != nil, didCelebrateFirstWin == false else { return }
            didCelebrateFirstWin = true
        }
    }

    private var habitSection: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text(OnboardingCopy.FirstWin.habitHeading)
                .lifeboardFont(.bodyEmphasis)
                .foregroundStyle(OnboardingTheme.textPrimary)

            VStack(spacing: spacing.s12) {
                ForEach(OnboardingStarterHabitPreference.allCases, id: \.rawValue) { preference in
                    OnboardingSelectableDetailCard(
                        title: preference.title,
                        subtitle: preference.subtitle,
                        isSelected: viewModel.selectedStarterHabitPreference == preference
                    ) {
                        registerSelection()
                        viewModel.chooseStarterHabitPreference(preference)
                    }
                }
            }

            ForEach(Array(viewModel.filteredHabitSuggestions.prefix(3).enumerated()), id: \.element.id) { index, template in
                OnboardingHabitRecommendationCard(
                    template: template,
                    projectName: onboardingProjectName(for: template),
                    state: viewModel.selectedStarterHabitTemplateID == template.id
                        ? .created(viewModel.createdHabitTemplateMap[template.id] ?? UUID())
                        : .idle,
                    isGuidanceHighlighted: viewModel.selectedStarterHabitTemplateID == template.id,
                    isSelectionEnabled: true,
                    onAdd: {
                        registerSelection()
                        viewModel.chooseStarterHabitTemplate(template)
                    }
                )
                .cardEntrance(index: index)
            }

            customHabitButton
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text(OnboardingCopy.FirstWin.taskHeading)
                .lifeboardFont(.bodyEmphasis)
                .foregroundStyle(OnboardingTheme.textPrimary)

            if let task = viewModel.starterTask {
                OnboardingTaskPreviewCard(
                    task: task,
                    projectName: viewModel.resolvedProjects
                        .first(where: { $0.project.id == task.projectID })?.project.name
                        ?? task.projectName
                        ?? ""
                )
            }

            ForEach(Array(viewModel.taskSuggestions.prefix(3).enumerated()), id: \.element.id) { index, template in
                OnboardingTaskRecommendationCard(
                    template: template,
                    state: viewModel.taskTemplateStates[template.id] ?? .idle,
                    isGuidanceHighlighted: viewModel.createdTaskTemplateMap[template.id] != nil,
                    showsIdleBadge: false,
                    accessibilityIdentifier: template.id == viewModel.taskSuggestions.first?.id
                        ? AppOnboardingAccessibilityID.primaryTaskAction
                        : AppOnboardingAccessibilityID.taskTemplate(template.id),
                    onAdd: {
                        registerSelection()
                        Task { await viewModel.addSuggestedTask(template) }
                    },
                    onEdit: {
                        if let taskID = viewModel.createdTaskTemplateMap[template.id],
                           let task = viewModel.createdTasks.first(where: { $0.id == taskID }) {
                            _ = onEditTask(task)
                        }
                    }
                )
                .cardEntrance(index: index)
            }

            customTaskButton
        }
    }

    var customHabitButton: some View {
        Button {
            guard let prefill = onboardingHabitPrefill() else {
                viewModel.errorMessage = OnboardingCopy.Error.customHabitFailed
                return
            }
            if onOpenCustomHabitComposer(prefill) == false {
                viewModel.errorMessage = OnboardingCopy.Error.customHabitFailed
            }
        } label: {
            Label(OnboardingCopy.FirstWin.customHabit, systemImage: "plus.circle.fill")
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.customHabit)
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
            Label(OnboardingCopy.FirstWin.customTask, systemImage: "plus.circle.fill")
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.customTask)
    }

    func onboardingProjectName(for template: StarterHabitTemplate) -> String? {
        guard let projectTemplateID = template.projectTemplateID else { return nil }
        return viewModel.resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.name
    }

    func onboardingHabitPrefill() -> AddHabitPrefillTemplate? {
        if let template = viewModel.primaryHabitSuggestions.first,
           let resolvedLifeArea = viewModel.resolvedLifeAreas.first(where: { $0.templateID == template.lifeAreaTemplateID }) {
            let projectID = template.projectTemplateID.flatMap { projectTemplateID in
                viewModel.resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.id
            }
            return template.makePrefill(lifeAreaID: resolvedLifeArea.lifeArea.id, projectID: projectID)
        }

        guard let lifeArea = viewModel.resolvedLifeAreas.first?.lifeArea else { return nil }
        return AddHabitPrefillTemplate(
            title: "",
            lifeAreaID: lifeArea.id,
            projectID: viewModel.resolvedProjects.first?.project.id
        )
    }
}
