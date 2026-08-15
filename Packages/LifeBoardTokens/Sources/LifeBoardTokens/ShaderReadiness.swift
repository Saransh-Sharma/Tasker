import Foundation

/// The one place any layer can ask "may a Metal effect draw right now?".
///
/// Two facts have to meet before a shader is allowed to render, and until now
/// they lived in two modules that could not see each other:
///
///   1. **Preload finished.** The app target owns the Metal library and warms
///      every stitchable function on launch; nothing may render before that
///      completes, or a missing function degrades into a broken surface rather
///      than into the caller's ordinary transition.
///   2. **Comfort allows it.** The Calm comfort profile drops the Metal layer.
///      `MotionPolicy.allowsCustomShaders` encoded that rule but had **zero
///      production readers**, so Calm suppressed nothing at all.
///
/// `LifeBoardUI` cannot import the app target, which is why the paper-grain
/// modifier in `KnowledgeComposerComponents` was reaching straight for
/// `ShaderFunction(library: .default, …)` with no readiness check. Publishing
/// both facts here gives the package a legal way to ask.
///
/// Deliberately narrower than `MotionPolicy.allowsCustomShaders`: Reduce Motion,
/// Reduce Transparency, scene phase and energy state stay resolved *per
/// modifier*, because several effects owe a different fallback to each. The
/// daypart bloom's tint fade, for example, is reachable **only** under Reduce
/// Motion — folding reduce-motion into a global gate would delete that fallback
/// rather than degrade to it.
/// The observable owner of both facts.
///
/// This exists because the static `ShaderReadiness` facade below could not
/// invalidate SwiftUI. Warm-up runs on a detached task and finishes *after*
/// first render; when it flipped `engineReady`, every view that had already
/// asked `allowsShaderRendering` inside its `body` kept its "not ready" answer
/// forever. Reading a `static var` is not an observation-tracked access, so
/// there was nothing to re-evaluate — which is why shaders appeared to be
/// permanently disabled even with Full Motion on and the flag enabled.
///
/// Views must not read this type directly either. Read
/// `\.lifeBoardShaderReadiness` from the environment: the root modifier
/// performs one tracked read on everyone's behalf and re-publishes, so a single
/// observation drives the whole tree.
@MainActor
@Observable
public final class ShaderReadinessStore {
    public static let shared = ShaderReadinessStore()

    public private(set) var engineReady = false
    public private(set) var comfortPermits = true

    /// Why the engine is unavailable, when it is. Surfaced by the DEBUG motion
    /// diagnostics overlay so "no shaders" can be distinguished from "shaders
    /// suppressed on purpose" without attaching a debugger.
    public private(set) var unavailabilityReason: String?

    public var allowsShaderRendering: Bool { engineReady && comfortPermits }

    public func publishEngineReady(_ isReady: Bool, reason: String? = nil) {
        engineReady = isReady
        unavailabilityReason = isReady ? nil : reason
    }

    public func publishComfort(profile: ComfortProfile) {
        comfortPermits = profile != .calm
    }
}

@MainActor
public enum ShaderReadiness {
    /// The app target's full verdict: every stitchable function materialized,
    /// the signature-shader flag on, not in Low Power Mode, and not thermally
    /// constrained. Starts false — nothing may render before the app says so.
    public static var engineReady: Bool { ShaderReadinessStore.shared.engineReady }

    /// Set by the shell whenever the comfort profile or presentation changes.
    /// Defaults permissive so nothing regresses before the first publish.
    public static var comfortPermits: Bool { ShaderReadinessStore.shared.comfortPermits }

    public static var unavailabilityReason: String? {
        ShaderReadinessStore.shared.unavailabilityReason
    }

    /// The question every effect should actually ask.
    ///
    /// Still a valid read for non-SwiftUI callers and for one-shot checks inside
    /// an already-invalidating body. It does **not** establish observation on
    /// its own — see `ShaderReadinessStore`.
    public static var allowsShaderRendering: Bool {
        ShaderReadinessStore.shared.allowsShaderRendering
    }

    public static func publishEngineReady(_ isReady: Bool, reason: String? = nil) {
        ShaderReadinessStore.shared.publishEngineReady(isReady, reason: reason)
    }

    /// `DESIGN.md`: "Comfort profiles change expression, not capability."
    /// Calm keeps every control and every outcome; it drops the Metal layer.
    ///
    /// Focused presentations are deliberately **not** gated here. They used to be,
    /// which meant every shader in the app went dark whenever a `.focused` route
    /// was on screen — and the routes mapped to `.focused` are Focus Session,
    /// Day Open and Close the Day. Close the Day is the heaviest shader consumer
    /// in the product (paper grain, dissolve away, completion burst, first light,
    /// chart reveal sweep), so none of its five effects had ever rendered.
    ///
    /// What a focused presentation actually owes is *quiet ambience*, not the
    /// absence of commitment effects — a completion burst is the whole point of
    /// closing the day. That suppression lives in `MotionPolicy.allowsIdleMotion`,
    /// which already drives the celestial and star field through
    /// `AtmospherePlacement.suppressesAmbientDetail`.
    public static func publishComfort(profile: ComfortProfile) {
        ShaderReadinessStore.shared.publishComfort(profile: profile)
    }
}
