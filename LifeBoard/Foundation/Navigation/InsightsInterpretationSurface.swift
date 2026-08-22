import LifeBoardUI
import SwiftUI
import UIKit

/// The headline claim Insights is willing to make, with the completeness of
/// the evidence it rests on stated alongside it.
///
/// This is the screen's hero. `DESIGN.md` asks Insights for "one interpretation
/// and one action before charts", which is the hero budget exactly — a claim, a
/// recommended action, and the honesty about what the claim rests on. The charts
/// and tallies that follow stay in clay, because evidence read over a moving
/// scene is evidence whose value depends on what is behind it.
struct InsightsInterpretationSurface: View {
    let interpretation: InsightsInterpretation
    let completenessDescription: String

    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Label("What changed", systemImage: "sparkles")
                .lifeboardFont(.eyebrow)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Text(interpretation.claim)
                .lifeboardFont(.title1)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Text(interpretation.recommendedAction)
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            // Completeness is not decoration. A claim drawn from partial
            // evidence has to say so beside the claim, not in a disclosure the
            // reader has to open.
            Label(completenessDescription, systemImage: "checkmark.shield")
                .lifeboardFont(.caption2)
                .foregroundStyle(Color.lifeboard(.textTertiary))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardHeroSurface(palette: palette)
        .accessibilityIdentifier("insights.interpretation")
    }
}
