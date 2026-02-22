import UIKit

public struct TaskerElevationStyle {
    public let shadowOffsetY: CGFloat
    public let shadowBlur: CGFloat
    public let shadowOpacity: Float
    public let shadowColor: UIColor
    public let borderWidth: CGFloat
    public let borderColor: UIColor
    public let blurStyle: UIBlurEffect.Style
}

public struct TaskerElevationTokens: TaskerTokenGroup {
    public let e0: TaskerElevationStyle
    public let e1: TaskerElevationStyle
    public let e2: TaskerElevationStyle
    public let e3: TaskerElevationStyle

    /// Executes style.
    public func style(for level: TaskerElevationLevel) -> TaskerElevationStyle {
        switch level {
        case .e0: return e0
        case .e1: return e1
        case .e2: return e2
        case .e3: return e3
        }
    }

    public static let `default` = TaskerElevationTokens(
        e0: TaskerElevationStyle(
            shadowOffsetY: 0,
            shadowBlur: 0,
            shadowOpacity: 0,
            shadowColor: .clear,
            borderWidth: 0,
            borderColor: .clear,
            blurStyle: .systemUltraThinMaterial
        ),
        e1: TaskerElevationStyle(
            shadowOffsetY: 2,
            shadowBlur: 10,
            shadowOpacity: 0.08,
            shadowColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 0.55)
                }
                return UIColor(red: 0.06, green: 0.10, blue: 0.15, alpha: 0.14)
            },
            borderWidth: 1,
            borderColor: UIColor.taskerDynamic(lightHex: "#D8E0E8", darkHex: "#3A414C"),
            blurStyle: .systemUltraThinMaterial
        ),
        e2: TaskerElevationStyle(
            shadowOffsetY: 5,
            shadowBlur: 22,
            shadowOpacity: 0.10,
            shadowColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 0.62)
                }
                return UIColor(red: 0.06, green: 0.10, blue: 0.15, alpha: 0.18)
            },
            borderWidth: 0.5,
            borderColor: UIColor.taskerDynamic(lightHex: "#D8E0E8", darkHex: "#3A414C"),
            blurStyle: .systemThinMaterial
        ),
        e3: TaskerElevationStyle(
            shadowOffsetY: 10,
            shadowBlur: 36,
            shadowOpacity: 0.14,
            shadowColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 0.70)
                }
                return UIColor(red: 0.06, green: 0.10, blue: 0.15, alpha: 0.24)
            },
            borderWidth: 1,
            borderColor: UIColor.taskerDynamic(lightHex: "#BAC6D3", darkHex: "#505B69"),
            blurStyle: .systemMaterial
        )
    )
}
