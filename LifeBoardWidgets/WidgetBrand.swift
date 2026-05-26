import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum WidgetBrand {
    static let navy = adaptive(light: "#071B52", dark: "#F7F1E7", darkHighContrast: "#FFFFFF")
    static let navySoft = adaptive(light: "#203765", dark: "#E7DFD1", darkHighContrast: "#FFFFFF")
    static let navyMuted = adaptive(light: "#48607F", dark: "#C9D2E3", darkHighContrast: "#E4EBF8")
    static let violet = adaptive(light: "#6842FF", dark: "#A890FF", darkHighContrast: "#C3B5FF")
    static let violetDeep = adaptive(light: "#4F2CFF", dark: "#D8CCFF", darkHighContrast: "#F1ECFF")
    static let violetSoft = adaptive(light: "#F6F2FF", dark: "#231D3B", darkHighContrast: "#3A315E")
    static let sunriseGold = adaptive(light: "#FFB300", dark: "#FFD36A", darkHighContrast: "#FFE2A4")
    static let sunriseGoldDeep = adaptive(light: "#D88900", dark: "#FFE0A0", darkHighContrast: "#FFF0C8")
    static let sky = adaptive(light: "#2F8CFF", dark: "#78B7FF", darkHighContrast: "#A8D0FF")
    static let sea = adaptive(light: "#14B8AE", dark: "#75E3DC", darkHighContrast: "#A0F1EC")
    static let leaf = adaptive(light: "#28B53F", dark: "#6EE581", darkHighContrast: "#95F0A4")
    static let peach = adaptive(light: "#FF7A3D", dark: "#FF9A70", darkHighContrast: "#FFC0A8")
    static let rose = adaptive(light: "#F64F95", dark: "#FF93BD", darkHighContrast: "#FFC2D9")

    static let canvas = adaptive(light: "#FFFDFC", dark: "#080C17", darkHighContrast: "#03050A")
    static let canvasWarm = adaptive(light: "#FFF8EF", dark: "#10101A", darkHighContrast: "#07070D")
    static let canvasCool = adaptive(light: "#F7FBFF", dark: "#07111E", darkHighContrast: "#030911")
    static let canvasSecondary = adaptive(light: "#FDF5EA", dark: "#111726", darkHighContrast: "#0B101C")
    static let canvasElevated = adaptive(light: "#FFFDF9", dark: "#171C2B", darkHighContrast: "#20263A")
    static let panel = adaptive(light: "#FFFFFF", dark: "#171C2B", lightOpacity: 0.92, darkOpacity: 0.90, darkHighContrastOpacity: 0.98)
    static let glass = adaptive(light: "#FFFFFF", dark: "#171C2B", lightOpacity: 0.78, darkOpacity: 0.84, darkHighContrastOpacity: 0.96)
    static let glassStrong = adaptive(light: "#FFFFFF", dark: "#22283A", lightOpacity: 0.94, darkOpacity: 0.92, darkHighContrastOpacity: 0.98)
    static let glassBorder = adaptive(light: "#FFFFFF", dark: "#FFFFFF", lightOpacity: 0.72, darkOpacity: 0.16, darkHighContrastOpacity: 0.30)

    static let line = adaptive(light: "#DDE3EE", dark: "#3A4258", darkHighContrast: "#56617B")
    static let lineStrong = adaptive(light: "#C9D2E3", dark: "#56617B", darkHighContrast: "#7B88A4")

    static let emerald = leaf
    static let magenta = violet
    static let marigold = sunriseGold
    static let red = adaptive(light: "#A83A32", dark: "#FFB7AD", darkHighContrast: "#FFD4CF")
    static let sandstone = peach

    static let actionPrimary = violet
    static let actionPrimaryPressed = violetDeep
    static let accentQuiet = violet.opacity(0.16)
    static let accentWash = violetSoft

    static let textPrimary = navy
    static let textSecondary = navyMuted
    static let textTertiary = adaptive(light: "#7A8BA5", dark: "#9DAAC2", darkHighContrast: "#C6D0E4")
    static let textInverse = adaptive(light: "#FFFFFF", dark: "#080C17", darkHighContrast: "#03050A")

    static let warmShadow = adaptive(light: "#071B52", dark: "#000000", lightOpacity: 0.12, darkOpacity: 0.36)
    static let floatingShadow = adaptive(light: "#6842FF", dark: "#000000", lightOpacity: 0.22, darkOpacity: 0.38)
    static let sunriseHighlight = adaptive(light: "#FFFFFF", dark: "#FFFFFF", lightOpacity: 0.66, darkOpacity: 0.12, darkHighContrastOpacity: 0.22)

    static func priority(_ code: String) -> Color {
        switch code.uppercased() {
        case "P0":
            return red
        case "P1":
            return violet
        case "P2":
            return sunriseGoldDeep
        case "P3", "P4", "P5":
            return leaf
        default:
            return textTertiary
        }
    }

    static func role(_ role: WidgetBrandRole) -> WidgetBrandRoleStyle {
        switch role {
        case .task:
            return WidgetBrandRoleStyle(base: leaf, deep: adaptive(light: "#15952B", dark: "#8AF09A"), soft: adaptive(light: "#EFF9EC", dark: "#152819"), border: adaptive(light: "#D6EFD3", dark: "#315F38"), symbol: "checkmark.square")
        case .meeting:
            return WidgetBrandRoleStyle(base: violet, deep: violetDeep, soft: adaptive(light: "#F4F0FF", dark: "#211B38"), border: adaptive(light: "#E2D8FF", dark: "#4C3D76"), symbol: "calendar")
        case .focus:
            return WidgetBrandRoleStyle(base: sky, deep: adaptive(light: "#1266D6", dark: "#A8D0FF"), soft: adaptive(light: "#EAF6FF", dark: "#11283C"), border: adaptive(light: "#CFE9FF", dark: "#315F86"), symbol: "sparkles")
        case .routine:
            return WidgetBrandRoleStyle(base: sunriseGold, deep: sunriseGoldDeep, soft: adaptive(light: "#FFF7DF", dark: "#332611"), border: adaptive(light: "#F6DE9A", dark: "#7E6425"), symbol: "sun.max")
        case .personal:
            return WidgetBrandRoleStyle(base: peach, deep: adaptive(light: "#C74716", dark: "#FFB494"), soft: adaptive(light: "#FFF1E9", dark: "#3A2018"), border: adaptive(light: "#FFD8C5", dark: "#7A442F"), symbol: "figure.walk")
        case .assistant:
            return WidgetBrandRoleStyle(base: violet, deep: violetDeep, soft: violetSoft, border: adaptive(light: "#DACDFF", dark: "#51417E"), symbol: "sparkles")
        case .warning:
            return WidgetBrandRoleStyle(base: sunriseGoldDeep, deep: adaptive(light: "#9B6200", dark: "#FFE0A0"), soft: adaptive(light: "#FFF7DF", dark: "#332611"), border: adaptive(light: "#F4E0B8", dark: "#7B622D"), symbol: "exclamationmark.triangle")
        case .neutral:
            return WidgetBrandRoleStyle(base: textTertiary, deep: navyMuted, soft: adaptive(light: "#F8FAFF", dark: "#171C2B"), border: line, symbol: "minus")
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
