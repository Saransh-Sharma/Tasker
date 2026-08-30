import SwiftUI

/// The ambient-motion budget, expressed in code.
///
/// `DESIGN.md` states it normatively — "at most **one** ambient timeline per
/// screen", "amplitude **at or below 2%** of the affected element's dimension"
/// — and then nothing in the product expressed either clause. There was no
/// constant, no claim, no lint and no test, in a codebase that had already
/// built exactly that mechanism for the neighbouring rule: hero glass has
/// `\.lifeBoardHeroGlassClaimed`, so a hero nested in a hero silently demotes
/// itself instead of stacking.
///
/// The document is unusually direct about the stakes: "Ambient motion that
/// cannot state its envelope is not ambient motion; it is a distraction, and it
/// does not ship." This is that envelope, stated.
public enum AmbientMotionBudget {
    /// Maximum displacement, as a fraction of the affected element's dimension.
    ///
    /// Ambient motion exists so the product feels alive rather than paused. Past
    /// roughly this amplitude it stops reading as life and starts moving a
    /// reading position or a touch target, which is the line `DESIGN.md` draws.
    public static let maximumAmplitudeFraction: Double = 0.02

    /// Maximum ambient frame rate. Ambient motion has no settled state, so it
    /// runs for as long as the screen is open; it is billed against battery the
    /// whole time.
    public static let maximumFrameRate: Double = 30

    /// Clamp a displacement to the budget.
    ///
    /// Takes the dimension it is relative to, because 2% is meaningless without
    /// one — which is exactly how an "ambient" effect ends up moving 12 points
    /// on a 40-point element.
    public static func clampAmplitude(_ points: Double, of dimension: Double) -> Double {
        let ceiling = abs(dimension) * maximumAmplitudeFraction
        return min(abs(points), ceiling) * (points < 0 ? -1 : 1)
    }
}

private struct AmbientTimelineClaimedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether something above this point in the hierarchy is already running
    /// the screen's one ambient timeline.
    ///
    /// Like the hero claim, this enforces the half that can be enforced: a
    /// nested ambient surface sees the claim and stands down. It cannot settle
    /// *siblings*, because SwiftUI environment flows down and not across — a
    /// screen with two ambient sections side by side has to nominate one where
    /// it is assembled, the same way it nominates its hero.
    var lifeBoardAmbientTimelineClaimed: Bool {
        get { self[AmbientTimelineClaimedKey.self] }
        set { self[AmbientTimelineClaimedKey.self] = newValue }
    }
}

public extension View {
    /// Claim the screen's single ambient timeline for this subtree.
    ///
    /// In debug builds a second claim traps, because the alternative is that it
    /// ships: an extra ambient loop costs battery continuously and is invisible
    /// in review — nothing looks wrong in a screenshot, and the screen still
    /// works.
    func lifeBoardClaimsAmbientTimeline() -> some View {
        modifier(AmbientTimelineClaim())
    }
}

private struct AmbientTimelineClaim: ViewModifier {
    @Environment(\.lifeBoardAmbientTimelineClaimed) private var alreadyClaimed

    func body(content: Content) -> some View {
        content
            .onAppear {
                #if DEBUG
                assert(
                    alreadyClaimed == false,
                    """
                    Two ambient timelines on one screen. DESIGN.md allows one: ambient \
                    surfaces share the screen's timeline, they do not each start their own. \
                    Either nominate a single owner where this screen is assembled, or make \
                    this surface boundary motion instead — boundary motion plays once and \
                    settles, so it is not billed against the budget.
                    """
                )
                #endif
            }
            .environment(\.lifeBoardAmbientTimelineClaimed, true)
    }
}
