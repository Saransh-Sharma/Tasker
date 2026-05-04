//
//  TaskDetailSheetView.swift
//  LifeBoard
//
//  Action-first task details with Add Task field parity.
//

import SwiftUI

enum TaskDetailContainerMode: Equatable {
    case sheet
    case inspector
}

struct TaskDetailSheetView: View {
    typealias UpdateHandler = (UUID, UpdateTaskDefinitionRequest, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias CompletionHandler = (UUID, Bool, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias DeleteHandler = (UUID, TaskDeleteScope, @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) -> Void
    typealias RescheduleHandler = (UUID, Date?, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias MetadataHandler = (UUID, @escaping @MainActor @Sendable (Result<TaskDetailMetadataPayload, Error>) -> Void) -> Void
    typealias RelationshipMetadataHandler = (UUID, @escaping @MainActor @Sendable (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void) -> Void
    typealias ChildrenHandler = (UUID, @escaping @MainActor @Sendable (Result<[TaskDefinition], Error>) -> Void) -> Void
    typealias CreateTaskHandler = (CreateTaskDefinitionRequest, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    typealias CreateTagHandler = (String, @escaping @MainActor @Sendable (Result<TagDefinition, Error>) -> Void) -> Void
    typealias CreateProjectHandler = (String, @escaping @MainActor @Sendable (Result<Project, Error>) -> Void) -> Void
    typealias SaveReflectionNoteHandler = (ReflectionNote, @escaping @MainActor @Sendable (Result<ReflectionNote, Error>) -> Void) -> Void
    typealias TaskFitHintHandler = (TaskDefinition, @escaping @MainActor @Sendable (LifeBoardTaskFitHintResult) -> Void) -> Void

    /// Initializes a new instance.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
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
            .onChange(of: viewModel.scheduledStartAt) {
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
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.lg) {
                topBar
                headerSection
                    .enhancedStaggeredAppearance(index: 0)
                scheduleSection
                    .enhancedStaggeredAppearance(index: 1)
                scheduleEditingSection
                    .enhancedStaggeredAppearance(index: 2)
                notesSection
                    .enhancedStaggeredAppearance(index: 3)
                stepsSection
                    .enhancedStaggeredAppearance(index: 4)
                moreDetailsSection
                    .enhancedStaggeredAppearance(index: 5)
                if viewModel.shouldShowRelationshipsSection {
                    relationshipsSection
                        .enhancedStaggeredAppearance(index: 6)
                }
                if showsContextSection {
                    contextSection
                        .enhancedStaggeredAppearance(index: 7)
                }
                destructiveSection
                metadataFooter
            }
            .lifeboardReadableContent(maxWidth: readableContentWidth, alignment: .center)
            .padding(.bottom, LifeBoardTheme.Spacing.xxxl)
        }
        .background(Color.lifeboard.bgCanvas)
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
                    HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.xs) {
                        EvaMascotView(placement: .taskCapture, size: .chip)
                        Text(routeBanner)
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .padding(.vertical, LifeBoardTheme.Spacing.sm)
                    .background(Color.lifeboard.surfaceSecondary)
                }

                if viewModel.isGeneratingAIBreakdown {
                    HStack(spacing: LifeBoardTheme.Spacing.xs) {
                        EvaMascotView(placement: .chatThinking, size: .chip)
                        Text("Refining step suggestions...")
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .padding(.vertical, LifeBoardTheme.Spacing.xs)
                }

                List {
                    if viewModel.aiBreakdownSteps.isEmpty {
                        Text("No step suggestions available.")
                            .foregroundColor(Color.lifeboard.textTertiary)
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
                                        .foregroundColor(selectedBreakdownSteps.contains(step) ? Color.lifeboard.accentPrimary : Color.lifeboard.textTertiary)
                                    Text(step)
                                        .foregroundColor(Color.lifeboard.textPrimary)
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
                        .foregroundColor(Color.lifeboard.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.lifeboard.surfaceSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskDetail.closeButton")
                .accessibilityLabel("Close task details")
            }

            Spacer()
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
        .padding(.top, LifeBoardTheme.Spacing.sm)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.md) {
                CompletionCheckbox(isComplete: viewModel.isComplete) {
                    viewModel.toggleRootCompletion()
                }
                .accessibilityIdentifier("taskDetail.completeButton")
                .accessibilityHint("Double tap to toggle completion")
                .padding(.top, 6)

                TextField("Task title", text: $viewModel.taskName, axis: .vertical)
                    .font(.lifeboard(.title1))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3...5)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(Color.lifeboard.textPrimary)
                    .focused($titleFocused)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("taskDetail.titleField")
            }

            Text(headerSummaryText)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("taskDetail.projectLabel")

            if viewModel.scheduleExtrasSummary.isEmpty == false {
                Text(viewModel.scheduleExtrasSummary)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.autosaveState != .idle {
                autosaveBanner
            }
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
        .padding(.vertical, LifeBoardTheme.Spacing.md)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
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
            HStack(spacing: LifeBoardTheme.Spacing.xs) {
                Image(systemName: autosaveSymbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(viewModel.autosaveState.label)
                    .font(.lifeboard(.meta).weight(.semibold))
            }
            .foregroundStyle(autosaveColor)
            .padding(.horizontal, LifeBoardTheme.Spacing.sm)
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
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            HStack {
                Text("Notes")
                    .font(.lifeboard(.headline).leading(.tight))
                    .foregroundColor(Color.lifeboard.textPrimary)
                Spacer()
                Button(showDescriptionEditor ? "Done" : "Edit") {
                    showDescriptionEditor.toggle()
                    if showDescriptionEditor {
                        descriptionFocused = true
                    }
                }
                .font(.lifeboard(.caption1).weight(.medium))
                .foregroundColor(Color.lifeboard.accentPrimary)
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
                                .font(.lifeboard(.body))
                                .foregroundStyle(Color.lifeboard.textQuaternary)
                                .italic()
                        } else {
                            Text(descriptionPreview)
                                .font(.lifeboard(.body))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                        }
                    }
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LifeBoardTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                            .fill(Color.lifeboard.surfaceSecondary.opacity(0.68))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskDetail.descriptionField")
            }
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
        .padding(.vertical, LifeBoardTheme.Spacing.md)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
    }

    private var stepsSection: some View {
        detailDisclosureCard(
            title: "Steps",
            systemImage: "list.bullet",
            summary: viewModel.summary(for: .steps),
            section: .steps,
            accessibilityIdentifier: "taskDetail.disclosure.steps"
        ) {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                Text(viewModel.stepCreationHint)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                HStack(spacing: LifeBoardTheme.Spacing.md) {
                    Button("Make smaller") {
                        stepFocused = true
                    }
                    .font(.lifeboard(.callout))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lifeboard.accentPrimary)

                    if V2FeatureFlags.assistantBreakdownEnabled && viewModel.childSteps.isEmpty {
                        Button(viewModel.isGeneratingAIBreakdown ? "Thinking..." : "Break down") {
                            viewModel.generateAIBreakdown {
                                selectedBreakdownSteps = Set(viewModel.aiBreakdownSteps)
                                showBreakdownSheet = true
                            }
                        }
                        .font(.lifeboard(.callout))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .disabled(viewModel.isGeneratingAIBreakdown)
                    }
                }

                ForEach(viewModel.childSteps, id: \.id) { step in
                    HStack(spacing: LifeBoardTheme.Spacing.sm) {
                        CompletionCheckbox(isComplete: step.isComplete, compact: true) {
                            viewModel.toggleStepCompletion(step)
                        }
                        .accessibilityHint("Toggle step completion")

                        Text(step.title)
                            .font(.lifeboard(.callout))
                            .foregroundColor(step.isComplete ? Color.lifeboard.textTertiary : Color.lifeboard.textPrimary)
                            .strikethrough(step.isComplete, color: Color.lifeboard.textTertiary)
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
                                .foregroundColor(Color.lifeboard.textSecondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .padding(.vertical, LifeBoardTheme.Spacing.sm)
                    .lifeboardDenseSurface(
                        cornerRadius: LifeBoardTheme.CornerRadius.md,
                        fillColor: Color.lifeboard.surfaceSecondary.opacity(0.7),
                        strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
                    )
                    .taskCompletionTransition(isComplete: step.isComplete)
                    .accessibilityIdentifier("taskDetail.step.\(step.id.uuidString)")
                }

                HStack(spacing: LifeBoardTheme.Spacing.sm) {
                    TextField("Add a step...", text: $newStepTitle)
                        .font(.lifeboard(.callout))
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
                            .foregroundColor(Color.lifeboard.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add step")
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.md)
                .padding(.vertical, LifeBoardTheme.Spacing.sm)
                .lifeboardDenseSurface(
                    cornerRadius: LifeBoardTheme.CornerRadius.md,
                    fillColor: Color.lifeboard.surfaceSecondary.opacity(0.7),
                    strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
                )
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            Text("Schedule")
                .font(.lifeboard(.headline).leading(.tight))
                .foregroundStyle(Color.lifeboard.textPrimary)

            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                AddTaskDatePresetRow(
                    dueDate: dueDateBinding,
                    customChipAccessibilityIdentifier: "taskDetail.chip.due"
                )

                AddTaskReminderChip(
                    hasReminder: hasReminderBinding,
                    reminderTime: reminderTimeBinding
                )

                if viewModel.dueDate != nil {
                    Button("Clear due date") {
                        viewModel.setDueDate(nil)
                    }
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.statusWarning)
                    .buttonStyle(.plain)
                }

                if viewModel.reminderTime != nil {
                    Button("Clear reminder") {
                        viewModel.reminderTime = nil
                    }
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.statusWarning)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
        .padding(.vertical, LifeBoardTheme.Spacing.md)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
    }

    private var scheduleEditingSection: some View {
        TaskScheduleEditor(
            startDate: scheduledStartBinding,
            durationMinutes: durationMinutesBinding,
            defaultStartDate: viewModel.defaultScheduledStartForEditor()
        )
        .accessibilityIdentifier("taskDetail.scheduleEditor")
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
    }

    private var moreDetailsSection: some View {
        detailDisclosureCard(
            title: "More details",
            systemImage: "slider.horizontal.3",
            summary: viewModel.summary(for: .details),
            section: .details,
            accessibilityIdentifier: "taskDetail.disclosure.details"
        ) {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
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
        return HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.xs) {
            Image(systemName: style.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.tint)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Task fit")
                        .font(.lifeboard(.meta).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    if viewModel.isLoadingTaskFitHint {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                Text(hint.message)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(style.tint)
                    .fixedSize(horizontal: false, vertical: true)

                if let window = taskFitWindowSummary(hint) {
                    Text(window)
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
        .padding(.vertical, LifeBoardTheme.Spacing.xs)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.sm,
            fillColor: style.tint.opacity(0.12),
            strokeColor: style.tint.opacity(0.24)
        )
        .accessibilityIdentifier("taskDetail.taskFitHint")
    }

    private func taskFitStyle(for classification: LifeBoardTaskFitClassification) -> (symbol: String, tint: Color) {
        switch classification {
        case .fit:
            return ("checkmark.circle.fill", Color.lifeboard.statusSuccess)
        case .tight:
            return ("exclamationmark.triangle.fill", Color.lifeboard.statusWarning)
        case .conflict:
            return ("xmark.octagon.fill", Color.lifeboard.statusDanger)
        case .unknown:
            return ("questionmark.circle.fill", Color.lifeboard.textSecondary)
        }
    }

    private func taskFitWindowSummary(_ hint: LifeBoardTaskFitHintResult) -> String? {
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
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
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
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
                if let preview = detailXPPreview {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reward")
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                        Text("Complete now for \(preview.shortLabel).")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                    }
                    .padding(LifeBoardTheme.Spacing.md)
                    .lifeboardDenseSurface(
                        cornerRadius: LifeBoardTheme.CornerRadius.md,
                        fillColor: Color.lifeboard.accentWash.opacity(0.72),
                        strokeColor: Color.lifeboard.accentPrimary.opacity(0.14)
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
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            Text("Danger zone")
                .font(.lifeboard(.meta).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textTertiary)

            Button(role: .destructive) {
                promptDeleteTask()
            } label: {
                Text("Delete Task")
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard.statusDanger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LifeBoardTheme.Spacing.sm)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("taskDetail.deleteButton")
        }
        .padding(LifeBoardTheme.Spacing.md)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
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
            LifeBoardFeedback.light()
            viewModel.toggleSection(section)
        } content: {
            content()
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
    }

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
            Text("Added \(DateUtils.formatDateTime(viewModel.persistedTask.dateAdded))")
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textTertiary)

            if viewModel.isComplete, let completedAt = viewModel.persistedTask.dateCompleted {
                Text("Completed \(DateUtils.formatDateTime(completedAt))")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)
            }
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.screenHorizontal)
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

    private var dueDateBinding: Binding<Date?> {
        Binding(
            get: { viewModel.dueDate },
            set: { viewModel.setDueDate($0) }
        )
    }

    private var scheduledStartBinding: Binding<Date?> {
        Binding(
            get: { viewModel.scheduledStartAt },
            set: { viewModel.setScheduledStartDate($0) }
        )
    }

    private var durationMinutesBinding: Binding<Int> {
        Binding(
            get: { viewModel.durationMinutes },
            set: { viewModel.setDurationMinutes($0) }
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
            return Color.lifeboard.textTertiary
        case .saved:
            return Color.lifeboard.statusSuccess
        case .failed:
            return Color.lifeboard.statusDanger
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
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            WeeklyPlanningPlacementSection(
                selectedPlanningBucket: $viewModel.selectedPlanningBucket,
                selectedWeeklyOutcomeID: $viewModel.selectedWeeklyOutcomeID,
                availableWeeklyOutcomes: viewModel.weeklyOutcomes
            )
            .accessibilityIdentifier("taskDetail.weeklyBucketPicker")
        }
    }

    private var recentReflectionsCard: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            HStack {
                Text("Recent reflection")
                    .font(.lifeboard(.meta))
                    .foregroundColor(Color.lifeboard.textTertiary)
                Spacer()
                Button(viewModel.isComplete ? "Capture completion note" : "Capture note") {
                    showingReflectionComposer = true
                }
                .font(.lifeboard(.callout))
                .buttonStyle(.plain)
                .foregroundStyle(Color.lifeboard.accentPrimary)
            }

            if viewModel.recentReflectionNotes.isEmpty {
                Text("Recent task and project reflections appear here once you capture them.")
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                    ForEach(viewModel.recentReflectionNotes.prefix(3), id: \.id) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            if let prompt = note.prompt, prompt.isEmpty == false {
                                Text(prompt)
                                    .font(.lifeboard(.meta))
                                    .foregroundColor(Color.lifeboard.textTertiary)
                            }
                            Text(note.noteText)
                                .font(.lifeboard(.callout))
                                .foregroundColor(Color.lifeboard.textPrimary)
                            Text(DateUtils.formatDateTime(note.createdAt))
                                .font(.lifeboard(.caption1))
                                .foregroundColor(Color.lifeboard.textQuaternary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(LifeBoardTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                                .fill(Color.lifeboard.surfaceSecondary)
                        )
                    }
                }
            }
        }
    }

    private func projectMotivationCard(_ motivation: ProjectWeeklyMotivation) -> some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            Text("Project motivation")
                .font(.lifeboard(.meta))
                .foregroundColor(Color.lifeboard.textTertiary)

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
        .padding(LifeBoardTheme.Spacing.sm)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: Color.lifeboard.accentPrimary.opacity(0.08),
            strokeColor: Color.lifeboard.accentPrimary.opacity(0.12)
        )
    }

    private func motivationRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.lifeboard(.meta))
                .foregroundColor(Color.lifeboard.textTertiary)
            Text(value)
                .font(.lifeboard(.callout))
                .foregroundColor(Color.lifeboard.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var autosaveFillColor: Color {
        switch viewModel.autosaveState {
        case .idle:
            return .clear
        case .saving:
            return Color.lifeboard.surfaceSecondary
        case .saved:
            return Color.lifeboard.statusSuccess.opacity(0.12)
        case .failed:
            return Color.lifeboard.statusDanger.opacity(0.12)
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
        LifeBoardFeedback.warning()
        if viewModel.persistedTask.recurrenceSeriesID != nil {
            showDeleteScopeDialog = true
            return
        }
        deleteTask(scope: .single)
    }

    /// Executes deleteTask.
    private func deleteTask(scope: TaskDeleteScope) {
        viewModel.deleteTask(scope: scope) { result in
            Task { @MainActor in
                switch result {
                case .success:
                    LifeBoardFeedback.success()
                    dismiss()
                case .failure(let error):
                    viewModel.autosaveState = .failed(error.localizedDescription)
                }
            }
        }
    }
}
