import SwiftUI

struct EvaFocusWhySheetView: View {
    let focusTasks: [TaskDefinition]
    let shuffleCandidates: [TaskDefinition]
    let insightProvider: (UUID) -> EvaFocusTaskInsight?
    let onToggleComplete: (TaskDefinition) -> Void
    let onStartFocus: (TaskDefinition) -> Void
    let onShuffleCandidates: () -> Void
    let onReplaceFocusTask: (TaskDefinition, TaskDefinition) -> Void

    @State private var expandedTaskIDs = Set<UUID>()
    @State private var selectedCandidateID: UUID?

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var selectedCandidate: TaskDefinition? {
        guard let selectedCandidateID else { return nil }
        return shuffleCandidates.first(where: { $0.id == selectedCandidateID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tasker.bgCanvas
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: spacing.s16) {
                        headerCard
                        shuffleTrayCard
                        currentFocusSection
                    }
                }
                .padding(.horizontal, spacing.s12)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s20)
            }
            .navigationTitle("Why Eva Picked These")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: shuffleCandidates.map(\.id)) { availableIDs in
            if let selectedCandidateID, availableIDs.contains(selectedCandidateID) == false {
                self.selectedCandidateID = nil
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Why Eva Picked These")
                .font(.tasker(.title3).weight(.semibold))
                .foregroundColor(Color.tasker.textPrimary)

            Text("Focus Now stays small on Home. This sheet explains the picks, lets you complete them, start a timer, and preview alternatives before swapping anything out.")
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(accentOpacity: 0.18))
    }

    private var shuffleTrayCard: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .center, spacing: spacing.s8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shuffle View")
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundColor(Color.tasker.textPrimary)

                    Text(selectedCandidate == nil
                         ? "Preview fresh replacements without changing Focus Now yet."
                         : "Pick which Focus Now task should be swapped out.")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                Button(action: {
                    selectedCandidateID = nil
                    onShuffleCandidates()
                }) {
                    Text("Shuffle Again")
                        .font(.tasker(.caption1).weight(.medium))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.tasker.surfaceSecondary)
                        )
                }
                .buttonStyle(.plain)
            }

            if shuffleCandidates.isEmpty {
                Text("No new candidates are available right now. Finish or shuffle Focus Now on Home to refresh the pool.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                    .padding(.top, spacing.s2)
            } else {
                VStack(spacing: spacing.s8) {
                    ForEach(shuffleCandidates, id: \.id) { candidate in
                        let presentation = EvaFocusWhyCandidatePresentation.make(
                            task: candidate,
                            insight: insightProvider(candidate.id)
                        )
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                selectedCandidateID = candidate.id
                            }
                        } label: {
                            EvaFocusShuffleCandidateRow(
                                presentation: presentation,
                                isSelected: selectedCandidateID == candidate.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selectedCandidate {
                Divider()
                    .overlay(Color.tasker.strokeHairline.opacity(0.8))
                    .padding(.vertical, spacing.s2)

                Text("Replace With \(selectedCandidate.title)")
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundColor(Color.tasker.textPrimary)

                VStack(spacing: spacing.s8) {
                    ForEach(focusTasks, id: \.id) { focusTask in
                        Button {
                            onReplaceFocusTask(selectedCandidate, focusTask)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                selectedCandidateID = nil
                            }
                        } label: {
                            replaceTargetRow(for: focusTask)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Cancel Replacement") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedCandidateID = nil
                    }
                }
                .font(.tasker(.caption1).weight(.medium))
                .foregroundColor(Color.tasker.textSecondary)
                .buttonStyle(.plain)
                .padding(.top, spacing.s2)
            }
        }
        .padding(spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(accentOpacity: 0.12))
    }

    private var currentFocusSection: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Current Focus Now")
                .font(.tasker(.callout).weight(.semibold))
                .foregroundColor(Color.tasker.textPrimary)

            if focusTasks.isEmpty {
                Text("Focus Now is empty right now.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                    .padding(spacing.s12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground(accentOpacity: 0.10))
            } else {
                VStack(spacing: spacing.s8) {
                    ForEach(focusTasks, id: \.id) { task in
                        EvaFocusWhyTaskCard(
                            presentation: EvaFocusWhyTaskCardPresentation.make(
                                task: task,
                                insight: insightProvider(task.id)
                            ),
                            isExpanded: expandedTaskIDs.contains(task.id),
                            onToggleComplete: { onToggleComplete(task) },
                            onStartFocus: { onStartFocus(task) },
                            onToggleExpanded: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                    if expandedTaskIDs.contains(task.id) {
                                        expandedTaskIDs.remove(task.id)
                                    } else {
                                        expandedTaskIDs.insert(task.id)
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func replaceTargetRow(for task: TaskDefinition) -> some View {
        let metadata = FocusZoneSecondaryLineResolver.resolve(task: task)

        return HStack(alignment: .center, spacing: spacing.s8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.tasker(.callout).weight(.semibold))
                    .foregroundColor(Color.tasker.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let context = metadata.text {
                    Text(context)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.tasker.accentPrimary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.tasker.surfaceSecondary)
                )
        }
        .padding(.horizontal, spacing.s8)
        .padding(.vertical, spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                .fill(Color.tasker.surfaceSecondary.opacity(0.66))
        )
    }

    private func cardBackground(accentOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
            .fill(Color.tasker.surfacePrimary.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.92), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.tasker.accentPrimary.opacity(accentOpacity))
                    .frame(width: 40, height: 3)
                    .padding(.horizontal, spacing.s12)
                    .padding(.top, 1)
            }
    }
}

struct EvaFocusWhyTaskCardPresentation: Equatable {
    let title: String
    let contextText: String?
    let summaryText: String
    let reasonLines: [String]
    let isComplete: Bool

    static func make(task: TaskDefinition, insight: EvaFocusTaskInsight?) -> EvaFocusWhyTaskCardPresentation {
        let metadata = FocusZoneSecondaryLineResolver.resolve(task: task)
        let rationale = insight?.rationale.map(\.label).filter { !$0.isEmpty } ?? []
        let summaryText = rationale.first ?? "Eva selected this using urgency and effort balance."

        return EvaFocusWhyTaskCardPresentation(
            title: task.title,
            contextText: metadata.text,
            summaryText: summaryText,
            reasonLines: rationale,
            isComplete: task.isComplete
        )
    }
}

struct EvaFocusWhyCandidatePresentation: Equatable {
    let title: String
    let contextText: String?
    let summaryText: String

    static func make(task: TaskDefinition, insight: EvaFocusTaskInsight?) -> EvaFocusWhyCandidatePresentation {
        let metadata = FocusZoneSecondaryLineResolver.resolve(task: task)
        let summaryText = insight?.rationale.first?.label ?? "Swap into Focus Now"

        return EvaFocusWhyCandidatePresentation(
            title: task.title,
            contextText: metadata.text,
            summaryText: summaryText
        )
    }
}

private struct EvaFocusWhyTaskCard: View {
    let presentation: EvaFocusWhyTaskCardPresentation
    let isExpanded: Bool
    let onToggleComplete: () -> Void
    let onStartFocus: () -> Void
    let onToggleExpanded: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .top, spacing: spacing.s8) {
                CompletionCheckbox(isComplete: presentation.isComplete, compact: true) {
                    onToggleComplete()
                }
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundColor(presentation.isComplete ? Color.tasker.textSecondary : Color.tasker.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let contextText = presentation.contextText {
                        Text(contextText)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onStartFocus) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(presentation.isComplete ? Color.tasker.textTertiary : Color.tasker.accentPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.tasker.surfaceSecondary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(presentation.isComplete)
                .accessibilityLabel("Start focus session")
            }

            Button(action: onToggleExpanded) {
                HStack(alignment: .center, spacing: spacing.s4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.tasker.accentPrimary.opacity(0.85))

                    Text(presentation.summaryText)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(isExpanded ? "Less" : "More")
                        .font(.tasker(.caption2).weight(.semibold))
                        .foregroundColor(Color.tasker.accentPrimary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(presentation.reasonLines.isEmpty ? [presentation.summaryText] : presentation.reasonLines, id: \.self) { line in
                        Text("• \(line)")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, spacing.s8)
        .padding(.vertical, spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                .fill(Color.tasker.surfacePrimary.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                        .stroke(Color.tasker.strokeHairline.opacity(0.9), lineWidth: 1)
                )
        )
        .opacity(presentation.isComplete ? 0.68 : 1)
    }
}

private struct EvaFocusShuffleCandidateRow: View {
    let presentation: EvaFocusWhyCandidatePresentation
    let isSelected: Bool

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        HStack(alignment: .center, spacing: spacing.s8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(.tasker(.callout).weight(.semibold))
                    .foregroundColor(Color.tasker.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let contextText = presentation.contextText {
                    Text(contextText)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(1)
                }

                Text(presentation.summaryText)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
        }
        .padding(.horizontal, spacing.s8)
        .padding(.vertical, spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                .fill(isSelected ? Color.tasker.surfaceSecondary.opacity(0.9) : Color.tasker.surfaceSecondary.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                        .stroke(
                            isSelected ? Color.tasker.accentPrimary.opacity(0.28) : Color.tasker.strokeHairline.opacity(0.82),
                            lineWidth: 1
                        )
                )
        )
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
        NavigationStack {
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
        NavigationStack {
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
