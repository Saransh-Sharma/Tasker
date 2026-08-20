import SwiftUI

/// Environment delivery for the resolved motion gates.
///
/// `\.accessibilityReduceMotion` is a get-only `KeyPath`, so the app-level Full
/// Motion override cannot be applied by shadowing it. These are additive keys
/// instead: resolve once at a root, read everywhere below.
///
/// Two keys rather than one because they have different lifetimes. The context
/// changes when accessibility settings, comfort, scene phase, or power state
/// change; shader readiness changes when a detached warm-up task completes. Both
/// need to invalidate the tree, and only the root modifier below establishes the
/// observation that makes the second one work at all.
private struct ResolvedMotionContextKey: EnvironmentKey {
    /// Deliberately reduced-motion by default.
    ///
    /// This cannot consult `UIAccessibility` — `EnvironmentKey.defaultValue` is
    /// nonisolated and that state is MainActor-only — so it has to pick a side
    /// blind. Defaulting to full motion would make a subtree that never got an
    /// injection *ignore* the user's Reduce Motion setting, which is an
    /// accessibility defect and invisible to whoever forgot the modifier.
    /// Defaulting to reduced makes the same mistake show up as "the animations
    /// are missing here", which gets found and fixed.
    ///
    /// `sceneIsActive` stays true so content is never withheld outright; only
    /// motion is.
    static var defaultValue: ResolvedMotionContext {
        ResolvedMotionContext(
            fullMotionEnabled: false,
            effectiveReduceMotion: true,
            reduceTransparency: false,
            comfortProfile: .balanced,
            requestedAmbientTierID: "ambient2D",
            sceneIsActive: true,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }
}

private struct ShaderReadinessKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Every motion gate, already resolved. Prefer this over reading
    /// `\.accessibilityReduceMotion` directly: only this value honours the
    /// app's Full Motion setting.
    var lifeBoardMotionContext: ResolvedMotionContext {
        get { self[ResolvedMotionContextKey.self] }
        set { self[ResolvedMotionContextKey.self] = newValue }
    }

    /// Whether Metal effects may draw right now.
    var lifeBoardShaderReadiness: Bool {
        get { self[ShaderReadinessKey.self] }
        set { self[ShaderReadinessKey.self] = newValue }
    }
}

/// Resolves both values once and injects them into a subtree.
///
/// Apply at the shell root **and** at every `UIHostingController` root. A
/// UIKit-hosted flow does not inherit the shell's environment, so a hosted
/// screen without this modifier gets the defaults above and silently loses
/// Full Motion and shader readiness.
public struct ResolvedMotionRootModifier: ViewModifier {
    private let comfortProfile: ComfortProfile
    private let requestedAmbientTierID: String

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    /// The one observation-tracked read of the readiness store in the app.
    /// Because this modifier reads `readiness.allowsShaderRendering` inside its
    /// own `body`, completing warm-up invalidates *this* modifier, which
    /// re-injects the environment value and invalidates everything below.
    @State private var readiness = ShaderReadinessStore.shared

    /// Power and thermal state arrive as notifications, not as observable
    /// state, so a revision counter is what forces re-resolution.
    @State private var powerRevision = 0

    public init(comfortProfile: ComfortProfile, requestedAmbientTierID: String) {
        self.comfortProfile = comfortProfile
        self.requestedAmbientTierID = requestedAmbientTierID
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.lifeBoardMotionContext, resolvedContext)
            .environment(\.lifeBoardShaderReadiness, readiness.allowsShaderRendering)
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                powerRevision &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
                powerRevision &+= 1
            }
    }

    private var resolvedContext: ResolvedMotionContext {
        _ = powerRevision
        return ResolvedMotionContext.resolve(
            systemReduceMotion: systemReduceMotion || VisualAppearanceFixture.active?.usesReducedMotion == true,
            reduceTransparency: reduceTransparency || VisualAppearanceFixture.active?.usesReducedTransparency == true,
            comfortProfile: comfortProfile,
            requestedAmbientTierID: requestedAmbientTierID,
            sceneIsActive: scenePhase == .active
        )
    }
}

public extension View {
    func lifeBoardResolvedMotion(
        comfortProfile: ComfortProfile,
        requestedAmbientTierID: String
    ) -> some View {
        modifier(ResolvedMotionRootModifier(
            comfortProfile: comfortProfile,
            requestedAmbientTierID: requestedAmbientTierID
        ))
    }
}
