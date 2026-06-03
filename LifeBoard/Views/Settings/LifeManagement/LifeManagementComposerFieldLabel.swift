import SwiftUI
import UIKit

struct LifeManagementComposerFieldLabel: View {
    let title: String
    let detail: String

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

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
