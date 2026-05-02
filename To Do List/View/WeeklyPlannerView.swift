import SwiftUI

struct WeeklyPlannerView: View {
    @ObservedObject var viewModel: WeeklyPlannerViewModel
    let onClose: () -> Void

    @State private var snackbar: SnackbarData?
    @State private var isHabitEditorPresented = false
    @State private var isTaskSourcePresented = false
    @State private var selectedTaskSourceMode: WeeklyTaskSourceMode = .suggested
    @State private var outcomeAttachmentState: PlannerOutcomeAttachmentSheetState?
    @State private var expandedReviewBuckets: Set<TaskPlanningBucket> = []

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        NavigationStack {
            WeeklyWizardScaffold(
                weekRange: viewModel.weekRangeText,
                currentStep: viewModel.currentStep,
                currentPrompt: viewModel.currentStepPrompt,
                showsBack: viewModel.currentStep != .direction,
                onBack: viewModel.moveBackward
            ) {
                if viewModel.hasLoadedInitialData == false {
                    if viewModel.isLoading {
                        WeeklyBlockingStateCard(
                            title: "Loading weekly plan…",
                            message: "Pulling tasks, habits, and outcomes for this week.",
                            showsProgress: true,
                            primaryActionTitle: nil,
                            onPrimaryAction: nil
                        )
                    } else if let errorMessage = viewModel.errorMessage {
                        WeeklyBlockingStateCard(
                            title: "We couldn't load this week",
                            message: errorMessage,
                            showsProgress: false,
                            primaryActionTitle: "Retry",
                            onPrimaryAction: { viewModel.load() }
                        )
                    } else {
                        WeeklyBlockingStateCard(
                            title: "Loading weekly plan…",
                            message: "Preparing your planner.",
                            showsProgress: true,
                            primaryActionTitle: nil,
                            onPrimaryAction: nil
                        )
                    }
                } else {
                    if let saveMessage = viewModel.saveMessage, saveMessage.isEmpty == false {
                        WeeklyInlineMessage(text: saveMessage, tone: .accent)
                    }

                    currentStepContent
                }
            } footer: {
                WeeklyStickyActionBar {
                    footerSummary
                } trailing: {
                    footerActions
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                        .accessibilityLabel("Close weekly planner")
                        .accessibilityHint("Dismiss the weekly planner and return to Home.")
                }
            }
            .task {
                if viewModel.availableProjects.isEmpty && !viewModel.isLoading {
                    viewModel.load()
                }
            }
            .alert(viewModel.errorTitle, isPresented: Binding(
                get: { viewModel.errorMessage != nil && viewModel.hasLoadedInitialData },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $isHabitEditorPresented) {
                WeeklyPlannerHabitEditorSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isTaskSourcePresented) {
                WeeklyPlannerTaskSourceSheet(
                    viewModel: viewModel,
                    selectedMode: $selectedTaskSourceMode,
                    onAdd: handleAddTaskToReviewFlow
                )
                .presentationDetents([.large])
            }
            .sheet(item: $outcomeAttachmentState) { target in
                WeeklyPlannerOutcomeAttachmentSheet(
                    state: target,
                    onSelect: { outcomeID in
                        viewModel.assignWeeklyOutcome(outcomeID, to: target.taskID)
                        outcomeAttachmentState = nil
                    },
                    onDismiss: { outcomeAttachmentState = nil }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: Binding(
                get: { viewModel.proposalState },
                set: { if $0 == nil { viewModel.dismissProposal() } }
            )) { proposalState in
                WeeklyPlannerProposalSheet(
                    state: proposalState,
                    onDismiss: { viewModel.dismissProposal() },
                    onSuggest: { viewModel.requestEvaSuggestion() },
                    onConfirm: { viewModel.confirmEvaProposal() },
                    onReject: { viewModel.rejectEvaProposal() }
                )
            }
            .taskerSnackbar($snackbar)
        }
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch viewModel.currentStep {
        case .direction:
            WeeklyPlannerDirectionStep(
                focusStatement: $viewModel.focusStatement,
                availableHabits: viewModel.availableHabits,
                selectedHabitIDs: viewModel.selectedHabitIDs,
                targetCapacity: $viewModel.targetCapacity,
                estimatedCapacity: viewModel.estimatedCapacity,
                overloadCount: viewModel.overloadCount,
                minimumViableWeekEnabled: $viewModel.minimumViableWeekEnabled,
                onToggleHabit: viewModel.toggleHabit,
                onEditHabits: { isHabitEditorPresented = true }
            )
        case .outcomes:
            WeeklyPlannerOutcomesStep(
                outcomeDrafts: $viewModel.outcomeDrafts,
                availableProjects: viewModel.availableProjects,
                projectNamesByID: viewModel.projectNamesByID,
                canAddOutcome: viewModel.canAddOutcome,
                onAddOutcome: viewModel.addOutcomeDraft,
                onRemoveOutcome: viewModel.removeOutcomeDraft(id:)
            )
        case .tasks:
            WeeklyPlannerTasksStep(
                snapshot: viewModel.triageSnapshot,
                lanes: viewModel.reviewSummary.lanes,
                outcomeTitlesByID: viewModel.outcomeTitlesByID,
                expandedReviewBuckets: expandedReviewBuckets,
                onToggleReviewBucket: toggleReviewLane,
                onDecision: handleTriageDecision,
                onFindMoreTasks: { isTaskSourcePresented = true }
            )
        case .review:
            WeeklyPlannerReviewStep(
                snapshot: viewModel.reviewSummary,
                expandedReviewBuckets: expandedReviewBuckets,
                outcomeTitlesByID: viewModel.outcomeTitlesByID,
                onToggleReviewBucket: toggleReviewLane,
                onEditStep: viewModel.jumpToStep
            )
        }
    }

    private var footerSummary: some View {
        WeeklyPlannerFooterSummaryView(snapshot: viewModel.footerSnapshot)
    }

    @ViewBuilder
    private var footerActions: some View {
        switch viewModel.currentStep {
        case .review:
            HStack(spacing: spacing.s8) {
                Button(viewModel.isRequestingEvaPreview ? "Working..." : WeeklyCopy.getAISuggestion) {
                    viewModel.requestEvaPreview()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSaving || viewModel.isRequestingEvaPreview)

                Button(viewModel.isSaving ? "Saving..." : WeeklyCopy.savePlan) {
                    viewModel.save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
            }
        default:
            Button(viewModel.currentStep.nextButtonTitle) {
                viewModel.moveForward()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading || viewModel.canMoveForward == false)
        }
    }

    private func toggleReviewLane(_ bucket: TaskPlanningBucket) {
        if expandedReviewBuckets.contains(bucket) {
            expandedReviewBuckets.remove(bucket)
        } else {
            expandedReviewBuckets.insert(bucket)
        }
    }

    private func handleTriageDecision(_ bucket: TaskPlanningBucket) {
        guard let decision = viewModel.assignCurrentTriageTask(to: bucket) else { return }

        if bucket == .thisWeek {
            TaskerFeedback.success()
        } else {
            TaskerFeedback.selection()
        }

        snackbar = SnackbarData(
            message: "\(decision.task.title) moved to \(bucket.conciseDisplayTitle)",
            actions: [
                SnackbarAction(title: "Undo") {
                    outcomeAttachmentState = nil
                    _ = viewModel.undoLastTriageDecision()
                }
            ],
            autoDismissSeconds: 4
        )

        if bucket == .thisWeek, viewModel.activeOutcomeDraftCount > 0 {
            outcomeAttachmentState = viewModel.outcomeAttachmentState(for: decision.task.id)
        }
    }

    private func handleAddTaskToReviewFlow(_ taskID: UUID) {
        guard viewModel.addTaskToReviewFlow(taskID) else { return }
        TaskerFeedback.success()
        snackbar = SnackbarData(message: WeeklyCopy.addedToReview, autoDismissSeconds: 2)
    }
}

private struct WeeklyBlockingStateCard: View {
    let title: String
    let message: String
    let showsProgress: Bool
    let primaryActionTitle: String?
    let onPrimaryAction: (() -> Void)?

    var body: some View {
        WeeklySectionCard(title: title, detail: message) {
            HStack(spacing: 12) {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                }

                if let primaryActionTitle, let onPrimaryAction {
                    Button(primaryActionTitle, action: onPrimaryAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}

private struct WeeklyPlannerFooterSummaryView: View {
    let snapshot: WeeklyPlannerFooterSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)

            if snapshot.detail.isEmpty == false {
                Text(snapshot.detail)
                    .font(.tasker(.caption2))
                    .foregroundStyle(snapshot.warning == nil ? Color.tasker.textSecondary : Color.tasker.statusWarning)
                    .lineLimit(2)
            }
        }
    }
}

private struct WeeklyPlannerField: View {
    let title: String
    let helper: String
    @Binding var text: String
    let lineLimit: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)

            TextField(title, text: $text, axis: .vertical)
                .lineLimit(lineLimit)
                .padding(12)
                .taskerDenseSurface(cornerRadius: 16, fillColor: Color.tasker.surfaceSecondary)

            Text(helper)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WeeklyPlannerMetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker.accentPrimary)
            Text(label)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.tasker.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WeeklyPlannerHabitChip: View {
    let habit: HabitLibraryRow
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.tasker.accentPrimary : Color.tasker.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(1)
                    Text(habit.projectName ?? habit.lifeAreaName)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .taskerDenseSurface(
                cornerRadius: 16,
                fillColor: isSelected ? Color.tasker.accentPrimary.opacity(0.10) : Color.tasker.surfaceSecondary
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WeeklyPlannerDirectionStep: View {
    @Binding var focusStatement: String
    let availableHabits: [HabitLibraryRow]
    let selectedHabitIDs: Set<UUID>
    @Binding var targetCapacity: Int
    let estimatedCapacity: Int
    let overloadCount: Int
    @Binding var minimumViableWeekEnabled: Bool
    let onToggleHabit: (UUID) -> Void
    let onEditHabits: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            WeeklySectionCard(
                title: WeeklyPlannerStep.direction.title,
                detail: "Start with one sentence. It should be short enough to remember when the week gets noisy."
            ) {
                WeeklyPlannerField(
                    title: WeeklyCopy.directionPrompt,
                    helper: "Write the shortest version of the truth for this week.",
                    text: $focusStatement,
                    lineLimit: 2...3
                )
            }

            WeeklySectionCard(
                title: WeeklyCopy.includedThisWeek,
                detail: "All active habits start included. Remove anything you do not want this week carrying with it."
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    if availableHabits.isEmpty {
                        Text(WeeklyCopy.noHabits)
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: spacing.s8)], spacing: spacing.s8) {
                            ForEach(availableHabits, id: \.habitID) { habit in
                                WeeklyPlannerHabitChip(
                                    habit: habit,
                                    isSelected: selectedHabitIDs.contains(habit.habitID),
                                    onToggle: { onToggleHabit(habit.habitID) }
                                )
                            }
                        }

                        Button(WeeklyCopy.editHabits, action: onEditHabits)
                            .buttonStyle(.bordered)
                    }
                }
            }

