import SwiftUI

enum TaskerSettingsMetrics {
    static let screenHorizontal: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let sectionHeaderToCardGap: CGFloat = 12
    static let cardInnerPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 24
    static let navigationRowMinHeight: CGFloat = 88
    static let toggleRowMinHeight: CGFloat = 84
    static let chipMinHeight: CGFloat = 44
}

enum TaskerSettingsTone {
    case accent
    case neutral
    case success
    case warning
    case danger
}

enum TaskerSettingsRowType {
    case navigation
    case toggle
    case toggleSummary
}

struct TaskerSettingsStatusDescriptor: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    var tone: TaskerSettingsTone = .neutral
}

struct TaskerSettingsInlineBadge {
    let title: String
    var tone: TaskerSettingsTone = .neutral
}

struct TaskerSettingsDestinationDescriptor {
    let iconName: String
    let title: String
    let subtitle: String
    var rowType: TaskerSettingsRowType = .navigation
    var trailingStatus: String? = nil
    var summaryText: String? = nil
    var inlineBadge: TaskerSettingsInlineBadge? = nil
    var tone: TaskerSettingsTone = .accent
    var accessibilityIdentifier: String? = nil
}

struct TaskerSettingsCard<Content: View>: View {
    var active: Bool = false
    @ViewBuilder let content: Content

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var cardPadding: CGFloat {
        TaskerSettingsMetrics.cardInnerPadding
    }

    private var cornerRadius: CGFloat {
        TaskerSettingsMetrics.cardCornerRadius
    }

    private var surfaceColor: Color {
        Color(uiColor: TaskerThemeManager.shared.tokens(for: layoutClass).color.surfacePrimary)
    }

    private var borderColor: Color {
        let color = active
            ? TaskerThemeManager.shared.tokens(for: layoutClass).color.borderStrong
            : TaskerThemeManager.shared.tokens(for: layoutClass).color.borderDefault
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
            .taskerElevation(.e1, cornerRadius: cornerRadius, includesBorder: false)
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let subtitle: String
    var topPadding: CGFloat = TaskerSettingsMetrics.sectionSpacing
    var includeHorizontalPadding: Bool = true
    @ViewBuilder let content: Content

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
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
                .padding(.top, TaskerSettingsMetrics.sectionHeaderToCardGap)
        }
    }
}

struct TaskerSettingsHeroCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let statusItems: [TaskerSettingsStatusDescriptor]
    var accessibilityIdentifier: String? = nil

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var cornerRadius: CGFloat {
        TaskerSettingsMetrics.cardCornerRadius
    }

    private var maxHeroHeight: CGFloat {
        layoutClass.isPad ? 228 : 220
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(eyebrow)
                    .font(.tasker(.eyebrow))
                    .foregroundStyle(Color.white.opacity(0.78))

                Text(title)
                    .font(.tasker(.screenTitle))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(layoutClass.isPad ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if statusItems.isEmpty == false {
                HStack(spacing: 10) {
                    ForEach(Array(statusItems.prefix(3))) { item in
                        TaskerSettingsStatusChip(descriptor: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                    }
                }
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, TaskerSettingsMetrics.screenHorizontal)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 208, maxHeight: maxHeroHeight, alignment: .topLeading)
        .background(heroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .taskerElevation(.e2, cornerRadius: cornerRadius, includesBorder: false)
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

struct TaskerSettingsStatusChip: View {
    let descriptor: TaskerSettingsStatusDescriptor

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: descriptor.systemImage)
                .font(.tasker(.caption2))
                .foregroundStyle(iconColor)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.title)
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(descriptor.value)
                    .font(.tasker(.bodyStrong))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: TaskerSettingsMetrics.chipMinHeight, alignment: .leading)
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
            return Color.tasker(.statusSuccess)
        case .warning:
            return Color.tasker(.statusWarning)
        case .danger:
            return Color.tasker(.statusDanger)
        }
    }
}

struct TaskerSettingsFieldCard<Content: View>: View {
    let title: String
    let subtitle: String
    var footer: String? = nil
    var accessibilityIdentifier: String? = nil
    @ViewBuilder let content: Content

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
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
        TaskerSettingsCard(active: true) {
            VStack(alignment: .leading, spacing: TaskerSettingsMetrics.cardInnerPadding) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker(.textPrimary))

