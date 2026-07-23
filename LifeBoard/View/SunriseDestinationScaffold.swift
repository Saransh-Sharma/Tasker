import SwiftUI

struct SunriseDestinationScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    var headerSymbolName: String? = nil
    var leadingSystemImage: String = "line.3.horizontal"
    var leadingAccessibilityLabel: String = "Back to tasks"
    var leadingAccessibilityIdentifier: String? = nil
    let leadingAction: () -> Void
    var trailingSystemImage: String? = nil
    var trailingAccessibilityLabel: String? = nil
    var trailingAccessibilityIdentifier: String? = nil
    var trailingAction: (() -> Void)? = nil
    var metricPillTitle: String? = nil
    var bottomInset: CGFloat = 0
    var topContentInset: CGFloat = 0
    @ViewBuilder let content: Content

    var body: some View {
        SecondaryScreenShell(
            title: title,
            subtitle: subtitle,
            leadingSystemImage: leadingSystemImage,
            leadingAccessibilityLabel: leadingAccessibilityLabel,
            leadingAccessibilityIdentifier: leadingAccessibilityIdentifier,
            leadingAction: leadingAction,
            trailingSystemImage: trailingSystemImage,
            trailingAccessibilityLabel: trailingAccessibilityLabel,
            trailingAccessibilityIdentifier: trailingAccessibilityIdentifier,
            trailingAction: trailingAction,
            metricPillTitle: metricPillTitle,
            bottomInset: bottomInset,
            topContentInset: topContentInset
        ) {
            content
        }
    }
}

struct SecondaryScreenShell<Content: View>: View {
    let title: String
    let subtitle: String
    var leadingSystemImage: String = "line.3.horizontal"
    var leadingAccessibilityLabel: String = "Back to tasks"
    var leadingAccessibilityIdentifier: String? = nil
    let leadingAction: () -> Void
    var trailingSystemImage: String? = nil
    var trailingAccessibilityLabel: String? = nil
    var trailingAccessibilityIdentifier: String? = nil
    var trailingAction: (() -> Void)? = nil
    var metricPillTitle: String? = nil
    var bottomInset: CGFloat = 0
    var topContentInset: CGFloat = 0
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LifeBoardScreenScaffold(
            mode: .detail,
            placement: .focusedPresentation,
            bottomClearance: bottomInset,
            readableWidth: 860
        ) {
            VStack(spacing: LBSpacingTokens.md) {
                SecondaryScreenHeader(
                    title: title,
                    subtitle: subtitle,
                    leadingSystemImage: leadingSystemImage,
                    leadingAccessibilityLabel: leadingAccessibilityLabel,
                    leadingAccessibilityIdentifier: leadingAccessibilityIdentifier,
                    leadingAction: leadingAction,
                    trailingSystemImage: trailingSystemImage,
                    trailingAccessibilityLabel: trailingAccessibilityLabel,
                    trailingAccessibilityIdentifier: trailingAccessibilityIdentifier,
                    trailingAction: trailingAction,
                    metricPillTitle: metricPillTitle
                )

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, LBSpacingTokens.screenMargin)
            .padding(.top, topPadding + max(0, topContentInset))
        }
    }

    private var topPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.lg : LBSpacingTokens.sm
    }

}

struct SecondaryScreenHeader: View {
    let title: String
    let subtitle: String
    var leadingSystemImage: String = "line.3.horizontal"
    var leadingAccessibilityLabel: String = "Back"
    var leadingAccessibilityIdentifier: String? = nil
    let leadingAction: () -> Void
    var trailingSystemImage: String? = nil
    var trailingAccessibilityLabel: String? = nil
    var trailingAccessibilityIdentifier: String? = nil
    var trailingAction: (() -> Void)? = nil
    var metricPillTitle: String? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                SecondaryHeaderButton(
                    systemName: leadingSystemImage,
                    accessibilityLabel: leadingAccessibilityLabel,
                    accessibilityIdentifier: leadingAccessibilityIdentifier,
                    action: leadingAction
                )

