import SwiftUI
import UIKit

struct LifeManagementComposerSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let iconSystemName: String
    let content: Content

    @Environment(\.lifeboardTokens) private var tokens

    var spacing: SemanticSpacingTokens { tokens.spacing }

    init(
        title: String,
        subtitle: String,
        iconSystemName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s8) {
                Image(systemName: iconSystemName)
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)

                    Text(subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.s16)
        .lifeboardDenseSurface(cornerRadius: Theme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }
}
