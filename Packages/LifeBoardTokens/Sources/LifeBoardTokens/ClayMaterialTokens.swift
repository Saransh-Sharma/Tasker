import UIKit

// The material layers that make LifeBoard surfaces read as clay and glass
// rather than as tinted rectangles. Extracted from `SemanticColorTokens.swift`
// when the specular rim and hero scrim were added: that file is at the
// file-size ratchet ceiling, and these four are a coherent concern of their
// own rather than more entries in the semantic palette.

/// The two inner layers that make a surface read as clay rather than as a
/// rectangle with a drop shadow. Consumed by `LifeBoardClaySurface` and by the
/// premium-surface highlight in `SwiftUI+TokenAdapters`, which previously
/// hardcoded `.white.opacity(0.34)`.
public extension SemanticColorTokens {
    /// The lit inner rim. Warm white on paper; a restrained lift in the dark
    /// composition, where a bright rim would read as a hard plastic edge.
    static let clayHighlight = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(lifeboardHex: "#B9C6F0", alpha: 0.16)
            : UIColor(lifeboardHex: "#FFFFFF", alpha: 0.9)
    }

    /// The inner contact shade that gives clay its thickness.
    static let clayInnerShade = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(lifeboardHex: "#05070F", alpha: 0.5)
            : UIColor(lifeboardHex: "#6B5130", alpha: 0.13)
    }

    /// The lit edge along a raised surface's upper side.
    ///
    /// Distinct from `clayHighlight`, which is an inner *shadow* spread across
    /// the top of the fill. This is a hairline-width stroke sitting exactly on
    /// the boundary, and it is what separates a soft solid catching light from
    /// a flat tinted rectangle. Weaker in the dark composition, where a bright
    /// edge reads as moulded plastic rather than clay.
    static let claySpecularRim = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(lifeboardHex: "#F8EEDC", alpha: 0.22)
            : UIColor(lifeboardHex: "#FFFDF7", alpha: 0.6)
    }

    /// The veil between the scenic atmosphere and a hero surface's content.
    ///
    /// `DESIGN.md` sizes this by the contrast it must achieve rather than by
    /// taste, so this is the *base* opacity a hero starts from; `HeroSurface`
    /// strengthens it further over bright scenes. Warm paper by day so the
    /// scene reads through as light rather than as fog; deep indigo at night.
    static let heroScrim = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(lifeboardHex: "#151A2A", alpha: 0.58)
            : UIColor(lifeboardHex: "#FFFDF7", alpha: 0.52)
    }
}
