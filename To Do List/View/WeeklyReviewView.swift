import SwiftUI

struct WeeklyReviewView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel
    let onClose: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    @State private var showingReflectionComposer = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        NavigationStack {
            WeeklyRitualScaffold(
                eyebrow: "Weekly review",
                title: WeeklyCopy.reviewTitle,
                subtitle: WeeklyCopy.reviewSubtitle,
                weekRange: viewModel.weekRangeText,
                steps: viewModel.reviewSteps,
                message: viewModel.saveMessage,
                messageTone: .accent
            ) {
                realityCheckSection
                outcomesSection
                cleanupSection
                reflectionSection
                notesSection
            } footer: {
                WeeklyStickyActionBar {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review status")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                        Text(viewModel.completionSummaryText)
                            .font(.tasker(.caption2))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } trailing: {
                    Button(viewModel.isSaving ? "Saving..." : WeeklyCopy.finishReview) {
                        viewModel.completeReview()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving || viewModel.snapshot?.plan == nil)
                }
            }
            .navigationTitle(WeeklyCopy.reviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
            .task {
                if viewModel.snapshot == nil && !viewModel.isLoading {
                    viewModel.load()
                }
            }
            .onChange(of: viewModel.wins) { _, _ in
                viewModel.scheduleDraftAutosave()
            }
            .onChange(of: viewModel.blockers) { _, _ in
                viewModel.scheduleDraftAutosave()
            }
            .onChange(of: viewModel.lessons) { _, _ in
                viewModel.scheduleDraftAutosave()
            }
            .onChange(of: viewModel.nextWeekPrepNotes) { _, _ in
                viewModel.scheduleDraftAutosave()
            }
            .onChange(of: viewModel.perceivedWeekRating) { _, _ in
                viewModel.scheduleDraftAutosave()
            }
            .alert(WeeklyCopy.reviewErrorTitle, isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingReflectionComposer) {
                if let linkedWeeklyPlanID = viewModel.snapshot?.plan?.id {
                    ReflectionNoteComposerView(
                        viewModel: ReflectionNoteComposerViewModel(
                            title: WeeklyCopy.reflectionTitle,
                            kind: .weeklyReview,
                            linkedWeeklyPlanID: linkedWeeklyPlanID,
                            prompt: "What should next week's version of you remember from this one?",
                            saveNoteHandler: { note, completion in
                                viewModel.saveReflectionNote(note, completion: completion)
                            }
                        )
                    )
                }
            }
        }
    }

    private var realityCheckSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[0],
            detail: "Start with the facts before deciding what the week means."
        ) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                HStack(spacing: spacing.s8) {
                    metricPill(value: "\(viewModel.completedTasks.count)", label: "Done")
                    metricPill(value: "\(viewModel.unfinishedTasks.count)", label: "To resolve")
                    metricPill(value: "\(viewModel.reflectionNotes.count)", label: "Reflections")
                }

                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Check habits")
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)

                    if let plan = viewModel.snapshot?.plan, plan.selectedHabitIDs.isEmpty {
                        Text("No habits were intentionally carried into this week.")
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else if viewModel.selectedHabits.isEmpty {
                        Text("Habit details will appear here after the review reloads current streaks.")
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(viewModel.selectedHabits, id: \.habitID) { habit in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.title)
                                        .font(.tasker(.bodyEmphasis))
                                        .foregroundStyle(Color.tasker.textPrimary)
                                    Text(habit.lifeAreaName)
                                        .font(.tasker(.caption2))
                                        .foregroundStyle(Color.tasker.textSecondary)
                                }

                                Spacer()

                                TaskerStatusPill(
                                    text: "\(habit.currentStreak)d streak",
                                    systemImage: "flame.fill",
                                    tone: .quiet
                                )
                            }
                            .padding(12)
                            .taskerDenseSurface(cornerRadius: 16, fillColor: Color.tasker.surfaceSecondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("What got done")
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)

                    if viewModel.completedTasks.isEmpty {
                        Text(WeeklyCopy.noCompletedWork)
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(viewModel.completedTasks, id: \.id) { task in
                            Label(task.title, systemImage: "checkmark.circle.fill")
                                .font(.tasker(.support))
                                .foregroundStyle(Color.tasker.accentPrimary)
                        }
                    }
                }
            }
        }
    }

    private var outcomesSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[1],
            detail: "Mark what really happened so momentum stays based on reality."
        ) {
            if let snapshot = viewModel.snapshot, snapshot.outcomes.isEmpty == false {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    ForEach(snapshot.outcomes, id: \.id) { outcome in
                        WeeklyOutcomeReviewRow(
                            outcome: outcome,
                            selectedStatus: viewModel.outcomeStatusesByID[outcome.id, default: .planned]
                        ) { status in
                            viewModel.setOutcomeStatus(status, for: outcome.id)
                        }
                    }
                }
            } else {
                Text(WeeklyCopy.noOutcomes)
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
        }
    }

    private var cleanupSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[2],
            detail: "Every unfinished item needs a clean decision: keep it active, move it out, or let it go."
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                if viewModel.unfinishedTasks.isEmpty {
                    Text(WeeklyCopy.noUnfinishedWork)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                } else {
                    HStack(spacing: spacing.s8) {
                        bulkDecisionButton(title: "Carry all", disposition: .carry)
                        bulkDecisionButton(title: "Move all later", disposition: .later)
                        bulkDecisionButton(title: "Drop all", disposition: .drop)
                    }

                    ForEach(viewModel.unfinishedTasks, id: \.id) { task in
                        WeeklyDecisionRow(
                            task: task,
                            selectedDisposition: viewModel.taskDecisions[task.id] ?? .carry
                        ) { decision in
                            viewModel.setDecision(decision, for: task.id)
                        }
                    }
                }
            }
        }
    }

    private var reflectionSection: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[3],
            detail: "Use short notes. Clear reflection is more useful than perfect reflection."
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                reflectionField(
                    title: "What worked?",
                    helper: "Name the wins you want to repeat.",
                    text: $viewModel.wins
                )
                reflectionField(
                    title: "What got in the way?",
                    helper: "Describe the pressure, friction, or mismatch that mattered most.",
                    text: $viewModel.blockers
                )
                reflectionField(
                    title: "What did this week teach you?",
                    helper: "Write the lesson plainly enough that you would believe it next week.",
                    text: $viewModel.lessons
                )
                reflectionField(
                    title: "How should next week start?",
                    helper: "Capture the setup that would make Monday easier.",
                    text: $viewModel.nextWeekPrepNotes
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("How did this week feel?")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                viewModel.perceivedWeekRating = rating
                            } label: {
                                Text("\(rating)")
                                    .font(.tasker(.bodyEmphasis))
                                    .foregroundStyle(viewModel.perceivedWeekRating == rating ? Color.tasker.accentOnPrimary : Color.tasker.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(viewModel.perceivedWeekRating == rating ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        WeeklySectionCard(
            title: "Weekly reflections",
            detail: "These notes help later reviews stay grounded in what actually happened."
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Button(WeeklyCopy.addReflection) {
                    showingReflectionComposer = true
                }
                .buttonStyle(.bordered)

                if viewModel.reflectionNotes.isEmpty {
                    Text(WeeklyCopy.noWeeklyNotes)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                } else {
                    ForEach(viewModel.reflectionNotes, id: \.id) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            if let prompt = note.prompt, prompt.isEmpty == false {
                                Text(prompt)
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            }
                            Text(note.noteText)
                                .font(.tasker(.support))
                                .foregroundStyle(Color.tasker.textPrimary)
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.tasker(.caption2))
                                .foregroundStyle(Color.tasker.textSecondary)
                        }
                        .padding(14)
                        .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfaceSecondary.opacity(0.84))
                    }
                }
            }
        }
    }

    private func bulkDecisionButton(title: String, disposition: WeeklyReviewTaskDisposition) -> some View {
        Button(title) {
            viewModel.applyDecisionToAllUnfinished(disposition)
        }
        .buttonStyle(.bordered)
        .tint(disposition.tintColor)
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

    private func reflectionField(title: String, helper: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)

            TextField(title, text: text, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .taskerDenseSurface(cornerRadius: 16, fillColor: Color.tasker.surfaceSecondary)

            Text(helper)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WeeklyOutcomeReviewRow: View {
    let outcome: WeeklyOutcome
    let selectedStatus: WeeklyOutcomeStatus
    let onSelect: (WeeklyOutcomeStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(outcome.title)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker.textPrimary)

            if let successDefinition = outcome.successDefinition, successDefinition.isEmpty == false {
                Text(successDefinition)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            HStack(spacing: 8) {
                ForEach(WeeklyOutcomeStatus.allCases, id: \.self) { status in
                    statusButton(status)
                }
            }
        }
        .padding(14)
        .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfaceSecondary.opacity(0.84))
    }

    private func statusButton(_ status: WeeklyOutcomeStatus) -> some View {
        let isSelected = selectedStatus == status
        let tint = status.tintColor

        return Button {
            onSelect(status)
        } label: {
            Text(status.displayTitle)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(isSelected ? tint : Color.tasker.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? tint.opacity(0.12) : Color.tasker.surfaceSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? tint.opacity(0.2) : Color.tasker.strokeHairline.opacity(0.78), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
