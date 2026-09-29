import SwiftUI
import UIKit

struct DeleteProjectSheet: View {
    @State var draft: LifeManagementDeleteProjectDraft
    let targets: [LifeManagementProjectRow]
    let isSaving: Bool
    let onSave: (LifeManagementDeleteProjectDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementDeleteProjectDraft,
        targets: [LifeManagementProjectRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementDeleteProjectDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Delete project") {
                    Text("‘\(draft.projectName)’ has ^[\(draft.taskCount) open task](inflect: true) and ^[\(draft.linkedHabitCount) linked habit](inflect: true).")
                }

                Section("Move open tasks to") {
                    Picker("Project", selection: $draft.destinationProjectID) {
                        ForEach(targets) { target in
                            Text(target.project.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            .navigationTitle("Delete project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.destinationProjectID == nil)
                }
            }
        }
    }
}
