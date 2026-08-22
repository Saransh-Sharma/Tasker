import LifeBoardTokens
import SwiftUI

public extension View {
    /// The full environment a UIKit-hosted SwiftUI root needs.
    ///
    /// A `UIHostingController` starts a fresh SwiftUI environment: it inherits
    /// nothing from `FoundationShell`, however deeply the presenting view
    /// controller is nested inside it. A host that applies only
    /// `lifeBoardTokenEnvironment(for:)` therefore gets the *default* motion
    /// context and a permanently-false `\.lifeBoardShaderReadiness` — so every
    /// signature effect on that surface takes its fallback branch forever, and
    /// no hero on it can ever resolve to glass.
    ///
    /// Onboarding discovered this and fixed it inline. This is the same fix,
    /// named once, so the next UIKit host does not have to rediscover it: reach
    /// for this rather than `lifeBoardTokenEnvironment(for:)` whenever the root
    /// is handed to a `UIHostingController`.
    @MainActor
    func lifeBoardUIKitHostEnvironment(for layoutClass: LayoutClass) -> some View {
        let preferences = FoundationCoordinator.shared.preferences
        return lifeBoardTokenEnvironment(for: layoutClass)
            .lifeBoardResolvedMotion(
                comfortProfile: preferences.comfortProfile,
                requestedAmbientTierID: preferences.renderingTier.rawValue
            )
    }
}
