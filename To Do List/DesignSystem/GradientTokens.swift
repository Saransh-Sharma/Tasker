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
        let accent = colors.accentPrimary.resolvedColor(with: traits)

        removeLayers(from: layer)

        // Layer order must remain stable:
        // gradient -> scrim -> bottomFade -> noise

        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "taskerHeaderGradient"
        gradientLayer.frame = bounds
        gradientLayer.colors = gradientColors(from: accent, traits: traits)
        gradientLayer.locations = [0.0, 0.35, 0.7, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        // Keep all header treatment layers behind subviews/content layers.
        // Insert at the bottom in declared order: gradient -> scrim -> bottomFade -> noise.
        layer.insertSublayer(gradientLayer, at: 0)

        let scrimLayer = CAGradientLayer()
        scrimLayer.name = "taskerHeaderScrim"
        scrimLayer.frame = bounds
        scrimLayer.colors = scrimColors(traits: traits)
        scrimLayer.locations = [0.0, 0.5, 1.0]
        scrimLayer.startPoint = CGPoint(x: 0.5, y: 0)
        scrimLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(scrimLayer, at: 1)

        let bottomFade = CAGradientLayer()
        bottomFade.name = "taskerHeaderBottomFade"
        bottomFade.frame = bounds
        bottomFade.colors = bottomFadeColors(traits: traits)
        bottomFade.locations = [0.0, 0.72, 1.0]
        bottomFade.startPoint = CGPoint(x: 0.5, y: 0)
        bottomFade.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(bottomFade, at: 2)

        let noiseLayer = CALayer()
        noiseLayer.name = "taskerHeaderNoise"
        noiseLayer.frame = bounds
        noiseLayer.contents = noiseImage(size: CGSize(width: 64, height: 64))?.cgImage
        noiseLayer.contentsGravity = .resizeAspectFill
        let isDark = traits.userInterfaceStyle == .dark
        noiseLayer.opacity = isDark ? 0.02 : 0.015
        noiseLayer.compositingFilter = "softLightBlendMode"
        layer.insertSublayer(noiseLayer, at: 3)
    }

    /// Backward-compatible convenience overload.
    public static func apply(to layer: CALayer, bounds: CGRect) {
        apply(to: layer, bounds: bounds, traits: UIScreen.main.traitCollection)
    }

    /// Remove all header gradient sublayers (useful before re-applying on theme change).
    public static func removeLayers(from layer: CALayer) {
        let names = ["taskerHeaderGradient", "taskerHeaderScrim", "taskerHeaderBottomFade", "taskerHeaderNoise"]
        layer.sublayers?.removeAll(where: { names.contains($0.name ?? "") })
    }

    // MARK: - Gradient Color Generation

    /// Build 4-stop gradient colors from the accent, adapting to light/dark mode.
    private static func gradientColors(from accent: UIColor, traits: UITraitCollection) -> [CGColor] {
        let isDark = traits.userInterfaceStyle == .dark
        if isDark {
            return [
                shade(accent, by: 0.72).cgColor,
                shade(accent, by: 0.54).cgColor,
                shade(accent, by: 0.36).cgColor,
                shade(accent, by: 0.20).cgColor
            ]
        } else {
            return [
                accent.cgColor,
                shade(accent, by: 0.08).cgColor,
                shade(accent, by: 0.16).cgColor,
                shade(accent, by: 0.24).cgColor
            ]
        }
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
