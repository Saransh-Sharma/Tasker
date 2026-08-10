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
        MotionOverride.resolve(reduceMotion) ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    /// A surface lifting under the finger, or settling back down.
    public static func cardLift(reduceMotion: Bool) -> Animation? {
        MotionOverride.resolve(reduceMotion) ? .linear(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.82)
    }

    /// A metric ring moving to a new value. Slower than a state change so the
    /// eye can follow the arc rather than just noticing it jumped.
    public static func ringSettle(reduceMotion: Bool) -> Animation? {
        MotionOverride.resolve(reduceMotion) ? nil : .spring(response: 0.55, dampingFraction: 0.9)
    }

    /// A sheet or overlay rising into place.
    public static func sheetRise(reduceMotion: Bool) -> Animation? {
        MotionOverride.resolve(reduceMotion) ? .linear(duration: 0.14) : .spring(response: 0.46, dampingFraction: 0.88)
    }

    /// A commitment being completed. The one place a little overshoot is
    /// earned, because the user just finished something.
    public static func completion(reduceMotion: Bool) -> Animation? {
        MotionOverride.resolve(reduceMotion) ? .linear(duration: 0.16) : .spring(response: 0.36, dampingFraction: 0.62)
    }

    /// The whole screen changing daypart. Long and unhurried — this is
    /// atmosphere, not feedback.
    public static func dayShift(reduceMotion: Bool) -> Animation? {
        MotionOverride.resolve(reduceMotion) ? .linear(duration: 0.2) : .easeInOut(duration: 0.85)
    }

    /// A horizontal rail settling after a flick.
    public static func railScroll(reduceMotion: Bool) -> Animation? {
        MotionOverride.resolve(reduceMotion) ? nil : .spring(response: 0.34, dampingFraction: 0.9)
    }

    /// A drag being released back to rest after not crossing its threshold.
    public static func dragRelease(reduceMotion: Bool) -> Animation? {
        MotionOverride.resolve(reduceMotion) ? .linear(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.74)
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
        case .commit: HapticFeedback.success()
        case .pick: HapticFeedback.selection()
        case .lift: HapticFeedback.medium()
        case .settle: HapticFeedback.light()
        case .threshold: HapticFeedback.medium()
        case .decline: HapticFeedback.warning()
        case .fail: HapticFeedback.error()
        }
    }
}

// MARK: - Press response

/// How much an object yields under the finger, by what kind of object it is.
///
/// `DESIGN.md`: "Objects follow the finger, controls respond immediately."
/// Scale is inversely proportional to size — a 44pt circular control needs a
/// deeper press than a full-width card to read as the same physical give, which
/// is why one shared constant never looked right everywhere and every screen
/// ended up hand-tuning its own.
public enum PressResponse: Sendable {
    /// A full-width list row. The most common case, and the quietest.
    case row
    /// An independent raised object.
    case card
    /// A small icon button, chip, or pill.
    case control
    /// The one dominant decision on a screen.
    case hero

    var pressedScale: CGFloat {
        switch self {
        case .row: 0.985
        case .card: 0.972
        case .control: 0.93
        case .hero: 0.978
        }
    }

    /// A touch of tonal recession, so the response survives grayscale and
    /// does not depend on the scale alone being perceptible.
    var pressedOpacity: Double {
        switch self {
        case .row: 0.72
        case .card: 0.86
        case .control: 0.7
        case .hero: 0.9
        }
    }

    var anchor: UnitPoint {
        // A row compressing toward its centre reads as the whole list shifting;
        // anchoring to the leading edge keeps the title still under the finger.
        self == .row ? .leading : .center
    }
}

private struct PressResponseModifier: ViewModifier {
    let response: PressResponse
    let haptic: Haptic?
    let isEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPressed = false

    private var policy: MotionPolicy {
        MotionPolicy.resolve(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        )
    }

