import SwiftUI
import UIKit

struct AreaListRow: View {
    let row: LifeManagementAreaRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.lifeArea.icon ?? "square.grid.2x2",
                accentHex: lifeManagementAreaAccentHex(row.lifeArea)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.lifeArea.name)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    if row.isGeneral {
                        InlineToneBadge(title: "Pinned")
                    }
                }

                Text("\(row.projectCount) projects · \(row.habitCount) habits")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.lifeboard(.textTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
