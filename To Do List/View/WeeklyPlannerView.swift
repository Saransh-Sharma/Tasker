import SwiftUI

struct WeeklyPlannerView: View {
    @ObservedObject var viewModel: WeeklyPlannerViewModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                planningOverviewSection
                outcomeSection
                habitSection
                taskBucketsSection(title: "This Week", tasks: viewModel.thisWeekTasks, bucket: .thisWeek)
                taskBucketsSection(title: "Next Week", tasks: viewModel.nextWeekTasks, bucket: .nextWeek)
                taskBucketsSection(title: "Later", tasks: viewModel.laterTasks, bucket: .later)
            }
            .navigationTitle("Weekly Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Ask Eva") {
                        viewModel.requestEvaPreview()
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Saving..." : "Save") {
                        viewModel.save()
                    }
                    .disabled(viewModel.isSaving)
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
                if viewModel.availableProjects.isEmpty && !viewModel.isLoading {
                    viewModel.load()
                }
            }
            .alert("Weekly planning error", isPresented: Binding(
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

    private var planningOverviewSection: some View {
        Section("Frame the week") {
            TextField("What matters most this week?", text: $viewModel.focusStatement, axis: .vertical)
                .lineLimit(2...4)

            Stepper(value: $viewModel.targetCapacity, in: 1...30) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Capacity target: \(viewModel.targetCapacity)")
                    Text("Estimated sustainable pace: \(viewModel.estimatedCapacity)")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }
            }

            Toggle("Minimum viable week mode", isOn: $viewModel.minimumViableWeekEnabled)

            if viewModel.overloadCount > 0 {
                Label("\(viewModel.overloadCount) tasks over capacity right now", systemImage: "exclamationmark.triangle.fill")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.statusWarning)
            }
        }
    }

    private var outcomeSection: some View {
        Section {
            ForEach($viewModel.outcomeDrafts) { $draft in
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Outcome title", text: $draft.title)
                    Picker("Project", selection: $draft.sourceProjectID) {
                        Text("No project").tag(UUID?.none)
                        ForEach(viewModel.availableProjects, id: \.id) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    TextField("Why it matters", text: $draft.whyItMatters, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("What success looks like", text: $draft.successDefinition, axis: .vertical)
                        .lineLimit(1...3)

                    Button("Remove outcome", role: .destructive) {
                        viewModel.removeOutcomeDraft(id: draft.id)
                    }
                    .disabled(viewModel.outcomeDrafts.count == 1)
                }
                .padding(.vertical, 4)
            }

            if viewModel.canAddOutcome {
                Button("Add outcome") {
                    viewModel.addOutcomeDraft()
                }
            }
        } header: {
            Text("Top outcomes")
        } footer: {
            Text("Keep this to three outcomes max so the week stays legible.")
        }
    }

    private var habitSection: some View {
        Section("Habits to hold") {
            if viewModel.availableHabits.isEmpty {
                Text("No active habits available.")
                    .foregroundStyle(Color.tasker.textSecondary)
            } else {
                ForEach(viewModel.availableHabits, id: \.habitID) { habit in
                    Button {
                        viewModel.toggleHabit(habit.habitID)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.title)
                                    .foregroundStyle(Color.tasker.textPrimary)
                                Text(habit.projectName ?? habit.lifeAreaName)
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            }
                            Spacer()
                            Image(systemName: viewModel.selectedHabitIDs.contains(habit.habitID) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(viewModel.selectedHabitIDs.contains(habit.habitID) ? Color.tasker.accentPrimary : Color.tasker.textQuaternary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func taskBucketsSection(title: String, tasks: [TaskDefinition], bucket: TaskPlanningBucket) -> some View {
        Section(title) {
            if tasks.isEmpty {
                Text("No tasks staged here.")
                    .foregroundStyle(Color.tasker.textSecondary)
            } else {
                ForEach(tasks, id: \.id) { task in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .foregroundStyle(Color.tasker.textPrimary)
                            if let dueDate = task.dueDate {
                                Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            }
                        }
                        Spacer()
                        Menu(bucket.title) {
                            ForEach(TaskPlanningBucket.weeklyPlannerBuckets, id: \.self) { option in
                                Button(option.title) {
                                    viewModel.moveTask(task.id, to: option)
                                }
                            }
                        }
                    }
                }
            }
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
            List {
                Section("Summary") {
                    LabeledContent("Affected tasks", value: "\(state.preview.affectedTaskCount)")
                    LabeledContent("Destructive changes", value: "\(state.preview.destructiveCount)")
                    Text(state.preview.rationale)
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Section("Diff") {
                    ForEach(Array(state.preview.diffLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: line.isDestructive ? "arrow.turn.down.right" : "checkmark.circle")
                                .foregroundStyle(line.isDestructive ? Color.tasker.statusWarning : Color.tasker.accentPrimary)
                            Text(line.text)
                                .foregroundStyle(Color.tasker.textPrimary)
                        }
                    }
                }

                if let errorMessage = state.errorMessage {
                    Section("Issue") {
                        Text(errorMessage)
                            .foregroundStyle(Color.tasker.statusWarning)
                    }
                }
            }
            .navigationTitle("Eva Weekly Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
                ToolbarItem(placement: .primaryAction) {
                    if state.preview.run == nil {
                        Button(state.isWorking ? "Working..." : "Suggest") {
                            onSuggest()
                        }
                        .disabled(state.isWorking)
                    } else {
                        Button(state.isWorking ? "Applying..." : "Confirm") {
                            onConfirm()
                        }
                        .disabled(state.isWorking)
                    }
                }
                if state.preview.run != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Reject", role: .destructive, action: onReject)
                            .disabled(state.isWorking)
                    }
                }
            }
        }
    }
}

private extension TaskPlanningBucket {
    static var weeklyPlannerBuckets: [TaskPlanningBucket] {
        [.thisWeek, .nextWeek, .later]
    }

    var title: String {
        switch self {
        case .today:
            return "This Week"
        case .thisWeek:
            return "This Week"
        case .nextWeek:
            return "Next Week"
        case .later:
            return "Later"
        case .someday:
            return "Later"
        }
    }
}
