import SwiftUI

// The atmosphere's motion budget, split out of `AdaptiveAtmosphere` so the
// view type stays inside the file-size ratchet's per-type ceiling — the
// metric that predicts the `-Onone` launch crash.
extension AdaptiveAtmosphere {
    struct ScenicLayout {
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
    var parallaxOffset: CGFloat {
        guard let scrollObserver, ambientPolicy.allowsIdleMotion, placement.allowsIdleDrift else { return 0 }
        let travel = min(1, max(0, scrollObserver.contentOffset / 420))
        return ambientPolicy.maximumParallax * travel * placement.idleDriftScale
    }

    func pseudoRandom(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return value - floor(value)
    }
}
