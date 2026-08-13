import SwiftUI
import UIKit

struct ProjectListRow: View {
    let row: LifeManagementProjectRow
    let destination: LifeManagementSelection
    let onEdit: () -> Void
    let onMove: (() -> Void)?
    let onArchive: (() -> Void)?
    let onDelete: (() -> Void)?
    let onDrag: () -> NSItemProvider

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(value: destination) {
                HStack(alignment: .top, spacing: 12) {
                    AccentIconBadge(
                        symbolName: row.project.icon.systemImageName,
                        accentHex: row.project.color.hexString
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.project.name)
                            .font(.lifeboard(.bodyEmphasis))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text(projectSubtitle)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit", systemImage: "pencil") {
                    onEdit()
                }
                if let onMove {
                    Button("Move Project", systemImage: "arrow.left.arrow.right") {
                        onMove()
                    }
                }
                if let onArchive {
                    Button(String(localized: "Archive", defaultValue: "Archive"), systemImage: "archivebox") {
                        onArchive()
                    }
                }
                if let onDelete {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
        .onDrag {
            onDrag()
        }
    }

    var projectSubtitle: String {
        if row.taskCount == 0 {
            return "Empty"
        }
        let owner = row.lifeArea?.name ?? "No Area"
        return "\(owner) · \(row.taskCount) open tasks"
    }
}