                Spacer(minLength: LBSpacingTokens.md)

                if let trailingSystemImage, let trailingAction {
                    SecondaryHeaderButton(
                        systemName: trailingSystemImage,
                        accessibilityLabel: trailingAccessibilityLabel ?? "Action",
                        accessibilityIdentifier: trailingAccessibilityIdentifier,
                        action: trailingAction
                    )
                } else {
                    Color.clear
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                }
            }

            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.xs : 3) {
                Text(title)
                    .font(.lifeboard(.screenTitle))
                    .foregroundStyle(Color.lifeboard(.primary, on: .canvas))
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.secondary, on: .canvas))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let metricPillTitle {
                    SecondaryMetricPill(title: metricPillTitle)
                }
            }
            .padding(.horizontal, 62)
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 118 : 96, alignment: .top)
        .accessibilityElement(children: .contain)
    }
}

struct SecondaryHeaderButton: View {
    let systemName: String
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.lifeboard(.buttonSmall))
                .foregroundStyle(Color.lifeboard(.primary, on: .toolbar))
                .frame(width: 52, height: 52)
                .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                .overlay(Circle().stroke(Color.lifeboard(.borderDefault), lineWidth: 1))
                .lifeboardElevation(.e1, cornerRadius: 26, includesBorder: false)
        }
        .buttonStyle(.plain)
        .lifeboardPressFeedback()
        .accessibilityLabel(accessibilityLabel)
        .lifeboardAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct SecondaryMetricPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(Color.lifeboard(.link, on: .raised))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, LBSpacingTokens.sm)
            .frame(minHeight: 30)
            .background(Color.lifeboard(.surfaceSecondary), in: Capsule())
            .overlay(Capsule().stroke(Color.lifeboard(.borderDefault), lineWidth: 1))
            .accessibilityLabel(title)
    }
}

struct SecondaryGlassCardSurface<Content: View>: View {
    var role: LBRole = .neutral
    var cornerRadius: CGFloat = 24
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(Color.lifeboard(.surfacePrimary))
                    .overlay(shape.stroke(Color.lifeboard(.borderDefault), lineWidth: 1))
            }
            .lifeboardElevation(.e2, cornerRadius: cornerRadius, includesBorder: false)
    }
}

struct SecondaryChipRow: View {
    let chips: [LifeBoardSearchFilterChipDescriptor]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LBSpacingTokens.sm) {
                ForEach(chips) { chip in
                    LifeBoardFilterChip(
                        title: chip.title,
                        systemImage: chip.systemImage,
                        count: chip.count,
                        isSelected: chip.isSelected,
                        accentColor: chip.tintColor,
                        accessibilityIdentifier: chip.accessibilityIdentifier,
                        action: chip.action
                    )
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }
}

struct SecondaryStateRenderer: View {
    let asset: SunriseDecorAsset
    let title: String
    let message: String
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        SecondaryGlassCardSurface(role: .assistant, cornerRadius: 28) {
            VStack(spacing: LBSpacingTokens.md) {
                SunriseDecorImage(asset: asset, size: 116, opacity: 0.86)
                    .accessibilityHidden(true)

                VStack(spacing: LBSpacingTokens.xs) {
                    Text(title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: LBSpacingTokens.sm) {
                    if let primaryTitle, let primaryAction {
                        Button(primaryTitle, systemImage: "arrow.right", action: primaryAction)
                            .font(.lifeboard(.callout).weight(.semibold))
                            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                            .padding(.horizontal, LBSpacingTokens.md)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(LBColorTokens.violetFill))
                    }

                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, systemImage: "sparkles", action: secondaryAction)
                            .font(.lifeboard(.callout).weight(.semibold))
                            .foregroundStyle(LBColorTokens.violetDeep)
                            .padding(.horizontal, LBSpacingTokens.md)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(LBColorTokens.glassStrong))
                    }
                }
            }
            .padding(LBSpacingTokens.lg)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}
