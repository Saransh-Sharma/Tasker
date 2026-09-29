import SwiftUI

extension PlanRootView {
    func withAlerts<Content: View>(_ content: Content) -> some View {
        content
            .alert("Couldn’t update plan", isPresented: errorBinding) {
                Button("OK", role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .confirmationDialog(
                backlogDeletionTitle,
                isPresented: $showsBacklogDeletionConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    let taskIDs = pendingBacklogDeletionTaskIDs
                    pendingBacklogDeletionTaskIDs.removeAll()
                    selectedTaskIDs.subtract(taskIDs)
                    Task { await store.deleteBacklogTasks(taskIDs) }
                }
                Button("Cancel", role: .cancel) { pendingBacklogDeletionTaskIDs.removeAll() }
            } message: {
                Text("You can undo this.")
            }
            .alert(
                "Couldn’t use template",
                isPresented: Binding(
                    get: { projectTemplateError != nil },
                    set: { if $0 == false { projectTemplateError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { projectTemplateError = nil }
            } message: {
                Text(projectTemplateError ?? "")
            }
    }

    private var backlogDeletionTitle: String {
        let count = pendingBacklogDeletionTaskIDs.count
        return count == 1
            ? String(localized: "Delete this task?")
            : String(localized: "Delete \(count) tasks?")
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil && store.daySnapshot != nil },
            set: { if $0 == false { store.errorMessage = nil } }
        )
    }
}
