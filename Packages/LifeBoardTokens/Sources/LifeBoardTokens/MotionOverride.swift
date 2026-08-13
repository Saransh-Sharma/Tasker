import Foundation
// `canImport(UIKit)` is true on watchOS, but `UIAccessibility` is not — the
// package declares watchOS support, so the guard has to be by platform.
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// The user's "Full motion" choice: a deliberate, in-app override of the system
/// Reduce Motion setting.
///
/// ## Why an override rather than deleting the gates
///
/// Roughly 541 sites in this codebase branch on Reduce Motion. Deleting those
/// branches would be an irreversible accessibility regression spread across the
/// whole app; this keeps the accessibility path intact and one toggle away.
///
/// The obvious implementation — injecting `\.accessibilityReduceMotion` once at
/// the shell root — is not available: SwiftUI exposes that key as a get-only
/// `KeyPath`, not a `WritableKeyPath`. So the override is applied one layer
/// lower instead, inside the motion policy itself. Every reduce-motion decision
/// in the app already funnels through a small number of token entry points:
///
///   - `MotionPolicy.resolve(reduceMotion:…)`
///   - `LifeBoardAnimation.animationsDisabled(reduceMotion:)`
///   - `MotionProfile.animation(reduceMotion:)`
///   - `InteractionMotion`'s curve factories
///   - each signature effect's `usesFallback`
///
/// Applying `resolve(_:)` at those points covers the feature layer without
/// touching a single feature file, and puts the rule where it can be tested.
///
/// Deliberately **not** covered: `LifeBoardAnimation.areProcessAnimationsDisabled`.
/// `-UI_TESTING` and `-DISABLE_ANIMATIONS` must keep suppressing motion whatever
/// this is set to, or the UI test suite becomes timing-dependent.
public enum MotionOverride {
    /// Mirrors `PresentationPreferences.fullMotionEnabled`, published by the
    /// shell. Defaults to the preference's own default so a reader that runs
    /// before the first publish agrees with the rest of the app.
    ///
    /// `nonisolated(unsafe)`: written once from the main actor on preference
    /// change, read from the nonisolated policy layer. A torn read of a `Bool`
    /// is not possible, and a one-frame-stale value only affects presentation.
    nonisolated(unsafe) public static var fullMotionEnabled = true

    /// The raw system setting, with no override applied.
    @MainActor
    public static var systemReduceMotion: Bool {
        #if canImport(UIKit) && !os(watchOS)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }

    /// Applies the override to a system Reduce Motion value. This is the single
    /// rule; every entry point above defers to it.
    public static func resolve(_ systemReduceMotion: Bool) -> Bool {
        fullMotionEnabled ? false : systemReduceMotion
    }

    /// What a caller outside both SwiftUI and the policy layer should branch on.
    @MainActor
    public static var effectiveReduceMotion: Bool {
        resolve(systemReduceMotion)
    }
}
