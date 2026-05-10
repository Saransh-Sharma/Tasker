import SwiftUI

enum LBRole: String, CaseIterable {
    case routine
    case task
    case meeting
    case personal
    case focus
    case meal
    case assistant
    case warning
    case error
    case neutral
}

struct LBRoleStyle: Equatable {
    let base: Color
    let deep: Color
    let softSurface: Color
    let border: Color
    let symbolName: String
}

enum LBColorTokens {
    static let navy = Color(lifeboardHex: "#071B52")
    static let navySoft = Color(lifeboardHex: "#203765")
    static let navyMuted = Color(lifeboardHex: "#48607F")
    static let textTertiary = Color(lifeboardHex: "#7A8BA5")
    static let canvas = Color(lifeboardHex: "#FFFDFC")
    static let warmCanvas = Color(lifeboardHex: "#FFF8EF")
    static let coolCanvas = Color(lifeboardHex: "#F7FBFF")
    static let glass = Color.white.opacity(0.90)
    static let glassStrong = Color.white.opacity(0.96)
    static let glassBorder = Color.white.opacity(0.72)
    static let hairline = Color(lifeboardHex: "#DDE3EE")
    static let violet = Color(lifeboardHex: "#6842FF")
    static let violetDeep = Color(lifeboardHex: "#4F2CFF")
    static let violetSoft = Color(lifeboardHex: "#EEE9FF")
    static let sunriseGold = Color(lifeboardHex: "#FFB300")
    static let sky = Color(lifeboardHex: "#2F8CFF")
    static let leaf = Color(lifeboardHex: "#28B53F")
    static let coral = Color(lifeboardHex: "#FF7A3D")
    static let amberSoft = Color(lifeboardHex: "#FFF7DF")
    static let coralSoft = Color(lifeboardHex: "#FFF1E9")

    static func role(_ role: LBRole) -> LBRoleStyle {
        switch role {
        case .routine:
            return LBRoleStyle(base: sunriseGold, deep: Color(lifeboardHex: "#D88900"), softSurface: amberSoft, border: Color(lifeboardHex: "#F6DE9A"), symbolName: "sun.max")
        case .task:
            return LBRoleStyle(base: leaf, deep: Color(lifeboardHex: "#15952B"), softSurface: Color(lifeboardHex: "#EFF9EC"), border: Color(lifeboardHex: "#D6EFD3"), symbolName: "checkmark.square")
        case .meeting:
            return LBRoleStyle(base: violet, deep: Color(lifeboardHex: "#5230F3"), softSurface: Color(lifeboardHex: "#F4F0FF"), border: Color(lifeboardHex: "#E2D8FF"), symbolName: "calendar")
        case .personal:
            return LBRoleStyle(base: coral, deep: Color(lifeboardHex: "#C74716"), softSurface: coralSoft, border: Color(lifeboardHex: "#FFD8C5"), symbolName: "figure.walk")
        case .focus:
            return LBRoleStyle(base: sky, deep: Color(lifeboardHex: "#1266D6"), softSurface: Color(lifeboardHex: "#EAF6FF"), border: Color(lifeboardHex: "#CFE9FF"), symbolName: "sparkles")
        case .meal:
            return LBRoleStyle(base: Color(lifeboardHex: "#F26C35"), deep: Color(lifeboardHex: "#B84312"), softSurface: Color(lifeboardHex: "#FFF0E8"), border: Color(lifeboardHex: "#FFD8C5"), symbolName: "fork.knife")
        case .assistant:
            return LBRoleStyle(base: violet, deep: violetDeep, softSurface: Color(lifeboardHex: "#F6F2FF"), border: Color(lifeboardHex: "#DACDFF"), symbolName: "sparkles")
        case .warning:
            return LBRoleStyle(base: Color(lifeboardHex: "#D88900"), deep: Color(lifeboardHex: "#9B6200"), softSurface: amberSoft, border: Color(lifeboardHex: "#F4E0B8"), symbolName: "exclamationmark.triangle")
        case .error:
            return LBRoleStyle(base: coral, deep: Color(lifeboardHex: "#A83A32"), softSurface: coralSoft, border: Color(lifeboardHex: "#FFD8C5"), symbolName: "exclamationmark.circle")
        case .neutral:
            return LBRoleStyle(base: textTertiary, deep: navyMuted, softSurface: Color(lifeboardHex: "#F8FAFF"), border: hairline, symbolName: "minus")
        }
    }
}

extension Color {
    init(lifeboardHex hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch sanitized.count {
        case 3:
            red = ((int >> 8) & 0xF) * 17
            green = ((int >> 4) & 0xF) * 17
            blue = (int & 0xF) * 17
        default:
            red = (int >> 16) & 0xFF
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
        }
        self.init(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: 1)
    }
}
