@preconcurrency import SwiftUI
import UIKit

/// Domain identity for the seven canonical life areas.
///
/// These colors answer "which part of life is this?" and nothing else. They are
/// **never** success, failure, health, urgency, completion, or quality. A life
/// area that is going badly and one that is going well are the same color, which
/// is the whole point: LifeBoard does not score a person's domains.
///
/// Before this vocabulary existed the seven areas carried raw hex strings on
/// `StarterLifeAreaTemplate`, resolved through `HexColor.color(_:fallback:)`.
/// Those were fixed sRGB values with no dark or Increase Contrast variant, so
/// every area rendered identically against the warm-paper canvas and the
/// warm-indigo one — and `#293A18`, the old Health & Self green, sat at roughly
/// 1.3:1 on the dark canvas, which is to say invisible.
public enum LifeAreaAccentRole: String, CaseIterable, Sendable {
    case work
    case home
    case health
    case relationships
    case learning
    case creativity
    case money

    /// Resolves the canonical starter-template identifier to a domain role.
    ///
    /// The identifiers are stable canonical strings rather than a dependency on
    /// the app-side catalog: the tokens package must not import a feature module,
    /// and these seven IDs are part of the persisted record shape, so they change
    /// only through a migration that would have to touch this table anyway.
    ///
    /// A user-created custom area has no role and keeps its own stored hex.
    public init?(lifeAreaTemplateID id: String) {
        switch id {
        case "work-career": self = .work
        case "life-admin": self = .home
        case "health-self": self = .health
        case "relationships": self = .relationships
        case "learning-growth": self = .learning
        case "creativity-fun": self = .creativity
        case "money": self = .money
        default: return nil
        }
    }

    /// The identifying mark. Sized for a node rim, an icon tile, or a narrow
    /// selected accent — the ~10% of an onboarding screen that is not neutral.
    ///
    /// Meets the 3:1 non-text floor against its own appearance's canvas in both
    /// appearances. It is **not** rated for body text and must not carry any.
    public var accent: UIColor {
        Self.adaptive(
            light: lightAccent,
            dark: darkAccent,
            lightHighContrast: lightHighContrastAccent,
            darkHighContrast: darkHighContrastAccent
        )
    }

    /// The same identity at tile strength, for the small glyph plate behind an
    /// area's symbol. Alpha rather than a second hex so it composites correctly
    /// over both clay and the scenic atmosphere.
    public var wash: UIColor {
        Self.adaptive(
            light: lightAccent,
            dark: darkAccent,
            lightAlpha: 0.16,
            darkAlpha: 0.24,
            lightHighContrast: lightHighContrastAccent,
            darkHighContrast: darkHighContrastAccent
        )
    }

    // MARK: - Values

    private var lightAccent: String {
        switch self {
        case .work: "#C68A64"          // muted apricot
        case .home: "#C2A35D"          // warm sand
        case .health: "#7A956D"        // sage
        case .relationships: "#B57C84" // dusty rose
        case .learning: "#7287A8"      // quiet blue
        case .creativity: "#8B7EAF"    // soft lavender
        case .money: "#A68C55"         // restrained ochre
        }
    }

    /// Lifted for the warm-indigo canvas, following the same relationship the
    /// semantic palette already uses (sage `#5D6A4D` light becomes `#9BAA82`).
    private var darkAccent: String {
        switch self {
        case .work: "#D9A582"
        case .home: "#D6BC7E"
        case .health: "#9BB48D"
        case .relationships: "#CF9AA2"
        case .learning: "#94A9C8"
        case .creativity: "#ADA0CE"
        case .money: "#C4AA76"
        }
    }

    private var lightHighContrastAccent: String {
        switch self {
        case .work: "#A96B47"
        case .home: "#A3843F"
        case .health: "#5C7850"
        case .relationships: "#965E66"
        case .learning: "#556A8A"
        case .creativity: "#6D6091"
        case .money: "#876E38"
        }
    }

    private var darkHighContrastAccent: String {
        switch self {
        case .work: "#E8BC9E"
        case .home: "#E6D09A"
        case .health: "#B5CBA7"
        case .relationships: "#E0B4BB"
        case .learning: "#B0C3DE"
        case .creativity: "#C6BBE2"
        case .money: "#DAC392"
        }
    }

    private static func adaptive(
        light: String,
        dark: String,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1,
        lightHighContrast: String,
        darkHighContrast: String
    ) -> UIColor {
        UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            let hex: String = if isDark {
                isHighContrast ? darkHighContrast : dark
            } else {
                isHighContrast ? lightHighContrast : light
            }
            return UIColor(lifeboardHex: hex).withAlphaComponent(isDark ? darkAlpha : lightAlpha)
        }
    }
}

public extension Color {
    /// Domain identity for a life area. Never a status.
    static func lifeboardArea(_ role: LifeAreaAccentRole) -> Color {
        Color(uiColor: role.accent)
    }

    /// Tile-strength domain identity, for the plate behind an area's glyph.
    static func lifeboardAreaWash(_ role: LifeAreaAccentRole) -> Color {
        Color(uiColor: role.wash)
    }
}
