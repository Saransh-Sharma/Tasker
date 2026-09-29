import Foundation
import Synchronization
// `canImport(UIKit)` is true on watchOS, but `UIAccessibility` is not — the
// package declares watchOS support, so the guard has to be by platform.
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// The user's in-app motion preference, bounded by the system accessibility
/// setting.
///
/// SwiftUI exposes `\.accessibilityReduceMotion` as a get-only key path, so the
/// app preference is combined with it inside the shared motion policy. Every
/// reduce-motion decision funnels through a small number of token entry points:
///
///   - `MotionPolicy.resolve(reduceMotion:…)`
///   - `LifeBoardAnimation.animationsDisabled(reduceMotion:)`
///   - `MotionProfile.animation(reduceMotion:)`
///   - `InteractionMotion`'s curve factories
///   - each signature effect's `usesFallback`
///
/// System Reduce Motion always wins. The in-app setting may request less motion,
/// but it can never silently restore motion disabled by the operating system.
///
/// Deliberately **not** covered: `LifeBoardAnimation.areProcessAnimationsDisabled`.
/// `-UI_TESTING` and `-DISABLE_ANIMATIONS` must keep suppressing motion whatever
/// this is set to, or the UI test suite becomes timing-dependent.
public enum MotionOverride {
    /// Mirrors `PresentationPreferences.fullMotionEnabled`, published by the
    /// shell. Defaults to the preference's own default so a reader that runs
    /// before the first publish agrees with the rest of the app.
    ///
    private static let fullMotionState = Mutex(true)

    public static var fullMotionEnabled: Bool {
        get { fullMotionState.withLock { $0 } }
        set { fullMotionState.withLock { $0 = newValue } }
    }

    /// The raw system setting, with no override applied.
    @MainActor
    public static var systemReduceMotion: Bool {
        #if canImport(UIKit) && !os(watchOS)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }

    /// Combines the system and app preferences. This is the single rule; every
    /// entry point above defers to it.
    public static func resolve(_ systemReduceMotion: Bool) -> Bool {
        systemReduceMotion || !fullMotionEnabled
    }

    /// What a caller outside both SwiftUI and the policy layer should branch on.
    @MainActor
    public static var effectiveReduceMotion: Bool {
        resolve(systemReduceMotion)
    }
}
