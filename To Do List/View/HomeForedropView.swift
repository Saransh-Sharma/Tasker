//
//  HomeForedropView.swift
//  Tasker
//
//  New SwiftUI Home shell with backdrop/foredrop pattern.
//

import SwiftUI
import UIKit
import Combine

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
    var calendarExpandedHeight: CGFloat = 0
    var analyticsSectionHeight: CGFloat = 0
    var geometryHeight: CGFloat = 0

    /// Executes offset.
    func offset(for anchor: ForedropAnchor) -> CGFloat {
        0
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

private extension TimeInterval {
    var nanoseconds: UInt64 {
        UInt64((self * 1_000_000_000).rounded())
    }
}

extension ForedropAnchor {
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

enum HomeForedropFace: Equatable {
    case tasks
    case analytics
    case search

    var isBackFace: Bool {
        self != .tasks
    }

    var selectedBottomBarItem: HomeBottomBarItem {
        switch self {
        case .tasks:
            return .home
        case .analytics:
            return .charts
        case .search:
            return .search
        }
    }

    var surfaceAccessibilityValue: String {
        switch self {
        case .tasks:
            return "collapsed"
        case .analytics, .search:
            return "fullReveal"
        }
    }
}

enum HomeSearchStatusFilter: String, CaseIterable, Equatable, Identifiable {
    case all
    case today
    case overdue
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .today:
            return "Today"
        case .overdue:
            return "Overdue"
        case .completed:
            return "Completed"
        }
    }

    var analyticsName: String { rawValue }

    var accessibilityIdentifier: String {
        "search.status.\(rawValue)"
    }
}

private extension HomeSearchStatusFilter {
    var legacyValue: LGSearchViewModel.StatusFilterType {
        switch self {
        case .all:
            return .all
        case .today:
            return .today
        case .overdue:
            return .overdue
        case .completed:
            return .completed
        }
    }
}

struct HomeSearchSection: Identifiable, Equatable {
    let projectName: String
    let tasks: [TaskDefinition]

    var id: String { projectName }
}

struct HomeSearchRequestSignature: Equatable {
    let dataRevision: Int
    let query: String
    let status: HomeSearchStatusFilter
    let priorities: [Int32]
    let projects: [String]
}

enum HomeSearchFocusPolicyResolver {
    static func shouldAutoFocusOnSearchEntry(layoutClass: TaskerLayoutClass) -> Bool {
        guard V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled else {
            return true
        }
        return layoutClass == .phone
    }
}

@MainActor
protocol HomeSearchEngine: AnyObject {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)? { get set }
    var projects: [Project] { get }

    func search(query: String, revision: Int)
    func loadProjects(completion: (() -> Void)?)
    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32])
    func clearFilters()
    func toggleProjectFilter(_ project: String)
    func togglePriorityFilter(_ priority: Int32)
    func setStatusFilter(_ filter: HomeSearchStatusFilter)
    func invalidateSearchCache(revision: Int)
    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])]
}

@MainActor
final class LGHomeSearchEngine: HomeSearchEngine {
    private let viewModel: LGSearchViewModel

    init(viewModel: LGSearchViewModel) {
        self.viewModel = viewModel
    }

    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)? {
        get { viewModel.onResultsUpdatedWithRevision }
        set { viewModel.onResultsUpdatedWithRevision = newValue }
    }

    var projects: [Project] {
        viewModel.projects
    }

    func search(query: String, revision: Int) {
        viewModel.search(query: query, revision: revision)
    }

    func loadProjects(completion: (() -> Void)?) {
        viewModel.loadProjects(completion: completion)
    }

    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32]) {
        viewModel.replaceFilters(
            status: status.legacyValue,
            projects: projects,
            priorities: priorities
        )
    }

    func clearFilters() {
        viewModel.clearFilters()
    }

    func toggleProjectFilter(_ project: String) {
        viewModel.toggleProjectFilter(project)
    }

    func togglePriorityFilter(_ priority: Int32) {
        viewModel.togglePriorityFilter(priority)
    }

    func setStatusFilter(_ filter: HomeSearchStatusFilter) {
        viewModel.setStatusFilter(filter.legacyValue)
    }

    func invalidateSearchCache(revision: Int) {
        viewModel.invalidateSearchCache(revision: revision)
    }

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        viewModel.groupTasksByProject(tasks)
    }
}

@MainActor
final class SearchRefreshCoordinator {
    private let debounceNanoseconds: UInt64
    private var debounceTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(debounceDelay: TimeInterval = 0.18) {
        debounceNanoseconds = UInt64(max(0, debounceDelay) * 1_000_000_000)
    }

    @discardableResult
    func request(
        immediate: Bool,
        perform: @escaping @MainActor (UInt64) -> Void
    ) -> UInt64 {
        generation &+= 1
        let requestGeneration = generation
        debounceTask?.cancel()

        if immediate || debounceNanoseconds == 0 {
            perform(requestGeneration)
            return requestGeneration
        }

        let wait = debounceNanoseconds
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: wait)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await perform(requestGeneration)
        }
        return requestGeneration
    }

    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}

@MainActor
final class HomeSearchState: ObservableObject {
    @Published var query: String = ""
    @Published var selectedStatus: HomeSearchStatusFilter = .all
    @Published var selectedPriorities: Set<Int32> = []
    @Published var selectedProjects: Set<String> = []
    @Published private(set) var sections: [HomeSearchSection] = []
    @Published private(set) var availableProjects: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    private var engine: HomeSearchEngine?
    private let refreshCoordinator: SearchRefreshCoordinator
    private var dataRevision: Int = 0
    private var latestIssuedSearchRevision: Int = 0
    private var needsRefreshOnNextActivation = false
    private var lastExecutedSignature: HomeSearchRequestSignature?

    init(debounceDelay: TimeInterval = 0.18) {
        refreshCoordinator = SearchRefreshCoordinator(debounceDelay: debounceDelay)
    }

    var hasActiveFilters: Bool {
        selectedStatus != .all || !selectedPriorities.isEmpty || !selectedProjects.isEmpty
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowNoResultsMessage: Bool {
        hasLoaded && !isLoading && sections.isEmpty
    }

    var emptyStateTitle: String {
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Start searching"
        }
        return "No tasks found"
    }

