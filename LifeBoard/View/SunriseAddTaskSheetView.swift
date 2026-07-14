//
//  SunriseAddTaskSheetView.swift
//  LifeBoard
//

import SwiftUI

public struct SunriseAddTaskSheetView: View {
    @StateObject private var viewModel: AddTaskViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let onTaskCreated: ((UUID) -> Void)?
    private let onDismissWithoutTask: (() -> Void)?

    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showDiscardConfirmation = false
    @State private var showAddAnother = false
    @State private var successFlash = false
    @State private var didCreateTask = false
    @State private var pendingBehavior: SunriseTaskSubmissionBehavior?
    @State private var successResetTask: Task<Void, Never>?
    @State private var showTimeEditor = false
    @State private var showDetails = false
    @State private var didAutoFocusTitleField = false
    @State private var previewPop = false
    @State private var previewPopTask: Task<Void, Never>?

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var canCreate: Bool {
        viewModel.viewState.canSubmit && viewModel.scheduledStartAt != nil && !viewModel.isLoading
    }
    private var isPreviewAwaiting: Bool {
        viewModel.taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func triggerPreviewPop() {
        guard !reduceMotion else { return }
        previewPopTask?.cancel()
        withAnimation(LifeBoardAnimation.snappy) { previewPop = true }
        previewPopTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard Task.isCancelled == false else { return }
            withAnimation(LifeBoardAnimation.snappy) { previewPop = false }
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
            AddTaskNavigationBar(
                containerMode: .sheet,
                title: "New Task",
                canSave: canCreate,
                onCancel: handleCancel,
                onSave: handleCreate
            )
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    SunriseTaskTimelinePreview(
                        title: viewModel.taskName,
                        scheduledStartAt: viewModel.scheduledStartAt,
                        scheduledEndAt: viewModel.scheduledEndAt,
                        duration: viewModel.estimatedDuration,
                        lifeArea: selectedLifeArea,
                        isAwaiting: isPreviewAwaiting,
                        action: { showTimeEditor = true }
                    )
                    .scaleEffect(previewPop && !reduceMotion ? 1.03 : 1.0)
                    .animation(LifeBoardAnimation.snappy, value: previewPop)
                    .cardEntrance(index: 0)

                    AddTaskTitleField(
                        text: $viewModel.taskName,
                        isFocused: $titleFieldFocused,
                        placeholder: "What do you want to do?",
                        helperText: "Keep it small enough for an ordinary day.",
                        onSubmit: handleCreate
                    )
                    .cardEntrance(index: 1)

                    SunriseTaskEssentials(
                        viewModel: viewModel,
                        scheduledStartAt: viewModel.scheduledStartAt,
                        scheduledEndAt: viewModel.scheduledEndAt,
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
                        SunriseAddTaskDetails(
                            viewModel: viewModel,
                            descriptionFocused: $descriptionFieldFocused,
                            onExpand: expandSheet
                        )
                    }
                    .cardEntrance(index: 3)

                    if let validationText {
                        SunriseAddTaskErrorView(message: validationText)
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
                buttonTitle: viewModel.scheduledStartAt == nil ? "Choose Time" : "Add Task",
                onCreateAction: handleCreate,
                onAddAnotherAction: handleAddAnother
            )
            .accessibilityIdentifier("addTask.createButton")
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 720 : .infinity, alignment: .center)
        .background(SunriseAddTaskBackground().ignoresSafeArea())
        .accessibilityIdentifier("addTask.view")
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .sheet(isPresented: $showTimeEditor) {
            SunriseTaskTimeEditorSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes that will be lost.")
        }
        .overlay(
            LBColorTokens.leaf
                .opacity(successFlash ? 0.06 : 0)
                .animation(LifeBoardAnimation.gentle, value: successFlash)
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
        if viewModel.scheduledStartAt == nil {
            return "Choose a start time to preview this task in your timeline."
        }
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
            parts.append("Notes")
        }
        if viewModel.selectedPriority != .low {
            parts.append("\(viewModel.selectedPriority.displayName) priority")
        }
        if viewModel.selectedTagIDs.isEmpty == false {
            parts.append(viewModel.selectedTagIDs.count == 1 ? "1 tag" : "\(viewModel.selectedTagIDs.count) tags")
        }
        return parts.isEmpty ? "Project, notes, priority, reminders, tags, and links." : parts.joined(separator: ", ")
    }

