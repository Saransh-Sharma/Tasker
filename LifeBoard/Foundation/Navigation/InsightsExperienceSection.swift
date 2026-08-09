import SwiftUI
import UIKit

/// The optional experience lens: a read of the local XP ledger, deliberately
/// framed as a record rather than a score.
struct InsightsExperienceSection: View {
    let isAvailable: Bool
    let loadFinished: Bool
    let errorMessage: String?
    let aggregates: [DailyXPAggregateDefinition]
    @Binding var lens: InsightsLens
    let reload: () -> Void

    @ViewBuilder
    var body: some View {
        if isAvailable == false {
            ContentUnavailableView(
                "Experience lens unavailable",
                systemImage: "sparkles",
                description: Text("Your planning and reflection evidence is still available in the other lenses.")
            )
            .frame(minHeight: 220)
        } else if loadFinished == false {
            ProgressView("Reading your local experience ledger…")
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if let errorMessage {
            StatusSurface(
                state: .recoverableError,
                title: "Experience history is temporarily unavailable",
                message: errorMessage,
                actionTitle: "Try again",
                action: reload
            )
        } else if aggregates.isEmpty {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "No experience history yet",
                    systemImage: "sparkles",
                    description: Text("This optional lens appears as actions earn entries in your local ledger.")
                )
                Button("Return to Review") {
                    lens = .review
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityIdentifier("insights.experience.empty.openReview")
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Experience, if it helps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Text("\(aggregates.reduce(0) { $0 + $1.totalXP }) XP")
                    .font(Typography.screenTitle().weight(.bold))
                    .monospacedDigit()
                Text("An optional view of the existing local ledger—not a score for your day.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: 24)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("insights.experience.summary")

            VStack(alignment: .leading, spacing: 0) {
                Text("Last seven days")
                    .font(.headline)
                    .padding(.bottom, 6)
                ForEach(aggregates.sorted { $0.dateKey > $1.dateKey }, id: \.id) { aggregate in
                    HStack {
                        Text(dayLabel(aggregate.dateKey))
                        Spacer()
                        Text("\(aggregate.totalXP) XP · \(aggregate.eventCount) \(aggregate.eventCount == 1 ? "entry" : "entries")")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .frame(minHeight: 48)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(LifeBoardColorTokens.foundationHairline))
                            .frame(height: 1)
                    }
                }
            }
            .accessibilityIdentifier("insights.experience.history")
        }
    }
    private func dayLabel(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return dateKey }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
