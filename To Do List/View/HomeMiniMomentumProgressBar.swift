import SwiftUI

struct HomeMiniMomentumProgressBar: View {
    let progress: Double
    let isStreakSafeToday: Bool
    let animate: Bool

    var body: some View {
        ProgressView(value: min(max(progress, 0), 1))
            .progressViewStyle(.linear)
            .tint(isStreakSafeToday ? Color.tasker.accentPrimary : Color.tasker.statusWarning)
            .scaleEffect(x: 1, y: 0.8, anchor: .center)
            .animation(
                animate ? .easeOut(duration: 0.22) : .linear(duration: 0.01),
                value: progress
            )
    }
}
