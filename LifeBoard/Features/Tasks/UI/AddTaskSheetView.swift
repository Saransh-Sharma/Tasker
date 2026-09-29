//
//  AddTaskSheetView.swift
//  LifeBoard
//

import SwiftUI

public struct AddTaskSheetView: View {
    @StateObject private var viewModel: AddTaskViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private let onTaskCreated: ((UUID) -> Void)?
    private let onDismissWithoutTask: (() -> Void)?

    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showDiscardConfirmation = false
    @State private var showAddAnother = false
    @State private var successFlash = false
    @State private var didCreateTask = false
    @State private var pendingBehavior: TaskSubmissionBehavior?
    @State private var successResetTask: Task<Void, Never>?
    @State private var showTimeEditor = false
    @State private var showDetails = false
    @State private var didAutoFocusTitleField = false
    @State private var previewPop = false
    @State private var previewPopTask: Task<Void, Never>?

    private var spacing: SemanticSpacingTokens { tokens.spacing }
    private var canCreate: Bool {
        viewModel.viewState.canSubmit && !viewModel.isLoading
    }
    private var isPreviewAwaiting: Bool {
        viewModel.taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func triggerPreviewPop() {
        guard !reduceMotion else { return }
        previewPopTask?.cancel()
        withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) { previewPop = true }
        previewPopTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard Task.isCancelled == false else { return }
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) { previewPop = false }
        }
    }

    public init(
        viewModel: AddTaskViewModel,
        onTaskCreated: ((UUID) -> Void)? = nil,
        onDismissWithoutTask: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onTaskCreated = onTaskCreated
        self.onDismissWithoutTask = onDismissWithoutTask
    }

    public var body: some View {
        VStack(spacing: 0) {
            // One primary action: "Add task" at the bottom. The bar's own
            // "Done" duplicated it; ⌘Return now lives on the bottom button.
            AddTaskNavigationBar(
                containerMode: .sheet,
                title: "New task",
                canSave: canCreate,
                showsSave: false,
                onCancel: handleCancel,
                onSave: handleCreate
            )
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    TaskTimelinePreview(
                        title: viewModel.taskName,
                        scheduledStartAt: viewModel.scheduledStartAt,
                        scheduledEndAt: viewModel.scheduledEndAt,
                        dueDate: viewModel.plannedDate,
                        duration: viewModel.estimatedDuration,
                        lifeArea: selectedLifeArea,
                        isAwaiting: isPreviewAwaiting,
                        action: { showTimeEditor = true }
                    )
                    .scaleEffect(previewPop && !reduceMotion ? 1.03 : 1.0)
                    .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: previewPop)
                    .cardEntrance(index: 0)

                    AddTaskTitleField(
                        text: $viewModel.taskName,
                        isFocused: $titleFieldFocused,
                        placeholder: "Task name",
                        onSubmit: handleCreate
                    )
                    .cardEntrance(index: 1)

                    // What the title will become, before it is saved: "Call mom
                    // tomorrow 3pm #family" files a dated, tagged task.
                    if let parsed = viewModel.typedTitleParse {
                        AddTaskUnderstoodLine(parsed: parsed)
                            .transition(.opacity)
                    }

                    TaskEssentials(
                        viewModel: viewModel,
                        scheduledStartAt: viewModel.scheduledStartAt,
                        scheduledEndAt: viewModel.scheduledEndAt,
                        dueDate: viewModel.plannedDate,
                        duration: $viewModel.estimatedDuration,
                        selectedLifeArea: selectedLifeArea,
                        onEditTime: { showTimeEditor = true }
                    )
                    .cardEntrance(index: 2)

                    CalmInlineReveal(
                        title: "Refine",
                        collapsedHint: detailsSummary,
                        isExpanded: $showDetails,
                        accessibilityID: "addTask.detailsDisclosure",
                        onToggle: toggleDetails
                    ) {
                        AddTaskDetails(
                            viewModel: viewModel,
                            descriptionFocused: $descriptionFieldFocused,
                            onExpand: expandSheet
                        )
                    }
                    .cardEntrance(index: 3)

                    if let validationText {
                        AddTaskErrorView(message: validationText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s20)
            }

            AddTaskCreateButton(
                isEnabled: canCreate,
                isLoading: viewModel.isLoading,
                successFlash: successFlash,
                showAddAnother: showAddAnother,
                buttonTitle: "Add task",
                submitsWithCommandReturn: true,
                onCreateAction: handleCreate,
                onAddAnotherAction: handleAddAnother
            )
            .accessibilityIdentifier("addTask.createButton")
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 720 : .infinity, alignment: .center)
        .background(AddTaskBackground().ignoresSafeArea())
        // `.contain` makes the sheet's root a real accessibility container, so
        // "addTask.view" is reachable (a bare stack never is) and its children
        // keep their own identifiers instead of inheriting this one.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addTask.view")
        // On the root so it is an ancestor of every field: the Mac's
        // accessibility cancel and VoiceOver's scrub reach Cancel from anywhere.
        .accessibilityAction(.escape, handleCancel)
        // Esc with the title field focused: same path as Cancel, so unsaved
        // changes still ask first.
        .escapeCancels(perform: handleCancel)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.modal)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .sheet(isPresented: $showTimeEditor) {
            TaskTimeEditorSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your changes will be lost.")
        }
        .overlay(
            Color.lifeboard(.statusSuccess)
                .opacity(successFlash ? 0.06 : 0)
                .animation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion), value: successFlash)
                .allowsHitTesting(false)
        )
        .onAppear(perform: handleAppear)
        .onDisappear {
            successResetTask?.cancel()
            previewPopTask?.cancel()
            if didCreateTask == false {
                onDismissWithoutTask?()
            }
        }
        .onChange(of: viewModel.lastCreatedTaskID) { _, taskID in
            guard let taskID, let pendingBehavior else { return }
            handleCreatedTask(taskID, behavior: pendingBehavior)
        }
        // The preview settles on structural changes (time, duration); title
        // typing updates the preview text under a quiet content transition,
        // so the card no longer pops on every keystroke.
        .onChange(of: viewModel.scheduledStartAt) { _, _ in triggerPreviewPop() }
        .onChange(of: viewModel.estimatedDuration) { _, _ in triggerPreviewPop() }
        .onChange(of: viewModel.selectedLifeAreaID) { _, _ in triggerPreviewPop() }
    }

    private var selectedLifeArea: LifeArea? {
        guard let id = viewModel.selectedLifeAreaID else { return nil }
        return viewModel.lifeAreas.first { $0.id == id }
    }

    private var validationText: String? {
        if let error = viewModel.errorMessage {
            return error
        }
        return viewModel.validationErrors.first?.errorDescription
    }

    private var detailsSummary: String {
        var parts: [String] = []
        if viewModel.selectedProjectID != ProjectConstants.inboxProjectID {
            parts.append(viewModel.selectedProject)
        }
        if viewModel.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append(String(localized: "Notes"))
        }
        if viewModel.selectedPriority != .low {
            parts.append(String(localized: "\(viewModel.selectedPriority.displayName) priority"))
        }
        if viewModel.selectedTagIDs.isEmpty == false {
            parts.append(viewModel.selectedTagIDs.count == 1 ? String(localized: "1 tag") : String(localized: "\(viewModel.selectedTagIDs.count) tags"))
        }
        return parts.isEmpty ? String(localized: "Project, notes, tags and more") : parts.joined(separator: ", ")
    }

    private func handleAppear() {
        if viewModel.scheduledStartAt == nil, viewModel.hasExplicitSchedule == false {
            viewModel.restoreDefaultSchedule()
        }
        if ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_README_LIFE_OS_TOUR") {
            titleFieldFocused = false
            return
        }
        guard layoutClass == .phone, didAutoFocusTitleField == false else { return }
        didAutoFocusTitleField = true
        // Immediately: the keyboard rises with the sheet instead of a beat
        // after it, so the first keystroke is never lost.
        titleFieldFocused = true
    }

    private func handleCancel() {
        Haptic.pick.play()
        if viewModel.hasUnsavedChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func handleCreate() {
        guard canCreate else { return }
        pendingBehavior = .dismiss
        showAddAnother = false
        submit()
    }

    private func handleAddAnother() {
        guard canCreate else { return }
        pendingBehavior = .addAnother
        showAddAnother = false
        submit()
    }

    /// Applies what the title says (date, time, tags, project, priority)
    /// before saving, the way the composer and the Inbox already do.
    private func submit() {
        applyUITestDeadlineIfRequested()
        Task { @MainActor in
            await viewModel.applyTypedTitleParse()
            viewModel.createTask()
        }
    }

    /// UI tests only. Add Task schedules a task but never gives it a deadline
    /// ("when is not deadline"), and Home's Tasks card lists due tasks, so the
    /// suites that complete, undo and delete from that card launch with
    /// `-LIFEBOARD_TEST_NEW_TASKS_DUE_TODAY` to make a new task due today.
    private func applyUITestDeadlineIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-UI_TESTING"),
              arguments.contains("-LIFEBOARD_TEST_NEW_TASKS_DUE_TODAY"),
              viewModel.dueDate == nil else { return }
        viewModel.dueDate = Calendar.current.startOfDay(for: Date())
    }

    private func handleCreatedTask(_ taskID: UUID, behavior: TaskSubmissionBehavior) {
        pendingBehavior = nil
        didCreateTask = true
        onTaskCreated?(taskID)

        switch behavior {
        case .dismiss:
            // After the task exists: `lastCreatedTaskID` only changes on a
            // successful save.
            Haptic.commit.play()
            dismiss()
        case .addAnother:
            runSuccessReset {
                viewModel.resetForm()
                showAddAnother = true
                showDetails = false
                selectedDetent = .medium
            }
        }
    }

    private func runSuccessReset(afterReset: @escaping @MainActor () -> Void) {
        successResetTask?.cancel()
        Haptic.commit.play()
        withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
            successFlash = true
        }
        successResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard Task.isCancelled == false else { return }
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                successFlash = false
                afterReset()
            }
        }
    }

    private func toggleDetails() {
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            showDetails.toggle()
        }
        if showDetails {
            expandSheet()
        }
    }

    private func expandSheet() {
        Haptic.pick.play()
        withAnimation(MotionProfile.route.animation(reduceMotion: reduceMotion)) {
            selectedDetent = .large
        }
    }
}