    func body(content: Content) -> some View {
        let resolved = policy
        // Reduce Motion keeps the tonal response and drops the geometry: the
        // control must still confirm the touch, it just must not move.
        let active = isPressed && isEnabled
        let allowsScale = resolved.allowsSpatialMotion

        content
            .scaleEffect(
                active && allowsScale ? response.pressedScale : 1,
                anchor: response.anchor
            )
            .opacity(active ? response.pressedOpacity : 1)
            .animation(InteractionMotion.cardLift(reduceMotion: reduceMotion), value: isPressed)
            // A 0-distance drag reports press and release without ever claiming
            // the gesture, so this composes with the row's own Button, with a
            // NavigationLink, and with an enclosing ScrollView. A ButtonStyle
            // would have forced every adopting call site to become a Button.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, isPressed == false else { return }
                        isPressed = true
                        haptic?.play(policy: resolved)
                    }
                    .onEnded { _ in isPressed = false }
            )
            .onChange(of: isEnabled) { _, enabled in
                if enabled == false { isPressed = false }
            }
    }
}

public extension View {
    /// The shared press response. Apply to the outermost shape of the object
    /// that should yield — the row, not its label.
    ///
    /// Pass `haptic: nil` where the press is only a prelude to a larger
    /// confirmation, so the user does not feel two taps for one action.
    func lifeBoardPressResponse(
        _ response: PressResponse = .row,
        haptic: Haptic? = .pick,
        isEnabled: Bool = true
    ) -> some View {
        modifier(PressResponseModifier(
            response: response,
            haptic: haptic,
            isEnabled: isEnabled
        ))
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

// MARK: - Ambient life

/// What a surface is, for the purpose of ambient motion. The role picks the
/// envelope; callers do not get to invent their own.
public enum AmbientRole: Sendable {
    /// The dominant object on a screen. The slowest and largest envelope.
    case heroSurface
    /// A metric that is currently being recorded or streamed.
    case activeMetric
    /// A small badge or dot standing for something happening right now.
    case liveIndicator

    var period: Double {
        switch self {
        case .heroSurface: 5.2
        case .activeMetric: 3.4
        case .liveIndicator: 2.1
        }
    }

    /// Scale swing, as a fraction. Capped well inside the DESIGN.md 2% budget.
    var scaleSwing: CGFloat {
        switch self {
        case .heroSurface: 0.006
        case .activeMetric: 0.011
        case .liveIndicator: 0.018
        }
    }

    var opacitySwing: Double {
        switch self {
        case .heroSurface: 0.03
        case .activeMetric: 0.06
        case .liveIndicator: 0.12
        }
    }
}

/// Bounded, always-on life for a surface that should not read as frozen.
///
/// This is the ambient tier described in DESIGN.md. It deliberately uses a
/// repeating `.animation` rather than a `TimelineView`: the budget allows only
/// one ambient timeline per screen, and that one belongs to the atmosphere.
/// A repeating spring costs nothing per frame when the value is not changing
/// and stops cleanly the moment the policy withdraws it.
private struct AmbientBreath: ViewModifier {
    let role: AmbientRole
    let intensity: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBreathing = false

    private var policy: MotionPolicy {
        MotionPolicy.resolve(
            reduceMotion: reduceMotion,
            reduceTransparency: false,
            sceneIsActive: scenePhase == .active
        )
    }

    func body(content: Content) -> some View {
        // `allowsIdleMotion` already folds in Reduce Motion, Low Power, thermal
        // pressure, scene phase and the Calm comfort profile, so ambient motion
        // inherits every withdrawal rule without restating any of them.
        if policy.allowsIdleMotion == false || intensity <= 0.001 {
            content
        } else {
            content
                .scaleEffect(isBreathing ? 1 + role.scaleSwing * intensity : 1 - role.scaleSwing * intensity)
                .opacity(isBreathing ? 1 : 1 - role.opacitySwing * Double(intensity))
                .animation(
                    .easeInOut(duration: role.period).repeatForever(autoreverses: true),
                    value: isBreathing
                )
                .onAppear { isBreathing = true }
                .onDisappear { isBreathing = false }
        }
    }
}

public extension View {
    /// Gives a surface bounded ambient life so it does not read as a still
    /// image. See the ambient motion budget in DESIGN.md — one ambient timeline
    /// per screen, and never behind body text.
    func lifeBoardAmbientBreath(role: AmbientRole, intensity: CGFloat = 1) -> some View {
        modifier(AmbientBreath(role: role, intensity: intensity))
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
    /// A leftward drag is not an action here, so it gets heavy resistance
    /// immediately rather than tracking the finger.
    private func rubberBanded(_ raw: CGFloat) -> CGFloat {
        guard raw > 0 else { return raw / 4 }
        return RubberBand.offset(raw, limit: threshold, resistance: 0.5)
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
