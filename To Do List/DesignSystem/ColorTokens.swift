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

    /// Executes color.
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

    /// Executes make.
    public static func make(
        accentTheme: TaskerAccentTheme,
        accentRamp: TaskerAccentRamp,
        secondaryRamp: TaskerAccentRamp
    ) -> TaskerColorTokens {
        // Calm Clarity cool-neutral palette.
        let bgCanvas = UIColor.taskerDynamic(lightHex: "#F8FAFB", darkHex: "#0F1114")
        let bgElevated = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#1A1D22")

        let surfacePrimary = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#22262D")
        let surfaceSecondary = UIColor.taskerDynamic(lightHex: "#F1F4F7", darkHex: "#2A2E36")
        let surfaceTertiary = UIColor.taskerDynamic(lightHex: "#E7EDF3", darkHex: "#323844")

        let divider = UIColor.taskerDynamic(lightHex: "#D8E0E8", darkHex: "#3A414C")
        let strokeHairline = UIColor.taskerDynamic(lightHex: "#D8E0E8", darkHex: "#3A414C")
        let strokeStrong = UIColor.taskerDynamic(lightHex: "#BAC6D3", darkHex: "#505B69")

        let textPrimary = UIColor.taskerDynamic(lightHex: "#111827", darkHex: "#F1F4F7")
        let textSecondary = UIColor.taskerDynamic(lightHex: "#4B5563", darkHex: "#9CA3AF")
        let textTertiary = UIColor.taskerDynamic(lightHex: "#9CA3AF", darkHex: "#6B7280")
        let textQuaternary = UIColor.taskerDynamic(lightHex: "#B6C0CC", darkHex: "#596373")
        let textInverse = UIColor.taskerDynamic(lightHex: "#FFFFFF", darkHex: "#0F1114")

        let statusSuccess = UIColor(taskerHex: "#16A34A")
        let statusWarning = UIColor(taskerHex: "#D97706")
        let statusDanger = UIColor(taskerHex: "#DC2626")

        // Keep semantic distinctions obvious for charting + badges.
        let priorityMax = UIColor(taskerHex: "#DC2626")
        let priorityHigh = UIColor(taskerHex: "#EA580C")
        let priorityLow = UIColor(taskerHex: "#2563EB")
        let priorityNone = UIColor(taskerHex: "#6B7280")

        let overlayScrim = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.black.withAlphaComponent(0.56)
            }
            return UIColor(taskerHex: "#111827").withAlphaComponent(0.20)
        }

        let overlayGlassTint = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(taskerHex: "#1A1D22").withAlphaComponent(0.74)
            }
            return UIColor(taskerHex: "#F8FAFB").withAlphaComponent(0.76)
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
            accentPrimaryPressed: UIColor(taskerHex: accentTheme.accentPressedHex),
            accentMuted: accentRamp.accent100,
            accentWash: UIColor(taskerHex: accentTheme.accentWashHex),
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
            taskOverdue: UIColor(taskerHex: "#BE123C"),
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
