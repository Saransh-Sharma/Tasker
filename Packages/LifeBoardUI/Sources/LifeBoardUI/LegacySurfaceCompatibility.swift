import LifeBoardTokens
import SwiftUI

// The three surface vocabularies that competed with clay.
//
// `lifeboardPremiumSurface` (25 sites), `lifeboardChromeSurface` (19) and
// `lifeboardDenseSurface` (42) predate `lifeBoardClaySurface` and drew their own
// backgrounds: gradients, hand-rolled top highlights, their own strokes and
// their own elevation. Three of the nine ways this app had to draw a card.
//
// The important part is what `lifeboardPremiumSurface` actually did. Its
// default path called `.glassEffect(.regular, in: shape)` — real Liquid Glass —
// and `lifeboardChromeSurface` routed through the same modifier. So 44 call
// sites were putting glass on ordinary content while reading, at the call site,
// as "premium surface" and "chrome surface". Home alone had eleven, against a
// contract that allows one hero per screen. None of it appeared in a glass
// audit, and the token-law gate could not see it either: the rule bans
// `.glassEffect(` in feature code, and this was a wrapper in the token layer.
//
// `DESIGN.md`: "Never place glass on ordinary rows, prose, charts, Journal
// entries, or assistant messages", and "a screen that reaches for glass a
// second time has stopped having a hero."
//
// These now resolve to clay. They are kept rather than deleted because 86 call
// sites is a merge-conflict machine to rewrite in one pass, and because the
// mapping is not mechanical — each name meant a different plane:
//
//   premium  → raised   (the standard content card)
//   chrome   → well     (it filled with `surfaceSecondary`, the recessed tone)
//   dense    → resting  (a flat fill and a hairline: a list row)
//
// The parameters they no longer use are retained so the call sites still
// compile. Migrate to `lifeBoardClaySurface` directly and drop them.

public extension View {
    @available(*, deprecated, message: "Use lifeBoardClaySurface(.raised, cornerRadius:). This drew Liquid Glass on ordinary content.")
    @MainActor
    func lifeboardPremiumSurface(
        cornerRadius: CGFloat,
        fillColor: Color? = nil,
        strokeColor: Color? = nil,
        accentColor: Color? = nil,
        level: ElevationLevel = .e2,
        useNativeGlass: Bool = true
    ) -> some View {
        _ = (strokeColor, accentColor, level, useNativeGlass)
        return lifeBoardClaySurface(.raised, cornerRadius: cornerRadius, fill: fillColor)
    }

    @available(*, deprecated, message: "Use lifeBoardClaySurface(.well, cornerRadius:). This drew Liquid Glass on ordinary content.")
    @MainActor
    func lifeboardChromeSurface(
        cornerRadius: CGFloat,
        accentColor: Color? = nil,
        level: ElevationLevel = .e1,
        useNativeGlass: Bool = true
    ) -> some View {
        _ = (accentColor, level, useNativeGlass)
        return lifeBoardClaySurface(.well, cornerRadius: cornerRadius)
    }

    @available(*, deprecated, message: "Use lifeBoardClaySurface(.resting, cornerRadius:).")
    @MainActor
    func lifeboardDenseSurface(
        cornerRadius: CGFloat,
        fillColor: Color? = nil,
        strokeColor: Color? = nil,
        lineWidth: CGFloat = 1
    ) -> some View {
        _ = (strokeColor, lineWidth)
        return lifeBoardClaySurface(.resting, cornerRadius: cornerRadius, fill: fillColor)
    }

    @available(*, deprecated, message: "Use lifeBoardClaySurface(.resting, cornerRadius:).")
    @MainActor
    func lifeboardAnalyticsSurface(
        cornerRadius: CGFloat,
        fillColor: Color? = nil,
        strokeColor: Color? = nil,
        accentColor: Color? = nil,
        level: ElevationLevel = .e1
    ) -> some View {
        _ = (strokeColor, accentColor, level)
        return lifeBoardClaySurface(.resting, cornerRadius: cornerRadius, fill: fillColor)
    }
}
