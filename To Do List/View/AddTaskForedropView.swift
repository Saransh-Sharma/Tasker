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
    @State private var isTaskIconPickerPresented = false
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
                    HStack(alignment: .center, spacing: spacing.s12) {
                        EvaMascotView(placement: .taskCapture, size: .inline)
                        VStack(alignment: .leading, spacing: spacing.s4) {
                            Text("Capture it with \(AssistantIdentityText.currentSnapshot().displayName)")
                                .font(.tasker(.headline))
                                .foregroundStyle(Color.tasker.textPrimary)
                            Text("Start with the task; details can come after.")
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(spacing.s12)
                    .background(Color.tasker.surfaceSecondary.opacity(0.72), in: RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $viewModel.taskName,
                        isFocused: $titleFieldFocused,
                        iconSystemName: V2FeatureFlags.autoTaskIconsEnabled ? viewModel.displayedTaskIconSymbolName : nil,
                        iconAccessibilityLabel: V2FeatureFlags.autoTaskIconsEnabled ? viewModel.displayedTaskIconLabel : nil,
                        onIconTap: V2FeatureFlags.autoTaskIconsEnabled ? { isTaskIconPickerPresented = true } : nil,
                        placeholder: "What do you want to do?",
                        helperText: "Keep it short. You can clarify later.",
                        onSubmit: submitTask
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    AddTaskScheduleQuickEditor(viewModel: viewModel)
                        .enhancedStaggeredAppearance(index: 2)

                    baseComposerSections
                        .enhancedStaggeredAppearance(index: 3)

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
        .background {
            ZStack(alignment: .topLeading) {
                Color.tasker.surfacePrimary
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Add Task")
                    .accessibilityIdentifier("addTask.view")
            }
        }
        .sheet(isPresented: $isTaskIconPickerPresented) {
            AddTaskIconPickerSheet(
                viewModel: viewModel,
                isPresented: $isTaskIconPickerPresented
            )
        }
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
            ownershipSection

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
                options: viewModel.lifeAreas.map {
                    TaskerComposerOption(
                        id: $0.id,
                        title: $0.name,
                        icon: $0.icon,
                        accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.color, for: $0.id)
                    )
                },
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
                options: viewModel.filteredProjectsForSelectedLifeArea.map {
                    TaskerComposerOption(id: $0.id, title: $0.name, icon: nil, accentHex: nil)
                },
                selectedID: viewModel.selectedProjectID == ProjectConstants.inboxProjectID ? nil : viewModel.selectedProjectID,
                noneOptionTitle: "Inbox",
                emptyStateText: viewModel.filteredProjectsForSelectedLifeArea.isEmpty ? "No projects in this area." : nil,
                accessibilityIdentifier: "addTask.projectSelector"
            ) { selectedProjectID in
                withAnimation(TaskerAnimation.snappy) {
                    viewModel.selectProject(id: selectedProjectID)
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

                    if viewModel.scheduledStartAt != nil {
                        Button("Clear schedule") {
                            viewModel.clearSchedule()
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

                    WeeklyPlanningPlacementSection(
                        selectedPlanningBucket: $viewModel.selectedPlanningBucket,
                        selectedWeeklyOutcomeID: $viewModel.selectedWeeklyOutcomeID,
                        availableWeeklyOutcomes: viewModel.availableWeeklyOutcomes
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

// MARK: - Schedule Quick Editor

private enum AddTaskScheduleAccessibilityID {
    static let editor = "addTask.scheduleEditor"
    static let dateToday = "addTask.schedule.date.today"
    static let dateTomorrow = "addTask.schedule.date.tomorrow"
    static let dateCustom = "addTask.schedule.date.custom"
    static let dateSomeday = "addTask.schedule.date.someday"
    static let timeRow = "addTask.schedule.timeRow"
    static let timePickerSheet = "addTask.schedule.timePickerSheet"
    static let timePicker = "addTask.schedule.timePicker"
    static let timePickerConfirm = "addTask.schedule.timePickerConfirm"
    static let datePickerSheet = "addTask.schedule.datePickerSheet"
    static let datePicker = "addTask.schedule.datePicker"
    static let datePickerConfirm = "addTask.schedule.datePickerConfirm"
    static let customDurationField = "addTask.schedule.customDurationField"

    static func durationChip(_ minutes: Int) -> String {
        "addTask.schedule.duration.\(minutes)"
    }
}

struct AddTaskScheduleQuickEditor: View {
    @ObservedObject var viewModel: AddTaskViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showCustomDuration = false
    @State private var customDurationMinutes = ""

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private let durationPresets: [(label: String, seconds: TimeInterval, minutes: Int)] = [
        ("15m", 15 * 60, 15),
        ("30m", 30 * 60, 30),
        ("1h", 60 * 60, 60),
        ("1h 30m", 90 * 60, 90),
        ("2h", 2 * 60 * 60, 120),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s8) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                Text("Schedule")
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textSecondary)
                Spacer(minLength: 0)
            }

            datePresetRow
            timeRow
            durationRow

            if showCustomDuration {
                customDurationRow
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: corner.r3)
                .fill(Color.tasker.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r3)
                        .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                )
        )
        .accessibilityIdentifier(AddTaskScheduleAccessibilityID.editor)
        .sheet(isPresented: $showDatePicker) {
            let todayStart = Calendar.current.startOfDay(for: Date())
            let initialDate = max(viewModel.scheduledStartAt ?? Date(), todayStart)
            AddTaskScheduleDatePickerSheet(
                initialDate: initialDate,
                onSet: { date in
                    viewModel.setScheduledDate(date)
                }
            )
        }
        .sheet(isPresented: $showTimePicker) {
            AddTaskScheduleTimePickerSheet(
                initialTime: viewModel.scheduledStartAt ?? AddTaskViewModel.defaultScheduledStart(),
                onSet: { time in
                    viewModel.setScheduledStartTime(time)
                }
            )
        }
        .animation(TaskerAnimation.snappy, value: showCustomDuration)
    }

    private var datePresetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.chipSpacing) {
                AddTaskMetadataChip(
                    icon: "sun.horizon",
                    text: "Today",
                    isActive: isScheduledToday
                ) {
                    if let today = DatePreset.today.resolvedDueDate() {
                        viewModel.setScheduledDate(today)
                    }
                }
                .accessibilityIdentifier(AddTaskScheduleAccessibilityID.dateToday)

                AddTaskMetadataChip(
                    icon: "sunrise",
                    text: "Tomorrow",
                    isActive: isScheduledTomorrow
                ) {
                    if let tomorrow = DatePreset.tomorrow.resolvedDueDate() {
                        viewModel.setScheduledDate(tomorrow)
                    }
                }
                .accessibilityIdentifier(AddTaskScheduleAccessibilityID.dateTomorrow)

                AddTaskMetadataChip(
                    icon: "calendar.badge.plus",
                    text: customDateText,
                    isActive: isCustomDateSelected
                ) {
                    if viewModel.scheduledStartAt == nil {
                        viewModel.restoreDefaultSchedule()
                    }
                    showDatePicker = true
                }
                .accessibilityIdentifier(AddTaskScheduleAccessibilityID.dateCustom)

                AddTaskMetadataChip(
                    icon: "tray",
                    text: "Someday",
                    isActive: viewModel.scheduledStartAt == nil
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        viewModel.clearSchedule()
                    }
                }
                .accessibilityIdentifier(AddTaskScheduleAccessibilityID.dateSomeday)
            }
        }
    }

    private var timeRow: some View {
        Button {
            if viewModel.scheduledStartAt == nil {
                viewModel.restoreDefaultSchedule()
            }
            showTimePicker = true
        } label: {
            HStack(spacing: spacing.s12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.tasker.accentWash))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textTertiary)
                    Text(timeRangeText)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }

                Spacer(minLength: spacing.s8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.tasker.textQuaternary)
            }
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: corner.r2)
                    .fill(Color.tasker.surfacePrimary)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityIdentifier(AddTaskScheduleAccessibilityID.timeRow)
    }

    private var durationRow: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Duration")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    ForEach(durationPresets, id: \.minutes) { preset in
                        AddTaskMetadataChip(
                            icon: "timer",
                            text: preset.label,
                            isActive: durationMatches(preset.seconds)
                        ) {
                            withAnimation(TaskerAnimation.snappy) {
                                viewModel.setEstimatedDuration(preset.seconds)
                                showCustomDuration = false
                            }
                        }
                        .accessibilityIdentifier(AddTaskScheduleAccessibilityID.durationChip(preset.minutes))
                    }

                    AddTaskMetadataChip(
                        icon: "pencil",
                        text: customDurationChipText,
                        isActive: showCustomDuration || isCustomDurationSelected
                    ) {
                        customDurationMinutes = currentDurationMinutesText
                        withAnimation(TaskerAnimation.snappy) {
                            showCustomDuration.toggle()
                        }
                    }
                }
            }
        }
    }

    private var customDurationRow: some View {
        HStack(spacing: spacing.s8) {
            TextField("Minutes", text: $customDurationMinutes)
                .font(.tasker(.callout))
                .keyboardType(.numberPad)
                .foregroundStyle(Color.tasker.textPrimary)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .fill(Color.tasker.surfacePrimary)
                )
                .frame(width: 112)
                .accessibilityIdentifier(AddTaskScheduleAccessibilityID.customDurationField)

            Text("minutes")
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textTertiary)

            Spacer(minLength: 0)

            Button("Set") {
                guard let minutes = Int(customDurationMinutes), minutes > 0 else { return }
                viewModel.setEstimatedDuration(TimeInterval(minutes) * 60)
                showCustomDuration = false
            }
            .font(.tasker(.callout).weight(.semibold))
            .foregroundStyle(Color.tasker.accentPrimary)
            .buttonStyle(.plain)
        }
    }

    private var isScheduledToday: Bool {
        guard let scheduledStartAt = viewModel.scheduledStartAt else { return false }
        return Calendar.current.isDateInToday(scheduledStartAt)
    }

    private var isScheduledTomorrow: Bool {
        guard let scheduledStartAt = viewModel.scheduledStartAt else { return false }
        return Calendar.current.isDateInTomorrow(scheduledStartAt)
    }

    private var isCustomDateSelected: Bool {
        guard viewModel.scheduledStartAt != nil else { return false }
        return isScheduledToday == false && isScheduledTomorrow == false
    }

    private var customDateText: String {
        guard isCustomDateSelected, let scheduledStartAt = viewModel.scheduledStartAt else {
            return "Pick date"
        }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: scheduledStartAt)
    }

    private var timeRangeText: String {
        guard let scheduledStartAt = viewModel.scheduledStartAt else {
            return "No start time"
        }
        return AddTaskViewModel.scheduleRangeLabel(start: scheduledStartAt, end: viewModel.scheduledEndAt)
    }

    private var customDurationChipText: String {
        guard isCustomDurationSelected, let duration = viewModel.estimatedDuration else {
            return "Custom"
        }
        return durationLabel(for: duration)
    }

    private var currentDurationMinutesText: String {
        guard let duration = viewModel.estimatedDuration else { return "" }
        return "\(max(1, Int((duration / 60).rounded())))"
    }

    private var isCustomDurationSelected: Bool {
        guard let duration = viewModel.estimatedDuration else { return false }
        return durationPresets.contains(where: { abs($0.seconds - duration) < 1 }) == false
    }

    private func durationMatches(_ duration: TimeInterval) -> Bool {
        guard let selected = viewModel.estimatedDuration else { return false }
        return abs(selected - duration) < 1
    }

    private func durationLabel(for duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }
}

