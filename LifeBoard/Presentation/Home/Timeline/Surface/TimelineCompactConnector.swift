import SwiftUI

struct TimelineCompactConnector: View {
    let laneWidth: CGFloat
    let height: CGFloat
    let topState: TimelineStemSegmentState
    let bottomState: TimelineStemSegmentState
    let spec = TimelineRailPresentationSpec.compactConnector

    var body: some View {
        ZStack {
            Path { path in
                let x = laneWidth / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
            .stroke(
                Color.lifeboard.strokeHairline.opacity(spec.opacity),
                style: StrokeStyle(lineWidth: spec.lineWidth)
            )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(timelineStemColor(for: topState, fallbackPalette: .resolve(from: nil)))
                    .frame(width: spec.lineWidth, height: height / 2)
                Rectangle()
                    .fill(timelineStemColor(for: bottomState, fallbackPalette: .resolve(from: nil)))
                    .frame(width: spec.lineWidth, height: height / 2)
            }
        }
        .frame(width: laneWidth, height: height)
    }
}