                    Text(subtitle)
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.tasker(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                content

                if let footer, footer.isEmpty == false {
                    Text(footer)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct TaskerSettingsToggleRow: View {
    let iconName: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var tone: TaskerSettingsTone = .accent
    var summaryText: String? = nil
    var accessibilityIdentifier: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: TaskerSwiftUITokens.spacing.s12) {
            SettingsRowIcon(iconName: iconName, tone: tone)

            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                Text(title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker(.textPrimary))

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: TaskerSwiftUITokens.spacing.s12)

            if let summaryText, summaryText.isEmpty == false {
                Text(summaryText)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.tasker(.accentPrimary))
                .accessibilityLabel(Text(title))
        }
        .frame(maxWidth: .infinity, minHeight: TaskerSettingsMetrics.toggleRowMinHeight, alignment: .leading)
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct TaskerSettingsToggleSummaryRow<ExpandedContent: View>: View {
    let descriptor: TaskerSettingsDestinationDescriptor
    @Binding var isOn: Bool
    @Binding var isExpanded: Bool
    var accessibilityIdentifier: String? = nil
    @ViewBuilder let expandedContent: ExpandedContent

    init(
        descriptor: TaskerSettingsDestinationDescriptor,
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
            HStack(alignment: .center, spacing: TaskerSwiftUITokens.spacing.s12) {
                Button {
                    withAnimation(TaskerAnimation.gentle) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: TaskerSwiftUITokens.spacing.s12) {
                        SettingsRowIcon(iconName: descriptor.iconName, tone: descriptor.tone)

                        VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                            Text(descriptor.title)
                                .font(.tasker(.bodyEmphasis))
                                .foregroundStyle(Color.tasker(.textPrimary))

                            Text(descriptor.subtitle)
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: TaskerSwiftUITokens.spacing.s12)

                        HStack(spacing: TaskerSwiftUITokens.spacing.s8) {
                            if let summaryText = descriptor.summaryText, summaryText.isEmpty == false {
                                Text(summaryText)
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker(.textSecondary))
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(1)
                            }

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.tasker(.caption2))
                                .foregroundStyle(Color.tasker(.textQuaternary))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color.tasker(.accentPrimary))
                    .accessibilityLabel(Text(descriptor.title))
            }
            .frame(maxWidth: .infinity, minHeight: TaskerSettingsMetrics.toggleRowMinHeight, alignment: .leading)

            if isExpanded {
                Divider()
                    .padding(.vertical, TaskerSwiftUITokens.spacing.s12)

                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(TaskerAnimation.gentle, value: isExpanded)
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
        VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s12) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker(.textTertiary))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerSwiftUITokens.spacing.s8) {
                    ForEach(options, id: \.value) { option in
                        TaskerChip(
                            title: option.label,
                            isSelected: option.value == selectedValue,
                            selectedStyle: .filled,
                            action: {
                                TaskerFeedback.selection()
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

struct TaskerSettingsInfoRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    var value: String? = nil
    var accessibilityIdentifier: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: TaskerSwiftUITokens.spacing.s12) {
            SettingsRowIcon(iconName: iconName, tone: .neutral)

            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                Text(title)
                    .font(.tasker(.bodyStrong))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text(subtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: TaskerSwiftUITokens.spacing.s12)

            if let value, value.isEmpty == false {
                Text(value)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct TaskerSettingsDangerZoneCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    var buttonRole: ButtonRole? = .destructive
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        TaskerSettingsCard {
            VStack(alignment: .leading, spacing: TaskerSettingsMetrics.cardInnerPadding) {
                HStack(alignment: .top, spacing: TaskerSwiftUITokens.spacing.s12) {
                    SettingsRowIcon(iconName: "exclamationmark.triangle.fill", tone: .danger)

                    VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                        Text(title)
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker(.textPrimary))

                        Text(subtitle)
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button(buttonTitle, role: buttonRole, action: action)
                    .font(.tasker(.buttonSmall))
                    .buttonStyle(.bordered)
                    .tint(Color.tasker(.statusDanger))
                    .applyOptionalAccessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }
}

struct SettingsRowIcon: View {
    let iconName: String
    let tone: TaskerSettingsTone

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(.tasker(.support))
                .foregroundStyle(foregroundColor)
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .accent:
            return Color.tasker(.accentPrimary)
        case .neutral:
            return Color.tasker(.textSecondary)
        case .success:
            return Color.tasker(.statusSuccess)
        case .warning:
            return Color.tasker(.statusWarning)
        case .danger:
            return Color.tasker(.statusDanger)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .accent:
            return Color.tasker(.accentWash)
        case .neutral:
            return Color.tasker(.surfaceSecondary)
        case .success:
            return Color.tasker(.statusSuccess).opacity(0.14)
        case .warning:
            return Color.tasker(.statusWarning).opacity(0.14)
        case .danger:
            return Color.tasker(.statusDanger).opacity(0.14)
        }
    }
}

struct SettingsNavigationRow: View {
    let descriptor: TaskerSettingsDestinationDescriptor
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button {
                    TaskerFeedback.light()
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
        HStack(alignment: .center, spacing: TaskerSwiftUITokens.spacing.s12) {
            SettingsRowIcon(iconName: descriptor.iconName, tone: descriptor.tone)

            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                Text(descriptor.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(.tasker(.textPrimary))

                Text(descriptor.subtitle)
                    .font(.tasker(.caption1))
                    .foregroundColor(.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                if let inlineBadge = descriptor.inlineBadge {
                    Text(inlineBadge.title)
                        .font(.tasker(.caption2))
                        .foregroundStyle(badgeForeground(for: inlineBadge.tone))
                        .padding(.horizontal, TaskerSwiftUITokens.spacing.s8)
                        .padding(.vertical, TaskerSwiftUITokens.spacing.s4)
                        .background(badgeBackground(for: inlineBadge.tone))
                        .clipShape(Capsule())
                }
            }

            Spacer(minLength: TaskerSwiftUITokens.spacing.s12)

            HStack(spacing: TaskerSwiftUITokens.spacing.s8) {
                if let trailingStatus = descriptor.trailingStatus, trailingStatus.isEmpty == false {
                    Text(trailingStatus)
                        .font(.tasker(.caption1))
                        .foregroundColor(.tasker(.textSecondary))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.tasker(.meta))
                    .foregroundColor(.tasker(.textQuaternary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: TaskerSettingsMetrics.navigationRowMinHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func badgeForeground(for tone: TaskerSettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.tasker(.accentPrimary)
        case .neutral:
            return Color.tasker(.textSecondary)
        case .success:
            return Color.tasker(.statusSuccess)
        case .warning:
            return Color.tasker(.statusWarning)
        case .danger:
            return Color.tasker(.statusDanger)
        }
    }

    private func badgeBackground(for tone: TaskerSettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.tasker(.accentWash)
        case .neutral:
            return Color.tasker(.surfaceSecondary)
        case .success:
            return Color.tasker(.statusSuccess).opacity(0.14)
        case .warning:
            return Color.tasker(.statusWarning).opacity(0.14)
        case .danger:
            return Color.tasker(.statusDanger).opacity(0.14)
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
