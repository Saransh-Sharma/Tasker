import SwiftUI
import UIKit

struct ProjectSummaryRow: View {
    let row: LifeManagementProjectRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.project.icon.systemImageName,
                accentHex: row.project.color.hexString
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.project.name)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(summarySubtitle)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var summarySubtitle: String {
        if row.taskCount == 0 {
            return String(localized: "No tasks")
        }
        let tasks = row.taskCount == 1 ? String(localized: "1 open task") : String(localized: "\(row.taskCount) open tasks")
        return "\(row.lifeArea?.name ?? String(localized: "No area")) · \(tasks)"
    }
}