            WeeklySectionCard(
                title: "Pace",
                detail: "Keep This Week believable. A smaller plan you will keep is stronger than an ambitious one you will abandon."
            ) {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    WeeklyCapacityCard(
                        targetCapacity: $targetCapacity,
                        estimatedCapacity: estimatedCapacity,
                        overloadCount: overloadCount
                    )

                    Toggle(isOn: $minimumViableWeekEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(WeeklyCopy.intentionalWeekLabel)
                                .font(.tasker(.bodyEmphasis))
                                .foregroundStyle(Color.tasker.textPrimary)
                            Text("Turn this on when constraints matter more than ambition.")
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker.textSecondary)
                        }
                    }
                    .tint(Color.tasker.accentPrimary)

                    if overloadCount > 0 {
                        WeeklyInlineMessage(text: WeeklyCopy.overloadHelper(count: overloadCount), tone: .warning)
                    }
                }
            }
        }
    }
}

private struct WeeklyPlannerOutcomesStep: View {
    @Binding var outcomeDrafts: [WeeklyOutcomeDraft]
    let availableProjects: [Project]
    let projectNamesByID: [UUID: String]
    let canAddOutcome: Bool
    let onAddOutcome: () -> Void
    let onRemoveOutcome: (UUID) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        WeeklySectionCard(
            title: WeeklyPlannerStep.outcomes.title,
            detail: "Choose up to three results worth protecting this week."
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                ForEach(Array(outcomeDrafts.indices), id: \.self) { index in
                    outcomeCard(index: index, draft: $outcomeDrafts[index])
                }

                if canAddOutcome {
                    Button {
                        onAddOutcome()
                    } label: {
                        Label("Add weekly outcome", systemImage: "plus")
                            .font(.tasker(.buttonSmall))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func outcomeCard(index: Int, draft: Binding<WeeklyOutcomeDraft>) -> some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outcome \(index + 1)")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                    TextField("Weekly outcome", text: draft.title, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.tasker(.body))
                        .foregroundStyle(Color.tasker.textPrimary)
                }

                Spacer()

                if outcomeDrafts.count > 1 {
                    Button(role: .destructive) {
                        onRemoveOutcome(draft.wrappedValue.id)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.tasker.statusWarning)
                }
            }

            Text("Name the result, not the activity.")
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)

