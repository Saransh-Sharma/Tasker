import SwiftUI
import UIKit

public enum DaypartColorRole: String, CaseIterable, Sendable {
    case canvas
    case canvasSecondary
    case celestialPrimary
    case celestialCore
    case layerOne
    case layerTwo
    case coolMist
    case decorativeHighlight
    case foreground
    case foregroundSecondary
}

public struct DaypartPalette: Equatable, Sendable {
    public let canvas: String
    public let canvasSecondary: String
    public let celestialPrimary: String
    public let celestialCore: String
    public let layerOne: String
    public let layerTwo: String
    public let coolMist: String
    public let decorativeHighlight: String
    public let foreground: String
    public let foregroundSecondary: String
    /// Which daypart this palette expresses, and whether it sits on a dark
    /// canvas. Surfaces used to infer this by string-comparing `canvas`
    /// against the night palette, which silently broke the moment a second
    /// dark palette existed.
    public let daypart: ResolvedDaypart
    public let isNocturnal: Bool

    public init(
        canvas: String,
        canvasSecondary: String,
        celestialPrimary: String,
        celestialCore: String,
        layerOne: String,
        layerTwo: String,
        coolMist: String,
        decorativeHighlight: String,
        foreground: String,
        foregroundSecondary: String,
        daypart: ResolvedDaypart = .afternoon,
        isNocturnal: Bool = false
    ) {
        self.canvas = canvas
        self.canvasSecondary = canvasSecondary
        self.celestialPrimary = celestialPrimary
        self.celestialCore = celestialCore
        self.layerOne = layerOne
        self.layerTwo = layerTwo
        self.coolMist = coolMist
        self.decorativeHighlight = decorativeHighlight
        self.foreground = foreground
        self.foregroundSecondary = foregroundSecondary
        self.daypart = daypart
        self.isNocturnal = isNocturnal
    }

    public func hex(for role: DaypartColorRole) -> String {
        switch role {
        case .canvas: return canvas
        case .canvasSecondary: return canvasSecondary
        case .celestialPrimary: return celestialPrimary
        case .celestialCore: return celestialCore
        case .layerOne: return layerOne
        case .layerTwo: return layerTwo
        case .coolMist: return coolMist
        case .decorativeHighlight: return decorativeHighlight
        case .foreground: return foreground
        case .foregroundSecondary: return foregroundSecondary
        }
    }

    public func uiColor(for role: DaypartColorRole) -> UIColor {
        UIColor(lifeboardHex: hex(for: role))
    }

    public func color(for role: DaypartColorRole) -> Color {
        Color(uiColor(for: role))
    }
}

public enum DaypartTokens {
    // MARK: Light appearance
    //
    // The four dayparts must be recognisably different screens. Morning and
    // afternoon previously shared an identical canvas, canvasSecondary,
    // layerOne, coolMist and highlight — they differed only in `celestialCore`,
    // so the adaptive-daypart promise never actually rendered. Morning is now
    // high-key and dewy, afternoon is deeper and more saturated, and evening
    // moves into terracotta and dusty rose.

    /// Pale, fresh, high-key. The screen has not warmed up yet.
    public static let morning = DaypartPalette(
        canvas: "#FFF9E4",
        canvasSecondary: "#FDF4DC",
        celestialPrimary: "#F7D98E",
        celestialCore: "#FAE3A4",
        layerOne: "#FBE3B0",
        layerTwo: "#FFF3D2",
        coolMist: "#CFD8CE",
        decorativeHighlight: "#FFFEFA",
        foreground: "#2B2118",
        foregroundSecondary: "#6F6252",
        daypart: .morning
    )

    /// Deeper, more saturated gold — the day at full strength.
    public static let afternoon = DaypartPalette(
        canvas: "#FFF2C9",
        canvasSecondary: "#FAEBBE",
        celestialPrimary: "#F3C45F",
        celestialCore: "#F0B944",
        layerOne: "#EDBA72",
        layerTwo: "#F8E6B6",
        coolMist: "#C3C9C0",
        decorativeHighlight: "#FFFDF4",
        foreground: "#2B2118",
        foregroundSecondary: "#6F6252",
        daypart: .afternoon
    )

