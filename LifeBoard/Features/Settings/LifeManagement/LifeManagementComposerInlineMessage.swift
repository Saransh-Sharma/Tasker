import SwiftUI
import UIKit

struct LifeManagementComposerInlineMessage: View {
    let title: String
    let message: String

    @Environment(\.lifeboardTokens) private var tokens
    var spacing: LifeBoardSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.statusDanger)

            Text(message)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(spacing.s12)
        .lifeboardDenseSurface(
            cornerRadius: Theme.CornerRadius.md,
            fillColor: Color.lifeboard.statusDanger.opacity(0.08),
            strokeColor: Color.lifeboard.statusDanger.opacity(0.18)
        )
    }
}
