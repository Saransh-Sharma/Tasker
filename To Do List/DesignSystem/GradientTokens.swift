import UIKit
import SwiftUI

// MARK: - Tasker Header Gradient

/// Provides a reusable multi-stop gradient + scrim + noise for header backdrops.
/// The look is fixed to the Tasker brand: gateway sunrise in light mode and
/// forest ink in dark mode.
@MainActor
public struct TaskerHeaderGradient {

    // MARK: - Public API

    /// Apply the full header treatment (gradient + scrim + bottom fade + noise) to a UIKit layer.
    /// Call again in `viewDidLayoutSubviews` so the layers resize correctly.
    public static func apply(to layer: CALayer, bounds: CGRect, traits: UITraitCollection) {
        let patterns = TaskerThemeManager.shared.currentTheme.patterns

        removeLayers(from: layer)

        // Layer order must remain stable:
        // gradient -> scrim -> bottomFade -> noise

        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "taskerHeaderGradient"
        gradientLayer.frame = bounds
        gradientLayer.colors = gradientColors(patterns: patterns, traits: traits)
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

    private static func gradientColors(patterns: TaskerPatternTokens, traits: UITraitCollection) -> [CGColor] {
        let isDark = traits.userInterfaceStyle == .dark
        if isDark {
            return [
                blendColors(patterns.forestInkBottom, patterns.gatewaySunriseTop, ratio: 0.02).cgColor,
                blendColors(patterns.forestInkBottom, patterns.gatewaySunriseTop, ratio: 0.06).cgColor,
                blendColors(patterns.forestInkBottom, patterns.gatewaySunriseBottom, ratio: 0.07).cgColor,
                blendColors(patterns.forestInkTop, patterns.forestInkBottom, ratio: 0.28).cgColor
            ]
        } else {
            let canvas = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas.resolvedColor(with: traits)
            return [
                blendColors(patterns.gatewaySunriseTop, canvas, ratio: 0.18).cgColor,
                shade(patterns.gatewaySunriseMid, by: 0.02).cgColor,
                blendColors(patterns.gatewaySunriseMid, patterns.gatewaySunriseBottom, ratio: 0.52).cgColor,
                shade(patterns.gatewaySunriseBottom, by: 0.04).cgColor
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
    /// - lowers saturation while shading, with reduced desaturation for warm hues
    ///   to preserve chromatic richness (prevents pinks/golds from going muddy)
    private static func shade(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return color
        }
        let shadedBrightness = max(b - amount, 0)
        // Warm hues (reds, pinks, oranges, golds: ~320-60 degrees) desaturate less
        let isWarmHue = h > 0.89 || h < 0.17 // ~320° to ~60° on the color wheel
        let satReduction = isWarmHue ? amount * 0.15 : amount * 0.28
        let shadedSaturation = max(s - satReduction, 0.02)
        return UIColor(hue: h, saturation: shadedSaturation, brightness: shadedBrightness, alpha: a)
    }

    // MARK: - Scrim

    /// Executes scrimColors.
    private static func scrimColors(traits: UITraitCollection) -> [CGColor] {
        let isDark = traits.userInterfaceStyle == .dark
        let topAlpha: CGFloat = isDark ? 0.18 : 0.18
        let midAlpha: CGFloat = isDark ? 0.10 : 0.10
        return [
            UIColor.black.withAlphaComponent(topAlpha).cgColor,
            UIColor.black.withAlphaComponent(midAlpha).cgColor,
            UIColor.clear.cgColor
        ]
    }

    /// Executes bottomFadeColors.
    private static func bottomFadeColors(traits: UITraitCollection) -> [CGColor] {
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color
        let target = colors.bgCanvas.resolvedColor(with: traits)
        let isDark = traits.userInterfaceStyle == .dark
        let midAlpha: CGFloat = isDark ? 0.68 : 0.55
        let endAlpha: CGFloat = isDark ? 0.90 : 0.78
        return [
            target.withAlphaComponent(0.0).cgColor,
            target.withAlphaComponent(midAlpha).cgColor,
            target.withAlphaComponent(endAlpha).cgColor
        ]
    }

    // MARK: - Noise Texture

    /// Executes noiseImage.
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
private final class HeaderGradientHostingView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyGradientIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyGradientIfNeeded()
    }

    func refreshGradient() {
        applyGradientIfNeeded()
    }

    private func applyGradientIfNeeded() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        TaskerHeaderGradient.apply(to: layer, bounds: bounds, traits: traitCollection)
    }
}

/// A SwiftUI view that renders the header gradient via UIKit layers.
@MainActor
public struct HeaderGradientView: UIViewRepresentable {
    /// Initializes a new instance.
    @ObservedObject private var themeManager = TaskerThemeManager.shared

    public init() {}

    /// Executes makeUIView.
    public func makeUIView(context: Context) -> UIView {
        let view = HeaderGradientHostingView()
        return view
    }

    /// Executes updateUIView.
    public func updateUIView(_ uiView: UIView, context: Context) {
        _ = themeManager.currentTheme.index
        if let hostingView = uiView as? HeaderGradientHostingView {
            hostingView.refreshGradient()
        } else {
            TaskerHeaderGradient.apply(to: uiView.layer, bounds: uiView.bounds, traits: uiView.traitCollection)
        }
    }
}
