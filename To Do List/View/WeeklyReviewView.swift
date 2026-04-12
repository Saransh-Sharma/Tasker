import SwiftUI

struct WeeklyReviewView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel
    let onClose: () -> Void
    let onCompleted: (String) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    @State private var showingReflectionComposer = false

    init(
        viewModel: WeeklyReviewViewModel,
        onClose: @escaping () -> Void,
        onCompleted: @escaping (String) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.onCompleted = onCompleted
    }

    var body: some View {
        let renderedSnapshot = viewModel.reviewSnapshot

        return NavigationStack {
            WeeklyRitualScaffold(
                eyebrow: "Weekly review",
                title: WeeklyCopy.reviewTitle,
                subtitle: WeeklyCopy.reviewSubtitle,
                weekRange: viewModel.weekRangeText,
                steps: renderedSnapshot?.reviewSteps ?? viewModel.reviewSteps,
                message: viewModel.saveMessage,
                messageTone: .accent
            ) {
                if let renderedSnapshot {
                    WeeklyReviewRealityStep(
                        completedTasks: renderedSnapshot.completedTasks,
                        unfinishedTasks: renderedSnapshot.unfinishedTasks,
                        reflectionCount: renderedSnapshot.reflectionNotes.count,
                        selectedHabits: renderedSnapshot.selectedHabits,
                        selectedHabitIDs: viewModel.snapshot?.plan?.selectedHabitIDs ?? []
                    )
                    WeeklyReviewOutcomesStep(
                        outcomeSnapshots: renderedSnapshot.outcomeSnapshots,
                        onSelectStatus: viewModel.setOutcomeStatus(_:for:)
                    )
                    WeeklyReviewCleanupStep(
                        unfinishedTasks: renderedSnapshot.unfinishedTasks,
                        taskDecisions: viewModel.taskDecisions,
                        onSelectDisposition: viewModel.setDecision(_:for:),
                        onApplyToAll: viewModel.applyDecisionToAllUnfinished(_:)
                    )
                    WeeklyReviewReflectionStep(
                        wins: $viewModel.wins,
                        blockers: $viewModel.blockers,
                        lessons: $viewModel.lessons,
                        nextWeekPrepNotes: $viewModel.nextWeekPrepNotes,
                        perceivedWeekRating: $viewModel.perceivedWeekRating
                    )
                    WeeklyReviewNotesStep(
                        reflectionNotes: renderedSnapshot.reflectionNotes,
                        onAddReflection: { showingReflectionComposer = true }
                    )
                }
            } footer: {
                WeeklyStickyActionBar {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review status")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                        Text(viewModel.footerSnapshot.completionSummaryText)
                            .font(.tasker(.caption2))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } trailing: {
                    Button(viewModel.isSaving ? "Saving..." : WeeklyCopy.finishReview) {
                        viewModel.completeReview { message in
                            onCompleted(message)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving || !viewModel.footerSnapshot.canFinishReview)
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
}

private struct WeeklyReviewRealityStep: View {
    let completedTasks: [TaskDefinition]
    let unfinishedTasks: [TaskDefinition]
    let reflectionCount: Int
    let selectedHabits: [HabitLibraryRow]
    let selectedHabitIDs: [UUID]

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[0],
            detail: "Start with the facts before deciding what the week means."
        ) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                HStack(spacing: spacing.s8) {
                    metricPill(value: "\(completedTasks.count)", label: "Done")
                    metricPill(value: "\(unfinishedTasks.count)", label: "To resolve")
                    metricPill(value: "\(reflectionCount)", label: "Reflections")
                }

                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Check habits")
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)

                    if selectedHabitIDs.isEmpty {
                        Text("No habits were intentionally carried into this week.")
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else if selectedHabits.isEmpty {
                        Text("Habit details will appear here after the review reloads current streaks.")
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(selectedHabits, id: \.habitID) { habit in
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
                                    tone: .accent
                                )
                            }
                            .padding(14)
                            .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfaceSecondary.opacity(0.84))
                        }
                    }
                }
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
}

private struct WeeklyReviewOutcomesStep: View {
    let outcomeSnapshots: [WeeklyReviewOutcomeSnapshot]
    let onSelectStatus: (WeeklyOutcomeStatus, UUID) -> Void

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[1],
            detail: "Check outcomes before deciding what unfinished work should mean."
        ) {
            if outcomeSnapshots.isEmpty {
                Text(WeeklyCopy.noOutcomes)
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(outcomeSnapshots.enumerated()), id: \.element.id) { index, snapshot in
                        WeeklyOutcomeReviewRow(
                            outcomeSnapshot: snapshot,
                            displayIndex: index + 1,
                            onSelect: { onSelectStatus($0, snapshot.id) }
                        )
                    }
                }
            }
        }
    }
}

