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
    var bottomInset: CGFloat = 0
    @ViewBuilder let content: Content

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            background

            VStack(spacing: LBSpacingTokens.lg) {
                header

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, LBSpacingTokens.screenMargin)
            .padding(.top, topPadding)
            .padding(.bottom, bottomInset)
            .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 860 : .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LBColorTokens.warmCanvas)
    }

    private var topPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.lg : LBSpacingTokens.md
    }

    private var header: some View {
        ZStack(alignment: .top) {
            HStack {
                headerButton(
                    systemName: leadingSystemImage,
                    accessibilityLabel: leadingAccessibilityLabel,
                    accessibilityIdentifier: leadingAccessibilityIdentifier,
                    action: leadingAction
                )

                Spacer(minLength: LBSpacingTokens.md)

                if let trailingSystemImage, let trailingAction {
                    headerButton(
                        systemName: trailingSystemImage,
                        accessibilityLabel: trailingAccessibilityLabel ?? "Action",
                        accessibilityIdentifier: trailingAccessibilityIdentifier,
                        action: trailingAction
                    )
                } else {
                    Color.clear
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                }
            }

            VStack(spacing: LBSpacingTokens.xs) {
                if let headerSymbolName {
                    Image(systemName: headerSymbolName)
                        .font(.system(size: 25, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(LBColorTokens.violetDeep)
                        .frame(height: 26)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.lifeboard(.screenTitle))
                    .foregroundStyle(LBColorTokens.navy)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 58)
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: headerSymbolName == nil ? 92 : 116, alignment: .top)
    }

    private func headerButton(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LBColorTokens.navySoft)
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(LBColorTokens.glassStrong.opacity(0.82))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(LBColorTokens.glassBorder, lineWidth: 1))
                        .shadow(color: LBColorTokens.elevationShadow, radius: 12, x: 0, y: 7)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .lifeboardAccessibilityIdentifier(accessibilityIdentifier)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    LBColorTokens.warmCanvas,
                    LBColorTokens.canvas,
                    LBColorTokens.coolCanvas.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

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
