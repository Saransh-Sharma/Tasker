import UIKit

/// A tiny enum to pick one of two nav-bar background colors.
enum ColoredPillBackgroundStyle {
    /// neutral “surface” background
    case neutralNavBar
    /// brand-themed background
    case brandNavBar
}

/// A wrapper view that picks a backgroundColor based on the style.
final class ColoredPillBackgroundView: UIView {
    /// Initializes a new instance.
    init(style: ColoredPillBackgroundStyle) {
        super.init(frame: .zero)
        let colors = LifeBoardThemeManager.shared.currentTheme.tokens.color
        switch style {
        case .neutralNavBar:
            backgroundColor = colors.surfaceSecondary
        case .brandNavBar:
            backgroundColor = colors.actionPrimary
        }
    }
    /// Initializes a new instance.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