private struct WeeklyReviewCleanupStep: View {
    let unfinishedTasks: [TaskDefinition]
    let taskDecisions: [UUID: WeeklyReviewTaskDisposition]
    let onSelectDisposition: (WeeklyReviewTaskDisposition, UUID) -> Void
    let onApplyToAll: (WeeklyReviewTaskDisposition) -> Void

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[2],
            detail: "Give every unfinished task a clear next home."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    bulkDecisionButton(title: "Carry all", disposition: .carry)
                    bulkDecisionButton(title: "Move all later", disposition: .later)
                    bulkDecisionButton(title: "Drop all", disposition: .drop)
                }

                if unfinishedTasks.isEmpty {
                    Text(WeeklyCopy.noUnfinishedWork)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                } else {
                    ForEach(unfinishedTasks, id: \.id) { task in
                        WeeklyDecisionRow(
                            task: task,
                            selectedDisposition: taskDecisions[task.id] ?? .carry,
                            onSelect: { onSelectDisposition($0, task.id) }
                        )
                    }
                }
            }
        }
    }

    private func bulkDecisionButton(title: String, disposition: WeeklyReviewTaskDisposition) -> some View {
        Button(title) {
            onApplyToAll(disposition)
        }
        .buttonStyle(.bordered)
        .tint(disposition.tintColor)
    }
}

private struct WeeklyReviewReflectionStep: View {
    @Binding var wins: String
    @Binding var blockers: String
    @Binding var lessons: String
    @Binding var nextWeekPrepNotes: String
    @Binding var perceivedWeekRating: Int

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[3],
            detail: "Capture only the signals that will help next week start sharper."
        ) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                reflectionField(
                    title: "What got done",
                    helper: "Name the few things that genuinely moved forward.",
                    text: $wins
                )
                reflectionField(
                    title: "What got in the way",
                    helper: "Keep it factual so you can act on it later.",
                    text: $blockers
                )
                reflectionField(
                    title: "What should you repeat or change",
                    helper: "One clear lesson is more useful than a long retrospective.",
                    text: $lessons
                )
                reflectionField(
                    title: "Set up next week",
                    helper: "Leave a short note that makes Monday easier to start.",
                    text: $nextWeekPrepNotes
                )

                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("How did the week feel?")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)

                    HStack(spacing: spacing.s8) {
                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                perceivedWeekRating = rating
                            } label: {
                                Text("\(rating)")
                                    .font(.tasker(.bodyEmphasis))
                                    .foregroundStyle(perceivedWeekRating == rating ? Color.tasker.accentOnPrimary : Color.tasker.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(perceivedWeekRating == rating ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
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

private struct WeeklyReviewNotesStep: View {
    let reflectionNotes: [ReflectionNote]
    let onAddReflection: () -> Void

    var body: some View {
        WeeklySectionCard(
            title: "Weekly reflections",
            detail: "These notes help later reviews stay grounded in what actually happened."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Button(WeeklyCopy.addReflection) {
                    onAddReflection()
                }
                .buttonStyle(.bordered)

                if reflectionNotes.isEmpty {
                    Text(WeeklyCopy.noWeeklyNotes)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                } else {
                    ForEach(reflectionNotes, id: \.id) { note in
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
}

private struct WeeklyOutcomeReviewRow: View {
    let outcomeSnapshot: WeeklyReviewOutcomeSnapshot
    let displayIndex: Int
    let onSelect: (WeeklyOutcomeStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(displayIndex).")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(outcomeSnapshot.outcome.title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker.textPrimary)

                    if let successDefinition = outcomeSnapshot.outcome.successDefinition, successDefinition.isEmpty == false {
                        Text(successDefinition)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                    }

                    if outcomeSnapshot.linkedTaskCount > 0 {
                        Text("\(outcomeSnapshot.linkedTaskCount) linked task\(outcomeSnapshot.linkedTaskCount == 1 ? "" : "s")")
                            .font(.tasker(.caption2))
                            .foregroundStyle(Color.tasker.textSecondary)
                    }
                }
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
        let isSelected = outcomeSnapshot.selectedStatus == status
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
