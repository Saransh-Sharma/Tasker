import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The widget palette, retuned from the old Sunrise set (navy ink, #6842FF
/// violet actions, bright leaf/sky) to the app's clay / warm-paper tokens, so
/// a widget sits next to the app and its Live Activities as one product.
///
/// The names are kept so every call site follows without edits; read them as
/// roles, not hues:
/// - `navy*` / `text*` are cocoa inks (`inkPrimary`/`inkSecondary`/`inkTertiary`).
/// - `actionPrimary` is the app's system tint: cocoa in light, warm amber in dark.
/// - `violet*` is reserved for Eva (a muted lunar lavender), never for actions.
/// - `sunriseGold` is the sun accent, deepened in light to clear 3:1 as a ring
///   or bar; `goldInk` is its text twin.
/// - `leaf`/`emerald`/`sky`/`sea` are the sage inks; `peach`/`sandstone`/
///   `magenta` the apricot ink; `red`/`rose` the clay danger.
/// - `canvas*` / `panel` / `glass*` are the paper canvases and clay surfaces.
/// Every value has a dark twin taken from the same tokens (navy paper, warm
/// inks), and a high-contrast twin where the token defines one.
@MainActor
enum WidgetBrand {
    static let navy = adaptive(light: "#2B2118", dark: "#F7F1E7", lightHighContrast: "#1A140E", darkHighContrast: "#FFFFFF")
    static let navySoft = adaptive(light: "#4A3B2C", dark: "#E7DFD1", darkHighContrast: "#FFFFFF")
    static let navyMuted = adaptive(light: "#6F6252", dark: "#C9C3B8", lightHighContrast: "#54493C", darkHighContrast: "#E3DED5")
    /// Eva's accent only.
    static let violet = adaptive(light: "#6B5A86", dark: "#C9BEE0", lightHighContrast: "#524468", darkHighContrast: "#E1D9F0")
    static let violetDeep = adaptive(light: "#4E4166", dark: "#DDD4EE", darkHighContrast: "#F1ECF8")
    static let violetSoft = adaptive(light: "#F1ECF1", dark: "#2A2740", darkHighContrast: "#3A3656")
    static let sunriseGold = adaptive(light: "#A67A1C", dark: "#F0CD87", lightHighContrast: "#7F5C0E", darkHighContrast: "#F8E3B5")
    static let sunriseGoldDeep = adaptive(light: "#7F5C0E", dark: "#F0CD87", lightHighContrast: "#634708", darkHighContrast: "#F8E3B5")
    static let sky = adaptive(light: "#5E6650", dark: "#C9C6BA", lightHighContrast: "#454C3A", darkHighContrast: "#E3E1D8")
    static let sea = adaptive(light: "#4F5A45", dark: "#B9C9C3", darkHighContrast: "#D6E2DE")
    static let leaf = adaptive(light: "#56653F", dark: "#B8C79E", lightHighContrast: "#414D2F", darkHighContrast: "#D3DEC0")
    static let peach = adaptive(light: "#8A5412", dark: "#E7BB7E", lightHighContrast: "#6E420C", darkHighContrast: "#F3D3A6")
    static let rose = adaptive(light: "#A14E41", dark: "#D98873", darkHighContrast: "#F0B4A6")

    static let canvas = adaptive(light: "#FFF7D8", dark: "#151B2D", darkHighContrast: "#0F1422")
    static let canvasWarm = adaptive(light: "#FAF2DA", dark: "#1B2133", darkHighContrast: "#121727")
    static let canvasCool = adaptive(light: "#F5ECC9", dark: "#23273D", darkHighContrast: "#181C2E")
    static let canvasSecondary = adaptive(light: "#FAF2DA", dark: "#1B2133", darkHighContrast: "#121727")
    static let canvasElevated = adaptive(light: "#FDF7E9", dark: "#2F3150", darkHighContrast: "#3A3D5E")
    static let panel = adaptive(light: "#FBF3E2", dark: "#282A44", lightOpacity: 0.92, darkOpacity: 0.90, darkHighContrastOpacity: 0.98)
    static let glass = adaptive(light: "#FBF3E2", dark: "#282A44", lightOpacity: 0.78, darkOpacity: 0.84, darkHighContrastOpacity: 0.96)
    static let glassStrong = adaptive(light: "#FDF7E9", dark: "#2F3150", lightOpacity: 0.94, darkOpacity: 0.92, darkHighContrastOpacity: 0.98)
    static let glassBorder = adaptive(light: "#FFFFFF", dark: "#FFFFFF", lightOpacity: 0.72, darkOpacity: 0.16, darkHighContrastOpacity: 0.30)

    static let line = adaptive(light: "#E9DFC6", dark: "#4D526D", lightHighContrast: "#A89572", darkHighContrast: "#777C9B")
    static let lineStrong = adaptive(light: "#D2BE93", dark: "#6E7490", lightHighContrast: "#8D806E", darkHighContrast: "#8E94AE")

    static let emerald = leaf
    static let magenta = peach
    static let marigold = sunriseGold
    static let red = adaptive(light: "#A14E41", dark: "#D98873", darkHighContrast: "#F0B4A6")
    static let sandstone = peach

    static let actionPrimary = adaptive(light: "#2B2118", dark: "#C0843A", lightHighContrast: "#1A140E", darkHighContrast: "#D1964B")
    static let actionPrimaryPressed = adaptive(light: "#4A3B2C", dark: "#D1964B", darkHighContrast: "#DDA862")
    static let accentQuiet = actionPrimary.opacity(0.12)
    static let accentWash = adaptive(light: "#F8EED0", dark: "#3A3D5E")

    static let textPrimary = navy
    static let textSecondary = navyMuted
    static let textTertiary = adaptive(light: "#8D806E", dark: "#A9A39A", lightHighContrast: "#6F6252", darkHighContrast: "#C9C3B8")
    static let textInverse = adaptive(light: "#FFFDF7", dark: "#151B2D", darkHighContrast: "#0F1422")

    static let warmShadow = adaptive(light: "#6B5130", dark: "#000000", lightOpacity: 0.12, darkOpacity: 0.32)
    static let floatingShadow = adaptive(light: "#6B5130", dark: "#000000", lightOpacity: 0.16, darkOpacity: 0.38)
    static let sunriseHighlight = adaptive(light: "#FFFFFF", dark: "#FFFFFF", lightOpacity: 0.66, darkOpacity: 0.12, darkHighContrastOpacity: 0.22)

    /// Text-safe twins of the sun and sage fills (4.5:1 on every widget canvas).
    static let goldInk = adaptive(light: "#7F5C0E", dark: "#F0CD87", lightHighContrast: "#634708", darkHighContrast: "#F8E3B5")
    static let leafInk = adaptive(light: "#56653F", dark: "#B8C79E", lightHighContrast: "#414D2F", darkHighContrast: "#D3DEC0")

    static func priority(_ code: String) -> Color {
        switch code.uppercased() {
        case "P0":
            return red
        case "P1":
            return peach
        case "P2":
            return goldInk
        case "P3", "P4", "P5":
            return leafInk
        default:
            return textTertiary
        }
    }

    static func role(_ role: WidgetBrandRole) -> WidgetBrandRoleStyle {
        switch role {
        case .task:
            return WidgetBrandRoleStyle(base: leaf, deep: adaptive(light: "#414D2F", dark: "#D3DEC0"), soft: adaptive(light: "#EEEEDF", dark: "#26302A"), border: adaptive(light: "#D8D8C2", dark: "#4A5747"), symbol: "checkmark.square")
        case .meeting:
            return WidgetBrandRoleStyle(base: sky, deep: adaptive(light: "#454C3A", dark: "#E3E1D8"), soft: adaptive(light: "#F1EFE6", dark: "#2A2D3C"), border: adaptive(light: "#DEDBCC", dark: "#4D526D"), symbol: "calendar")
        case .focus:
            return WidgetBrandRoleStyle(base: sunriseGold, deep: sunriseGoldDeep, soft: adaptive(light: "#FBF0D2", dark: "#332A1A"), border: adaptive(light: "#EBD69F", dark: "#6E5A2E"), symbol: "scope")
        case .routine:
            return WidgetBrandRoleStyle(base: sunriseGold, deep: sunriseGoldDeep, soft: adaptive(light: "#FBF0D2", dark: "#332A1A"), border: adaptive(light: "#EBD69F", dark: "#6E5A2E"), symbol: "sun.max")
        case .personal:
            return WidgetBrandRoleStyle(base: peach, deep: adaptive(light: "#6E420C", dark: "#F3D3A6"), soft: adaptive(light: "#F9EBD6", dark: "#35291D"), border: adaptive(light: "#EACFA8", dark: "#6E5337"), symbol: "figure.walk")
        case .assistant:
            return WidgetBrandRoleStyle(base: violet, deep: violetDeep, soft: violetSoft, border: adaptive(light: "#DDD4E4", dark: "#4A4466"), symbol: "sparkles")
        case .warning:
            return WidgetBrandRoleStyle(base: sunriseGoldDeep, deep: adaptive(light: "#634708", dark: "#F8E3B5"), soft: adaptive(light: "#FBF0D2", dark: "#332A1A"), border: adaptive(light: "#EBD69F", dark: "#6E5A2E"), symbol: "exclamationmark.triangle")
        case .neutral:
            return WidgetBrandRoleStyle(base: textTertiary, deep: navyMuted, soft: adaptive(light: "#FBF3E2", dark: "#282A44"), border: line, symbol: "minus")
        }
    }

    static func timelineRole(source: TaskListWidgetTimelineItemSource) -> WidgetBrandRole {
        source == .calendarEvent ? .meeting : .task
    }

    static func adaptive(
        light: String,
        dark: String,
        lightOpacity: Double = 1,
        darkOpacity: Double = 1,
        lightHighContrast: String? = nil,
        darkHighContrast: String? = nil,
        lightHighContrastOpacity: Double? = nil,
        darkHighContrastOpacity: Double? = nil
    ) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            let hex: String
            let opacity: Double
            if isDark {
                hex = isHighContrast ? (darkHighContrast ?? dark) : dark
                opacity = isHighContrast ? (darkHighContrastOpacity ?? darkOpacity) : darkOpacity
            } else {
                hex = isHighContrast ? (lightHighContrast ?? light) : light
                opacity = isHighContrast ? (lightHighContrastOpacity ?? lightOpacity) : lightOpacity
            }
            return UIColor(widgetHex: hex).withAlphaComponent(CGFloat(opacity))
        })
        #else
        return Color(widgetHex: light)?.opacity(lightOpacity) ?? .primary
        #endif
    }
}

enum WidgetBrandRole {
    case task
    case meeting
    case focus
    case routine
    case personal
    case assistant
    case warning
    case neutral
}

struct WidgetBrandRoleStyle {
    let base: Color
    let deep: Color
    let soft: Color
    let border: Color
    let symbol: String
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(widgetHex hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let red = CGFloat((int >> 16) & 0xFF) / 255
        let green = CGFloat((int >> 8) & 0xFF) / 255
        let blue = CGFloat(int & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
#endif
