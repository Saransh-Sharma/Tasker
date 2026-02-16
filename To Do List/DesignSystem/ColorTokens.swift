import UIKit

public struct TaskerColorTokens: TaskerTokenGroup {
    public let bgCanvas: UIColor
    public let bgElevated: UIColor

    public let surfacePrimary: UIColor
    public let surfaceSecondary: UIColor
    public let surfaceTertiary: UIColor

    public let divider: UIColor
    public let strokeHairline: UIColor
    public let strokeStrong: UIColor

    public let textPrimary: UIColor
    public let textSecondary: UIColor
    public let textTertiary: UIColor
    public let textQuaternary: UIColor
    public let textInverse: UIColor

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

    public func color(for role: TaskerColorRole) -> UIColor {
        switch role {
        case .bgCanvas: return bgCanvas
        case .bgElevated: return bgElevated
        case .surfacePrimary: return surfacePrimary
        case .surfaceSecondary: return surfaceSecondary
        case .surfaceTertiary: return surfaceTertiary
        case .divider: return divider
        case .strokeHairline: return strokeHairline
        case .strokeStrong: return strokeStrong
        case .textPrimary: return textPrimary
        case .textSecondary: return textSecondary
        case .textTertiary: return textTertiary
        case .textQuaternary: return textQuaternary
        case .textInverse: return textInverse
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

    public static func make(accentRamp: TaskerAccentRamp, secondaryRamp: TaskerAccentRamp) -> TaskerColorTokens {
        // Premium "Obsidian & Gems" palette — warm undertones throughout
        let bgCanvas = UIColor.taskerDynamic(lightHex: "#FAF8F5", darkHex: "#0F0E0C")
        let bgElevated = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#171513")

        let surfacePrimary = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#1D1B18")
        let surfaceSecondary = UIColor.taskerDynamic(lightHex: "#F5F2EE", darkHex: "#252320")
        let surfaceTertiary = UIColor.taskerDynamic(lightHex: "#EDE9E3", darkHex: "#2E2B27")

        let divider = UIColor.taskerDynamic(lightHex: "#E8E2DA", darkHex: "#363230")
        let strokeHairline = UIColor.taskerDynamic(lightHex: "#E8E2DA", darkHex: "#363230")
        let strokeStrong = UIColor.taskerDynamic(lightHex: "#D4CCC2", darkHex: "#443F3A")

        let textPrimary = UIColor.taskerDynamic(lightHex: "#1A1714", darkHex: "#F5F0EB")
        let textSecondary = UIColor.taskerDynamic(lightHex: "#6B6259", darkHex: "#C9C1B8")
        let textTertiary = UIColor.taskerDynamic(lightHex: "#9C9389", darkHex: "#9A9188")
        let textQuaternary = UIColor.taskerDynamic(lightHex: "#B8B0A6", darkHex: "#6B6359")
        let textInverse = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#0F0E0C")

        // Dark-luxe status colors
        let statusSuccess = UIColor(taskerHex: "#38C8A8")  // Jade Teal
        let statusWarning = UIColor(taskerHex: "#E8A040")  // Warm Amber
        let statusDanger = UIColor(taskerHex: "#E05058")   // Scarlet Garnet

        // "Four Jewels" priority colors — ~90° apart on color wheel for max distinction on tiny pie charts
        let priorityMax  = UIColor(taskerHex: "#E05058")  // Scarlet Garnet  (~358°)
        let priorityHigh = UIColor(taskerHex: "#7C68D8")  // Imperial Violet (~248°)
        let priorityLow  = UIColor(taskerHex: "#38C8A8")  // Jade Teal       (~168°)
        let priorityNone = UIColor(taskerHex: "#B09080")  // Antique Bronze  (~20°)

        let overlayScrim = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.black.withAlphaComponent(0.50)
            }
            return UIColor(taskerHex: "#1A1714").withAlphaComponent(0.22)
        }

        let overlayGlassTint = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(taskerHex: "#171513").withAlphaComponent(0.72)
            }
            return UIColor(taskerHex: "#FAF8F5").withAlphaComponent(0.74)
        }

        return TaskerColorTokens(
            bgCanvas: bgCanvas,
            bgElevated: bgElevated,
            surfacePrimary: surfacePrimary,
            surfaceSecondary: surfaceSecondary,
            surfaceTertiary: surfaceTertiary,
            divider: divider,
            strokeHairline: strokeHairline,
            strokeStrong: strokeStrong,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            textQuaternary: textQuaternary,
            textInverse: textInverse,
            accentPrimary: accentRamp.accent500,
            accentPrimaryPressed: accentRamp.accent600,
            accentMuted: accentRamp.accent100,
            accentWash: accentRamp.accent050,
            accentOnPrimary: accentRamp.onAccent,
            accentRing: accentRamp.ring,
            accentSecondary: secondaryRamp.accent500,
            accentSecondaryPressed: secondaryRamp.accent600,
            accentSecondaryMuted: secondaryRamp.accent100,
            accentSecondaryWash: secondaryRamp.accent050,
            statusSuccess: statusSuccess,
            statusWarning: statusWarning,
            statusDanger: statusDanger,
            overlayScrim: overlayScrim,
            overlayGlassTint: overlayGlassTint,
            taskCheckboxBorder: strokeStrong,
            taskCheckboxFill: accentRamp.accent500,
            taskOverdue: UIColor(taskerHex: "#D43860"),  // Blood Rose — distinct from danger
            chartPrimary: accentRamp.accent500,
            chartSecondary: secondaryRamp.accent500,
            chipSelectedBackground: accentRamp.accent500,
            chipUnselectedBackground: surfaceSecondary,
            priorityMax: priorityMax,
            priorityHigh: priorityHigh,
            priorityLow: priorityLow,
            priorityNone: priorityNone
        )
    }
}
