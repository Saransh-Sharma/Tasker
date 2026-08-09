import SwiftUI
import UIKit

struct LifeManagementComposerFieldLabel: View {
    let title: String
    let detail: String

    @Environment(\.lifeboardTokens) private var tokens
    var spacing: LifeBoardSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)

            Text(detail)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
    }
}
