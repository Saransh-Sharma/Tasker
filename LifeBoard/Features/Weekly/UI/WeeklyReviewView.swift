import SwiftUI

struct WeeklyReviewView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel
    let onClose: () -> Void
    let onCompleted: (String) -> Void
    /// False when pushed onto an existing stack; see `OptionalNavigationStack`.
    let embedsInNavigationStack: Bool

    @Environment(\.lifeboardTokens) private var tokens
    @State private var showingReflectionComposer = false
    /// The commit phase for "Finish review", so running, success and a
    /// recoverable failure are all distinguishable.
    @State private var finishPhase: AsyncActionPhase<String> = .idle

    init(
        viewModel: WeeklyReviewViewModel,
        onClose: @escaping () -> Void,
        onCompleted: @escaping (String) -> Void = { _ in },
        embedsInNavigationStack: Bool = true
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.onCompleted = onCompleted
        self.embedsInNavigationStack = embedsInNavigationStack
    }

    var body: some View {
        let renderedSnapshot = viewModel.reviewSnapshot

        return OptionalNavigationStack(isEnabled: embedsInNavigationStack) {
            WeeklyRitualScaffold(
                eyebrow: "Weekly review",
                title: WeeklyCopy.reviewTitle,
                subtitle: WeeklyCopy.reviewSubtitle,
                weekRange: viewModel.weekRangeText,
                steps: renderedSnapshot?.reviewSteps ?? viewModel.reviewSteps,
                message: viewModel.saveMessage,
                messageTone: .accent,
                headerScene: .insights
            ) {
                if viewModel.hasLoadedInitialData == false {
                    if viewModel.isLoading {
                        WeeklyReviewBlockingStateCard(
                            title: "Loading…",
                            message: "",
                            showsProgress: true,
                            primaryActionTitle: nil,
                            onPrimaryAction: nil
                        )
                    } else if let errorMessage = viewModel.errorMessage {
                        WeeklyReviewBlockingStateCard(
                            title: WeeklyCopy.reviewErrorTitle,
                            message: errorMessage,
                            showsProgress: false,
                            primaryActionTitle: "Try again",
                            onPrimaryAction: { viewModel.load() }
                        )
                    } else {
                        WeeklyReviewBlockingStateCard(
                            title: "Loading…",
                            message: "",
                            showsProgress: true,
                            primaryActionTitle: nil,
                            onPrimaryAction: nil
                        )
                    }
                } else if let renderedSnapshot {
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
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                        Text(viewModel.footerSnapshot.completionSummaryText)
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } trailing: {
                    // Was a title swap to "Saving..." on a plain button. The
                    // shared control carries running, success and recoverable
                    // failure as real phases, which is what `DESIGN.md` asks of
                    // a commit.
                    AsyncActionControl(
                        title: WeeklyCopy.finishReview,
                        runningTitle: "Saving…",
                        successTitle: WeeklyCopy.reviewSaveSuccess,
                        phase: finishPhase
                    ) {
                        guard viewModel.isSaving == false else { return }
                        finishPhase = .running(progress: nil)
                        viewModel.completeReview { result in
                            switch result {
                            case .success(let message):
                                finishPhase = .success(receipt: message)
                                onCompleted(message)
                            case .failure(let error):
                                finishPhase = .recoverableFailure(.init(
                                    message: error.localizedDescription,
                                    recovery: .retry
                                ))
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.footerSnapshot.canFinishReview)
                }
            }
            .navigationTitle(WeeklyCopy.reviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Pushed, Back already leaves; see `EvaRitualShell`.
                if embedsInNavigationStack {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                            .accessibilityLabel("Close weekly review")
                            .keyboardShortcut(.cancelAction)
                    }
                }
            }
            .task {
                if viewModel.snapshot == nil && !viewModel.isLoading {
                    viewModel.load()
                }
            }
            .alert(WeeklyCopy.reviewErrorTitle, isPresented: Binding(
                get: { viewModel.errorMessage != nil && viewModel.hasLoadedInitialData },
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
                            prompt: String(localized: "What to remember next week?"),
                            saveNoteHandler: { note, completion in
                                viewModel.saveReflectionNote(note, completion: completion)
                            }
                        )
                    )
                }
            }
            .accessibilityIdentifier("weeklyReview.view")
        }
    }
}