            HStack(spacing: spacing.s8) {
                Button(draft.wrappedValue.showsDetails ? "Hide detail" : "Add detail") {
                    draft.wrappedValue.showsDetails.toggle()
                }
                .buttonStyle(.bordered)

                Button(draft.wrappedValue.sourceProjectID.flatMap { projectNamesByID[$0] } ?? "Link project") {
                    draft.wrappedValue.showsProjectPicker.toggle()
                }
                .buttonStyle(.bordered)
            }

            if draft.wrappedValue.showsProjectPicker {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)

                    Picker("Project", selection: draft.sourceProjectID) {
                        Text("No project").tag(UUID?.none)
                        ForEach(availableProjects, id: \.id) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if draft.wrappedValue.showsDetails {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    WeeklyPlannerField(
                        title: "Why this matters",
                        helper: "Only add this if it helps you protect the outcome.",
                        text: draft.whyItMatters,
                        lineLimit: 1...3
                    )

                    WeeklyPlannerField(
                        title: "How you will know it happened",
                        helper: "Describe the finished state in concrete terms.",
                        text: draft.successDefinition,
                        lineLimit: 1...3
                    )
                }
            }
        }
        .padding(spacing.s16)
        .taskerDenseSurface(cornerRadius: 20, fillColor: Color.tasker.surfaceSecondary.opacity(0.8))
    }
}

