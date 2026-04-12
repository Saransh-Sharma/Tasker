import SwiftUI

struct WeeklyReviewView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel
    let onClose: () -> Void
    @State private var showingReflectionComposer = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Outcome recap") {
                    if let snapshot = viewModel.snapshot, snapshot.outcomes.isEmpty == false {
                        ForEach(snapshot.outcomes, id: \.id) { outcome in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(outcome.title)
                                        if let successDefinition = outcome.successDefinition, !successDefinition.isEmpty {
                                            Text(successDefinition)
                                                .font(.tasker(.caption1))
                                                .foregroundStyle(Color.tasker.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Menu(viewModel.outcomeStatusesByID[outcome.id, default: .planned].title) {
                                        ForEach(WeeklyOutcomeStatus.allCases, id: \.self) { status in
                                            Button(status.title) {
                                                viewModel.setOutcomeStatus(status, for: outcome.id)
                                            }
                                        }
                                    }
                                }
                                Text("Mark the real outcome so weekly momentum stays honest.")
                                    .font(.tasker(.caption2))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            }
                        }
                    } else {
                        Text("No saved outcomes for this week.")
                            .foregroundStyle(Color.tasker.textSecondary)
                    }
                }

                Section("Habit recap") {
                    if let plan = viewModel.snapshot?.plan, plan.selectedHabitIDs.isEmpty {
                        Text("No habits were explicitly carried into this week.")
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else if viewModel.selectedHabits.isEmpty {
                        Text("Selected habits will appear here once the review reloads their latest streaks.")
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(viewModel.selectedHabits, id: \.habitID) { habit in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(habit.title)
                                    Spacer()
                                    Text("\(habit.currentStreak)d streak")
                                        .font(.tasker(.caption1))
                                        .foregroundStyle(Color.tasker.textSecondary)
                                }
                                Text(habit.lifeAreaName)
                                    .font(.tasker(.caption2))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Completed work") {
                    if viewModel.completedTasks.isEmpty {
                        Text("Nothing completed from the weekly bucket yet.")
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(viewModel.completedTasks, id: \.id) { task in
                            Label(task.title, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.tasker.accentPrimary)
                        }
                    }
                }

                Section("Unfinished work") {
                    if viewModel.unfinishedTasks.isEmpty {
                        Text("No unfinished weekly tasks.")
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(viewModel.unfinishedTasks, id: \.id) { task in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(task.title)
                                Picker(
                                    "Disposition",
                                    selection: Binding(
                                        get: { viewModel.taskDecisions[task.id] ?? .carry },
                                        set: { viewModel.setDecision($0, for: task.id) }
                                    )
                                ) {
                                    Text("Carry").tag(WeeklyReviewTaskDisposition.carry)
                                    Text("Later").tag(WeeklyReviewTaskDisposition.later)
                                    Text("Drop").tag(WeeklyReviewTaskDisposition.drop)
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Reflection") {
                    TextField("Wins", text: $viewModel.wins, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Blockers", text: $viewModel.blockers, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Lessons", text: $viewModel.lessons, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Prep for next week", text: $viewModel.nextWeekPrepNotes, axis: .vertical)
                        .lineLimit(2...4)

                    Stepper(value: $viewModel.perceivedWeekRating, in: 1...5) {
                        Text("Week rating: \(viewModel.perceivedWeekRating)/5")
                    }
                }

                Section("Weekly notes") {
                    Button("Capture reflection note") {
                        showingReflectionComposer = true
                    }

                    if viewModel.reflectionNotes.isEmpty {
                        Text("Capture one note to keep the review grounded in what actually happened.")
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(viewModel.reflectionNotes, id: \.id) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.noteText)
                                    .foregroundStyle(Color.tasker.textPrimary)
                                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.tasker(.caption2))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Weekly Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Saving..." : "Complete") {
                        viewModel.completeReview()
                    }
                    .disabled(viewModel.isSaving || viewModel.snapshot?.plan == nil)
                }
            }
            .overlay(alignment: .bottom) {
                if let saveMessage = viewModel.saveMessage {
                    Text(saveMessage)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.tasker.surfaceSecondary)
                        .clipShape(Capsule())
                        .padding(.bottom, 16)
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
            .alert("Weekly review error", isPresented: Binding(
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
                            title: "Weekly reflection",
                            kind: .weeklyReview,
                            linkedWeeklyPlanID: linkedWeeklyPlanID,
                            prompt: "What should this week teach future-you?",
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

private extension WeeklyOutcomeStatus {
    var title: String {
        switch self {
        case .planned:
            return "Planned"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .dropped:
            return "Dropped"
        }
    }
}
