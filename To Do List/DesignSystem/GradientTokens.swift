import UIKit
import SwiftUI

// MARK: - Tasker Header Gradient

/// Provides a reusable multi-stop gradient + scrim + noise for header backdrops.
/// All stops are derived dynamically from the current accent color so they adapt
/// across all accent themes.
@MainActor
public struct TaskerHeaderGradient {

    // MARK: - Public API

    /// Apply the full header treatment (gradient + scrim + bottom fade + noise) to a UIKit layer.
    /// Call again in `viewDidLayoutSubviews` so the layers resize correctly.
    public static func apply(to layer: CALayer, bounds: CGRect, traits: UITraitCollection) {
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color
        let primary = colors.accentPrimary.resolvedColor(with: traits)
        let secondary = colors.accentSecondary.resolvedColor(with: traits)

        removeLayers(from: layer)

        // Layer order must remain stable:
        // gradient -> scrim -> bottomFade -> noise

        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "taskerHeaderGradient"
        gradientLayer.frame = bounds
        gradientLayer.colors = gradientColors(primary: primary, secondary: secondary, traits: traits)
        gradientLayer.locations = [0.0, 0.35, 0.7, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        // Keep all header treatment layers behind subviews/content layers.
        // Insert at the bottom in declared order: gradient -> scrim -> bottomFade -> noise.

        let scrimLayer = CAGradientLayer()
        scrimLayer.name = "taskerHeaderScrim"
        scrimLayer.frame = bounds
        scrimLayer.colors = scrimColors(traits: traits)
        scrimLayer.locations = [0.0, 0.5, 1.0]
        scrimLayer.startPoint = CGPoint(x: 0.5, y: 0)
        scrimLayer.endPoint = CGPoint(x: 0.5, y: 1)

        let bottomFade = CAGradientLayer()
        bottomFade.name = "taskerHeaderBottomFade"
        bottomFade.frame = bounds
        bottomFade.colors = bottomFadeColors(traits: traits)
        bottomFade.locations = [0.0, 0.72, 1.0]
        bottomFade.startPoint = CGPoint(x: 0.5, y: 0)
        bottomFade.endPoint = CGPoint(x: 0.5, y: 1)

        // Radial highlight at top-center for depth
        let radialHighlight = CAGradientLayer()
        radialHighlight.name = "taskerHeaderRadialHighlight"
        radialHighlight.type = .radial
        radialHighlight.frame = bounds
        let isDark = traits.userInterfaceStyle == .dark
        let highlightAlpha: CGFloat = isDark ? 0.08 : 0.12
        radialHighlight.colors = [
            UIColor.white.withAlphaComponent(highlightAlpha).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        radialHighlight.startPoint = CGPoint(x: 0.5, y: 0)
        radialHighlight.endPoint = CGPoint(x: 0.5, y: 1.0)

        let noiseLayer = CALayer()
        noiseLayer.name = "taskerHeaderNoise"
        noiseLayer.frame = bounds
        noiseLayer.contents = noiseImage(size: CGSize(width: 64, height: 64))?.cgImage
        noiseLayer.contentsGravity = .resizeAspectFill
        noiseLayer.opacity = isDark ? 0.025 : 0.02
        noiseLayer.compositingFilter = "softLightBlendMode"

        // Wrap all sublayers in a container with rounded bottom corners
        let container = CALayer()
        container.name = "taskerHeaderGradientContainer"
        container.frame = bounds
        container.addSublayer(gradientLayer)
        container.addSublayer(scrimLayer)
        container.addSublayer(bottomFade)
        container.addSublayer(radialHighlight)
        container.addSublayer(noiseLayer)

        let maskPath = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: 24, height: 24)
        )
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath.cgPath
        container.mask = maskLayer

        layer.insertSublayer(container, at: 0)
    }

    /// Backward-compatible convenience overload.
    public static func apply(to layer: CALayer, bounds: CGRect) {
        apply(to: layer, bounds: bounds, traits: UIScreen.main.traitCollection)
    }

    /// Remove all header gradient sublayers (useful before re-applying on theme change).
    public static func removeLayers(from layer: CALayer) {
        layer.sublayers?.removeAll(where: { $0.name == "taskerHeaderGradientContainer" })
    }

    // MARK: - Gradient Color Generation

    /// Build 4-stop dual-tone gradient blending primary → secondary, adapting to light/dark mode.
    /// Creates a "gem catching light" effect with richer color dimension than monochromatic shading.
    private static func gradientColors(primary: UIColor, secondary: UIColor, traits: UITraitCollection) -> [CGColor] {
        let isDark = traits.userInterfaceStyle == .dark
        if isDark {
            // Dark mode: deep primary shades at top → secondary tones emerging at bottom
            return [
                shade(primary, by: 0.68).cgColor,
                shade(primary, by: 0.48).cgColor,
                shade(blendColors(primary, secondary, ratio: 0.5), by: 0.30).cgColor,
                shade(secondary, by: 0.20).cgColor
            ]
        } else {
            // Light mode: primary at top → blending through to secondary
            return [
                primary.cgColor,
                shade(primary, by: 0.06).cgColor,
                blendColors(primary, secondary, ratio: 0.5).cgColor,
                shade(secondary, by: 0.10).cgColor
            ]
        }
    }

    /// Blend two colors by a ratio (0.0 = first color, 1.0 = second color).
    private static func blendColors(_ c1: UIColor, _ c2: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let inv = 1.0 - ratio
        return UIColor(
            red: r1 * inv + r2 * ratio,
            green: g1 * inv + g2 * ratio,
            blue: b1 * inv + b2 * ratio,
            alpha: a1 * inv + a2 * ratio
        )
    }

    /// Premium shade function:
    /// - lowers brightness
    /// - lowers saturation while shading to avoid muddy/brown tones
    private static func shade(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return color
        }
        let shadedBrightness = max(b - amount, 0)
        let shadedSaturation = max(s - (amount * 0.28), 0.02)
        return UIColor(hue: h, saturation: shadedSaturation, brightness: shadedBrightness, alpha: a)
    }

    // MARK: - Scrim

    private static func scrimColors(traits: UITraitCollection) -> [CGColor] {
        let isDark = traits.userInterfaceStyle == .dark
        let topAlpha: CGFloat = isDark ? 0.26 : 0.18
        let midAlpha: CGFloat = isDark ? 0.14 : 0.10
        return [
            UIColor.black.withAlphaComponent(topAlpha).cgColor,
            UIColor.black.withAlphaComponent(midAlpha).cgColor,
            UIColor.clear.cgColor
        ]
    }

    private static func bottomFadeColors(traits: UITraitCollection) -> [CGColor] {
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color
        let target = colors.bgCanvas.resolvedColor(with: traits)
        return [
            target.withAlphaComponent(0.0).cgColor,
            target.withAlphaComponent(0.82).cgColor,
            target.withAlphaComponent(1.0).cgColor
        ]
    }

    // MARK: - Noise Texture

    private static func noiseImage(size: CGSize) -> UIImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height)

        for i in 0..<pixels.count {
            pixels[i] = UInt8.random(in: 0...255)
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider,
                decode: nil, shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return nil }

        return UIImage(cgImage: cgImage)
    }

}

// MARK: - SwiftUI Wrapper

/// A SwiftUI view that renders the header gradient via UIKit layers.
@MainActor
public struct HeaderGradientView: UIViewRepresentable {
    @ObservedObject private var themeManager = TaskerThemeManager.shared

    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        _ = themeManager.currentTheme.index
        TaskerHeaderGradient.apply(to: uiView.layer, bounds: uiView.bounds, traits: uiView.traitCollection)
    }
}
