import SwiftUI

// MARK: - Completion mark
//
// The ring→tick morph. Interaction concept adapted from Shubham Kumar Singh's
// Apache-2.0 SwiftUI-Animations `DownloadArrowShape` / `DownloadTickShape`,
// which morph one glyph into another through a single `animatableData` channel.
// The geometry, phase split and easing here are LifeBoard's own: the sample
// morphs a download arrow inside a filled disc, this unwinds an open task ring
// and draws a checkmark in its place.
//
// One animatable channel is the whole point. Two independent animations (a ring
// fading while a tick scales) drift apart at different Dynamic Type sizes and
// under interrupted gestures; a single `progress` cannot desynchronise.

// MARK: - Completion control

/// The canonical task completion target.
///
/// Every task row in the Foundation shell previously drew a decorative `circle`
/// glyph with no gesture attached, so completing a task was only reachable from
/// widgets, notifications, Eva and routine steps. This is the 44 pt control the
/// task-row contract calls for.
///
/// Callers own the write. This view reports intent and plays the reward; it
/// never assumes the mutation succeeded.
public struct CompletionControl: View {
    private let isComplete: Bool
    private let title: String
    private let isEnabled: Bool
    private let onToggle: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    @State private var progress: Double = 0
    @State private var burstTrigger = 0

    /// The visible ring is smaller than the 44 pt target; the target is padding.
    private let markSide: CGFloat = 22
    private let strokeWidth: CGFloat = 2

    public init(
        isComplete: Bool,
        title: String,
        isEnabled: Bool = true,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.isComplete = isComplete
        self.title = title
        self.isEnabled = isEnabled
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: toggle) {
            ZStack {
                if isEnabled {
                    CompletionMark(progress: progress)
                        .stroke(
                            markTint,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: markSide, height: markSide)
                } else {
                    // A blocked task is a different state, not a disabled
                    // control: the lock explains *why* it cannot be completed.
                    Image(systemName: "lock.circle")
                        .font(.system(size: markSide, weight: .regular))
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(CompletionButtonStyle())
        .disabled(isEnabled == false)
        .lifeboardCompletionBurst(trigger: burstTrigger)
        .onAppear { progress = isComplete ? 1 : 0 }
        .onChange(of: isComplete) { _, updated in settle(to: updated ? 1 : 0) }
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isEnabled ? "Completing can be undone." : "")
        .accessibilityAddTraits(isComplete ? [.isSelected] : [])
    }

    private var markTint: Color {
        // Shape carries the state, not colour: the ring and the tick are
        // different marks, so this survives Differentiate Without Color.
        isComplete
            ? Color(LifeBoardColorTokens.foundationSageAccent)
            : Color(LifeBoardColorTokens.inkTertiary)
    }

    private var accessibilityValue: String {
        if isEnabled == false { return "Waiting on a dependency" }
        return isComplete ? "Complete" : "Not complete"
    }

    private func toggle() {
        let target = isComplete == false
        settle(to: target ? 1 : 0)
        if target {
            burstTrigger &+= 1
            Haptic.commit.play(policy: motionPolicy)
        } else {
            Haptic.decline.play(policy: motionPolicy)
        }
        onToggle(target)
    }

    private var motionPolicy: MotionPolicy {
        MotionPolicy.resolve(
            reduceMotion: reduceMotion || VisualAppearanceFixture.active?.usesReducedMotion == true,
            reduceTransparency: reduceTransparency || VisualAppearanceFixture.active?.usesReducedTransparency == true,
            sceneIsActive: scenePhase == .active
        )
    }

    /// Under Reduce Motion the mark snaps between its two rest states. It never
    /// stops part-drawn, which would leave an ambiguous glyph on screen.
    private func settle(to target: Double) {
        let suppressed = LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion)
            || VisualAppearanceFixture.active?.usesReducedMotion == true
        guard suppressed == false else {
            progress = target
            return
        }
        withAnimation(InteractionMotion.completion(reduceMotion: false)) {
            progress = target
        }
    }
}

/// Press feedback for the completion target. Separate from
/// `ClayButtonStyle` because this control has no clay surface to
/// compress — only the mark itself moves.
private struct CompletionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && reduceMotion == false ? 0.88 : 1)
            .animation(MotionProfile.press.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
