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
///   2. **Comfort allows it.** `MotionPolicy.allowsCustomShaders` already folds
///      in the Calm comfort profile and focused presentations — and had **zero
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
@MainActor
public enum ShaderReadiness {
    /// The app target's full verdict: every stitchable function materialized,
    /// the signature-shader flag on, not in Low Power Mode, and not thermally
    /// constrained. Starts false — nothing may render before the app says so.
    public private(set) static var engineReady = false

    /// Set by the shell whenever the comfort profile or presentation changes.
    /// Defaults permissive so nothing regresses before the first publish.
    public private(set) static var comfortPermits = true

    /// The question every effect should actually ask.
    public static var allowsShaderRendering: Bool {
        engineReady && comfortPermits
    }

    public static func publishEngineReady(_ isReady: Bool) {
        engineReady = isReady
    }

    /// `DESIGN.md`: "Comfort profiles change expression, not capability."
    /// Calm keeps every control and every outcome; it drops the Metal layer.
    public static func publishComfort(
        profile: ComfortProfile,
        isFocusedPresentation: Bool
    ) {
        comfortPermits = profile != .calm && isFocusedPresentation == false
    }
}
