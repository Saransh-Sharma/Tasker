import LifeBoardTokens

/// The comfort and readiness gate for every Metal effect in the app.
///
/// Split into its own file rather than added to `SignatureShaders` because that
/// enum is already at the file-size ratchet's per-type ceiling — and because the
/// reasoning below is the kind that gets deleted as "obvious" when it is buried
/// inside a 1,800-line file.
///
/// ## Why the comfort gate is not in `performancePermits`
///
/// `performancePermits` also guards `warmUp()`. Suppressing it under Calm would
/// leave `preloadState` at `.idle` forever, so a later switch to Balanced would
/// find nothing warmed and would never render — the setting would be one-way.
/// Folding the gate into `isReadyForRendering` instead keeps warm-up
/// unconditional and the render decision live.
///
/// ## What is deliberately *not* gated here
///
/// Reduce Motion, Reduce Transparency and scene phase stay resolved per
/// modifier. Several effects owe a different fallback to each, and at least one
/// would be destroyed by a global gate: `DaypartBloomModifier` only reaches its
/// Reduce Motion tint fade if `startDate` was set, and `startDate` is only set
/// when `isReadyForRendering` was true. A global reduce-motion gate would delete
/// that fallback rather than degrade to it.
extension SignatureShaders {
    /// Mirrors this target's verdict into `LifeBoardTokens` so `LifeBoardUI` —
    /// which cannot import the app target — can gate its own effects on the same
    /// fact. Without this, the package's paper grain reached straight for
    /// `ShaderFunction(library: .default, …)` with no readiness check at all.
    static func publishEngineReadiness() {
        ShaderReadiness.publishEngineReady(performancePermits && preloadDidFinish)
    }

    /// Called by the shell when the comfort profile or the active presentation
    /// changes.
    ///
    /// `MotionPolicy.allowsCustomShaders` has encoded exactly this rule since it
    /// was written and had **zero** production readers, so a person who chose
    /// Calm still got every shader, and so did every focus session.
    public static func updateComfort(profile: ComfortProfile, isFocusedPresentation: Bool) {
        ShaderReadiness.publishComfort(
            profile: profile,
            isFocusedPresentation: isFocusedPresentation
        )
    }
}
