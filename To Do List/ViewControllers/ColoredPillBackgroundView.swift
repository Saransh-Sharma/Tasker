import UIKit
import FluentUI

/// A tiny enum to pick one of two nav-bar background colors.
enum ColoredPillBackgroundStyle {
    /// neutral “surface” background
    case neutralNavBar
    /// brand-themed background
    case brandNavBar
}

/// A wrapper view that picks a backgroundColor based on the style.
final class ColoredPillBackgroundView: UIView {
    init(style: ColoredPillBackgroundStyle) {
        super.init(frame: .zero)
        let theme = FluentTheme()
        switch style {
        case .neutralNavBar:
            backgroundColor = theme.color(.background5)
        case .brandNavBar:
            backgroundColor = theme.color(.brandBackground1)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
