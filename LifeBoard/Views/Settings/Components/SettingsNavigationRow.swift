import SwiftUI

enum LifeBoardSettingsMetrics {
    static let screenHorizontal: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let sectionHeaderToCardGap: CGFloat = 12
    static let cardInnerPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 24
    static let navigationRowMinHeight: CGFloat = 88
    static let toggleRowMinHeight: CGFloat = 84
    static let chipMinHeight: CGFloat = 44
}

enum LifeBoardSettingsTone {
    case accent
    case neutral
    case success
    case warning
    case danger
}

enum LifeBoardSettingsRowType {
    case navigation
    case toggle
    case toggleSummary
}

struct LifeBoardSettingsStatusDescriptor: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    var tone: LifeBoardSettingsTone = .neutral
}

struct LifeBoardSettingsInlineBadge {
    let title: String
    var tone: LifeBoardSettingsTone = .neutral
}

struct LifeBoardSettingsDestinationDescriptor {
    let iconName: String
    let title: String
    let subtitle: String
    var rowType: LifeBoardSettingsRowType = .navigation
    var trailingStatus: String? = nil
    var summaryText: String? = nil
    var inlineBadge: LifeBoardSettingsInlineBadge? = nil
    var tone: LifeBoardSettingsTone = .accent
    var accessibilityIdentifier: String? = nil
}

struct LifeBoardSettingsCard<Content: View>: View {
    var active: Bool = false
    @ViewBuilder let content: Content

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var cardPadding: CGFloat {
        LifeBoardSettingsMetrics.cardInnerPadding
    }

    private var cornerRadius: CGFloat {
        LifeBoardSettingsMetrics.cardCornerRadius
    }

    private var surfaceColor: Color {
        Color(uiColor: LifeBoardThemeManager.shared.tokens(for: layoutClass).color.surfacePrimary)
    }

    private var borderColor: Color {
        let color = active
            ? LifeBoardThemeManager.shared.tokens(for: layoutClass).color.borderStrong
            : LifeBoardThemeManager.shared.tokens(for: layoutClass).color.borderDefault
        return Color(uiColor: color).opacity(0.95)
    }

    var body: some View {
        content
            .padding(cardPadding)
            .background(surfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .lifeboardElevation(.e1, cornerRadius: cornerRadius, includesBorder: false)
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let subtitle: String
    var topPadding: CGFloat = LifeBoardSettingsMetrics.sectionSpacing
    var includeHorizontalPadding: Bool = true
    @ViewBuilder let content: Content

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(
                title: title,
                subtitle: subtitle,
                includeHorizontalPadding: includeHorizontalPadding
            )
            .padding(.top, topPadding)

            content
                .padding(.horizontal, includeHorizontalPadding ? spacing.screenHorizontal : 0)
                .padding(.top, LifeBoardSettingsMetrics.sectionHeaderToCardGap)
        }
    }
}

struct LifeBoardSettingsHeroCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let statusItems: [LifeBoardSettingsStatusDescriptor]
    var accessibilityIdentifier: String? = nil

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var cornerRadius: CGFloat {
        LifeBoardSettingsMetrics.cardCornerRadius
    }

    private var maxHeroHeight: CGFloat {
        layoutClass.isPad ? 228 : 220
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(eyebrow)
                    .font(.lifeboard(.eyebrow))
                    .foregroundStyle(Color.white.opacity(0.78))

                Text(title)
                    .font(.lifeboard(.screenTitle))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(layoutClass.isPad ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if statusItems.isEmpty == false {
                HStack(spacing: 10) {
                    ForEach(Array(statusItems.prefix(3))) { item in
                        LifeBoardSettingsStatusChip(descriptor: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                    }
                }
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, LifeBoardSettingsMetrics.screenHorizontal)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 208, maxHeight: maxHeroHeight, alignment: .topLeading)
        .background(heroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
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
                    Color(red: 0.90, green: 0.60, blue: 0.48),
                    Color(red: 0.82, green: 0.54, blue: 0.62),
                    Color(red: 0.63, green: 0.42, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.03),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct LifeBoardSettingsStatusChip: View {
    let descriptor: LifeBoardSettingsStatusDescriptor

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: descriptor.systemImage)
                .font(.lifeboard(.caption2))
                .foregroundStyle(iconColor)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.title)
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(descriptor.value)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: LifeBoardSettingsMetrics.chipMinHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var iconColor: Color {
        switch descriptor.tone {
        case .accent:
            return Color.white
        case .neutral:
            return Color.white.opacity(0.88)
        case .success:
            return Color.lifeboard(.statusSuccess)
        case .warning:
            return Color.lifeboard(.statusWarning)
        case .danger:
            return Color.lifeboard(.statusDanger)
        }
    }
}

struct LifeBoardSettingsFieldCard<Content: View>: View {
    let title: String
    let subtitle: String
    var footer: String? = nil
    var accessibilityIdentifier: String? = nil
    @ViewBuilder let content: Content

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    init(
        title: String,
        subtitle: String,
        footer: String? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.footer = footer
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content()
    }

    var body: some View {
        LifeBoardSettingsCard(active: true) {
            VStack(alignment: .leading, spacing: LifeBoardSettingsMetrics.cardInnerPadding) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))

                    Text(subtitle)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                content

                if let footer, footer.isEmpty == false {
                    Text(footer)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct LifeBoardSettingsToggleRow: View {
    let iconName: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var tone: LifeBoardSettingsTone = .accent
    var summaryText: String? = nil
    var accessibilityIdentifier: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: LifeBoardSwiftUITokens.spacing.s12) {
            SettingsRowIcon(iconName: iconName, tone: tone)

            VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                Text(title)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.lifeboard(.textPrimary))

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: LifeBoardSwiftUITokens.spacing.s12)

            if let summaryText, summaryText.isEmpty == false {
                Text(summaryText)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.lifeboard(.accentPrimary))
                .accessibilityLabel(Text(title))
        }
        .frame(maxWidth: .infinity, minHeight: LifeBoardSettingsMetrics.toggleRowMinHeight, alignment: .leading)
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct LifeBoardSettingsToggleSummaryRow<ExpandedContent: View>: View {
    let descriptor: LifeBoardSettingsDestinationDescriptor
    @Binding var isOn: Bool
    @Binding var isExpanded: Bool
    var accessibilityIdentifier: String? = nil
    @ViewBuilder let expandedContent: ExpandedContent

    init(
        descriptor: LifeBoardSettingsDestinationDescriptor,
        isOn: Binding<Bool>,
        isExpanded: Binding<Bool>,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder expandedContent: () -> ExpandedContent
    ) {
        self.descriptor = descriptor
        self._isOn = isOn
        self._isExpanded = isExpanded
        self.accessibilityIdentifier = accessibilityIdentifier
        self.expandedContent = expandedContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: LifeBoardSwiftUITokens.spacing.s12) {
                Button {
                    withAnimation(LifeBoardAnimation.gentle) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: LifeBoardSwiftUITokens.spacing.s12) {
                        SettingsRowIcon(iconName: descriptor.iconName, tone: descriptor.tone)

                        VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                            Text(descriptor.title)
                                .font(.lifeboard(.bodyEmphasis))
                                .foregroundStyle(Color.lifeboard(.textPrimary))

                            Text(descriptor.subtitle)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: LifeBoardSwiftUITokens.spacing.s12)

                        HStack(spacing: LifeBoardSwiftUITokens.spacing.s8) {
                            if let summaryText = descriptor.summaryText, summaryText.isEmpty == false {
                                Text(summaryText)
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard(.textSecondary))
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(1)
                            }

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.lifeboard(.caption2))
                                .foregroundStyle(Color.lifeboard(.textQuaternary))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color.lifeboard(.accentPrimary))
                    .accessibilityLabel(Text(descriptor.title))
            }
            .frame(maxWidth: .infinity, minHeight: LifeBoardSettingsMetrics.toggleRowMinHeight, alignment: .leading)

            if isExpanded {
                Divider()
                    .padding(.vertical, LifeBoardSwiftUITokens.spacing.s12)

                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(LifeBoardAnimation.gentle, value: isExpanded)
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier ?? descriptor.accessibilityIdentifier)
    }
}

