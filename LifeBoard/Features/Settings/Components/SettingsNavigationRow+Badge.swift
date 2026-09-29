import SwiftUI

extension SettingsNavigationRow {
    func badgeForeground(for tone: SettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.lifeboard(.accentPrimary)
        case .neutral:
            return Color.lifeboard(.textSecondary)
        case .success:
            return Color.lifeboard(.statusSuccess)
        case .warning:
            return Color.lifeboard(.statusWarning)
        case .danger:
            return Color.lifeboard(.statusDanger)
        }
    }

    func badgeBackground(for tone: SettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.lifeboard(.accentWash)
        case .neutral:
            return Color.lifeboard(.surfaceSecondary)
        case .success:
            return Color.lifeboard(.statusSuccess).opacity(0.14)
        case .warning:
            return Color.lifeboard(.statusWarning).opacity(0.14)
        case .danger:
            return Color.lifeboard(.statusDanger).opacity(0.14)
        }
    }
}

struct SettingsHeroCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let statusItems: [SettingsStatusDescriptor]
    var accessibilityIdentifier: String? = nil

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    private var cornerRadius: CGFloat {
        SettingsMetrics.cardCornerRadius
    }

    private var maxHeroHeight: CGFloat? {
        dynamicTypeSize.isAccessibilitySize ? nil : (layoutClass.isPad ? 228 : 220)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(eyebrow)
                    .lifeboardFont(.eyebrow)
                    .foregroundStyle(heroInk)

                Text(title)
                    .lifeboardFont(.screenTitle)
                    .foregroundStyle(heroInk)
                    .lineLimit(2)

                if subtitle.isEmpty == false {
                    Text(subtitle)
                        .lifeboardFont(.callout)
                        .foregroundStyle(heroInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : (layoutClass.isPad ? 2 : 3))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if statusItems.isEmpty == false {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        statusChips
                    }
                } else {
                    HStack(spacing: 12) {
                        statusChips
                    }
                }
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, SettingsMetrics.screenHorizontal)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 208, maxHeight: maxHeroHeight, alignment: .topLeading)
        .background(heroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(heroInk.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .lifeboardElevation(.e2, cornerRadius: cornerRadius, includesBorder: false)
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(SemanticColorTokens.foundationSettingsHeroStart),
                    Color(SemanticColorTokens.foundationSettingsHeroMiddle),
                    Color(SemanticColorTokens.foundationSettingsHeroEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Color(SemanticColorTokens.foundationOnSettingsHero).opacity(0.025)
        }
    }

    private var heroInk: Color {
        Color(SemanticColorTokens.foundationOnSettingsHero)
    }

    @ViewBuilder
    private var statusChips: some View {
        ForEach(Array(statusItems.prefix(3))) { item in
            SettingsStatusChip(descriptor: item)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
    }
}

struct SettingsStatusChip: View {
    let descriptor: SettingsStatusDescriptor

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: descriptor.systemImage)
                .font(.lifeboard(.caption2))
                .foregroundStyle(iconColor)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.title)
                    .lifeboardFont(.caption2)
                    .foregroundStyle(heroInk)
                    .lineLimit(2)

                Text(descriptor.value)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(heroInk)
                    .lineLimit(2)
            }
            // The title owns the row's width; trailing values truncate first.
            // Without this a summary and chevron crushed "Due Soon Nudges" to
            // three letters a line.
            .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minHeight: SettingsMetrics.chipMinHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.lifeboard(.surfacePrimary).opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(heroInk.opacity(0.16), lineWidth: 1)
        )
    }

    private var iconColor: Color {
        heroInk
    }

    private var heroInk: Color {
        Color(SemanticColorTokens.foundationOnSettingsHero)
    }
}
