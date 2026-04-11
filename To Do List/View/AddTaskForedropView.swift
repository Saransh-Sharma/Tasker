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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    AddTaskTitleField(
                        text: $viewModel.taskName,
                        isFocused: $titleFieldFocused,
                        placeholder: "What do you want to do?",
                        helperText: "Keep it short. You can clarify later.",
                        onSubmit: submitTask
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    baseComposerSections
                        .enhancedStaggeredAppearance(index: 1)

                    if viewModel.isCoreDetailsExpanded {
                        detailedSections
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
                            .bellShake(trigger: $errorShakeTrigger)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

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

    private var baseComposerSections: some View {
        VStack(spacing: spacing.s16) {
            if dynamicTypeSize.isAccessibilitySize {
                dueDateSection
                ownershipSection
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: spacing.s16) {
                        dueDateSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ownershipSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: spacing.s16) {
                        dueDateSection
                        ownershipSection
                    }
                }
            }

            TaskerComposerDisclosureRow(
                title: "Add details",
                summary: coreDetailsSummary,
                isExpanded: viewModel.isCoreDetailsExpanded,
                accessibilityIdentifier: "addTask.detailsDisclosure"
            ) {
                withAnimation(TaskerAnimation.snappy) {
                    viewModel.isCoreDetailsExpanded.toggle()
                }
                if viewModel.isCoreDetailsExpanded {
                    onExpandToLarge()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        descriptionFieldFocused = true
                    }
                }
            }
        }
    }

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            AddTaskDatePresetRow(dueDate: $viewModel.dueDate)
        }
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            TaskerComposerOptionGrid(
                title: "Life Area",
                helperText: "Pick an area to narrow projects.",
                options: viewModel.lifeAreas.map { TaskerComposerOption(id: $0.id, title: $0.name, icon: $0.icon) },
                selectedID: viewModel.selectedLifeAreaID,
                noneOptionTitle: "Any area",
                emptyStateText: viewModel.lifeAreas.isEmpty ? "No life areas yet." : nil,
                accessibilityIdentifier: "addTask.lifeAreaSelector"
            ) { selectedID in
                withAnimation(TaskerAnimation.snappy) {
                    viewModel.selectedLifeAreaID = selectedID
                }
            }

            TaskerComposerOptionGrid(
                title: "Project",
                helperText: "Choose a project or leave this in Inbox.",
                options: viewModel.filteredProjectsForSelectedLifeArea.map { TaskerComposerOption(id: $0.name, title: $0.name, icon: nil) },
                selectedID: viewModel.selectedProject == ProjectConstants.inboxProjectName ? nil : viewModel.selectedProject,
                noneOptionTitle: "Inbox",
                emptyStateText: viewModel.filteredProjectsForSelectedLifeArea.isEmpty ? "No projects in this area." : nil,
                accessibilityIdentifier: "addTask.projectSelector"
            ) { selectedProject in
                withAnimation(TaskerAnimation.snappy) {
                    viewModel.selectedProject = selectedProject ?? ProjectConstants.inboxProjectName
                }
            }
        }
    }

    private var detailedSections: some View {
        VStack(spacing: spacing.s16) {
            AddTaskDescriptionField(
                text: $viewModel.taskDetails,
                isFocused: $descriptionFieldFocused
            )

            AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)

            if viewModel.isGeneratingSuggestion {
                HStack(spacing: spacing.s8) {
                    ProgressView()
                    Text(viewModel.aiSuggestion == nil ? "Thinking through the details…" : "Refreshing suggestions…")
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let suggestion = viewModel.aiSuggestion {
                aiSuggestionCard(suggestion)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            sectionCard(.schedule, index: 2) {
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
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.statusWarning)
                        .buttonStyle(.plain)
                    }
                }
            }

            sectionCard(.organize, index: 3) {
                VStack(alignment: .leading, spacing: spacing.s12) {
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

            sectionCard(.execution, index: 4) {
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

            sectionCard(.relationships, index: 5) {
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
        }
    }

    private var coreDetailsSummary: String {
        let trimmed = viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Priority, notes, scheduling, tags, and linked tasks stay optional."
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
                        .foregroundStyle(Color.tasker.accentPrimary)
                    Text(routeBanner)
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textTertiary)
                    Spacer(minLength: 0)
                }
            }
            HStack {
                Text(viewModel.aiSuggestionIsRefined ? "AI refined" : "Instant suggestion")
                    .font(.tasker(.meta))
                    .foregroundStyle(Color.tasker.textSecondary)
                Spacer()
                Button("Accept all") {
                    viewModel.applyAISuggestion(suggestion)
                    TaskerFeedback.selection()
                }
                .font(.tasker(.meta).weight(.semibold))
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    suggestionChip("Priority: \(suggestion.priority.displayName)") {
                        viewModel.selectedPriority = suggestion.priority
                    }
                    suggestionChip("Energy: \(suggestion.energy.displayName)") {
                        viewModel.selectedEnergy = suggestion.energy
                    }
                    suggestionChip("Context: \(suggestion.context.displayName)") {
                        viewModel.selectedContext = suggestion.context
                    }
                    suggestionChip("Type: \(suggestion.type.displayName)") {
                        viewModel.selectedType = suggestion.type
                    }
                }
            }

            Text(suggestion.rationale)
                .font(.tasker(.meta))
                .foregroundStyle(Color.tasker.textTertiary)
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
                .font(.tasker(.meta))
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

struct TaskerComposerOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let icon: String?
}

struct TaskerComposerOptionGrid<ID: Hashable>: View {
    let title: String
    let helperText: String?
    let options: [TaskerComposerOption<ID>]
    let selectedID: ID?
    let noneOptionTitle: String?
    let emptyStateText: String?
    let accessibilityIdentifier: String?
    let onSelect: (ID?) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 168 : 128), spacing: spacing.s8, alignment: .leading)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(title)
                    .font(.tasker(.callout).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)

                if let helperText, helperText.isEmpty == false {
                    Text(helperText)
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: spacing.s8) {
                if let noneOptionTitle {
                    optionButton(
                        title: noneOptionTitle,
                        icon: "minus",
                        isSelected: selectedID == nil
                    ) {
                        onSelect(nil)
                    }
                }

                ForEach(options) { option in
                    optionButton(
                        title: option.title,
                        icon: option.icon,
                        isSelected: selectedID == option.id
                    ) {
                        onSelect(option.id)
                    }
                }
            }
            .accessibilityIdentifier(accessibilityIdentifier ?? "")

            if options.isEmpty, let emptyStateText, emptyStateText.isEmpty == false {
                Text(emptyStateText)
                    .font(.tasker(.meta))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .padding(.top, spacing.s4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func optionButton(
        title: String,
        icon: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                if let icon, icon.isEmpty == false {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                }

                Text(title)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.tasker.accentPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(isSelected ? Color.tasker.accentRing : Color.tasker.strokeHairline, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .animation(TaskerAnimation.quick, value: isSelected)
    }
}

struct TaskerComposerDisclosureRow: View {
    let title: String
    let summary: String
    let isExpanded: Bool
    let accessibilityIdentifier: String?
    let action: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            HStack(alignment: .top, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)

                    Text(summary)
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.tasker.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .padding(.top, 2)
            }
            .padding(spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(isExpanded ? 0.72 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(Color.tasker.strokeHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .accessibilityLabel("\(title). \(summary)")
        .accessibilityHint(isExpanded ? "Collapse details" : "Expand details")
        .animation(TaskerAnimation.snappy, value: isExpanded)
    }
}
