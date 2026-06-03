import SwiftUI

struct TimelineStemSegments: View {
    let leading: TimelineStemSegmentState
    let trailing: TimelineStemSegmentState
    let fallbackPalette: TimelinePalette
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(timelineStemColor(for: leading, fallbackPalette: fallbackPalette))
                .frame(width: width, height: height / 2)
            Rectangle()
                .fill(timelineStemColor(for: trailing, fallbackPalette: fallbackPalette))
                .frame(width: width, height: height / 2)
        }
        .frame(width: width, height: height)
    }
}
