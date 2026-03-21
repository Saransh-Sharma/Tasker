import SwiftUI

@MainActor
enum WidgetBrand {
    static let canvas = TaskerTheme.Colors.background
    static let canvasSecondary = TaskerTheme.Colors.backgroundSecondary
    static let canvasElevated = Color.tasker(.bgElevated)
    static let panel = TaskerTheme.Colors.cardBackground

    static let line = Color.tasker(.borderSubtle)
    static let lineStrong = Color.tasker(.borderStrong)

    static let emerald = TaskerTheme.Colors.brandPrimary
    static let magenta = TaskerTheme.Colors.accentSecondary
    static let marigold = TaskerTheme.Colors.statusWarning
    static let red = TaskerTheme.Colors.statusDanger
    static let sandstone = TaskerTheme.Colors.brandSecondary

    static let actionPrimary = TaskerTheme.Colors.actionPrimary
    static let actionPrimaryPressed = Color.tasker(.actionPrimaryPressed)
    static let accentQuiet = TaskerTheme.Colors.accentSecondaryMuted
    static let accentWash = Color.tasker(.accentSecondaryWash)

    static let textPrimary = TaskerTheme.Colors.textPrimary
    static let textSecondary = TaskerTheme.Colors.textSecondary
    static let textTertiary = TaskerTheme.Colors.textTertiary
    static let textInverse = Color.tasker(.textInverse)

    static func priority(_ code: String) -> Color {
        switch code.uppercased() {
        case "P0":
            return TaskerTheme.Colors.priorityMax
        case "P1":
            return TaskerTheme.Colors.priorityHigh
        case "P2":
            return TaskerTheme.Colors.statusWarning
        case "P3", "P4", "P5":
            return TaskerTheme.Colors.priorityLow
        default:
            return TaskerTheme.Colors.priorityNone
        }
    }
}
