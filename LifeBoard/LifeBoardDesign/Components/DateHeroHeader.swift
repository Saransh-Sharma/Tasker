import SwiftUI

enum DateHeroNavigationMode: Equatable {
    case dateSelector(title: String)
    case backToToday

    var accessibilityIdentifier: String {
        switch self {
        case .dateSelector: return "home.sunrise.date.selector"
        case .backToToday: return "home.sunrise.backToToday"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .dateSelector: return "Choose date"
        case .backToToday: return "Back to Today"
        }
    }

    static func resolve(isOnNonTodayLens: Bool, navigatorTitle: String) -> Self {
        isOnNonTodayLens ? .backToToday : .dateSelector(title: navigatorTitle)
    }
}

struct DateHeroHeader: View {
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
        let isOnNonTodayLens: Bool
        let backToTodayColor: Color
        let hasNotifications: Bool
        let hasActiveFilters: Bool
    }

    let model: Model
    let headerHeight: CGFloat
    let safeAreaTop: CGFloat
    let onMenu: () -> Void
    let onSearch: () -> Void
    let onDateTap: () -> Void
    let onBackToToday: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimizedRendering

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
        .padding(.horizontal, ClayLayoutMetrics.screenMargin)
    }

    private var dateGroup: some View {
        return Button(action: onDateTap) {
            VStack(spacing: 2) {
                Text(Self.dateTitle(model.date))
                    .font(ClayTypography.dateHero)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .foregroundStyle(model.heroTitleColor)
                    .shadow(color: ClayColorTokens.elevationShadow.opacity(1.2), radius: 6, y: 2)

                HStack(spacing: 6) {
                    Image(systemName: model.period.symbolName)
                        .foregroundStyle(ClayColorTokens.sunriseGold)
                    Text(model.subtitle)
                        .font(ClayTypography.heroOverline)
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
        .padding(.horizontal, ClayLayoutMetrics.screenMargin * 2)
    }

    private var navigatorRow: some View {
        Group {
            if model.isOnNonTodayLens {
                backToTodayButton
            } else {
                dateNavigatorButton
            }
        }
        .id(model.isOnNonTodayLens)
        .transition(navigatorTransition)
        .animation(navigatorAnimation, value: model.isOnNonTodayLens)
        .padding(.horizontal, ClayLayoutMetrics.screenMargin)
        .frame(maxWidth: .infinity)
    }

    private var dateNavigatorButton: some View {
        let mode = DateHeroNavigationMode.resolve(
            isOnNonTodayLens: model.isOnNonTodayLens,
            navigatorTitle: model.navigatorTitle
        )
        return Button(action: onDateTap) {
            navigatorLabel(
                leadingSystemName: "calendar",
                title: model.navigatorTitle,
                trailingSystemName: "chevron.down",
                fill: model.navigatorGlassFill,
                stroke: model.navigatorGlassStroke
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityValue(model.navigatorTitle)
        .accessibilityIdentifier(mode.accessibilityIdentifier)
    }

    private var backToTodayButton: some View {
        let mode = DateHeroNavigationMode.resolve(
            isOnNonTodayLens: model.isOnNonTodayLens,
            navigatorTitle: model.navigatorTitle
        )
        return Button(action: onBackToToday) {
            navigatorLabel(
                leadingSystemName: "arrow.uturn.backward",
                title: "Today",
                trailingSystemName: nil,
                fill: model.backToTodayColor.opacity(0.16),
                stroke: model.backToTodayColor.opacity(0.42)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityIdentifier(mode.accessibilityIdentifier)
    }

    private func navigatorLabel(
        leadingSystemName: String,
        title: String,
        trailingSystemName: String?,
        fill: Color,
        stroke: Color
    ) -> some View {
        HStack(spacing: ClayLayoutMetrics.sm) {
            Image(systemName: leadingSystemName)
            Text(title)
            if let trailingSystemName {
                Image(systemName: trailingSystemName)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .font(ClayTypography.chip)
        .foregroundStyle(model.navigatorColor)
        .frame(minHeight: 44)
        .padding(.horizontal, ClayLayoutMetrics.md)
        .background {
            clearCapsuleSurface(fill: fill, stroke: stroke)
        }
    }

    private var navigatorTransition: AnyTransition {
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
            return .identity
        }
        return .opacity.combined(with: .scale(scale: 0.98))
    }

    private var navigatorAnimation: Animation? {
        LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.stateChange
    }

    private var dateGroupTop: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return safeHeaderTop + 13
        }
        return safeHeaderTop + 3
    }

    private var navigatorTop: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return safeHeaderTop + 159 + ClayLayoutMetrics.xs
        }
        return safeHeaderTop + 117 + ClayLayoutMetrics.xs
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
                        .fill(ClayColorTokens.sunriseGold)
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
        if scrollOptimizedRendering {
            shape
                .fill(fill.opacity(0.94))
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        } else {
            // The `#available(iOS 26.0, *)` branch and its `.ultraThinMaterial`
            // fallback are gone: the deployment target *is* 26.0, so the
            // availability check was always true and the fallback was
            // unreachable code drawing a system material the design system does
            // not use.
            shape
                .fill(.clear)
                .lifeBoardSystemGlass(.regular, in: shape)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(ClayColorTokens.glassDimmingOverlay) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        }
    }

    @ViewBuilder
    private func clearCapsuleSurface(fill: Color, stroke: Color) -> some View {
        let shape = Capsule()
        if scrollOptimizedRendering {
            shape
                .fill(fill.opacity(0.94))
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        } else {
            // The `#available(iOS 26.0, *)` branch and its `.ultraThinMaterial`
            // fallback are gone: the deployment target *is* 26.0, so the
            // availability check was always true and the fallback was
            // unreachable code drawing a system material the design system does
            // not use.
            shape
                .fill(.clear)
                .lifeBoardSystemGlass(.regular, in: shape)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(ClayColorTokens.glassDimmingOverlay) }
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