    var emptyStateSubtitle: String {
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Type to search your tasks or use quick chips."
        }
        return "Try a different query or adjust quick chips."
    }

    func configureIfNeeded(makeEngine: () -> HomeSearchEngine) {
        guard engine == nil else { return }
        let resolvedEngine = makeEngine()
        engine = resolvedEngine
        resolvedEngine.invalidateSearchCache(revision: dataRevision)
        resolvedEngine.onResultsUpdated = { [weak self] revision, tasks in
            guard let self else { return }
            Task { @MainActor in
                self.handleResults(tasks, revision: revision)
            }
        }
        resolvedEngine.loadProjects { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.refreshAvailableProjects()
            }
        }
        refresh(immediate: true)
    }

    func activate() {
        guard engine != nil else { return }
        let nextSignature = requestSignature
        if hasLoaded,
           needsRefreshOnNextActivation == false,
           lastExecutedSignature == nextSignature {
            return
        }
        refresh(immediate: true)
    }

    func deactivate() {
        refreshCoordinator.cancel()
        isLoading = false
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        refresh(immediate: false)
    }

    func clearQuery() {
        guard !query.isEmpty else { return }
        query = ""
        refresh(immediate: true)
    }

    func setStatus(_ status: HomeSearchStatusFilter) {
        guard selectedStatus != status else { return }
        selectedStatus = status
        refresh(immediate: true)
    }

    func togglePriority(_ priority: TaskPriorityConfig.Priority) {
        let raw = priority.rawValue
        if selectedPriorities.contains(raw) {
            selectedPriorities.remove(raw)
        } else {
            selectedPriorities.insert(raw)
        }
        refresh(immediate: true)
    }

    func toggleProject(_ project: String) {
        if selectedProjects.contains(project) {
            selectedProjects.remove(project)
        } else {
            selectedProjects.insert(project)
        }
        refresh(immediate: true)
    }

    func markDataMutated() {
        dataRevision &+= 1
        needsRefreshOnNextActivation = true
        engine?.invalidateSearchCache(revision: dataRevision)
    }

    func refresh(immediate: Bool) {
        guard engine != nil else { return }
        guard V2FeatureFlags.iPadPerfSearchCoalescingV2Enabled else {
            let nextRevision = max(1, latestIssuedSearchRevision &+ 1)
            performSearch(refreshGeneration: UInt64(nextRevision))
            return
        }
        logWarning(
            event: "searchRefresh",
            message: "Home search refresh requested",
            fields: [
                "immediate": immediate ? "true" : "false",
                "data_revision": String(dataRevision),
                "query_length": String(trimmedQuery.count)
            ]
        )
        _ = refreshCoordinator.request(immediate: immediate) { [weak self] refreshGeneration in
            self?.performSearch(refreshGeneration: refreshGeneration)
        }
    }

    private func performSearch(refreshGeneration: UInt64) {
        guard let engine else { return }
        let cappedRevision = Int(refreshGeneration % UInt64(Int.max))
        latestIssuedSearchRevision = cappedRevision
        isLoading = true
        let signature = requestSignature
        let projects = signature.projects
        let priorities = signature.priorities
        engine.setFilters(
            status: selectedStatus,
            projects: projects,
            priorities: priorities
        )
        lastExecutedSignature = signature
        needsRefreshOnNextActivation = false
        logWarning(
            event: "searchPerform",
            message: "Home search execution started",
            fields: [
                "search_revision": String(cappedRevision),
                "data_revision": String(dataRevision),
                "status": selectedStatus.analyticsName,
                "query_length": String(trimmedQuery.count),
                "project_filter_count": String(projects.count),
                "priority_filter_count": String(priorities.count)
            ]
        )
        engine.search(query: trimmedQuery, revision: cappedRevision)
    }

    private func handleResults(_ tasks: [TaskDefinition], revision: Int) {
        guard let engine else { return }
        guard revision >= latestIssuedSearchRevision else { return }
        sections = engine
            .groupTasksByProject(tasks)
            .map { HomeSearchSection(projectName: $0.project, tasks: $0.tasks) }
        hasLoaded = true
        isLoading = false
        refreshAvailableProjects()
    }

    private func refreshAvailableProjects() {
        let remoteProjectNames = Set((engine?.projects ?? []).map(\.name))
        let visibleProjectNames = Set(sections.map(\.projectName))
        let allProjects = remoteProjectNames
            .union(visibleProjectNames)
            .union([ProjectConstants.inboxProjectName])
        availableProjects = allProjects.sorted()
        selectedProjects = selectedProjects.intersection(allProjects)
    }

    private var requestSignature: HomeSearchRequestSignature {
        HomeSearchRequestSignature(
            dataRevision: dataRevision,
            query: trimmedQuery,
            status: selectedStatus,
            priorities: selectedPriorities.sorted(),
            projects: selectedProjects.sorted()
        )
    }
}

struct HomeBackdropForedropRootView: View {
    @ObservedObject var viewModel: HomeViewModel
    let chartCardViewModel: ChartCardViewModel
    let radarChartCardViewModel: RadarChartCardViewModel
    let insightsViewModel: InsightsViewModel
    let layoutClass: TaskerLayoutClass
    let forcedFace: Binding<HomeForedropFace>?
    @ObservedObject private var themeManager = TaskerThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let onTaskTap: (TaskDefinition) -> Void
    let onToggleComplete: (TaskDefinition) -> Void
    let onDeleteTask: (TaskDefinition) -> Void
    let onRescheduleTask: (TaskDefinition) -> Void
    let onReorderCustomProjects: ([UUID]) -> Void
    let onAddTask: () -> Void
    let onOpenChat: () -> Void
    let onOpenProjectCreator: () -> Void
    let onOpenSettings: () -> Void
    let onStartFocus: (TaskDefinition) -> Void

