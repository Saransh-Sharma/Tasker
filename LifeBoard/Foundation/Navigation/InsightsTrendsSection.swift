import SwiftUI
import UIKit

/// The trends lens: a chart of recorded activity with its prose equivalent,
/// then a per-area tally.
struct InsightsTrendsSection: View {
    let interpretation: InsightsInterpretation
    let sourceCounts: [(domain: String, count: Int)]

    var body: some View {
        let resolved = interpretation
        VStack(alignment: .leading, spacing: 14) {
            Text("Recorded shape")
                .font(.title2.weight(.semibold))

            // A real chart, with its prose equivalent always visible —
            // this lens used to be a list of per-domain row counts, which
            // is a tally, not a trend.
            if resolved.dailyCounts.count > 1 {
                let chart = TrendChart(
                    points: resolved.dailyCounts,
                    tint: Color(LifeBoardColorTokens.foundationApricotAccent),
                    unit: "records"
                )
                chart.frame(height: 150)
                Text(chart.textEquivalent)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("One day of history so far. A trend needs a few more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("By area")
                .font(.headline)
            ForEach(sourceCounts, id: \.domain) { item in
                HStack {
                    Text(item.domain.capitalized)
                    Spacer()
                    Text("\(item.count) \(item.count == 1 ? "record" : "records")")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 22)    }
}
