import SwiftUI

@MainActor
func gapPromptTint(for gap: TimelineGap) -> Color {
    switch gap.emphasis {
    case .openTime:
        return Color.lifeboard.accentPrimary
    case .prepWindow:
        return Color.lifeboard.statusWarning
    case .quietWindow:
        return Color.lifeboard.statusSuccess
    }
}