    /// Terracotta and dusty rose as the light goes long.
    public static let evening = DaypartPalette(
        canvas: "#FBEBD6",
        canvasSecondary: "#F6E0C8",
        celestialPrimary: "#EFA95E",
        celestialCore: "#E68F4E",
        layerOne: "#E8A98C",
        layerTwo: "#D89A94",
        coolMist: "#A294A8",
        decorativeHighlight: "#F9D9BE",
        foreground: "#2B2118",
        foregroundSecondary: "#6F6252",
        daypart: .evening
    )

    public static let night = DaypartPalette(
        canvas: "#151B2D",
        canvasSecondary: "#24243B",
        celestialPrimary: "#F3E6C8",
        celestialCore: "#C8B7D5",
        layerOne: "#343754",
        layerTwo: "#4D526D",
        coolMist: "#607C7A",
        decorativeHighlight: "#D8BD7A",
        foreground: "#F7F1E7",
        foregroundSecondary: "#C9C3B8",
        daypart: .night,
        isNocturnal: true
    )

    // MARK: Dark appearance
    //
    // Dark mode used to collapse every daypart onto `night`, so a dark-mode
    // user got the same screen at 7am and 11pm. These keep the dark canvas
    // that dark appearance requires while preserving each daypart's mood in
    // the celestial and layer roles.

    public static let morningDark = DaypartPalette(
        canvas: "#171D2B",
        canvasSecondary: "#1F2637",
        celestialPrimary: "#F2D9A0",
        celestialCore: "#E8C88A",
        layerOne: "#2A3348",
        layerTwo: "#37415A",
        coolMist: "#4A6B6E",
        decorativeHighlight: "#C8B78A",
        foreground: "#F4EBDD",
        foregroundSecondary: "#C6BBA8",
        daypart: .morning,
        isNocturnal: true
    )

    public static let afternoonDark = DaypartPalette(
        canvas: "#1A1E28",
        canvasSecondary: "#232833",
        celestialPrimary: "#F0CD87",
        celestialCore: "#E5B972",
        layerOne: "#33384A",
        layerTwo: "#424860",
        coolMist: "#55707A",
        decorativeHighlight: "#D2BC8C",
        foreground: "#F4EBDD",
        foregroundSecondary: "#C6BBA8",
        daypart: .afternoon,
        isNocturnal: true
    )

    public static let eveningDark = DaypartPalette(
        canvas: "#1E1926",
        canvasSecondary: "#2A2233",
        celestialPrimary: "#E8A063",
        celestialCore: "#D98A5E",
        layerOne: "#3B2E42",
        layerTwo: "#4E3B52",
        coolMist: "#6B5A70",
        decorativeHighlight: "#D9A87E",
        foreground: "#F4EBDD",
        foregroundSecondary: "#C6BBA8",
        daypart: .evening,
        isNocturnal: true
    )

    /// The ambient/art palette for a daypart in light appearance.
    public static func palette(for daypart: ResolvedDaypart) -> DaypartPalette {
        switch daypart {
        case .morning: return morning
        case .afternoon: return afternoon
        case .evening: return evening
        case .night: return night
        }
    }

    /// The ambient/art palette for a daypart in dark appearance.
    public static func darkPalette(for daypart: ResolvedDaypart) -> DaypartPalette {
        switch daypart {
        case .morning: return morningDark
        case .afternoon: return afternoonDark
        case .evening: return eveningDark
        case .night: return night
        }
    }

    /// Daypart selects the celestial mood; system appearance selects functional contrast.
    /// In Light appearance, Night remains recognizably lunar without forcing a dark canvas.
    public static func appearancePalette(
        for daypart: ResolvedDaypart,
        colorScheme: ColorScheme
    ) -> DaypartPalette {
        if colorScheme == .dark { return darkPalette(for: daypart) }
        guard daypart == .night else { return palette(for: daypart) }
        return DaypartPalette(
            canvas: "#FFF7D8",
            canvasSecondary: "#F5ECC9",
            celestialPrimary: night.celestialPrimary,
            celestialCore: night.celestialCore,
            layerOne: "#D8CEE0",
            layerTwo: "#C9C6BA",
            coolMist: "#B9C9C3",
            decorativeHighlight: night.decorativeHighlight,
            foreground: afternoon.foreground,
            foregroundSecondary: afternoon.foregroundSecondary,
            daypart: .night
        )
    }

