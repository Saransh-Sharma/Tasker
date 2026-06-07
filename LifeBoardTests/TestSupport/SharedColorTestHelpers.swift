#if canImport(UIKit)
import SwiftUI
import UIKit

func resolvedColor(
    _ color: Color,
    style: UIUserInterfaceStyle,
    contrast: UIAccessibilityContrast = .normal
) -> UIColor {
    let traits = UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceStyle: style),
        UITraitCollection(accessibilityContrast: contrast)
    ])
    return UIColor(color).resolvedColor(with: traits)
}

func contrastRatio(_ foreground: UIColor, _ background: UIColor) -> CGFloat {
    let lighter = max(relativeLuminance(foreground), relativeLuminance(background))
    let darker = min(relativeLuminance(foreground), relativeLuminance(background))
    return (lighter + 0.05) / (darker + 0.05)
}

func composited(_ foreground: UIColor, over background: UIColor) -> UIColor {
    let foregroundComponents = rgbaComponents(foreground)
    let backgroundComponents = rgbaComponents(background)
    let foregroundAlpha = foregroundComponents.alpha
    let backgroundAlpha = backgroundComponents.alpha * (1 - foregroundAlpha)
    let alpha = foregroundAlpha + backgroundAlpha
    guard alpha > 0 else { return .clear }

    let red = (foregroundComponents.red * foregroundAlpha + backgroundComponents.red * backgroundAlpha) / alpha
    let green = (foregroundComponents.green * foregroundAlpha + backgroundComponents.green * backgroundAlpha) / alpha
    let blue = (foregroundComponents.blue * foregroundAlpha + backgroundComponents.blue * backgroundAlpha) / alpha
    return UIColor(red: red, green: green, blue: blue, alpha: alpha)
}

func relativeLuminance(_ color: UIColor) -> CGFloat {
    let components = rgbaComponents(color)
    func channel(_ value: CGFloat) -> CGFloat {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(components.red)
        + 0.7152 * channel(components.green)
        + 0.0722 * channel(components.blue)
}

func redComponent(_ color: UIColor) -> CGFloat {
    rgbaComponents(color).red
}

func greenComponent(_ color: UIColor) -> CGFloat {
    rgbaComponents(color).green
}

func blueComponent(_ color: UIColor) -> CGFloat {
    rgbaComponents(color).blue
}

func alphaComponent(_ color: UIColor) -> CGFloat {
    rgbaComponents(color).alpha
}

func rgbaComponents(_ color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (red, green, blue, alpha)
}
#endif