/// "Understood: Tomorrow, 3:00 PM · #family" under the title field.
private struct AddTaskUnderstoodLine: View {
    let parsed: ParsedCapture

    private var parts: [String] {
        var values: [String] = []
        if let date = parsed.dueDate {
            values.append(parsed.isAllDay
                ? date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
        }
        if let duration = parsed.duration { values.append(LifeBoardDuration.text(seconds: duration)) }
        if parsed.repeatPattern != nil { values.append("Repeats") }
        if let priority = parsed.priority { values.append("\(priority.displayName) priority") }
        if let project = parsed.projectName { values.append("+\(project)") }
        values.append(contentsOf: parsed.tags.map { "#\($0)" })
        if let context = parsed.context { values.append("@\(context)") }
        return values
    }

    var body: some View {
        Label {
            Text("Found: \(parts.joined(separator: " · "))")
        } icon: {
            Image(systemName: "text.badge.checkmark")
        }
        .font(.lifeboard(.caption1))
        .foregroundStyle(Color.lifeboard(.textSecondary))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("addTask.understood")
    }
}

private enum TaskSubmissionBehavior {
    case dismiss
    case addAnother
}

/// The essentials rail — a single calm "when & where" unit. A chip rail (Time, Life area)
/// sits over the always-visible duration presets. The Time chip keeps the
/// `addTask.schedule.timeRow` identifier and the duration presets keep
/// `addTask.scheduleEditor` / `addTask.schedule.duration.*`, all of which the UI suite
/// asserts on directly (no expand step), so they must remain mounted and hittable.
private struct TaskEssentials: View {
    @ObservedObject var viewModel: AddTaskViewModel
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    var dueDate: Date? = nil
    @Binding var duration: TimeInterval?
    let selectedLifeArea: LifeArea?
    let onEditTime: () -> Void

