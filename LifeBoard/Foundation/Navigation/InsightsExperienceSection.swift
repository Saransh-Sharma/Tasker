import SwiftUI
import UIKit

/// The optional Activity lens (`InsightsLens.experience`): what got done each
/// day, framed as a record rather than a score. The XP totals behind it are
/// not shown — a number of points is a score whatever it is called.
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
                title: "Activity unavailable",
                message: ""
            )
            .frame(minHeight: 220)
        } else if loadFinished == false {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if errorMessage != nil {
            StatusSurface(
                state: .recoverableError,
                title: "Couldn’t load activity.",
                message: "",
                actionTitle: "Try again",
                action: reload
            )
        } else if aggregates.isEmpty {
            VStack(spacing: 12) {
                StatusSurface(
                    state: .noRecord,
                    title: "No activity yet",
                    message: "Finished tasks and habits show up here."
                )
                Button("Open Review") {
                    lens = .review
                }
                .buttonStyle(.lifeBoardChip)
                .frame(minHeight: 44)
                .accessibilityIdentifier("insights.experience.empty.openReview")
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 7 days")
                    .lifeboardFont(.eyebrow)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Text("\(totalEntries) done")
                    .font(Typography.screenTitle().weight(.bold))
                    .monospacedDigit()
                Text("Tasks, habits, focus and check-ins you completed.")
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("insights.experience.summary")

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("By day")
                    .padding(.bottom, 8)
                ForEach(aggregates.sorted { $0.dateKey > $1.dateKey }, id: \.id) { aggregate in
                    HStack {
                        Text(dayLabel(aggregate.dateKey))
                        Spacer()
                        Text("\(aggregate.eventCount) done")
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
    private var totalEntries: Int {
        aggregates.reduce(0) { $0 + $1.eventCount }
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
