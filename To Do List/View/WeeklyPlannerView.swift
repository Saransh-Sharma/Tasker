import SwiftUI

struct WeeklyPlannerView: View {
    @ObservedObject var viewModel: WeeklyPlannerViewModel
    let onClose: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        NavigationStack {
            WeeklyRitualScaffold(
                eyebrow: "Weekly planning",
                title: WeeklyCopy.plannerTitle,
                subtitle: WeeklyCopy.plannerSubtitle,
                weekRange: viewModel.weekRangeText,
                steps: viewModel.plannerSteps,
                message: viewModel.saveMessage,
                messageTone: .accent
            ) {
                directionSection
                outcomesSection
                workPlacementSection
                reviewSection
            } footer: {
                WeeklyStickyActionBar {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready to save")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                        Text(viewModel.reviewSummaryText)
                            .font(.tasker(.caption2))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } trailing: {
                    HStack(spacing: spacing.s8) {
                        Button(WeeklyCopy.getAISuggestion) {
                            viewModel.requestEvaPreview()
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isSaving)

                        Button(viewModel.isSaving ? "Saving..." : WeeklyCopy.savePlan) {
                            viewModel.save()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSaving)
                    }
                }
            }
            .navigationTitle(WeeklyCopy.plannerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
            .task {
                if viewModel.availableProjects.isEmpty && !viewModel.isLoading {
                    viewModel.load()
                }
            }
            .alert(WeeklyCopy.plannerErrorTitle, isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
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
        }
    }

    private var directionSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.plannerSteps[0],
            detail: "Decide what this week is for before you start moving tasks around."
        ) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                plannerField(
                    title: "What matters most this week?",
                    helper: "Write one sentence you can come back to when the week gets noisy.",
                    text: $viewModel.focusStatement,
                    lineLimit: 2...4
                )

                WeeklyCapacityCard(
                    targetCapacity: $viewModel.targetCapacity,
                    estimatedCapacity: viewModel.estimatedCapacity,
                    overloadCount: viewModel.overloadCount
                )

                Toggle(isOn: $viewModel.minimumViableWeekEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WeeklyCopy.intentionalWeekLabel)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(Color.tasker.textPrimary)
                        Text("Use this when the right plan is a smaller week, not a more ambitious one.")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                    }
                }
                .tint(Color.tasker.accentPrimary)

                if viewModel.overloadCount > 0 {
                    WeeklyInlineMessage(
                        text: WeeklyCopy.overloadHelper(count: viewModel.overloadCount),
                        tone: .warning
                    )
                }
            }
        }
    }

    private var outcomesSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.plannerSteps[1],
            detail: "Keep it to three outcomes so the week stays readable and choices stay honest."
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                ForEach($viewModel.outcomeDrafts) { $draft in
                    outcomeCard($draft)
                }

                if viewModel.canAddOutcome {
                    Button {
                        viewModel.addOutcomeDraft()
                    } label: {
                        Label("Add weekly outcome", systemImage: "plus")
                            .font(.tasker(.buttonSmall))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func outcomeCard(_ draft: Binding<WeeklyOutcomeDraft>) -> some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            plannerField(
                title: "Weekly outcome",
                helper: "Name the result, not the activity.",
                text: draft.title,
                lineLimit: 1...3
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Project")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)

                Picker("Project", selection: draft.sourceProjectID) {
                    Text("No project").tag(UUID?.none)
                    ForEach(viewModel.availableProjects, id: \.id) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
            }

            plannerField(
                title: "Why this matters",
                helper: "Make the reason strong enough that you would still choose it on Wednesday.",
                text: draft.whyItMatters,
                lineLimit: 1...3
            )

            plannerField(
                title: "How you'll know it happened",
                helper: "Describe the finished state in concrete terms.",
                text: draft.successDefinition,
                lineLimit: 1...3
            )

            Button("Remove outcome", role: .destructive) {
                viewModel.removeOutcomeDraft(id: draft.wrappedValue.id)
            }
            .disabled(viewModel.outcomeDrafts.count == 1)
        }
        .padding(spacing.s16)
        .taskerDenseSurface(cornerRadius: 20, fillColor: Color.tasker.surfaceSecondary.opacity(0.8))
    }

    private var workPlacementSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.plannerSteps[2],
            detail: "Place work into This Week, Next Week, or Later. Keep weekly outcomes linked only to active work."
        ) {
            VStack(alignment: .leading, spacing: spacing.s20) {
                habitSection

                WeeklyTaskLaneView(
                    title: WeeklyCopy.thisWeek,
                    detail: "Only keep work here that you still want to own this week.",
                    bucket: .thisWeek,
                    tasks: viewModel.thisWeekTasks,
                    outcomeTitlesByID: viewModel.outcomeTitlesByID,
                    emptyText: WeeklyCopy.noTasksInLane,
                    onMove: viewModel.moveTask
                )

                WeeklyTaskLaneView(
                    title: WeeklyCopy.nextWeek,
                    detail: "Move work here when it matters soon but not now.",
                    bucket: .nextWeek,
                    tasks: viewModel.nextWeekTasks,
                    outcomeTitlesByID: viewModel.outcomeTitlesByID,
                    emptyText: WeeklyCopy.noTasksInLane,
                    onMove: viewModel.moveTask
                )

                WeeklyTaskLaneView(
                    title: WeeklyCopy.later,
                    detail: "Keep backlog pressure visible without letting it run this week.",
                    bucket: .later,
                    tasks: viewModel.laterTasks,
                    outcomeTitlesByID: viewModel.outcomeTitlesByID,
                    emptyText: WeeklyCopy.noTasksInLane,
                    onMove: viewModel.moveTask
                )
            }
        }
    }

    private var habitSection: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Keep these habits steady")
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)

            if viewModel.availableHabits.isEmpty {
                Text(WeeklyCopy.noHabits)
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
            } else {
                VStack(spacing: spacing.s8) {
                    ForEach(viewModel.availableHabits, id: \.habitID) { habit in
                        Button {
                            viewModel.toggleHabit(habit.habitID)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.title)
                                        .font(.tasker(.bodyEmphasis))
                                        .foregroundStyle(Color.tasker.textPrimary)
                                    Text(habit.projectName ?? habit.lifeAreaName)
                                        .font(.tasker(.caption1))
                                        .foregroundStyle(Color.tasker.textSecondary)
                                }

                                Spacer()

                                Image(systemName: viewModel.selectedHabitIDs.contains(habit.habitID) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(viewModel.selectedHabitIDs.contains(habit.habitID) ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                            }
                            .padding(14)
                            .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfaceSecondary.opacity(0.84))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var reviewSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.plannerSteps[3],
            detail: "Before saving, check that the week still looks believable."
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(spacing: spacing.s8) {
                    metricPill(value: "\(viewModel.activeOutcomeDraftCount)", label: "Outcomes")
                    metricPill(value: "\(viewModel.thisWeekTasks.count)", label: "This Week")
                    metricPill(value: "\(viewModel.selectedHabitIDs.count)", label: "Habits")
                }

                Text(viewModel.reviewSummaryText)
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker.accentPrimary)
            Text(label)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func plannerField(
        title: String,
        helper: String,
        text: Binding<String>,
        lineLimit: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)

            TextField(title, text: text, axis: .vertical)
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
