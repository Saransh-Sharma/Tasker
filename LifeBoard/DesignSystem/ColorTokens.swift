import UIKit

public struct LifeBoardColorTokens: LifeBoardTokenGroup, @unchecked Sendable {
    public let bgCanvas: UIColor
    public let bgCanvasSecondary: UIColor
    public let bgElevated: UIColor

    public let surfacePrimary: UIColor
    public let surfaceSecondary: UIColor
    public let surfaceTertiary: UIColor

    public let brandPrimary: UIColor
    public let brandSecondary: UIColor
    public let brandHighlight: UIColor

    public let actionPrimary: UIColor
    public let actionPrimaryPressed: UIColor
    public let actionFocus: UIColor

    public let divider: UIColor
    public let strokeHairline: UIColor
    public let strokeStrong: UIColor
    public let borderSubtle: UIColor
    public let borderDefault: UIColor
    public let borderStrong: UIColor

    public let textPrimary: UIColor
    public let textSecondary: UIColor
    public let textTertiary: UIColor
    public let textQuaternary: UIColor
    public let textInverse: UIColor
    public let textDisabled: UIColor

    public let accentPrimary: UIColor
    public let accentPrimaryPressed: UIColor
    public let accentMuted: UIColor
    public let accentWash: UIColor
    public let accentOnPrimary: UIColor
    public let accentRing: UIColor

    public let accentSecondary: UIColor
    public let accentSecondaryPressed: UIColor
    public let accentSecondaryMuted: UIColor
    public let accentSecondaryWash: UIColor

    public let statusSuccess: UIColor
    public let statusWarning: UIColor
    public let statusDanger: UIColor
    public let stateInfo: UIColor

    public let overlayScrim: UIColor
    public let overlayGlassTint: UIColor

    public let taskCheckboxBorder: UIColor
    public let taskCheckboxFill: UIColor
    public let taskOverdue: UIColor
    public let chartPrimary: UIColor
    public let chartSecondary: UIColor
    public let chipSelectedBackground: UIColor
    public let chipUnselectedBackground: UIColor

    public let priorityMax: UIColor
    public let priorityHigh: UIColor
    public let priorityLow: UIColor
    public let priorityNone: UIColor

    public var primaryAction: UIColor { actionPrimary }
    public var primaryActionPressed: UIColor { actionPrimaryPressed }
    public var primaryActionWash: UIColor { accentWash }
    public var onPrimaryAction: UIColor { accentOnPrimary }
    public var assistantAccent: UIColor { accentSecondary }
    public var assistantAccentWash: UIColor { accentSecondaryWash }
    public var celebrationAccent: UIColor { statusWarning }
    public var warningAccent: UIColor { statusWarning }
    public var dangerAccent: UIColor { statusDanger }
    public var dangerWash: UIColor { taskOverdue.withAlphaComponent(0.14) }
    public var canvas: UIColor { bgCanvas }
    public var canvasSecondary: UIColor { bgCanvasSecondary }
    public var canvasElevated: UIColor { bgElevated }
    public var strokeSubtle: UIColor { borderSubtle }
    public var focusRing: UIColor { actionFocus }
    public var scrim: UIColor { overlayScrim }
    public var glassTint: UIColor { overlayGlassTint }
    public var patternTint: UIColor { accentSecondaryWash }