    @State private var activeFace: HomeForedropFace = .tasks
    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()
    @State private var celebrationRouter = DefaultCelebrationRouter()
    @State private var showXPBurst = false
    @State private var xpBurstValue = 0
    @State private var showLevelUp = false
    @State private var levelUpValue = 1
    @State private var showMilestone = false
    @State private var milestoneValue: XPCalculationEngine.Milestone?
    @State private var semanticCelebrationXP = 0
    @State private var showReflectionSheet = false
    @State private var reflectionClaimState: DailyReflectionClaimState = .ready
    @State private var bottomBarState = HomeBottomBarState()
    @State private var foredropHintOffset: CGFloat = 0
    @State private var hintAnimationTask: _Concurrency.Task<Void, Never>?
    @State private var lastHintTriggerAt: Date?
    @State private var isHomeVisible = false
    @State private var snackbar: SnackbarData?
    @State private var shownUnlockKeys = Set<String>()
    @State private var lastSearchQueryTelemetryAt: Date?
    @StateObject private var searchState = HomeSearchState()
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasAutoFocusedSearchField = false
    @State private var projectsByIDCache: [UUID: Project] = [:]
    @State private var projectsByNameCache: [String: Project] = [:]
    @State private var tagNameByIDCache: [UUID: String] = [:]
    @State private var rescueTasksByIDCache: [UUID: TaskDefinition] = [:]

