import SwiftUI

struct CurvingDayStreamView: View {
    let geometry: TimelineStreamGeometry
    let currentY: CGFloat?
    @Environment(\.lifeboardScrollOptimizedRendering) var scrollOptimizedRendering

    var body: some View {
        if scrollOptimizedRendering {
            streamCanvas
        } else {
            streamCanvas
                .drawingGroup()
        }
    }

    var streamCanvas: some View {
        Canvas { context, _ in
            let path = geometry.path()
            let fullOpacity = currentY == nil ? 0.88 : 0.94
            let gradient = Gradient(colors: [
                TimelineStreamPalette.color(progress: 0).opacity(0.78 * fullOpacity),
                TimelineStreamPalette.color(progress: 0.38).opacity(0.80 * fullOpacity),
                TimelineStreamPalette.color(progress: 0.72).opacity(0.78 * fullOpacity),
                TimelineStreamPalette.color(progress: 1).opacity(0.76 * fullOpacity)
            ])
            let startPoint = CGPoint(x: geometry.baseX, y: geometry.startY)
            let endPoint = CGPoint(x: geometry.baseX, y: geometry.endY)

            if scrollOptimizedRendering == false {
                let visibleGlintIDs = TimelineStreamGlintPresentation.visibleAnchorIDs(
                    anchors: geometry.anchors,
                    currentY: currentY
                )
                let glowGradient = Gradient(colors: [
                    TimelineStreamPalette.color(progress: 0).opacity(0.18),
                    TimelineStreamPalette.color(progress: 0.38).opacity(0.20),
                    TimelineStreamPalette.color(progress: 0.72).opacity(0.18),
                    TimelineStreamPalette.color(progress: 1).opacity(0.17)
                ])
                context.stroke(
                    path,
                    with: .linearGradient(glowGradient, startPoint: startPoint, endPoint: endPoint),
                    style: StrokeStyle(
                        lineWidth: TimelineStreamGeometry.glowLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                for anchor in geometry.anchors where visibleGlintIDs.contains(anchor.id) {
                    guard let glintPath = glintPath(centerY: anchor.y) else {
                        continue
                    }
                    let glintColor = TimelineStreamPalette.color(progress: progress(for: anchor.y))
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: TimelineStreamGlintPresentation.blurRadius))
                        layer.stroke(
                            glintPath,
                            with: .color(glintColor.opacity(TimelineStreamGlintPresentation.opacity * 0.55)),
                            style: StrokeStyle(
                                lineWidth: TimelineStreamGeometry.baseLineWidth + TimelineStreamGlintPresentation.extraLineWidth + 1,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                    context.stroke(
                        glintPath,
                        with: .color(glintColor.opacity(TimelineStreamGlintPresentation.opacity)),
                        style: StrokeStyle(
                            lineWidth: TimelineStreamGeometry.baseLineWidth + TimelineStreamGlintPresentation.extraLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }

            context.stroke(
                path,
                with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint),
                style: StrokeStyle(
                    lineWidth: TimelineStreamGeometry.baseLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.58 * fullOpacity)),
                style: StrokeStyle(
                    lineWidth: TimelineStreamGeometry.coreLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .accessibilityHidden(true)
    }

    func glintPath(centerY: CGFloat) -> Path? {
        let samples = geometry.samples(stride: 5).filter { abs($0.y - centerY) <= TimelineStreamGlintPresentation.halfLength }
        guard samples.count > 1 else { return nil }
        var path = Path()
        path.move(to: CGPoint(x: samples[0].x, y: samples[0].y))
        for sample in samples.dropFirst() {
            path.addLine(to: CGPoint(x: sample.x, y: sample.y))
        }
        return path
    }

    func progress(for y: CGFloat) -> CGFloat {
        let span = max(geometry.endY - geometry.startY, 1)
        return min(max((y - geometry.startY) / span, 0), 1)
    }
}