    @State private var showLifeArea = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var timeText: String {
        guard let scheduledStartAt else { return AddTaskViewModel.anytimeLabel(day: dueDate) }
        return AddTaskViewModel.scheduleRangeLabel(start: scheduledStartAt, end: scheduledEndAt)
    }

    private var lifeAreaAccent: Color {
        guard let area = selectedLifeArea else { return Color.lifeboard(.accentPrimary) }
        return Color(lifeboardHex: LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id))
    }

    private var lifeAreaIcon: String { selectedLifeArea?.icon ?? "circle.dashed" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CalmSummaryChip(
                        icon: "clock",
                        label: timeText,
                        state: scheduledStartAt == nil && dueDate == nil ? .empty : .filled,
                        accentColor: Color.lifeboard(.accentPrimary),
                        action: onEditTime
                    )
                    .accessibilityIdentifier("addTask.schedule.timeRow")

                    CalmSummaryChip(
                        icon: lifeAreaIcon,
                        label: selectedLifeArea?.name ?? "Any area",
                        state: showLifeArea ? .active : (selectedLifeArea == nil ? .empty : .filled),
                        accentColor: lifeAreaAccent,
                        action: {
                            withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) { showLifeArea.toggle() }
                        }
                    )
                }
                .padding(.horizontal, 1)
            }

            DurationPicker(duration: $duration)

            if showLifeArea {
                LifeAreaPicker(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}

private struct DurationPicker: View {
    @Binding var duration: TimeInterval?
    @State private var showCustomDuration = false
    @State private var customMinutes = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let presets: [(label: String, minutes: Int)] = [15, 30, 45, 60, 90].map {
        (LifeBoardDuration.text(minutes: $0), $0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(Color.lifeboard(.textPrimary))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.minutes) { preset in
                        AddTaskMetadataChip(
                            icon: "timer",
                            text: preset.label,
                            isActive: matches(minutes: preset.minutes)
                        ) {
                            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                                duration = TimeInterval(preset.minutes * 60)
                                showCustomDuration = false
                            }
                        }
                        .accessibilityIdentifier("addTask.schedule.duration.\(preset.minutes)")
                    }

                    AddTaskMetadataChip(
                        icon: "pencil",
                        text: customTitle,
                        isActive: showCustomDuration || isCustomDuration,
                        action: toggleCustom
                    )
                }
            }

            if showCustomDuration {
                HStack(spacing: 8) {
                    TextField("Minutes", text: $customMinutes, prompt: Text("Minutes").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .font(.lifeboard(.callout))
                        .padKeyboard(.numberPad)
                        .padding(.horizontal, 12)
                        .frame(width: 116, height: 44)
                        .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                        .accessibilityIdentifier("addTask.schedule.customDurationField")

                    Button("Set", action: applyCustom)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                        .frame(minWidth: 44, minHeight: 44)
                        .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .accessibilityIdentifier("addTask.scheduleEditor")
    }

    private var customTitle: String {
        guard isCustomDuration, let duration else { return "Custom" }
        return Self.durationLabel(duration)
    }

    private var isCustomDuration: Bool {
        guard let duration else { return false }
        let minutes = Int((duration / 60).rounded())
        return presets.contains { $0.minutes == minutes } == false
    }

    private func matches(minutes: Int) -> Bool {
        guard let duration else { return false }
        return Int((duration / 60).rounded()) == minutes
    }

    private func toggleCustom() {
        customMinutes = duration.map { "\(max(1, Int(($0 / 60).rounded())))" } ?? ""
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            showCustomDuration.toggle()
        }
    }

    private func applyCustom() {
        guard let minutes = Int(customMinutes), minutes > 0 else { return }
        duration = TimeInterval(minutes * 60)
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            showCustomDuration = false
        }
    }

    private static func durationLabel(_ duration: TimeInterval) -> String {
        LifeBoardDuration.text(minutes: max(1, Int((duration / 60).rounded())))
    }
}

