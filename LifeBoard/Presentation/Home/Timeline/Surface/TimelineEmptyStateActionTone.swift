import SwiftUI

@MainActor
enum TimelineEmptyStateActionTone {
    case primary
    case secondary

    var foreground: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentOnPrimary
        case .secondary:
            return Color.lifeboard.accentPrimary
        }
    }

    var background: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentPrimary
        case .secondary:
            return Color.lifeboard.accentWash.opacity(0.76)
        }
    }

    var border: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentPrimary.opacity(0.18)
        case .secondary:
            return Color.lifeboard.accentMuted.opacity(0.34)
        }
    }
}
