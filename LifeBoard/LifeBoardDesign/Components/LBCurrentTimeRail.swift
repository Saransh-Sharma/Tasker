import SwiftUI

struct LBCurrentTimeRail: View, Equatable {
    struct Model: Equatable {
        let now: Date
        let isToday: Bool
    }

    let model: Model

    nonisolated static func == (lhs: LBCurrentTimeRail, rhs: LBCurrentTimeRail) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        if model.isToday {
            HStack(spacing: LBSpacingTokens.timelineCardGap) {
                LBCurrentTimeBubble(
                    model: LBCurrentTimeBubble.Model(
                        timeText: model.now.formatted(date: .omitted, time: .shortened),
                        label: "Now"
                    )
                )
                .frame(width: LBSpacingTokens.timelineTimeColumnWidth, alignment: .trailing)

                Circle()
                    .fill(LBColorTokens.violet)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(LBColorTokens.canvas.opacity(0.92), lineWidth: 3))
                    .frame(width: LBSpacingTokens.timelineRailWidth)

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
