//
//  HomeForedropView.swift
//  Tasker
//
//  New SwiftUI Home shell with backdrop/foredrop pattern.
//

import SwiftUI
import UIKit

// MARK: - Foredrop Anchor

enum ForedropAnchor: Equatable {
    /// Foredrop covers calendar + charts. Default state.
    case collapsed
    /// Foredrop anchors below the weekly calendar strip.
    case midReveal
    /// Foredrop anchors below the chart cards (full analytics view).
    case fullReveal
}

// MARK: - Eva Sheets

private struct EvaFocusWhySheetView: View {
    let focusTasks: [TaskDefinition]
    let insightProvider: (UUID) -> EvaFocusTaskInsight?

    var body: some View {
        NavigationView {
            List {
                ForEach(focusTasks, id: \.id) { task in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundColor(Color.tasker.textPrimary)
                        let rationale = insightProvider(task.id)?.rationale ?? []
                        if rationale.isEmpty {
                            Text("Eva selected this using urgency and effort balance.")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)
                        } else {
                            ForEach(rationale, id: \.factor) { reason in
                                Text("• \(reason.label)")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Why Eva Picked These")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct EvaTriageSprintSheetView: View {
    let queue: [EvaTriageQueueItem]
    let projectsByID: [UUID: Project]
    let onApplySuggestion: (EvaTriageQueueItem, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    let onApplyAll: (@escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onSkip: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onEdit: (UUID) -> Void

    @State private var currentIndex: Int = 0
    @State private var isApplying = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var currentItem: EvaTriageQueueItem? {
        guard queue.isEmpty == false else { return nil }
        let clamped = min(max(0, currentIndex), queue.count - 1)
        return queue[clamped]
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Triage Sprint")
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textPrimary)

                if let currentItem {
                    Text("Card \(min(currentIndex + 1, queue.count))/\(queue.count)")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(currentItem.task.title)
                            .font(.tasker(.headline))
                            .foregroundColor(Color.tasker.textPrimary)
                            .lineLimit(3)

                        suggestionRow(title: "Project", value: projectText(for: currentItem))
                        suggestionRow(title: "Due", value: dueText(for: currentItem))
                        suggestionRow(title: "Duration", value: durationText(for: currentItem))
                        if let stateHint = currentItem.suggestions.stateHint {
                            suggestionRow(title: "State", value: stateHint.capitalized)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.tasker.surfaceSecondary)
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.statusDanger)
                    }

                    HStack(spacing: 10) {
                        Button("Accept") {
                            isApplying = true
                            onApplySuggestion(currentItem) { result in
                                DispatchQueue.main.async {
                                    isApplying = false
                                    switch result {
                                    case .success:
                                        errorMessage = nil
                                        currentIndex = min(currentIndex, max(queue.count - 2, 0))
                                    case .failure(let error):
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isApplying)

                        Button("Edit") {
                            onEdit(currentItem.task.id)
                        }
                        .buttonStyle(.bordered)

                        Button("Skip") {
                            onSkip(currentItem.task.id)
                            currentIndex = min(currentIndex, max(queue.count - 2, 0))
                        }
                        .buttonStyle(.bordered)

                        Button("Delete") {
                            showDeleteConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.tasker.statusDanger)
                    }

                    if queue.count > 1 {
                        Button("Apply all high confidence") {
                            isApplying = true
                            onApplyAll { result in
                                DispatchQueue.main.async {
                                    isApplying = false
                                    switch result {
                                    case .success:
                                        errorMessage = nil
                                        dismiss()
                                    case .failure(let error):
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isApplying)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You're all triaged.")
                            .font(.tasker(.headline))
                            .foregroundColor(Color.tasker.textPrimary)
                        Text("Inbox is clear for now.")
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textSecondary)
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Start triage")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete task?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    guard let currentItem else { return }
                    onDelete(currentItem.task.id)
                    currentIndex = min(currentIndex, max(queue.count - 2, 0))
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func suggestionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
            Spacer()
            Text(value)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
        }
    }

    private func projectText(for item: EvaTriageQueueItem) -> String {
        guard let projectID = item.suggestions.projectID else { return "No suggestion" }
        return projectsByID[projectID]?.name ?? "Suggested project"
    }

    private func dueText(for item: EvaTriageQueueItem) -> String {
        switch item.suggestions.dueBucket {
        case .today:
            return "Today"
        case .tomorrow:
            return "Tomorrow"
        case .thisWeek:
            return "This Week"
        case .someday:
            return "Someday"
        case .none:
            return "No suggestion"
        }
    }

    private func durationText(for item: EvaTriageQueueItem) -> String {
        guard let duration = item.suggestions.durationSeconds else { return "No suggestion" }
        let minutes = Int(round(duration / 60))
        if minutes >= 60 {
            if minutes % 60 == 0 {
                return "\(minutes / 60)h"
            }
            return String(format: "%.1fh", Double(minutes) / 60.0)
        }
        return "\(minutes)m"
    }
}

private struct EvaOverdueRescueSheetView: View {
    let plan: EvaRescuePlan?
    let tasksByID: [UUID: TaskDefinition]
    let lastBatchRunID: UUID?
    let onApply: ([EvaBatchMutationInstruction]) -> Void
    let onUndo: () -> Void
    let onSplitTask: (UUID) -> Void

    @State private var selectedActionByTaskID: [UUID: EvaRescueActionType] = [:]
    @State private var showDropConfirm = false
    @State private var pendingMutations: [EvaBatchMutationInstruction] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                if let plan {
                    HStack {
                        Text("Debt: \(plan.debtLevel.rawValue.capitalized)")
                            .font(.tasker(.headline))
                        Spacer()
                        Text(String(format: "%.1f", plan.debtScore))
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            rescueRows(title: "Do today", items: plan.doToday)
                            rescueRows(title: "Move", items: plan.move)
                            rescueRows(title: "Split", items: plan.split)
                            rescueRows(title: "Drop?", items: plan.dropCandidate)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Apply plan") {
                            let mutations = buildMutations(plan: plan)
                            if hasDropSelection(plan: plan) {
                                pendingMutations = mutations
                                showDropConfirm = true
                            } else {
                                onApply(mutations)
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        if lastBatchRunID != nil {
                            Button("Undo last apply") {
                                onUndo()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Text("No overdue tasks to rescue.")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .navigationTitle("Rescue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let plan else { return }
                var defaults: [UUID: EvaRescueActionType] = [:]
                for item in plan.doToday { defaults[item.taskID] = .doToday }
                for item in plan.move { defaults[item.taskID] = .move }
                for item in plan.split { defaults[item.taskID] = .split }
                for item in plan.dropCandidate { defaults[item.taskID] = .dropCandidate }
                selectedActionByTaskID = defaults
            }
            .alert("Move selected tasks to Inbox?", isPresented: $showDropConfirm) {
                Button("Apply", role: .destructive) {
                    onApply(pendingMutations)
                    pendingMutations = []
                    dismiss()
                }
                Button("Cancel", role: .cancel) {
                    pendingMutations = []
                }
            } message: {
                Text("Tasks marked Drop? will move to Inbox and have their due date cleared.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func rescueRows(title: String, items: [EvaRescueRecommendation]) -> some View {
        if items.isEmpty == false {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            ForEach(items, id: \.taskID) { item in
                HStack(spacing: 8) {
                    Text(tasksByID[item.taskID]?.title ?? "Task")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    Menu {
                        Button("Do today") { selectedActionByTaskID[item.taskID] = .doToday }
                        Button("Move") { selectedActionByTaskID[item.taskID] = .move }
                        Button("Split") { selectedActionByTaskID[item.taskID] = .split }
                        Button("Drop?") { selectedActionByTaskID[item.taskID] = .dropCandidate }
                    } label: {
                        Text(actionTitle(for: selectedActionByTaskID[item.taskID] ?? item.action))
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.accentPrimary)
                    }
                    .frame(minHeight: 44)
                }
                .padding(.vertical, 6)
                if (selectedActionByTaskID[item.taskID] ?? item.action) == .split {
                    Button("Open split helper") {
                        onSplitTask(item.taskID)
                    }
                    .buttonStyle(.plain)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                }
            }
        }
    }

    private func actionTitle(for action: EvaRescueActionType) -> String {
        switch action {
        case .doToday: return "Do today"
        case .move: return "Move"
        case .split: return "Split"
        case .dropCandidate: return "Drop?"
        }
    }

    private func buildMutations(plan: EvaRescuePlan) -> [EvaBatchMutationInstruction] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate

        return recommendations.compactMap { item in
            let selected = selectedActionByTaskID[item.taskID] ?? item.action
            switch selected {
            case .doToday:
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: today)
            case .move:
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: item.toDate ?? tomorrow)
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

private struct EvaTriageCardDraftState: Equatable {
    var useSuggestedProject: Bool
    var useSuggestedDue: Bool
    var useSuggestedDuration: Bool
    var useSuggestedState: Bool
    var selectedProjectID: UUID?
    var selectedDueBucket: EvaDueBucket?
    var customDueDate: Date?
    var clearDueDate: Bool
    var selectedDurationSeconds: TimeInterval?
    var clearDuration: Bool
    var stateHint: String?
    var deferPreset: EvaTriageDeferPreset?

    init(item: EvaTriageQueueItem) {
        self.useSuggestedProject = item.suggestions.projectID != nil
        self.useSuggestedDue = item.suggestions.dueBucket != nil
        self.useSuggestedDuration = item.suggestions.durationSeconds != nil
        self.useSuggestedState = item.suggestions.stateHint != nil
        self.selectedProjectID = nil
        self.selectedDueBucket = nil
        self.customDueDate = nil
        self.clearDueDate = false
        self.selectedDurationSeconds = nil
        self.clearDuration = false
        self.stateHint = item.suggestions.stateHint
        self.deferPreset = nil
    }
}

private struct EvaTriageSprintSheetV2: View {
    let queue: [EvaTriageQueueItem]
    let projectsByID: [UUID: Project]
    let activeScope: EvaTriageScope
    let isLoadingScope: Bool
    let queueErrorMessage: String?
    let lastBatchRunID: UUID?
    let onScopeChange: (EvaTriageScope, @escaping (Result<Void, Error>) -> Void) -> Void
    let onApplyDecision: (EvaTriageQueueItem, EvaTriageDecision, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    let onApplyAll: (@escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onUndoBulkApply: ((@escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void)?
    let onSkip: (UUID) -> Void
    let onDelete: (UUID, @escaping (Result<Void, Error>) -> Void) -> Void
    let onTrack: (String, [String: Any]) -> Void

    @State private var currentIndex: Int = 0
    @State private var selectedScope: EvaTriageScope = .visible
    @State private var draftByTaskID: [UUID: EvaTriageCardDraftState] = [:]
    @State private var isChangingScope = false
    @State private var isApplying = false
    @State private var isUndoingBulk = false
    @State private var showDeleteConfirm = false
    @State private var showBulkConfirm = false
    @State private var showEditFields = false
    @State private var errorMessage: String?
    @State private var acceptedCount = 0
    @State private var deferredCount = 0
    @State private var skippedCount = 0
    @State private var deletedCount = 0
    @State private var snackbar: SnackbarData?
    @Environment(\.dismiss) private var dismiss

    private let durationPresets: [TimeInterval] = [15 * 60, 30 * 60, 60 * 60, 2 * 60 * 60, 4 * 60 * 60]
    private let suggestionThreshold: Double = 0.45

    private var currentItem: EvaTriageQueueItem? {
        guard queue.isEmpty == false else { return nil }
        let clamped = min(max(0, currentIndex), queue.count - 1)
        return queue[clamped]
    }

    private var currentDraft: EvaTriageCardDraftState? {
        guard let currentItem else { return nil }
        return draftByTaskID[currentItem.task.id] ?? EvaTriageCardDraftState(item: currentItem)
    }

    private var isBusy: Bool {
        isApplying || isChangingScope || isLoadingScope || isUndoingBulk
    }

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    HStack(spacing: spacing.s8) {
                        Text("Triage Sprint")
                            .font(.tasker(.title3))
                            .foregroundColor(Color.tasker.textPrimary)
                        Text("\(queue.count)")
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.textSecondary)
                            .padding(.horizontal, spacing.s8)
                            .padding(.vertical, spacing.s4)
                            .background(Color.tasker.surfaceSecondary)
                            .clipShape(Capsule())
                        Spacer()
                    }

                    triageScopeToggle

                    if let queueErrorMessage {
                        Text(queueErrorMessage)
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.statusDanger)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: spacing.s16) {
                        if isBusy && queue.isEmpty {
                            ProgressView("Loading triage queue...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, spacing.s20)
                        } else if let currentItem, let draft = currentDraft {
                            // 6F: Progress indicator
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                Text("Card \(min(currentIndex + 1, queue.count)) of \(queue.count)")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                                    .contentTransition(.numericText())
                                    .animation(TaskerAnimation.snappy, value: currentIndex)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.tasker.surfaceSecondary)
                                            .frame(height: 4)
                                        Capsule()
                                            .fill(Color.tasker.accentPrimary)
                                            .frame(
                                                width: geo.size.width * CGFloat(min(currentIndex + 1, queue.count)) / CGFloat(max(queue.count, 1)),
                                                height: 4
                                            )
                                            .animation(TaskerAnimation.snappy, value: currentIndex)
                                    }
                                }
                                .frame(height: 4)
                            }
                            .enhancedStaggeredAppearance(index: 0)

                            // 6B: Task card with priority stripe
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(priorityColor(for: currentItem.task.priority))
                                    .frame(width: 4)
                                    .padding(.vertical, spacing.s8)

                                VStack(alignment: .leading, spacing: spacing.s8) {
                                    Text(currentItem.task.title)
                                        .font(.tasker(.title3))
                                        .foregroundColor(Color.tasker.textPrimary)
                                        .lineLimit(3)
                                    Text(contextLine(for: currentItem.task))
                                        .font(.tasker(.caption1))
                                        .foregroundColor(Color.tasker.textSecondary)
                                }
                                .padding(spacing.s16)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: corner.r2)
                                    .fill(Color.tasker.surfacePrimary)
                            )
                            .taskerElevation(.e2, cornerRadius: corner.r2)
                            .id(currentItem.task.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .enhancedStaggeredAppearance(index: 0)

                            // 6C: Suggestion rows
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                suggestionRow(
                                    title: "Project",
                                    icon: "folder",
                                    value: projectText(for: currentItem, draft: draft),
                                    confidence: currentItem.suggestions.projectID == nil ? nil : currentItem.suggestions.projectConfidence
                                )
                                suggestionRow(
                                    title: "Due",
                                    icon: "calendar",
                                    value: dueText(for: currentItem, draft: draft),
                                    confidence: currentItem.suggestions.dueBucket == nil ? nil : currentItem.suggestions.dueConfidence
                                )
                                suggestionRow(
                                    title: "Duration",
                                    icon: "clock",
                                    value: durationText(for: currentItem, draft: draft),
                                    confidence: currentItem.suggestions.durationSeconds == nil ? nil : currentItem.suggestions.durationConfidence
                                )
                                suggestionRow(
                                    title: "State",
                                    icon: "flag",
                                    value: stateText(for: currentItem, draft: draft),
                                    confidence: currentItem.suggestions.stateHint == nil ? nil : 0.65
                                )
                            }
                            .padding(spacing.s16)
                            .background(
                                RoundedRectangle(cornerRadius: corner.r2)
                                    .fill(Color.tasker.surfaceSecondary)
                            )
                            .taskerElevation(.e1, cornerRadius: corner.r2)
                            .enhancedStaggeredAppearance(index: 1)

                            // 6D: Quick defer chips
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                Text("Quick defer")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                                HStack(spacing: spacing.s8) {
                                    deferChip(title: "Tomorrow", preset: .tomorrow, draft: draft, item: currentItem)
                                    deferChip(title: "72h", preset: .hours72, draft: draft, item: currentItem)
                                    deferChip(title: "Weekend", preset: .weekendSaturday, draft: draft, item: currentItem)
                                }
                            }
                            .enhancedStaggeredAppearance(index: 2)

                            if showEditFields {
                                editPanel(item: currentItem, draft: draft)
                            }

                            // 6I: Error text with transition
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.statusDanger)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            if highConfidencePreviewCount > 0 {
                                Button {
                                    showBulkConfirm = true
                                    onTrack("triage_bulk_apply_open", [
                                        "preview_count": highConfidencePreviewCount
                                    ])
                                } label: {
                                    Text("Apply all high confidence (\(highConfidencePreviewCount))")
                                        .font(.tasker(.caption1))
                                        .foregroundColor(Color.tasker.accentPrimary)
                                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: corner.r2)
                                        .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                                )
                                .disabled(isBusy)
                            }
                        } else {
                            completionSummary
                        }
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s12)
                    .padding(.bottom, spacing.s24)
                }

                if currentItem != nil {
                    Divider()
                    triageStickyActionBar
                }
            }
            .background(Color.tasker.bgCanvas)
            .navigationTitle("Start triage")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedScope = activeScope
                syncDraftsWithQueue()
            }
            .onChange(of: activeScope) { _, newValue in
                selectedScope = newValue
            }
            .onChange(of: queue.map(\.task.id)) { _, _ in
                syncDraftsWithQueue()
                if currentIndex >= queue.count {
                    currentIndex = max(queue.count - 1, 0)
                }
                if queue.isEmpty {
                    showEditFields = false
                }
            }
            .alert("Delete task?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    deleteCurrentItem()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes the task.")
            }
            .alert("Apply all high confidence?", isPresented: $showBulkConfirm) {
                Button("Apply") {
                    applyAllHighConfidence()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This applies high-confidence triage suggestions in one review-confirmed batch.")
            }
        }
        .taskerSnackbar($snackbar)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @State private var completionAppeared = false

    private var completionSummary: some View {
        VStack(spacing: spacing.s24) {
            // 6G: Celebration header
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.tasker.statusSuccess)
                .scaleEffect(completionAppeared ? 1.0 : 0.3)
                .opacity(completionAppeared ? 1.0 : 0)
                .animation(TaskerAnimation.expressive, value: completionAppeared)

            Text("Triage complete")
                .font(.tasker(.title3))
                .foregroundColor(Color.tasker.textPrimary)

            // 6G: Stats pills
            HStack(spacing: spacing.s8) {
                triageStatPill(label: "Accepted", count: acceptedCount, color: Color.tasker.statusSuccess, index: 0)
                triageStatPill(label: "Deferred", count: deferredCount, color: Color.tasker.accentPrimary, index: 1)
                triageStatPill(label: "Skipped", count: skippedCount, color: Color.tasker.textTertiary, index: 2)
                triageStatPill(label: "Deleted", count: deletedCount, color: Color.tasker.statusDanger, index: 3)
            }

            if let onUndoBulkApply, lastBatchRunID != nil {
                Button {
                    isUndoingBulk = true
                    onUndoBulkApply { result in
                        DispatchQueue.main.async {
                            isUndoingBulk = false
                            switch result {
                            case .success:
                                snackbar = SnackbarData(message: "Bulk triage undone")
                            case .failure(let error):
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Text("Undo last bulk apply")
                        .font(.tasker(.buttonSmall))
                        .foregroundColor(Color.tasker.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isUndoingBulk)
            }

            // 6G: Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.tasker(.button))
                    .foregroundColor(Color.tasker.accentOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: corner.r2))
            }
            .buttonStyle(.plain)
            .scaleOnPress()
        }
        .padding(.top, spacing.s32)
        .onAppear {
            completionAppeared = true
            TaskerFeedback.success()
        }
    }

    private func triageStatPill(label: String, count: Int, color: Color, index: Int) -> some View {
        VStack(spacing: spacing.s4) {
            Text("\(count)")
                .font(.tasker(.callout))
                .foregroundColor(color)
            Text(label)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
        }
        .padding(.horizontal, spacing.s8)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: corner.r2))
        .enhancedStaggeredAppearance(index: index)
    }

    private var triageStickyActionBar: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if let currentItem, let draft = currentDraft, !hasActionableChange(for: currentItem, draft: draft) {
                Text("Pick at least one change or a defer option to continue.")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
            }

            HStack(spacing: spacing.s8) {
                // 6E: Apply & Next - primary filled
                Button {
                    applyCurrentItem()
                } label: {
                    Text("Apply & Next")
                        .font(.tasker(.button))
                        .foregroundColor(Color.tasker.accentOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(canApplyCurrentItem ? Color.tasker.accentPrimary : Color.tasker.accentMuted)
                        .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .disabled(!canApplyCurrentItem)

                // 6E: Skip - outline
                Button {
                    skipCurrentItem()
                    TaskerFeedback.selection()
                } label: {
                    Text("Skip")
                        .font(.tasker(.buttonSmall))
                        .foregroundColor(Color.tasker.textSecondary)
                        .frame(minWidth: 56, minHeight: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .disabled(isBusy)

                // 6E: Delete - danger outline
                Button {
                    TaskerFeedback.warning()
                    showDeleteConfirm = true
                } label: {
                    Text("Delete")
                        .font(.tasker(.buttonSmall))
                        .foregroundColor(Color.tasker.statusDanger)
                        .frame(minWidth: 64, minHeight: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .stroke(Color.tasker.statusDanger.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .disabled(isBusy)
            }

            Button {
                showEditFields.toggle()
                TaskerFeedback.selection()
            } label: {
                Text(showEditFields ? "Done editing" : "Edit fields")
                    .font(.tasker(.buttonSmall))
                    .foregroundColor(Color.tasker.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: corner.r2)
                            .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s12)
        .padding(.bottom, spacing.s12)
        .background(Color.tasker.surfacePrimary)
    }

    // 6H: Custom segmented scope toggle
    private var triageScopeToggle: some View {
        HStack(spacing: 0) {
            ForEach([EvaTriageScope.visible, .allInbox], id: \.self) { scope in
                let isSelected = selectedScope == scope
                Button {
                    changeScope(to: scope)
                    TaskerFeedback.selection()
                } label: {
                    Text(scope == .allInbox ? "Backlog" : "Visible")
                        .font(.tasker(.caption1))
                        .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            isSelected
                                ? AnyView(Capsule().fill(Color.tasker.accentPrimary))
                                : AnyView(Capsule().fill(Color.clear))
                        )
                        .animation(TaskerAnimation.snappy, value: selectedScope)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
        }
        .padding(spacing.s4)
        .background(Color.tasker.surfaceSecondary)
        .clipShape(Capsule())
        .accessibilityLabel("Scope")
        .accessibilityHint("Toggle between visible inbox tasks and all inbox tasks")
    }

    private var canApplyCurrentItem: Bool {
        guard let currentItem, let draft = currentDraft else { return false }
        return !isBusy && hasActionableChange(for: currentItem, draft: draft)
    }

    private var highConfidencePreviewCount: Int {
        queue.reduce(into: 0) { partialResult, item in
            var hasChange = false
            if item.suggestions.projectConfidence >= 0.75,
               let projectID = item.suggestions.projectID,
               projectID != item.task.projectID {
                hasChange = true
            }
            if item.suggestions.dueConfidence >= 0.75 {
                switch item.suggestions.dueBucket {
                case .someday:
                    hasChange = hasChange || item.task.dueDate != nil
                case .none:
                    break
                default:
                    let suggestedDate = resolvedDueDate(for: item.suggestions.dueBucket)
                    hasChange = hasChange || item.task.dueDate != suggestedDate
                }
            }
            if item.suggestions.durationConfidence >= 0.75,
               let duration = item.suggestions.durationSeconds,
               item.task.estimatedDuration != duration {
                hasChange = true
            }
            if hasChange { partialResult += 1 }
        }
    }

    private func editPanel(item: EvaTriageQueueItem, draft: EvaTriageCardDraftState) -> some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Edit fields")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)

            if !projectsByID.isEmpty {
                Menu {
                    Button("Use suggestion") {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedProject = true
                            draft.selectedProjectID = nil
                        }
                    }
                    ForEach(projectsByID.values.sorted(by: { $0.name < $1.name }), id: \.id) { project in
                        Button(project.name) {
                            updateDraft(for: item) { draft in
                                draft.useSuggestedProject = false
                                draft.selectedProjectID = project.id
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Project")
                            .font(.tasker(.caption1))
                        Spacer()
                        Text(projectText(for: item, draft: draft))
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                    }
                    .padding(.horizontal, spacing.s12)
                    .frame(minHeight: 44)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    dueChip("Suggested", isSelected: draft.useSuggestedDue && item.suggestions.dueBucket != nil) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDue = true
                            draft.clearDueDate = false
                            draft.selectedDueBucket = nil
                            draft.customDueDate = nil
                        }
                    }
                    dueChip("Today", isSelected: !draft.useSuggestedDue && draft.selectedDueBucket == .today) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDue = false
                            draft.clearDueDate = false
                            draft.selectedDueBucket = .today
                            draft.customDueDate = nil
                        }
                    }
                    dueChip("Tomorrow", isSelected: !draft.useSuggestedDue && draft.selectedDueBucket == .tomorrow) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDue = false
                            draft.clearDueDate = false
                            draft.selectedDueBucket = .tomorrow
                            draft.customDueDate = nil
                        }
                    }
                    dueChip("This week", isSelected: !draft.useSuggestedDue && draft.selectedDueBucket == .thisWeek) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDue = false
                            draft.clearDueDate = false
                            draft.selectedDueBucket = .thisWeek
                            draft.customDueDate = nil
                        }
                    }
                    dueChip("Someday", isSelected: !draft.useSuggestedDue && draft.clearDueDate) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDue = false
                            draft.clearDueDate = true
                            draft.selectedDueBucket = nil
                            draft.customDueDate = nil
                        }
                    }
                    dueChip("Custom", isSelected: !draft.useSuggestedDue && draft.customDueDate != nil) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDue = false
                            draft.clearDueDate = false
                            draft.selectedDueBucket = nil
                            draft.customDueDate = draft.customDueDate ?? Calendar.current.startOfDay(for: Date())
                        }
                    }
                }
            }

