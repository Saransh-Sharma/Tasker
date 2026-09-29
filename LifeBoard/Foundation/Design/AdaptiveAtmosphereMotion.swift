import SwiftUI

// The atmosphere's motion budget, split out of `AdaptiveAtmosphere` so the
// view type stays inside the file-size ratchet's per-type ceiling — the
// metric that predicts the `-Onone` launch crash.
extension AdaptiveAtmosphere {
    struct ScenicLayout: Equatable, Sendable {
        let width: CGFloat
        let minX: CGFloat
        var midX: CGFloat { minX + width / 2 }
    }

    func scenicLayout(for size: CGSize) -> ScenicLayout {
        let width = size.width >= 700 ? min(520, size.width) : size.width
        return ScenicLayout(width: width, minX: (size.width - width) / 2)
    }

    var motionPolicy: MotionPolicy {
        _ = powerRevision
        let context = ResolvedMotionContext.resolve(
            systemReduceMotion: reduceMotion || VisualAppearanceFixture.active?.usesReducedMotion == true,
            reduceTransparency: reduceTransparency || VisualAppearanceFixture.active?.usesReducedTransparency == true,
            comfortProfile: comfortProfile,
            requestedAmbientTierID: requestedTier.rawValue,
            sceneIsActive: scenePhase == .active
        )
        return MotionPolicy.resolve(
            reduceMotion: context.effectiveReduceMotion,
            reduceTransparency: context.reduceTransparency,
            lowPowerMode: context.lowPowerMode,
            thermalState: context.thermalState,
            sceneIsActive: scenePhase == .active,
            comfortProfile: comfortProfile,
            // `allowsIdleDrift`, not `suppressesAmbientDetail`: the latter now
            // includes `.secondary`, and feeding that in here would set
            // `allowsIdleMotion == false` and re-freeze every detail screen.
            isFocusedPresentation: placement.allowsIdleDrift == false
        )
    }

    /// How far the celestial travels from its anchor, in points.
    ///
    /// This was 3pt on Balanced over a ~68 second cycle, which is roughly
    /// 0.09pt per second — below the threshold at which a person registers
    /// movement at all. The atmosphere was technically animating and visibly
    /// frozen. These values are sized against the DESIGN.md ambient budget: on
    /// a 402pt-wide screen 20pt is under 2% of the scene's dimension while
    /// still being plainly alive.
    var celestialAmplitude: CGFloat {
        guard motionPolicy.allowsIdleMotion, effectiveTier != .static else { return 0 }
        return switch comfortProfile {
        case .calm: 0
        case .balanced: 12
        case .playful: 20
        }
    }

    /// The ambient tier and parallax budget for this scene.
    var ambientPolicy: AmbientRenderingPolicy {
        _ = powerRevision
        let effectiveReduceMotion = MotionOverride.resolve(
            reduceMotion || VisualAppearanceFixture.active?.usesReducedMotion == true
        )
        return AmbientRenderingPolicy.resolve(
            requestedTier: requestedTier,
            comfortProfile: comfortProfile,
            reduceMotion: effectiveReduceMotion
        )
    }

    var effectiveTier: AmbientRenderingTier { ambientPolicy.effectiveTier }

    /// Scroll-linked depth, in points.
    ///
    /// The shell already tracks root scroll for composer compression, so this
    /// reads the same observer rather than adding a second one. `maximumParallax`
    /// had zero readers in the entire codebase before this — the value was
    /// computed on every resolve and thrown away.
    var sampledParallaxOffset: CGFloat {
        guard let scrollObserver, ambientPolicy.allowsIdleMotion, placement.allowsIdleDrift else { return 0 }
        let travel = min(1, max(0, scrollObserver.sampledParallaxContentOffset / 420))
        return ambientPolicy.maximumParallax * travel * placement.idleDriftScale
    }

    func pseudoRandom(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return value - floor(value)
    }
}

/// Whether anyone is using the app right now, so ambient loops can settle.
///
/// `DESIGN.md` launch contract 7: "a screen runs at most one ambient loop, and
/// it settles when nobody is interacting." The sky's 30 fps timeline used to
/// rebuild the whole scene every frame for as long as Home was on screen —
/// including a phone left face-up on a desk. Now it pauses after
/// `idleInterval` without a touch and resumes on the next one.
///
/// Fed by `SceneDelegate`'s window-level touch observer, which sees every
/// touch without taking part in gesture resolution; the same observer reports
/// whether a full-screen presentation (onboarding) covers the shell, since the
/// sky behind it is invisible.
@MainActor
@Observable
final class AmbientActivityClock {
    static let shared = AmbientActivityClock()

    static let idleInterval: Duration = .seconds(20)

    /// True once nobody has touched the app for `idleInterval`.
    private(set) var isIdle = false
    /// True while a full-screen presentation hides the shell.
    private(set) var isCovered = false

    @ObservationIgnored private var idleTask: Task<Void, Never>?
    @ObservationIgnored private var lastRearm: ContinuousClock.Instant?

    init() {
        rearm()
    }

    /// Ambient decoration may run: someone is here and can see it.
    var allowsAmbientMotion: Bool { isIdle == false && isCovered == false }

    /// Call on any touch. Cheap enough for every `touchesMoved`: the idle
    /// timer is rearmed at most once a second, and observers are invalidated
    /// only on the idle → active transition.
    func noteInteraction() {
        if isIdle { isIdle = false }
        let now = ContinuousClock.now
        if let lastRearm, idleTask != nil, now - lastRearm < .seconds(1) { return }
        rearm()
    }

    func setCovered(_ covered: Bool) {
        guard isCovered != covered else { return }
        isCovered = covered
    }

    private func rearm() {
        lastRearm = ContinuousClock.now
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.idleInterval)
            guard Task.isCancelled == false else { return }
            self?.isIdle = true
        }
    }
}