    public static func functionalPalette(
        for daypart: ResolvedDaypart,
        colorScheme: ColorScheme
    ) -> DaypartPalette {
        appearancePalette(for: daypart, colorScheme: colorScheme)
    }
}

public extension SemanticColorTokens {
    static let foundationCanvas = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#151B2D" : "#FFF7D8")
    }
    /// A quietly lifted background band. The dark value used to be `#24243B`,
    /// byte-identical to `foundationSurfaceSolid`, so any card resting on a soft
    /// canvas in dark appearance was separated from it by nothing but the
    /// hairline.
    static let foundationCanvasSoft = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#1B2133" : "#FAF2DA")
    }
    /// A muted canvas region. The dark value used to be `#343754`, byte-identical
    /// to `foundationSurfaceSelected`, so a selected control sitting on a muted
    /// canvas was invisible. It now also stays below `foundationSurfaceSolid` in
    /// value, because a background must never read as more elevated than a card.
    static let foundationCanvasMuted = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#23273D" : "#F5ECC9")
    }
    /// Carved below the canvas plane: fields, progress tracks, embedded controls.
    /// Deepened in light from `#F5EBCB` so the well still reads as inset now that
    /// `foundationSurfaceSolid` no longer sits at the top of the value range.
    static let foundationSurfaceRecessed = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#20233A" : "#F2E6C4")
    }
    /// Selection. Pulled clear of `foundationSurfaceRecessed` in light — they
    /// were 0.4 of a value step apart, so a selected chip and a plain well
    /// looked identical — and clear of `foundationCanvasMuted` in dark, where
    /// they were the same hex.
    ///
    /// Selection reads *lighter* than the well rather than darker, which is
    /// also what keeps `inkTertiary` above its 3:1 metadata floor here. The
    /// light palette has very little room at that floor: `inkTertiary` clears
    /// it by only 0.10 on `foundationSurfaceRecessed`, so any surface that
    /// darkens breaks legibility before it looks wrong.
    static let foundationSurfaceSelected = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#3A3D5E" : "#F8EED0")
    }
    static let foundationSunAccent = UIColor(lifeboardHex: "#F0CD87")
    /// Cocoa ink is the verified foreground for every celestial/daypart accent,
    /// including the pale lunar lavender used by the dark appearance.
    static let foundationOnCelestialAccent = UIColor(lifeboardHex: "#2B2118")
    // A sunrise gradient rather than the previous peach → pink → lavender ramp,
    // which was the only cool/violet surface in the product and read as a
    // different app sitting on the warm canvas. Contrast against
    // `foundationOnSettingsHero` stays above 10:1 across all three stops.
    static let foundationSettingsHeroStart = UIColor(lifeboardHex: "#F2C6AE")
    static let foundationSettingsHeroMiddle = UIColor(lifeboardHex: "#EFB98F")
    static let foundationSettingsHeroEnd = UIColor(lifeboardHex: "#E9CE94")
    static let foundationOnSettingsHero = UIColor(lifeboardHex: "#2B2118")
    static let foundationApricotAccent = UIColor(lifeboardHex: "#E7BB7E")
    static let foundationSageAccent = UIColor(lifeboardHex: "#C9C6BA")
    /// Overdue and destructive states in foundation surfaces. Same clay values
    /// as `statusDanger` in the instance token set, exposed statically so
    /// foundation views do not have to resolve a token group first.
    static let foundationDanger = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#D98873" : "#A14E41")
    }
    /// Content resting directly on a dark scenic backdrop. Fixed rather than
    /// appearance-aware on purpose: the daypart scene is dark whatever the
    /// system appearance is, so ink that flips with appearance disappears on a
    /// Night scene in Light mode. These are the same warm inks the dark
    /// appearance uses, so contrast is already verified against navy.
    static let foundationOnScenicDark = UIColor(lifeboardHex: "#F7F1E7")
    static let foundationOnScenicDarkSecondary = UIColor(lifeboardHex: "#D3CCC0")
    static let foundationFocusRing = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#F3E6C8" : "#5A3D1E")
    }
    static let inkPrimary = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#F7F1E7" : "#2B2118")
    }
    static let inkSecondary = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#C9C3B8" : "#6F6252")
    }
    static let inkTertiary = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#A9A39A" : "#8D806E")
    }
    /// The body tone of clay.
    ///
    /// The light value was `#FFFDF7` — luminance 0.982, i.e. 98% of maximum. A
    /// surface that close to white has no headroom above it, and the two lit
    /// layers of the clay material both live in that headroom: `clayHighlight`
    /// is an inner shadow toward white, and the specular rim is a `.plusLighter`
    /// stroke whose entire effect is bounded by the distance to white. On
    /// `#FFFDF7` the rim could only ever shift the surface by 3.3 of 255 before
    /// saturating, which is why every "raised clay card" in the app rendered as
    /// a flat white rectangle with a drop shadow and an outline.
    ///
    /// Seated at `#FBF3E2` the same rim moves 15.0 — 4.5× the range — and the
    /// inner highlight moves 13.7 instead of 3. Ink stays at 14.26:1 and
    /// secondary ink at 5.37:1, both far above the 4.5:1 body floor.
    ///
    /// The surface is now marginally *below* the canvas in luminance and differs
    /// from it mostly in hue. That is deliberate and is the claymorphic model:
    /// on a bright cream ground a soft solid reads as raised through its lit
    /// edge and its contact shadow, not by being whiter than the paper.
    static let foundationSurfaceSolid = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#282A44" : "#FBF3E2")
    }

    /// One step nearer the light than `foundationSurfaceSolid`.
    ///
    /// `DESIGN.md` names `surface-raised` and the whole hero/raised-clay chapter
    /// is written against it, but it had no counterpart in code at all. Used for
    /// the floating plane and for the hero's opaque fallback, which must read as
    /// the topmost object on the screen without reaching for glass.
    static let foundationSurfaceRaised = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#2F3150" : "#FDF7E9")
    }
    static let foundationHairline = UIColor { traits in
        let dark = traits.accessibilityContrast == .high ? "#777C9B" : "#4D526D"
        let light = traits.accessibilityContrast == .high ? "#A89572" : "#E9DFC6"
        return UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? dark : light)
    }
    static let metricRingFill = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#F3E6C8" : "#5A3D1E")
    }
    /// The resting track behind a real progress arc. Meaning comes from the
    /// arc, so this stays quiet — but the previous light value (`#F5EBCB`)
    /// measured 1.10:1 against the warm canvas and was simply invisible.
    static let metricRingTrack = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#4D526D" : "#D2BE93")
    }

    /// Used when the track itself carries the message — setup required,
    /// permission required, unavailable. There is no arc to read, so this must
    /// clear the 3:1 floor for meaningful non-text UI against every daypart
    /// canvas in both appearances.
    static let metricRingTrackProminent = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#6E7490" : "#8D806E")
    }
    static let warmMenuGlass = UIColor { traits in
        UIColor(
            lifeboardHex: traits.userInterfaceStyle == .dark ? "#343754" : "#FFF7D8",
            alpha: traits.userInterfaceStyle == .dark ? 0.94 : 0.88
        )
    }
    static let foundationWarmShadow = UIColor { traits in
        UIColor(
            lifeboardHex: traits.userInterfaceStyle == .dark ? "#000000" : "#6B5130",
            alpha: traits.userInterfaceStyle == .dark ? 0.32 : 0.12
        )
    }

    static func daypartPalette(for daypart: ResolvedDaypart) -> DaypartPalette {
        DaypartTokens.palette(for: daypart)
    }
}

