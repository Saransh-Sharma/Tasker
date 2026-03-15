import SwiftUI

struct EvaFocusWhySheetView: View {
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
