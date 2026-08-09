import SwiftUI
import UIKit

/// The date/lens header above Plan's content: day stepping, the capacity
/// one-liner, and undo for the last planning mutation.
struct PlanOrientationBar: View {
    let store: PlanStore
    let lens: PlanLens

    var body: some View {
        HStack(spacing: 10) {
            if lens == .day {
                Button { Task { await store.moveSelection(by: -1) } } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous day")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lens == .day ? dayTitle(store.selectedDay) : lens.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Text(contextLine)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .lineLimit(1)
            }
            Spacer()
            if store.lastMutationReceiptID != nil {
                Button { Task { await store.undoLastMutation() } } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Undo last planning change")
            }
            if lens == .day {
                Button { Task { await store.select(day: PlanningDay(date: Date())) } } label: {
                    Image(systemName: "calendar").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Return to today")
                Button { Task { await store.moveSelection(by: 1) } } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next day")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
        .accessibilityIdentifier("plan.header")
    }

    private var contextLine: String {
        guard let capacity = store.daySnapshot?.capacity else { return "Loading capacity…" }
        return capacity.overloadDuration > 0
            ? "\(PlanSectionCopy.duration(capacity.overloadDuration)) overloaded"
            : "\(PlanSectionCopy.duration(capacity.remainingKnownCapacity)) known room"
    }

    private func dayTitle(_ day: PlanningDay) -> String { day.startDate()?.formatted(.dateTime.weekday(.wide).month(.wide).day()) ?? "Selected day" }
}
