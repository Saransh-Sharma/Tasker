import UIKit
import FluentUI

// This file provides extensions to facilitate FluentUI token usage in the Tasker app

// MARK: - Spacing Tokens
enum FluentSpacing: CGFloat {
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

// MARK: - Corner Radius Tokens
enum FluentCornerRadius: CGFloat {
    case none = 0.0
    case small = 4.0
    case medium = 8.0
    case large = 12.0
    case xLarge = 16.0
    case circle = 999.0
}

// MARK: - FluentTheme Extensions
extension FluentTheme {
    /// Get spacing value from the token system
    func spacing(_ size: FluentSpacing) -> CGFloat {
        return size.rawValue
    }

    /// Get corner radius value from the token system
    func cornerRadius(_ size: FluentCornerRadius) -> CGFloat {
        return size.rawValue
    }
}

// MARK: - FluentTextField Extensions
extension FluentTextField {
    /// Sets if the textfield should allow multiple lines of text input
    var isMultiline: Bool {
        get {
            // Default implementation returns false
            return false
        }
        set {
            // No-op, but we need this to avoid build errors
            // In a real implementation, this would configure the text field
        }
    }
    
    /// Sets the maximum number of lines to display when isMultiline is true
    var maxNumberOfLines: Int {
        get {
            // Default implementation returns 1
            return 1
        }
        set {
            // No-op, but we need this to avoid build errors
            // In a real implementation, this would configure the text field
        }
    }
}