private struct WeeklyPlannerLaneSummaryView: View {
    let summary: WeeklyPlannerReviewLaneSummary
    let outcomeTitlesByID: [UUID: String]
    let isExpanded: Bool
    let expandsByDefault: Bool
    let onToggle: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .center, spacing: spacing.s8) {
                Text(summary.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker.textPrimary)

                Text(summary.tasks.isEmpty ? "0" : "\(summary.tasks.count)")
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.s8)
                    .padding(.vertical, 4)
                    .background(Color.tasker.surfaceSecondary, in: Capsule(style: .continuous))

                Spacer()

                if expandsByDefault == false, summary.tasks.isEmpty == false {
                    Button(isExpanded ? "Hide" : "Show", action: onToggle)
                        .font(.tasker(.buttonSmall))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.tasker.accentPrimary)
                }
            }

            if summary.tasks.isEmpty {
                Text(WeeklyCopy.noTasksInPlan)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            } else if isExpanded {
                VStack(spacing: spacing.s8) {
                    ForEach(summary.tasks, id: \.id) { task in
                        WeeklyPlannerReviewTaskRow(
                            task: task,
                            outcomeTitle: task.weeklyOutcomeID.flatMap { outcomeTitlesByID[$0] }
                        )
                    }
                }
            }
        }
        .padding(spacing.s12)
        .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfaceSecondary.opacity(0.7))
    }
}

private struct WeeklyPlannerTasksStep: View {
    let snapshot: WeeklyPlannerTriageSnapshot
    let lanes: [WeeklyPlannerReviewLaneSummary]
    let outcomeTitlesByID: [UUID: String]
    let expandedReviewBuckets: Set<TaskPlanningBucket>
    let onToggleReviewBucket: (TaskPlanningBucket) -> Void
    let onDecision: (TaskPlanningBucket) -> Void
    let onFindMoreTasks: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            WeeklySectionCard(
                title: WeeklyPlannerStep.tasks.title,
                detail: snapshot.sectionDetail
            ) {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    HStack(spacing: spacing.s8) {
                        WeeklyPlannerMetricPill(value: "\(lane(.thisWeek).tasks.count)", label: WeeklyCopy.thisWeek)
                        WeeklyPlannerMetricPill(value: "\(lane(.nextWeek).tasks.count)", label: WeeklyCopy.nextWeek)
                        WeeklyPlannerMetricPill(value: "\(lane(.later).tasks.count)", label: WeeklyCopy.later)
                    }

                    if let cardModel = snapshot.cardModel {
                        WeeklyPlannerTriageCard(model: cardModel, onDecision: onDecision)
                    } else {
                        WeeklyInlineMessage(text: WeeklyCopy.tasksCompleteTitle, tone: .accent)
                    }

                    Button(WeeklyCopy.findMoreTasks, action: onFindMoreTasks)
                        .buttonStyle(.bordered)
                }
            }

            if snapshot.cardModel == nil {
                WeeklySectionCard(
                    title: "What the week holds",
                    detail: "Review the balance before you move on."
                ) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        laneView(for: .thisWeek, expandsByDefault: true)
                        laneView(for: .nextWeek, expandsByDefault: false)
                        laneView(for: .later, expandsByDefault: false)
                    }
                }
            }
        }
    }

    private func lane(_ bucket: TaskPlanningBucket) -> WeeklyPlannerReviewLaneSummary {
        lanes.first(where: { $0.bucket == bucket }) ?? WeeklyPlannerReviewLaneSummary(bucket: bucket, title: bucket.conciseDisplayTitle, tasks: [])
    }

    private func laneView(for bucket: TaskPlanningBucket, expandsByDefault: Bool) -> some View {
        let summary = lane(bucket)
        let isExpanded = expandsByDefault || expandedReviewBuckets.contains(bucket)
        return WeeklyPlannerLaneSummaryView(
            summary: summary,
            outcomeTitlesByID: outcomeTitlesByID,
            isExpanded: isExpanded,
            expandsByDefault: expandsByDefault,
            onToggle: { onToggleReviewBucket(bucket) }
        )
    }
}

