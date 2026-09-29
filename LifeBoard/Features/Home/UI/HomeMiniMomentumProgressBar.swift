import SwiftUI

struct HomeMiniMomentumProgressBar: View {
    let progress: Double
    let isStreakSafeToday: Bool
    let animate: Bool

    var body: some View {
        ProgressView(value: min(max(progress, 0), 1))
            .progressViewStyle(.linear)
            .tint(Color.lifeboard.accentPrimary)
            .scaleEffect(x: 1, y: 0.8, anchor: .center)
            .animation(
                animate ? MotionProfile.threadAdvance.animation(reduceMotion: false) : nil,
                value: progress
            )
    }
}