private struct AddTaskScheduleDatePickerSheet: View {
    let onSet: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    init(initialDate: Date, onSet: @escaping (Date) -> Void) {
        _selectedDate = State(initialValue: initialDate)
        self.onSet = onSet
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: spacing.s20) {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, spacing.s16)
                .accessibilityIdentifier(AddTaskScheduleAccessibilityID.datePicker)

                Spacer(minLength: 0)
            }
            .accessibilityIdentifier(AddTaskScheduleAccessibilityID.datePickerSheet)
            .navigationTitle("Pick Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Date") {
                        onSet(selectedDate)
                        TaskerFeedback.success()
                        dismiss()
                    }
                    .accessibilityIdentifier(AddTaskScheduleAccessibilityID.datePickerConfirm)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct AddTaskScheduleTimePickerSheet: View {
    let onSet: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    init(initialTime: Date, onSet: @escaping (Date) -> Void) {
        _selectedTime = State(initialValue: initialTime)
        self.onSet = onSet
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: spacing.s16) {
                DatePicker(
                    "Start Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, spacing.s16)
                .accessibilityIdentifier(AddTaskScheduleAccessibilityID.timePicker)

                Spacer(minLength: 0)
            }
            .accessibilityIdentifier(AddTaskScheduleAccessibilityID.timePickerSheet)
            .navigationTitle("Start Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Time") {
                        onSet(selectedTime)
                        TaskerFeedback.success()
                        dismiss()
                    }
                    .accessibilityIdentifier(AddTaskScheduleAccessibilityID.timePickerConfirm)
                }
            }
        }
        .presentationDetents([.height(320), .medium])
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
    let accentHex: String?
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
                        accentHex: nil,
                        isSelected: selectedID == nil
                    ) {
                        onSelect(nil)
                    }
                }

                ForEach(options) { option in
                    optionButton(
                        title: option.title,
                        icon: option.icon,
                        accentHex: option.accentHex,
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
        accentHex: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let hasAccent = TaskerHexColor.normalized(accentHex) != nil
        let accentColor = TaskerHexColor.color(accentHex, fallback: Color.tasker.accentPrimary)
        return Button {
            TaskerFeedback.selection()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                if let icon, icon.isEmpty == false {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                                ? (hasAccent ? accentColor : Color.tasker.accentPrimary)
                                : (hasAccent ? accentColor.opacity(0.86) : Color.tasker.textTertiary)
                        )
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
                        .foregroundStyle(hasAccent ? accentColor : Color.tasker.accentPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(
                        isSelected
                            ? (hasAccent ? accentColor.opacity(0.18) : Color.tasker.accentWash)
                            : (hasAccent ? accentColor.opacity(0.08) : Color.tasker.surfaceSecondary)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(
                        isSelected
                            ? (hasAccent ? accentColor.opacity(0.52) : Color.tasker.accentRing)
                            : (hasAccent ? accentColor.opacity(0.24) : Color.tasker.strokeHairline),
                        lineWidth: isSelected ? 1.5 : 1
                    )
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

private struct AddTaskIconPickerSheet: View {
    @ObservedObject var viewModel: AddTaskViewModel
    @Binding var isPresented: Bool

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    currentSelectionCard
                    searchField
                    LazyVGrid(columns: columns, spacing: spacing.s12) {
                        ForEach(viewModel.availableTaskIconOptions) { option in
                            AddTaskIconOptionButton(
                                option: option,
                                isSelected: viewModel.displayedTaskIconSymbolName == option.symbolName
                            ) {
                                TaskerFeedback.selection()
                                viewModel.applyManualTaskIconSelection(symbolName: option.symbolName)
                                isPresented = false
                            }
                        }
                    }
                }
                .padding(spacing.s16)
            }
            .background(Color.tasker.surfacePrimary)
            .navigationTitle("Task Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .accessibilityIdentifier("addTask.iconPickerSheet")
    }

    private var currentSelectionCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s12) {
                Image(systemName: viewModel.displayedTaskIconSymbolName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.tasker.accentWash)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(viewModel.displayedTaskIconLabel)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text(viewModel.taskIconSelectionSource == .manual ? "Manual override" : "Live suggestion")
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)
            }

            let shouldShowResetAction = viewModel.taskIconSelectionSource == .manual
            if shouldShowResetAction {
                let autoSuggested = viewModel.autoSuggestedTaskIconSymbolName
                let title = {
                    guard let autoSuggested else { return "Reset to Auto" }
                    return autoSuggested == viewModel.displayedTaskIconSymbolName ? "Reset to Auto" : "Use Suggested Icon"
                }()
                let systemImage = autoSuggested ?? "wand.and.stars"
                Button(title, systemImage: systemImage) {
                    TaskerFeedback.selection()
                    viewModel.resetTaskIconToAuto()
                }
                .accessibilityIdentifier("addTask.iconResetButton")
            }
        }
        .padding(spacing.s16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
        )
    }

    private var searchField: some View {
        TextField("Search SF Symbols", text: $viewModel.taskIconSearchQuery)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .font(.tasker(.body))
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.tasker.strokeHairline, lineWidth: 1)
            )
            .accessibilityIdentifier("addTask.iconSearchField")
    }
}

private struct AddTaskIconOptionButton: View {
    let option: TaskIconOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: option.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.tasker.accentPrimary : Color.tasker.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfacePrimary)
                    )
                    .accessibilityHidden(true)

                Text(option.displayName)
                    .font(.tasker(.meta))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.tasker.accentRing : Color.tasker.strokeHairline, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addTask.iconOption.\(option.symbolName)")
        .accessibilityLabel(option.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
