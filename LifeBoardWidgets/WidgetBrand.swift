import SwiftUI

@MainActor
enum WidgetBrand {
    static let canvas = LifeBoardTheme.Colors.background
    static let canvasSecondary = LifeBoardTheme.Colors.backgroundSecondary
    static let canvasElevated = Color.lifeboard(.bgElevated)
    static let panel = LifeBoardTheme.Colors.cardBackground

    static let line = Color.lifeboard(.borderSubtle)
    static let lineStrong = Color.lifeboard(.borderStrong)

    static let emerald = LifeBoardTheme.Colors.brandPrimary
    static let magenta = LifeBoardTheme.Colors.accentSecondary
    static let marigold = LifeBoardTheme.Colors.statusWarning
    static let red = LifeBoardTheme.Colors.statusDanger
    static let sandstone = LifeBoardTheme.Colors.brandSecondary

    static let actionPrimary = LifeBoardTheme.Colors.actionPrimary
    static let actionPrimaryPressed = Color.lifeboard(.actionPrimaryPressed)
    static let accentQuiet = LifeBoardTheme.Colors.accentSecondaryMuted
    static let accentWash = Color.lifeboard(.accentSecondaryWash)

    static let textPrimary = LifeBoardTheme.Colors.textPrimary
    static let textSecondary = LifeBoardTheme.Colors.textSecondary
    static let textTertiary = LifeBoardTheme.Colors.textTertiary
    static let textInverse = Color.lifeboard(.textInverse)

    static func priority(_ code: String) -> Color {
        switch code.uppercased() {
        case "P0":
            return LifeBoardTheme.Colors.priorityMax
        case "P1":
            return LifeBoardTheme.Colors.priorityHigh
        case "P2":
            return LifeBoardTheme.Colors.statusWarning
        case "P3", "P4", "P5":
            return LifeBoardTheme.Colors.priorityLow
        default:
            return LifeBoardTheme.Colors.priorityNone
        }
    }
}
