//
//  TaskDetailSheetView.swift
//  Tasker
//
//  Action-first task details with Add Task field parity.
//

import SwiftUI

enum TaskDetailContainerMode: Equatable {
    case sheet
    case inspector
}

struct TaskDetailSheetView: View {
    typealias UpdateHandler = (UUID, UpdateTaskDefinitionRequest, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias CompletionHandler = (UUID, Bool, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias DeleteHandler = (UUID, TaskDeleteScope, @escaping (Result<Void, Error>) -> Void) -> Void
    typealias RescheduleHandler = (UUID, Date?, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias MetadataHandler = (UUID, @escaping (Result<TaskDetailMetadataPayload, Error>) -> Void) -> Void
    typealias RelationshipMetadataHandler = (UUID, @escaping (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void) -> Void
    typealias ChildrenHandler = (UUID, @escaping (Result<[TaskDefinition], Error>) -> Void) -> Void
    typealias CreateTaskHandler = (CreateTaskDefinitionRequest, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias CreateTagHandler = (String, @escaping (Result<TagDefinition, Error>) -> Void) -> Void
    typealias CreateProjectHandler = (String, @escaping (Result<Project, Error>) -> Void) -> Void

    /// Initializes a new instance.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.taskerLayoutClass) private var layoutClass
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var liveTodayXPSoFar: Int?

    @State private var showDeleteScopeDialog = false
    @State private var showDescriptionEditor = false
    @State private var newStepTitle = ""
    @State private var showBreakdownSheet = false
    @State private var selectedBreakdownSteps: Set<String> = []

    @FocusState private var titleFocused: Bool
    @FocusState private var stepFocused: Bool
    @FocusState private var descriptionFocused: Bool
    private let isGamificationV2Enabled: Bool
    private let containerMode: TaskDetailContainerMode
    private var readableContentWidth: CGFloat {
        switch containerMode {
        case .sheet:
            return 760
        case .inspector:
            return layoutClass == .padExpanded ? 900 : 780
        }
    }

    init(
        task: TaskDefinition,
        projects: [Project],
        todayXPSoFar: Int? = nil,
        isGamificationV2Enabled: Bool = V2FeatureFlags.gamificationV2Enabled,
        containerMode: TaskDetailContainerMode = .sheet,
        onUpdate: @escaping UpdateHandler,
        onSetCompletion: @escaping CompletionHandler,
        onDelete: @escaping DeleteHandler,
        onReschedule: @escaping RescheduleHandler,
        onLoadMetadata: @escaping MetadataHandler,
        onLoadRelationshipMetadata: @escaping RelationshipMetadataHandler,
        onLoadChildren: @escaping ChildrenHandler,
        onCreateTask: @escaping CreateTaskHandler,
        onCreateTag: @escaping CreateTagHandler,
        onCreateProject: @escaping CreateProjectHandler
    ) {
        self._liveTodayXPSoFar = State(initialValue: todayXPSoFar)
        self.isGamificationV2Enabled = isGamificationV2Enabled
        self.containerMode = containerMode
        _viewModel = StateObject(wrappedValue: TaskDetailViewModel(
            task: task,
            projects: projects,
            onUpdate: onUpdate,
            onSetCompletion: onSetCompletion,
            onDelete: onDelete,
            onReschedule: onReschedule,
            onLoadMetadata: onLoadMetadata,
            onLoadRelationshipMetadata: onLoadRelationshipMetadata,
            onLoadChildren: onLoadChildren,
            onCreateTask: onCreateTask,
            onCreateTag: onCreateTag,
            onCreateProject: onCreateProject
        ))
    }

    var body: some View {
        dialogsAndSheetsBoundView
    }

    private var dialogsAndSheetsBoundView: some View {
        autosaveBoundView
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
            .sheet(isPresented: $showBreakdownSheet) {
                breakdownSheetContent
            }
    }

    private var autosaveBoundView: some View {
        relationshipAutosaveObservedView
            .onChange(of: viewModel.aiBreakdownSteps) { _, updated in
                guard showBreakdownSheet else { return }
                reconcileBreakdownSelection(with: updated)
            }
    }

    private var primaryAutosaveObservedView: some View {
        baseContentView
            .onChange(of: viewModel.taskName) {
                viewModel.scheduleAutosave(debounced: true)
            }
            .onChange(of: viewModel.taskDescription) {
                viewModel.scheduleAutosave(debounced: true)
            }
            .onChange(of: viewModel.selectedPriority) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedType) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedProjectID) {
                viewModel.refreshMetadata()
                viewModel.refreshRelationshipMetadata()
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.dueDate) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.reminderTime) {
                viewModel.scheduleAutosave(debounced: false)
            }
    }

    private var relationshipAutosaveObservedView: some View {
        primaryAutosaveObservedView
            .onChange(of: viewModel.selectedLifeAreaID) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedSectionID) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedTagIDs) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onDisappear {
                viewModel.handleDisappear()
            }
            .onChange(of: viewModel.selectedParentTaskID) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedDependencyTaskIDs) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedDependencyKind) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedEnergy) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedCategory) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedContext) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.estimatedDuration) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.repeatPattern) {
                viewModel.scheduleAutosave(debounced: false)
            }
    }

    private var baseContentView: some View {
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
                notesSection
                    .enhancedStaggeredAppearance(index: 2)
                stepsSection
                    .enhancedStaggeredAppearance(index: 3)
                scheduleSection
                    .enhancedStaggeredAppearance(index: 4)
                organizeSection
                    .enhancedStaggeredAppearance(index: 5)
                executionSection
                    .enhancedStaggeredAppearance(index: 6)
                relationshipsSection
                    .enhancedStaggeredAppearance(index: 7)
                destructiveSection
                metadataFooter
            }
            .taskerReadableContent(maxWidth: readableContentWidth, alignment: .center)
            .padding(.bottom, TaskerTheme.Spacing.xxxl)
        }
        .background(Color.tasker.bgCanvas)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("taskDetail.view")
        .onAppear {
            viewModel.onAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .gamificationLedgerDidMutate)) { notification in
            guard let mutation = notification.gamificationLedgerMutation else { return }
            liveTodayXPSoFar = max(0, mutation.dailyXPSoFar)
        }
    }

    private var breakdownSheetContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let routeBanner = viewModel.aiBreakdownRouteBanner, routeBanner.isEmpty == false {
                    HStack(alignment: .top, spacing: TaskerTheme.Spacing.xs) {
                        Image(systemName: "cpu")
                            .foregroundColor(Color.tasker.accentPrimary)
                        Text(routeBanner)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .padding(.vertical, TaskerTheme.Spacing.sm)
                    .background(Color.tasker.surfaceSecondary)
                }

                if viewModel.isGeneratingAIBreakdown {
                    HStack(spacing: TaskerTheme.Spacing.xs) {
                        ProgressView()
                        Text("Refining step suggestions...")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .padding(.vertical, TaskerTheme.Spacing.xs)
                }

                List {
                    if viewModel.aiBreakdownSteps.isEmpty {
                        Text("No step suggestions available.")
                            .foregroundColor(Color.tasker.textTertiary)
                    } else {
                        ForEach(viewModel.aiBreakdownSteps, id: \.self) { step in
                            Button {
                                if selectedBreakdownSteps.contains(step) {
                                    selectedBreakdownSteps.remove(step)
                                } else {
                                    selectedBreakdownSteps.insert(step)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedBreakdownSteps.contains(step) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedBreakdownSteps.contains(step) ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                                    Text(step)
                                        .foregroundColor(Color.tasker.textPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Breakdown")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBreakdownSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to task") {
                        viewModel.addBreakdownSteps(Array(selectedBreakdownSteps)) {
                            showBreakdownSheet = false
                        }
                    }
                    .disabled(selectedBreakdownSteps.isEmpty)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            if containerMode == .sheet {
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
            } else {
                Color.clear
                    .frame(width: 30, height: 30)
            }

            Spacer()

            Text("Task")
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 30, height: 30)
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
                ScoreBadge(
                    preview: detailXPPreview,
                    reasonHint: XPCalculationEngine.estimateReasonHints(
                        estimatedDuration: viewModel.estimatedDuration,
                        isFocusSessionActive: false,
                        isPinnedInFocusStrip: false
                    )
                )

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

    private var detailXPPreview: XPCompletionPreview? {
        if isGamificationV2Enabled {
            guard let liveTodayXPSoFar else { return nil }
            return XPCalculationEngine.completionXPIfCompletedNow(
                priorityRaw: viewModel.selectedPriority.rawValue,
                estimatedDuration: viewModel.estimatedDuration,
                dueDate: viewModel.dueDate,
                dailyEarnedSoFar: liveTodayXPSoFar,
                isGamificationV2Enabled: true
            )
        }
        return XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: viewModel.selectedPriority.rawValue,
            estimatedDuration: viewModel.estimatedDuration,
            dueDate: viewModel.dueDate,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: false
        )
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
            actionChip(
                icon: viewModel.isComplete ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill",
                title: viewModel.isComplete ? "Reopen" : "Complete",
                tint: viewModel.isComplete ? Color.tasker.statusWarning : Color.tasker.statusSuccess
            ) {
                viewModel.toggleRootCompletion()
            }
            .accessibilityIdentifier("taskDetail.completeButton.action")

            actionChip(icon: "list.bullet", title: "Make smaller", tint: Color.tasker.accentPrimary) {
                stepFocused = true
            }
            .accessibilityHint("Focus add step input")

            if V2FeatureFlags.assistantBreakdownEnabled && viewModel.childSteps.isEmpty {
                actionChip(
                    icon: viewModel.isGeneratingAIBreakdown ? "hourglass" : "sparkles",
                    title: viewModel.isGeneratingAIBreakdown ? "Thinking..." : "Break down",
                    tint: Color.tasker.accentPrimary
                ) {
                    viewModel.generateAIBreakdown {
                        selectedBreakdownSteps = Set(viewModel.aiBreakdownSteps)
                        showBreakdownSheet = true
                    }
                }
                .disabled(viewModel.isGeneratingAIBreakdown)
                .accessibilityHint("Generate AI subtask suggestions")
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .accessibilityIdentifier("taskDetail.actionRow")
    }

    /// Executes reconcileBreakdownSelection.
    private func reconcileBreakdownSelection(with updatedSteps: [String]) {
        let updatedSet = Set(updatedSteps)
        let intersection = selectedBreakdownSteps.intersection(updatedSet)
        if intersection.isEmpty == false {
            selectedBreakdownSteps = intersection
            return
        }

        if selectedBreakdownSteps.isEmpty {
            selectedBreakdownSteps = Set(updatedSteps.prefix(3))
            return
        }

        selectedBreakdownSteps = Set(updatedSteps.prefix(min(selectedBreakdownSteps.count, updatedSteps.count)))
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

    private var scheduleSection: some View {
        sectionCard(.schedule) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                AddTaskDatePresetRow(dueDate: $viewModel.dueDate)

                AddTaskReminderChip(
                    hasReminder: hasReminderBinding,
                    reminderTime: reminderTimeBinding
                )

                AddTaskTypeChips(selectedType: $viewModel.selectedType)

                AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)
                    .accessibilityIdentifier("taskDetail.repeatPicker")

                if viewModel.dueDate != nil {
                    Button("Clear due date") {
                        viewModel.dueDate = nil
                    }
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.statusWarning)
                    .buttonStyle(.plain)
                }

                if viewModel.reminderTime != nil {
                    Button("Clear reminder") {
                        viewModel.reminderTime = nil
                    }
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.statusWarning)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var organizeSection: some View {
        sectionCard(.organize) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                AddTaskProjectBar(
                    selectedProject: selectedProjectNameBinding,
                    projects: viewModel.projects,
                    onCreateProject: { name in
                        viewModel.createProject(name: name) { _ in }
                    }
                )

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

                AddTaskTagMultiSelect(
                    tags: viewModel.tags,
                    selectedTagIDs: $viewModel.selectedTagIDs,
                    onCreateTag: { name, completion in
                        viewModel.createTag(name: name, completion: completion)
                    }
                )
            }
        }
    }

    private var executionSection: some View {
        sectionCard(.execution) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                    .accessibilityIdentifier("taskDetail.priorityControl")

                AddTaskDurationPicker(duration: $viewModel.estimatedDuration)
                    .accessibilityIdentifier("taskDetail.durationPicker")

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
            }
        }
    }

    private var relationshipsSection: some View {
        sectionCard(.relationships) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
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
            }
        }
    }

    private var destructiveSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Text("Danger zone")
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(Color.tasker.statusDanger)

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
            .accessibilityIdentifier("taskDetail.deleteButton")
        }
        .padding(TaskerTheme.Spacing.md)
        .background(Color.tasker.statusDanger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        _ section: TaskEditorSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TaskEditorSectionCard(
            section: section,
            summary: viewModel.summary(for: section),
            isExpanded: viewModel.isSectionExpanded(section)
        ) {
            TaskerFeedback.light()
            viewModel.toggleSection(section)
        } content: {
            content()
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
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

    private var descriptionIsEmpty: Bool {
        viewModel.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var descriptionPreview: String {
        descriptionIsEmpty ? "Add details you'll want later (optional)." : viewModel.taskDescription
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