    private static let foredropHintLaunchDelay: TimeInterval = 0.10
    private static let foredropHintPeekDistance: CGFloat = 24
    private static let foredropHintPeekDuration: TimeInterval = 0.10
    private static let foredropHintReturnResponse: TimeInterval = 0.22
    private static let foredropHintReturnDampingFraction: CGFloat = 0.86
    private static let foredropHintSettleDuration: TimeInterval = 0.16
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }
    private var forcedFaceValue: HomeForedropFace? { forcedFace?.wrappedValue }
    private var showsBottomBar: Bool { layoutClass == .phone }
    private var topNavGlassCircleColor: Color {
        Color.tasker.accentSecondaryMuted.opacity(colorScheme == .dark ? 0.44 : 0.68)
    }
    private var isUITesting: Bool {
        Self.launchArguments.contains("-UI_TESTING") || Self.launchArguments.contains("-DISABLE_ANIMATIONS")
    }
    private var foredropAnchorForHint: ForedropAnchor {
        activeFace == .tasks ? .collapsed : .fullReveal
    }
    private var isSearchOpen: Bool { activeFace == .search }
    private var isBackFaceVisible: Bool { activeFace.isBackFace }
    private var foredropFlipTransition: AnyTransition {
        if reduceMotion || isUITesting || (layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled) {
            return .opacity
        }
        return .coverFlip(blurStrength: 3.5)
    }
    private var foredropFlipAnimation: Animation {
        let duration: TimeInterval
        if reduceMotion || isUITesting {
            duration = 0.2
        } else if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
            duration = 0.12
        } else {
            duration = 0.42
        }
        return .easeInOut(duration: duration)
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
                                    .offset(y: foredropHintOffset)
                                    .animation(foredropFlipAnimation, value: activeFace)
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
                LevelUpCelebrationView(
                    level: levelUpValue,
                    awardedXP: semanticCelebrationXP,
                    isPresented: $showLevelUp
                )
            }

            if showMilestone, let milestone = milestoneValue {
                MilestoneCelebrationView(
                    milestone: milestone,
                    awardedXP: semanticCelebrationXP,
                    isPresented: $showMilestone
                )
            }
        }
        .accessibilityIdentifier("home.view")
        .overlay(alignment: .bottom) {
            if showsBottomBar {
                homeBottomBar
            }
        }
        .taskerSnackbar($snackbar)
        .onAppear {
            if let forcedFaceValue {
                activeFace = forcedFaceValue
            }
            isHomeVisible = true
            hasAutoFocusedSearchField = false
            rebuildProjectCaches(viewModel.projects)
            rebuildTagCache(viewModel.tags)
            rebuildRescueTasksCache(
                overdueTasks: viewModel.overdueTasks,
                morningTasks: viewModel.morningTasks,
                eveningTasks: viewModel.eveningTasks,
                triageQueue: viewModel.evaTriageQueue
            )
            searchState.configureIfNeeded {
                LGHomeSearchEngine(viewModel: viewModel.makeHomeSearchViewModel())
            }
            bottomBarState.select(activeFace.selectedBottomBarItem)
            refreshReflectionClaimState()
            triggerForedropHintIfEligible()
        }
        .onDisappear {
            isHomeVisible = false
            cancelForedropHintAnimation()
            searchState.deactivate()
        }
        .onChange(of: activeFace) { _, newValue in
            bottomBarState.select(newValue.selectedBottomBarItem)
            forcedFace?.wrappedValue = newValue
            if newValue == .search {
                searchState.activate()
                if HomeSearchFocusPolicyResolver.shouldAutoFocusOnSearchEntry(layoutClass: layoutClass),
                   hasAutoFocusedSearchField == false {
                    hasAutoFocusedSearchField = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        isSearchFieldFocused = true
                    }
                } else if layoutClass.isPad && V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled {
                    logWarning(
                        event: "ipadSearchAutoFocusSkipped",
                        message: "Skipped implicit search field autofocus on iPad tab switch"
                    )
                }
                return
            }
            isSearchFieldFocused = false
            if newValue != .search {
                searchState.deactivate()
            }
        }
        .onReceive(viewModel.$projects.receive(on: RunLoop.main)) { projects in
            rebuildProjectCaches(projects)
        }
        .onReceive(viewModel.$tags.receive(on: RunLoop.main)) { tags in
            rebuildTagCache(tags)
        }
        .onReceive(
            Publishers.CombineLatest4(
                viewModel.$overdueTasks,
                viewModel.$morningTasks,
                viewModel.$eveningTasks,
                viewModel.$evaTriageQueue
            )
            .receive(on: RunLoop.main)
        ) { overdueTasks, morningTasks, eveningTasks, triageQueue in
            rebuildRescueTasksCache(
                overdueTasks: overdueTasks,
                morningTasks: morningTasks,
                eveningTasks: eveningTasks,
                triageQueue: triageQueue
            )
        }
        .onChange(of: forcedFaceValue) { _, newValue in
            guard let newValue, newValue != activeFace else { return }
            if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
                withAnimation(.easeInOut(duration: 0.12)) {
                    activeFace = newValue
                }
            } else {
                withAnimation(foredropFlipAnimation) {
                    activeFace = newValue
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            triggerForedropHintIfEligible()
        }
        .onReceive(viewModel.$lastXPResult.receive(on: RunLoop.main)) { result in
            handleXPResult(result)
        }
        .onReceive(viewModel.$insightsLaunchRequest.receive(on: RunLoop.main)) { request in
            handleInsightsLaunchRequest(request)
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
                projectsByID: projectsByIDCache,
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
                tasksByID: rescueTasksByIDCache,
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
                claimState: reflectionClaimState,
                onComplete: {
                    reflectionClaimState = .submitting
                    viewModel.completeDailyReflection { result in
                        switch result {
                        case .success(let xpResult):
                            if xpResult.awardedXP > 0 {
                                reflectionClaimState = .claimed(xp: xpResult.awardedXP)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    showReflectionSheet = false
                                }
                            } else {
                                reflectionClaimState = .alreadyClaimed
                            }
                        case .failure(let error):
                            reflectionClaimState = .unavailable(message: error.localizedDescription)
                        }
                    }
                }
            )
        }
    }

    /// Executes triggerForedropHintIfEligible.
    private func triggerForedropHintIfEligible(now: Date = Date()) {
        if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
            logWarning(
                event: "ipadForedropHintSuppressed",
                message: "Suppressed decorative foredrop hint animation on iPad"
            )
            return
        }

        let canTrigger = HomeForedropHintEligibility.canTrigger(
            isHomeVisible: isHomeVisible,
            foredropAnchor: foredropAnchorForHint,
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
                        WeeklyCalendarStripView(
                            selectedDate: Binding(
                                get: { viewModel.selectedDate },
                                set: { viewModel.selectDate($0) }
                            ),
                            todayDate: Date()
                        )
                        .padding(.horizontal, spacing.s16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(isBackFaceVisible ? 0.001 : 1)
                    }
                }
            Spacer(minLength: 0)
        }
    }

    /// Executes foredropLayer.
    private func foredropLayer(geometry: GeometryProxy, taskListBottomInset: CGFloat) -> some View {
        ZStack {
            if activeFace == .tasks {
                foredropFrontFace(taskListBottomInset: taskListBottomInset)
                    .transition(foredropFlipTransition)
                    .zIndex(1)
            } else if activeFace == .analytics {
                foredropAnalyticsFace(geometry: geometry)
                    .transition(foredropFlipTransition)
                    .zIndex(1)
            } else {
                foredropSearchFace(taskListBottomInset: taskListBottomInset)
                    .transition(foredropFlipTransition)
                    .zIndex(1)
            }
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
        .accessibilityValue(activeFace.surfaceAccessibilityValue)
        .animation(foredropFlipAnimation, value: activeFace)
    }

    private var handleBar: some View {
        VStack(spacing: spacing.s4) {
            Capsule()
                .fill(Color.tasker.textQuaternary.opacity(0.4))
                .frame(width: 44, height: 5)
                .accessibilityIdentifier("home.foredrop.handle")
        }
    }

    private func foredropFrontFace(taskListBottomInset: CGFloat) -> some View {
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
                tagNameByID: tagNameByIDCache,
                activeQuickView: viewModel.activeScope.quickView,
                todayXPSoFar: (V2FeatureFlags.gamificationV2Enabled && viewModel.progressState.todayTargetXP <= 0) ? nil : viewModel.progressState.earnedXP,
                isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
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
    }

    private func foredropAnalyticsFace(geometry: GeometryProxy) -> some View {
        VStack(spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                Text("Analytics")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                Spacer()
                Button {
                    returnToTasks(source: "back_chip")
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back to tasks")
                            .font(.tasker(.caption2))
                    }
                    .foregroundColor(Color.tasker.textQuaternary.opacity(0.92))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.foredrop.collapseHint")
                .accessibilityLabel("Back to tasks")
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)

            InsightsTabView(viewModel: insightsViewModel)
                .frame(maxWidth: .infinity)
                .frame(height: chartCardsViewportHeight(for: geometry))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func foredropSearchFace(taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: spacing.s8) {
                Text("Search")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                Spacer()
                Button {
                    returnToTasks(source: "back_chip")
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back to tasks")
                            .font(.tasker(.caption2))
                    }
                    .foregroundColor(Color.tasker.textQuaternary.opacity(0.92))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.backChip")
                .accessibilityLabel("Back to tasks")
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s8)

            VStack(alignment: .leading, spacing: spacing.s8) {
                searchStatusChips
                searchPriorityChips
                if !searchState.availableProjects.isEmpty {
                    searchProjectChips
                }
            }
            .padding(.horizontal, spacing.s12)
            .padding(.bottom, spacing.s8)

            Divider()
                .overlay(Color.tasker.strokeHairline)

            if searchState.isLoading && !searchState.hasLoaded {
                VStack(spacing: spacing.s8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading tasks…")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if searchState.shouldShowNoResultsMessage {
                VStack(spacing: spacing.s8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color.tasker.textTertiary)
                    Text(searchState.emptyStateTitle)
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)
                        .accessibilityIdentifier("search.emptyStateLabel")
                    Text(searchState.emptyStateSubtitle)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, spacing.s16)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: spacing.s12) {
                        ForEach(searchState.sections) { section in
                            TaskSectionView(
                                project: searchProject(for: section.projectName),
                                tasks: section.tasks,
                                tagNameByID: tagNameByIDCache,
                                completedCollapsed: false,
                                isTaskDragEnabled: false,
                                onTaskTap: { task in
                                    trackSearchResultOpened(task, projectName: section.projectName)
                                    onTaskTap(task)
                                },
                                onToggleComplete: { task in
                                    trackTaskToggle(task, source: "search_results")
                                    onToggleComplete(task)
                                    refreshSearchAfterMutation()
                                },
                                onDeleteTask: { task in
                                    onDeleteTask(task)
                                    refreshSearchAfterMutation()
                                },
                                onRescheduleTask: { task in
                                    onRescheduleTask(task)
                                    refreshSearchAfterMutation()
                                }
                            )
                        }
                        Spacer()
                            .frame(height: taskListBottomInset)
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s8)
                    .padding(.bottom, spacing.s8)
                }
                .accessibilityIdentifier("search.resultsList")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.view")
    }

    private func topNavigationBar() -> some View {
        if isSearchOpen {
            return AnyView(searchTopBackdropBar)
        }
        return AnyView(defaultTopNavigationBar)
    }

    private var defaultTopNavigationBar: some View {
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

                topSearchButton
                topSettingsButton
            }

            momentumHUD
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, 0)
        .padding(.bottom, spacing.s8)
    }

    private var searchTopBackdropBar: some View {
        HStack(spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.tasker.textSecondary)

                TextField(
                    "Search tasks...",
                    text: Binding(
                        get: { searchState.query },
                        set: { newValue in
                            searchState.updateQuery(newValue)
                            trackSearchQueryChanged(newValue)
                        }
                    )
                )
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textPrimary)
                .accessibilityIdentifier("search.searchField")

                if !searchState.query.isEmpty {
                    Button {
                        searchState.clearQuery()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search.clearButton")
                    .accessibilityLabel("Clear Search")
                }
            }
            .padding(.horizontal, spacing.s12)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(0.96))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.tasker.strokeHairline.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s4)
        .padding(.bottom, spacing.s8)
    }

    private var topSearchButton: some View {
        Button {
            openSearch(source: "top_nav_search")
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

    private var searchStatusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(HomeSearchStatusFilter.allCases) { status in
                    searchChipButton(
                        title: status.title,
                        isSelected: searchState.selectedStatus == status,
                        accessibilityIdentifier: status.accessibilityIdentifier
                    ) {
                        searchState.setStatus(status)
                        trackSearchChipToggled(kind: "status", value: status.analyticsName, isSelected: true)
                    }
                }
            }
            .padding(.horizontal, spacing.s4)
        }
    }

    private var searchPriorityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(TaskPriorityConfig.Priority.allCases, id: \.rawValue) { priority in
                    let isSelected = searchState.selectedPriorities.contains(priority.rawValue)
                    searchChipButton(
                        title: priority.code,
                        isSelected: isSelected,
                        tintColor: Color(uiColor: priority.color),
                        accessibilityIdentifier: "search.priority.\(priority.code.lowercased())"
                    ) {
                        searchState.togglePriority(priority)
                        trackSearchChipToggled(
                            kind: "priority",
                            value: priority.code.lowercased(),
                            isSelected: !isSelected
                        )
                    }
                }
            }
            .padding(.horizontal, spacing.s4)
        }
    }

    private var searchProjectChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(searchState.availableProjects, id: \.self) { projectName in
                    let isSelected = searchState.selectedProjects.contains(projectName)
                    searchChipButton(
                        title: projectName,
                        isSelected: isSelected,
                        accessibilityIdentifier: "search.project.\(searchIdentifierToken(projectName))"
                    ) {
                        searchState.toggleProject(projectName)
                        trackSearchChipToggled(
                            kind: "project",
                            value: projectName,
                            isSelected: !isSelected
                        )
                    }
                }
            }
            .padding(.horizontal, spacing.s4)
        }
    }

    private func searchChipButton(
        title: String,
        isSelected: Bool,
        tintColor: Color? = nil,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        let resolvedTintColor = tintColor ?? Color.tasker.accentPrimary
        return Button(action: action) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(isSelected ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s4)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? resolvedTintColor.opacity(0.25)
                                : Color.tasker.surfaceSecondary
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    isSelected
                                        ? resolvedTintColor.opacity(0.55)
                                        : Color.tasker.strokeHairline.opacity(0.35),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityValue(isSelected ? "selected" : "unselected")
    }

    private func searchProject(for name: String) -> Project {
        if let resolved = projectsByNameCache[name] {
            return resolved
        }
        if name == ProjectConstants.inboxProjectName {
            return Project.createInbox()
        }
        return Project(name: name)
    }

    private func rebuildProjectCaches(_ projects: [Project]) {
        var byID: [UUID: Project] = [:]
        byID.reserveCapacity(projects.count)

        var byName: [String: Project] = [:]
        byName.reserveCapacity(projects.count + 1)

        for project in projects {
            byID[project.id] = project
            byName[project.name] = project
        }

        let inbox = Project.createInbox()
        byName[ProjectConstants.inboxProjectName] = inbox

        projectsByIDCache = byID
        projectsByNameCache = byName
    }

    private func rebuildTagCache(_ tags: [TagDefinition]) {
        var tagMap: [UUID: String] = [:]
        tagMap.reserveCapacity(tags.count)
        for tag in tags {
            tagMap[tag.id] = tag.name
        }
        tagNameByIDCache = tagMap
    }

    private func rebuildRescueTasksCache(
        overdueTasks: [TaskDefinition],
        morningTasks: [TaskDefinition],
        eveningTasks: [TaskDefinition],
        triageQueue: [EvaTriageQueueItem]
    ) {
        let combinedTasks = overdueTasks + morningTasks + eveningTasks + triageQueue.map(\.task)
        var taskMap: [UUID: TaskDefinition] = [:]
        taskMap.reserveCapacity(combinedTasks.count)
        for task in combinedTasks {
            taskMap[task.id] = task
        }
        rescueTasksByIDCache = taskMap
    }

    private func searchIdentifierToken(_ rawValue: String) -> String {
        rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private func refreshSearchAfterMutation() {
        searchState.markDataMutated()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            searchState.refresh(immediate: true)
        }
    }

    private func trackSearchQueryChanged(_ query: String) {
        let now = Date()
        if let lastSearchQueryTelemetryAt, now.timeIntervalSince(lastSearchQueryTelemetryAt) < 0.7 {
            return
        }
        lastSearchQueryTelemetryAt = now
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.trackHomeInteraction(
            action: "home_search_query_changed",
            metadata: [
                "length": trimmed.count,
                "has_query": trimmed.isEmpty ? "false" : "true"
            ]
        )
    }

    private func trackSearchChipToggled(kind: String, value: String, isSelected: Bool) {
        viewModel.trackHomeInteraction(
            action: "home_search_chip_toggled",
            metadata: [
                "kind": kind,
                "value": value,
                "selected": isSelected ? "true" : "false"
            ]
        )
    }

    private func trackSearchResultOpened(_ task: TaskDefinition, projectName: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_result_opened",
            metadata: [
                "task_id": task.id.uuidString,
                "project": projectName
            ]
        )
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

    private var momentumHUD: some View {
        let progress = viewModel.progressState
        let denominator = max(1, progress.todayTargetXP)
        let progressRatio = min(1, Double(progress.earnedXP) / Double(denominator))
        let completionPercent = Int((viewModel.completionRate * 100).rounded())

        return VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s12) {
                NavPieChart(
                    score: viewModel.dailyScore,
                    maxScore: viewModel.progressState.todayTargetXP,
                    accessibilityContainerID: "home.navXpPieChart",
                    accessibilityButtonID: "home.navXpPieChart.button"
                ) {
                    toggleInsights(source: "nav_xp_chart")
                }
                .background(
                    Circle()
                        .fill(topNavGlassCircleColor)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(progress.earnedXP)/\(progress.todayTargetXP) XP")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textPrimary)
                        .accessibilityIdentifier("home.dailyScoreLabel")
                        .lineLimit(1)

                    HStack(spacing: spacing.s8) {
                        Text("\(completionPercent)% complete")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .accessibilityIdentifier("home.completionRateLabel")
                            .lineLimit(1)

                        streakIndicator(for: progress)
                            .accessibilityIdentifier("home.streakLabel")
                    }
                }

                Spacer(minLength: spacing.s4)

                if reflectionEligible {
                    Button("Reflection") {
                        openReflectionSheet()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.tasker.accentPrimary)
                    .accessibilityIdentifier("home.reflectionChip")
                }
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
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.7), value: progressRatio)

            Text(momentumGuidanceText)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(
            RoundedRectangle(cornerRadius: corner.card)
                .fill(Color.tasker.surfaceSecondary.opacity(0.9))
        )
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
                .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: !progress.isStreakSafeToday && !reduceMotion)

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
            onHome: {
                returnToTasks(source: "bottom_bar_home")
            },
            onChartsToggle: {
                toggleInsights(source: "bottom_bar_analytics")
            },
            onSearch: {
                toggleSearch(source: "bottom_bar_search")
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
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    private var reflectionEligible: Bool {
        viewModel.activeScope.quickView == .today && !viewModel.isDailyReflectionCompletedToday()
    }

    private var momentumGuidanceText: String {
        let progress = viewModel.progressState
        if !progress.isStreakSafeToday {
            return "Complete 1 more task to keep your streak safe."
        }
        if progress.earnedXP < progress.todayTargetXP {
            return "Complete another task to keep building XP."
        }
        if viewModel.todayOpenTaskCount > 0 {
            return "Daily goal hit. Keep momentum with one more completion."
        }
        return "Daily board clear. Add a task to keep momentum rolling."
    }

    private func handleXPResult(_ result: XPEventResult?) {
        guard let result, let event = CelebrationEvent.from(result) else { return }
        guard let routed = celebrationRouter.route(event: event) else { return }
        let routedEvent = routed.event
        semanticCelebrationXP = routedEvent.awardedXP

        switch routedEvent.kind {
        case .milestone:
            if let milestone = routedEvent.milestone {
                milestoneValue = milestone
                showMilestone = true
            }
        case .levelUp:
            levelUpValue = routedEvent.level
            showLevelUp = true
        case .achievementUnlock:
            if V2FeatureFlags.gamificationOverhaulV1Enabled {
                showAchievementUnlockToast(for: routedEvent)
            } else {
                xpBurstValue = routedEvent.awardedXP
                showXPBurst = true
            }
        case .xpBurst:
            xpBurstValue = routedEvent.awardedXP
            showXPBurst = true
        }

        if routedEvent.awardedXP >= 7 {
            TaskerFeedback.success()
        } else if routedEvent.awardedXP >= 4 {
            TaskerFeedback.medium()
        } else {
            TaskerFeedback.light()
        }

        viewModel.trackHomeInteraction(
            action: "home_reward_xp_burst",
            metadata: ["delta": routedEvent.awardedXP, "new_score": viewModel.dailyScore, "kind": routedEvent.kind.rawValue]
        )
    }

    private func toggleInsights(source: String) {
        let shouldOpenInsights = activeFace != .analytics
        if shouldOpenInsights {
            openAnalytics(source: source, launchDefaultInsights: true)
        } else {
            closeAnalytics(source: source)
        }
    }

    private func handleInsightsLaunchRequest(_ request: InsightsLaunchRequest?) {
        guard let request else { return }
        openAnalytics(source: "launch_request", launchDefaultInsights: false)
        insightsViewModel.selectTab(request.targetTab)
        insightsViewModel.highlightAchievement(request.highlightedAchievementKey)
    }

    private func openAnalytics(source: String, launchDefaultInsights: Bool) {
        guard activeFace != .analytics else { return }
        if activeFace == .search {
            trackSearchFlipClose(source: "analytics_switch")
        }
        withAnimation(foredropFlipAnimation) {
            activeFace = .analytics
        }
        bottomBarState.select(activeFace.selectedBottomBarItem)
        viewModel.trackHomeInteraction(
            action: "home_insights_flip_open",
            metadata: ["source": source]
        )
        if launchDefaultInsights {
            viewModel.launchInsights(.default)
        }
    }

    private func closeAnalytics(source: String) {
        guard activeFace == .analytics else { return }
        withAnimation(foredropFlipAnimation) {
            activeFace = .tasks
        }
        bottomBarState.select(activeFace.selectedBottomBarItem)
        viewModel.trackHomeInteraction(
            action: "home_insights_flip_close",
            metadata: ["source": source]
        )
    }

    private func toggleSearch(source: String) {
        let shouldOpenSearch = activeFace != .search
        if shouldOpenSearch {
            openSearch(source: source)
        } else {
            closeSearch(source: source)
        }
    }

    private func openSearch(source: String) {
        guard activeFace != .search else { return }
        if activeFace == .analytics {
            viewModel.trackHomeInteraction(
                action: "home_insights_flip_close",
                metadata: ["source": "analytics_switch"]
            )
        }
        withAnimation(foredropFlipAnimation) {
            activeFace = .search
        }
        bottomBarState.select(activeFace.selectedBottomBarItem)
        trackSearchFlipOpen(source: source)
    }

    private func closeSearch(source: String) {
        guard activeFace == .search else { return }
        withAnimation(foredropFlipAnimation) {
            activeFace = .tasks
        }
        bottomBarState.select(activeFace.selectedBottomBarItem)
        trackSearchFlipClose(source: source)
    }

    private func returnToTasks(source: String) {
        switch activeFace {
        case .tasks:
            bottomBarState.select(HomeForedropFace.tasks.selectedBottomBarItem)
        case .analytics:
            closeAnalytics(source: source)
        case .search:
            closeSearch(source: source)
        }
    }

    private func trackSearchFlipOpen(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_open",
            metadata: ["source": source]
        )
    }

    private func trackSearchFlipClose(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_close",
            metadata: ["source": source]
        )
    }

    private func showAchievementUnlockToast(for event: CelebrationEvent) {
        guard let achievementKey = event.achievementKey else { return }
        guard !shownUnlockKeys.contains(achievementKey) else { return }
        shownUnlockKeys.insert(achievementKey)

        let badgeName = AchievementCatalog.definition(for: achievementKey)?.name ?? "Badge"
        snackbar = SnackbarData(
            message: "Achievement unlocked: \(badgeName)",
            actions: [
                SnackbarAction(title: "View badge") {
                    viewModel.launchInsights(
                        InsightsLaunchRequest(
                            targetTab: .systems,
                            highlightedAchievementKey: achievementKey
                        )
                    )
                }
            ]
        )
    }

    private func refreshReflectionClaimState() {
        reflectionClaimState = viewModel.isDailyReflectionCompletedToday() ? .alreadyClaimed : .ready
    }

    private func openReflectionSheet() {
        refreshReflectionClaimState()
        showReflectionSheet = true
    }
}

