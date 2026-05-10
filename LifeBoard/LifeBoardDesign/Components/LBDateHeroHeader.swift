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
    let onMenu: () -> Void
    let onNotifications: () -> Void
    let onDateTap: () -> Void
    let onFilters: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                headerButton(systemName: "line.3.horizontal", size: 48, action: onMenu)
                    .accessibilityLabel("Menu")
                Spacer()
                headerButton(systemName: "bell", size: 48, showsDot: model.hasNotifications, action: onNotifications)
                    .accessibilityLabel("Notifications")
            }
            .padding(.horizontal, LBSpacingTokens.screenMargin)

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
            }
            .buttonStyle(.plain)

            HStack(spacing: LBSpacingTokens.xs) {
                dateStepButton(systemName: "chevron.left")
                Button(action: onDateTap) {
                    HStack(spacing: LBSpacingTokens.sm) {
                        Image(systemName: "calendar")
                        Text(model.navigatorTitle)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .font(LBTypographyTokens.chip)
                    .foregroundStyle(model.navigatorColor)
                    .frame(minHeight: 42)
                    .padding(.horizontal, LBSpacingTokens.md)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(model.navigatorGlassFill, in: Capsule())
                    .overlay { Capsule().stroke(model.navigatorGlassStroke, lineWidth: 1.2) }
                }
                .buttonStyle(.plain)
                dateStepButton(systemName: "chevron.right")
                headerButton(systemName: "slider.horizontal.3", size: 42, showsDot: model.hasActiveFilters, action: onFilters)
                    .accessibilityLabel("Filters")
            }
            .padding(.horizontal, LBSpacingTokens.screenMargin)
        }
        .padding(.top, 2)
    }

    private func headerButton(systemName: String, size: CGFloat, showsDot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: size > 44 ? 20 : 17, weight: .semibold))
                    .foregroundStyle(model.chromeControlColor)
                    .frame(width: size, height: size)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(model.chromeGlassFill, in: Circle())
                    .overlay { Circle().stroke(model.chromeGlassStroke, lineWidth: 1.2) }
                if showsDot {
                    Circle()
                        .fill(LBColorTokens.sunriseGold)
                        .frame(width: 11, height: 11)
                        .offset(x: -7, y: 7)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func dateStepButton(systemName: String) -> some View {
        Button(action: onDateTap) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(model.navigatorColor)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .background(model.navigatorGlassFill, in: Circle())
                .overlay { Circle().stroke(model.navigatorGlassStroke, lineWidth: 1.2) }
        }
        .buttonStyle(.plain)
    }

    static func dateTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day())
    }

    static func navigatorTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().weekday(.wide))
    }
}
