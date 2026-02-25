//
//  TaskDetailSheetView.swift
//  Tasker
//
//  Action-first task details with Add Task field parity.
//

import SwiftUI

struct TaskDetailSheetView: View {
    typealias UpdateHandler = (UUID, UpdateTaskDefinitionRequest, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias CompletionHandler = (UUID, Bool, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias DeleteHandler = (UUID, TaskDeleteScope, @escaping (Result<Void, Error>) -> Void) -> Void
    typealias RescheduleHandler = (UUID, Date?, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias MetadataHandler = (UUID, @escaping (Result<TaskDetailMetadataPayload, Error>) -> Void) -> Void
    typealias ChildrenHandler = (UUID, @escaping (Result<[TaskDefinition], Error>) -> Void) -> Void
    typealias CreateTaskHandler = (CreateTaskDefinitionRequest, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias CreateTagHandler = (String, @escaping (Result<TagDefinition, Error>) -> Void) -> Void
    typealias CreateProjectHandler = (String, @escaping (Result<Project, Error>) -> Void) -> Void

    private enum ActiveEditor: Hashable {
        case due
        case reminder
        case priority
        case project
        case type
        case tags
    }

    /// Initializes a new instance.
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskDetailViewModel

    @State private var activeEditor: ActiveEditor?
    @State private var showDeleteScopeDialog = false
    @State private var showDescriptionEditor = false
    @State private var newStepTitle = ""

    @FocusState private var titleFocused: Bool
    @FocusState private var stepFocused: Bool
    @FocusState private var descriptionFocused: Bool

    init(
        task: TaskDefinition,
        projects: [Project],
        onUpdate: @escaping UpdateHandler,
        onSetCompletion: @escaping CompletionHandler,
        onDelete: @escaping DeleteHandler,
        onReschedule: @escaping RescheduleHandler,
        onLoadMetadata: @escaping MetadataHandler,
        onLoadChildren: @escaping ChildrenHandler,
        onCreateTask: @escaping CreateTaskHandler,
        onCreateTag: @escaping CreateTagHandler,
        onCreateProject: @escaping CreateProjectHandler
    ) {
        _viewModel = StateObject(wrappedValue: TaskDetailViewModel(
            task: task,
            projects: projects,
            onUpdate: onUpdate,
            onSetCompletion: onSetCompletion,
            onDelete: onDelete,
            onReschedule: onReschedule,
            onLoadMetadata: onLoadMetadata,
            onLoadChildren: onLoadChildren,
            onCreateTask: onCreateTask,
            onCreateTag: onCreateTag,
            onCreateProject: onCreateProject
        ))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                Rectangle()
                    .fill(priorityColor)
                    .frame(height: 4)
                    .animation(TaskerAnimation.gentle, value: viewModel.selectedPriority)

                topBar
                headerSection
                    .enhancedStaggeredAppearance(index: 0)
                autosaveBanner
                primaryActionsRow
                    .enhancedStaggeredAppearance(index: 1)
                metadataChipRow
                    .enhancedStaggeredAppearance(index: 2)
                activeEditorPanel
                notesSection
                    .enhancedStaggeredAppearance(index: 3)
                stepsSection
                    .enhancedStaggeredAppearance(index: 4)
                moreDetailsSection
                    .enhancedStaggeredAppearance(index: 5)
                advancedSection
                    .enhancedStaggeredAppearance(index: 6)
                destructiveSection
                metadataFooter
            }
            .padding(.bottom, TaskerTheme.Spacing.xxxl)
        }
        .background(Color.tasker.bgCanvas)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("taskDetail.view")
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.taskName) { _ in
            viewModel.scheduleAutosave(debounced: true)
        }
        .onChange(of: viewModel.taskDescription) { _ in
            viewModel.scheduleAutosave(debounced: true)
        }
        .onChange(of: viewModel.selectedPriority) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedType) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedProjectID) { _ in
            viewModel.refreshMetadata()
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.dueDate) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.reminderTime) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedLifeAreaID) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedSectionID) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedTagIDs) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedParentTaskID) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedDependencyTaskIDs) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedDependencyKind) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedEnergy) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedCategory) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.selectedContext) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.estimatedDuration) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.repeatPattern) { _ in
            viewModel.scheduleAutosave(debounced: false)
        }
        .confirmationDialog(
            "Delete recurring task?",
            isPresented: $showDeleteScopeDialog,
            titleVisibility: .visible
        ) {
            Button("Delete This Task", role: .destructive) {
                deleteTask(scope: .single)
            }
            Button("Delete Entire Series", role: .destructive) {
                deleteTask(scope: .series)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to remove only this task or every task in the series.")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.tasker.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("taskDetail.closeButton")
            .accessibilityLabel("Close task details")

            Spacer()

            Text("Task")
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)

            Spacer()

            Menu {
                Button(role: .destructive) {
                    promptDeleteTask()
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .accessibilityLabel("More actions")
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.top, TaskerTheme.Spacing.sm)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: TaskerTheme.Spacing.md) {
                CompletionCheckbox(isComplete: viewModel.isComplete) {
                    viewModel.toggleRootCompletion()
                }
                .accessibilityIdentifier("taskDetail.completeButton")
                .accessibilityHint("Double tap to toggle completion")

                TextField("Task title", text: $viewModel.taskName)
                    .font(.tasker(.title2))
                    .foregroundColor(Color.tasker.textPrimary)
                    .focused($titleFocused)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("taskDetail.titleField")
            }

            HStack(spacing: TaskerTheme.Spacing.sm) {
                PriorityBadge(priority: viewModel.selectedPriority.rawValue)
                ScoreBadge(points: viewModel.selectedPriority.scorePoints)

                Spacer()

                Text(viewModel.selectedProjectName)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.accentPrimary)
                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.tasker.accentMuted)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("taskDetail.projectLabel")
            }

            Text(statusText)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
                .accessibilityLabel("Task status \(statusText)")
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    @ViewBuilder
    private var autosaveBanner: some View {
        if viewModel.autosaveState != .idle {
            Text(viewModel.autosaveState.label)
                .font(.tasker(.caption2))
                .foregroundColor(autosaveColor)
                .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
                .accessibilityLabel(viewModel.autosaveState.label)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
        }
    }

    private var primaryActionsRow: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            actionChip(icon: "calendar.badge.clock", title: "Schedule", tint: Color.tasker.accentPrimary) {
                toggleEditor(.due)
            }
            .accessibilityHint("Edit due date")

            actionChip(icon: "list.bullet", title: "Make smaller", tint: Color.tasker.accentPrimary) {
                stepFocused = true
            }
            .accessibilityHint("Focus add step input")

            actionChip(
                icon: viewModel.isComplete ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill",
                title: viewModel.isComplete ? "Reopen" : "Complete",
                tint: viewModel.isComplete ? Color.tasker.statusWarning : Color.tasker.statusSuccess
            ) {
                viewModel.toggleRootCompletion()
            }
            .accessibilityIdentifier("taskDetail.completeButton.action")
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .accessibilityIdentifier("taskDetail.actionRow")
    }

    /// Executes actionChip.
    private func actionChip(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.tasker(.callout))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(tint.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private var metadataChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                AddTaskMetadataChip(
                    icon: "calendar",
                    text: dueChipText,
                    isActive: activeEditor == .due || viewModel.dueDate != nil
                ) {
                    toggleEditor(.due)
                }
                .accessibilityIdentifier("taskDetail.chip.due")

                AddTaskMetadataChip(
                    icon: viewModel.reminderTime == nil ? "bell" : "bell.fill",
                    text: reminderChipText,
                    isActive: activeEditor == .reminder || viewModel.reminderTime != nil
                ) {
                    toggleEditor(.reminder)
                }
                .accessibilityIdentifier("taskDetail.chip.reminder")

                AddTaskMetadataChip(
                    icon: "flag.fill",
                    text: viewModel.selectedPriority.displayName,
                    isActive: activeEditor == .priority
                ) {
                    toggleEditor(.priority)
                }
                .accessibilityIdentifier("taskDetail.chip.priority")

                AddTaskMetadataChip(
                    icon: "folder",
                    text: viewModel.selectedProjectName,
                    isActive: activeEditor == .project
                ) {
                    toggleEditor(.project)
                }
                .accessibilityIdentifier("taskDetail.chip.project")

                AddTaskMetadataChip(
                    icon: typeChipIcon,
                    text: viewModel.selectedType.displayName,
                    isActive: activeEditor == .type
                ) {
                    toggleEditor(.type)
                }
                .accessibilityIdentifier("taskDetail.chip.type")

                AddTaskMetadataChip(
                    icon: "number",
                    text: tagsChipText,
                    isActive: activeEditor == .tags || !viewModel.selectedTagIDs.isEmpty
                ) {
                    toggleEditor(.tags)
                }
                .accessibilityIdentifier("taskDetail.chip.tags")
            }
            .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        }
    }

    @ViewBuilder
    private var activeEditorPanel: some View {
        Group {
            switch activeEditor {
            case .due:
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                    AddTaskDatePresetRow(dueDate: $viewModel.dueDate)
                    if viewModel.dueDate != nil {
                        Button("Clear due date") {
                            viewModel.dueDate = nil
                        }
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.statusWarning)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)

            case .reminder:
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                    AddTaskReminderChip(
                        hasReminder: hasReminderBinding,
                        reminderTime: reminderTimeBinding
                    )
                    if viewModel.reminderTime != nil {
                        Button("Clear reminder") {
                            viewModel.reminderTime = nil
                        }
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.statusWarning)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)

            case .priority:
                AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                    .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)

            case .project:
                AddTaskProjectBar(
                    selectedProject: selectedProjectNameBinding,
                    projects: viewModel.projects,
                    onCreateProject: { name in
                        viewModel.createProject(name: name) { _ in }
                    }
                )
                .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)

            case .type:
                AddTaskTypeChips(selectedType: $viewModel.selectedType)
                    .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)

            case .tags:
                AddTaskTagMultiSelect(
                    tags: viewModel.tags,
                    selectedTagIDs: $viewModel.selectedTagIDs,
                    onCreateTag: { name, completion in
                        viewModel.createTag(name: name, completion: completion)
                    }
                )
                .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)

            case .none:
                EmptyView()
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(TaskerAnimation.snappy, value: activeEditor)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack {
                Text("Notes")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                Spacer()
                Button(showDescriptionEditor ? "Done" : "Edit") {
                    showDescriptionEditor.toggle()
                    if showDescriptionEditor {
                        descriptionFocused = true
                    }
                }
                .font(.tasker(.caption1).weight(.medium))
                .foregroundColor(Color.tasker.accentPrimary)
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskDetail.editButton")
            }

            if showDescriptionEditor {
                AddTaskDescriptionField(text: $viewModel.taskDescription, isFocused: $descriptionFocused)
                    .accessibilityIdentifier("taskDetail.descriptionField")
            } else {
                Group {
                    if descriptionIsEmpty {
                        Text(descriptionPreview)
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textQuaternary)
                            .italic()
                    } else {
                        Text(descriptionPreview)
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textSecondary)
                    }
                }
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TaskerTheme.Spacing.md)
                .background(Color.tasker.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
                .accessibilityIdentifier("taskDetail.descriptionField")
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Text("Steps")
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)

            if viewModel.childSteps.isEmpty {
                Text("Break the task into tiny steps to make starting easier.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)
                    .padding(.vertical, TaskerTheme.Spacing.xs)
            }

            ForEach(Array(viewModel.childSteps.enumerated()), id: \.element.id) { stepIndex, step in
                HStack(spacing: TaskerTheme.Spacing.sm) {
                    CompletionCheckbox(isComplete: step.isComplete, compact: true) {
                        viewModel.toggleStepCompletion(step)
                    }
                    .accessibilityHint("Toggle step completion")

                    Text(step.title)
                        .font(.tasker(.callout))
                        .foregroundColor(step.isComplete ? Color.tasker.textTertiary : Color.tasker.textPrimary)
                        .strikethrough(step.isComplete, color: Color.tasker.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Button("Move up") {
                            viewModel.moveStepUp(step)
                        }
                        Button("Move down") {
                            viewModel.moveStepDown(step)
                        }
                        Button("Delete", role: .destructive) {
                            viewModel.deleteStep(step)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.tasker.textSecondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .padding(.vertical, TaskerTheme.Spacing.sm)
                .background(Color.tasker.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
                .taskCompletionTransition(isComplete: step.isComplete)
                .enhancedStaggeredAppearance(index: stepIndex)
                .accessibilityIdentifier("taskDetail.step.\(step.id.uuidString)")
            }

            HStack(spacing: TaskerTheme.Spacing.sm) {
                TextField("Add a step...", text: $newStepTitle)
                    .font(.tasker(.callout))
                    .focused($stepFocused)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addStep()
                    }
                    .accessibilityIdentifier("taskDetail.stepInput")

                Button {
                    addStep()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.tasker.accentPrimary)
                }
                .buttonStyle(.plain)
                .disabled(newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add step")
            }
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, TaskerTheme.Spacing.sm)
            .background(Color.tasker.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var moreDetailsSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Button {
                withAnimation(TaskerAnimation.snappy) {
                    viewModel.showMoreDetails.toggle()
                }
            } label: {
                HStack {
                    Text("More details")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.tasker.textTertiary)
                        .rotationEffect(.degrees(viewModel.showMoreDetails ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if viewModel.showMoreDetails {
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    if !viewModel.lifeAreas.isEmpty {
                        AddTaskEntityPicker(
                            label: "Life Area",
                            items: viewModel.lifeAreas.map { (id: $0.id, name: $0.name, icon: $0.icon) },
                            selectedID: $viewModel.selectedLifeAreaID
                        )
                        .accessibilityIdentifier("taskDetail.lifeAreaPicker")
                    }

                    if !viewModel.sections.isEmpty {
                        AddTaskEntityPicker(
                            label: "Section",
                            items: viewModel.sections.map { (id: $0.id, name: $0.name, icon: nil as String?) },
                            selectedID: $viewModel.selectedSectionID
                        )
                        .accessibilityIdentifier("taskDetail.sectionPicker")
                    }
                }
            }
        }
        .padding(TaskerTheme.Spacing.md)
        .background(Color.tasker.surfaceSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Button {
                withAnimation(TaskerAnimation.snappy) {
                    viewModel.showAdvancedDetails.toggle()
                }
            } label: {
                HStack {
                    Text("Advanced")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.tasker.textTertiary)
                        .rotationEffect(.degrees(viewModel.showAdvancedDetails ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if viewModel.showAdvancedDetails {
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    if !viewModel.availableParentTasks.isEmpty {
                        AddTaskTaskPicker(
                            label: "Parent Task",
                            tasks: viewModel.availableParentTasks,
                            selectedTaskID: $viewModel.selectedParentTaskID
                        )
                        .accessibilityIdentifier("taskDetail.parentTaskPicker")
                    }

                    if !viewModel.availableDependencyTasks.isEmpty {
                        AddTaskDependenciesPicker(
                            tasks: viewModel.availableDependencyTasks,
                            selectedTaskIDs: $viewModel.selectedDependencyTaskIDs,
                            dependencyKind: $viewModel.selectedDependencyKind
                        )
                        .accessibilityIdentifier("taskDetail.dependenciesPicker")
                    }

                    AddTaskEnumChipRow(
                        label: "Energy",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "bolt" : $0.emoji },
                        selected: $viewModel.selectedEnergy
                    )
                    .accessibilityIdentifier("taskDetail.energyPicker")

                    AddTaskEnumChipRow(
                        label: "Category",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "tag" : $0.emoji },
                        selected: $viewModel.selectedCategory
                    )
                    .accessibilityIdentifier("taskDetail.categoryPicker")

                    AddTaskEnumChipRow(
                        label: "Context",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "mappin" : $0.emoji },
                        selected: $viewModel.selectedContext
                    )
                    .accessibilityIdentifier("taskDetail.contextPicker")

                    AddTaskDurationPicker(duration: $viewModel.estimatedDuration)
                        .accessibilityIdentifier("taskDetail.durationPicker")

                    AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)
                        .accessibilityIdentifier("taskDetail.repeatPicker")
                }
            }
        }
        .padding(TaskerTheme.Spacing.md)
        .background(Color.tasker.surfaceSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var destructiveSection: some View {
        Button(role: .destructive) {
            promptDeleteTask()
        } label: {
            Text("Delete Task")
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.statusDanger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TaskerTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .accessibilityIdentifier("taskDetail.deleteButton")
    }

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            Text("Added \(DateUtils.formatDateTime(viewModel.persistedTask.dateAdded))")
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)

            if viewModel.isComplete, let completedAt = viewModel.persistedTask.dateCompleted {
                Text("Completed \(DateUtils.formatDateTime(completedAt))")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var hasReminderBinding: Binding<Bool> {
        Binding(
            get: { viewModel.reminderTime != nil },
            set: { hasReminder in
                if hasReminder {
                    if viewModel.reminderTime == nil {
                        viewModel.reminderTime = Date()
                    }
                } else {
                    viewModel.reminderTime = nil
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { viewModel.reminderTime ?? Date() },
            set: { viewModel.reminderTime = $0 }
        )
    }

    private var selectedProjectNameBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedProjectName },
            set: { newName in
                guard let projectID = viewModel.projects.first(where: { $0.name == newName })?.id else { return }
                viewModel.selectedProjectID = projectID
            }
        )
    }

    private var statusText: String {
        if viewModel.isComplete {
            if let dateCompleted = viewModel.persistedTask.dateCompleted {
                return "Completed · \(DateUtils.formatDateTime(dateCompleted))"
            }
            return "Completed"
        }

        if let dueDate = viewModel.dueDate {
            return "Due \(DateUtils.formatDate(dueDate))"
        }

        return "Not started"
    }

    private var autosaveColor: Color {
        switch viewModel.autosaveState {
        case .idle:
            return Color.clear
        case .saving:
            return Color.tasker.textTertiary
        case .saved:
            return Color.tasker.statusSuccess
        case .failed:
            return Color.tasker.statusDanger
        }
    }

    private var priorityColor: Color {
        switch viewModel.selectedPriority {
        case .none: return Color.tasker.priorityNone
        case .low: return Color.tasker.priorityLow
        case .high: return Color.tasker.priorityHigh
        case .max: return Color.tasker.priorityMax
        }
    }

    private var dueChipText: String {
        guard let dueDate = viewModel.dueDate else { return "No due" }
        return DateUtils.formatDate(dueDate)
    }

    private var reminderChipText: String {
        guard let reminderTime = viewModel.reminderTime else { return "Reminder" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: reminderTime)
    }

    private var typeChipIcon: String {
        switch viewModel.selectedType {
        case .morning: return "sun.max"
        case .evening: return "moon.stars"
        case .upcoming: return "arrow.right.circle"
        case .inbox: return "tray"
        }
    }

    private var tagsChipText: String {
        if viewModel.selectedTagIDs.isEmpty {
            return "Tags"
        }
        return "Tags · \(viewModel.selectedTagIDs.count)"
    }

    private var descriptionIsEmpty: Bool {
        viewModel.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var descriptionPreview: String {
        descriptionIsEmpty ? "Add details you'll want later (optional)." : viewModel.taskDescription
    }

    /// Executes toggleEditor.
    private func toggleEditor(_ editor: ActiveEditor) {
        withAnimation(TaskerAnimation.snappy) {
            activeEditor = (activeEditor == editor) ? nil : editor
        }
    }

    /// Executes addStep.
    private func addStep() {
        let candidate = newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return }

        viewModel.createStep(title: candidate) { success in
            guard success else { return }
            newStepTitle = ""
            stepFocused = true
        }
    }

    /// Executes promptDeleteTask.
    private func promptDeleteTask() {
        TaskerFeedback.warning()
        if viewModel.persistedTask.recurrenceSeriesID != nil {
            showDeleteScopeDialog = true
            return
        }
        deleteTask(scope: .single)
    }

    /// Executes deleteTask.
    private func deleteTask(scope: TaskDeleteScope) {
        viewModel.deleteTask(scope: scope) { result in
            switch result {
            case .success:
                TaskerFeedback.success()
                dismiss()
            case .failure(let error):
                viewModel.autosaveState = .failed(error.localizedDescription)
            }
        }
    }
}
