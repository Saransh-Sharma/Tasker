import SwiftUI

public enum AtmospherePlacement: String, CaseIterable, Hashable, Sendable {
    /// `secondary` is the ordinary detail/editor/utility backdrop: quiet, but
    /// still moving. `focusedPresentation` is reserved for surfaces that hold
    /// attention on their own — a focus session, a ritual — and is the only
    /// placement that renders a genuinely still scene.
    case home, plan, track, insights, eva, onboarding, secondary, focusedPresentation

    public static func root(_ destination: Destination) -> Self {
        switch destination {
        case .home: .home
        case .plan: .plan
        case .track: .track
        case .insights: .insights
        case .eva: .eva
        }
    }

    /// Drops the *busy* parts of the scene — the star field, and the celestial's
    /// full scale — so a working or ceremonial surface keeps the eye on itself.
    var suppressesAmbientDetail: Bool {
        self == .onboarding || self == .secondary || self == .focusedPresentation
    }

    /// Whether the scene may still drift.
    ///
    /// This used to be the same flag as `suppressesAmbientDetail`, which meant
    /// every secondary screen and every sheet in the app — everything hosted by
    /// `ScreenScaffold` — rendered a completely frozen backdrop. "Quieter" and
    /// "stopped" are different things, and stopped is what made the app read as
    /// a screenshot of itself. Only genuinely immersive surfaces stop now:
    /// `ScreenMode.focused` and `.critical`, which map to `.focusedPresentation`.
    var allowsIdleDrift: Bool {
        self != .focusedPresentation
    }

    /// Secondary surfaces drift, but at a fraction of a root's amplitude.
    ///
    /// This scales scroll parallax as well as idle drift — `parallaxOffset`
    /// multiplies by it — so it is the single value deciding whether two screens
    /// share a scroll behaviour. The four navigable roots share one.
    var idleDriftScale: CGFloat {
        switch self {
        case .home, .plan, .track, .insights, .onboarding: 1
        case .eva: 0.7
        case .secondary: 0.55
        case .focusedPresentation: 0
        }
    }

    /// How far down the celestial should sit, as a fraction of screen height
    /// added to the descriptor's anchor.
    ///
    /// This used to push every non-home root down, because every non-home root
    /// had a navigation bar in that corner and a full-strength sun behind a
    /// toolbar makes its controls unreadable. That bar is gone: the premium IA
    /// hides the navigation bar on all four roots in favour of the shared
    /// `ScreenRootHeader`, so they now have identical top chrome and can share
    /// one celestial position. The offset is kept for surfaces that still own
    /// something in that corner — Eva's transcript, and the toolbars on
    /// ordinary detail screens.
    var celestialAnchorOffset: Double {
        switch self {
        case .home, .plan, .track, .insights, .onboarding, .focusedPresentation: return 0
        case .eva, .secondary: return 0.14
        }
    }

    /// The roots share one celestial size; Eva and detail screens are working
    /// surfaces where it is atmosphere rather than the subject.
    var celestialScaleMultiplier: Double {
        switch self {
        case .home, .plan, .track, .insights: return 0.76
        case .onboarding, .focusedPresentation: return 1
        case .eva, .secondary: return 0.78
        }
    }
}