private struct WeeklyPlannerReviewStep: View {
    let snapshot: WeeklyPlannerReviewSummary
    let expandedReviewBuckets: Set<TaskPlanningBucket>
    let outcomeTitlesByID: [UUID: String]
    let onToggleReviewBucket: (TaskPlanningBucket) -> Void
    let onEditStep: (WeeklyPlannerStep) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HStack(spacing: spacing.s8) {
                WeeklyPlannerMetricPill(value: "\(snapshot.outcomes.count)", label: "Outcomes")
                WeeklyPlannerMetricPill(value: "\(lane(.thisWeek).tasks.count)", label: WeeklyCopy.thisWeek)
                WeeklyPlannerMetricPill(value: "\(snapshot.habits.count)", label: "Habits")
            }

            reviewSectionCard(title: WeeklyCopy.reviewDirectionTitle, step: .direction) {
                Text(snapshot.direction ?? WeeklyCopy.reviewDirectionFallback)
                    .font(.tasker(.body))
                    .foregroundStyle(snapshot.direction == nil ? Color.tasker.textSecondary : Color.tasker.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            reviewSectionCard(title: "Weekly outcomes", step: .outcomes) {
                if snapshot.outcomes.isEmpty {
                    Text(WeeklyCopy.noOutcomes)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        ForEach(Array(snapshot.outcomes.enumerated()), id: \.element.id) { index, outcome in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: spacing.s8) {
                                    Text("\(index + 1).")
                                        .font(.tasker(.bodyEmphasis))
                                        .foregroundStyle(Color.tasker.accentPrimary)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(outcome.title)
                                            .font(.tasker(.bodyEmphasis))
                                            .foregroundStyle(Color.tasker.textPrimary)
                                        HStack(spacing: spacing.s8) {
                                            if let projectName = outcome.projectName {
                                                TaskerStatusPill(text: projectName, systemImage: "folder", tone: .quiet)
                                            }
                                            TaskerStatusPill(
                                                text: outcome.linkedTaskCount == 1 ? "1 task linked" : "\(outcome.linkedTaskCount) tasks linked",
                                                systemImage: "checklist",
                                                tone: .accent
                                            )
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.bottom, spacing.s4)
                        }
                    }
                }
            }

            reviewSectionCard(title: WeeklyCopy.reviewPlacedWorkTitle, step: .tasks) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    laneView(for: .thisWeek, expandsByDefault: true)
                    laneView(for: .nextWeek, expandsByDefault: false)
                    laneView(for: .later, expandsByDefault: false)
                }
            }

            reviewSectionCard(title: WeeklyCopy.reviewHabitsTitle, step: .direction) {
                if snapshot.habits.isEmpty {
                    Text(WeeklyCopy.noHabits)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: spacing.s8)], spacing: spacing.s8) {
                        ForEach(snapshot.habits, id: \.habitID) { habit in
                            WeeklyPlannerHabitToken(title: habit.title, subtitle: habit.projectName ?? habit.lifeAreaName)
                        }
                    }
                }
            }
        }
    }

    private func reviewSectionCard<Content: View>(
        title: String,
        step: WeeklyPlannerStep,
        @ViewBuilder content: () -> Content
    ) -> some View {
        WeeklySectionCard(title: title) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack {
                    Spacer()
                    Button(WeeklyCopy.edit) {
                        onEditStep(step)
                    }
                    .font(.tasker(.buttonSmall))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.tasker.accentPrimary)
                }

                content()
            }
        }
    }

    private func lane(_ bucket: TaskPlanningBucket) -> WeeklyPlannerReviewLaneSummary {
        snapshot.lanes.first(where: { $0.bucket == bucket }) ?? WeeklyPlannerReviewLaneSummary(bucket: bucket, title: bucket.conciseDisplayTitle, tasks: [])
    }

    private func laneView(for bucket: TaskPlanningBucket, expandsByDefault: Bool) -> some View {
        let summary = lane(bucket)
        let isExpanded = expandsByDefault || expandedReviewBuckets.contains(bucket)
        return WeeklyPlannerLaneSummaryView(
            summary: summary,
            outcomeTitlesByID: outcomeTitlesByID,
            isExpanded: isExpanded,
            expandsByDefault: expandsByDefault,
            onToggle: { onToggleReviewBucket(bucket) }
        )
    }
}

