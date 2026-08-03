import SwiftUI

// MARK: - Commit control
//
// A primary action that morphs through the real state of the work it started:
// label → circle → orbiting arc → drawn tick. The shape-morph concept is adapted
// from Shubham Kumar Singh's Apache-2.0 SwiftUI-Animations `SubmitView`, which
// collapses a button into a spinner and then a checkmark. That sample drives the
// sequence from a chain of `Timer`s on a fixed schedule; this is driven entirely
// by `AsyncActionPhase`, so the control cannot claim success before the work
// actually succeeded, and a failure returns it to a retryable label instead of
// stranding a spinner.

/// The two channels of the success moment, animated together.
///
/// Kept as one keyframed value rather than two `withAnimation` calls: a tick
/// drawing on one curve while the control settles on another is exactly the kind
/// of pair that drifts apart under interruption or at large Dynamic Type sizes.
private struct CommitSuccessValues {
    var mark: Double = 0
    var scale: Double = 1
}

/// A commit button that reports the state of its own work.
///
/// Sized for the 44-point minimum at every phase, including while collapsed —
/// the circle is 48 points, so the control never becomes a target the user
/// cannot hit halfway through their own action.
public struct LifeBoardCommitControl<Receipt: Equatable & Sendable>: View {
    private let title: String
    private let runningTitle: String
    private let successTitle: String
    private let phase: AsyncActionPhase<Receipt>
    private let isEnabled: Bool
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin: Double = 0

    private static var collapsedSide: CGFloat { 48 }

    public init(
        title: String,
        runningTitle: String? = nil,
        successTitle: String? = nil,
        phase: AsyncActionPhase<Receipt>,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.runningTitle = runningTitle ?? title
        self.successTitle = successTitle ?? title
        self.phase = phase
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            phaseContent
                .frame(minHeight: Self.collapsedSide)
                .frame(maxWidth: isCollapsed ? Self.collapsedSide : .infinity)
                .background(background)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false || isRunning)
        .animation(morph, value: isCollapsed)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    // MARK: Phase content

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .idle, .cancelled:
            label(title)
        case .running(let progress):
            runningIndicator(progress: progress)
        case .success:
            successMark
        case .recoverableFailure:
            label("Try again")
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 18)
            .transition(.opacity)
    }

    /// A determinate ring when the work reports progress, an orbiting arc when it
    /// cannot. Under Reduce Motion the arc stops travelling and becomes the
    /// system indicator, because a perpetually rotating element is exactly what
    /// that setting exists to remove.
    @ViewBuilder
    private func runningIndicator(progress: Double?) -> some View {
        if let progress {
            Circle()
                .trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(inverseInk, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 22, height: 22)
        } else if reduceMotion {
            ProgressView()
                .controlSize(.small)
                .tint(inverseInk)
        } else {
            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(inverseInk, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(spin))
                .onAppear {
                    spin = 0
                    withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                        spin = 360
                    }
                }
                .onDisappear { spin = 0 }
        }
    }

    /// The ring unwinds into a checkmark while the control settles, both driven
    /// from one keyframed value.
    @ViewBuilder
    private var successMark: some View {
        if reduceMotion {
            LifeBoardCompletionMark(progress: 1)
                .stroke(inverseInk, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 22, height: 22)
        } else {
            KeyframeAnimator(
                initialValue: CommitSuccessValues(),
                trigger: successTitle
            ) { values in
                LifeBoardCompletionMark(progress: values.mark)
                    .stroke(inverseInk, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 22, height: 22)
                    .scaleEffect(values.scale)
            } keyframes: { _ in
                KeyframeTrack(\.mark) {
                    CubicKeyframe(1, duration: 0.36)
                }
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.16, duration: 0.2, spring: Spring(response: 0.24, dampingRatio: 0.62))
                    SpringKeyframe(1.0, duration: 0.24, spring: Spring(response: 0.3, dampingRatio: 0.82))
                }
            }
        }
    }

    // MARK: Appearance

    private var background: some View {
        Capsule(style: .continuous).fill(fillColor)
    }

    private var fillColor: Color {
        switch phase {
        case .success:
            Color.lifeboard(.statusSuccess)
        case .recoverableFailure:
            Color.lifeboard(.statusWarning)
        case .idle, .running, .cancelled:
            Color(LifeBoardColorTokens.inkPrimary)
        }
    }

    private var inverseInk: Color {
        Color(LifeBoardColorTokens.foundationSurfaceSolid)
    }

    /// Collapsed only while the control is showing state rather than an
    /// instruction, so the label never disappears with work still to request.
    private var isCollapsed: Bool {
        switch phase {
        case .running, .success: true
        case .idle, .cancelled, .recoverableFailure: false
        }
    }

    private var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    private var morph: Animation? {
        LifeBoardMotionProfile.controlMorph.animation(reduceMotion: reduceMotion)
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        switch phase {
        case .idle, .cancelled: title
        case .running: runningTitle
        case .success: successTitle
        case .recoverableFailure: "Try again"
        }
    }

    private var accessibilityValue: String {
        switch phase {
        case .idle: "Ready"
        case .running(let progress):
            progress.map { "\(Int($0 * 100)) percent" } ?? "In progress"
        case .success: "Complete"
        case .recoverableFailure(let failure): failure.message
        case .cancelled: "Cancelled"
        }
    }
}
