import SwiftUI

struct TimelineSpineEndView: View {
    let extent: TimelineCanvasLayoutPlan.SpineExtent
    let lineWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(TimelineVisualTokens.neutralStem)
                .frame(width: lineWidth, height: max(extent.solidEndY - extent.startY, 0))
                .offset(y: extent.startY)

            LinearGradient(
                colors: [
                    TimelineVisualTokens.neutralStem,
                    TimelineVisualTokens.neutralStem.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: lineWidth, height: max(extent.fadeEndY - extent.fadeStartY, 0))
            .offset(y: extent.fadeStartY)
        }
    }
}
