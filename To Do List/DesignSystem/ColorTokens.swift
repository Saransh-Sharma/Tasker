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

    public let statusSuccess: UIColor
    public let statusWarning: UIColor
    public let statusDanger: UIColor

    public let overlayScrim: UIColor
    public let overlayGlassTint: UIColor

    public let taskCheckboxBorder: UIColor
    public let taskCheckboxFill: UIColor
    public let taskOverdue: UIColor
    public let chartPrimary: UIColor
    public let chipSelectedBackground: UIColor
    public let chipUnselectedBackground: UIColor

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
        case .statusSuccess: return statusSuccess
        case .statusWarning: return statusWarning
        case .statusDanger: return statusDanger
        case .overlayScrim: return overlayScrim
        case .overlayGlassTint: return overlayGlassTint
        case .taskCheckboxBorder: return taskCheckboxBorder
        case .taskCheckboxFill: return taskCheckboxFill
        case .taskOverdue: return taskOverdue
        case .chartPrimary: return chartPrimary
        case .chipSelectedBackground: return chipSelectedBackground
        case .chipUnselectedBackground: return chipUnselectedBackground
        }
    }

    public static func make(accentRamp: TaskerAccentRamp) -> TaskerColorTokens {
        let bgCanvas = UIColor.taskerDynamic(lightHex: "#F6F7F9", darkHex: "#0E0F12")
        let bgElevated = UIColor.taskerDynamic(lightHex: "#FBFCFD", darkHex: "#14161B")

        let surfacePrimary = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#181B21")
        let surfaceSecondary = UIColor.taskerDynamic(lightHex: "#F2F3F6", darkHex: "#20242C")
        let surfaceTertiary = UIColor.taskerDynamic(lightHex: "#ECEEF2", darkHex: "#262B35")

        let divider = UIColor.taskerDynamic(lightHex: "#E4E7ED", darkHex: "#2A2F3A")
        let strokeHairline = UIColor.taskerDynamic(lightHex: "#E4E7ED", darkHex: "#2A2F3A")
        let strokeStrong = UIColor.taskerDynamic(lightHex: "#D7DBE3", darkHex: "#323847")

        let textPrimary = UIColor.taskerDynamic(lightHex: "#101114", darkHex: "#F2F4F7")
        let textSecondary = UIColor.taskerDynamic(lightHex: "#4B4F58", darkHex: "#C7CBD3")
        let textTertiary = UIColor.taskerDynamic(lightHex: "#7B808A", darkHex: "#9AA1AD")
        let textQuaternary = UIColor.taskerDynamic(lightHex: "#A1A6AF", darkHex: "#737B89")
        let textInverse = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#0E0F12")

        let statusSuccess = UIColor(taskerHex: "#34C759")
        let statusWarning = UIColor(taskerHex: "#FF9F0A")
        let statusDanger = UIColor(taskerHex: "#FF3B30")

        let overlayScrim = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.black.withAlphaComponent(0.45)
            }
            return UIColor.black.withAlphaComponent(0.25)
        }

        let overlayGlassTint = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(taskerHex: "#14161B").withAlphaComponent(0.70)
            }
            return UIColor.white.withAlphaComponent(0.72)
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
            statusSuccess: statusSuccess,
            statusWarning: statusWarning,
            statusDanger: statusDanger,
            overlayScrim: overlayScrim,
            overlayGlassTint: overlayGlassTint,
            taskCheckboxBorder: strokeStrong,
            taskCheckboxFill: accentRamp.accent500,
            taskOverdue: statusDanger,
            chartPrimary: accentRamp.accent500,
            chipSelectedBackground: accentRamp.accent500,
            chipUnselectedBackground: surfaceSecondary
        )
    }
}
