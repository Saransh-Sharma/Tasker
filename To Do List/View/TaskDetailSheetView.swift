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
    typealias SaveReflectionNoteHandler = (ReflectionNote, @escaping (Result<ReflectionNote, Error>) -> Void) -> Void
    typealias TaskFitHintHandler = (TaskDefinition, @escaping (TaskerTaskFitHintResult) -> Void) -> Void

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
    @State private var showingReflectionComposer = false

    @FocusState private var titleFocused: Bool
    @FocusState private var stepFocused: Bool
    @FocusState private var descriptionFocused: Bool
    private let isGamificationV2Enabled: Bool
    private let containerMode: TaskDetailContainerMode
    private let onSaveReflectionNote: SaveReflectionNoteHandler
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
        onCreateProject: @escaping CreateProjectHandler,
        onSaveReflectionNote: @escaping SaveReflectionNoteHandler = { _, completion in
            completion(.failure(NSError(
                domain: "TaskDetailSheetView",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "Reflection notes are unavailable in this context."]
            )))
        },
        onLoadTaskFitHint: @escaping TaskFitHintHandler = { _, completion in
            completion(.unknown)
        }
    ) {
        self._liveTodayXPSoFar = State(initialValue: todayXPSoFar)
        self.isGamificationV2Enabled = isGamificationV2Enabled
        self.containerMode = containerMode
        self.onSaveReflectionNote = onSaveReflectionNote
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
            onCreateProject: onCreateProject,
            onLoadTaskFitHint: onLoadTaskFitHint
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
            .sheet(isPresented: $showingReflectionComposer) {
                reflectionComposerSheet
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
                viewModel.refreshProjectScopedMetadata()
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.dueDate) {
                viewModel.refreshTaskFitHint()
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
                viewModel.refreshTaskFitHint()
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.repeatPattern) {
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedPlanningBucket) {
                if viewModel.selectedPlanningBucket != .thisWeek && viewModel.selectedWeeklyOutcomeID != nil {
                    viewModel.selectedWeeklyOutcomeID = nil
                }
                viewModel.scheduleAutosave(debounced: false)
            }
            .onChange(of: viewModel.selectedWeeklyOutcomeID) { _, newValue in
                if newValue != nil && viewModel.selectedPlanningBucket != .thisWeek {
                    viewModel.selectedPlanningBucket = .thisWeek
                }
                viewModel.scheduleAutosave(debounced: false)
            }
    }

    private var baseContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
                topBar
                headerSection
                    .enhancedStaggeredAppearance(index: 0)
                scheduleSection
                    .enhancedStaggeredAppearance(index: 1)
                notesSection
                    .enhancedStaggeredAppearance(index: 2)
                stepsSection
                    .enhancedStaggeredAppearance(index: 3)
                moreDetailsSection
                    .enhancedStaggeredAppearance(index: 4)
                if viewModel.shouldShowRelationshipsSection {
                    relationshipsSection
                        .enhancedStaggeredAppearance(index: 5)
                }
                if showsContextSection {
                    contextSection
                        .enhancedStaggeredAppearance(index: 6)
                }
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
            viewModel.ensureChildrenLoaded()
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
            }

            Spacer()
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
                .padding(.top, 6)

                TextField("Task title", text: $viewModel.taskName, axis: .vertical)
                    .font(.tasker(.title1))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3...5)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(Color.tasker.textPrimary)
                    .focused($titleFocused)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("taskDetail.titleField")
            }

            Text(headerSummaryText)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("taskDetail.projectLabel")

            if viewModel.scheduleExtrasSummary.isEmpty == false {
                Text(viewModel.scheduleExtrasSummary)
                    .font(.tasker(.meta))
                    .foregroundStyle(Color.tasker.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.autosaveState != .idle {
                autosaveBanner
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.vertical, TaskerTheme.Spacing.md)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.72)
        )
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
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Image(systemName: autosaveSymbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(viewModel.autosaveState.label)
                    .font(.tasker(.meta).weight(.semibold))
            }
            .foregroundStyle(autosaveColor)
            .padding(.horizontal, TaskerTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(autosaveFillColor)
            .overlay(
                Capsule()
                    .stroke(autosaveColor.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
            .accessibilityLabel(viewModel.autosaveState.label)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack {
                Text("Notes")
                    .font(.tasker(.headline).leading(.tight))
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
                Button {
                    showDescriptionEditor = true
                    descriptionFocused = true
                } label: {
                    Group {
                        if descriptionIsEmpty {
                            Text(descriptionPreview)
                                .font(.tasker(.body))
                                .foregroundStyle(Color.tasker.textQuaternary)
                                .italic()
                        } else {
                            Text(descriptionPreview)
                                .font(.tasker(.body))
                                .foregroundStyle(Color.tasker.textSecondary)
                        }
                    }
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(TaskerTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                            .fill(Color.tasker.surfaceSecondary.opacity(0.68))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskDetail.descriptionField")
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.vertical, TaskerTheme.Spacing.md)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var stepsSection: some View {
        detailDisclosureCard(
            title: "Steps",
            systemImage: "list.bullet",
            summary: viewModel.summary(for: .steps),
            section: .steps,
            accessibilityIdentifier: "taskDetail.disclosure.steps"
        ) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                Text(viewModel.stepCreationHint)
                    .font(.tasker(.meta))
                    .foregroundStyle(Color.tasker.textSecondary)

                HStack(spacing: TaskerTheme.Spacing.md) {
                    Button("Make smaller") {
                        stepFocused = true
                    }
                    .font(.tasker(.callout))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.tasker.accentPrimary)

                    if V2FeatureFlags.assistantBreakdownEnabled && viewModel.childSteps.isEmpty {
                        Button(viewModel.isGeneratingAIBreakdown ? "Thinking..." : "Break down") {
                            viewModel.generateAIBreakdown {
                                selectedBreakdownSteps = Set(viewModel.aiBreakdownSteps)
                                showBreakdownSheet = true
                            }
                        }
                        .font(.tasker(.callout))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.tasker.accentPrimary)
                        .disabled(viewModel.isGeneratingAIBreakdown)
                    }
                }

                ForEach(viewModel.childSteps, id: \.id) { step in
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
                    .taskerDenseSurface(
                        cornerRadius: TaskerTheme.CornerRadius.md,
                        fillColor: Color.tasker.surfaceSecondary.opacity(0.7),
                        strokeColor: Color.tasker.strokeHairline.opacity(0.72)
                    )
                    .taskCompletionTransition(isComplete: step.isComplete)
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
                .taskerDenseSurface(
                    cornerRadius: TaskerTheme.CornerRadius.md,
                    fillColor: Color.tasker.surfaceSecondary.opacity(0.7),
                    strokeColor: Color.tasker.strokeHairline.opacity(0.72)
                )
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Text("Schedule")
                .font(.tasker(.headline).leading(.tight))
                .foregroundStyle(Color.tasker.textPrimary)

            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                AddTaskDatePresetRow(
                    dueDate: $viewModel.dueDate,
                    customChipAccessibilityIdentifier: "taskDetail.chip.due"
                )

                AddTaskReminderChip(
                    hasReminder: hasReminderBinding,
                    reminderTime: reminderTimeBinding
                )

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
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.vertical, TaskerTheme.Spacing.md)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var moreDetailsSection: some View {
        detailDisclosureCard(
            title: "More details",
            systemImage: "slider.horizontal.3",
            summary: viewModel.summary(for: .details),
            section: .details,
            accessibilityIdentifier: "taskDetail.disclosure.details"
        ) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                AddTaskProjectBar(
                    selectedProject: selectedProjectNameBinding,
                    projects: viewModel.projects,
                    onCreateProject: { name in
                        viewModel.createProject(name: name) { _ in }
                    }
                )
                .accessibilityIdentifier("taskDetail.projectLabel")

                if !viewModel.lifeAreas.isEmpty {
                    AddTaskEntityPicker(
                        label: "Life Area",
                        items: viewModel.lifeAreas.map {
                            AddTaskEntityPickerItem(
                                id: $0.id,
                                name: $0.name,
                                icon: $0.icon,
                                accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.color, for: $0.id)
                            )
                        },
                        selectedID: $viewModel.selectedLifeAreaID
                    )
                    .accessibilityIdentifier("taskDetail.lifeAreaPicker")
                }

                if !viewModel.sections.isEmpty {
                    AddTaskEntityPicker(
                        label: "Section",
                        items: viewModel.sections.map {
                            AddTaskEntityPickerItem(
                                id: $0.id,
                                name: $0.name,
                                icon: nil,
                                accentHex: nil
                            )
                        },
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

                AddTaskTypeChips(selectedType: $viewModel.selectedType)

                AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)
                    .accessibilityIdentifier("taskDetail.repeatPicker")

                AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                    .accessibilityIdentifier("taskDetail.priorityControl")

                AddTaskDurationPicker(duration: $viewModel.estimatedDuration)
                    .accessibilityIdentifier("taskDetail.durationPicker")

                taskFitHintRow

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

                if viewModel.shouldShowRelationshipsSection == false {
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

                planningSection
            }
        }
    }

    private var taskFitHintRow: some View {
        let hint = viewModel.taskFitHint
        let style = taskFitStyle(for: hint.classification)
        return HStack(alignment: .top, spacing: TaskerTheme.Spacing.xs) {
            Image(systemName: style.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.tint)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Task fit")
                        .font(.tasker(.meta).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                    if viewModel.isLoadingTaskFitHint {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                Text(hint.message)
                    .font(.tasker(.caption1))
                    .foregroundStyle(style.tint)
                    .fixedSize(horizontal: false, vertical: true)

                if let window = taskFitWindowSummary(hint) {
                    Text(window)
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, TaskerTheme.Spacing.sm)
        .padding(.vertical, TaskerTheme.Spacing.xs)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.sm,
            fillColor: style.tint.opacity(0.12),
            strokeColor: style.tint.opacity(0.24)
        )
        .accessibilityIdentifier("taskDetail.taskFitHint")
    }

    private func taskFitStyle(for classification: TaskerTaskFitClassification) -> (symbol: String, tint: Color) {
        switch classification {
        case .fit:
            return ("checkmark.circle.fill", Color.tasker.statusSuccess)
        case .tight:
            return ("exclamationmark.triangle.fill", Color.tasker.statusWarning)
        case .conflict:
            return ("xmark.octagon.fill", Color.tasker.statusDanger)
        case .unknown:
            return ("questionmark.circle.fill", Color.tasker.textSecondary)
        }
    }

    private func taskFitWindowSummary(_ hint: TaskerTaskFitHintResult) -> String? {
        guard let start = hint.freeWindowStart, let end = hint.freeWindowEnd else { return nil }
        let startText = start.formatted(date: .omitted, time: .shortened)
        let endText = end.formatted(date: .omitted, time: .shortened)
        return "Largest window: \(startText) - \(endText)"
    }

    private var relationshipsSection: some View {
        detailDisclosureCard(
            title: "Relationships",
            systemImage: "link",
            summary: viewModel.summary(for: .relationships),
            section: .relationships,
            accessibilityIdentifier: "taskDetail.disclosure.relationships"
        ) {
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

    private var contextSection: some View {
        detailDisclosureCard(
            title: "More context",
            systemImage: "text.bubble",
            summary: contextSummaryText,
            section: .context,
            accessibilityIdentifier: "taskDetail.disclosure.context"
        ) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                if let preview = detailXPPreview {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reward")
                            .font(.tasker(.meta))
                            .foregroundStyle(Color.tasker.textTertiary)
                        Text("Complete now for \(preview.shortLabel).")
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker.textPrimary)
                    }
                    .padding(TaskerTheme.Spacing.md)
                    .taskerDenseSurface(
                        cornerRadius: TaskerTheme.CornerRadius.md,
                        fillColor: Color.tasker.accentWash.opacity(0.72),
                        strokeColor: Color.tasker.accentPrimary.opacity(0.14)
                    )
                }

                if viewModel.recentReflectionNotes.isEmpty == false {
                    recentReflectionsCard
                }

                if let motivation = viewModel.projectMotivation, !motivation.isEmpty {
                    projectMotivationCard(motivation)
                }
            }
        }
    }

    private var destructiveSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Text("Danger zone")
                .font(.tasker(.meta).weight(.semibold))
                .foregroundStyle(Color.tasker.textTertiary)

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
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.md,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    @ViewBuilder
    private func detailDisclosureCard<Content: View>(
        title: String,
        systemImage: String,
        summary: String,
        section: TaskDetailDisclosureSection,
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TaskEditorSectionCard(
            title: title,
            systemImage: systemImage,
            summary: summary,
            isExpanded: viewModel.isSectionExpanded(section),
            accessibilityIdentifier: accessibilityIdentifier
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
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            if viewModel.isComplete, let completedAt = viewModel.persistedTask.dateCompleted {
                Text("Completed \(DateUtils.formatDateTime(completedAt))")
                    .font(.tasker(.caption1))
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

    private var reflectionComposerSheet: some View {
        ReflectionNoteComposerView(
            viewModel: ReflectionNoteComposerViewModel(
                title: "Task Reflection",
                kind: viewModel.isComplete ? .taskCompletion : .freeform,
                linkedTaskID: viewModel.persistedTask.id,
                linkedProjectID: viewModel.selectedProjectID,
                prompt: viewModel.isComplete
                    ? "What helped this task finish cleanly?"
                    : "What is changing about this task right now?",
                saveNoteHandler: onSaveReflectionNote
            )
        ) { _ in
            viewModel.refreshRelationshipMetadata()
        }
    }

    private var planningSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            WeeklyPlanningPlacementSection(
                selectedPlanningBucket: $viewModel.selectedPlanningBucket,
                selectedWeeklyOutcomeID: $viewModel.selectedWeeklyOutcomeID,
                availableWeeklyOutcomes: viewModel.weeklyOutcomes
            )
            .accessibilityIdentifier("taskDetail.weeklyBucketPicker")
        }
    }

    private var recentReflectionsCard: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack {
                Text("Recent reflection")
                    .font(.tasker(.meta))
                    .foregroundColor(Color.tasker.textTertiary)
                Spacer()
                Button(viewModel.isComplete ? "Capture completion note" : "Capture note") {
                    showingReflectionComposer = true
                }
                .font(.tasker(.callout))
                .buttonStyle(.plain)
                .foregroundStyle(Color.tasker.accentPrimary)
            }

            if viewModel.recentReflectionNotes.isEmpty {
                Text("Recent task and project reflections appear here once you capture them.")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    ForEach(viewModel.recentReflectionNotes.prefix(3), id: \.id) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            if let prompt = note.prompt, prompt.isEmpty == false {
                                Text(prompt)
                                    .font(.tasker(.meta))
                                    .foregroundColor(Color.tasker.textTertiary)
                            }
                            Text(note.noteText)
                                .font(.tasker(.callout))
                                .foregroundColor(Color.tasker.textPrimary)
                            Text(DateUtils.formatDateTime(note.createdAt))
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textQuaternary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(TaskerTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                                .fill(Color.tasker.surfaceSecondary)
                        )
                    }
                }
            }
        }
    }

    private func projectMotivationCard(_ motivation: ProjectWeeklyMotivation) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Text("Project motivation")
                .font(.tasker(.meta))
                .foregroundColor(Color.tasker.textTertiary)

            if let why = motivation.why, why.isEmpty == false {
                motivationRow(title: "Why now", value: why)
            }
            if let successLooksLike = motivation.successLooksLike, successLooksLike.isEmpty == false {
                motivationRow(title: "Success looks like", value: successLooksLike)
            }
            if let costOfNeglect = motivation.costOfNeglect, costOfNeglect.isEmpty == false {
                motivationRow(title: "If ignored", value: costOfNeglect)
            }
        }
        .padding(TaskerTheme.Spacing.sm)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.md,
            fillColor: Color.tasker.accentPrimary.opacity(0.08),
            strokeColor: Color.tasker.accentPrimary.opacity(0.12)
        )
    }

    private func motivationRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.tasker(.meta))
                .foregroundColor(Color.tasker.textTertiary)
            Text(value)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var autosaveFillColor: Color {
        switch viewModel.autosaveState {
        case .idle:
            return .clear
        case .saving:
            return Color.tasker.surfaceSecondary
        case .saved:
            return Color.tasker.statusSuccess.opacity(0.12)
        case .failed:
            return Color.tasker.statusDanger.opacity(0.12)
        }
    }

    private var autosaveSymbol: String {
        switch viewModel.autosaveState {
        case .idle:
            return "circle.fill"
        case .saving:
            return "arrow.triangle.2.circlepath"
        case .saved:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var descriptionIsEmpty: Bool {
        viewModel.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var descriptionPreview: String {
        descriptionIsEmpty ? "Add details you'll want later (optional)." : viewModel.taskDescription
    }

    private var headerSummaryText: String {
        viewModel.headerSummary.isEmpty ? statusText : viewModel.headerSummary
    }

    private var contextSummaryText: String {
        var parts: [String] = []
        if detailXPPreview != nil {
            parts.append("Reward preview")
        }
        let modelSummary = viewModel.summary(for: .context)
        if modelSummary.isEmpty == false && modelSummary != "Extra context is hidden" {
            parts.append(modelSummary)
        }
        return parts.isEmpty ? "Extra context is hidden" : parts.joined(separator: " · ")
    }

    private var showsContextSection: Bool {
        detailXPPreview != nil || viewModel.shouldShowContextSection
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
