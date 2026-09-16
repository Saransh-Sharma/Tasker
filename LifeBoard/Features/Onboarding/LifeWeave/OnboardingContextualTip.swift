import Foundation
import LifeBoardDomain

/// The one-time cues that replace the five-beat root tour.
///
/// v5 explained Home, Plan, Track, Insights and Eva in five screens at the end
/// of onboarding — which is the moment the user should be receiving the payoff,
/// not memorising five product descriptions for destinations they have not
/// opened. Each of those beats is now a single line that appears the first time
/// the person actually arrives somewhere it could mean something.
///
/// Deliberately **not** a modal, and never on arrival at Home from the reveal:
/// a tutorial that blocks the first screen is the thing this replaces.
enum OnboardingContextualTip: String, CaseIterable, Sendable {
    case home
    case plan
    case track
    case eva

    /// The root that shows it, if any.
    ///
    /// Insights is missing on purpose. It is the one root whose whole job is to
    /// separate a supported conclusion from insufficient evidence, so a tip
    /// explaining it before there is any evidence would be teaching a promise
    /// the screen cannot yet keep.
    init?(destination: Destination) {
        switch destination {
        case .home: self = .home
        case .plan: self = .plan
        case .track: self = .track
        case .eva: self = .eva
        case .insights: return nil
        }
    }

    var title: String {
        switch self {
        case .home: String(localized: "This is Today")
        case .plan: String(localized: "Plan around your day")
        case .track: String(localized: "Track what helps")
        case .eva: String(localized: "Ask EVA")
        }
    }

    var detail: String {
        switch self {
        case .home: String(localized: "Your next thing lives here.")
        case .plan: String(localized: "Drop tasks into open time.")
        case .track: String(localized: "A missed day isn't a failure.")
        case .eva: String(localized: "You approve changes before they happen.")
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .plan: "calendar"
        case .track: "chart.bar"
        case .eva: "sparkles"
        }
    }
}

/// Whether a cue is still owed, persisted per tip.
///
/// Mirrors `PermissionPromptState`'s shape — App Group suite, one namespaced key
/// per subject — so the two "have we already said this?" gates read the same way
/// and can be reset together in tests.
public enum OnboardingContextualTipState {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
    }

    private static func key(_ tip: OnboardingContextualTip) -> String {
        "feature.onboarding.tip.\(tip.rawValue).seen"
    }

    /// Only ever offered to someone who finished onboarding under v6.
    ///
    /// A user who completed the v5 journey already sat through the root tour;
    /// showing them the same four sentences again would be the product
    /// forgetting what it had already told them.
    /// Set when the first run finishes, for the rest of the process.
    ///
    /// Arriving at Home from Ready used to meet a tip about Home in the same
    /// instant — the product explaining itself over the top of the user's own
    /// first thing. The Home tip now waits for a later visit.
    @MainActor private static var suppressedForArrival = false

    @MainActor static func suppressForArrival() {
        suppressedForArrival = true
    }

    @MainActor static func shouldShow(_ tip: OnboardingContextualTip, hasCompletedLifeWeave: Bool) -> Bool {
        guard hasCompletedLifeWeave else { return false }
        if tip == .home, suppressedForArrival { return false }
        return defaults.bool(forKey: key(tip)) == false
    }

    static func markSeen(_ tip: OnboardingContextualTip) {
        defaults.set(true, forKey: key(tip))
    }

    /// Test hook.
    public static func resetAll() {
        for tip in OnboardingContextualTip.allCases {
            defaults.removeObject(forKey: key(tip))
        }
    }
}