enum HomeiPadDestination: String, CaseIterable, Identifiable {
    case tasks
    case search
    case analytics
    case addTask
    case settings
    case projects
    case chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "Tasks"
        case .search: return "Search"
        case .analytics: return "Analytics"
        case .addTask: return "Add Task"
        case .settings: return "Settings"
        case .projects: return "Projects"
        case .chat: return "Eva"
        }
    }

    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .search: return "magnifyingglass"
        case .analytics: return "chart.bar.xaxis"
        case .addTask: return "plus.circle"
        case .settings: return "gearshape"
        case .projects: return "folder"
        case .chat: return "sparkles"
        }
    }

    var homeFace: HomeForedropFace? {
        switch self {
        case .tasks: return .tasks
        case .search: return .search
        case .analytics: return .analytics
        case .addTask, .settings, .projects, .chat: return nil
        }
    }

    var isPrimaryHomeDestination: Bool {
        homeFace != nil
    }
}

@MainActor
enum HomeiPadModalRequest: Equatable {
    case addTask
}

@MainActor
final class HomeiPadShellState: ObservableObject {
    @Published var destination: HomeiPadDestination = .tasks
    @Published var selectedTask: TaskDefinition?
    @Published var modalRequest: HomeiPadModalRequest?
}

// MARK: - iPad Sidebar Sections