private struct WeeklyPlannerTriageCard: View {
    let model: WeeklyPlannerTriageCardModel
    let onDecision: (TaskPlanningBucket) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGFloat = 0

    private let thisWeekThreshold: CGFloat = 110
    private let nextWeekThreshold: CGFloat = -90
    private let laterThreshold: CGFloat = -190

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.task.title)
                        .font(.tasker(.title2))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if let projectName = model.task.projectName, projectName.isEmpty == false {
                            TaskerStatusPill(text: projectName, systemImage: "folder", tone: .quiet)
                        }
                        if let dueDate = model.task.dueDate {
                            TaskerStatusPill(
                                text: dueDate.formatted(date: .abbreviated, time: .omitted),
                                systemImage: model.task.isOverdue ? "exclamationmark.triangle.fill" : "calendar",
                                tone: model.task.isOverdue ? .warning : .quiet
                            )
                        }
                        TaskerStatusPill(text: model.task.priority.displayName, systemImage: "flag.fill", tone: model.task.priority.isHighPriority ? .warning : .quiet)
                    }
                }

                Spacer()
            }

            if let details = model.task.details, details.isEmpty == false {
                Text(details)
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                TaskerStatusPill(text: model.currentPlacementText, systemImage: "arrow.triangle.branch", tone: .quiet)
                if let outcomeTitle = model.outcomeTitle, outcomeTitle.isEmpty == false {
                    TaskerStatusPill(text: outcomeTitle, systemImage: "scope", tone: .accent)
                }
            }

            HStack(spacing: 8) {
                triageButton(title: WeeklyCopy.thisWeek, bucket: .thisWeek, systemImage: "calendar")
                triageButton(title: WeeklyCopy.nextWeek, bucket: .nextWeek, systemImage: "calendar.badge.plus")
                triageButton(title: WeeklyCopy.later, bucket: .later, systemImage: "clock.arrow.circlepath")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: dragOffset >= 0 ? .leading : .trailing) {
            if let dragLabel = dragLabel {
                Text(dragLabel.title)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(dragLabel.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(dragLabel.color.opacity(0.10), in: Capsule(style: .continuous))
                    .padding(.horizontal, 16)
            }
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset / 40)))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    handleDragEnd(value.translation.width)
                }
        )
        .animation(reduceMotion ? nil : TaskerAnimation.snappy, value: dragOffset)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(WeeklyCopy.keepInThisWeek)) {
            onDecision(.thisWeek)
        }
        .accessibilityAction(named: Text(WeeklyCopy.moveToNextWeek)) {
            onDecision(.nextWeek)
        }
        .accessibilityAction(named: Text(WeeklyCopy.moveToLater)) {
            onDecision(.later)
        }
    }

    private var cardBackground: Color {
        if dragOffset >= thisWeekThreshold {
            return Color.tasker.accentPrimary.opacity(0.12)
        }
        if dragOffset <= laterThreshold {
            return Color.tasker.textSecondary.opacity(0.12)
        }
        if dragOffset <= nextWeekThreshold {
            return Color.tasker.accentSecondary.opacity(0.12)
        }
        return Color.tasker.surfacePrimary
    }

    private var dragLabel: (title: String, color: Color)? {
        if dragOffset >= thisWeekThreshold {
            return (WeeklyCopy.thisWeek, Color.tasker.accentPrimary)
        }
        if dragOffset <= laterThreshold {
            return (WeeklyCopy.later, Color.tasker.textPrimary)
        }
        if dragOffset <= nextWeekThreshold {
            return (WeeklyCopy.nextWeek, Color.tasker.accentSecondary)
        }
        return nil
    }

    private func triageButton(title: String, bucket: TaskPlanningBucket, systemImage: String) -> some View {
        Button {
            onDecision(bucket)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.tasker(.caption1).weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(buttonColor(for: bucket))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(buttonColor(for: bucket).opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func buttonColor(for bucket: TaskPlanningBucket) -> Color {
        switch bucket {
        case .thisWeek:
            return Color.tasker.accentPrimary
        case .nextWeek:
            return Color.tasker.accentSecondary
        case .later:
            return Color.tasker.textPrimary
        default:
            return Color.tasker.textSecondary
        }
    }

    private func handleDragEnd(_ width: CGFloat) {
        if width >= thisWeekThreshold {
            onDecision(.thisWeek)
            dragOffset = 0
            return
        }
        if width <= laterThreshold {
            onDecision(.later)
            dragOffset = 0
            return
        }
        if width <= nextWeekThreshold {
            onDecision(.nextWeek)
            dragOffset = 0
            return
        }
        dragOffset = 0
    }
}

private struct WeeklyPlannerTaskSourceSheet: View {
    @ObservedObject var viewModel: WeeklyPlannerViewModel
    @Binding var selectedMode: WeeklyTaskSourceMode
    let onAdd: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: spacing.s16) {
                Text("Bring in more work only if it still deserves attention this week.")
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.screenHorizontal)

                Picker("Task source", selection: $selectedMode) {
                    ForEach(WeeklyTaskSourceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, spacing.screenHorizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        let snapshot = viewModel.taskSourceSnapshot(for: selectedMode)
                        let tasks = snapshot.tasks

                        if tasks.isEmpty {
                            Text("Nothing is available here right now.")
                                .font(.tasker(.support))
                                .foregroundStyle(Color.tasker.textSecondary)
                                .padding(.top, spacing.s16)
                        } else {
                            ForEach(tasks, id: \.id) { task in
                                WeeklyPlannerSourceTaskRow(
                                    task: task,
                                    badge: viewModel.taskSourceBadge(for: task.id),
                                    canAdd: viewModel.isTaskInReviewFlow(task.id) == false,
                                    onAdd: {
                                        onAdd(task.id)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.vertical, spacing.s8)
                    .taskerReadableContent()
                }
            }
            .padding(.top, spacing.s12)
            .background(Color.tasker.bgCanvas.ignoresSafeArea())
            .navigationTitle(WeeklyCopy.findMoreTasks)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WeeklyPlannerSourceTaskRow: View {
    let task: TaskDefinition
    let badge: String?
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let projectName = task.projectName, projectName.isEmpty == false {
                        TaskerStatusPill(text: projectName, systemImage: "folder", tone: .quiet)
                    }
                    if let dueDate = task.dueDate {
                        TaskerStatusPill(
                            text: dueDate.formatted(date: .abbreviated, time: .omitted),
                            systemImage: task.isOverdue ? "exclamationmark.triangle.fill" : "calendar",
                            tone: task.isOverdue ? .warning : .quiet
                        )
                    }
                }
            }

            Spacer()

            if let badge, canAdd == false {
                Text(badge)
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.tasker.surfaceSecondary, in: Capsule(style: .continuous))
            } else {
                Button(WeeklyCopy.addTaskToReview) {
                    onAdd()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfaceSecondary.opacity(0.8))
    }
}

private struct WeeklyPlannerOutcomeAttachmentSheet: View {
    let state: PlannerOutcomeAttachmentSheetState
    let onSelect: (UUID?) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(state.taskTitle)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker.textPrimary)
                } header: {
                    Text(WeeklyCopy.attachOutcomeQuestion)
                }

                Section {
                    Button {
                        onSelect(nil)
                    } label: {
                        outcomeRow(title: WeeklyCopy.noOutcome, isSelected: state.currentOutcomeID == nil)
                    }
                    .buttonStyle(.plain)

                    ForEach(state.outcomeOptions) { outcome in
                        Button {
                            onSelect(outcome.outcomeID)
                        } label: {
                            outcomeRow(
                                title: outcome.title,
                                isSelected: state.currentOutcomeID == outcome.outcomeID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Weekly outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }

    private func outcomeRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.tasker.textPrimary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.tasker.accentPrimary)
            }
        }
    }
}

