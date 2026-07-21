import SwiftUI
import UIKit

public enum LifeBoardDaypartColorRole: String, CaseIterable, Sendable {
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

public struct LifeBoardDaypartPalette: Equatable, Sendable {
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

    public func hex(for role: LifeBoardDaypartColorRole) -> String {
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

    public func uiColor(for role: LifeBoardDaypartColorRole) -> UIColor {
        UIColor(lifeboardHex: hex(for: role))
    }

    public func color(for role: LifeBoardDaypartColorRole) -> Color {
        Color(uiColor(for: role))
    }
}

public enum LifeBoardDaypartTokens {
    public static let morning = LifeBoardDaypartPalette(
        canvas: "#FFF7D8",
        canvasSecondary: "#FAF2DA",
        celestialPrimary: "#F0CD87",
        celestialCore: "#F4D277",
        layerOne: "#E7BB7E",
        layerTwo: "#F5EBCB",
        coolMist: "#C9C6BA",
        decorativeHighlight: "#FFFDF7",
        foreground: "#2B2118",
        foregroundSecondary: "#746757"
    )

    public static let afternoon = LifeBoardDaypartPalette(
        canvas: "#FFF7D8",
        canvasSecondary: "#FAF2DA",
        celestialPrimary: "#F0CD87",
        celestialCore: "#F3C966",
        layerOne: "#E7BB7E",
        layerTwo: "#F2E7C2",
        coolMist: "#C9C6BA",
        decorativeHighlight: "#FFFDF7",
        foreground: "#2B2118",
        foregroundSecondary: "#746757"
    )

    public static let evening = LifeBoardDaypartPalette(
        canvas: "#FAF2DA",
        canvasSecondary: "#F5ECC9",
        celestialPrimary: "#EFAF63",
        celestialCore: "#E69A58",
        layerOne: "#E9B08F",
        layerTwo: "#C98F8D",
        coolMist: "#9D92A8",
        decorativeHighlight: "#F8D7BC",
        foreground: "#2B2118",
        foregroundSecondary: "#746757"
    )

    public static let night = LifeBoardDaypartPalette(
        canvas: "#151B2D",
        canvasSecondary: "#24243B",
        celestialPrimary: "#F3E6C8",
        celestialCore: "#C8B7D5",
        layerOne: "#343754",
        layerTwo: "#4D526D",
        coolMist: "#607C7A",
        decorativeHighlight: "#D8BD7A",
        foreground: "#F7F1E7",
        foregroundSecondary: "#C9C3B8"
    )

    public static func palette(for daypart: ResolvedDaypart) -> LifeBoardDaypartPalette {
        switch daypart {
        case .morning: return morning
        case .afternoon: return afternoon
        case .evening: return evening
        case .night: return night
        }
    }

    /// Daypart selects the celestial mood; system appearance selects functional contrast.
    /// In Light appearance, Night remains recognizably lunar without forcing a dark canvas.
    public static func appearancePalette(
        for daypart: ResolvedDaypart,
        colorScheme: ColorScheme
    ) -> LifeBoardDaypartPalette {
        guard daypart == .night, colorScheme == .light else { return palette(for: daypart) }
        return LifeBoardDaypartPalette(
            canvas: "#FFF7D8",
            canvasSecondary: "#F5ECC9",
            celestialPrimary: night.celestialPrimary,
            celestialCore: night.celestialCore,
            layerOne: "#D8CEE0",
            layerTwo: "#C9C6BA",
            coolMist: "#B9C9C3",
            decorativeHighlight: night.decorativeHighlight,
            foreground: afternoon.foreground,
            foregroundSecondary: afternoon.foregroundSecondary
        )
    }

    public static func functionalPalette(
        for daypart: ResolvedDaypart,
        colorScheme: ColorScheme
    ) -> LifeBoardDaypartPalette {
        colorScheme == .dark ? night : appearancePalette(for: daypart, colorScheme: .light)
    }
}

public extension LifeBoardColorTokens {
    static let foundationCanvas = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#151B2D" : "#FFF7D8")
    }
    static let foundationCanvasSoft = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#24243B" : "#FAF2DA")
    }
    static let foundationCanvasMuted = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#343754" : "#F5ECC9")
    }
    static let foundationSurfaceRecessed = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#20233A" : "#F5EBCB")
    }
    static let foundationSurfaceSelected = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#343754" : "#F2E7C2")
    }
    static let foundationSunAccent = UIColor(lifeboardHex: "#F0CD87")
    static let foundationApricotAccent = UIColor(lifeboardHex: "#E7BB7E")
    static let foundationSageAccent = UIColor(lifeboardHex: "#C9C6BA")
    static let foundationFocusRing = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#F3E6C8" : "#5A3D1E")
    }
    static let inkPrimary = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#F7F1E7" : "#2B2118")
    }
    static let inkSecondary = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#C9C3B8" : "#746757")
    }
    static let inkTertiary = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#A9A39A" : "#8D806E")
    }
    static let foundationSurfaceSolid = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#24243B" : "#FFFDF7")
    }
    static let foundationHairline = UIColor { traits in
        let dark = traits.accessibilityContrast == .high ? "#777C9B" : "#4D526D"
        let light = traits.accessibilityContrast == .high ? "#A89572" : "#E9DFC6"
        return UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? dark : light)
    }
    static let metricRingFill = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#F3E6C8" : "#5A3D1E")
    }
    static let metricRingTrack = UIColor { traits in
        UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? "#4D526D" : "#F5EBCB")
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

    static func daypartPalette(for daypart: ResolvedDaypart) -> LifeBoardDaypartPalette {
        LifeBoardDaypartTokens.palette(for: daypart)
    }
}

public enum LifeBoardFoundationTypography {
    /// Greetings and friendly emphasis use SF Rounded; body and data stay on
    /// SF Pro; metrics use monospaced digits at their call sites.
    public static func hero() -> Font { .system(.largeTitle, design: .rounded, weight: .semibold) }
    public static func screenTitle() -> Font { .system(.title, design: .rounded, weight: .semibold) }
    public static func sectionTitle() -> Font { .system(.title2, design: .rounded, weight: .semibold) }
    public static func body() -> Font { .body }
    public static func metric() -> Font { .caption.weight(.medium) }
    public static func metadata() -> Font { .caption2 }
}

public enum LifeBoardFoundationRadius {
    public static let compact: CGFloat = 12
    public static let card: CGFloat = 16
    public static let largeCard: CGFloat = 22
    public static let modal: CGFloat = 28
    public static let pill: CGFloat = 999
}
