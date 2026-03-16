import SwiftUI
import UIKit

enum WidgetBrand {
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.082, green: 0.067, blue: 0.055, alpha: 1) : UIColor(red: 1.0, green: 0.973, blue: 0.937, alpha: 1)
    })
    static let canvasElevated = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.114, green: 0.09, blue: 0.071, alpha: 1) : UIColor(red: 1.0, green: 0.988, blue: 0.973, alpha: 1)
    })
    static let emerald = Color(red: 0.161, green: 0.227, blue: 0.094)
    static let magenta = Color(red: 0.694, green: 0.125, blue: 0.373)
    static let marigold = Color(red: 0.996, green: 0.749, blue: 0.169)
    static let red = Color(red: 0.757, green: 0.075, blue: 0.09)
    static let sandstone = Color(red: 0.62, green: 0.373, blue: 0.039)
    static let actionPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.996, green: 0.749, blue: 0.169, alpha: 1) : UIColor(red: 0.161, green: 0.227, blue: 0.094, alpha: 1)
    })
    static let textPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 1.0, green: 0.953, blue: 0.902, alpha: 1) : UIColor(red: 0.106, green: 0.082, blue: 0.067, alpha: 1)
    })
    static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.906, green: 0.851, blue: 0.796, alpha: 1) : UIColor(red: 0.416, green: 0.349, blue: 0.294, alpha: 1)
    })
    static let line = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.227, green: 0.18, blue: 0.141, alpha: 1) : UIColor(red: 0.886, green: 0.827, blue: 0.761, alpha: 1)
    })
}