private struct WeeklyReviewBlockingStateCard: View {
    let title: String
    let message: String
    let showsProgress: Bool
    let primaryActionTitle: String?
    let onPrimaryAction: (() -> Void)?

    var body: some View {
        WeeklySectionCard(title: title, detail: message) {
            HStack(spacing: 12) {
                DecorImage(asset: showsProgress ? .decisionSign : .thinkingCup, size: 44, opacity: 0.9)

                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                }

                if let primaryActionTitle, let onPrimaryAction {
                    Button(primaryActionTitle, action: onPrimaryAction)
                        .buttonStyle(.lifeBoardPrimaryCompact)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}

private struct WeeklyReviewRealityStep: View {
    let completedTasks: [TaskDefinition]
    let unfinishedTasks: [TaskDefinition]
    let reflectionCount: Int
    let selectedHabits: [HabitLibraryRow]
    let selectedHabitIDs: [UUID]

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[0]
        ) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                HStack(spacing: spacing.s8) {
                    metricPill(value: "\(completedTasks.count)", label: "Done")
                    metricPill(value: "\(unfinishedTasks.count)", label: "To sort")
                    metricPill(value: "\(reflectionCount)", label: "Notes")
                }

                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Habits")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)

                    if selectedHabitIDs.isEmpty {
                        Text("No habits this week")
                            .font(.lifeboard(.support))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    } else if selectedHabits.isEmpty {
                        Text("Loading…")
                            .font(.lifeboard(.support))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    } else {
                        ForEach(selectedHabits, id: \.habitID) { habit in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.title)
                                        .font(.lifeboard(.bodyEmphasis))
                                        .foregroundStyle(Color.lifeboard.textPrimary)
                                    Text(habit.lifeAreaName)
                                        .font(.lifeboard(.caption2))
                                        .foregroundStyle(Color.lifeboard.textSecondary)
                                }

                                Spacer()

                                StatusPill(
                                    text: habit.currentStreak == 1
                                        ? String(localized: "1-day streak")
                                        : String(localized: "\(habit.currentStreak)-day streak"),
                                    systemImage: "leaf.fill",
                                    tone: .accent
                                )
                            }
                            .padding(14)
                            .lifeboardDenseSurface(cornerRadius: Radius.card, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.84))
                            .lifeBoardScrollEntrance(intensity: 0.55)
                        }
                    }
                }
            }
        }
    }

    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.lifeboard(.bodyEmphasis))
                .foregroundStyle(Color.lifeboard.accentPrimary)
            Text(label)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WeeklyReviewOutcomesStep: View {
    let outcomeSnapshots: [WeeklyReviewOutcomeSnapshot]
    let onSelectStatus: (WeeklyOutcomeStatus, UUID) -> Void

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[1]
        ) {
            if outcomeSnapshots.isEmpty {
                Text(WeeklyCopy.noOutcomes)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(outcomeSnapshots.enumerated()), id: \.element.id) { index, snapshot in
                        WeeklyOutcomeReviewRow(
                            outcomeSnapshot: snapshot,
                            displayIndex: index + 1,
                            onSelect: { onSelectStatus($0, snapshot.id) }
                        )
                        .lifeBoardScrollEntrance()
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

    @State private var confirmsDropAll = false

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[2]
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    bulkDecisionButton(title: String(localized: "Keep all"), disposition: .carry)
                    bulkDecisionButton(title: String(localized: "All to Later"), disposition: .later)
                    // Dropping every unfinished task at once is the one bulk
                    // decision that throws work away, so it says so first.
                    // `DESIGN.md`: explain consequences before a consequential
                    // action.
                    bulkDecisionButton(title: String(localized: "All to Someday"), disposition: .drop) {
                        confirmsDropAll = true
                    }
                }
                .confirmationDialog(
                    "Move all to Someday?",
                    isPresented: $confirmsDropAll,
                    titleVisibility: .visible
                ) {
                    Button("Move all \(unfinishedTasks.count)", role: .destructive) {
                        onApplyToAll(.drop)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("They leave this week’s plan.")
                }

                if unfinishedTasks.isEmpty {
                    Text(WeeklyCopy.noUnfinishedWork)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                } else {
                    ForEach(unfinishedTasks, id: \.id) { task in
                        WeeklyDecisionRow(
                            task: task,
                            selectedDisposition: taskDecisions[task.id] ?? .carry,
                            onSelect: { onSelectDisposition($0, task.id) }
                        )
                        .lifeBoardScrollEntrance()
                    }
                }
            }
        }
    }

    private func bulkDecisionButton(
        title: String,
        disposition: WeeklyReviewTaskDisposition,
        action: (() -> Void)? = nil
    ) -> some View {
        Button(title) {
            if let action {
                action()
            } else {
                onApplyToAll(disposition)
            }
        }
        .buttonStyle(.bordered)
        .tint(disposition.tintColor)
        .frame(minHeight: 44)
    }
}