enum HomeiPadSidebarSection: String, CaseIterable, Identifiable {
    case primary
    case create
    case manage

    var id: String { rawValue }

    var title: String? {
        switch self {
        case .primary: return nil
        case .create: return "Create"
        case .manage: return "Manage"
        }
    }

    var destinations: [HomeiPadDestination] {
        switch self {
        case .primary: return [.tasks, .search, .analytics]
        case .create: return [.addTask]
        case .manage: return [.projects, .settings, .chat]
        }
    }
}

// MARK: - iPad Split Shell

private struct HomeiPadPrimaryPaneHost: View {
    @Binding var activeFace: HomeForedropFace
    let layoutClass: TaskerLayoutClass
    let destination: HomeiPadDestination
    let homeSurface: (Binding<HomeForedropFace>) -> AnyView

    var body: some View {
        homeSurface($activeFace)
            .accessibilityIdentifier("home.ipad.detail.\(destination.rawValue)")
            .onAppear {
                guard layoutClass.isPad, V2FeatureFlags.iPadPerfPrimarySurfacePersistenceV3Enabled else { return }
                logWarning(
                    event: "ipadPrimarySurfaceReused",
                    message: "Reused the persistent iPad primary surface host",
                    fields: ["destination": destination.rawValue]
                )
            }
    }
}

