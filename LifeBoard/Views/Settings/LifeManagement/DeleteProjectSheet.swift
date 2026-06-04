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
                Section("Delete Project") {
                    Text("\(draft.projectName) has \(draft.taskCount) open tasks and \(draft.linkedHabitCount) linked habits. Move the open tasks before you delete it.")
                }

                Section("Move open tasks to") {
                    Picker("Project", selection: $draft.destinationProjectID) {
                        ForEach(targets) { target in
                            Text(target.project.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Delete Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
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
