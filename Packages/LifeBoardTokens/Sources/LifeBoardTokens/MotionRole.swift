import SwiftUI

// The semantic motion role table and the modifier that applies it. Split out
// of `LifeBoardSignatureEffects`, which stays app-side because it reads
// `V2FeatureFlags`; none of this does.
@MainActor
public extension MotionProfile {
    func animation(reduceMotion: Bool) -> Animation? {
        guard LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false else { return nil }
        return switch self {
        case .press, .micro:
            LifeBoardAnimation.rolePress
        case .selection:
            LifeBoardAnimation.selection
        case .localState:
            LifeBoardAnimation.roleLocalState
        case .contentInsertion:
            LifeBoardAnimation.contentInsertion
        case .controlMorph:
            LifeBoardAnimation.controlMorph
        case .cardReflow:
            LifeBoardAnimation.cardReflow
        case .directManipulation:
            LifeBoardAnimation.directManipulation
        case .route:
            LifeBoardAnimation.roleRoute
        case .celebration:
            LifeBoardAnimation.celebration
        case .deckSettle:
            LifeBoardAnimation.deckSettle
        case .threadAdvance:
            LifeBoardAnimation.threadAdvance
        case .firstLight:
            LifeBoardAnimation.firstLight
        case .ambient:
            LifeBoardAnimation.roleAmbient
        }
    }
}

/// Reads Reduce Motion for the caller and resolves it through the semantic role
/// table, so a feature never spells the accessibility check itself.
///
/// Feature code had been writing `reduceMotion ? nil : LifeBoardAnimation.x`
/// inline. That honours Reduce Motion but not `-UI_TESTING` or
/// `-DISABLE_ANIMATIONS`, so those animations still ran during UI tests and
/// charged every assertion their settle time. Routing through
/// `MotionProfile.animation(reduceMotion:)` picks up
/// `LifeBoardAnimation.animationsDisabled` for free.
private struct MotionRoleModifier<Value: Equatable>: ViewModifier {
    let profile: MotionProfile
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(profile.animation(reduceMotion: reduceMotion), value: value)
    }
}

public extension View {
    /// Animates changes to `value` with the curve for a semantic motion role.
    ///
    /// Prefer this over `.animation(_:value:)` in feature code: it is the only
    /// form that resolves accessibility *and* process animation flags centrally.
    func lifeBoardMotion<Value: Equatable>(
        _ profile: MotionProfile,
        value: Value
    ) -> some View {
        modifier(MotionRoleModifier(profile: profile, value: value))
    }
}
