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

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .top) {
            background

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
            .padding(.bottom, bottomInset)
            .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 860 : .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LBColorTokens.canvas)
    }

    private var topPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.lg : LBSpacingTokens.sm
    }

    private var background: some View {
        ZStack {
            if reduceTransparency {
                LBColorTokens.canvas
            } else {
                LinearGradient(
                    colors: [
                        LBColorTokens.canvas,
                        LBColorTokens.warmCanvas.opacity(0.82),
                        LBColorTokens.coolCanvas.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            SunriseDecorImage(asset: .subtleLeaf, size: 150, opacity: 0.16, rotation: .degrees(18))
                .offset(x: 172, y: -32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            SunriseDecorImage(asset: .subtleLeaf, size: 170, opacity: 0.10, rotation: .degrees(-24), mirrorX: true)
                .offset(x: -148, y: 440)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            SunriseDecorImage(asset: .cloud, size: 170, opacity: 0.10)
                .offset(x: 130, y: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea()
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
                    .foregroundStyle(LBColorTokens.navy)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LBColorTokens.navySoft)
                .frame(width: 52, height: 52)
                .background {
                    Circle()
                        .fill(reduceTransparency ? LBColorTokens.glassStrong : LBColorTokens.glassStrong.opacity(0.84))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(LBColorTokens.glassBorder, lineWidth: 1))
                        .shadow(color: LBColorTokens.elevationShadow, radius: 12, x: 0, y: 7)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .lifeboardAccessibilityIdentifier(accessibilityIdentifier)
    }
}

struct SecondaryMetricPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(LBColorTokens.violetDeep)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, LBSpacingTokens.sm)
            .frame(minHeight: 30)
            .background(LBColorTokens.glassStrong.opacity(0.88), in: Capsule())
            .overlay(Capsule().stroke(LBColorTokens.glassBorder, lineWidth: 1))
            .accessibilityLabel(title)
    }
}

struct SecondaryGlassCardSurface<Content: View>: View {
    var role: LBRole = .neutral
    var cornerRadius: CGFloat = 24
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var style: LBRoleStyle { LBColorTokens.role(role) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: reduceTransparency
                                ? [LBColorTokens.glassStrong, LBColorTokens.glassStrong]
                                : [style.softSurface.opacity(0.90), LBColorTokens.glassStrong.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.stroke(style.border.opacity(reduceTransparency ? 0.90 : 0.58), lineWidth: 1))
                    .shadow(color: LBColorTokens.elevationShadow, radius: 16, x: 0, y: 9)
            }
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
                            .foregroundStyle(Color.white)
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