private struct LifeAreaPicker: View {
    @ObservedObject var viewModel: AddTaskViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ComposerOptionGrid(
            title: "Life area",
            helperText: nil,
            options: viewModel.lifeAreas.map {
                ComposerOption(
                    id: $0.id,
                    title: $0.name,
                    icon: $0.icon,
                    accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.color, for: $0.id)
                )
            },
            selectedID: viewModel.selectedLifeAreaID,
            noneOptionTitle: "Any area",
            emptyStateText: viewModel.lifeAreas.isEmpty ? String(localized: "No life areas yet") : nil,
            accessibilityIdentifier: "addTask.lifeAreaSelector"
        ) { selectedID in
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                viewModel.selectedLifeAreaID = selectedID
            }
        }
    }
}

private struct AddTaskDetails: View {
    @ObservedObject var viewModel: AddTaskViewModel
    @FocusState.Binding var descriptionFocused: Bool
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            CalmFieldGroup(title: "Notes") {
                AddTaskDescriptionField(
                    text: $viewModel.taskDetails,
                    isFocused: $descriptionFocused
                )
            }

            CalmFieldGroup(title: "Organize") {
                if viewModel.filteredProjectsForSelectedLifeArea.isEmpty == false {
                    AddTaskEntityPicker(
                        label: "Project",
                        items: viewModel.filteredProjectsForSelectedLifeArea.map {
                            AddTaskEntityPickerItem(id: $0.id, name: $0.name, icon: nil, accentHex: nil)
                        },
                        selectedID: Binding(
                            get: {
                                viewModel.selectedProjectID == ProjectConstants.inboxProjectID ? nil : viewModel.selectedProjectID
                            },
                            set: { viewModel.selectProject(id: $0) }
                        )
                    )
                }

                AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)

