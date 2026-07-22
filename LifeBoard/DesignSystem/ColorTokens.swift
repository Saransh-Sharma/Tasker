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

    // Final LifeBoard 5.0 composition roles. These aliases keep feature code
    // semantic while preserving the existing additive token storage contract.
    public var scenicCanvas: UIColor { bgCanvas }
    public var paperPrimary: UIColor { surfacePrimary }
    public var paperRaised: UIColor { bgElevated }
    public var inkPrimary: UIColor { textPrimary }
    public var inkSecondary: UIColor { textSecondary }
    public var hairline: UIColor { strokeHairline }
    public var focusAccent: UIColor { actionFocus }
    public var success: UIColor { statusSuccess }
    public var warning: UIColor { statusWarning }
    public var danger: UIColor { statusDanger }
    public var assistantEvidence: UIColor { accentSecondary }
    public var imageScrim: UIColor { overlayScrim }

    public func color(
        for role: LifeBoardLegibilityRole,
        on surface: LifeBoardSurfaceContext,
        imageLuminance: CGFloat? = nil
    ) -> UIColor {
        if surface == .image || surface == .modalScrim {
            let usesDarkImageInk = surface == .image
                && LifeBoardImageReadabilityPolicy.foregroundStyle(forLuminance: imageLuminance ?? 0.5) == .darkContent
            switch role {
            case .primary, .secondary, .tertiary, .onImage:
                return usesDarkImageInk ? textPrimary : textInverse
            default:
                break
            }
        }

        switch role {
        case .primary:
            return surface == .accent ? accentOnPrimary : textPrimary
        case .secondary:
            return surface == .accent ? accentOnPrimary : textSecondary
        case .tertiary:
            return surface == .accent ? accentOnPrimary : textTertiary
        case .disabled:
            return textDisabled
        case .link:
            return surface == .accent ? accentOnPrimary : accentPrimary
        case .success:
            return statusSuccess
        case .warning:
            return statusWarning
        case .destructive:
            return statusDanger
        case .onAccent:
            return accentOnPrimary
        case .onImage:
            let luminance = imageLuminance ?? 0.5
            return LifeBoardImageReadabilityPolicy.foregroundStyle(forLuminance: luminance) == .darkContent
                ? textPrimary
                : textInverse
        case .focusRing:
            return actionFocus
        }
    }

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

    /// Executes make. The unified Life OS presentation resolves the warm
    /// paper/cocoa system; the legacy sunrise palette remains one release
    /// behind it as the documented rollback.
    public static func make(palette: LifeBoardBrandPalette) -> LifeBoardColorTokens {
        if unifiedPresentationEnabled {
            return makeWarmPaper()
        }
        return makeLegacySunrise(palette: palette)
    }

    /// Mirrors `V2FeatureFlags.lifeOSUnifiedPresentationV2Enabled` storage so
    /// widget and Watch targets — which do not compile the flag service —
    /// resolve the same palette as the app.
    private static var unifiedPresentationEnabled: Bool {
        let key = "feature.life_os.unified_presentation_v2"
        let arguments = ProcessInfo.processInfo.arguments
        let shared = UserDefaults(suiteName: AppGroupConstants.suiteName)
        #if DEBUG
        if arguments.contains("-LIFEBOARD_ENABLE_LIFE_OS_UNIFIED_PRESENTATION_V2") { return true }
        if arguments.contains("-LIFEBOARD_DISABLE_LIFE_OS_UNIFIED_PRESENTATION_V2") { return false }
        if let override = shared?.object(forKey: key) as? Bool
            ?? UserDefaults.standard.object(forKey: key) as? Bool {
            return override
        }
        return true
        #else
        return shared?.object(forKey: key) as? Bool
            ?? UserDefaults.standard.object(forKey: key) as? Bool
            ?? false
        #endif
    }

    /// The canonical LifeBoard 5.0 palette: warm paper canvases, cocoa ink,
    /// sun/apricot/sage accents, and a designed warm-indigo dark treatment.
    /// Saturated color is reserved for semantic status and the one primary
    /// action; violet survives only as the assistant/focus domain color.
    private static func makeWarmPaper() -> LifeBoardColorTokens {
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

        let ink = adaptive(light: "#2B2118", dark: "#F4EBDD")
        let inkSecondary = adaptive(light: "#746757", dark: "#C6BBA8")
        // Darkened from #9B8F7E so tertiary metadata clears 3:1 on the lightest
        // composited clay wells (task-detail chevron/icon surfaces).
        let inkTertiary = adaptive(light: "#877B68", dark: "#96907F")
        let inkQuaternary = adaptive(light: "#B3A791", dark: "#7C7466")
        let sun = adaptive(light: "#F0CD87", dark: "#E7BB7E")
        let apricot = adaptive(light: "#E7BB7E", dark: "#D9A85C")
        let sage = adaptive(light: "#5D6A4D", dark: "#9BAA82")
        let clayWarning = adaptive(light: "#8A6A2F", dark: "#D9A85C")
        let clayDanger = adaptive(light: "#A14E41", dark: "#D98873")
        let slate = adaptive(light: "#68727E", dark: "#A8B4C0")
        let assistantViolet = adaptive(light: "#6842FF", dark: "#A890FF")

        let bgCanvas = adaptive(light: "#FFF7D8", dark: "#151B2D")
        let bgCanvasSecondary = adaptive(light: "#FAF2DA", dark: "#111624")
        let bgElevated = adaptive(light: "#FFFDF7", dark: "#1C2338")

        let surfacePrimary = adaptive(light: "#FFFDF7", dark: "#202741", lightAlpha: 0.96, darkAlpha: 0.92)
        let surfaceSecondary = adaptive(light: "#F5EBCB", dark: "#262E4A", lightAlpha: 0.94, darkAlpha: 0.88)
        let surfaceTertiary = adaptive(light: "#F2E7C2", dark: "#2B2C22", lightAlpha: 0.92, darkAlpha: 0.86)

        // Dark hairline lightened so separators/selection rings clear 1.4:1
        // against the warm-indigo dark surfaces.
        let divider = adaptive(light: "#E9DFC6", dark: "#414A64")
        let strokeHairline = adaptive(light: "#E9DFC6", dark: "#4A5470")
        let strokeStrong = adaptive(light: "#CBBFA4", dark: "#667390")

        // Primary action is cocoa ink on paper; in the dark treatment the
        // action surface flips to warm sun so labels keep 4.5:1 contrast.
        let actionPrimary = adaptive(light: "#2B2118", dark: "#F0CD87")
        let actionPrimaryPressed = adaptive(light: "#4A3A2A", dark: "#E7BB7E")
        let accentMuted = adaptive(light: "#F2E7C2", dark: "#2E3652", lightAlpha: 0.8, darkAlpha: 0.88)
        let accentWash = adaptive(light: "#F5EBCB", dark: "#232B45", lightAlpha: 0.72, darkAlpha: 0.84)
        let accentRing = adaptive(light: "#5A3D1E", dark: "#F0CD87", lightAlpha: 0.42, darkAlpha: 0.46)
        let textInverse = adaptive(light: "#FFFDF7", dark: "#2B2118")

        let overlayScrim = adaptive(light: "#2B2118", dark: "#000000", lightAlpha: 0.16, darkAlpha: 0.52)
        let overlayGlassTint = adaptive(light: "#FFFDF7", dark: "#1C2338", lightAlpha: 0.86, darkAlpha: 0.86)

        return LifeBoardColorTokens(
            bgCanvas: bgCanvas,
            bgCanvasSecondary: bgCanvasSecondary,
            bgElevated: bgElevated,
            surfacePrimary: surfacePrimary,
            surfaceSecondary: surfaceSecondary,
            surfaceTertiary: surfaceTertiary,
            brandPrimary: ink,
            brandSecondary: assistantViolet,
            brandHighlight: sun,
            actionPrimary: actionPrimary,
            actionPrimaryPressed: actionPrimaryPressed,
            actionFocus: accentRing,
            divider: divider,
            strokeHairline: strokeHairline,
            strokeStrong: strokeStrong,
            borderSubtle: divider,
            borderDefault: strokeHairline,
            borderStrong: strokeStrong,
            textPrimary: ink,
            textSecondary: inkSecondary,
            textTertiary: inkTertiary,
            textQuaternary: inkQuaternary,
            textInverse: textInverse,
            textDisabled: inkQuaternary,
            accentPrimary: actionPrimary,
            accentPrimaryPressed: actionPrimaryPressed,
            accentMuted: accentMuted,
            accentWash: accentWash,
            accentOnPrimary: textInverse,
            accentRing: accentRing,
            accentSecondary: sun,
            accentSecondaryPressed: apricot,
            accentSecondaryMuted: adaptive(light: "#F5EBCB", dark: "#332C1B", lightAlpha: 0.92, darkAlpha: 0.86),
            accentSecondaryWash: adaptive(light: "#FAF2DA", dark: "#2B2C22", lightAlpha: 0.84, darkAlpha: 0.82),
            statusSuccess: sage,
            statusWarning: clayWarning,
            statusDanger: clayDanger,
            stateInfo: slate,
            overlayScrim: overlayScrim,
            overlayGlassTint: overlayGlassTint,
            taskCheckboxBorder: inkTertiary,
            taskCheckboxFill: actionPrimary,
            taskOverdue: adaptive(light: "#F6E4DC", dark: "#3A241E"),
            chartPrimary: sage,
            chartSecondary: apricot,
            chipSelectedBackground: adaptive(light: "#F2E7C2", dark: "#2E3652"),
            chipUnselectedBackground: surfaceSecondary,
            priorityMax: clayDanger,
            priorityHigh: adaptive(light: "#B5654F", dark: "#E09A82"),
            priorityLow: sage,
            priorityNone: inkTertiary
        )
    }

    private static func makeLegacySunrise(palette _: LifeBoardBrandPalette) -> LifeBoardColorTokens {
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
