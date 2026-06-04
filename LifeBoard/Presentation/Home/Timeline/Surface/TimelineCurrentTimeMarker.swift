import SwiftUI

struct TimelineCurrentTimeMarker: View {
    let time: Date
    let railMetrics: TimelineRailMetrics
    let startX: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            TimelineRailLabel(
                text: TimelineRailTimeFormatter.railText(for: time, kind: .current),
                kind: .current,
                isEmphasized: true,
                color: Color.lifeboard.statusDanger,
                metrics: railMetrics
            )
                .offset(y: -8)

            Circle()
                .fill(Color.lifeboard.statusDanger)
                .frame(width: 8, height: 8)
                .offset(x: startX - 4, y: -4)
        }
        .frame(width: startX + 4, height: 1, alignment: .leading)
    }
}
