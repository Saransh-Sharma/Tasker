import SwiftUI
import UIKit

struct DeleteAreaSheet: View {
    @State var draft: LifeManagementDeleteAreaDraft
    let targets: [LifeManagementAreaRow]
    let isSaving: Bool
    let onSave: (LifeManagementDeleteAreaDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementDeleteAreaDraft,
        targets: [LifeManagementAreaRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementDeleteAreaDraft) -> Void,
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
                Section("Delete Area") {
                    Text("\(draft.areaName) has \(draft.projectCount) projects and \(draft.habitCount) habits. Move them to another area before you delete it.")
                }

                Section("Move items to") {
                    Picker("Destination", selection: $draft.destinationLifeAreaID) {
                        ForEach(targets) { target in
                            Text(target.lifeArea.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Delete Area")
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
                    .disabled(isSaving || draft.destinationLifeAreaID == nil)
                }
            }
        }
    }
}
