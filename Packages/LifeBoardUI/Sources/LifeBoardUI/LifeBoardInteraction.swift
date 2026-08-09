import SwiftUI
import UIKit
import LifeBoardTokens
// MARK: - Purpose-named motion
//
// Motion tokens are named for what the interface is *doing*, never for how the
// curve feels. "bouncy", "snappy" and "expressive" are banned by the motion-law
// guardrail precisely because feel-named tokens get reused for unrelated
// reasons and the system loses its meaning.
//
// These live in `DesignSystem/` because that is the only place raw spring
// geometry is permitted; feature code composes these instead of writing springs.

@MainActor
public enum InteractionMotion {
    /// A card arriving into the viewport.
    public static func cardEntrance(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    /// A surface lifting under the finger, or settling back down.
    public static func cardLift(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.82)
    }

    /// A metric ring moving to a new value. Slower than a state change so the
    /// eye can follow the arc rather than just noticing it jumped.
    public static func ringSettle(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.9)
    }

    /// A sheet or overlay rising into place.
    public static func sheetRise(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.14) : .spring(response: 0.46, dampingFraction: 0.88)
    }

    /// A commitment being completed. The one place a little overshoot is
    /// earned, because the user just finished something.
    public static func completion(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.16) : .spring(response: 0.36, dampingFraction: 0.62)
    }

    /// The whole screen changing daypart. Long and unhurried — this is
    /// atmosphere, not feedback.
    public static func dayShift(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.2) : .easeInOut(duration: 0.85)
    }

    /// A horizontal rail settling after a flick.
    public static func railScroll(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9)
    }

    /// A drag being released back to rest after not crossing its threshold.
    public static func dragRelease(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.74)
    }
}

// MARK: - Intent-named haptics

/// Haptics named for intent rather than for engine style.
///
/// The app previously called `UIImpactFeedbackGenerator` directly in 37 places
/// with no shared vocabulary, so the same physical tap meant "saved", "picked"
/// and "crossed a threshold" on different screens. Routing everything through
/// one type also gives a single place to honour `MotionPolicy`, which
/// suppresses haptics under Low Power Mode and on Catalyst.
@MainActor
public enum Haptic {
    /// Something was recorded: a task completed, an entry saved.
    case commit
    /// The selection moved: a tab, a chip, a day.
    case pick
    /// A drag was picked up.
    case lift
    /// A drag settled back into place.
    case settle
    /// A magnetic detent was crossed — the moment the action becomes committed.
    case threshold
    /// An action was refused, reverted, or undone.
    case decline
    /// Something failed.
    case fail

    public func play(policy: MotionPolicy? = nil) {
        let resolved = policy ?? MotionPolicy.resolve(
            reduceMotion: false,
            reduceTransparency: false,
            sceneIsActive: true
        )
        guard resolved.allowsHaptics else { return }
        switch self {
        case .commit: LifeBoardFeedback.success()
        case .pick: LifeBoardFeedback.selection()
        case .lift: LifeBoardFeedback.medium()
        case .settle: LifeBoardFeedback.light()
        case .threshold: LifeBoardFeedback.medium()
        case .decline: LifeBoardFeedback.warning()
        case .fail: LifeBoardFeedback.error()
        }
    }
}

// MARK: - Scroll-driven entrance

/// Cards rise, focus and fade in as they enter the viewport.
///
/// This is the app's first use of `scrollTransition` — before it, every list
/// and dashboard grid appeared with SwiftUI's default instant insert, which is
/// the single biggest reason the product read as static.
///
/// The effect is deliberately asymmetric: content is treated only on the way
/// *in* from the bottom. Applying it to the top edge as well makes scrolling up
/// feel like the interface is dissolving behind you.
private struct ScrollEntrance: ViewModifier {
    let intensity: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(.interactive, axis: .vertical) { view, phase in
                let entering = max(0, phase.value)
                return view
                    .opacity(1 - entering * 0.5 * intensity)
                    .scaleEffect(1 - entering * 0.045 * intensity, anchor: .top)
                    .offset(y: entering * 16 * intensity)
                    .blur(radius: entering * 2.2 * intensity)
            }
        }
    }
}

public extension View {
    /// Applies the shared scroll entrance. `intensity` scales the whole effect
    /// so dense rails can use a lighter touch than full-width cards.
    func lifeBoardScrollEntrance(intensity: CGFloat = 1) -> some View {
        modifier(ScrollEntrance(intensity: intensity))
    }
}

// MARK: - Magnetic toggle

/// Drag-to-complete with a magnetic detent.
///
/// The row follows the finger with progressively increasing resistance, snaps
/// open once the threshold is crossed, and fires a single haptic at exactly
/// that crossing rather than continuously. Past the detent the rubber band
/// stiffens so the gesture has a felt ceiling.
///
/// The design contract requires gesture parity: every drag action must also be
/// reachable as a button, a keyboard action and a VoiceOver custom action. This
/// modifier supplies the accessibility action itself; callers are responsible
/// for the visible control.
private struct MagneticToggle: ViewModifier {
    let threshold: CGFloat
    let actionLabel: String
    let perform: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var translation: CGFloat = 0
    @State private var hasCrossed = false

    func body(content: Content) -> some View {
        content
            .offset(x: translation)
            .gesture(dragGesture)
            .animation(InteractionMotion.dragRelease(reduceMotion: reduceMotion), value: translation)
            .accessibilityAction(named: Text(actionLabel), perform)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                // Never steal a vertical scroll. The row only tracks the finger
                // once the gesture is unambiguously horizontal.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let raw = value.translation.width
                translation = rubberBanded(raw)
                let crossed = raw >= threshold
                if crossed != hasCrossed {
                    hasCrossed = crossed
                    if crossed { Haptic.threshold.play() }
                }
            }
            .onEnded { value in
                let committed = value.translation.width >= threshold
                translation = 0
                hasCrossed = false
                if committed {
                    Haptic.commit.play()
                    perform()
                } else if abs(value.translation.width) > 8 {
                    Haptic.settle.play()
                }
            }
    }

    /// Linear up to the detent, then log-compressed so the row cannot be
    /// dragged off the screen and the threshold stays physically legible.
    private func rubberBanded(_ raw: CGFloat) -> CGFloat {
        guard raw > 0 else { return raw / 4 }
        if raw <= threshold { return raw }
        let excess = raw - threshold
        return threshold + log10(1 + excess / 10) * 22
    }
}

public extension View {
    /// Drag right past `threshold` to fire `perform`. Always pair with a
    /// visible control — this supplies only the gesture and its VoiceOver
    /// custom action.
    func lifeBoardMagneticToggle(
        threshold: CGFloat = 88,
        actionLabel: String,
        perform: @escaping () -> Void
    ) -> some View {
        modifier(MagneticToggle(
            threshold: threshold,
            actionLabel: actionLabel,
            perform: perform
        ))
    }
}
