import SwiftUI
import UIKit

/// The default occupant of the day's decision slot: how much room is left, and
/// the only entry point to the working-hours composer the budget is derived
/// from.
struct PlanCapacityCard: View {
    let capacity: CapacityBudget
    @Binding var showsWorkingHours: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(capacity.overloadDuration > 0 ? "Over capacity" : "Room in the day")
                        .font(.headline)
                    Text(PlanSectionCopy.loadLabel(capacity))
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer()
                NumericRoll(
                    value: capacity.usableDuration / 3_600,
                    fractionDigits: capacity.usableDuration.truncatingRemainder(dividingBy: 3_600) == 0 ? 0 : 1,
                    unit: "hours"
                )
                    .accessibilityLabel("\(PlanSectionCopy.duration(capacity.usableDuration)) usable")
                Button { showsWorkingHours = true } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit working hours and buffer")
            }
            ProgressView(value: PlanSectionCopy.loadFraction(capacity))
                .tint(PlanSectionCopy.loadColor(capacity))
            // Capacity says how much room is left; this says how much of the day
            // is left to spend it in. The two together are the actual question.
            CelestialDaypartIndicator()
                .frame(height: 44)
                .accessibilityIdentifier("plan.capacity.daypart")
            HStack {
                Label(
                    "\(PlanSectionCopy.duration(capacity.plannedEstimatedDuration)) planned",
                    systemImage: "checkmark.circle"
                )
                Spacer()
                if capacity.isEstimateIncomplete {
                    Label("\(capacity.missingEstimateCount) estimates missing", systemImage: "questionmark.circle")
                } else {
                    Label("High confidence", systemImage: "checkmark.shield")
                }
            }
            .font(.caption)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.capacity")
    }
}