struct HomeiPadSplitShellView: View {
    let layoutClass: TaskerLayoutClass
    @ObservedObject var shellState: HomeiPadShellState
    let homeSurface: (Binding<HomeForedropFace>) -> AnyView
    let addTaskSurface: () -> AnyView
    let settingsSurface: () -> AnyView
    let projectsSurface: () -> AnyView
    let chatSurface: () -> AnyView
    let inspectorSurface: (TaskDefinition) -> AnyView
    let onOpenTaskDetailSheet: (TaskDefinition) -> Void

    @State private var activeHomeFace: HomeForedropFace = .tasks
    @State private var showCompactSidebar = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var isPrimaryHomeDestination: Bool {
        shellState.destination.isPrimaryHomeDestination
    }

    var body: some View {
        shellLayout
            .accessibilityIdentifier("home.ipad.shell")
            .background {
                hiddenKeyboardShortcuts
            }
            .onAppear {
                if let face = shellState.destination.homeFace {
                    activeHomeFace = face
            }
        }
        .onChange(of: shellState.destination) { _, newValue in
            if newValue.isPrimaryHomeDestination {
                logWarning(
                    event: "ipadPrimaryDestinationSwitchStart",
                    message: "Switched iPad primary destination",
                    fields: ["destination": newValue.rawValue]
                )
            }
            if newValue == .addTask, layoutClass != .padExpanded {
                shellState.modalRequest = .addTask
                shellState.destination = .tasks
                return
            }
            if let face = newValue.homeFace {
                activeHomeFace = face
            } else {
                shellState.selectedTask = nil
            }
        }
        .onChange(of: activeHomeFace) {
            handleActiveHomeFaceChange()
        }
    }

    private var shellLayout: AnyView {
        if layoutClass == .padCompact {
            return AnyView(compactShell)
        }
        if layoutClass == .padExpanded {
            return AnyView(expandedShell)
        }
        return AnyView(regularShell)
    }

    private var compactShell: some View {
        NavigationStack {
            detailContent
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        compactSidebarToggle
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
        }
        .sheet(isPresented: $showCompactSidebar) {
            compactSidebarSheet
        }
    }

