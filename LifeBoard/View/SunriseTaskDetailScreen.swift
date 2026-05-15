//
//  SunriseTaskDetailScreen.swift
//  LifeBoard
//
//  Sunrise Glass task detail screen with action-first progressive disclosure.
//

import SwiftUI

private enum SunriseTaskDetailSection: String, Hashable, CaseIterable {
    case plan
    case notes
    case steps
    case organize
    case links
    case context
    case delete
}

struct SunriseTaskDetailScreen: View {
    typealias UpdateHandler = TaskDetailUpdateHandler
    typealias CompletionHandler = TaskDetailCompletionHandler
    typealias DeleteHandler = TaskDetailDeleteHandler
    typealias RescheduleHandler = TaskDetailRescheduleHandler
    typealias MetadataHandler = TaskDetailMetadataHandler
    typealias RelationshipMetadataHandler = TaskDetailRelationshipMetadataHandler
    typealias ChildrenHandler = TaskDetailChildrenHandler
    typealias CreateTaskHandler = TaskDetailCreateTaskHandler
    typealias CreateTagHandler = TaskDetailCreateTagHandler
    typealias CreateProjectHandler = TaskDetailCreateProjectHandler
    typealias SaveReflectionNoteHandler = TaskDetailSaveReflectionNoteHandler
    typealias TaskFitHintHandler = TaskDetailFitHintHandler

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var liveTodayXPSoFar: Int?
    @State private var expandedSections: Set<SunriseTaskDetailSection>
    @State private var showDeleteScopeDialog = false
    @State private var showBreakdownSheet = false
    @State private var selectedBreakdownSteps: Set<String> = []
    @State private var showingReflectionComposer = false
    @State private var newStepTitle = ""

    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool
    @FocusState private var stepFocused: Bool