    private func handleAppear() {
        if viewModel.scheduledStartAt == nil {
            viewModel.restoreDefaultSchedule()
        }
        guard layoutClass == .phone, didAutoFocusTitleField == false else { return }
        didAutoFocusTitleField = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            titleFieldFocused = true
        }
    }

    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            LifeBoardFeedback.medium()
            showDiscardConfirmation = true
        } else {
            LifeBoardFeedback.light()
            dismiss()
        }
    }

    private func handleCreate() {
        guard canCreate else {
            if viewModel.scheduledStartAt == nil {
                showTimeEditor = true
            }
            return
        }
        pendingBehavior = .dismiss
        showAddAnother = false
        viewModel.createTask()
    }

    private func handleAddAnother() {
        guard canCreate else { return }
        pendingBehavior = .addAnother
        showAddAnother = false
        viewModel.createTask()
    }

    private func handleCreatedTask(_ taskID: UUID, behavior: SunriseTaskSubmissionBehavior) {
        pendingBehavior = nil
        didCreateTask = true
        onTaskCreated?(taskID)

        switch behavior {
        case .dismiss:
            LifeBoardFeedback.success()
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
        LifeBoardFeedback.success()
        withAnimation(LifeBoardAnimation.snappy) {
            successFlash = true
        }
        successResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard Task.isCancelled == false else { return }
            withAnimation(LifeBoardAnimation.snappy) {
                successFlash = false
                afterReset()
            }
        }
    }

    private func toggleDetails() {
        withAnimation(LifeBoardAnimation.snappy) {
            showDetails.toggle()
        }
        if showDetails {
            expandSheet()
        }
    }

    private func expandSheet() {
        LifeBoardFeedback.light()
        withAnimation(LifeBoardAnimation.gentle) {
            selectedDetent = .large
        }
    }
}

private enum SunriseTaskSubmissionBehavior {
    case dismiss
    case addAnother
}

/// The essentials rail — a single calm "when & where" unit. A chip rail (Time, Life area)
/// sits over the always-visible duration presets. The Time chip keeps the
/// `addTask.schedule.timeRow` identifier and the duration presets keep
/// `addTask.scheduleEditor` / `addTask.schedule.duration.*`, all of which the UI suite
/// asserts on directly (no expand step), so they must remain mounted and hittable.
private struct SunriseTaskEssentials: View {
    @ObservedObject var viewModel: AddTaskViewModel
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    @Binding var duration: TimeInterval?
    let selectedLifeArea: LifeArea?
    let onEditTime: () -> Void

    @State private var showLifeArea = false

    private var timeText: String {
        guard let scheduledStartAt else { return "Choose time" }
        return AddTaskViewModel.scheduleRangeLabel(start: scheduledStartAt, end: scheduledEndAt)
    }