                if viewModel.sections.isEmpty == false {
                    AddTaskEntityPicker(
                        label: "Section",
                        items: viewModel.sections.map {
                            AddTaskEntityPickerItem(id: $0.id, name: $0.name, icon: nil, accentHex: nil)
                        },
                        selectedID: $viewModel.selectedSectionID
                    )
                }

                AddTaskTagMultiSelect(
                    tags: viewModel.tags,
                    selectedTagIDs: $viewModel.selectedTagIDs,
                    onCreateTag: { name, completion in
                        viewModel.createTag(name: name) { didCreate in
                            completion(didCreate)
                        }
                    }
                )

                AddTaskEnumChipRow(
                    label: "Energy",
                    displayName: { $0.displayName },
                    icon: { $0.emoji.isEmpty ? "bolt" : $0.emoji },
                    selected: $viewModel.selectedEnergy
                )

                AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)
            }

            TaskEditorSectionCard(
                section: .relationships,
                summary: viewModel.relationshipsSummary,
                isExpanded: viewModel.isSectionExpanded(.relationships)
            ) {
                viewModel.toggleSection(.relationships)
                if viewModel.isSectionExpanded(.relationships) {
                    viewModel.loadRelationshipTaskOptionsIfNeeded()
                    onExpand()
                }
            } content: {
                VStack(spacing: 12) {
                    if viewModel.availableParentTasks.isEmpty == false {
                        AddTaskTaskPicker(
                            label: "Parent task",
                            tasks: viewModel.availableParentTasks,
                            selectedTaskID: $viewModel.selectedParentTaskID
                        )
                    }
                    if viewModel.availableDependencyTasks.isEmpty == false {
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
}

private struct TaskTimeEditorSheet: View {
    @ObservedObject var viewModel: AddTaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                DatePicker(
                    "Start",
                    selection: $draftDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(Color.lifeboard(.accentPrimary))
                .accessibilityIdentifier("addTask.schedule.timePicker")

                TaskTimelinePreview(
                    title: viewModel.taskName,
                    scheduledStartAt: draftDate,
                    scheduledEndAt: draftDate.addingTimeInterval(viewModel.estimatedDuration ?? AddTaskViewModel.defaultEstimatedDuration),
                    duration: viewModel.estimatedDuration,
                    lifeArea: selectedLifeArea,
                    action: {}
                )
                .allowsHitTesting(false)
            }
            .padding(20)
            .background(AddTaskBackground().ignoresSafeArea())
            .navigationTitle("Task time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .bottomBar) {
                    // A task does not need a slot. "Anytime" keeps the chosen day
                    // (unless it is today) and drops the time.
                    Button("Anytime") {
                        let isToday = Calendar.current.isDateInToday(draftDate)
                        viewModel.setAnytime(on: isToday ? nil : draftDate)
                        dismiss()
                    }
                    .accessibilityIdentifier("addTask.schedule.anytime")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        viewModel.setScheduledDate(draftDate)
                        viewModel.setScheduledStartTime(draftDate)
                        dismiss()
                    }
                    .accessibilityIdentifier("addTask.schedule.timePickerConfirm")
                }
            }
        }
        .accessibilityIdentifier("addTask.schedule.timePickerSheet")
        .onAppear {
            draftDate = viewModel.scheduledStartAt
                ?? viewModel.plannedDate.map { day in
                    let time = AddTaskViewModel.defaultScheduledStart()
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                    return Calendar.current.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: day) ?? time
                }
                ?? AddTaskViewModel.defaultScheduledStart()
        }
    }

    private var selectedLifeArea: LifeArea? {
        guard let id = viewModel.selectedLifeAreaID else { return nil }
        return viewModel.lifeAreas.first { $0.id == id }
    }
}

private struct AddTaskErrorView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.lifeboard(.callout))
            .foregroundStyle(Color.lifeboard(.textPrimary))
            .symbolRenderingMode(.multicolor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .lifeBoardClaySurface(.resting, cornerRadius: Radius.card, fill: Color.lifeboard(.statusWarning).opacity(0.14))
    }
}

/// The sheet's canvas: the semantic page color, not the Sunrise gradient.
private struct AddTaskBackground: View {
    var body: some View {
        Color.lifeboard(.bgCanvas)
    }
}
