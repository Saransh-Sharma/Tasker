import SwiftUI

struct SunriseInsightsHeroCard: View {
    let title: String
    let answer: String
    let metric: String
    var role: LBRole = .focus
    var decorAsset: SunriseDecorAsset = .daySun
    var primaryActionTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var accessibilityIdentifier: String = "home.insights.hero"

    private var style: LBRoleStyle { LBColorTokens.role(role) }

    var body: some View {
        Button(action: { primaryAction?() }) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                    Text(title)
                        .font(.lifeboard(.title3).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(answer)
                        .font(.lifeboard(.body))
                        .foregroundStyle(LBColorTokens.navySoft)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(metric)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(style.deep)
                        .padding(.top, 2)
                        .accessibilityIdentifier("home.insights.hero.metric")

                    if let primaryActionTitle {
                        Text(primaryActionTitle)
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(LBColorTokens.violetDeep)
                            .padding(.horizontal, LBSpacingTokens.sm)
                            .padding(.vertical, 6)
                            .background(LBColorTokens.glassStrong, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(LBSpacingTokens.md)
                .padding(.trailing, 92)
                .padding(.bottom, LBSpacingTokens.xs)

                SunriseDecorImage(asset: .cloud, size: 196, opacity: 0.30)
                    .offset(x: -10, y: 48)

                SunriseDecorImage(asset: decorAsset, size: decorSize, opacity: 0.94)
                    .offset(x: decorOffsetX, y: decorOffsetY)
            }
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                style.softSurface.opacity(0.92),
                                LBColorTokens.glassStrong,
                                LBColorTokens.coolCanvas.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(style.border.opacity(0.58), lineWidth: 1)
                    )
                    .shadow(color: LBColorTokens.elevationShadow, radius: 20, x: 0, y: 11)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var decorSize: CGFloat {
        switch decorAsset {
        case .daySun, .planSun:
            return 132
        case .mountain:
            return 116
        case .thinkingCup:
            return 104
        default:
            return 118
        }
    }

    private var decorOffsetX: CGFloat {
        switch decorAsset {
        case .daySun, .planSun:
            return 24
        case .mountain:
            return 4
        default:
            return 18
        }
    }

    private var decorOffsetY: CGFloat {
        switch decorAsset {
        case .daySun, .planSun:
            return 26
        case .mountain:
            return 16
        default:
            return 18
        }
    }
}

struct SunriseInsightsReflectionCard: View {
    let state: DailyReflectionEntryState
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: LBSpacingTokens.md) {
                VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                    Text(state.badgeText ?? state.title)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(LBColorTokens.role(.warning).deep)

                    Text(state.narrativeSummary.homeCardLine)
                        .font(.lifeboard(.body))
                        .foregroundStyle(LBColorTokens.navySoft)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SunriseDecorImage(asset: .growthPlant, size: 82, opacity: 0.86)
            }
            .padding(LBSpacingTokens.md)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [LBColorTokens.amberSoft.opacity(0.82), LBColorTokens.glassStrong],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(LBColorTokens.role(.warning).border.opacity(0.48), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.dailyReflection.entry.compact")
        .accessibilityLabel("\(state.title). \(state.narrativeSummary.homeCardLine). Reflect and plan")
        .accessibilityHint("Opens Reflect and Plan")
    }
}
