//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Overdue rescue sheet for the Home sunrise shell.
//

import SwiftUI

private enum EvaRescueMoveChoice: String, CaseIterable {
    case tomorrow
    case weekend
    case custom

    var title: String {
        switch self {
        case .tomorrow: return "Tomorrow"
        case .weekend: return "Weekend"
        case .custom: return "Custom"
        }
    }
}

private struct EvaRescueSplitComposerState: Sendable {
    var isOpen = false
    var childTitles: [String] = ["", ""]
    var duePreset: EvaTriageDeferPreset?
    var isCreating = false
    var errorMessage: String?
    var completed = false
    var createdChildIDs: [UUID] = []
}

struct EvaOverdueRescueSheetV2: View {
    let plan: EvaRescuePlan?
    let tasksByID: [UUID: TaskDefinition]
    let lastBatchRunID: UUID?
    let onApply: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onUndo: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onCreateSplit: @Sendable (UUID, EvaSplitDraft, @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void) -> Void
    let onUndoSplit: @Sendable ([UUID], @escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    let onTrack: (String, [String: Any]) -> Void

    @State private var selectedActionByTaskID: [UUID: EvaRescueActionType] = [:]
    @State private var moveChoiceByTaskID: [UUID: EvaRescueMoveChoice] = [:]
    @State private var customMoveDateByTaskID: [UUID: Date] = [:]
    @State private var splitStateByTaskID: [UUID: EvaRescueSplitComposerState] = [:]
    @State private var showDropConfirm = false
    @State private var pendingMutations: [EvaBatchMutationInstruction] = []
    @State private var isApplying = false
    @State private var isUndoing = false
    @State private var errorMessage: String?
    @State private var snackbar: SnackbarData?
    @State private var emptyStateAppeared = false

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    private var allRecommendations: [EvaRescueRecommendation] {
        guard let plan else { return [] }
        return plan.doToday + plan.move + plan.split + plan.dropCandidate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let plan {
                    // 7B: Debt level header
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        HStack {
                            Text("Debt: \(plan.debtLevel.rawValue.capitalized)")
                                .font(.lifeboard(.title3))
                                .foregroundColor(debtLevelColor(plan.debtLevel))
                            Spacer()
                            Text("\(allRecommendations.count)")
                                .font(.lifeboard(.caption1))
                                .foregroundColor(Color.lifeboard.textSecondary)
                                .contentTransition(.numericText())
                                .padding(.horizontal, spacing.s8)
                                .padding(.vertical, spacing.s4)
                                .background(Color.lifeboard.surfaceSecondary)
                                .clipShape(Capsule())
                            Text("overdue")
                                .font(.lifeboard(.caption2))
                                .foregroundColor(Color.lifeboard.textTertiary)
                        }

                        // 7B: Debt progress bar
                        LifeBoardProgressBar(
                            progress: min(plan.debtScore / 100.0, 1.0),
                            colors: [debtLevelColor(plan.debtLevel), debtLevelColor(plan.debtLevel)],
                            trackColor: Color.lifeboard.surfaceSecondary,
                            height: 6
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.lifeboard(.caption2))
                                .foregroundColor(Color.lifeboard.statusDanger)
                        }
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s12)
                    .enhancedStaggeredAppearance(index: 0)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            rescueGroup(title: "Do today", icon: "flame.fill", iconColor: Color.lifeboard.statusWarning, items: plan.doToday, startIndex: 0)
                            rescueGroup(title: "Move", icon: "calendar.badge.clock", iconColor: Color.lifeboard.accentPrimary, items: plan.move, startIndex: plan.doToday.count)
                            rescueGroup(title: "Split", icon: "scissors", iconColor: Color.lifeboard.priorityHigh, items: plan.split, startIndex: plan.doToday.count + plan.move.count)
                            rescueGroup(title: "Drop?", icon: "trash", iconColor: Color.lifeboard.statusDanger, items: plan.dropCandidate, startIndex: plan.doToday.count + plan.move.count + plan.split.count)
                        }
                        .padding(.horizontal, spacing.s16)
                        .padding(.top, spacing.s12)
                        .padding(.bottom, spacing.s24)
                    }

                    Divider()
                    stickyRescueActionBar(plan: plan)
                } else {
                    // 7I: Empty state
                    VStack(spacing: spacing.s16) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.lifeboard.statusSuccess)
                            .breathingPulse(min: 0.7, max: 1.0, duration: 2.0)
                            .scaleEffect(emptyStateAppeared ? 1.0 : 0.3)
                            .animation(LifeBoardAnimation.expressive, value: emptyStateAppeared)
                        Text("All caught up!")
                            .font(.lifeboard(.title3))
                            .foregroundColor(Color.lifeboard.textPrimary)
                            .opacity(emptyStateAppeared ? 1.0 : 0)
                            .animation(LifeBoardAnimation.expressive.delay(0.1), value: emptyStateAppeared)
                        Text("No overdue tasks to rescue.")
                            .font(.lifeboard(.body))
                            .foregroundColor(Color.lifeboard.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(spacing.s16)
                    .onAppear { emptyStateAppeared = true }
                }
            }
            .background(Color.lifeboard.bgCanvas)
            .navigationTitle("Rescue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeDefaults()
            }
            .alert("Apply drop actions?", isPresented: $showDropConfirm) {
                Button("Apply", role: .destructive) {
                    runApply(mutations: pendingMutations)
                    pendingMutations = []
                }
                Button("Cancel", role: .cancel) {
                    pendingMutations = []
                }
            } message: {
                Text("Tasks marked Drop? will be moved to Inbox and their due dates cleared.")
            }
        }
        .lifeboardSnackbar($snackbar)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func debtLevelColor(_ level: EvaDebtLevel) -> Color {
        switch level {
        case .none: return Color.lifeboard.statusSuccess
        case .low: return Color.lifeboard.accentPrimary
        case .medium: return Color.lifeboard.statusWarning
        case .high: return Color.lifeboard.statusDanger
        }
    }

    private func stickyRescueActionBar(plan: EvaRescuePlan) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if buildMutations(plan: plan).isEmpty {
                Text("Select at least one Today, Move, or Drop action to apply.")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }

            HStack(spacing: spacing.s8) {
                // 7H: Apply plan - primary filled
                Button {
                    let mutations = buildMutations(plan: plan)
                    if hasDropSelection(plan: plan) {
                        pendingMutations = mutations
                        showDropConfirm = true
                    } else {
                        runApply(mutations: mutations)
                    }
                } label: {
                    Text("Apply plan")
                        .font(.lifeboard(.button))
                        .foregroundColor(Color.lifeboard.accentOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(
                            (isApplying || buildMutations(plan: plan).isEmpty)
                                ? Color.lifeboard.accentMuted
                                : Color.lifeboard.accentPrimary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .disabled(isApplying || buildMutations(plan: plan).isEmpty)

                // 7H: Undo - outline
                if lastBatchRunID != nil {
                    Button {
                        isUndoing = true
                        onTrack("rescue_undo_tap", [:])
                        onUndo { result in
                            Task { @MainActor in
                                isUndoing = false
                                switch result {
                                case .success:
                                    snackbar = SnackbarData(message: "Rescue plan undone")
                                    LifeBoardFeedback.success()
                                case .failure(let error):
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        Text("Undo")
                            .font(.lifeboard(.buttonSmall))
                            .foregroundColor(Color.lifeboard.textSecondary)
                            .frame(minWidth: 64, minHeight: spacing.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: corner.r2)
                                    .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .disabled(isApplying || isUndoing)
                }
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s12)
        .padding(.bottom, spacing.s12)
        .background(Color.lifeboard.surfacePrimary)
    }

    @ViewBuilder
    private func rescueGroup(title: String, icon: String, iconColor: Color, items: [EvaRescueRecommendation], startIndex: Int) -> some View {
        if items.isEmpty == false {
            // 7C: Group header with icon and count badge
            HStack(spacing: spacing.s8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard.textPrimary)
                Text("\(items.count)")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(Color.lifeboard.textSecondary)
                    .padding(.horizontal, spacing.s8)
                    .padding(.vertical, spacing.s2)
                    .background(Color.lifeboard.surfaceSecondary)
                    .clipShape(Capsule())
                Spacer()
            }

            ForEach(Array(items.enumerated()), id: \.element.taskID) { index, item in
                let selectedAction = selectedActionByTaskID[item.taskID] ?? item.action
                let splitState = splitStateByTaskID[item.taskID] ?? EvaRescueSplitComposerState()
                let task = tasksByID[item.taskID]

                // 7D: Rescue item card
                HStack(spacing: 0) {
                    // Priority stripe
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rescuePriorityColor(for: task?.priority))
                        .frame(width: 4)
                        .padding(.vertical, spacing.s8)

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        HStack(spacing: spacing.s8) {
                            Text(task?.title ?? "Task")
                                .font(.lifeboard(.body))
                                .foregroundColor(Color.lifeboard.textPrimary)
                                .lineLimit(2)

                            Spacer()

                            // 7D: Confidence badge
                            Text(confidenceText(for: item.confidence))
                                .font(.lifeboard(.caption2))
                                .foregroundColor(rescueConfidenceBadgeTextColor(item.confidence))
                                .padding(.horizontal, spacing.s8)
                                .padding(.vertical, spacing.s4)
                                .background(rescueConfidenceBadgeColor(item.confidence))
                                .clipShape(Capsule())
                        }

                        // 7D: Overdue age badge + reason pills
                        HStack(spacing: spacing.s4) {
                            if let dueDate = task?.dueDate, dueDate < Date() {
                                let daysOverdue = max(0, Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0)
                                Text("\(daysOverdue)d overdue")
                                    .font(.lifeboard(.caption2))
                                    .foregroundColor(Color.lifeboard.statusDanger)
                                    .padding(.horizontal, spacing.s8)
                                    .padding(.vertical, spacing.s2)
                                    .background(Color.lifeboard.statusDanger.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        // 7D: Reason pills
                        if !item.reasons.isEmpty {
                            HStack(spacing: spacing.s4) {
                                ForEach(item.reasons, id: \.self) { reason in
                                    Text(reason)
                                        .font(.lifeboard(.caption2))
                                        .foregroundColor(Color.lifeboard.textTertiary)
                                        .padding(.horizontal, spacing.s8)
                                        .padding(.vertical, spacing.s2)
                                        .background(Color.lifeboard.surfaceSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        // 7E: Action chip row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: spacing.s8) {
                                rescueActionChip(item: item, action: .doToday, selectedAction: selectedAction)
                                rescueActionChip(item: item, action: .move, selectedAction: selectedAction)
                                rescueActionChip(item: item, action: .split, selectedAction: selectedAction)
                                rescueActionChip(item: item, action: .dropCandidate, selectedAction: selectedAction)
                            }
                        }

                        // 7F: Move choice row
                        if selectedAction == .move {
                            moveChoiceRow(for: item)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if selectedAction == .split {
                            splitComposer(for: item, state: splitState)
                        }

                        if splitState.completed {
                            HStack(spacing: spacing.s4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.lifeboard.statusSuccess)
                                Text("Split done")
                                    .font(.lifeboard(.caption2))
                                    .foregroundColor(Color.lifeboard.accentPrimary)
                            }
                        }
                    }
                    .padding(spacing.s12)
                }
                .lifeboardDenseSurface(
                    cornerRadius: corner.r2,
                    fillColor: Color.lifeboard.surfacePrimary,
                    strokeColor: Color.lifeboard.strokeHairline
                )
                .enhancedStaggeredAppearance(index: startIndex + index + 1)
            }
        }
    }

    private func rescuePriorityColor(for priority: TaskPriority?) -> Color {
        guard let priority else { return Color.lifeboard.priorityNone }
        switch priority {
        case .max: return Color.lifeboard.priorityMax
        case .high: return Color.lifeboard.priorityHigh
        case .low: return Color.lifeboard.priorityLow
        case .none: return Color.lifeboard.priorityNone
        }
    }

    private func rescueConfidenceBadgeColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.lifeboard.statusSuccess.opacity(0.15)
        case 0.45..<0.75: return Color.lifeboard.statusWarning.opacity(0.15)
        default: return Color.lifeboard.textTertiary.opacity(0.12)
        }
    }

    private func rescueConfidenceBadgeTextColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.lifeboard.statusSuccess
        case 0.45..<0.75: return Color.lifeboard.statusWarning
        default: return Color.lifeboard.textTertiary
        }
    }

    private func moveChoiceRow(for item: EvaRescueRecommendation) -> some View {
        let selectedChoice = moveChoiceByTaskID[item.taskID] ?? .tomorrow
        return VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                ForEach(EvaRescueMoveChoice.allCases, id: \.self) { choice in
                    Button {
                        withAnimation(LifeBoardAnimation.quick) {
                            moveChoiceByTaskID[item.taskID] = choice
                        }
                        onTrack("rescue_action_changed", [
                            "task_id": item.taskID.uuidString,
                            "action": "move_\(choice.rawValue)"
                        ])
                        LifeBoardFeedback.selection()
                    } label: {
                        Text(choice.title)
                            .font(.lifeboard(.caption2))
                            .foregroundColor(selectedChoice == choice ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
                            .padding(.horizontal, spacing.s12)
                            .frame(minHeight: 36)
                            .background(selectedChoice == choice ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }

            if selectedChoice == .custom {
                let selectedDate = customMoveDateByTaskID[item.taskID] ?? Calendar.current.startOfDay(for: Date())
                DatePicker(
                    "Move date",
                    selection: Binding(
                        get: { selectedDate },
                        set: { customMoveDateByTaskID[item.taskID] = Calendar.current.startOfDay(for: $0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .frame(minHeight: 44)
                .padding(spacing.s8)
                .background(Color.lifeboard.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                .tint(Color.lifeboard.accentPrimary)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // 7G: Split composer
    private func splitComposer(for item: EvaRescueRecommendation, state: EvaRescueSplitComposerState) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if !state.isOpen {
                Button {
                    var next = state
                    next.isOpen = true
                    splitStateByTaskID[item.taskID] = next
                    onTrack("rescue_split_open", [
                        "task_id": item.taskID.uuidString
                    ])
                    LifeBoardFeedback.selection()
                } label: {
                    Text("Open split helper")
                        .font(.lifeboard(.buttonSmall))
                        .foregroundColor(Color.lifeboard.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
            } else {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    ForEach(Array(state.childTitles.enumerated()), id: \.offset) { index, title in
                        TextField(
                            "Subtask \(index + 1)",
                            text: Binding(
                                get: { splitStateByTaskID[item.taskID]?.childTitles[safe: index] ?? title },
                                set: { newValue in
                                    var next = splitStateByTaskID[item.taskID] ?? state
                                    guard next.childTitles.indices.contains(index) else { return }
                                    next.childTitles[index] = newValue
                                    splitStateByTaskID[item.taskID] = next
                                }
                            )
                        )
                        .textInputAutocapitalization(.sentences)
                        .font(.lifeboard(.caption1))
                        .padding(.horizontal, spacing.s12)
                        .frame(minHeight: 40)
                        .background(Color.lifeboard.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: corner.r1))
                    }

                    if state.childTitles.count < 3 {
                        Button {
                            withAnimation(LifeBoardAnimation.bouncy) {
                                var next = splitStateByTaskID[item.taskID] ?? state
                                next.childTitles.append("")
                                splitStateByTaskID[item.taskID] = next
                            }
                        } label: {
                            HStack(spacing: spacing.s4) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color.lifeboard.accentPrimary)
                                Text("Add child")
                                    .font(.lifeboard(.caption1))
                                    .foregroundColor(Color.lifeboard.accentPrimary)
                            }
                            .frame(minHeight: 36)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: spacing.s8) {
                        splitDueChip(item: item, title: "No due", preset: nil, state: state)
                        splitDueChip(item: item, title: "Tomorrow", preset: .tomorrow, state: state)
                        splitDueChip(item: item, title: "Weekend", preset: .weekendSaturday, state: state)
                    }

                    if let splitError = state.errorMessage {
                        Text(splitError)
                            .font(.lifeboard(.caption2))
                            .foregroundColor(Color.lifeboard.statusDanger)
                    }

                    Button {
                        runSplitCreation(for: item, state: state)
                    } label: {
                        Text("Create subtasks")
                            .font(.lifeboard(.button))
                            .foregroundColor(Color.lifeboard.accentOnPrimary)
                            .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                            .background(
                                (state.isCreating || validSplitTitles(state).count < 2)
                                    ? Color.lifeboard.accentMuted
                                    : Color.lifeboard.accentPrimary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .disabled(state.isCreating || validSplitTitles(state).count < 2)
                }
                .padding(spacing.s12)
                .background(Color.lifeboard.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: corner.r2))
            }
        }
    }

    private func splitDueChip(
        item: EvaRescueRecommendation,
        title: String,
        preset: EvaTriageDeferPreset?,
        state: EvaRescueSplitComposerState
    ) -> some View {
        let isSelected = state.duePreset == preset
        return Button {
            withAnimation(LifeBoardAnimation.quick) {
                var next = splitStateByTaskID[item.taskID] ?? state
                next.duePreset = preset
                splitStateByTaskID[item.taskID] = next
            }
            LifeBoardFeedback.selection()
        } label: {
            Text(title)
                .font(.lifeboard(.caption2))
                .foregroundColor(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
                .padding(.horizontal, spacing.s12)
                .frame(minHeight: 36)
                .background(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    // 7E: Action chip with icon
    private func rescueActionChip(
        item: EvaRescueRecommendation,
        action: EvaRescueActionType,
        selectedAction: EvaRescueActionType
    ) -> some View {
        let isSelected = selectedAction == action
        return Button {
            withAnimation(LifeBoardAnimation.quick) {
                selectedActionByTaskID[item.taskID] = action
            }
            onTrack("rescue_action_changed", [
                "task_id": item.taskID.uuidString,
                "action": action.rawValue
            ])
            LifeBoardFeedback.selection()
        } label: {
            HStack(spacing: spacing.s4) {
                Image(systemName: rescueActionIcon(for: action))
                    .font(.system(size: 11))
                Text(actionTitle(for: action))
                    .font(.lifeboard(.caption2))
            }
            .foregroundColor(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
            .padding(.horizontal, spacing.s12)
            .frame(minHeight: 36)
            .background(
                isSelected
                    ? Color.lifeboard.accentPrimary
                    : Color.lifeboard.surfaceSecondary
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.lifeboard.strokeHairline, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .activeGlow(isActive: isSelected, color: Color.lifeboard.accentPrimary)
        .accessibilityLabel(actionTitle(for: action))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func rescueActionIcon(for action: EvaRescueActionType) -> String {
        switch action {
        case .doToday: return "flame.fill"
        case .move: return "calendar"
        case .split: return "scissors"
        case .dropCandidate: return "trash"
        }
    }

    private func runSplitCreation(for item: EvaRescueRecommendation, state: EvaRescueSplitComposerState) {
        var next = state
        next.isCreating = true
        next.errorMessage = nil
        splitStateByTaskID[item.taskID] = next

        let draft = EvaSplitDraft(
            parentTaskID: item.taskID,
            children: validSplitTitles(state).map { EvaSplitDraftChild(title: $0) },
            childDuePreset: state.duePreset,
            createStatus: .creating,
            createdChildIDs: []
        )

        onCreateSplit(item.taskID, draft) { result in
            Task { @MainActor in
                var updated = splitStateByTaskID[item.taskID] ?? state
                updated.isCreating = false
                switch result {
                case .success(let createdChildren):
                    let createdIDs = createdChildren.map(\.id)
                    updated.completed = true
                    updated.createdChildIDs = createdIDs
                    updated.errorMessage = nil
                    splitStateByTaskID[item.taskID] = updated
                    snackbar = SnackbarData(
                        message: "Split created (\(createdIDs.count))",
                        actions: [
                            SnackbarAction(title: "Undo") {
                                onUndoSplit(createdIDs) { undoResult in
                                    Task { @MainActor in
                                        switch undoResult {
                                        case .success:
                                            var reset = splitStateByTaskID[item.taskID] ?? updated
                                            reset.completed = false
                                            reset.createdChildIDs = []
                                            splitStateByTaskID[item.taskID] = reset
                                        case .failure(let error):
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        ]
                    )
                    LifeBoardFeedback.success()
                case .failure(let error):
                    updated.errorMessage = error.localizedDescription
                    splitStateByTaskID[item.taskID] = updated
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func validSplitTitles(_ state: EvaRescueSplitComposerState) -> [String] {
        state.childTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func runApply(mutations: [EvaBatchMutationInstruction]) {
        guard mutations.isEmpty == false else {
            errorMessage = "No rescue changes selected."
            return
        }
        isApplying = true
        errorMessage = nil
        onTrack("rescue_apply_tap", ["mutation_count": mutations.count])
        onApply(mutations) { result in
            Task { @MainActor in
                isApplying = false
                switch result {
                case .success:
                    snackbar = SnackbarData(
                        message: "Rescue plan applied",
                        actions: [
                            SnackbarAction(title: "Undo") {
                                onUndo { undoResult in
                                    Task { @MainActor in
                                        switch undoResult {
                                        case .success:
                                            snackbar = SnackbarData(message: "Rescue plan undone")
                                        case .failure(let error):
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        ]
                    )
                    LifeBoardFeedback.success()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func initializeDefaults() {
        guard let plan else { return }
        var defaults: [UUID: EvaRescueActionType] = [:]
        for item in plan.doToday { defaults[item.taskID] = .doToday }
        for item in plan.move { defaults[item.taskID] = .move }
        for item in plan.split { defaults[item.taskID] = .split }
        for item in plan.dropCandidate { defaults[item.taskID] = .dropCandidate }
        selectedActionByTaskID = defaults

        for item in plan.move {
            moveChoiceByTaskID[item.taskID] = .tomorrow
            if let toDate = item.toDate {
                customMoveDateByTaskID[item.taskID] = toDate
            }
        }
    }

    private func actionTitle(for action: EvaRescueActionType) -> String {
        switch action {
        case .doToday: return "Today"
        case .move: return "Move"
        case .split: return "Split"
        case .dropCandidate: return "Drop"
        }
    }

    private func confidenceText(for confidence: Double) -> String {
        switch confidence {
        case 0.75...:
            return "High"
        case 0.45..<0.75:
            return "Medium"
        default:
            return "Low"
        }
    }

    private func buildMutations(plan: EvaRescuePlan) -> [EvaBatchMutationInstruction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate

        return recommendations.compactMap { item in
            let selected = selectedActionByTaskID[item.taskID] ?? item.action
            switch selected {
            case .doToday:
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: today)
            case .move:
                let choice = moveChoiceByTaskID[item.taskID] ?? .tomorrow
                let dueDate: Date?
                switch choice {
                case .tomorrow:
                    dueDate = calendar.date(byAdding: .day, value: 1, to: today)
                case .weekend:
                    dueDate = EvaTriageDeferPreset.weekendSaturday.resolveDueDate()
                case .custom:
                    dueDate = customMoveDateByTaskID[item.taskID] ?? item.toDate ?? calendar.date(byAdding: .day, value: 1, to: today)
                }
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: dueDate)
            case .dropCandidate:
                return EvaBatchMutationInstruction(
                    taskID: item.taskID,
                    projectID: ProjectConstants.inboxProjectID,
                    clearDueDate: true
                )
            case .split:
                return nil
            }
        }
    }

    private func hasDropSelection(plan: EvaRescuePlan) -> Bool {
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate
        return recommendations.contains { item in
            (selectedActionByTaskID[item.taskID] ?? item.action) == .dropCandidate
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

struct LifeBoardProgressBar: View {
    let progress: Double
    let colors: [Color]
    var trackColor: Color = Color.lifeboard.surfaceSecondary
    var height: CGFloat = 6
    var animate: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(trackColor)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: clampedProgress, y: 1, anchor: .leading)
                    .animation(animate ? .spring(response: 0.34, dampingFraction: 0.82) : .linear(duration: 0.01), value: clampedProgress)
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}