public enum Typography {
    /// Greetings and friendly emphasis use SF Rounded; body and data stay on
    /// SF Pro; metrics use monospaced digits at their call sites.
    public static func hero() -> Font { .system(.largeTitle, design: .rounded, weight: .semibold) }
    public static func screenTitle() -> Font { .system(.title, design: .rounded, weight: .semibold) }
    public static func sectionTitle() -> Font { .system(.title2, design: .rounded, weight: .semibold) }
    public static func body() -> Font { .body }
    /// - Warning: Despite the name this is **caption-sized supporting text**,
    ///   not the metric numeral. The numeral token is `TypographyStyle.metric`
    ///   (24 pt bold rounded, scaling to 32), reached through
    ///   `Font.lifeboard(.metric)` or `.lifeboardFont(.metric)`.
    ///
    ///   The two have been confusable since this shim was written, and reaching
    ///   for the wrong one shrinks a screen's largest number to a caption. Kept
    ///   at its current value because ~11 call sites depend on the small size;
    ///   prefer the canonical vocabulary in new code.
    public static func metric() -> Font { .caption.weight(.medium) }
    public static func metadata() -> Font { .caption2 }
}

public enum Radius {
    /// `DESIGN.md` "Shapes": 14 fields and wells, 16 interactive rows, 20 raised
    /// decisions, 24 the hero, 28 sheets, 30 dock and composer, plus the pill.
    ///
    /// Three of these were off that vocabulary entirely. `compact` was 12 and
    /// `largeCard` 22 — values the contract does not contain — and `card`, the
    /// name 54 call sites reach for when they mean "a card", resolved to the
    /// *row* radius. The contract's 20 existed nowhere in the token layer at
    /// all, which is why 136 call sites hardcoded 18 or 22: they were reading
    /// the tokens correctly and the tokens were wrong.
    public static let field: CGFloat = 14
    public static let row: CGFloat = 16
    /// Retained name, corrected value: 16 was the row radius.
    public static let card: CGFloat = 20
    /// Was 22. Folded onto the raised radius rather than deleted, because nine
    /// call sites mean "a card" by it; 24 is reserved for the hero.
    public static let largeCard: CGFloat = 20
    /// Was 12.
    public static let compact: CGFloat = 14
    /// The hero silhouette, shared by the card that represents a surface, the
    /// hero it becomes when opened, and the opaque fallback that replaces it
    /// under reduced transparency. `DESIGN.md`: at this size radius is not a
    /// decorative choice, it is the continuity across the transition.
    public static let hero: CGFloat = 24
    public static let modal: CGFloat = 28
    /// The dock and composer cluster. `RadiusTokens.dock` used to alias `modal`,
    /// so the floating chrome was two points off the contract.
    public static let dock: CGFloat = 30
    public static let pill: CGFloat = 999
}

/// Literal hex values that belong to the token layer rather than to the screens
/// that draw them.
///
/// `scripts/phase1-foundation-guardrails.sh` bans `#RRGGBB` anywhere under
/// `LifeBoard/Foundation` except this file, and it was failing at `HEAD` on nine
/// literals that had accumulated in `LifeBoardAtmosphereRenderer` and
/// `TrackFoundationServices`. The values below are byte-for-byte what those call
/// sites used, so this is a relocation and not a retint — nothing renders
/// differently.
public enum SceneHex {
    /// Flat colours drawn only when a celestial phase's artwork asset is
    /// unavailable. Not a palette: never use these for content or chrome.
    public static let dawnFallback = "#F2D6B6"
    public static let morningFallback = "#F4D9A8"
    public static let middayFallback = "#EDC178"
    public static let goldenHourFallback = "#E7B875"
    public static let twilightFallback = "#B7A5A2"
    public static let nightFallback = "#343545"

    /// The two-tone starfield on twilight and night scenes.
    public static let starCool = "#E7DDF1"
    public static let starWarm = "#FFF3D9"

    /// Apricot, as a string, for the few models that persist a colour as hex
    /// rather than resolving a semantic token at render time.
    public static let apricot = "#E7BB7E"
}
