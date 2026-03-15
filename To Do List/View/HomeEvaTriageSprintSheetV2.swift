import SwiftUI

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

struct EvaTriageSprintSheetV2: View {
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
    @State private var completionAppeared = false
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
        triageBody
    }

    private var triageBody: some View {
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
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                Text("Card \(min(currentIndex + 1, queue.count)) of \(queue.count)")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                                    .contentTransition(.numericText())
                                    .animation(TaskerAnimation.snappy, value: currentIndex)

                                TaskerProgressBar(
                                    progress: Double(min(currentIndex + 1, queue.count)) / Double(max(queue.count, 1)),
                                    colors: [Color.tasker.accentPrimary, Color.tasker.accentPrimary],
                                    trackColor: Color.tasker.surfaceSecondary,
                                    height: 4
                                )
                            }
                            .enhancedStaggeredAppearance(index: 0)

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
                            .taskerDenseSurface(
                                cornerRadius: corner.r2,
                                fillColor: Color.tasker.surfacePrimary,
                                strokeColor: Color.tasker.strokeHairline
                            )
                            .id(currentItem.task.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .enhancedStaggeredAppearance(index: 0)

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
                            .taskerDenseSurface(
                                cornerRadius: corner.r2,
                                fillColor: Color.tasker.surfaceSecondary,
                                strokeColor: Color.tasker.strokeHairline
                            )
                            .enhancedStaggeredAppearance(index: 1)

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

    private var completionSummary: some View {
        VStack(spacing: spacing.s24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.tasker.statusSuccess)
                .scaleEffect(completionAppeared ? 1.0 : 0.3)
                .opacity(completionAppeared ? 1.0 : 0)
                .animation(TaskerAnimation.expressive, value: completionAppeared)

            Text("Triage complete")
                .font(.tasker(.title3))
                .foregroundColor(Color.tasker.textPrimary)

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
                        .background(Capsule().fill(isSelected ? Color.tasker.accentPrimary : Color.clear))
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
        .taskerDenseSurface(
            cornerRadius: corner.r2,
            fillColor: Color.tasker.surfaceSecondary,
            strokeColor: Color.tasker.strokeHairline
        )
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
