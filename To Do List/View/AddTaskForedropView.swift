//
//  AddTaskForedropView.swift
//  Tasker
//
//  Three-tier form: Primary Capture → Secondary Details → Advanced Planning.
//  Quick + Expand pattern optimized for ADHD execution.
//

import SwiftUI

// MARK: - Add Task Foredrop View

struct AddTaskForedropView: View {
    @ObservedObject var viewModel: AddTaskViewModel
    let containerMode: AddTaskContainerMode
    let showAddAnother: Bool
    @Binding var successFlash: Bool
    let onCancel: () -> Void
    let onCreate: () -> Void
    let onAddAnother: () -> Void
    let onExpandToLarge: () -> Void

    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    @State private var errorShakeTrigger = false
    @State private var didAutoFocusTitleField = false
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: "New Task",
                canSave: viewModel.viewState.canSubmit && !viewModel.isLoading
            ) {
                onCancel()
            } onSave: {
                submitTask()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    composerHeroCard
                        .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $viewModel.taskName,
                        isFocused: $titleFieldFocused,
                        placeholder: "What do you want to do?",
                        helperText: "Keep it short. You can clarify later.",
                        onSubmit: submitTask
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    if let suggestion = viewModel.aiSuggestion {
                        aiSuggestionCard(suggestion)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if viewModel.isGeneratingSuggestion {
                        HStack(spacing: spacing.s8) {
                            ProgressView()
                            Text(viewModel.aiSuggestion == nil ? "Generating instant suggestion..." : "Refining with AI...")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    }

                    coreDetailsDisclosure
                        .enhancedStaggeredAppearance(index: 2)

                    AddTaskDatePresetRow(dueDate: $viewModel.dueDate)
                        .enhancedStaggeredAppearance(index: 3)

                    AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                        .enhancedStaggeredAppearance(index: 4)

                    sectionCard(.schedule, index: 5) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            AddTaskReminderChip(
                                hasReminder: $viewModel.hasReminder,
                                reminderTime: $viewModel.reminderTime
                            )

                            AddTaskTypeChips(selectedType: $viewModel.selectedType)

                            AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)

                            if viewModel.dueDate != nil {
                                Button("Clear due date") {
                                    viewModel.dueDate = nil
                                }
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.statusWarning)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    sectionCard(.organize, index: 6) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            AddTaskProjectBar(
                                selectedProject: $viewModel.selectedProject,
                                projects: viewModel.projects,
                                onCreateProject: { name in
                                    viewModel.createProject(name: name)
                                }
                            )

                            if !viewModel.lifeAreas.isEmpty {
                                AddTaskEntityPicker(
                                    label: "Life Area",
                                    items: viewModel.lifeAreas.map { (id: $0.id, name: $0.name, icon: $0.icon) },
                                    selectedID: $viewModel.selectedLifeAreaID
                                )
                            }

                            if !viewModel.sections.isEmpty {
                                AddTaskEntityPicker(
                                    label: "Section",
                                    items: viewModel.sections.map { (id: $0.id, name: $0.name, icon: nil as String?) },
                                    selectedID: $viewModel.selectedSectionID
                                )
                            }

                            AddTaskTagMultiSelect(
                                tags: viewModel.tags,
                                selectedTagIDs: $viewModel.selectedTagIDs,
                                onCreateTag: { name, completion in
                                    viewModel.createTag(name: name, completion: completion)
                                }
                            )
                        }
                    }

                    sectionCard(.execution, index: 7) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            AddTaskDurationPicker(duration: $viewModel.estimatedDuration)

                            AddTaskEnumChipRow(
                                label: "Energy",
                                displayName: { $0.displayName },
                                icon: { $0.emoji.isEmpty ? "bolt" : $0.emoji },
                                selected: $viewModel.selectedEnergy
                            )

                            AddTaskEnumChipRow(
                                label: "Category",
                                displayName: { $0.displayName },
                                icon: { $0.emoji.isEmpty ? "tag" : $0.emoji },
                                selected: $viewModel.selectedCategory
                            )

                            AddTaskEnumChipRow(
                                label: "Context",
                                displayName: { $0.displayName },
                                icon: { $0.emoji.isEmpty ? "mappin" : $0.emoji },
                                selected: $viewModel.selectedContext
                            )
                        }
                    }

                    sectionCard(.relationships, index: 8) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            if !viewModel.availableParentTasks.isEmpty {
                                AddTaskTaskPicker(
                                    label: "Parent Task",
                                    tasks: viewModel.availableParentTasks,
                                    selectedTaskID: $viewModel.selectedParentTaskID
                                )
                            }

                            if !viewModel.availableDependencyTasks.isEmpty {
                                AddTaskDependenciesPicker(
                                    tasks: viewModel.availableDependencyTasks,
                                    selectedTaskIDs: $viewModel.selectedDependencyTaskIDs,
                                    dependencyKind: $viewModel.selectedDependencyKind
                                )
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
                            .bellShake(trigger: $errorShakeTrigger)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    AddTaskXPPreview(
                        priority: viewModel.selectedPriority,
                        estimatedDuration: viewModel.estimatedDuration,
                        dueDate: viewModel.dueDate,
                        todayXPSoFar: viewModel.todayXPSoFar,
                        isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled
                    )
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s20)
            }

            AddTaskCreateButton(
                isEnabled: viewModel.viewState.canSubmit,
                isLoading: viewModel.isLoading,
                successFlash: successFlash,
                showAddAnother: showAddAnother,
                buttonTitle: "Add Task",
                onCreateAction: submitTask,
                onAddAnotherAction: onAddAnother
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.tasker.surfacePrimary)
        .accessibilityIdentifier("addTask.view")
        .overlay(
            Color.tasker.statusSuccess
                .opacity(successFlash ? 0.05 : 0)
                .animation(TaskerAnimation.gentle, value: successFlash)
                .allowsHitTesting(false)
        )
        .onChange(of: viewModel.errorMessage) { _, errorMessage in
            if errorMessage != nil {
                errorShakeTrigger.toggle()
            }
        }
        .onAppear {
            if viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                viewModel.isCoreDetailsExpanded = true
            }
            guard layoutClass == .phone else { return }
            guard didAutoFocusTitleField == false else { return }
            didAutoFocusTitleField = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                titleFieldFocused = true
            }
        }
    }

    // MARK: - Helpers

    private var composerHeroCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: corner.r3, style: .continuous)
                        .fill(Color.tasker.accentWash)
                        .frame(width: 56, height: 56)

                    if reduceMotion {
                        Image(systemName: heroIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.tasker.accentPrimary)
                    } else {
                        Image(systemName: heroIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.tasker.accentPrimary)
                            .symbolEffect(.pulse.byLayer, value: successFlash)
                    }
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    HStack(spacing: spacing.s8) {
                        Text(heroEyebrow)
                            .font(.tasker(.caption1).weight(.semibold))
                            .foregroundStyle(Color.tasker.accentPrimary)
                        TaskerStatusPill(
                            text: heroStatusText,
                            systemImage: heroStatusSymbol,
                            tone: heroStatusTone
                        )
                    }

                    Text(heroTitle)
                        .font(.tasker(.title3))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Text(heroGuidance)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: spacing.s8) {
                TaskerHeroMetricTile(
                    title: "Lane",
                    value: viewModel.selectedType.displayName,
                    detail: viewModel.selectedPriority.displayName,
                    tone: .accent
                )
                TaskerHeroMetricTile(
                    title: "Due",
                    value: heroDueValue,
                    detail: heroProjectValue,
                    tone: viewModel.dueDate == nil ? .neutral : .success
                )
                TaskerHeroMetricTile(
                    title: "Depth",
                    value: heroDepthValue,
                    detail: viewModel.selectedEnergy.displayName,
                    tone: viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .warning : .neutral
                )
            }
        }
        .padding(spacing.s16)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
        .taskerSuccessPulse(isActive: successFlash)
        .accessibilityElement(children: .contain)
    }

    private var coreDetailsDisclosure: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Button {
                TaskerFeedback.selection()
                withAnimation(TaskerAnimation.snappy) {
                    viewModel.isCoreDetailsExpanded.toggle()
                }
                if viewModel.isCoreDetailsExpanded {
                    onExpandToLarge()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        descriptionFieldFocused = true
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: spacing.s12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(viewModel.isCoreDetailsExpanded ? Color.tasker.accentWash : Color.tasker.surfacePrimary)
                            .frame(width: 34, height: 34)

                        Image(systemName: "text.alignleft")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(viewModel.isCoreDetailsExpanded ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        HStack(spacing: spacing.s8) {
                            Text(viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add details" : "Details")
                                .font(.tasker(.callout).weight(.semibold))
                                .foregroundStyle(Color.tasker.textPrimary)

                            TaskerStatusPill(
                                text: viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Optional" : "Helpful",
                                systemImage: viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "sparkles" : "text.justify.leading",
                                tone: viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .quiet : .accent
                            )
                        }

                        Text(coreDetailsSummary)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .fill(Color.tasker.surfacePrimary.opacity(viewModel.isCoreDetailsExpanded ? 1 : 0.72))
                            .frame(width: 28, height: 28)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(viewModel.isCoreDetailsExpanded ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                            .rotationEffect(.degrees(viewModel.isCoreDetailsExpanded ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel(viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add details. Keep the title short. Add context only if it will help later." : "Details. \(coreDetailsSummary)")
            .accessibilityHint(viewModel.isCoreDetailsExpanded ? "Collapse details editor" : "Expand details editor")

            if viewModel.isCoreDetailsExpanded {
                AddTaskDescriptionField(
                    text: $viewModel.taskDetails,
                    isFocused: $descriptionFieldFocused
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(spacing.s12)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: viewModel.isCoreDetailsExpanded ? Color.tasker.surfacePrimary : Color.tasker.surfaceSecondary.opacity(0.72),
            accentColor: viewModel.isCoreDetailsExpanded ? Color.tasker.accentSecondary : Color.tasker.strokeHairline,
            level: viewModel.isCoreDetailsExpanded ? .e2 : .e1
        )
        .animation(TaskerAnimation.snappy, value: viewModel.isCoreDetailsExpanded)
    }

    private var coreDetailsSummary: String {
        let trimmed = viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Keep the title short. Add context only if it will help later."
        }
        let normalized = trimmed.replacingOccurrences(of: "\n", with: " ")
        if normalized.count <= 96 {
            return normalized
        }
        return "\(normalized.prefix(93))..."
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        _ section: TaskEditorSection,
        index: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TaskEditorSectionCard(
            section: section,
            summary: viewModel.summary(for: section),
            isExpanded: viewModel.isSectionExpanded(section)
        ) {
            TaskerFeedback.light()
            viewModel.toggleSection(section)
            if viewModel.isSectionExpanded(section) {
                if section == .relationships {
                    viewModel.loadRelationshipTaskOptionsIfNeeded()
                }
                onExpandToLarge()
            }
        } content: {
            content()
        }
        .enhancedStaggeredAppearance(index: index)
    }

    /// Executes submitTask.
    private func submitTask() {
        guard viewModel.viewState.canSubmit, !viewModel.isLoading else { return }
        onCreate()
    }

    /// Executes errorMessageView.
    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.tasker.statusWarning)

            Text(message)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.statusWarning)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.statusWarning.opacity(0.12))
        )
        .animation(TaskerAnimation.bouncy, value: viewModel.errorMessage != nil)
    }

    /// Executes aiSuggestionCard.
    private func aiSuggestionCard(_ suggestion: TaskFieldSuggestion) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if let routeBanner = suggestion.routeBanner, routeBanner.isEmpty == false {
                HStack(alignment: .top, spacing: spacing.s8) {
                    Image(systemName: "cpu")
                        .foregroundColor(Color.tasker.accentPrimary)
                    Text(routeBanner)
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textTertiary)
                    Spacer(minLength: 0)
                }
            }
            HStack {
                Text(viewModel.aiSuggestionIsRefined ? "AI refined" : "Instant suggestion")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                Spacer()
                Button("Accept all") {
                    viewModel.applyAISuggestion(suggestion)
                    TaskerFeedback.selection()
                }
                .font(.tasker(.caption1))
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    suggestionChip("⚡ \(suggestion.priority.displayName)") {
                        viewModel.selectedPriority = suggestion.priority
                    }
                    suggestionChip("🔋 \(suggestion.energy.displayName)") {
                        viewModel.selectedEnergy = suggestion.energy
                    }
                    suggestionChip("📍 \(suggestion.context.displayName)") {
                        viewModel.selectedContext = suggestion.context
                    }
                    suggestionChip("🕒 \(suggestion.type.displayName)") {
                        viewModel.selectedType = suggestion.type
                    }
                }
            }

            Text("Eva: \"\(suggestion.rationale)\"")
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .stroke(Color.tasker.accentMuted.opacity(0.35), lineWidth: 1)
                )
        )
    }

    /// Executes suggestionChip.
    private func suggestionChip(_ text: String, action: @escaping () -> Void) -> some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            Text(text)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.accentPrimary)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(Color.tasker.accentWash)
                .overlay(
                    Capsule()
                        .stroke(Color.tasker.accentPrimary.opacity(0.18), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private var heroIcon: String {
        switch viewModel.selectedType {
        case .morning:
            return "sun.max.fill"
        case .evening:
            return "moon.stars.fill"
        case .upcoming:
            return "arrow.right.circle.fill"
        case .inbox:
            return "tray.full.fill"
        }
    }

    private var heroEyebrow: String {
        if successFlash {
            return "Task captured"
        }
        return viewModel.viewState.canSubmit ? "Ready to add" : "Quick capture"
    }

    private var heroStatusText: String {
        if successFlash {
            return "Saved"
        }
        if viewModel.taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Draft"
        }
        return "In progress"
    }

    private var heroStatusSymbol: String {
        if successFlash {
            return "checkmark.circle.fill"
        }
        return viewModel.taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "pencil" : "sparkles"
    }

    private var heroStatusTone: TaskerStatusPillTone {
        if successFlash {
            return .success
        }
        return viewModel.taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .quiet : .accent
    }

    private var heroTitle: String {
        let trimmed = viewModel.taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Shape the next step before the backlog gets louder." : trimmed
    }

    private var heroGuidance: String {
        if let error = viewModel.errorMessage, error.isEmpty == false {
            return error
        }
        if viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "The title is clear. Use the sections below to tune timing, context, and execution."
        }
        return "Lead with the action. Add only the structure that will help you restart quickly later."
    }

    private var heroDueValue: String {
        guard let dueDate = viewModel.dueDate else { return "No date" }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var heroProjectValue: String {
        let project = viewModel.selectedProject.trimmingCharacters(in: .whitespacesAndNewlines)
        return project.isEmpty ? "Inbox" : project
    }

    private var heroDepthValue: String {
        if viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Lean"
        }
        return "Clarified"
    }
}

// MARK: - Task Type Chips

struct AddTaskTypeChips: View {
    @Binding var selectedType: TaskType

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private let types: [(type: TaskType, icon: String, label: String)] = [
        (.morning, "sun.max", "Morning"),
        (.evening, "moon.stars", "Evening"),
        (.upcoming, "arrow.right.circle", "Upcoming"),
    ]

    var body: some View {
        HStack(spacing: spacing.chipSpacing) {
            ForEach(types, id: \.type) { item in
                AddTaskMetadataChip(
                    icon: item.icon,
                    text: item.label,
                    isActive: selectedType == item.type
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        selectedType = item.type
                    }
                }
            }
        }
    }
}
