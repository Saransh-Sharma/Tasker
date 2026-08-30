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
            StatusSurface(
                state: .unavailable,
                title: "Experience lens unavailable",
                message: "Your planning and reflection evidence is still available in the other lenses."
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
                StatusSurface(
                    state: .noRecord,
                    title: "No experience history yet",
                    message: "This optional lens appears as actions earn entries in your local ledger."
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
                    .lifeboardFont(.eyebrow)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Text("\(aggregates.reduce(0) { $0 + $1.totalXP }) XP")
                    .font(Typography.screenTitle().weight(.bold))
                    .monospacedDigit()
                Text("An optional view of the existing local ledger—not a score for your day.")
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("insights.experience.summary")

            VStack(alignment: .leading, spacing: 0) {
                Text("Last seven days")
                    .lifeboardFont(.headline)
                    .padding(.bottom, 6)
                ForEach(aggregates.sorted { $0.dateKey > $1.dateKey }, id: \.id) { aggregate in
                    HStack {
                        Text(dayLabel(aggregate.dateKey))
                        Spacer()
                        Text("\(aggregate.totalXP) XP · \(aggregate.eventCount) \(aggregate.eventCount == 1 ? "entry" : "entries")")
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .monospacedDigit()
                    }
                    .lifeBoardScrollEntrance(intensity: 0.5)
                    .lifeboardFont(.support)
                    .frame(minHeight: 48)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(SemanticColorTokens.foundationHairline))
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