    private var expandedShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } content: {
            detailContent
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
                .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: .infinity)
        } detail: {
            inspectorPanel
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
                .background(Color.tasker.bgElevated)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var regularShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } detail: {
            detailContent
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }

    private var hiddenKeyboardShortcuts: some View {
        Group {
            Button("") { shellState.destination = .search }
                .keyboardShortcut("f", modifiers: .command)
            Button("") { shellState.destination = .tasks }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { shellState.destination = .analytics }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { shellState.destination = .settings }
                .keyboardShortcut(",", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }

    private func analyticsName(for face: HomeForedropFace) -> String {
        switch face {
        case .tasks:
            return "tasks"
        case .analytics:
            return "analytics"
        case .search:
            return "search"
        }
    }

    private func handleActiveHomeFaceChange() {
        let newValue = activeHomeFace
        if layoutClass.isPad && V2FeatureFlags.iPadPerfPrimarySurfacePersistenceV3Enabled {
            logWarning(
                event: "ipadPrimaryDestinationSwitchEnd",
                message: "Completed iPad primary destination switch",
                fields: ["face": analyticsName(for: newValue)]
            )
        }
        let nextDestination = destination(for: newValue)
        if shellState.destination != nextDestination {
            shellState.destination = nextDestination
        }
    }

    // MARK: - Toolbar Items

    @ViewBuilder
    private var detailToolbarItems: some View {
        if isPrimaryHomeDestination {
            Button {
                if layoutClass == .padExpanded {
                    shellState.destination = .addTask
                } else {
                    shellState.modalRequest = .addTask
                }
            } label: {
                Image(systemName: "plus")
            }
            .hoverEffect(.highlight)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityIdentifier("home.ipad.toolbar.addTask")
            .accessibilityLabel("New Task")
        }
    }

    // MARK: - Compact Sidebar Toggle

    private var compactSidebarToggle: some View {
        Button {
            showCompactSidebar = true
        } label: {
            Label(shellState.destination.title, systemImage: "sidebar.left")
                .labelStyle(.titleAndIcon)
                .frame(minWidth: 44, minHeight: 44)
        }
        .hoverEffect(.highlight)
        .accessibilityIdentifier("home.ipad.sidebar.toggle")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: Binding<HomeiPadDestination?>(
            get: { shellState.destination },
            set: { newValue in
                if let newValue { shellState.destination = newValue }
            }
        )) {
            ForEach(HomeiPadSidebarSection.allCases) { section in
                Section {
                    ForEach(section.destinations) { dest in
                        Label(dest.title, systemImage: dest.icon)
                            .tag(dest)
                            .hoverEffect(.highlight)
                            .accessibilityIdentifier("home.ipad.destination.\(dest.rawValue)")
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.tasker.bgCanvas)
        .navigationTitle("Tasker")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
        .accessibilityIdentifier("home.ipad.sidebar")
    }

    private var sidebarFooter: some View {
        VStack(spacing: spacing.s4) {
            Divider()
            Text("Tasker v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textQuaternary)
                .padding(.vertical, spacing.s8)
        }
        .padding(.horizontal, spacing.s16)
    }

    // MARK: - Compact Sidebar Sheet

    private var compactSidebarSheet: some View {
        NavigationStack {
            List {
                ForEach(HomeiPadSidebarSection.allCases) { section in
                    Section {
                        ForEach(section.destinations) { dest in
                            Button {
                                shellState.destination = dest
                                showCompactSidebar = false
                            } label: {
                                Label(dest.title, systemImage: dest.icon)
                            }
                            .hoverEffect(.highlight)
                            .accessibilityIdentifier("home.ipad.compact.destination.\(dest.rawValue)")
                        }
                    } header: {
                        if let title = section.title {
                            Text(title)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Navigate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showCompactSidebar = false
                    }
                }
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch shellState.destination {
        case .tasks, .search, .analytics:
            HomeiPadPrimaryPaneHost(
                activeFace: $activeHomeFace,
                layoutClass: layoutClass,
                destination: shellState.destination,
                homeSurface: homeSurface
            )
        case .addTask:
            if layoutClass == .padExpanded {
                addTaskSurface()
                    .accessibilityIdentifier("home.ipad.detail.addTask")
            } else {
                HomeiPadPrimaryPaneHost(
                    activeFace: $activeHomeFace,
                    layoutClass: layoutClass,
                    destination: .tasks,
                    homeSurface: homeSurface
                )
            }
        case .settings:
            settingsSurface()
                .accessibilityIdentifier("home.ipad.detail.settings")
        case .projects:
            projectsSurface()
                .accessibilityIdentifier("home.ipad.detail.projects")
        case .chat:
            chatSurface()
                .accessibilityIdentifier("home.ipad.detail.chat")
        }
    }

    // MARK: - Inspector Panel

    @ViewBuilder
    private var inspectorPanel: some View {
        if let task = shellState.selectedTask {
            NavigationStack {
                inspectorSurface(task)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text(task.title)
                                .font(.tasker(.headline))
                                .foregroundColor(Color.tasker.textPrimary)
                                .lineLimit(1)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                onOpenTaskDetailSheet(task)
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            .hoverEffect(.highlight)
                            .accessibilityLabel("Expand to sheet")
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .id(task.id)
            .accessibilityIdentifier("home.ipad.inspector.task")
        } else {
            VStack(spacing: spacing.s16) {
                Image(systemName: "rectangle.righthalf.inset.filled")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(Color.tasker.accentMuted)
                Text("No task selected")
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textSecondary)
                Text("Tap a task in the list to see its details here.")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.tasker.bgCanvas)
            .accessibilityIdentifier("home.ipad.inspector.empty")
        }
    }

    private func destination(for face: HomeForedropFace) -> HomeiPadDestination {
        switch face {
        case .tasks:
            return .tasks
        case .analytics:
            return .analytics
        case .search:
            return .search
        }
    }
}

struct HomeiPadSettingsContainer: View {
    let onNavigateToProjects: () -> Void
    let onNavigateToChats: () -> Void
    let onNavigateToModels: () -> Void

    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            SettingsRootView(viewModel: viewModel)
                .onAppear {
                    viewModel.onNavigateToProjects = onNavigateToProjects
                    viewModel.onNavigateToChats = onNavigateToChats
                    viewModel.onNavigateToModels = onNavigateToModels
                }
        }
        .accessibilityIdentifier("home.ipad.detail.settings")
    }
}
