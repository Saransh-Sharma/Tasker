import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// One reflection figure in the review grid.
///
/// Was the only tile on the screen that was not clay — a translucent
/// `RoundedRectangle` at a radius nothing else used, which made a grid of
/// identical facts render in two different materials.
struct InsightMetric: View {
    let value: String
    let label: String

    var body: some View {
        MetricHeroWell(
            MetricHero(
                label: label,
                reading: .recorded(value: value, unit: nil),
                accessibilityID: "insights.metric"
            )
        )
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    }
}

struct EvidenceRow: View {
    let event: NormalizedLifeEvent
    let onOpenEvidence: (EvidenceReference) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(Color(SemanticColorTokens.foundationFocusRing))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .lifeboardFont(.headline)
                Text(event.provenance)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(.secondary)
                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .lifeboardFont(.caption2)
                    .foregroundStyle(.secondary)
                if event.evidence.isEmpty == false {
                    HStack(spacing: 6) {
                        ForEach(event.evidence, id: \.self) { evidence in
                            Button(evidence.display) { onOpenEvidence(evidence) }
                                .lifeboardFont(.eyebrow)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if let value = event.numericValue { Text(value.formatted()).font(.headline.monospacedDigit()) }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider().opacity(0.55) }
        .accessibilityElement(children: .contain)
    }
}
