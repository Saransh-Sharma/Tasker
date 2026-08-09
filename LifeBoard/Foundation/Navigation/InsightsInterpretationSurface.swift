import SwiftUI
import UIKit

/// The headline claim Insights is willing to make, with the completeness of
/// the evidence it rests on stated alongside it.
struct InsightsInterpretationSurface: View {
    let interpretation: InsightsInterpretation
    let completenessDescription: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What changed", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            Text(interpretation.claim)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(interpretation.recommendedAction)
                .font(.body)
                .foregroundStyle(.secondary)
            Label(completenessDescription, systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 24)
        .accessibilityIdentifier("insights.interpretation")
    }}
