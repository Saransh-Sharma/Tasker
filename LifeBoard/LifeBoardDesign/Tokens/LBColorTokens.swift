import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum LBRole: String, CaseIterable {
    case routine
    case windDown
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
    static let navy = adaptive(light: "#071B52", dark: "#F7F1E7", darkHighContrast: "#FFFFFF")
    static let navySoft = adaptive(light: "#203765", dark: "#E7DFD1", darkHighContrast: "#FFFFFF")
    static let navyMuted = adaptive(light: "#48607F", dark: "#C9D2E3", darkHighContrast: "#E4EBF8")
    static let textTertiary = adaptive(light: "#7A8BA5", dark: "#9DAAC2", darkHighContrast: "#C6D0E4")
    static let canvas = adaptive(light: "#FFFDFC", dark: "#080C17", darkHighContrast: "#03050A")
    static let warmCanvas = adaptive(light: "#FFF8EF", dark: "#10101A", darkHighContrast: "#07070D")
    static let coolCanvas = adaptive(light: "#F7FBFF", dark: "#07111E", darkHighContrast: "#030911")
    static let glass = adaptive(light: "#FFFFFF", dark: "#171C2B", lightOpacity: 0.90, darkOpacity: 0.86, darkHighContrast: "#20263A", darkHighContrastOpacity: 0.94)
    static let glassStrong = adaptive(light: "#FFFFFF", dark: "#22283A", lightOpacity: 0.96, darkOpacity: 0.92, darkHighContrast: "#2B3146", darkHighContrastOpacity: 0.98)
    static let glassBorder = adaptive(light: "#FFFFFF", dark: "#FFFFFF", lightOpacity: 0.72, darkOpacity: 0.16, darkHighContrastOpacity: 0.28)
    static let glassDimmingOverlay = adaptive(light: "#000000", dark: "#000000", lightOpacity: 0.05, darkOpacity: 0.12, darkHighContrastOpacity: 0.18)
    static let hairline = adaptive(light: "#DDE3EE", dark: "#3A4258", darkHighContrast: "#56617B")
    static let elevationShadow = adaptive(light: "#071B52", dark: "#000000", lightOpacity: 0.10, darkOpacity: 0.34)
    static let floatingShadow = adaptive(light: "#6842FF", dark: "#000000", lightOpacity: 0.28, darkOpacity: 0.38)
    static let dockShadow = adaptive(light: "#071B52", dark: "#000000", lightOpacity: 0.12, darkOpacity: 0.42)
    static let whiteStroke = adaptive(light: "#FFFFFF", dark: "#FFFFFF", lightOpacity: 0.58, darkOpacity: 0.18, darkHighContrastOpacity: 0.30)
    static let violet = adaptive(light: "#6842FF", dark: "#A890FF", darkHighContrast: "#C3B5FF")
    static let violetDeep = adaptive(light: "#4F2CFF", dark: "#D8CCFF", darkHighContrast: "#F1ECFF")
    static let violetFill = adaptive(light: "#6842FF", dark: "#6F55FF", darkHighContrast: "#846CFF")
    static let violetFillDeep = adaptive(light: "#4F2CFF", dark: "#4F37D9", darkHighContrast: "#674FE8")
    static let violetSoft = adaptive(light: "#EEE9FF", dark: "#29243F", darkHighContrast: "#3A315E")
    static let sunriseGold = Color(lifeboardHex: "#FFB300")
    static let sky = adaptive(light: "#2F8CFF", dark: "#78B7FF", darkHighContrast: "#A8D0FF")
    static let leaf = adaptive(light: "#28B53F", dark: "#6EE581", darkHighContrast: "#95F0A4")
    static let coral = adaptive(light: "#FF7A3D", dark: "#FF9A70", darkHighContrast: "#FFC0A8")
    static let amberSoft = adaptive(light: "#FFF7DF", dark: "#332611", darkHighContrast: "#483618")
    static let coralSoft = adaptive(light: "#FFF1E9", dark: "#3A2018", darkHighContrast: "#522D21")

    static func role(_ role: LBRole) -> LBRoleStyle {
        switch role {
        case .routine:
            return LBRoleStyle(base: sunriseGold, deep: adaptive(light: "#D88900", dark: "#FFD36A"), softSurface: amberSoft, border: adaptive(light: "#F6DE9A", dark: "#7E6425"), symbolName: "sun.max")
        case .windDown:
            return LBRoleStyle(base: adaptive(light: "#E7A900", dark: "#F0C96A"), deep: adaptive(light: "#8F6500", dark: "#F7DD97"), softSurface: adaptive(light: "#FFF9EC", dark: "#292414"), border: adaptive(light: "#F4E0B8", dark: "#69572D"), symbolName: "moon.stars.fill")
        case .task:
            return LBRoleStyle(base: leaf, deep: adaptive(light: "#15952B", dark: "#8AF09A"), softSurface: adaptive(light: "#EFF9EC", dark: "#152819"), border: adaptive(light: "#D6EFD3", dark: "#315F38"), symbolName: "checkmark.square")
        case .meeting:
            return LBRoleStyle(base: violet, deep: adaptive(light: "#5230F3", dark: "#C7B9FF"), softSurface: adaptive(light: "#F4F0FF", dark: "#211B38"), border: adaptive(light: "#E2D8FF", dark: "#4C3D76"), symbolName: "calendar")
        case .personal:
            return LBRoleStyle(base: coral, deep: adaptive(light: "#C74716", dark: "#FFB494"), softSurface: coralSoft, border: adaptive(light: "#FFD8C5", dark: "#7A442F"), symbolName: "figure.walk")
        case .focus:
            return LBRoleStyle(base: sky, deep: adaptive(light: "#1266D6", dark: "#A8D0FF"), softSurface: adaptive(light: "#EAF6FF", dark: "#11283C"), border: adaptive(light: "#CFE9FF", dark: "#315F86"), symbolName: "sparkles")
        case .meal:
            return LBRoleStyle(base: adaptive(light: "#F26C35", dark: "#FF9A70"), deep: adaptive(light: "#B84312", dark: "#FFB99F"), softSurface: adaptive(light: "#FFF0E8", dark: "#351F17"), border: adaptive(light: "#FFD8C5", dark: "#74442E"), symbolName: "fork.knife")
        case .assistant:
            return LBRoleStyle(base: violet, deep: violetDeep, softSurface: adaptive(light: "#F6F2FF", dark: "#231D3B"), border: adaptive(light: "#DACDFF", dark: "#51417E"), symbolName: "sparkles")
        case .warning:
            return LBRoleStyle(base: adaptive(light: "#D88900", dark: "#FFD36A"), deep: adaptive(light: "#9B6200", dark: "#FFE0A0"), softSurface: amberSoft, border: adaptive(light: "#F4E0B8", dark: "#7B622D"), symbolName: "exclamationmark.triangle")
        case .error:
            return LBRoleStyle(base: coral, deep: adaptive(light: "#A83A32", dark: "#FFB7AD"), softSurface: coralSoft, border: adaptive(light: "#FFD8C5", dark: "#80463F"), symbolName: "exclamationmark.circle")
        case .neutral:
            return LBRoleStyle(base: textTertiary, deep: navyMuted, softSurface: adaptive(light: "#F8FAFF", dark: "#171C2B"), border: hairline, symbolName: "minus")
        }
    }

    static func actionGradient(for role: LBRole) -> [Color] {
        switch role {
        case .routine, .windDown, .warning:
            return [
                adaptive(light: "#B87300", dark: "#D58A00"),
                adaptive(light: "#8C5400", dark: "#9E6400")
            ]
        case .task:
            return [
                adaptive(light: "#15952B", dark: "#218A38"),
                adaptive(light: "#0B6F1D", dark: "#11692A")
            ]
        case .meeting, .assistant:
            return [violetFill, violetFillDeep]
        case .personal, .meal, .error:
            return [
                adaptive(light: "#C74716", dark: "#C85B32"),
                adaptive(light: "#A83A32", dark: "#96372F")
            ]
        case .focus:
            return [
                adaptive(light: "#1266D6", dark: "#1F6ECB"),
                adaptive(light: "#0B4FA8", dark: "#134C95")
            ]
        case .neutral:
            return [
                adaptive(light: "#48607F", dark: "#3A4258"),
                adaptive(light: "#203765", dark: "#252D40")
            ]
        }
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
        Color(UIColor { traits in
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
            return UIColor(lifeboardHex: hex).withAlphaComponent(CGFloat(opacity))
        })
        #else
        Color(lifeboardHex: light).opacity(lightOpacity)
        #endif
    }
}