    private var lifeAreaAccent: Color {
        guard let area = selectedLifeArea else { return LBColorTokens.violet }
        return Color(lifeboardHex: LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id))
    }

    private var lifeAreaIcon: String { selectedLifeArea?.icon ?? "circle.dashed" }

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LBSpacingTokens.xs) {
                    CalmSummaryChip(
                        icon: "clock",
                        label: timeText,
                        state: scheduledStartAt == nil ? .empty : .filled,
                        accentColor: LBColorTokens.violet,
                        action: onEditTime
                    )
                    .accessibilityIdentifier("addTask.schedule.timeRow")

                    CalmSummaryChip(
                        icon: lifeAreaIcon,
                        label: selectedLifeArea?.name ?? "Any area",
                        state: showLifeArea ? .active : (selectedLifeArea == nil ? .empty : .filled),
                        accentColor: lifeAreaAccent,
                        action: {
                            withAnimation(LifeBoardAnimation.snappy) { showLifeArea.toggle() }
                        }
                    )
                }
                .padding(.horizontal, 1)
            }

            SunriseDurationPicker(duration: $duration)

            if showLifeArea {
                SunriseLifeAreaPicker(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}

private struct SunriseTaskTimelinePreview: View {
    let title: String
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let duration: TimeInterval?
    let lifeArea: LifeArea?
    var isAwaiting: Bool = false
    let action: () -> Void

    private var role: LBRoleStyle { LBColorTokens.role(.task) }
    private var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New task" : trimmed
    }
    private var lifeAreaText: String {
        lifeArea?.name ?? "Any life area"
    }
    private var durationText: String? {
        guard let duration else { return nil }
        let minutes = max(1, Int((duration / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
    }
    private var timeText: String {
        guard let scheduledStartAt else { return "Choose time" }
        return AddTaskViewModel.scheduleRangeLabel(start: scheduledStartAt, end: scheduledEndAt)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
                VStack(spacing: 6) {
                    Text(scheduledStartAt.map(Self.hourText(for:)) ?? "--")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .frame(width: 58, alignment: .trailing)
                    Circle()
                        .fill(role.base)
                        .frame(width: 10, height: 10)
                        .breathingPulse(min: isAwaiting ? 0.35 : 1.0, max: 1.0, duration: 1.6)
                    Rectangle()
                        .fill(role.border)
                        .frame(width: 2, height: 56)
                        .opacity(0.7)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(timeText, systemImage: "clock")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(role.deep)
                        Spacer(minLength: LBSpacingTokens.xs)
                        if let durationText {
                            Text(durationText)
                                .font(.lifeboard(.caption1).weight(.semibold))
                                .foregroundStyle(LBColorTokens.navyMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(LBColorTokens.glassStrong))
                        }
                    }

                    Text(displayTitle)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(LBColorTokens.navy)
                        .lineLimit(2)
                        .contentTransition(.opacity)
                        .animation(LifeBoardAnimation.snappy, value: displayTitle)

                    Label(lifeAreaText, systemImage: role.symbolName)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
                }
                .padding(LBSpacingTokens.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [role.softSurface, LBColorTokens.glassStrong],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(role.border.opacity(0.82), lineWidth: 1)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addTask.timelinePreview")
        .accessibilityLabel("Timeline preview. \(displayTitle). \(timeText). \(durationText.map { "\($0). " } ?? "")\(lifeAreaText).")
    }

    private static func hourText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}

private struct SunriseDurationPicker: View {
    @Binding var duration: TimeInterval?
    @State private var showCustomDuration = false
    @State private var customMinutes = ""

    private let presets: [(label: String, minutes: Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("45m", 45),
        ("1h", 60),
        ("90m", 90)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
            Text("Duration")
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LBSpacingTokens.xs) {
                    ForEach(presets, id: \.minutes) { preset in
                        AddTaskMetadataChip(
                            icon: "timer",
                            text: preset.label,
                            isActive: matches(minutes: preset.minutes)
                        ) {
                            withAnimation(LifeBoardAnimation.snappy) {
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
                HStack(spacing: LBSpacingTokens.xs) {
                    TextField("Minutes", text: $customMinutes)
                        .font(.lifeboard(.callout))
                        .keyboardType(.numberPad)
                        .padding(.horizontal, LBSpacingTokens.sm)
                        .frame(width: 116, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LBColorTokens.glassStrong)
                        )
                        .accessibilityIdentifier("addTask.schedule.customDurationField")

                    Button("Set", action: applyCustom)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(LBColorTokens.violet)
                        .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(LBSpacingTokens.md)
        .sunriseGlassCard(cornerRadius: 22, accentColor: LBColorTokens.leaf)
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
        withAnimation(LifeBoardAnimation.snappy) {
            showCustomDuration.toggle()
        }
    }

    private func applyCustom() {
        guard let minutes = Int(customMinutes), minutes > 0 else { return }
        duration = TimeInterval(minutes * 60)
        withAnimation(LifeBoardAnimation.snappy) {
            showCustomDuration = false
        }
    }

    private static func durationLabel(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
    }
}

private struct SunriseLifeAreaPicker: View {
    @ObservedObject var viewModel: AddTaskViewModel

    var body: some View {
        LifeBoardComposerOptionGrid(
            title: "Life Area",
            helperText: "This sets the color and context for the timeline preview.",
            options: viewModel.lifeAreas.map {
                LifeBoardComposerOption(
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
            withAnimation(LifeBoardAnimation.snappy) {
                viewModel.selectedLifeAreaID = selectedID
            }
        }
    }
}

private struct SunriseAddTaskDetails: View {
    @ObservedObject var viewModel: AddTaskViewModel
    @FocusState.Binding var descriptionFocused: Bool
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: LBSpacingTokens.lg) {
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
                VStack(spacing: LBSpacingTokens.sm) {
                    if viewModel.availableParentTasks.isEmpty == false {
                        AddTaskTaskPicker(
                            label: "Parent Task",
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

private struct SunriseTaskTimeEditorSheet: View {
    @ObservedObject var viewModel: AddTaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: LBSpacingTokens.lg) {
                DatePicker(
                    "Start",
                    selection: $draftDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(LBColorTokens.violet)
                .accessibilityIdentifier("addTask.schedule.timePicker")

                SunriseTaskTimelinePreview(
                    title: viewModel.taskName,
                    scheduledStartAt: draftDate,
                    scheduledEndAt: draftDate.addingTimeInterval(viewModel.estimatedDuration ?? AddTaskViewModel.defaultEstimatedDuration),
                    duration: viewModel.estimatedDuration,
                    lifeArea: selectedLifeArea,
                    action: {}
                )
                .allowsHitTesting(false)
            }
            .padding(LBSpacingTokens.lg)
            .background(SunriseAddTaskBackground().ignoresSafeArea())
            .navigationTitle("Task time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            draftDate = viewModel.scheduledStartAt ?? AddTaskViewModel.defaultScheduledStart()
        }
    }

    private var selectedLifeArea: LifeArea? {
        guard let id = viewModel.selectedLifeAreaID else { return nil }
        return viewModel.lifeAreas.first { $0.id == id }
    }
}

private struct SunriseAddTaskErrorView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.lifeboard(.callout))
            .foregroundStyle(LBColorTokens.role(.warning).deep)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LBSpacingTokens.md)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LBColorTokens.role(.warning).softSurface)
            )
    }
}

private struct SunriseAddTaskBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                LBColorTokens.warmCanvas,
                LBColorTokens.coolCanvas,
                LBColorTokens.canvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    func sunriseGlassCard(cornerRadius: CGFloat, accentColor: Color) -> some View {
        modifier(SunriseGlassCardModifier(cornerRadius: cornerRadius, accentColor: accentColor))
    }
}

private struct SunriseGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let accentColor: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if #available(iOS 26.0, *) {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                        .overlay(shape.fill(LBColorTokens.glass.opacity(0.50)))
                } else {
                    shape
                        .fill(.regularMaterial)
                        .overlay(shape.fill(LBColorTokens.glass))
                }
            }
            .overlay {
                shape.stroke(LBColorTokens.glassBorder, lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(accentColor.opacity(0.16))
                    .frame(width: 34, height: 8)
                    .padding(.top, 11)
                    .padding(.leading, 14)
            }
            .shadow(color: LBColorTokens.elevationShadow, radius: 18, x: 0, y: 10)
    }
}
