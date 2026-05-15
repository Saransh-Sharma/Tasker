import SwiftUI

struct LBDateHeroHeader: View {
    struct Model: Equatable {
        let date: Date
        let period: TimeOfDayHeaderAsset.Period
        let subtitle: String
        let heroTitleColor: Color
        let heroSubtitleColor: Color
        let chromeControlColor: Color
        let chromeGlassFill: Color
        let chromeGlassStroke: Color
        let navigatorColor: Color
        let navigatorTitle: String
        let navigatorGlassFill: Color
        let navigatorGlassStroke: Color
        let hasNotifications: Bool
        let hasActiveFilters: Bool
    }

    let model: Model
    let headerHeight: CGFloat
    let safeAreaTop: CGFloat
    let onMenu: () -> Void
    let onSearch: () -> Void
    let onDateTap: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            topChrome
                .padding(.top, topChromeTop)

            dateGroup
                .padding(.top, dateGroupTop)

            navigatorRow
                .padding(.top, navigatorTop)
        }
        .frame(height: headerHeight, alignment: .top)
    }

    private var topChrome: some View {
        HStack {
            topChromeButton(systemName: "line.3.horizontal", action: onMenu)
                .accessibilityLabel("Menu")
            Spacer()
            topChromeButton(systemName: "magnifyingglass", action: onSearch)
                .accessibilityLabel("Search")
                .accessibilityIdentifier("home.searchButton")
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
    }

    private var dateGroup: some View {
        Button(action: onDateTap) {
            VStack(spacing: 2) {
                Text(Self.dateTitle(model.date))
                    .font(LBTypographyTokens.dateHero)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .foregroundStyle(model.heroTitleColor)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)

                HStack(spacing: 6) {
                    Image(systemName: model.period.symbolName)
                        .foregroundStyle(LBColorTokens.sunriseGold)
                    Text(model.subtitle)
                        .font(LBTypographyTokens.heroOverline)
                        .tracking(4)
                        .foregroundStyle(model.heroSubtitleColor)
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(model.heroSubtitleColor)
                }
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, LBSpacingTokens.screenMargin * 2)
    }

    private var navigatorRow: some View {
        Button(action: onDateTap) {
            HStack(spacing: LBSpacingTokens.sm) {
                Image(systemName: "calendar")
                Text(model.navigatorTitle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
            }
            .font(LBTypographyTokens.chip)
            .foregroundStyle(model.navigatorColor)
            .frame(minHeight: 44)
            .padding(.horizontal, LBSpacingTokens.md)
            .background {
                clearCapsuleSurface(fill: model.navigatorGlassFill, stroke: model.navigatorGlassStroke)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose date")
        .accessibilityValue(model.navigatorTitle)
        .accessibilityIdentifier("home.sunrise.date.selector")
        .padding(.horizontal, LBSpacingTokens.screenMargin)
        .frame(maxWidth: .infinity)
    }

    private var dateGroupTop: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return safeHeaderTop + 13
        }
        return safeHeaderTop + 3
    }

    private var navigatorTop: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return safeHeaderTop + 159 + LBSpacingTokens.xs
        }
        return safeHeaderTop + 117 + LBSpacingTokens.xs
    }

    private var topChromeTop: CGFloat {
        safeHeaderTop + 8
    }

    private var safeHeaderTop: CGFloat {
        max(safeAreaTop, 54)
    }

    private func topChromeButton(systemName: String, showsDot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(model.chromeControlColor)
                    .frame(width: 44, height: 44)
                    .background {
                        clearCircleSurface(fill: model.chromeGlassFill, stroke: model.chromeGlassStroke)
                    }
                if showsDot {
                    Circle()
                        .fill(LBColorTokens.sunriseGold)
                        .frame(width: 11, height: 11)
                        .offset(x: -5, y: 5)
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func clearCircleSurface(fill: Color, stroke: Color) -> some View {
        let shape = Circle()
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.clear, in: shape)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(LBColorTokens.glassDimmingOverlay) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(LBColorTokens.glassDimmingOverlay.opacity(0.8)) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        }
    }

    @ViewBuilder
    private func clearCapsuleSurface(fill: Color, stroke: Color) -> some View {
        let shape = Capsule()
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.clear, in: shape)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(LBColorTokens.glassDimmingOverlay) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(LBColorTokens.glassDimmingOverlay.opacity(0.8)) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        }
    }

    static func dateTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day())
    }

    static func navigatorTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().weekday(.wide))
    }
}
