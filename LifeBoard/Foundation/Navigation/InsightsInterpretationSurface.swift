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
    /// The hero's one primary action and its one quiet alternative. They used to
    /// sit outside the surface as two loose buttons, which left the hero with a
    /// claim and no way to act on it — `DESIGN.md` gives a hero "one primary
    /// action and at most one quiet alternative", and these are they.
    var exploreWithEva: (() -> Void)?
    var dismissEverywhere: (() -> Void)?

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

            if exploreWithEva != nil || dismissEverywhere != nil {
                VStack(spacing: 8) {
                    if let exploreWithEva {
                        Button(action: exploreWithEva) {
                            Label("Explore this with Eva", systemImage: "sparkles")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .tint(Color(SemanticColorTokens.foundationApricotAccent))
                        .accessibilityIdentifier("insights.interpretation.askEva")
                    }

                    if let dismissEverywhere {
                        Button("Dismiss everywhere", systemImage: "xmark.circle", action: dismissEverywhere)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .accessibilityIdentifier("insights.interpretation.dismiss")
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardHeroSurface(palette: palette)
        .accessibilityIdentifier("insights.interpretation")
    }
}
