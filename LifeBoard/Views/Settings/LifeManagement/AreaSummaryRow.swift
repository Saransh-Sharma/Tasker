import SwiftUI
import UIKit

struct AreaSummaryRow: View {
    let row: LifeManagementAreaRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.lifeArea.icon ?? "square.grid.2x2",
                accentHex: lifeManagementAreaAccentHex(row.lifeArea)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.lifeArea.name)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text("\(row.projectCount) projects · \(row.habitCount) habits")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
