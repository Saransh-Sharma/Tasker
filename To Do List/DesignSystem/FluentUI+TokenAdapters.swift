import UIKit
import FluentUI

public enum FluentSpacing: CGFloat {
    case xxxSmall = 2.0
    case xxSmall = 4.0
    case xSmall = 8.0
    case small = 12.0
    case medium = 16.0
    case large = 20.0
    case xLarge = 24.0
    case xxLarge = 32.0
    case xxxLarge = 40.0
}

public enum FluentCornerRadius: CGFloat {
    case none = 0.0
    case small = 8.0
    case medium = 12.0
    case large = 16.0
    case xLarge = 24.0
    case circle = 999.0
}

@MainActor
public extension FluentTheme {
    func spacing(_ size: FluentSpacing) -> CGFloat {
        let spacing = TaskerThemeManager.shared.currentTheme.tokens.spacing
        switch size {
        case .xxxSmall: return spacing.s2
        case .xxSmall: return spacing.s4
        case .xSmall: return spacing.s8
        case .small: return spacing.s12
        case .medium: return spacing.s16
        case .large: return spacing.s20
        case .xLarge: return spacing.s24
        case .xxLarge: return spacing.s32
        case .xxxLarge: return spacing.s40
        }
    }

    func cornerRadius(_ size: FluentCornerRadius) -> CGFloat {
        let corner = TaskerThemeManager.shared.currentTheme.tokens.corner
        switch size {
        case .none: return corner.r0
        case .small: return corner.r1
        case .medium: return corner.r2
        case .large: return corner.r3
        case .xLarge: return corner.r4
        case .circle: return corner.pill
        }
    }

    var taskerColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }
}

public extension FluentTextField {
    var isMultiline: Bool {
        get { false }
        set { }
    }

    var maxNumberOfLines: Int {
        get { 1 }
        set { }
    }
}
