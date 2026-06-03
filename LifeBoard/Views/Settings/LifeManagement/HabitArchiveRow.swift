import SwiftUI
import UIKit

struct HabitArchiveRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HabitSummaryRow(row: row, onOpen: onOpen)

            Menu {
                Button("Restore", systemImage: "arrow.uturn.backward") {
                    onRestore()
                }
                Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
    }
}
