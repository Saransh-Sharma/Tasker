import SwiftUI

final class TaskerLaunchSplashState: ObservableObject {
    @Published private(set) var isCompletingReveal = false

    func completeReveal() {
        guard isCompletingReveal == false else { return }
        isCompletingReveal = true
    }
}

enum TaskerLaunchSplashMetrics {
    static let iconSide: CGFloat = 112
    static let coverOverscan: CGFloat = 1.18
    static let revealDuration: TimeInterval = 0.58
    static let finalCrossfadeDuration: TimeInterval = 0.08
    static let revealAnimation: Animation = .timingCurve(
        0.65,
        0,
        0.35,
        1,
        duration: revealDuration
    )

    static func coverScale(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return max(max(size.width, size.height) / iconSide * coverOverscan, 1)
    }
}

struct TaskerLaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var state: TaskerLaunchSplashState

    init(state: TaskerLaunchSplashState = TaskerLaunchSplashState()) {
        self.state = state
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("LaunchCanvas")
                    .ignoresSafeArea()

                Image(decorative: "TaskerSplashIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: TaskerLaunchSplashMetrics.iconSide,
                        height: TaskerLaunchSplashMetrics.iconSide
                    )
                    .scaleEffect(iconScale(for: geometry.size), anchor: .center)
                    .animation(
                        reduceMotion ? nil : TaskerLaunchSplashMetrics.revealAnimation,
                        value: state.isCompletingReveal
                    )
            }
        }
    }

    private func iconScale(for size: CGSize) -> CGFloat {
        guard reduceMotion == false, state.isCompletingReveal else { return 1 }
        return TaskerLaunchSplashMetrics.coverScale(for: size)
    }
}

#Preview {
    TaskerLaunchSplashView()
}