    /// Executes color.
    public func color(for role: LifeBoardColorRole) -> UIColor {
        switch role {
        case .bgCanvas: return bgCanvas
        case .bgCanvasSecondary: return bgCanvasSecondary
        case .bgElevated: return bgElevated
        case .surfacePrimary: return surfacePrimary
        case .surfaceSecondary: return surfaceSecondary
        case .surfaceTertiary: return surfaceTertiary
        case .brandPrimary: return brandPrimary
        case .brandSecondary: return brandSecondary
        case .brandHighlight: return brandHighlight
        case .actionPrimary: return actionPrimary
        case .actionPrimaryPressed: return actionPrimaryPressed
        case .actionFocus: return actionFocus
        case .borderSubtle: return borderSubtle
        case .borderDefault: return borderDefault
        case .borderStrong: return borderStrong
        case .divider: return divider
        case .strokeHairline: return strokeHairline
        case .strokeStrong: return strokeStrong
        case .textPrimary: return textPrimary
        case .textSecondary: return textSecondary
        case .textTertiary: return textTertiary
        case .textQuaternary: return textQuaternary
        case .textInverse: return textInverse
        case .textDisabled: return textDisabled
        case .accentPrimary: return accentPrimary
        case .accentPrimaryPressed: return accentPrimaryPressed
        case .accentMuted: return accentMuted
        case .accentWash: return accentWash
        case .accentOnPrimary: return accentOnPrimary
        case .accentRing: return accentRing
        case .accentSecondary: return accentSecondary
        case .accentSecondaryPressed: return accentSecondaryPressed
        case .accentSecondaryMuted: return accentSecondaryMuted
        case .accentSecondaryWash: return accentSecondaryWash
        case .statusSuccess: return statusSuccess
        case .statusWarning: return statusWarning
        case .statusDanger: return statusDanger
        case .stateInfo: return stateInfo
        case .overlayScrim: return overlayScrim
        case .overlayGlassTint: return overlayGlassTint
        case .taskCheckboxBorder: return taskCheckboxBorder
        case .taskCheckboxFill: return taskCheckboxFill
        case .taskOverdue: return taskOverdue
        case .chartPrimary: return chartPrimary
        case .chartSecondary: return chartSecondary
        case .chipSelectedBackground: return chipSelectedBackground
        case .chipUnselectedBackground: return chipUnselectedBackground
        case .priorityMax: return priorityMax
        case .priorityHigh: return priorityHigh
        case .priorityLow: return priorityLow
        case .priorityNone: return priorityNone
        }
    }

