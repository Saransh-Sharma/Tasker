import SwiftUI

extension TaskDetailScreen {
    var breakdownSheet: some View {
        NavigationStack {
            List {
                if viewModel.aiBreakdownRouteBanner != nil || viewModel.aiBreakdownSteps.isEmpty {
                    Text(viewModel.aiBreakdownRouteBanner ?? String(localized: "Thinking…"))
                }
                ForEach(viewModel.aiBreakdownSteps, id: \.self) { step in
                    Button {
                        if selectedBreakdownSteps.contains(step) {
                            selectedBreakdownSteps.remove(step)
                        } else {
                            selectedBreakdownSteps.insert(step)
                        }
                    } label: {
                        Label(step, systemImage: selectedBreakdownSteps.contains(step) ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            .navigationTitle("Breakdown")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBreakdownSheet = false }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to task") {
                        viewModel.addBreakdownSteps(Array(selectedBreakdownSteps)) {
                            showBreakdownSheet = false
                        }
                    }
                    .disabled(selectedBreakdownSteps.isEmpty)
                }
            }
        }
    }


    var reflectionComposerSheet: some View {
        ReflectionNoteComposerView(
            viewModel: ReflectionNoteComposerViewModel(
                title: String(localized: "Task note"),
                kind: viewModel.isComplete ? .taskCompletion : .freeform,
                linkedTaskID: viewModel.persistedTask.id,
                linkedProjectID: viewModel.selectedProjectID,
                prompt: viewModel.isComplete ? String(localized: "What helped?") : String(localized: "What’s changed?"),
                saveNoteHandler: onSaveReflectionNote
            )
        ) { _ in
            viewModel.refreshRelationshipMetadata()
        }
    }

    var metadataFooter: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text("Added \(DateUtils.formatDateTime(viewModel.persistedTask.dateAdded))")
            if viewModel.isComplete, let completedAt = viewModel.persistedTask.dateCompleted {
                Text("Completed \(DateUtils.formatDateTime(completedAt))")
            }
        }
        .font(.lifeboard(.caption1))
        .foregroundStyle(Color.lifeboard.textTertiary)
    }

    func projectMotivationCard(_ motivation: ProjectWeeklyMotivation) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Project motivation")
                .font(.lifeboard(.callout).weight(.semibold))
            if let why = motivation.why, why.isEmpty == false {
                motivationRow("Why now", why)
            }
            if let success = motivation.successLooksLike, success.isEmpty == false {
                motivationRow("Success looks like", success)
            }
            if let cost = motivation.costOfNeglect, cost.isEmpty == false {
                motivationRow("If ignored", cost)
            }
        }
        .padding(spacing.s12)
        .lifeboardDenseSurface(cornerRadius: Theme.CornerRadius.md, fillColor: Color.lifeboard.accentWash.opacity(0.72))
    }

    private func motivationRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textTertiary)
            Text(value)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textPrimary)
        }
    }
}