    private let isGamificationV2Enabled: Bool
    private let containerMode: TaskDetailContainerMode
    private let onSaveReflectionNote: SaveReflectionNoteHandler

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var readableContentWidth: CGFloat { containerMode == .inspector && layoutClass == .padExpanded ? 900 : 760 }

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
                domain: "SunriseTaskDetailScreen",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "Reflection notes are unavailable in this context."]
            )))
        },
        onLoadTaskFitHint: @escaping TaskFitHintHandler = { _, completion in completion(.unknown) }
    ) {
        self._liveTodayXPSoFar = State(initialValue: todayXPSoFar)
        self._expandedSections = State(initialValue: Self.defaultExpandedSections(for: task))
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
        autosaveObservedScreen
    }

    private var baseScreen: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                headerChrome
                heroCard
                primaryActionCluster
                planDisclosure
                notesDisclosure
                stepsDisclosure
                organizeDisclosure
                if showsLinksDisclosure {
                    linksDisclosure
                }
                if showsContextDisclosure {
                    contextDisclosure
                }
                deleteDisclosure
                metadataFooter
            }
            .lifeboardReadableContent(maxWidth: readableContentWidth, alignment: .center)
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)
            .padding(.bottom, spacing.s32)
        }
        .background(sunriseBackground)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("taskDetail.view")
    }

    private var sheetBoundScreen: some View {
        baseScreen
        .confirmationDialog("Delete recurring task?", isPresented: $showDeleteScopeDialog, titleVisibility: .visible) {
            Button("Delete This Task", role: .destructive) { deleteTask(scope: .single) }
            Button("Delete Entire Series", role: .destructive) { deleteTask(scope: .series) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to remove only this task or every task in the series.")
        }
        .sheet(isPresented: $showBreakdownSheet) {
            breakdownSheet
        }
        .sheet(isPresented: $showingReflectionComposer) {
            reflectionComposerSheet
        }
    }

    private var lifecycleObservedScreen: some View {
        sheetBoundScreen
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.handleDisappear)
        .onChange(of: viewModel.aiBreakdownSteps) { _, steps in
            guard showBreakdownSheet else { return }
            selectedBreakdownSteps = selectedBreakdownSteps.intersection(Set(steps))
            if selectedBreakdownSteps.isEmpty {
                selectedBreakdownSteps = Set(steps.prefix(3))
            }
        }
    }

    private var autosaveObservedScreen: some View {
        planningAutosaveObservedScreen
    }

    private var primaryAutosaveObservedScreen: some View {
        lifecycleObservedScreen
        .onChange(of: viewModel.taskName) { viewModel.scheduleAutosave(debounced: true) }
        .onChange(of: viewModel.taskDescription) { viewModel.scheduleAutosave(debounced: true) }
        .onChange(of: viewModel.selectedPriority) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedType) { viewModel.scheduleAutosave(debounced: false) }
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
        .onChange(of: viewModel.reminderTime) { viewModel.scheduleAutosave(debounced: false) }
    }

    private var relationshipAutosaveObservedScreen: some View {
        primaryAutosaveObservedScreen
        .onChange(of: viewModel.selectedLifeAreaID) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedSectionID) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedTagIDs) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedParentTaskID) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedDependencyTaskIDs) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedDependencyKind) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedEnergy) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedCategory) { viewModel.scheduleAutosave(debounced: false) }
        .onChange(of: viewModel.selectedContext) { viewModel.scheduleAutosave(debounced: false) }
    }

    private var planningAutosaveObservedScreen: some View {
        relationshipAutosaveObservedScreen
        .onChange(of: viewModel.estimatedDuration) {
            viewModel.refreshTaskFitHint()
            viewModel.scheduleAutosave(debounced: false)
        }
        .onChange(of: viewModel.repeatPattern) { viewModel.scheduleAutosave(debounced: false) }
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

    private var headerChrome: some View {
        HStack {
            if containerMode == .sheet {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .frame(width: 44, height: 44)
                .lifeboardChromeSurface(cornerRadius: LifeBoardTheme.CornerRadius.pill, accentColor: Color.lifeboard.accentSecondary)
                .accessibilityIdentifier("taskDetail.closeButton")
                .accessibilityLabel("Close task details")
            }

            Spacer()

            if viewModel.autosaveState != .idle {
                autosavePill
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HStack(alignment: .top, spacing: spacing.s12) {
                CompletionCheckbox(isComplete: viewModel.isComplete) {
                    viewModel.toggleRootCompletion()
                }
                .accessibilityIdentifier("taskDetail.completeButton")
                .accessibilityHint("Double tap to toggle completion")
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    TextField("Task title", text: $viewModel.taskName, axis: .vertical)
                        .font(.lifeboard(.title1))
                        .bold()
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(2...4)
                        .focused($titleFocused)
                        .textFieldStyle(.plain)
                        .accessibilityIdentifier("taskDetail.titleField")

                    Text(headerSummaryText)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("taskDetail.projectLabel")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing.s8) { heroMetrics }
                VStack(spacing: spacing.s8) { heroMetrics }
            }
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: taskAccentColor,
            level: .e2
        )
    }

    @ViewBuilder
    private var heroMetrics: some View {
        LifeBoardHeroMetricTile(title: "Schedule", value: scheduleSummary, detail: scheduleDetail, tone: .accent)
        LifeBoardHeroMetricTile(title: "Status", value: statusText, detail: viewModel.selectedPriority.displayName, tone: viewModel.isComplete ? .success : .neutral)
    }

    private var primaryActionCluster: some View {
        HStack(spacing: spacing.s8) {
            Button(viewModel.isComplete ? "Reopen" : "Complete", systemImage: viewModel.isComplete ? "arrow.uturn.left.circle.fill" : "checkmark.circle.fill") {
                viewModel.toggleRootCompletion()
            }
            .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: viewModel.isComplete ? .quiet : .success))

            Button("Adjust time", systemImage: "clock.badge.checkmark") {
                expand(.plan)
            }
            .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .accent))

            Button("Add step", systemImage: "plus.circle.fill") {
                expand(.steps)
                stepFocused = true
            }
            .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .quiet))
        }
        .lifeboardChromeSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, accentColor: Color.lifeboard.accentPrimary)
    }

    private var planDisclosure: some View {
        disclosureCard(.plan, title: "Plan", systemImage: "calendar.badge.clock", summary: planSummary, accessibilityIdentifier: nil) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                TaskScheduleEditor(
                    startDate: scheduledStartBinding,
                    durationMinutes: durationMinutesBinding,
                    defaultStartDate: viewModel.defaultScheduledStartForEditor()
                )
                .accessibilityIdentifier("taskDetail.scheduleEditor")

                AddTaskDatePresetRow(dueDate: dueDateBinding, customChipAccessibilityIdentifier: "taskDetail.chip.due")
                AddTaskReminderChip(hasReminder: hasReminderBinding, reminderTime: reminderTimeBinding)

                HStack(spacing: spacing.s8) {
                    if viewModel.dueDate != nil {
                        Button("Clear due date") { viewModel.setDueDate(nil) }
                            .buttonStyle(SunriseTextButtonStyle(tone: .warning))
                    }
                    if viewModel.reminderTime != nil {
                        Button("Clear reminder") { viewModel.reminderTime = nil }
                            .buttonStyle(SunriseTextButtonStyle(tone: .warning))
                    }
                }

                taskFitHintRow
            }
        }
    }

    private var notesDisclosure: some View {
        disclosureCard(.notes, title: "Notes", systemImage: "note.text", summary: notesSummary, accessibilityIdentifier: nil) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                AddTaskDescriptionField(text: $viewModel.taskDescription, isFocused: $notesFocused)
                    .accessibilityIdentifier("taskDetail.descriptionField")

                Button(viewModel.isComplete ? "Capture completion note" : "Capture reflection", systemImage: "sparkles") {
                    showingReflectionComposer = true
                }
                .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .accent))
            }
        }
    }

    private var stepsDisclosure: some View {
        disclosureCard(.steps, title: "Steps", systemImage: "list.bullet", summary: viewModel.stepsSummary, accessibilityIdentifier: "taskDetail.disclosure.steps") {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(viewModel.stepCreationHint)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                HStack(spacing: spacing.s8) {
                    if V2FeatureFlags.assistantBreakdownEnabled && viewModel.childSteps.isEmpty {
                        Button(viewModel.isGeneratingAIBreakdown ? "Thinking..." : "Break down", systemImage: "sparkles") {
                            viewModel.generateAIBreakdown {
                                selectedBreakdownSteps = Set(viewModel.aiBreakdownSteps)
                                showBreakdownSheet = true
                            }
                        }
                        .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .accent))
                        .disabled(viewModel.isGeneratingAIBreakdown)
                    }
                }

                ForEach(viewModel.childSteps, id: \.id) { step in
                    HStack(spacing: spacing.s8) {
                        CompletionCheckbox(isComplete: step.isComplete, compact: true) {
                            viewModel.toggleStepCompletion(step)
                        }
                        .accessibilityHint("Toggle step completion")

                        Text(step.title)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(step.isComplete ? Color.lifeboard.textTertiary : Color.lifeboard.textPrimary)
                            .strikethrough(step.isComplete, color: Color.lifeboard.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Menu("Step actions", systemImage: "ellipsis") {
                            Button("Move up") { viewModel.moveStepUp(step) }
                            Button("Move down") { viewModel.moveStepDown(step) }
                            Button("Delete", role: .destructive) { viewModel.deleteStep(step) }
                        }
                        .labelStyle(.iconOnly)
                    }
                    .padding(spacing.s12)
                    .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.72))
                    .accessibilityIdentifier("taskDetail.step.\(step.id.uuidString)")
                }

                HStack(spacing: spacing.s8) {
                    TextField("Add a step...", text: $newStepTitle)
                        .font(.lifeboard(.callout))
                        .focused($stepFocused)
                        .textFieldStyle(.plain)
                        .onSubmit(addStep)
                        .accessibilityIdentifier("taskDetail.stepInput")

                    Button("Add step", systemImage: "plus.circle.fill", action: addStep)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .disabled(newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Add step")
                }
                .padding(spacing.s12)
                .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.72))
            }
        }
    }

    private var organizeDisclosure: some View {
        disclosureCard(.organize, title: "Organize", systemImage: "square.grid.2x2", summary: viewModel.detailsSummary, accessibilityIdentifier: "taskDetail.disclosure.details") {
            VStack(alignment: .leading, spacing: spacing.s12) {
                AddTaskProjectBar(selectedProject: selectedProjectNameBinding, projects: viewModel.projects) { name in
                    viewModel.createProject(name: name) { _ in }
                }
                .accessibilityIdentifier("taskDetail.projectLabel")

                if !viewModel.lifeAreas.isEmpty {
                    AddTaskEntityPicker(
                        label: "Life Area",
                        items: viewModel.lifeAreas.map { AddTaskEntityPickerItem(id: $0.id, name: $0.name, icon: $0.icon, accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.color, for: $0.id)) },
                        selectedID: $viewModel.selectedLifeAreaID
                    )
                    .accessibilityIdentifier("taskDetail.lifeAreaPicker")
                }

                if !viewModel.sections.isEmpty {
                    AddTaskEntityPicker(
                        label: "Section",
                        items: viewModel.sections.map { AddTaskEntityPickerItem(id: $0.id, name: $0.name, icon: nil, accentHex: nil) },
                        selectedID: $viewModel.selectedSectionID
                    )
                    .accessibilityIdentifier("taskDetail.sectionPicker")
                }

                AddTaskTagMultiSelect(tags: viewModel.tags, selectedTagIDs: $viewModel.selectedTagIDs) { name, completion in
                    viewModel.createTag(name: name, completion: completion)
                }

                AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                    .accessibilityIdentifier("taskDetail.priorityControl")
                AddTaskTypeChips(selectedType: $viewModel.selectedType)
                AddTaskEnumChipRow(label: "Energy", displayName: { $0.displayName }, icon: { $0.emoji.isEmpty ? "bolt" : $0.emoji }, selected: $viewModel.selectedEnergy)
                    .accessibilityIdentifier("taskDetail.energyPicker")
                AddTaskEnumChipRow(label: "Category", displayName: { $0.displayName }, icon: { $0.emoji.isEmpty ? "tag" : $0.emoji }, selected: $viewModel.selectedCategory)
                    .accessibilityIdentifier("taskDetail.categoryPicker")
                AddTaskEnumChipRow(label: "Context", displayName: { $0.displayName }, icon: { $0.emoji.isEmpty ? "mappin" : $0.emoji }, selected: $viewModel.selectedContext)
                    .accessibilityIdentifier("taskDetail.contextPicker")
                AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)
                    .accessibilityIdentifier("taskDetail.repeatPicker")
                WeeklyPlanningPlacementSection(
                    selectedPlanningBucket: $viewModel.selectedPlanningBucket,
                    selectedWeeklyOutcomeID: $viewModel.selectedWeeklyOutcomeID,
                    availableWeeklyOutcomes: viewModel.weeklyOutcomes
                )
                .accessibilityIdentifier("taskDetail.weeklyBucketPicker")

                if !showsLinksDisclosure {
                    linksFields
                }
            }
        }
    }

    private var linksDisclosure: some View {
        disclosureCard(.links, title: "Links", systemImage: "link", summary: viewModel.relationshipsSummary, accessibilityIdentifier: "taskDetail.disclosure.relationships") {
            linksFields
        }
    }

    private var linksFields: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            if !viewModel.availableParentTasks.isEmpty {
                AddTaskTaskPicker(label: "Parent Task", tasks: viewModel.availableParentTasks, selectedTaskID: $viewModel.selectedParentTaskID)
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
            if viewModel.availableParentTasks.isEmpty && viewModel.availableDependencyTasks.isEmpty {
                Text("Related tasks will appear here when this project has other tasks to link.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }
        }
    }

    private var contextDisclosure: some View {
        disclosureCard(.context, title: "Context", systemImage: "text.bubble", summary: contextSummary, accessibilityIdentifier: "taskDetail.disclosure.context") {
            VStack(alignment: .leading, spacing: spacing.s12) {
                if let preview = detailXPPreview {
                    LifeBoardHeroMetricTile(title: "Reward", value: preview.shortLabel, detail: "Complete now", tone: .accent)
                }
                if !viewModel.recentReflectionNotes.isEmpty {
                    ForEach(viewModel.recentReflectionNotes.prefix(3), id: \.id) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            if let prompt = note.prompt, prompt.isEmpty == false {
                                Text(prompt)
                                    .font(.lifeboard(.meta))
                                    .foregroundStyle(Color.lifeboard.textTertiary)
                            }
                            Text(note.noteText)
                                .font(.lifeboard(.callout))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                        }
                        .padding(spacing.s12)
                        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.72))
                    }
                }
                if let motivation = viewModel.projectMotivation, !motivation.isEmpty {
                    projectMotivationCard(motivation)
                }
            }
        }
    }

    private var deleteDisclosure: some View {
        disclosureCard(.delete, title: "Delete", systemImage: "trash", summary: "Destructive actions stay separate.", accessibilityIdentifier: nil) {
            Button(role: .destructive) {
                promptDeleteTask()
            } label: {
                Text("Delete Task")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.statusDanger)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("taskDetail.deleteButton")
        }
    }

    private func disclosureCard<Content: View>(
        _ section: SunriseTaskDetailSection,
        title: String,
        systemImage: String,
        summary: String,
        accessibilityIdentifier: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SunriseDetailDisclosureCard(
            title: title,
            systemImage: systemImage,
            summary: summary,
            isExpanded: expandedSections.contains(section),
            accessibilityIdentifier: accessibilityIdentifier
        ) {
            LifeBoardFeedback.light()
            withAnimation(LifeBoardAnimation.snappy) {
                toggle(section)
            }
        } content: {
            content()
        }
    }

    private var taskFitHintRow: some View {
        let style = taskFitStyle(for: viewModel.taskFitHint.classification)
        return HStack(alignment: .top, spacing: spacing.s8) {
            Image(systemName: style.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style.tint)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Task fit")
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    if viewModel.isLoadingTaskFitHint {
                        ProgressView().controlSize(.mini)
                    }
                }
                Text(viewModel.taskFitHint.message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(style.tint)
                if let window = taskFitWindowSummary {
                    Text(window)
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(spacing.s12)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: style.tint.opacity(0.12), strokeColor: style.tint.opacity(0.24))
        .accessibilityIdentifier("taskDetail.taskFitHint")
    }

    private var breakdownSheet: some View {
        NavigationStack {
            List {
                if viewModel.aiBreakdownRouteBanner != nil || viewModel.aiBreakdownSteps.isEmpty {
                    Text(viewModel.aiBreakdownRouteBanner ?? "Thinking through smaller steps...")
                }
                ForEach(viewModel.aiBreakdownSteps, id: \.self) { step in
                    Button {
                        if selectedBreakdownSteps.contains(step) {
                            selectedBreakdownSteps.remove(step)
                        } else {
                            selectedBreakdownSteps.insert(step)
                        }
                    } label: {
                        Label(step, systemImage: selectedBreakdownSteps.contains(step) ? "checkmark.circle.fill" : "circle")
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

    private var autosavePill: some View {
        LifeBoardStatusPill(text: viewModel.autosaveState.label, systemImage: autosaveSymbol, tone: autosaveTone)
            .accessibilityLabel(viewModel.autosaveState.label)
    }

    private var reflectionComposerSheet: some View {
        SunriseReflectionNoteComposerView(
            viewModel: SunriseReflectionNoteComposerViewModel(
                title: "Task Reflection",
                kind: viewModel.isComplete ? .taskCompletion : .freeform,
                linkedTaskID: viewModel.persistedTask.id,
                linkedProjectID: viewModel.selectedProjectID,
                prompt: viewModel.isComplete ? "What helped this task finish cleanly?" : "What is changing about this task right now?",
                saveNoteHandler: onSaveReflectionNote
            )
        ) { _ in
            viewModel.refreshRelationshipMetadata()
        }
    }

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text("Added \(DateUtils.formatDateTime(viewModel.persistedTask.dateAdded))")
            if viewModel.isComplete, let completedAt = viewModel.persistedTask.dateCompleted {
                Text("Completed \(DateUtils.formatDateTime(completedAt))")
            }
        }
        .font(.lifeboard(.caption1))
        .foregroundStyle(Color.lifeboard.textTertiary)
    }

    private func projectMotivationCard(_ motivation: ProjectWeeklyMotivation) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Project motivation")
                .font(.lifeboard(.callout).weight(.semibold))
            if let why = motivation.why, why.isEmpty == false {
                motivationRow("Why now", why)
            }
            if let success = motivation.successLooksLike, success.isEmpty == false {
                motivationRow("Success looks like", success)
            }
            if let cost = motivation.costOfNeglect, cost.isEmpty == false {
                motivationRow("If ignored", cost)
            }
        }
        .padding(spacing.s12)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.accentWash.opacity(0.72))
    }

    private func motivationRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textTertiary)
            Text(value)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textPrimary)
        }
    }

    private var sunriseBackground: some View {
        LinearGradient(
            colors: [
                Color(lifeboardHex: "#FFF8EF"),
                Color(lifeboardHex: "#FFFDFC"),
                Color(lifeboardHex: "#F7FBFF")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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

    private var hasReminderBinding: Binding<Bool> {
        Binding(
            get: { viewModel.reminderTime != nil },
            set: { hasReminder in
                viewModel.reminderTime = hasReminder ? (viewModel.reminderTime ?? Date()) : nil
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(get: { viewModel.reminderTime ?? Date() }, set: { viewModel.reminderTime = $0 })
    }

    private var dueDateBinding: Binding<Date?> {
        Binding(get: { viewModel.dueDate }, set: { viewModel.setDueDate($0) })
    }

    private var scheduledStartBinding: Binding<Date?> {
        Binding(get: { viewModel.scheduledStartAt }, set: { viewModel.setScheduledStartDate($0) })
    }

    private var durationMinutesBinding: Binding<Int> {
        Binding(get: { viewModel.durationMinutes }, set: { viewModel.setDurationMinutes($0) })
    }

    private var selectedProjectNameBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedProjectName },
            set: { name in
                guard let projectID = viewModel.projects.first(where: { $0.name == name })?.id else { return }
                viewModel.selectedProjectID = projectID
            }
        )
    }

    private var statusText: String {
        if viewModel.isComplete { return "Completed" }
        if let dueDate = viewModel.dueDate { return "Due \(DateUtils.formatDate(dueDate))" }
        return "Open"
    }

    private var headerSummaryText: String {
        viewModel.headerSummary.isEmpty ? statusText : viewModel.headerSummary
    }

    private var scheduleSummary: String {
        guard let start = viewModel.scheduledStartAt else {
            return viewModel.dueDate.map { "Due \(DateUtils.formatDate($0))" } ?? "Unscheduled"
        }
        if let end = Calendar.current.date(byAdding: .minute, value: viewModel.durationMinutes, to: start), viewModel.durationMinutes > 0 {
            return TaskDetailViewModel.scheduleRangeLabel(start: start, end: end)
        }
        return DateUtils.formatDateTime(start)
    }

    private var scheduleDetail: String {
        viewModel.scheduleExtrasSummary.isEmpty ? "Adjust when useful" : viewModel.scheduleExtrasSummary
    }

    private var planSummary: String {
        [scheduleSummary, viewModel.reminderTime == nil ? nil : "Reminder"].compactMap { $0 }.joined(separator: " · ")
    }

    private var notesSummary: String {
        let trimmed = viewModel.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Add context only when it helps." : "Notes added"
    }

    private var contextSummary: String {
        var parts: [String] = []
        if detailXPPreview != nil { parts.append("Reward preview") }
        if viewModel.contextSummary != "Extra context is hidden" { parts.append(viewModel.contextSummary) }
        return parts.isEmpty ? "Reflections and project context." : parts.joined(separator: " · ")
    }

    private var showsLinksDisclosure: Bool {
        viewModel.shouldShowRelationshipsSection || expandedSections.contains(.links)
    }

    private var showsContextDisclosure: Bool {
        detailXPPreview != nil || viewModel.shouldShowContextSection || expandedSections.contains(.context)
    }

    private var taskAccentColor: Color {
        viewModel.isComplete ? Color.lifeboard.statusSuccess : Color(lifeboardHex: "#28B53F")
    }

    private var autosaveSymbol: String {
        switch viewModel.autosaveState {
        case .idle: return "circle"
        case .saving: return "arrow.triangle.2.circlepath"
        case .saved: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var autosaveTone: LifeBoardStatusPillTone {
        switch viewModel.autosaveState {
        case .idle, .saving: return .quiet
        case .saved: return .success
        case .failed: return .danger
        }
    }

    private var taskFitWindowSummary: String? {
        guard let start = viewModel.taskFitHint.freeWindowStart, let end = viewModel.taskFitHint.freeWindowEnd else { return nil }
        return "Largest window: \(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    private func taskFitStyle(for classification: LifeBoardTaskFitClassification) -> (symbol: String, tint: Color) {
        switch classification {
        case .fit: return ("checkmark.circle.fill", Color.lifeboard.statusSuccess)
        case .tight: return ("exclamationmark.triangle.fill", Color.lifeboard.statusWarning)
        case .conflict: return ("xmark.octagon.fill", Color.lifeboard.statusDanger)
        case .unknown: return ("questionmark.circle.fill", Color.lifeboard.textSecondary)
        }
    }

    private func expand(_ section: SunriseTaskDetailSection) {
        withAnimation(LifeBoardAnimation.snappy) {
            _ = expandedSections.insert(section)
        }
    }

    private func toggle(_ section: SunriseTaskDetailSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func addStep() {
        let title = newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }
        viewModel.createStep(title: title) { success in
            guard success else { return }
            newStepTitle = ""
            stepFocused = true
        }
    }

    private func promptDeleteTask() {
        LifeBoardFeedback.warning()
        if viewModel.persistedTask.recurrenceSeriesID != nil {
            showDeleteScopeDialog = true
        } else {
            deleteTask(scope: .single)
        }
    }

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

    private static func defaultExpandedSections(for task: TaskDefinition) -> Set<SunriseTaskDetailSection> {
        var sections: Set<SunriseTaskDetailSection> = []
        if task.subtasks.isEmpty == false { sections.insert(.steps) }
        if task.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false { sections.insert(.notes) }
        return sections
    }
}