            if !draft.useSuggestedDue, let customDate = draft.customDueDate {
                DatePicker(
                    "Custom due date",
                    selection: Binding(
                        get: { customDate },
                        set: { newValue in
                            updateDraft(for: item) { draft in
                                draft.customDueDate = Calendar.current.startOfDay(for: newValue)
                            }
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(.tasker(.caption1))
                .frame(minHeight: 44)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    durationChip("Suggested", isSelected: draft.useSuggestedDuration && item.suggestions.durationSeconds != nil) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDuration = true
                            draft.selectedDurationSeconds = nil
                            draft.clearDuration = false
                        }
                    }
                    ForEach(durationPresets, id: \.self) { preset in
                        durationChip(durationLabel(for: preset), isSelected: !draft.useSuggestedDuration && draft.selectedDurationSeconds == preset) {
                            updateDraft(for: item) { draft in
                                draft.useSuggestedDuration = false
                                draft.selectedDurationSeconds = preset
                                draft.clearDuration = false
                            }
                        }
                    }
                    durationChip("None", isSelected: !draft.useSuggestedDuration && draft.clearDuration) {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedDuration = false
                            draft.selectedDurationSeconds = nil
                            draft.clearDuration = true
                        }
                    }
                }
            }

            if item.suggestions.stateHint != nil {
                Menu {
                    Button("Use suggestion") {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedState = true
                            draft.stateHint = item.suggestions.stateHint
                        }
                    }
                    Button("Blocked") {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedState = false
                            draft.stateHint = "blocked"
                        }
                    }
                    Button("Waiting") {
                        updateDraft(for: item) { draft in
                            draft.useSuggestedState = false
                            draft.stateHint = "waiting"
                        }
                    }
                } label: {
                    HStack {
                        Text("State")
                            .font(.tasker(.caption1))
                        Spacer()
                        Text(stateText(for: item, draft: draft))
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                    }
                    .padding(.horizontal, spacing.s12)
                    .frame(minHeight: 44)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.surfaceSecondary)
        )
        .taskerElevation(.e1, cornerRadius: corner.r2)
    }

    private func changeScope(to nextScope: EvaTriageScope) {
        guard selectedScope != nextScope else { return }
        selectedScope = nextScope
        isChangingScope = true
        errorMessage = nil
        onTrack("triage_scope_changed", [
            "scope": nextScope.rawValue
        ])
        onScopeChange(nextScope) { result in
            DispatchQueue.main.async {
                isChangingScope = false
                switch result {
                case .success:
                    break
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func applyCurrentItem() {
        guard let currentItem, let draft = currentDraft else { return }
        guard hasActionableChange(for: currentItem, draft: draft) else {
            errorMessage = "Pick at least one change or defer option."
            return
        }

        let decision = EvaTriageDecision(
            selectedProjectID: draft.selectedProjectID,
            useSuggestedProject: draft.useSuggestedProject,
            selectedDueDate: draft.customDueDate,
            clearDueDate: draft.clearDueDate,
            useSuggestedDue: draft.useSuggestedDue,
            selectedDurationSeconds: draft.selectedDurationSeconds,
            clearDuration: draft.clearDuration,
            useSuggestedDuration: draft.useSuggestedDuration,
            stateHint: draft.stateHint,
            useSuggestedState: draft.useSuggestedState,
            deferPreset: draft.deferPreset
        )

        isApplying = true
        onTrack("triage_apply_next", [
            "task_id": currentItem.task.id.uuidString,
            "defer": draft.deferPreset?.rawValue ?? "none"
        ])
        onApplyDecision(currentItem, decision) { result in
            DispatchQueue.main.async {
                isApplying = false
                switch result {
                case .success:
                    errorMessage = nil
                    if draft.deferPreset != nil {
                        deferredCount += 1
                    } else {
                        acceptedCount += 1
                    }
                    TaskerFeedback.success()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func skipCurrentItem() {
        guard let currentItem else { return }
        onSkip(currentItem.task.id)
        skippedCount += 1
        onTrack("triage_skip", ["task_id": currentItem.task.id.uuidString])
        TaskerFeedback.selection()
    }

    private func deleteCurrentItem() {
        guard let currentItem else { return }
        isApplying = true
        onDelete(currentItem.task.id) { result in
            DispatchQueue.main.async {
                isApplying = false
                switch result {
                case .success:
                    deletedCount += 1
                    errorMessage = nil
                    onTrack("triage_delete_confirmed", ["task_id": currentItem.task.id.uuidString])
                    TaskerFeedback.medium()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func applyAllHighConfidence() {
        isApplying = true
        onApplyAll { result in
            DispatchQueue.main.async {
                isApplying = false
                switch result {
                case .success:
                    errorMessage = nil
                    snackbar = SnackbarData(message: "High-confidence updates applied")
                    onTrack("triage_bulk_apply_confirmed", [
                        "preview_count": highConfidencePreviewCount
                    ])
                    TaskerFeedback.success()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    onTrack("triage_error", [
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }

    private func updateDraft(for item: EvaTriageQueueItem, mutate: (inout EvaTriageCardDraftState) -> Void) {
        var draft = draftByTaskID[item.task.id] ?? EvaTriageCardDraftState(item: item)
        mutate(&draft)
        draftByTaskID[item.task.id] = draft
    }

    private func syncDraftsWithQueue() {
        let queueIDs = Set(queue.map(\.task.id))
        draftByTaskID = draftByTaskID.filter { queueIDs.contains($0.key) }
        for item in queue where draftByTaskID[item.task.id] == nil {
            draftByTaskID[item.task.id] = EvaTriageCardDraftState(item: item)
        }
    }

    private func hasActionableChange(for item: EvaTriageQueueItem, draft: EvaTriageCardDraftState) -> Bool {
        if let preset = draft.deferPreset {
            let dueDate = preset.resolveDueDate()
            if item.task.dueDate != dueDate {
                return true
            }
        }

        if draft.useSuggestedProject,
           item.suggestions.projectConfidence >= suggestionThreshold,
           let projectID = item.suggestions.projectID,
           projectID != item.task.projectID {
            return true
        }
        if !draft.useSuggestedProject,
           let selectedProjectID = draft.selectedProjectID,
           selectedProjectID != item.task.projectID {
            return true
        }

        if draft.deferPreset == nil {
            if draft.useSuggestedDue, item.suggestions.dueConfidence >= suggestionThreshold {
                switch item.suggestions.dueBucket {
                case .someday:
                    if item.task.dueDate != nil { return true }
                case .none:
                    break
                default:
                    let dueDate = resolvedDueDate(for: item.suggestions.dueBucket)
                    if item.task.dueDate != dueDate { return true }
                }
            } else if !draft.useSuggestedDue {
                if draft.clearDueDate {
                    if item.task.dueDate != nil { return true }
                } else if let customDate = draft.customDueDate, item.task.dueDate != customDate {
                    return true
                } else if let dueBucket = draft.selectedDueBucket {
                    let dueDate = resolvedDueDate(for: dueBucket)
                    if item.task.dueDate != dueDate { return true }
                }
            }
        }

        if draft.useSuggestedDuration,
           item.suggestions.durationConfidence >= suggestionThreshold,
           let suggestedDuration = item.suggestions.durationSeconds,
           item.task.estimatedDuration != suggestedDuration {
            return true
        }
        if !draft.useSuggestedDuration {
            if draft.clearDuration {
                if item.task.estimatedDuration != nil { return true }
            } else if let selectedDuration = draft.selectedDurationSeconds,
                      item.task.estimatedDuration != selectedDuration {
                return true
            }
        }

        return false
    }

    private func suggestionRow(title: String, icon: String, value: String, confidence: Double?) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color.tasker.textTertiary)
                .frame(width: 20)
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
            Spacer()
            if let confidence {
                Text(confidenceLabel(confidence) ?? "")
                    .font(.tasker(.caption2))
                    .foregroundColor(confidenceBadgeTextColor(confidence))
                    .padding(.horizontal, spacing.s8)
                    .padding(.vertical, spacing.s4)
                    .background(confidenceBadgeColor(confidence))
                    .clipShape(Capsule())
                    .accessibilityLabel("\(title) confidence \(confidenceLabel(confidence) ?? "")")
            }
            Text(value)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textPrimary)
        }
        .frame(minHeight: 28)
    }

    private func confidenceBadgeColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.tasker.statusSuccess.opacity(0.15)
        case 0.45..<0.75: return Color.tasker.statusWarning.opacity(0.15)
        default: return Color.tasker.textTertiary.opacity(0.12)
        }
    }

    private func confidenceBadgeTextColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.tasker.statusSuccess
        case 0.45..<0.75: return Color.tasker.statusWarning
        default: return Color.tasker.textTertiary
        }
    }

    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .max: return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low: return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone
        }
    }

    private func deferChip(title: String, preset: EvaTriageDeferPreset, draft: EvaTriageCardDraftState, item: EvaTriageQueueItem) -> some View {
        let isSelected = draft.deferPreset == preset
        return Button {
            withAnimation(TaskerAnimation.quick) {
                updateDraft(for: item) { draft in
                    draft.deferPreset = (draft.deferPreset == preset) ? nil : preset
                }
            }
            onTrack("triage_defer_selected", [
                "preset": preset.rawValue,
                "task_id": item.task.id.uuidString
            ])
            TaskerFeedback.selection()
        } label: {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .frame(minHeight: spacing.buttonHeight)
                .background(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func dueChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(TaskerAnimation.quick) { action() }
            TaskerFeedback.selection()
        } label: {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .frame(minHeight: 36)
                .background(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private func durationChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(TaskerAnimation.quick) { action() }
            TaskerFeedback.selection()
        } label: {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .frame(minHeight: 36)
                .background(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private func projectText(for item: EvaTriageQueueItem, draft: EvaTriageCardDraftState) -> String {
        if !draft.useSuggestedProject, let selectedProjectID = draft.selectedProjectID {
            return projectsByID[selectedProjectID]?.name ?? "Project"
        }
        if draft.useSuggestedProject, let suggestionID = item.suggestions.projectID {
            return projectsByID[suggestionID]?.name ?? "Suggested project"
        }
        return "No suggestion"
    }

    private func dueText(for item: EvaTriageQueueItem, draft: EvaTriageCardDraftState) -> String {
        if let preset = draft.deferPreset {
            switch preset {
            case .tomorrow: return "Tomorrow"
            case .hours72: return "72h"
            case .weekendSaturday: return "Weekend"
            }
        }
        if !draft.useSuggestedDue {
            if draft.clearDueDate { return "Someday" }
            if let customDueDate = draft.customDueDate {
                return shortDate(customDueDate)
            }
            if let dueBucket = draft.selectedDueBucket {
                return dueBucketText(dueBucket)
            }
        }
        if draft.useSuggestedDue, let dueBucket = item.suggestions.dueBucket {
            return dueBucketText(dueBucket)
        }
        return "No suggestion"
    }

    private func durationText(for item: EvaTriageQueueItem, draft: EvaTriageCardDraftState) -> String {
        if !draft.useSuggestedDuration {
            if draft.clearDuration { return "None" }
            if let duration = draft.selectedDurationSeconds {
                return durationLabel(for: duration)
            }
        }
        if draft.useSuggestedDuration, let duration = item.suggestions.durationSeconds {
            return durationLabel(for: duration)
        }
        return "No suggestion"
    }

    private func stateText(for item: EvaTriageQueueItem, draft: EvaTriageCardDraftState) -> String {
        if !draft.useSuggestedState, let stateHint = draft.stateHint {
            return stateHint.capitalized
        }
        if draft.useSuggestedState, let stateHint = item.suggestions.stateHint {
            return stateHint.capitalized
        }
        return "No suggestion"
    }

    private func confidenceLabel(_ value: Double?) -> String? {
        guard let value else { return nil }
        switch value {
        case 0.75...:
            return "High"
        case 0.45..<0.75:
            return "Medium"
        default:
            return "Low"
        }
    }

    private func durationLabel(for duration: TimeInterval) -> String {
        let minutes = Int(round(duration / 60))
        if minutes >= 60 {
            if minutes % 60 == 0 {
                return "\(minutes / 60)h"
            }
            return String(format: "%.1fh", Double(minutes) / 60.0)
        }
        return "\(minutes)m"
    }

    private func dueBucketText(_ bucket: EvaDueBucket) -> String {
        switch bucket {
        case .today:
            return "Today"
        case .tomorrow:
            return "Tomorrow"
        case .thisWeek:
            return "This Week"
        case .someday:
            return "Someday"
        }
    }

    private func resolvedDueDate(for bucket: EvaDueBucket?) -> Date? {
        guard let bucket else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch bucket {
        case .today:
            return today
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today)
        case .thisWeek:
            let daysUntilEndOfWeek = 7 - calendar.component(.weekday, from: today)
            return calendar.date(byAdding: .day, value: max(daysUntilEndOfWeek, 2), to: today)
        case .someday:
            return nil
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func contextLine(for task: TaskDefinition) -> String {
        let calendar = Calendar.current
        let createdDays = max(0, calendar.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0)
        if let dueDate = task.dueDate {
            return "Created \(createdDays)d ago • Due \(shortDate(dueDate))"
        }
        return "Created \(createdDays)d ago • No due date"
    }
}

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

private struct EvaRescueSplitComposerState {
    var isOpen = false
    var childTitles: [String] = ["", ""]
    var duePreset: EvaTriageDeferPreset?
    var isCreating = false
    var errorMessage: String?
    var completed = false
    var createdChildIDs: [UUID] = []
}

private struct EvaOverdueRescueSheetV2: View {
    let plan: EvaRescuePlan?
    let tasksByID: [UUID: TaskDefinition]
    let lastBatchRunID: UUID?
    let onApply: ([EvaBatchMutationInstruction], @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onUndo: (@escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onCreateSplit: (UUID, EvaSplitDraft, @escaping (Result<[TaskDefinition], Error>) -> Void) -> Void
    let onUndoSplit: ([UUID], @escaping (Result<Void, Error>) -> Void) -> Void
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

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private var allRecommendations: [EvaRescueRecommendation] {
        guard let plan else { return [] }
        return plan.doToday + plan.move + plan.split + plan.dropCandidate
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let plan {
                    // 7B: Debt level header
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        HStack {
                            Text("Debt: \(plan.debtLevel.rawValue.capitalized)")
                                .font(.tasker(.title3))
                                .foregroundColor(debtLevelColor(plan.debtLevel))
                            Spacer()
                            Text("\(allRecommendations.count)")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)
                                .contentTransition(.numericText())
                                .padding(.horizontal, spacing.s8)
                                .padding(.vertical, spacing.s4)
                                .background(Color.tasker.surfaceSecondary)
                                .clipShape(Capsule())
                            Text("overdue")
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.textTertiary)
                        }

                        // 7B: Debt progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.tasker.surfaceSecondary)
                                    .frame(height: 6)
                                Capsule()
                                    .fill(debtLevelColor(plan.debtLevel))
                                    .frame(width: geo.size.width * min(plan.debtScore / 100.0, 1.0), height: 6)
                                    .animation(TaskerAnimation.snappy, value: plan.debtScore)
                            }
                        }
                        .frame(height: 6)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.statusDanger)
                        }
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s12)
                    .enhancedStaggeredAppearance(index: 0)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            rescueGroup(title: "Do today", icon: "flame.fill", iconColor: Color.tasker.statusWarning, items: plan.doToday, startIndex: 0)
                            rescueGroup(title: "Move", icon: "calendar.badge.clock", iconColor: Color.tasker.accentPrimary, items: plan.move, startIndex: plan.doToday.count)
                            rescueGroup(title: "Split", icon: "scissors", iconColor: Color.tasker.priorityHigh, items: plan.split, startIndex: plan.doToday.count + plan.move.count)
                            rescueGroup(title: "Drop?", icon: "trash", iconColor: Color.tasker.statusDanger, items: plan.dropCandidate, startIndex: plan.doToday.count + plan.move.count + plan.split.count)
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
                            .foregroundColor(Color.tasker.statusSuccess)
                            .breathingPulse(min: 0.7, max: 1.0, duration: 2.0)
                            .scaleEffect(emptyStateAppeared ? 1.0 : 0.3)
                            .animation(TaskerAnimation.expressive, value: emptyStateAppeared)
                        Text("All caught up!")
                            .font(.tasker(.title3))
                            .foregroundColor(Color.tasker.textPrimary)
                            .opacity(emptyStateAppeared ? 1.0 : 0)
                            .animation(TaskerAnimation.expressive.delay(0.1), value: emptyStateAppeared)
                        Text("No overdue tasks to rescue.")
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(spacing.s16)
                    .onAppear { emptyStateAppeared = true }
                }
            }
            .background(Color.tasker.bgCanvas)
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
        .taskerSnackbar($snackbar)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func debtLevelColor(_ level: EvaDebtLevel) -> Color {
        switch level {
        case .none: return Color.tasker.statusSuccess
        case .low: return Color.tasker.accentPrimary
        case .medium: return Color.tasker.statusWarning
        case .high: return Color.tasker.statusDanger
        }
    }

    private func stickyRescueActionBar(plan: EvaRescuePlan) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if buildMutations(plan: plan).isEmpty {
                Text("Select at least one Today, Move, or Drop action to apply.")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
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
                        .font(.tasker(.button))
                        .foregroundColor(Color.tasker.accentOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(
                            (isApplying || buildMutations(plan: plan).isEmpty)
                                ? Color.tasker.accentMuted
                                : Color.tasker.accentPrimary
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
                            DispatchQueue.main.async {
                                isUndoing = false
                                switch result {
                                case .success:
                                    snackbar = SnackbarData(message: "Rescue plan undone")
                                    TaskerFeedback.success()
                                case .failure(let error):
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        Text("Undo")
                            .font(.tasker(.buttonSmall))
                            .foregroundColor(Color.tasker.textSecondary)
                            .frame(minWidth: 64, minHeight: spacing.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: corner.r2)
                                    .stroke(Color.tasker.strokeHairline, lineWidth: 1)
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
        .background(Color.tasker.surfacePrimary)
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
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textPrimary)
                Text("\(items.count)")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.s8)
                    .padding(.vertical, spacing.s2)
                    .background(Color.tasker.surfaceSecondary)
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
                                .font(.tasker(.body))
                                .foregroundColor(Color.tasker.textPrimary)
                                .lineLimit(2)

                            Spacer()

                            // 7D: Confidence badge
                            Text(confidenceText(for: item.confidence))
                                .font(.tasker(.caption2))
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
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.statusDanger)
                                    .padding(.horizontal, spacing.s8)
                                    .padding(.vertical, spacing.s2)
                                    .background(Color.tasker.statusDanger.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        // 7D: Reason pills
                        if !item.reasons.isEmpty {
                            HStack(spacing: spacing.s4) {
                                ForEach(item.reasons, id: \.self) { reason in
                                    Text(reason)
                                        .font(.tasker(.caption2))
                                        .foregroundColor(Color.tasker.textTertiary)
                                        .padding(.horizontal, spacing.s8)
                                        .padding(.vertical, spacing.s2)
                                        .background(Color.tasker.surfaceSecondary)
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
                                    .foregroundColor(Color.tasker.statusSuccess)
                                Text("Split done")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.accentPrimary)
                            }
                        }
                    }
                    .padding(spacing.s12)
                }
                .background(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .fill(Color.tasker.surfacePrimary)
                )
                .taskerElevation(.e1, cornerRadius: corner.r2)
                .enhancedStaggeredAppearance(index: startIndex + index + 1)
            }
        }
    }

    private func rescuePriorityColor(for priority: TaskPriority?) -> Color {
        guard let priority else { return Color.tasker.priorityNone }
        switch priority {
        case .max: return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low: return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone
        }
    }

    private func rescueConfidenceBadgeColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.tasker.statusSuccess.opacity(0.15)
        case 0.45..<0.75: return Color.tasker.statusWarning.opacity(0.15)
        default: return Color.tasker.textTertiary.opacity(0.12)
        }
    }

    private func rescueConfidenceBadgeTextColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.tasker.statusSuccess
        case 0.45..<0.75: return Color.tasker.statusWarning
        default: return Color.tasker.textTertiary
        }
    }

    private func moveChoiceRow(for item: EvaRescueRecommendation) -> some View {
        let selectedChoice = moveChoiceByTaskID[item.taskID] ?? .tomorrow
        return VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                ForEach(EvaRescueMoveChoice.allCases, id: \.self) { choice in
                    Button {
                        withAnimation(TaskerAnimation.quick) {
                            moveChoiceByTaskID[item.taskID] = choice
                        }
                        onTrack("rescue_action_changed", [
                            "task_id": item.taskID.uuidString,
                            "action": "move_\(choice.rawValue)"
                        ])
                        TaskerFeedback.selection()
                    } label: {
                        Text(choice.title)
                            .font(.tasker(.caption2))
                            .foregroundColor(selectedChoice == choice ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                            .padding(.horizontal, spacing.s12)
                            .frame(minHeight: 36)
                            .background(selectedChoice == choice ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
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
                .background(Color.tasker.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                .tint(Color.tasker.accentPrimary)
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
                    TaskerFeedback.selection()
                } label: {
                    Text("Open split helper")
                        .font(.tasker(.buttonSmall))
                        .foregroundColor(Color.tasker.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
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
                        .font(.tasker(.caption1))
                        .padding(.horizontal, spacing.s12)
                        .frame(minHeight: 40)
                        .background(Color.tasker.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: corner.r1))
                    }

                    if state.childTitles.count < 3 {
                        Button {
                            withAnimation(TaskerAnimation.bouncy) {
                                var next = splitStateByTaskID[item.taskID] ?? state
                                next.childTitles.append("")
                                splitStateByTaskID[item.taskID] = next
                            }
                        } label: {
                            HStack(spacing: spacing.s4) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color.tasker.accentPrimary)
                                Text("Add child")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.accentPrimary)
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
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.statusDanger)
                    }

                    Button {
                        runSplitCreation(for: item, state: state)
                    } label: {
                        Text("Create subtasks")
                            .font(.tasker(.button))
                            .foregroundColor(Color.tasker.accentOnPrimary)
                            .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                            .background(
                                (state.isCreating || validSplitTitles(state).count < 2)
                                    ? Color.tasker.accentMuted
                                    : Color.tasker.accentPrimary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .disabled(state.isCreating || validSplitTitles(state).count < 2)
                }
                .padding(spacing.s12)
                .background(Color.tasker.surfaceSecondary)
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
            withAnimation(TaskerAnimation.quick) {
                var next = splitStateByTaskID[item.taskID] ?? state
                next.duePreset = preset
                splitStateByTaskID[item.taskID] = next
            }
            TaskerFeedback.selection()
        } label: {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .frame(minHeight: 36)
                .background(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
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
            withAnimation(TaskerAnimation.quick) {
                selectedActionByTaskID[item.taskID] = action
            }
            onTrack("rescue_action_changed", [
                "task_id": item.taskID.uuidString,
                "action": action.rawValue
            ])
            TaskerFeedback.selection()
        } label: {
            HStack(spacing: spacing.s4) {
                Image(systemName: rescueActionIcon(for: action))
                    .font(.system(size: 11))
                Text(actionTitle(for: action))
                    .font(.tasker(.caption2))
            }
            .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
            .padding(.horizontal, spacing.s12)
            .frame(minHeight: 36)
            .background(
                isSelected
                    ? Color.tasker.accentPrimary
                    : Color.tasker.surfaceSecondary
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.tasker.strokeHairline, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .activeGlow(isActive: isSelected, color: Color.tasker.accentPrimary)
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
            DispatchQueue.main.async {
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
                                    DispatchQueue.main.async {
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
                    TaskerFeedback.success()
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
            DispatchQueue.main.async {
                isApplying = false
                switch result {
                case .success:
                    snackbar = SnackbarData(
                        message: "Rescue plan applied",
                        actions: [
                            SnackbarAction(title: "Undo") {
                                onUndo { undoResult in
                                    DispatchQueue.main.async {
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
                    TaskerFeedback.success()
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

struct HomeForedropLayoutMetrics {
    static let midRevealBaseOffset: CGFloat = 94
    static let extraFullRevealPadding: CGFloat = 72
    static let minimumVisibleForedropHeight: CGFloat = 120
    static let minimumAnalyticsPeekAtFullReveal: CGFloat = 620

    var calendarExpandedHeight: CGFloat
    var analyticsSectionHeight: CGFloat
    var geometryHeight: CGFloat

    var midOffset: CGFloat {
        Self.midRevealBaseOffset + calendarExpandedHeight
    }

    var fullOffset: CGFloat {
        let analyticsDrivenPeek = analyticsSectionHeight + Self.extraFullRevealPadding
        let targetPeek = max(analyticsDrivenPeek, Self.minimumAnalyticsPeekAtFullReveal)
        let fullRaw = midOffset + targetPeek
        let cappedOffset = min(fullRaw, geometryHeight - Self.minimumVisibleForedropHeight)
        return max(midOffset, cappedOffset)
    }

    /// Executes offset.
    func offset(for anchor: ForedropAnchor) -> CGFloat {
        switch anchor {
        case .collapsed:
            return 0
        case .midReveal:
            return midOffset
        case .fullReveal:
            return fullOffset
        }
    }
}

struct HomeForedropHintEligibility {
    static let triggerCooldown: TimeInterval = 0.7

    /// Executes canTrigger.
    static func canTrigger(
        isHomeVisible: Bool,
        foredropAnchor: ForedropAnchor,
        reduceMotionEnabled: Bool,
        isUITesting: Bool,
        hasRunningAnimation: Bool,
        lastTriggerDate: Date?,
        now: Date = Date(),
        cooldown: TimeInterval = triggerCooldown
    ) -> Bool {
        guard isHomeVisible else { return false }
        guard foredropAnchor == .collapsed else { return false }
        guard !reduceMotionEnabled else { return false }
        guard !isUITesting else { return false }
        guard !hasRunningAnimation else { return false }
        guard let lastTriggerDate else { return true }

        return now.timeIntervalSince(lastTriggerDate) >= cooldown
    }
}

private struct CalendarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 80
    /// Executes reduce.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AnalyticsSectionHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    /// Executes reduce.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension TimeInterval {
    var nanoseconds: UInt64 {
        UInt64((self * 1_000_000_000).rounded())
    }
}

private extension ForedropAnchor {
    var accessibilityValue: String {
        switch self {
        case .collapsed:
            return "collapsed"
        case .midReveal:
            return "midReveal"
        case .fullReveal:
            return "fullReveal"
        }
    }
}

struct HomeBackdropForedropRootView: View {
    @ObservedObject var viewModel: HomeViewModel
    let chartCardViewModel: ChartCardViewModel
    let radarChartCardViewModel: RadarChartCardViewModel
    let insightsViewModel: InsightsViewModel
    @ObservedObject private var themeManager = TaskerThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let onTaskTap: (TaskDefinition) -> Void
    let onToggleComplete: (TaskDefinition) -> Void
    let onDeleteTask: (TaskDefinition) -> Void
    let onRescheduleTask: (TaskDefinition) -> Void
    let onReorderCustomProjects: ([UUID]) -> Void
    let onAddTask: () -> Void
    let onOpenSearch: () -> Void
    let onOpenChat: () -> Void
    let onOpenProjectCreator: () -> Void
    let onOpenSettings: () -> Void
    let onStartFocus: (TaskDefinition) -> Void

    @State private var foredropAnchor: ForedropAnchor = .collapsed
    @State private var calendarExpandedHeight: CGFloat = 0
    @State private var analyticsSectionHeight: CGFloat = 0
    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()
    @State private var lastDailyScore: Int?
    @State private var showXPBurst = false
    @State private var xpBurstValue = 0
    @State private var showLevelUp = false
    @State private var levelUpValue = 1
    @State private var showMilestone = false
    @State private var milestoneValue: XPCalculationEngine.Milestone?
    @State private var lastCelebrationAt: Date?
    @State private var showReflectionSheet = false
    @State private var reflectionIsSubmitting = false
    @State private var reflectionAlreadyCompleted = false
    @State private var reflectionStatusMessage: String?
    @State private var bottomBarState = HomeBottomBarState()
    @State private var foredropHintOffset: CGFloat = 0
    @State private var hintAnimationTask: _Concurrency.Task<Void, Never>?
    @State private var lastHintTriggerAt: Date?
    @State private var isHomeVisible = false

    private static let foredropHintLaunchDelay: TimeInterval = 0.10
    private static let foredropHintPeekDistance: CGFloat = 24
    private static let foredropHintPeekDuration: TimeInterval = 0.10
    private static let foredropHintReturnResponse: TimeInterval = 0.22
    private static let foredropHintReturnDampingFraction: CGFloat = 0.86
    private static let foredropHintSettleDuration: TimeInterval = 0.16
    private static let celebrationCooldownSeconds: TimeInterval = GamificationEngine.celebrationCooldownSeconds
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var topNavGlassCircleColor: Color {
        Color.tasker.accentSecondaryMuted.opacity(colorScheme == .dark ? 0.44 : 0.68)
    }
    private var isUITesting: Bool {
        Self.launchArguments.contains("-UI_TESTING") || Self.launchArguments.contains("-DISABLE_ANIMATIONS")
    }

    /// Executes foredropOffset.
    private func foredropOffset(for geometryHeight: CGFloat) -> CGFloat {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: calendarExpandedHeight,
            analyticsSectionHeight: analyticsSectionHeight,
            geometryHeight: geometryHeight
        )
        return metrics.offset(for: foredropAnchor)
    }

    /// Executes chartCardsViewportHeight.
    private func chartCardsViewportHeight(for geometry: GeometryProxy) -> CGFloat {
        let preferred = geometry.size.height * 0.66
        let lowerBound: CGFloat = 560
        let upperBound = geometry.size.height - 150
        return min(max(preferred, lowerBound), upperBound)
    }

    var body: some View {
        let _ = themeManager.currentTheme.index

        ZStack {
            GeometryReader { geometry in
                let backdropGradientHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                let bottomOverlayObstruction = (spacing.s12 * 2) + 56 + 6
                let taskListBottomInset = bottomOverlayObstruction + geometry.safeAreaInsets.bottom + spacing.s20

                ZStack(alignment: .top) {
                    Color.tasker.bgCanvas
                        .ignoresSafeArea()

                    HeaderGradientView()
                        .frame(height: backdropGradientHeight)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    LinearGradient(
                        colors: [
                            Color.tasker(.overlayScrim).opacity(0.12),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                        .frame(height: backdropGradientHeight)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        topNavigationBar()
                            .accessibilityIdentifier("home.topNav.container")

                        GeometryReader { contentGeometry in
                            ZStack(alignment: .top) {
                                backdropLayer(geometry: contentGeometry)

                                foredropLayer(
                                    geometry: contentGeometry,
                                    taskListBottomInset: taskListBottomInset
                                )
                                    .offset(y: foredropOffset(for: contentGeometry.size.height) + foredropHintOffset)
                                    .animation(TaskerAnimation.snappy, value: foredropAnchor)
                                    .gesture(
                                        DragGesture(minimumDistance: 8)
                                            .onEnded { value in
                                                let threshold: CGFloat = 50
                                                withAnimation(TaskerAnimation.snappy) {
                                                    if value.translation.height > threshold {
                                                        // Pull down: advance to next stop
                                                        switch foredropAnchor {
                                                        case .collapsed:  foredropAnchor = .midReveal
                                                        case .midReveal:  foredropAnchor = .fullReveal
                                                        case .fullReveal: break
                                                        }
                                                    } else if value.translation.height < -threshold {
                                                        // Pull up: retreat to previous stop
                                                        switch foredropAnchor {
                                                        case .collapsed:  break
                                                        case .midReveal:  foredropAnchor = .collapsed
                                                        case .fullReveal: foredropAnchor = .midReveal
                                                        }
                                                    }
                                                }
                                            }
                                    )
                            }
                        }
                    }
                }
                .background(Color.clear)
                .sheet(isPresented: $showDatePicker) {
                    NavigationView {
                        VStack(spacing: spacing.s16) {
                            DatePicker(
                                "Select date",
                                selection: $draftDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .padding(.horizontal, spacing.s16)

                            HStack(spacing: spacing.s12) {
                                Button("Today") {
                                    draftDate = Date()
                                    viewModel.selectDate(Date())
                                    showDatePicker = false
                                }
                                .buttonStyle(.bordered)

                                Button("Apply") {
                                    viewModel.selectDate(draftDate)
                                    showDatePicker = false
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .navigationTitle("Date")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showDatePicker = false }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAdvancedFilters) {
                    HomeAdvancedFilterSheetView(
                        initialFilter: viewModel.activeFilterState.advancedFilter,
                        initialShowCompletedInline: viewModel.activeFilterState.showCompletedInline,
                        savedViews: viewModel.savedHomeViews,
                        activeSavedViewID: viewModel.activeFilterState.selectedSavedViewID,
                        onApply: { filter, showCompletedInline in
                            viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                        },
                        onClear: {
                            viewModel.applyAdvancedFilter(nil, showCompletedInline: false)
                            viewModel.clearProjectFilters()
                            viewModel.setQuickView(.today)
                        },
                        onSaveNamedView: { filter, showCompletedInline, name in
                            viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                            viewModel.saveCurrentFilterAsView(name: name)
                        },
                        onApplySavedView: { id in
                            viewModel.applySavedView(id: id)
                        },
                        onDeleteSavedView: { id in
                            viewModel.deleteSavedView(id: id)
                        }
                    )
                }
            }

            if showXPBurst {
                xpBurstOverlay
            }

            if showLevelUp {
                LevelUpCelebrationView(level: levelUpValue, isPresented: $showLevelUp)
            }

            if showMilestone, let milestone = milestoneValue {
                MilestoneCelebrationView(milestone: milestone, isPresented: $showMilestone)
            }
        }
        .accessibilityIdentifier("home.view")
        .overlay(alignment: .bottom) {
            homeBottomBar
        }
        .onAppear {
            isHomeVisible = true
            lastDailyScore = viewModel.dailyScore
            triggerForedropHintIfEligible()
        }
        .onDisappear {
            isHomeVisible = false
            cancelForedropHintAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            triggerForedropHintIfEligible()
        }
        .onReceive(viewModel.$dailyScore.receive(on: RunLoop.main)) { newScore in
            handleDailyScoreUpdate(newScore)
        }
        .onReceive(viewModel.$lastXPResult.receive(on: RunLoop.main)) { result in
            handleXPResult(result)
        }
        .onReceive(viewModel.$insightsLaunchToken.receive(on: RunLoop.main)) { token in
            guard token != nil else { return }
            withAnimation(TaskerAnimation.snappy) {
                foredropAnchor = .fullReveal
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.evaFocusWhySheetPresented },
            set: { viewModel.setEvaFocusWhyPresented($0) }
        )) {
            EvaFocusWhySheetView(
                focusTasks: viewModel.focusTasks,
                insightProvider: { taskID in
                    viewModel.evaFocusInsight(for: taskID)
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.evaTriageSheetPresented },
            set: { viewModel.setEvaTriagePresented($0) }
        )) {
            EvaTriageSprintSheetV2(
                queue: viewModel.evaTriageQueue,
                projectsByID: Dictionary(uniqueKeysWithValues: viewModel.projects.map { ($0.id, $0) }),
                activeScope: viewModel.evaTriageScope,
                isLoadingScope: viewModel.evaTriageQueueLoading,
                queueErrorMessage: viewModel.evaTriageQueueErrorMessage,
                lastBatchRunID: viewModel.evaLastBatchRunID,
                onScopeChange: { scope, completion in
                    viewModel.refreshTriageQueue(scope: scope, completion: completion)
                },
                onApplyDecision: { item, decision, completion in
                    viewModel.applyTriageDecision(for: item, decision: decision, completion: completion)
                },
                onApplyAll: { completion in
                    viewModel.applyAllTriageSuggestions(completion: completion)
                },
                onUndoBulkApply: { completion in
                    viewModel.undoEvaBatchPlan(completion: completion)
                },
                onSkip: { taskID in
                    viewModel.removeTriageQueueItem(taskID: taskID)
                },
                onDelete: { taskID, completion in
                    viewModel.deleteTask(taskID: taskID, scope: .single) { result in
                        switch result {
                        case .success:
                            viewModel.removeTriageQueueItem(taskID: taskID)
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                },
                onTrack: { action, metadata in
                    viewModel.trackHomeInteraction(action: action, metadata: metadata)
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.evaRescueSheetPresented },
            set: { viewModel.setEvaRescuePresented($0) }
        )) {
            EvaOverdueRescueSheetV2(
                plan: viewModel.evaRescuePlan,
                tasksByID: (viewModel.overdueTasks + viewModel.morningTasks + viewModel.eveningTasks + viewModel.evaTriageQueue.map(\.task))
                    .reduce(into: [UUID: TaskDefinition]()) { partialResult, task in
                        partialResult[task.id] = task
                    },
                lastBatchRunID: viewModel.evaLastBatchRunID,
                onApply: { mutations, completion in
                    viewModel.applyRescuePlan(mutations: mutations, completion: completion)
                },
                onUndo: { completion in
                    viewModel.undoRescueRun(completion: completion)
                },
                onCreateSplit: { taskID, draft, completion in
                    viewModel.createSplitChildren(parentTaskID: taskID, draft: draft, completion: completion)
                },
                onUndoSplit: { childIDs, completion in
                    viewModel.undoCreatedSplitChildren(childTaskIDs: childIDs, completion: completion)
                },
                onTrack: { action, metadata in
                    viewModel.trackHomeInteraction(action: action, metadata: metadata)
                }
            )
        }
        .sheet(isPresented: $showReflectionSheet) {
            DailyReflectionView(
                tasksCompleted: max(viewModel.dailyCompletedTasks.count, insightsViewModel.tasksCompletedToday),
                xpEarned: viewModel.dailyScore,
                streakDays: viewModel.streak,
                isSubmitting: reflectionIsSubmitting,
                alreadyCompletedToday: reflectionAlreadyCompleted,
                statusMessage: reflectionStatusMessage,
                onComplete: {
                    reflectionIsSubmitting = true
                    reflectionStatusMessage = nil
                    viewModel.completeDailyReflection { result in
                        reflectionIsSubmitting = false
                        switch result {
                        case .success(let xpResult):
                            if xpResult.awardedXP > 0 {
                                reflectionAlreadyCompleted = false
                                reflectionStatusMessage = nil
                                showReflectionSheet = false
                            } else {
                                reflectionAlreadyCompleted = true
                                reflectionStatusMessage = "Reflection already completed today."
                            }
                        case .failure(let error):
                            reflectionAlreadyCompleted = false
                            reflectionStatusMessage = error.localizedDescription
                        }
                    }
                }
            )
        }
    }

    /// Executes triggerForedropHintIfEligible.
    private func triggerForedropHintIfEligible(now: Date = Date()) {
        let canTrigger = HomeForedropHintEligibility.canTrigger(
            isHomeVisible: isHomeVisible,
            foredropAnchor: foredropAnchor,
            reduceMotionEnabled: reduceMotion,
            isUITesting: isUITesting,
            hasRunningAnimation: hintAnimationTask != nil,
            lastTriggerDate: lastHintTriggerAt,
            now: now
        )
        guard canTrigger else { return }

        startForedropHintAnimation(triggeredAt: now)
    }

    /// Executes startForedropHintAnimation.
    private func startForedropHintAnimation(triggeredAt timestamp: Date) {
        cancelForedropHintAnimation()
        lastHintTriggerAt = timestamp

        hintAnimationTask = _Concurrency.Task { @MainActor in
            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintLaunchDelay.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(.easeOut(duration: Self.foredropHintPeekDuration)) {
                foredropHintOffset = Self.foredropHintPeekDistance
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintPeekDuration.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(
                .spring(
                    response: Self.foredropHintReturnResponse,
                    dampingFraction: Self.foredropHintReturnDampingFraction
                )
            ) {
                foredropHintOffset = 0
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintSettleDuration.nanoseconds)
            } catch {
                return
            }

            hintAnimationTask = nil
        }
    }

    /// Executes cancelForedropHintAnimation.
    private func cancelForedropHintAnimation() {
        hintAnimationTask?.cancel()
        hintAnimationTask = nil
        foredropHintOffset = 0
    }

    /// Executes backdropLayer.
    private func backdropLayer(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: max(480, geometry.size.height * 0.65))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        // 1. Weekly Calendar Strip
                        WeeklyCalendarStripView(
                            selectedDate: Binding(
                                get: { viewModel.selectedDate },
                                set: { viewModel.selectDate($0) }
                            ),
                            todayDate: Date()
                        )
                        .padding(.horizontal, spacing.s16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            GeometryReader { calGeo in
                                Color.clear.preference(
                                    key: CalendarHeightPreferenceKey.self,
                                    value: calGeo.size.height
                                )
                            }
                        )
                        .onPreferenceChange(CalendarHeightPreferenceKey.self) { height in
                            let baseWeekHeight: CGFloat = 80
                            let nextHeight = max(0, height - baseWeekHeight)
                            guard abs(calendarExpandedHeight - nextHeight) > 0.5 else { return }
                            calendarExpandedHeight = nextHeight
                        }
                        .opacity(foredropAnchor != .collapsed ? 1 : 0.001)

                        // 2. Chart Cards (visible when fully revealed)
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            HStack(spacing: spacing.s8) {
                                Text("Analytics")
                                    .font(.tasker(.headline))
                                    .foregroundColor(Color.tasker.textPrimary)
                                Spacer()
                                Button("Reflect") {
                                    reflectionIsSubmitting = false
                                    let completedToday = viewModel.isDailyReflectionCompletedToday()
                                    reflectionAlreadyCompleted = completedToday
                                    reflectionStatusMessage = completedToday
                                        ? "Reflection already completed today."
                                        : nil
                                    showReflectionSheet = true
                                }
                                .font(.tasker(.caption1))
                                .buttonStyle(.plain)
                                .foregroundColor(Color.tasker.accentPrimary)
                                .frame(minHeight: 44)
                            }

                            InsightsTabView(viewModel: insightsViewModel)
                                .frame(height: chartCardsViewportHeight(for: geometry))
                        }
                        .padding(.horizontal, spacing.s16)
                        .background(
                            GeometryReader { analyticsGeo in
                                Color.clear.preference(
                                    key: AnalyticsSectionHeightPreferenceKey.self,
                                    value: analyticsGeo.size.height
                                )
                            }
                        )
                        .onPreferenceChange(AnalyticsSectionHeightPreferenceKey.self) { height in
                            let nextHeight = max(0, height)
                            guard abs(analyticsSectionHeight - nextHeight) > 0.5 else { return }
                            analyticsSectionHeight = nextHeight
                        }
                        .opacity(foredropAnchor == .fullReveal ? 1 : 0.001)
                    }
                }
            Spacer(minLength: 0)
        }
    }

    /// Executes foredropLayer.
    private func foredropLayer(geometry: GeometryProxy, taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            handleBar
                .padding(.top, spacing.s8)

            if hasActiveQuickFilters {
                quickFilterPills
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s8)
            }

            if viewModel.canUseManualFocusDrag || !viewModel.focusTasks.isEmpty {
                focusStrip
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s2)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.focus.strip")
            }

            // Next action module: contextual guidance for empty/low-content states
            if viewModel.activeScope.quickView == .today && viewModel.pinnedFocusTaskIDs.count < 3 {
                NextActionModule(
                    openTaskCount: viewModel.todayOpenTaskCount,
                    focusPinnedCount: viewModel.pinnedFocusTaskIDs.count,
                    onAddTask: { onAddTask() }
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s4)
            }

            TaskListView(
                morningTasks: viewModel.morningTasks,
                eveningTasks: viewModel.eveningTasks,
                overdueTasks: viewModel.overdueTasks,
                inlineCompletedTasks: viewModel.activeScope.quickView == .today ? viewModel.completedTasks : [],
                projects: viewModel.projects,
                doneTimelineTasks: viewModel.doneTimelineTasks,
                tagNameByID: Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0.name) }),
                activeQuickView: viewModel.activeScope.quickView,
                projectGroupingMode: viewModel.activeFilterState.projectGroupingMode,
                customProjectOrderIDs: viewModel.activeFilterState.customProjectOrderIDs,
                emptyStateMessage: viewModel.emptyStateMessage,
                emptyStateActionTitle: viewModel.emptyStateActionTitle,
                isTaskDragEnabled: viewModel.canUseManualFocusDrag,
                onTaskTap: onTaskTap,
                onToggleComplete: { task in
                    trackTaskToggle(task, source: "task_list")
                    onToggleComplete(task)
                },
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onReorderCustomProjects: onReorderCustomProjects,
                onInboxHeaderAction: shouldShowInboxTriageAction ? {
                    viewModel.startTriage()
                } : nil,
                inboxHeaderActionTitle: shouldShowInboxTriageAction ? "Start triage" : nil,
                onOverdueHeaderAction: shouldShowOverdueRescueAction ? {
                    viewModel.openRescue()
                } : nil,
                overdueHeaderActionTitle: shouldShowOverdueRescueAction ? "Rescue" : nil,
                onCompletedSectionToggle: { sectionID, collapsed, count in
                    viewModel.trackHomeInteraction(
                        action: "home_completed_group_toggled",
                        metadata: [
                            "section_id": sectionID.uuidString,
                            "collapsed": collapsed,
                            "count": count
                        ]
                    )
                },
                onEmptyStateAction: { onAddTask() },
                onTaskDragStarted: { task in
                    trackTaskDragStarted(task, source: "task_list")
                },
                onScrollOffsetChange: { newOffset in
                    bottomBarState.handleScrollOffsetChange(newOffset)
                },
                bottomContentInset: taskListBottomInset
            )
            .padding(.top, spacing.s4)
            .onDrop(of: ["public.text"], isTargeted: nil, perform: handleListDrop)
            .accessibilityIdentifier("home.list.dropzone")
        }
        .frame(
            width: geometry.size.width,
            height: geometry.size.height,
            alignment: .top
        )
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: corner.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner.modal
            )
                .fill(Color.tasker.surfaceTertiary)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: corner.modal,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: corner.modal
                    )
                        .stroke(Color.tasker.strokeHairline.opacity(0.35), lineWidth: 1)
                )
                .taskerElevation(.e2, cornerRadius: corner.modal, includesBorder: false)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: corner.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner.modal
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.foredrop.surface")
        .accessibilityValue(foredropAnchor.accessibilityValue)
    }

    private var handleBar: some View {
        VStack(spacing: spacing.s4) {
            Capsule()
                .fill(Color.tasker.textQuaternary.opacity(0.4))
                .frame(width: 44, height: 5)
                .accessibilityIdentifier("home.foredrop.handle")

            if foredropAnchor == .fullReveal {
                Button {
                    withAnimation(TaskerAnimation.snappy) {
                        foredropAnchor = .collapsed
                    }
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                        Text("collapse")
                            .font(.tasker(.caption2))
                    }
                    .foregroundColor(Color.tasker.textQuaternary.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.foredrop.collapseHint")
                .accessibilityLabel("Collapse analytics")
            }
        }
    }

    private func topNavigationBar() -> some View {
        VStack(spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                QuickViewSelector(
                    selectedQuickView: Binding(
                        get: { viewModel.activeScope.quickView },
                        set: { viewModel.setQuickView($0) }
                    ),
                    taskCounts: viewModel.quickViewCounts,
                    onShowDatePicker: {
                        draftDate = viewModel.selectedDate
                        showDatePicker = true
                    },
                    onShowAdvancedFilters: {
                        showAdvancedFilters = true
                    },
                    onResetFilters: {
                        viewModel.resetAllFilters()
                    }
                )
                .frame(minHeight: 44)

                Spacer(minLength: spacing.s4)

                NavPieChart(
                    score: viewModel.dailyScore,
                    maxScore: viewModel.progressState.todayTargetXP,
                    accessibilityContainerID: "home.navXpPieChart",
                    accessibilityButtonID: "home.navXpPieChart.button"
                ) {
                    let shouldOpenInsights = foredropAnchor != .fullReveal
                    withAnimation(TaskerAnimation.snappy) {
                        foredropAnchor = foredropAnchor == .fullReveal ? .collapsed : .fullReveal
                    }
                    if shouldOpenInsights {
                        viewModel.launchInsights()
                    }
                }
                .background(
                    Circle()
                        .fill(topNavGlassCircleColor)
                )

                topSearchButton
                topSettingsButton
            }

            cockpitStats
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, 0)
        .padding(.bottom, spacing.s8)
    }

    private var topSearchButton: some View {
        Button {
            onOpenSearch()
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.tasker.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(topNavGlassCircleColor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.topNav.searchButton")
        .accessibilityLabel("Search")
    }

    private var topSettingsButton: some View {
        Button {
            onOpenSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.tasker.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(topNavGlassCircleColor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.settingsButton")
    }

    private var hasActiveQuickFilters: Bool {
        !viewModel.activeFilterState.selectedProjectIDs.isEmpty
            || viewModel.activeFilterState.advancedFilter != nil
    }

    private var shouldShowInboxTriageAction: Bool {
        V2FeatureFlags.evaTriageEnabled && viewModel.activeScope.quickView == .today
    }

    private var shouldShowOverdueRescueAction: Bool {
        V2FeatureFlags.evaRescueEnabled && viewModel.activeScope.quickView == .today
    }

    private var quickFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s4) {
                if let projectFilter = viewModel.activeFilterState.selectedProjectIDs.first {
                    FilterPill(
                        title: viewModel.projects.first(where: { $0.id == projectFilter })?.name ?? "Project",
                        systemImage: "folder"
                    ) {
                        viewModel.clearProjectFilters()
                    }
                }

                if viewModel.activeFilterState.advancedFilter != nil {
                    FilterPill(
                        title: "Filters",
                        systemImage: "slider.horizontal.3"
                    ) {
                        viewModel.applyAdvancedFilter(nil, showCompletedInline: false)
                    }
                }

                FilterPill(
                    title: "Clear all",
                    systemImage: "xmark.circle.fill",
                    isDestructive: true
                ) {
                    viewModel.resetAllFilters()
                }
            }
        }
    }

    private var cockpitStats: some View {
        let progress = viewModel.progressState
        let denominator = max(1, progress.todayTargetXP)
        let progressRatio = min(1, Double(progress.earnedXP) / Double(denominator))
        let completionPercent = Int((viewModel.completionRate * 100).rounded())

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: spacing.s8) {
                Text("\(progress.earnedXP)/\(progress.todayTargetXP) XP")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
                    .accessibilityIdentifier("home.dailyScoreLabel")
                    .lineLimit(1)

                Spacer(minLength: spacing.s8)

                Text("\(completionPercent)% complete")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textSecondary)
                    .accessibilityIdentifier("home.completionRateLabel")
                    .lineLimit(1)

                streakIndicator(for: progress)
                    .accessibilityIdentifier("home.streakLabel")

            }

            // Enhanced progress bar with gradient and glow
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.tasker.surfaceSecondary)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: progressGradientColors(isStreakSafe: progress.isStreakSafeToday),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressRatio)
                        .shadow(
                            color: progress.isStreakSafeToday
                                ? Color.tasker.accentPrimary.opacity(0.4)
                                : Color.tasker.statusWarning.opacity(0.4),
                            radius: 4,
                            x: 2,
                            y: 0
                        )
                }
            }
            .frame(height: 6)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progressRatio)
        }
    }

    /// Executes progressGradientColors.
    private func progressGradientColors(isStreakSafe: Bool) -> [Color] {
        if isStreakSafe {
            return [Color.tasker.accentPrimary, Color.tasker.accentSecondary]
        } else {
            return [Color.tasker.statusWarning, Color.tasker.statusWarning.opacity(0.7)]
        }
    }

    /// Executes streakIndicator.
    @ViewBuilder
    private func streakIndicator(for progress: HomeProgressState) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(progress.isStreakSafeToday ? Color.tasker.accentSecondary : Color.tasker.statusWarning)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: !progress.isStreakSafeToday)

            Text("\(progress.streakDays)d")
                .font(.tasker(.caption1))
                .fontWeight(.medium)
                .foregroundColor(progress.isStreakSafeToday ? Color.tasker.textSecondary : Color.tasker.statusWarning)
        }
    }

    private var focusStrip: some View {
        FocusZone(
            tasks: viewModel.focusTasks,
            canDrag: viewModel.canUseManualFocusDrag,
            insightForTaskID: { taskID in
                viewModel.evaFocusInsight(for: taskID)
            },
            onShuffle: {
                viewModel.shuffleFocusNow()
            },
            onWhy: {
                viewModel.openFocusWhy()
            },
            onTaskTap: { task in
                onTaskTap(task)
            },
            onToggleComplete: { task in
                trackTaskToggle(task, source: "focus_strip")
                onToggleComplete(task)
            },
            onStartFocus: { task in
                onStartFocus(task)
            },
            onTaskDragStarted: { task in
                trackTaskDragStarted(task, source: "focus_strip")
            },
            onDrop: handleFocusDrop
        )
    }

    private var homeBottomBar: some View {
        HomeGlassBottomBar(
            state: bottomBarState,
            onChartsToggle: {
                let shouldOpenInsights = foredropAnchor != .fullReveal
                withAnimation(TaskerAnimation.snappy) {
                    foredropAnchor = foredropAnchor == .fullReveal ? .collapsed : .fullReveal
                }
                if shouldOpenInsights {
                    viewModel.launchInsights()
                }
            },
            onSearch: {
                onOpenSearch()
            },
            onChat: {
                onOpenChat()
            },
            onCreate: {
                onAddTask()
            }
        )
        .padding(.horizontal, spacing.s16)
        .padding(.bottom, 0)
        .ignoresSafeArea(.container, edges: .bottom)
        .offset(y: 6)
        .animation(TaskerAnimation.snappy, value: bottomBarState.isMinimized)
    }

    private var xpBurstOverlay: some View {
        XPCelebrationView(xpValue: xpBurstValue, isPresented: $showXPBurst)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 100)
            .allowsHitTesting(false)
    }

    /// Executes trackTaskToggle.
    private func trackTaskToggle(_ task: TaskDefinition, source: String) {
        viewModel.trackHomeInteraction(
            action: "home_task_toggle",
            metadata: [
                "source": source,
                "task_id": task.id.uuidString,
                "current_state": task.isComplete ? "done" : "open"
            ]
        )
    }

    /// Executes trackTaskDragStarted.
    private func trackTaskDragStarted(_ task: TaskDefinition, source: String) {
        var metadata = focusScopeMetadata(source: source, taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(
            action: "home_focus_drag_started",
            metadata: metadata
        )
    }

    /// Executes handleFocusDrop.
    private func handleFocusDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }

            let pinResult = viewModel.pinTaskToFocus(taskID)
            var metadata = focusScopeMetadata(source: "task_list", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

            switch pinResult {
            case .pinned:
                TaskerFeedback.success()
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .alreadyPinned:
                TaskerFeedback.selection()
                metadata["result"] = "already_pinned"
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .capacityReached(let limit):
                TaskerFeedback.light()
                metadata["limit"] = limit
                viewModel.trackHomeInteraction(action: "home_focus_drop_rejected_capacity", metadata: metadata)
            case .taskIneligible:
                TaskerFeedback.selection()
            }
        }
    }

    /// Executes handleListDrop.
    private func handleListDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }
            let wasPinned = viewModel.pinnedFocusTaskIDs.contains(taskID)
            guard wasPinned else { return }

            viewModel.unpinTaskFromFocus(taskID)
            TaskerFeedback.selection()

            var metadata = focusScopeMetadata(source: "focus_strip", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
            viewModel.trackHomeInteraction(action: "home_focus_dropped_out", metadata: metadata)
        }
    }

    /// Executes loadTaskIDFromDrop.
    private func loadTaskIDFromDrop(
        providers: [NSItemProvider],
        completion: @escaping (UUID?) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            completion(nil)
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            let rawValue = (object as? NSString)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let taskID = rawValue.flatMap(UUID.init(uuidString:))
            DispatchQueue.main.async {
                completion(taskID)
            }
        }
        return true
    }

    /// Executes focusScopeMetadata.
    private func focusScopeMetadata(source: String, taskID: UUID) -> [String: Any] {
        [
            "source": source,
            "task_id": taskID.uuidString,
            "quick_view": viewModel.activeScope.quickView.analyticsAction,
            "scope": scopeAnalyticsName
        ]
    }

    private var scopeAnalyticsName: String {
        switch viewModel.activeScope {
        case .today:
            return "today"
        case .customDate:
            return "custom_date"
        case .upcoming:
            return "upcoming"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    private func canShowCelebration(now: Date = Date()) -> Bool {
        guard let lastCelebrationAt else { return true }
        return now.timeIntervalSince(lastCelebrationAt) >= Self.celebrationCooldownSeconds
    }

    private func markCelebrationShown(now: Date = Date()) {
        lastCelebrationAt = now
    }

    private func handleXPResult(_ result: XPEventResult?) {
        guard let result, result.awardedXP > 0 else { return }
        guard canShowCelebration() else { return }

        if let milestone = result.crossedMilestone {
            milestoneValue = milestone
            showMilestone = true
            markCelebrationShown()
            return
        }

        if result.didLevelUp {
            levelUpValue = result.level
            showLevelUp = true
            markCelebrationShown()
            return
        }

        xpBurstValue = result.awardedXP
        showXPBurst = true
        markCelebrationShown()
    }

    /// Executes handleDailyScoreUpdate.
    private func handleDailyScoreUpdate(_ newScore: Int) {
        defer { lastDailyScore = newScore }

        guard let previous = lastDailyScore else { return }
        let delta = newScore - previous
        guard delta > 0 else { return }
        guard canShowCelebration() else { return }

        xpBurstValue = delta
        showXPBurst = true
        markCelebrationShown()

        // Enhanced haptic feedback based on XP gain
        if delta >= 7 {
            TaskerFeedback.success()
        } else if delta >= 4 {
            TaskerFeedback.medium()
        } else {
            TaskerFeedback.light()
        }

        viewModel.trackHomeInteraction(
            action: "home_reward_xp_burst",
            metadata: ["delta": delta, "new_score": newScore]
        )
    }
}
