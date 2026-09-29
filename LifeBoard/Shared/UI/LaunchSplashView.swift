import SwiftUI

final class LaunchSplashState: ObservableObject {
    @Published private(set) var isCompletingReveal = false
    /// How long the icon's zoom-through takes. Full length only the first
    /// time; see `LaunchSplashMetrics.warmRevealDuration`.
    @Published private(set) var revealDuration: TimeInterval = LaunchSplashMetrics.revealDuration

    func completeReveal(duration: TimeInterval = LaunchSplashMetrics.revealDuration) {
        guard isCompletingReveal == false else { return }
        revealDuration = duration
        isCompletingReveal = true
    }
}

enum LaunchSplashMetrics {
    static let iconSide: CGFloat = 112
    static let coverOverscan: CGFloat = 1.18
    static let revealDuration: TimeInterval = 0.58
    /// Every launch after the first. The 0.58 s zoom is a nice first
    /// impression and a tax on every launch after it: Home was already
    /// attached underneath and the person waited on the icon.
    static let warmRevealDuration: TimeInterval = 0.24
    static let finalCrossfadeDuration: TimeInterval = 0.08
    static let revealAnimation: Animation = revealAnimation(duration: revealDuration)

    static func revealAnimation(duration: TimeInterval) -> Animation {
        .timingCurve(0.65, 0, 0.35, 1, duration: duration)
    }

    /// When the loading status line appears, and when it adds that the app
    /// is still working. A normal launch attaches Home long before either.
    static let statusDelay: Duration = .milliseconds(1_500)
    static let slowHintDelay: Duration = .seconds(10)

    static func coverScale(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return max(max(size.width, size.height) / iconSide * coverOverscan, 1)
    }
}

struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var state: LaunchSplashState
    private let runtime: AppRuntime?
    @State private var showsStatus = false
    @State private var showsSlowHint = false

    init(state: LaunchSplashState = LaunchSplashState(), runtime: AppRuntime? = nil) {
        self.state = state
        self.runtime = runtime
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("LaunchCanvas")
                    .ignoresSafeArea()

                statusLines
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 32)
                    .padding(.bottom, max(geometry.size.height * 0.16, 48))

                Image(decorative: "LifeBoardSplashIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: LaunchSplashMetrics.iconSide,
                        height: LaunchSplashMetrics.iconSide
                    )
                    .scaleEffect(iconScale(for: geometry.size), anchor: .center)
                    .animation(
                        reduceMotion
                            ? nil
                            : LaunchSplashMetrics.revealAnimation(duration: state.revealDuration),
                        value: state.isCompletingReveal
                    )
            }
        }
        .task {
            // A static icon with no end in sight reads as a hang. After a
            // beat, say what is happening; after a long wait, say it is still
            // happening. Neither shows on a normal launch.
            try? await Task.sleep(for: LaunchSplashMetrics.statusDelay)
            guard Task.isCancelled == false else { return }
            showsStatus = true
            try? await Task.sleep(
                for: LaunchSplashMetrics.slowHintDelay - LaunchSplashMetrics.statusDelay
            )
            guard Task.isCancelled == false else { return }
            showsSlowHint = true
        }
    }

    @ViewBuilder
    private var statusLines: some View {
        if showsStatus, state.isCompletingReveal == false {
            VStack(spacing: 8) {
                Text(statusText)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                if showsSlowHint {
                    Text("This can take a minute.")
                        .lifeboardFont(.meta)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
            .lifeBoardMotion(.contentInsertion, value: showsSlowHint)
        }
    }

    private var statusText: String {
        // Loading copy is never narrated: one word, whatever the stage.
        String(localized: "Loading…")
    }

    private func iconScale(for size: CGSize) -> CGFloat {
        guard reduceMotion == false, state.isCompletingReveal else { return 1 }
        return LaunchSplashMetrics.coverScale(for: size)
    }
}

#Preview {
    LaunchSplashView()
}
