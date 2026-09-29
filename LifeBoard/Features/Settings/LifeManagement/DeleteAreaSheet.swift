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
                Section("Delete area") {
                    Text("‘\(draft.areaName)’ has ^[\(draft.projectCount) project](inflect: true) and ^[\(draft.habitCount) habit](inflect: true). Move them first.")
                }

                Section("Move them to") {
                    Picker("Area", selection: $draft.destinationLifeAreaID) {
                        ForEach(targets) { target in
                            Text(target.lifeArea.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            .navigationTitle("Delete area")
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
                    .disabled(isSaving || draft.destinationLifeAreaID == nil)
                }
            }
        }
    }
}