typealias LBSunriseColorTokens = LBColorTokens
typealias LBSunriseTypographyTokens = LBTypographyTokens
typealias LBSunriseSpacingTokens = LBSpacingTokens
typealias LBSunriseRadiusTokens = LBRadiusTokens
typealias LBSunriseElevationTokens = LBShadowTokens
typealias LBSunriseRoleTokens = LBRole

enum LBSunriseMaterialTokens {
    static let glass = LBColorTokens.glass
    static let glassStrong = LBColorTokens.glassStrong
    static let border = LBColorTokens.glassBorder
    static let dimmingOverlay = LBColorTokens.glassDimmingOverlay
}

enum LBSunriseMotionTokens {
    static let responsive = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let gentle = Animation.easeInOut(duration: 0.22)
}

enum LBSunriseHabitTokens {
    static let completed = LBColorTokens.leaf
    static let dueToday = LBColorTokens.violet
    static let skipped = LBColorTokens.coral
    static let bridge = LBColorTokens.sky
    static let noActivity = LBColorTokens.textTertiary
}

typealias SunriseScaffold<Content: View> = SunriseDestinationScaffold<Content>
typealias SunriseScenicHeader<Content: View> = SunriseHeaderView<Content>
typealias SunriseGlassDock = LBBottomDock
typealias SunriseEmptyState = LBEmptyState
typealias SunriseLoadingSkeleton = LBLoadingSkeleton
typealias SunriseTimelineSpine = LBTimelineSpine
typealias SunriseRoleCard = LBTimelineCard