private struct WeeklyReviewReflectionStep: View {
    @Binding var wins: String
    @Binding var blockers: String
    @Binding var lessons: String
    @Binding var nextWeekPrepNotes: String
    @Binding var perceivedWeekRating: Int

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        WeeklySectionCard(
            title: WeeklyCopy.reviewSteps[3]
        ) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                reflectionField(
                    title: String(localized: "What got done"),
                    helper: "",
                    text: $wins
                )
                reflectionField(
                    title: String(localized: "Blockers"),
                    helper: "",
                    text: $blockers
                )
                reflectionField(
                    title: String(localized: "Lessons"),
                    helper: "",
                    text: $lessons
                )
                reflectionField(
                    title: String(localized: "Next week"),
                    helper: "",
                    text: $nextWeekPrepNotes
                )

                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("How did the week feel?")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)

                    HStack(spacing: spacing.s8) {
                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                perceivedWeekRating = rating
                            } label: {
                                Text("\(rating)")
                                    .font(.lifeboard(.bodyEmphasis))
                                    .foregroundStyle(perceivedWeekRating == rating ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                                            .fill(perceivedWeekRating == rating ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                                    )
                            }
                            .buttonStyle(.plain)
                            // Colour alone carried the selection, and the label
                            // read as a bare number. `DESIGN.md`: selection uses
                            // accessibility state, never tint alone.
                            .accessibilityLabel("Week felt \(rating) out of 5")
                            .accessibilityAddTraits(perceivedWeekRating == rating ? [.isSelected] : [])
                            .accessibilityIdentifier("weekly.review.rating.\(rating)")
                        }
                    }
                }
            }
        }
    }

    private func reflectionField(title: String, helper: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)

            TextField(title, text: text, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .lifeboardDenseSurface(cornerRadius: 16, fillColor: Color.lifeboard.surfaceSecondary)

            if helper.isEmpty == false {
                Text(helper)
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct WeeklyReviewNotesStep: View {
    let reflectionNotes: [ReflectionNote]
    let onAddReflection: () -> Void

    var body: some View {
        WeeklySectionCard(
            title: "Notes"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Button(WeeklyCopy.addReflection) {
                    onAddReflection()
                }
                .buttonStyle(.lifeBoardChip)

                if reflectionNotes.isEmpty {
                    Text(WeeklyCopy.noWeeklyNotes)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                } else {
                    ForEach(reflectionNotes, id: \.id) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            if let prompt = note.prompt, prompt.isEmpty == false {
                                Text(prompt)
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard.textSecondary)
                            }
                            Text(note.noteText)
                                .font(.lifeboard(.support))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.lifeboard(.caption2))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                        }
                        .padding(14)
                        .lifeboardDenseSurface(cornerRadius: Radius.card, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.84))
                        .lifeBoardScrollEntrance(intensity: 0.55)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(displayIndex).")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text(outcomeSnapshot.outcome.title)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard.textPrimary)

                    if let successDefinition = outcomeSnapshot.outcome.successDefinition, successDefinition.isEmpty == false {
                        Text(successDefinition)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }

                    if outcomeSnapshot.linkedTaskCount > 0 {
                        Text(outcomeSnapshot.linkedTaskCount == 1
                            ? String(localized: "1 linked task")
                            : String(localized: "\(outcomeSnapshot.linkedTaskCount) linked tasks"))
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color.lifeboard.textSecondary)
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
        .lifeboardDenseSurface(cornerRadius: Radius.card, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.84))
    }

    private func statusButton(_ status: WeeklyOutcomeStatus) -> some View {
        let isSelected = outcomeSnapshot.selectedStatus == status
        let tint = status.tintColor

        return Button {
            onSelect(status)
        } label: {
            Text(status.displayTitle)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(isSelected ? tint : Color.lifeboard.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? tint.opacity(0.12) : Color.lifeboard.surfaceSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? tint.opacity(0.2) : Color.lifeboard.strokeHairline.opacity(0.78), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
