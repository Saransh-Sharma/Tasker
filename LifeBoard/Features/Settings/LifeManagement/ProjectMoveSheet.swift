import SwiftUI
import UIKit

struct ProjectMoveSheet: View {
    @State var draft: LifeManagementProjectMoveDraft
    let targets: [LifeManagementAreaRow]
    let isSaving: Bool
    let onSave: (LifeManagementProjectMoveDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementProjectMoveDraft,
        targets: [LifeManagementAreaRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementProjectMoveDraft) -> Void,
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
                Section("Project") {
                    Text(draft.projectName)
                }

                Section("Move to Area") {
                    Picker("Area", selection: $draft.targetLifeAreaID) {
                        ForEach(targets) { target in
                            Text(target.lifeArea.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Move Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.targetLifeAreaID == nil)
                }
            }
        }
    }
}