private struct WeeklyPlannerHabitEditorSheet: View {
    @ObservedObject var viewModel: WeeklyPlannerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.availableHabits.isEmpty {
                    Text(WeeklyCopy.noHabits)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                } else {
                    ForEach(viewModel.availableHabits, id: \.habitID) { habit in
                        Button {
                            viewModel.toggleHabit(habit.habitID)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.title)
                                        .font(.tasker(.body))
                                        .foregroundStyle(Color.tasker.textPrimary)
                                    Text(habit.projectName ?? habit.lifeAreaName)
                                        .font(.tasker(.caption1))
                                        .foregroundStyle(Color.tasker.textSecondary)
                                }

                                Spacer()

                                Image(systemName: viewModel.selectedHabitIDs.contains(habit.habitID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selectedHabitIDs.contains(habit.habitID) ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(WeeklyCopy.includedThisWeek)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WeeklyPlannerReviewTaskRow: View {
    let task: TaskDefinition
    let outcomeTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let dueDate = task.dueDate {
                    TaskerStatusPill(
                        text: dueDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: task.isOverdue ? "exclamationmark.triangle.fill" : "calendar",
                        tone: task.isOverdue ? .warning : .quiet
                    )
                }
                if let outcomeTitle, outcomeTitle.isEmpty == false {
                    TaskerStatusPill(text: outcomeTitle, systemImage: "scope", tone: .accent)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskerDenseSurface(cornerRadius: 16, fillColor: Color.tasker.surfacePrimary)
    }
}

private struct WeeklyPlannerHabitToken: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.textPrimary)
                .lineLimit(1)
            Text(subtitle)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .taskerDenseSurface(cornerRadius: 16, fillColor: Color.tasker.surfaceSecondary)
    }
}

private struct WeeklyPlannerProposalSheet: View {
    let state: WeeklyPlannerProposalState
    let onDismiss: () -> Void
    let onSuggest: () -> Void
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        NavigationStack {
            WeeklyRitualScaffold(
                eyebrow: "AI suggestion",
                title: "Review the suggested changes",
                subtitle: "Read the changes before they touch your plan. Nothing applies until you confirm.",
                weekRange: "Draft preview",
                steps: [
                    WeeklyRitualStep(id: 0, title: "Review summary", isComplete: true),
                    WeeklyRitualStep(id: 1, title: "Read changes", isComplete: state.preview.diffLines.isEmpty == false),
                    WeeklyRitualStep(id: 2, title: "Confirm or reject", isComplete: state.preview.run != nil)
                ],
                message: state.errorMessage,
                messageTone: .warning
            ) {
                WeeklySectionCard(
                    title: "Eva suggestion",
                    detail: "Review what Eva wants to change before applying it."
                ) {
                    HStack(spacing: 12) {
                        EvaMascotView(placement: .weeklySuggestion, size: .inline)
                        Text("Eva has a planning recommendation ready for review.")
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    }
                }

                WeeklySectionCard(
                    title: "Summary",
                    detail: "Start here before deciding whether to use the suggestion."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Affected tasks", value: "\(state.preview.affectedTaskCount)")
                        LabeledContent("Removals or drops", value: "\(state.preview.destructiveCount)")
                        Text(state.preview.rationale)
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    }
                }

                WeeklySectionCard(
                    title: "Suggested changes",
                    detail: "Each line shows what would change if you confirm."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(state.preview.diffLines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: line.isDestructive ? "arrow.turn.down.right" : "checkmark.circle.fill")
                                    .foregroundStyle(line.isDestructive ? Color.tasker.statusWarning : Color.tasker.accentPrimary)
                                Text(line.text)
                                    .font(.tasker(.support))
                                    .foregroundStyle(Color.tasker.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            } footer: {
                WeeklyStickyActionBar {
                    Button("Reject", role: .destructive, action: onReject)
                        .disabled(state.isWorking || state.preview.run == nil)
                } trailing: {
                    if state.preview.run == nil {
                        Button(state.isWorking ? "Working..." : WeeklyCopy.getAISuggestion) {
                            onSuggest()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.isWorking)
                    } else {
                        Button(state.isWorking ? "Applying..." : "Apply suggestion") {
                            onConfirm()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.isWorking)
                    }
                }
            }
            .navigationTitle("AI suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }
}