struct SettingsChipSelector<Option: Hashable>: View {
    let title: String
    let options: [(value: Option, label: String)]
    let selectedValue: Option
    let onSelect: (Option) -> Void
    var accessibilityIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s12) {
            Text(title)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard(.textTertiary))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LifeBoardSwiftUITokens.spacing.s8) {
                    ForEach(options, id: \.value) { option in
                        LifeBoardChip(
                            title: option.label,
                            isSelected: option.value == selectedValue,
                            selectedStyle: .filled,
                            action: {
                                LifeBoardFeedback.selection()
                                onSelect(option.value)
                            }
                        )
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct LifeBoardSettingsInfoRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    var value: String? = nil
    var accessibilityIdentifier: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: LifeBoardSwiftUITokens.spacing.s12) {
            SettingsRowIcon(iconName: iconName, tone: .neutral)

            VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                Text(title)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(subtitle)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LifeBoardSwiftUITokens.spacing.s12)

            if let value, value.isEmpty == false {
                Text(value)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct LifeBoardSettingsDangerZoneCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    var buttonRole: ButtonRole? = .destructive
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        LifeBoardSettingsCard {
            VStack(alignment: .leading, spacing: LifeBoardSettingsMetrics.cardInnerPadding) {
                HStack(alignment: .top, spacing: LifeBoardSwiftUITokens.spacing.s12) {
                    SettingsRowIcon(iconName: "exclamationmark.triangle.fill", tone: .danger)

                    VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                        Text(title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard(.textPrimary))

                        Text(subtitle)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button(buttonTitle, role: buttonRole, action: action)
                    .font(.lifeboard(.buttonSmall))
                    .buttonStyle(.bordered)
                    .tint(Color.lifeboard(.statusDanger))
                    .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }
}

struct SettingsRowIcon: View {
    let iconName: String
    let tone: LifeBoardSettingsTone

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(.lifeboard(.support))
                .foregroundStyle(foregroundColor)
        }
    }

    private var foregroundColor: Color {
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

    private var backgroundColor: Color {
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

struct SettingsNavigationRow: View {
    let descriptor: LifeBoardSettingsDestinationDescriptor
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button {
                    LifeBoardFeedback.light()
                    action()
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .applyOptionalAccessibilityIdentifier(descriptor.accessibilityIdentifier)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: LifeBoardSwiftUITokens.spacing.s12) {
            SettingsRowIcon(iconName: descriptor.iconName, tone: descriptor.tone)

            VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                Text(descriptor.title)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundColor(.lifeboard(.textPrimary))

                Text(descriptor.subtitle)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                if let inlineBadge = descriptor.inlineBadge {
                    Text(inlineBadge.title)
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(badgeForeground(for: inlineBadge.tone))
                        .padding(.horizontal, LifeBoardSwiftUITokens.spacing.s8)
                        .padding(.vertical, LifeBoardSwiftUITokens.spacing.s4)
                        .background(badgeBackground(for: inlineBadge.tone))
                        .clipShape(Capsule())
                }
            }

            Spacer(minLength: LifeBoardSwiftUITokens.spacing.s12)

            HStack(spacing: LifeBoardSwiftUITokens.spacing.s8) {
                if let trailingStatus = descriptor.trailingStatus, trailingStatus.isEmpty == false {
                    Text(trailingStatus)
                        .font(.lifeboard(.caption1))
                        .foregroundColor(.lifeboard(.textSecondary))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.lifeboard(.meta))
                    .foregroundColor(.lifeboard(.textQuaternary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: LifeBoardSettingsMetrics.navigationRowMinHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func badgeForeground(for tone: LifeBoardSettingsTone) -> Color {
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

    private func badgeBackground(for tone: LifeBoardSettingsTone) -> Color {
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

extension View {
    @ViewBuilder
    func applyOptionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier, identifier.isEmpty == false {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
