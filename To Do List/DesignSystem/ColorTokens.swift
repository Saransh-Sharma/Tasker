import UIKit

public struct TaskerColorTokens: TaskerTokenGroup {
    public let bgCanvas: UIColor
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
    public var canvasElevated: UIColor { bgElevated }
    public var strokeSubtle: UIColor { borderSubtle }
    public var focusRing: UIColor { actionFocus }
    public var scrim: UIColor { overlayScrim }
    public var glassTint: UIColor { overlayGlassTint }
    public var patternTint: UIColor { accentSecondaryWash }

    /// Executes color.
    public func color(for role: TaskerColorRole) -> UIColor {
        switch role {
        case .bgCanvas: return bgCanvas
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
    public static func make(palette: TaskerBrandPalette) -> TaskerColorTokens {
        let bgCanvas = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk0 : palette.neutralIvory
        }
        let bgElevated = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk1 : UIColor(taskerHex: "#FFFCF8")
        }

        let surfacePrimary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk1 : UIColor(taskerHex: "#FFFCF8")
        }
        let surfaceSecondary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk2 : palette.neutralCream
        }
        let surfaceTertiary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk3 : palette.neutralMist
        }

        let divider = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkBorder1 : palette.neutralMist
        }
        let strokeHairline = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkBorder1 : palette.neutralStone
        }
        let strokeStrong = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkBorder2 : palette.neutralSandGray
        }

        let textPrimary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkText1 : palette.neutralInk
        }
        let textSecondary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkText2 : palette.neutralUmber
        }
        let textTertiary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkText3 : UIColor(taskerHex: "#6A594B")
        }
        let textQuaternary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkDisabled : UIColor(taskerHex: "#A19386")
        }
        let textInverse = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk0 : palette.neutralIvory
        }

        let actionPrimary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.brandMarigold : palette.brandEmerald
        }
        let actionPrimaryPressed = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(taskerHex: "#E2A81E") : UIColor(taskerHex: "#223114")
        }
        let accentMuted = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return palette.brandMarigold.withAlphaComponent(0.14)
            }
            return palette.brandEmerald.withAlphaComponent(0.12)
        }
        let accentWash = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return palette.brandMarigold.withAlphaComponent(0.10)
            }
            return palette.brandEmerald.withAlphaComponent(0.08)
        }
        let accentRing = UIColor { traits in
            let base = traits.userInterfaceStyle == .dark ? palette.brandMagenta : palette.brandEmerald
            return base.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.36 : 0.28)
        }

        let accentSecondary = palette.brandMagenta
        let accentSecondaryPressed = UIColor(taskerHex: "#8F184B")
        let accentSecondaryMuted = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.brandMagenta.withAlphaComponent(0.18) : palette.brandMagenta.withAlphaComponent(0.10)
        }
        let accentSecondaryWash = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.brandMagenta.withAlphaComponent(0.10) : palette.brandMagenta.withAlphaComponent(0.08)
        }

        let statusSuccess = palette.brandEmerald
        let statusWarning = palette.brandMarigold
        let statusDanger = palette.brandRed
        let stateInfo = palette.brandSandstone

        let priorityMax = palette.brandRed
        let priorityHigh = palette.brandMagenta
        let priorityLow = palette.brandEmerald
        let priorityNone = palette.brandSandstone

        let overlayScrim = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.black.withAlphaComponent(0.54)
            }
            return UIColor(taskerHex: "#221B13").withAlphaComponent(0.20)
        }

        let overlayGlassTint = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return palette.neutralDarkInk2.withAlphaComponent(0.82)
            }
            return palette.neutralIvory.withAlphaComponent(0.88)
        }

        return TaskerColorTokens(
            bgCanvas: bgCanvas,
            bgElevated: bgElevated,
            surfacePrimary: surfacePrimary,
            surfaceSecondary: surfaceSecondary,
            surfaceTertiary: surfaceTertiary,
            brandPrimary: palette.brandEmerald,
            brandSecondary: palette.brandMagenta,
            brandHighlight: palette.brandMarigold,
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
            taskOverdue: UIColor(taskerHex: "#B13126"),
            chartPrimary: palette.brandEmerald,
            chartSecondary: palette.brandMarigold,
            chipSelectedBackground: accentWash,
            chipUnselectedBackground: surfaceSecondary,
            priorityMax: priorityMax,
            priorityHigh: priorityHigh,
            priorityLow: priorityLow,
            priorityNone: priorityNone
        )
    }
}
