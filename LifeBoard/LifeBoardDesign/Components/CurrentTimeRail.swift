import SwiftUI

struct CurrentTimeRail: View, Equatable {
    struct Model: Equatable {
        let now: Date
        let isToday: Bool
    }

    let model: Model

    nonisolated static func == (lhs: CurrentTimeRail, rhs: CurrentTimeRail) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        if model.isToday {
            HStack(spacing: ClayLayoutMetrics.timelineCardGap) {
                CurrentTimeBubble(
                    model: CurrentTimeBubble.Model(
                        timeText: model.now.formatted(date: .omitted, time: .shortened),
                        label: "Now"
                    )
                )
                .frame(width: ClayLayoutMetrics.timelineTimeColumnWidth, alignment: .trailing)

                Circle()
                    .fill(ClayColorTokens.violet)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(ClayColorTokens.canvas.opacity(0.92), lineWidth: 3))
                    .breathingPulse(min: 0.85, max: 1.0, duration: 2.6)
                    .frame(width: ClayLayoutMetrics.timelineRailWidth)

                Color.clear
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }
}
