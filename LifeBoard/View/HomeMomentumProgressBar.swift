import SwiftUI

struct HomeMomentumProgressBar: View {
    let progress: Double
    let colors: [Color]
    var trackColor: Color = Color.tasker.surfaceSecondary
    var height: CGFloat = 6
    var animate: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(trackColor)
            .frame(height: height)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: height)
                    .scaleEffect(x: clampedProgress, y: 1, anchor: .leading)
                    .animation(
                        animate ? .spring(response: 0.34, dampingFraction: 0.82) : .linear(duration: 0.01),
                        value: clampedProgress
                    )
            }
    }
}
