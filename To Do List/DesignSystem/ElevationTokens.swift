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
            shadowOpacity: 0.10,
            shadowColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor.black.withAlphaComponent(0.45)
                }
                return UIColor.black.withAlphaComponent(0.18)
            },
            borderWidth: 1,
            borderColor: UIColor.taskerDynamic(lightHex: "#E4E7ED", darkHex: "#323847"),
            blurStyle: .systemUltraThinMaterial
        ),
        e2: TaskerElevationStyle(
            shadowOffsetY: 6,
            shadowBlur: 20,
            shadowOpacity: 0.14,
            shadowColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor.black.withAlphaComponent(0.55)
                }
                return UIColor.black.withAlphaComponent(0.22)
            },
            borderWidth: 0.5,
            borderColor: UIColor.taskerDynamic(lightHex: "#E4E7ED", darkHex: "#2A2F3A"),
            blurStyle: .systemThinMaterial
        ),
        e3: TaskerElevationStyle(
            shadowOffsetY: 12,
            shadowBlur: 40,
            shadowOpacity: 0.18,
            shadowColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor.black.withAlphaComponent(0.62)
                }
                return UIColor.black.withAlphaComponent(0.30)
            },
            borderWidth: 1,
            borderColor: UIColor.taskerDynamic(lightHex: "#D7DBE3", darkHex: "#323847"),
            blurStyle: .systemMaterial
        )
    )
}
