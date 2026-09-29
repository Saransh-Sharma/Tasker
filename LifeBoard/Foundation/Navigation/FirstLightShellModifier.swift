import SwiftUI
import LifeBoardTokens

/// The day's first commitment: the shell claims the one-per-day gate, shows
/// a one-line caption that folds away, and tells the surface that was
/// completed to run its `firstLight` sweep (`.lifeboardFirstLightFired`).
///
/// Every boundary — a habit, a task, a composer capture — posts
/// `.lifeboardDailyCommitment` and this is the only place the gate is claimed,
/// so the caption and the Calm, Reduce Motion and energy rules apply to all of
/// them. The composer used to claim the gate itself and skipped both.
struct FirstLightShellModifier: ViewModifier {
    @Environment(\.lifeBoardMotionContext) private var motion
    @State private var captionIsShowing = false
    @State private var captionTask: Task<Void, Never>?

    static let captionDuration: Duration = .milliseconds(3_200)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if captionIsShowing {
                    caption
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(MotionProfile.contentInsertion.animation(reduceMotion: motion.effectiveReduceMotion), value: captionIsShowing)
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardDailyCommitment)) { notification in
                fire(forwarding: notification.userInfo)
            }
    }

    private var caption: some View {
        Text("First one done.")
            .lifeboardFont(.caption1)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.pill)
            // Above the floating composer and the dock, not on top of them.
            .padding(.bottom, 168)
            .allowsHitTesting(false)
            .accessibilityIdentifier("lifeboard.firstLight.fired")
    }

    private func fire(forwarding userInfo: [AnyHashable: Any]?) {
        guard FirstLightGate.shared.claim() else { return }
        // Calm, Reduce Motion and a constrained device get the words without
        // the sweep; the modifier's own fallback covers Reduce Motion, this
        // covers the comfort and energy rules the design law adds on top.
        // The sweep itself runs on the leaf that was completed (the habit
        // tile row, the board's day cards): `lifeboardFirstLight` cannot sit
        // above stateful views. Calm, Reduce Motion and a constrained device
        // get the words without the sweep.
        if motion.comfortProfile != .calm, motion.effectiveReduceMotion == false, motion.isEnergyConstrained == false {
            // The commitment's source and token ride along, so only the
            // surface that recorded it sweeps.
            NotificationCenter.default.post(name: .lifeboardFirstLightFired, object: nil, userInfo: userInfo)
        }
        captionTask?.cancel()
        captionIsShowing = true
        captionTask = Task {
            try? await Task.sleep(for: Self.captionDuration)
            guard Task.isCancelled == false else { return }
            captionIsShowing = false
        }
    }
}

extension View {
    func lifeBoardFirstLightOnFirstCommitment() -> some View {
        modifier(FirstLightShellModifier())
    }
}
