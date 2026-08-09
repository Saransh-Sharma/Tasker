import SwiftUI
import UIKit

struct HabitListRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void
    let onTogglePause: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onOpen()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    AccentIconBadge(
                        symbolName: row.row.icon?.symbolName ?? "circle.dashed",
                        accentHex: row.row.colorHex ?? lifeManagementAreaAccentHex(row.lifeArea)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.row.title)
                            .font(.lifeboard(.bodyEmphasis))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text(habitSubtitle)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button(row.row.isPaused ? "Resume" : "Pause", systemImage: row.row.isPaused ? "play.fill" : "pause.fill") {
                    onTogglePause()
                }
                Button(String(localized: "Archive", defaultValue: "Archive"), systemImage: "archivebox") {
                    onArchive()
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
    }

    var habitSubtitle: String {
        var parts: [String] = [row.row.kind == .positive ? "Build" : "Quit"]
        parts.append(lifeManagementHabitStatusText(row.row))
        return parts.joined(separator: " · ")
    }
}
