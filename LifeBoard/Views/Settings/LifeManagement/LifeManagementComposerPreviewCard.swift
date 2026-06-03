import SwiftUI
import UIKit

struct LifeManagementComposerPreviewCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    let metrics: [LifeManagementComposerPreviewMetric]

    @Environment(\.lifeboardLayoutClass) var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var previewSignature: String {
        "\(title)-\(subtitle)-\(iconName)-\(metrics.map(\.value).joined(separator: "|"))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Group {
                        if reduceMotion {
                            Image(systemName: iconName)
                        } else {
                            Image(systemName: iconName)
                                .symbolEffect(.bounce, value: previewSignature)
                        }
                    }
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(eyebrow)
                        .font(.lifeboard(.eyebrow))
                        .foregroundStyle(Color.white.opacity(0.78))

                    Text(title)
                        .font(.lifeboard(.title2).weight(.semibold))
                        .foregroundStyle(Color.white)
                        .contentTransition(.opacity)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .contentTransition(.opacity)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if metrics.isEmpty == false {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: spacing.s8) {
                        ForEach(metrics) { metric in
                            LifeManagementComposerMetricTile(metric: metric)
                        }
                    }

                    VStack(spacing: spacing.s8) {
                        ForEach(metrics) { metric in
                            LifeManagementComposerMetricTile(metric: metric)
                        }
                    }
                }
            }
        }
        .padding(spacing.s16)
        .background(
            LinearGradient(
                colors: [
                    accentColor.opacity(0.92),
                    accentColor.opacity(0.58),
                    Color.lifeboard.surfacePrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.03),
                    Color.white.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .lifeboardPremiumSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: .clear,
            strokeColor: Color.white.opacity(0.16),
            accentColor: accentColor,
            level: .e2
        )
        .animation(reduceMotion ? nil : LifeBoardAnimation.heroEmphasis, value: previewSignature)
    }
}
