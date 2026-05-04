import UIKit

@MainActor
public struct LifeBoardElevationStyle {
    public let shadowOffsetY: CGFloat
    public let shadowBlur: CGFloat
    public let shadowOpacity: Float
    public let shadowColor: UIColor
    public let borderWidth: CGFloat
    public let borderColor: UIColor
    public let blurStyle: UIBlurEffect.Style
}

@MainActor
public struct LifeBoardElevationTokens: LifeBoardTokenGroup {
    public let e0: LifeBoardElevationStyle
    public let e1: LifeBoardElevationStyle
    public let e2: LifeBoardElevationStyle
    public let e3: LifeBoardElevationStyle

    private static let warmBorder = UIColor.lifeboardDynamic(lightHex: "#E2D3C2", darkHex: "#3A2E24")
    private static let warmBorderStrong = UIColor.lifeboardDynamic(lightHex: "#C9B9A6", darkHex: "#4A3B30")

    private static func warmShadowColor(darkAlpha: CGFloat, lightAlpha: CGFloat) -> UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.02, green: 0.02, blue: 0.02, alpha: darkAlpha)
            }
            return UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: lightAlpha)
        }
    }

    /// Executes style.
    public func style(for level: LifeBoardElevationLevel) -> LifeBoardElevationStyle {
        switch level {
        case .e0: return e0
        case .e1: return e1
        case .e2: return e2
        case .e3: return e3
        }
    }

    public static let `default` = LifeBoardElevationTokens(
        e0: LifeBoardElevationStyle(
            shadowOffsetY: 0,
            shadowBlur: 0,
            shadowOpacity: 0,
            shadowColor: .clear,
            borderWidth: 0,
            borderColor: .clear,
            blurStyle: .systemUltraThinMaterial
        ),
        e1: LifeBoardElevationStyle(
            shadowOffsetY: 1,
            shadowBlur: 8,
            shadowOpacity: 0.06,
            shadowColor: warmShadowColor(darkAlpha: 0.36, lightAlpha: 0.10),
            borderWidth: 1,
            borderColor: warmBorder,
            blurStyle: .systemUltraThinMaterial
        ),
        e2: LifeBoardElevationStyle(
            shadowOffsetY: 6,
            shadowBlur: 24,
            shadowOpacity: 0.08,
            shadowColor: warmShadowColor(darkAlpha: 0.44, lightAlpha: 0.14),
            borderWidth: 1,
            borderColor: warmBorder,
            blurStyle: .systemThinMaterial
        ),
        e3: LifeBoardElevationStyle(
            shadowOffsetY: 10,
            shadowBlur: 34,
            shadowOpacity: 0.10,
            shadowColor: warmShadowColor(darkAlpha: 0.56, lightAlpha: 0.20),
            borderWidth: 1,
            borderColor: warmBorderStrong,
            blurStyle: .systemMaterial
        )
    )

    private static let padCompact: LifeBoardElevationTokens = scaled(
        from: `default`,
        blurMultiplier: 1.08,
        offsetMultiplier: 1.05,
        opacityMultiplier: 1.03,
        borderMultiplier: 1.0
    )

    private static let padRegular: LifeBoardElevationTokens = scaled(
        from: `default`,
        blurMultiplier: 1.18,
        offsetMultiplier: 1.12,
        opacityMultiplier: 1.08,
        borderMultiplier: 1.0
    )

    private static let padExpanded: LifeBoardElevationTokens = scaled(
        from: `default`,
        blurMultiplier: 1.26,
        offsetMultiplier: 1.2,
        opacityMultiplier: 1.12,
        borderMultiplier: 1.0
    )

    /// Executes forLayout.
    public static func forLayout(_ layoutClass: LifeBoardLayoutClass) -> LifeBoardElevationTokens {
        switch layoutClass {
        case .phone:
            return `default`
        case .padCompact:
            return padCompact
        case .padRegular:
            return padRegular
        case .padExpanded:
            return padExpanded
        }
    }

    /// Executes scaled.
    private static func scaled(
        from source: LifeBoardElevationTokens,
        blurMultiplier: CGFloat,
        offsetMultiplier: CGFloat,
        opacityMultiplier: Float,
        borderMultiplier: CGFloat
    ) -> LifeBoardElevationTokens {
        func apply(_ style: LifeBoardElevationStyle) -> LifeBoardElevationStyle {
            LifeBoardElevationStyle(
                shadowOffsetY: style.shadowOffsetY * offsetMultiplier,
                shadowBlur: style.shadowBlur * blurMultiplier,
                shadowOpacity: min(1, style.shadowOpacity * opacityMultiplier),
                shadowColor: style.shadowColor,
                borderWidth: style.borderWidth * borderMultiplier,
                borderColor: style.borderColor,
                blurStyle: style.blurStyle
            )
        }

        return LifeBoardElevationTokens(
            e0: apply(source.e0),
            e1: apply(source.e1),
            e2: apply(source.e2),
            e3: apply(source.e3)
        )
    }
}