    /// Executes make.
    public static func make(palette _: LifeBoardBrandPalette) -> LifeBoardColorTokens {
        func adaptive(
            light: String,
            dark: String,
            lightAlpha: CGFloat = 1,
            darkAlpha: CGFloat = 1
        ) -> UIColor {
            UIColor { traits in
                let color = traits.userInterfaceStyle == .dark ? dark : light
                let alpha = traits.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
                return UIColor(lifeboardHex: color).withAlphaComponent(alpha)
            }
        }

        let navy = adaptive(light: "#071B52", dark: "#F7F1E7")
        let navyMuted = adaptive(light: "#48607F", dark: "#C9D2E3")
        let textTertiary = adaptive(light: "#7A8BA5", dark: "#9DAAC2")
        let violet = adaptive(light: "#6842FF", dark: "#A890FF")
        let violetPressed = adaptive(light: "#4F2CFF", dark: "#C3B5FF")
        let violetSoft = adaptive(light: "#EEE9FF", dark: "#29243F")
        let gold = adaptive(light: "#FFB300", dark: "#FFD36A")
        let leaf = adaptive(light: "#28B53F", dark: "#6EE581")
        let sky = adaptive(light: "#2F8CFF", dark: "#78B7FF")
        let coral = adaptive(light: "#FF7A3D", dark: "#FF9A70")
        let rose = adaptive(light: "#F64F95", dark: "#FF89B8")

        let bgCanvas = adaptive(light: "#FFFDFC", dark: "#080C17")
        let bgCanvasSecondary = adaptive(light: "#FFF8EF", dark: "#10101A")
        let bgElevated = adaptive(light: "#F7FBFF", dark: "#111827")

        let surfacePrimary = adaptive(light: "#FFFFFF", dark: "#171C2B", lightAlpha: 0.92, darkAlpha: 0.88)
        let surfaceSecondary = adaptive(light: "#F8FAFF", dark: "#20263A", lightAlpha: 0.90, darkAlpha: 0.84)
        let surfaceTertiary = adaptive(light: "#FFF7DF", dark: "#292414", lightAlpha: 0.82, darkAlpha: 0.80)

        let divider = adaptive(light: "#E7ECF5", dark: "#30384C")
        let strokeHairline = adaptive(light: "#DDE3EE", dark: "#3A4258")
        let strokeStrong = adaptive(light: "#B9C7DC", dark: "#56617B")

        let textPrimary = navy
        let textSecondary = navyMuted
        let textQuaternary = adaptive(light: "#9AA8BA", dark: "#7E8AA2")
        let textInverse = adaptive(light: "#FFFFFF", dark: "#071B52")

        let actionPrimary = violet
        let actionPrimaryPressed = violetPressed
        let accentMuted = adaptive(light: "#EEE9FF", dark: "#29243F", lightAlpha: 0.74, darkAlpha: 0.88)
        let accentWash = adaptive(light: "#F6F2FF", dark: "#231D3B", lightAlpha: 0.82, darkAlpha: 0.84)
        let accentRing = adaptive(light: "#6842FF", dark: "#A890FF", lightAlpha: 0.28, darkAlpha: 0.38)

        let accentSecondary = gold
        let accentSecondaryPressed = adaptive(light: "#D88900", dark: "#FFE0A0")
        let accentSecondaryMuted = adaptive(light: "#FFF7DF", dark: "#332611", lightAlpha: 0.92, darkAlpha: 0.84)
        let accentSecondaryWash = adaptive(light: "#FFF9EC", dark: "#292414", lightAlpha: 0.82, darkAlpha: 0.82)

        let statusSuccess = leaf
        let statusWarning = gold
        let statusDanger = coral
        let stateInfo = sky

        let priorityMax = coral
        let priorityHigh = rose
        let priorityLow = leaf
        let priorityNone = textTertiary

        let overlayScrim = adaptive(light: "#071B52", dark: "#000000", lightAlpha: 0.18, darkAlpha: 0.54)
        let overlayGlassTint = adaptive(light: "#FFFFFF", dark: "#171C2B", lightAlpha: 0.88, darkAlpha: 0.86)

        return LifeBoardColorTokens(
            bgCanvas: bgCanvas,
            bgCanvasSecondary: bgCanvasSecondary,
            bgElevated: bgElevated,
            surfacePrimary: surfacePrimary,
            surfaceSecondary: surfaceSecondary,
            surfaceTertiary: surfaceTertiary,
            brandPrimary: navy,
            brandSecondary: violet,
            brandHighlight: gold,
            actionPrimary: actionPrimary,
            actionPrimaryPressed: actionPrimaryPressed,
            actionFocus: accentRing,
            divider: divider,
            strokeHairline: strokeHairline,
            strokeStrong: strokeStrong,
            borderSubtle: divider,
            borderDefault: strokeHairline,
            borderStrong: strokeStrong,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            textQuaternary: textQuaternary,
            textInverse: textInverse,
            textDisabled: textQuaternary,
            accentPrimary: actionPrimary,
            accentPrimaryPressed: actionPrimaryPressed,
            accentMuted: accentMuted,
            accentWash: accentWash,
            accentOnPrimary: textInverse,
            accentRing: accentRing,
            accentSecondary: accentSecondary,
            accentSecondaryPressed: accentSecondaryPressed,
            accentSecondaryMuted: accentSecondaryMuted,
            accentSecondaryWash: accentSecondaryWash,
            statusSuccess: statusSuccess,
            statusWarning: statusWarning,
            statusDanger: statusDanger,
            stateInfo: stateInfo,
            overlayScrim: overlayScrim,
            overlayGlassTint: overlayGlassTint,
            taskCheckboxBorder: textTertiary,
            taskCheckboxFill: actionPrimary,
            taskOverdue: adaptive(light: "#FFF0E8", dark: "#351F17"),
            chartPrimary: leaf,
            chartSecondary: sky,
            chipSelectedBackground: accentWash,
            chipUnselectedBackground: surfaceSecondary,
            priorityMax: priorityMax,
            priorityHigh: priorityHigh,
            priorityLow: priorityLow,
            priorityNone: priorityNone
        )
    }
}