struct SunriseGlassButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        LBPrimaryButton(title: title, systemImage: systemImage, action: action)
    }
}

struct SunriseInlineBanner: View {
    let title: String
    let message: String
    var role: LBRole = .assistant

    var body: some View {
        let style = LBColorTokens.role(role)
        HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
            Image(systemName: style.symbolName)
                .font(.headline)
                .foregroundStyle(style.deep)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(LBTypographyTokens.cardTitle)
                    .foregroundStyle(LBColorTokens.navy)
                Text(message)
                    .font(LBTypographyTokens.body)
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LBSpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.softSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: LBRadiusTokens.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LBRadiusTokens.card, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SunriseUndoSnackbar: View {
    let message: String
    let undoTitle: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: LBSpacingTokens.sm) {
            Text(message)
                .font(LBTypographyTokens.body)
                .foregroundStyle(LBColorTokens.navy)
                .lineLimit(2)
            Spacer(minLength: LBSpacingTokens.xs)
            Button(undoTitle, action: undo)
                .font(LBTypographyTokens.chip)
                .foregroundStyle(LBColorTokens.violetDeep)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, LBSpacingTokens.md)
        .padding(.vertical, LBSpacingTokens.sm)
        .background(LBColorTokens.glassStrong, in: Capsule())
        .overlay(Capsule().stroke(LBColorTokens.glassBorder, lineWidth: 1))
        .shadow(color: LBColorTokens.elevationShadow, radius: 14, y: 7)
    }
}

struct SunriseDecisionDeck<Content: View>: View {
    let progressText: String
    @ViewBuilder let content: Content

    var body: some View {
        LBGlassCard(cornerRadius: LBRadiusTokens.largeCard) {
            VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                Text(progressText)
                    .font(LBTypographyTokens.meta)
                    .foregroundStyle(LBColorTokens.navyMuted)
                content
            }
            .padding(LBSpacingTokens.lg)
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
