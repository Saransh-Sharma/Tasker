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

    /// Executes scrimColors.
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

    /// Executes bottomFadeColors.
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
@MainActor
public struct HeaderGradientView: UIViewRepresentable {
    /// Initializes a new instance.
    @ObservedObject private var themeManager = TaskerThemeManager.shared

    public init() {}

    /// Executes makeUIView.
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    /// Executes updateUIView.
    public func updateUIView(_ uiView: UIView, context: Context) {
        _ = themeManager.currentTheme.index
        TaskerHeaderGradient.apply(to: uiView.layer, bounds: uiView.bounds, traits: uiView.traitCollection)
    }
}

// MARK: - Animated Gradient System (Calm Clarity)

public enum TaskerGradientDebugSettings {
    public static let disableMotionKey = "tasker.design.gradientMotionDisabled"

    public static var isMotionDisabled: Bool {
        UserDefaults.standard.bool(forKey: disableMotionKey)
    }

    public static func setMotionDisabled(_ disabled: Bool) {
        UserDefaults.standard.set(disabled, forKey: disableMotionKey)
    }
}

@MainActor
public struct TaskerAnimatedGradientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var themeManager = TaskerThemeManager.shared

    private let layerCount: Int
    private let cornerRadius: CGFloat
    private let usesDrawingGroup: Bool
    private let baseOpacity: CGFloat
    @State private var phase: CGFloat = 0
    @State private var cycleDuration: TimeInterval = 15
    @State private var didLogFallback = false

    public init(
        layerCount: Int = 2,
        cornerRadius: CGFloat = 0,
        baseOpacity: CGFloat = 1,
        usesDrawingGroup: Bool = false
    ) {
        self.layerCount = layerCount
        self.cornerRadius = cornerRadius
        self.baseOpacity = baseOpacity
        self.usesDrawingGroup = usesDrawingGroup
    }

    public var body: some View {
        let tokens = themeManager.currentTheme.tokens
        let motion = tokens.motion
        let colors = tokens.color
        let resolvedLayerCount = max(1, min(layerCount, motion.maxAnimatedGradientLayers))
        let shouldAnimate = !reduceMotion && !TaskerGradientDebugSettings.isMotionDisabled
        let opacity = reduceTransparency ? 1.0 : baseOpacity

        return ZStack {
            LinearGradient(
                colors: gradientColors(
                    primary: colors.accentPrimary,
                    secondary: colors.accentSecondary,
                    phase: shouldAnimate ? phase : 0,
                    saturationBias: 0.0
                ),
                startPoint: startPoint(for: 0, phase: shouldAnimate ? phase : 0),
                endPoint: endPoint(for: 0, phase: shouldAnimate ? phase : 0)
            )

            if resolvedLayerCount > 1 {
                LinearGradient(
                    colors: gradientColors(
                        primary: colors.accentSecondary,
                        secondary: colors.accentPrimary,
                        phase: shouldAnimate ? (1 - phase) : 0,
                        saturationBias: -0.4
                    ),
                    startPoint: startPoint(for: 1, phase: shouldAnimate ? phase : 0),
                    endPoint: endPoint(for: 1, phase: shouldAnimate ? phase : 0)
                )
                .opacity(0.42)
            }
        }
        .opacity(opacity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .modifier(TaskerGradientDrawingGroupModifier(enabled: usesDrawingGroup))
        .onAppear {
            if shouldAnimate {
                startAnimating()
            } else if !didLogFallback {
                logWarning(
                    "gradient_motion_fallback_triggered reduceMotion=\(reduceMotion) debugDisabled=\(TaskerGradientDebugSettings.isMotionDisabled)"
                )
                didLogFallback = true
            }
        }
        .onChange(of: themeManager.currentTheme.index) { _, _ in
            phase = 0
            didLogFallback = false
            if shouldAnimate {
                startAnimating()
            }
        }
        .onChange(of: reduceMotion) { _, _ in
            phase = 0
            didLogFallback = false
            if shouldAnimate {
                startAnimating()
            }
        }
        .onChange(of: TaskerGradientDebugSettings.isMotionDisabled) { _, _ in
            phase = 0
            didLogFallback = false
            if shouldAnimate {
                startAnimating()
            }
        }
    }

    private func startAnimating() {
        let motion = themeManager.currentTheme.tokens.motion
        cycleDuration = motion.gradientCycleDuration + .random(in: (-motion.gradientCycleRandomness)...motion.gradientCycleRandomness)
        phase = 0
        withAnimation(
            .easeInOut(duration: cycleDuration)
                .repeatForever(autoreverses: true)
        ) {
            phase = 1
        }
    }

    private func gradientColors(
        primary: UIColor,
        secondary: UIColor,
        phase: CGFloat,
        saturationBias: CGFloat
    ) -> [Color] {
        let motion = themeManager.currentTheme.tokens.motion
        let hueShift = sin(phase * .pi * 2) * motion.gradientHueShiftDegrees
        let saturationShift = sin((phase + 0.17 + saturationBias) * .pi * 2) * motion.gradientSaturationShiftPercent
        let opacityShift = sin((phase + 0.09) * .pi * 2) * motion.gradientOpacityDeltaMax

        let first = primary.taskerAdjustedColor(
            hueDegrees: hueShift,
            saturationPercent: saturationShift,
            opacityDelta: opacityShift
        )
        let second = secondary.taskerAdjustedColor(
            hueDegrees: -hueShift * 0.72,
            saturationPercent: -saturationShift * 0.66,
            opacityDelta: -opacityShift * 0.5
        )
        return [Color(uiColor: first), Color(uiColor: second)]
    }

    private func startPoint(for layer: Int, phase: CGFloat) -> UnitPoint {
        if layer == 0 {
            return UnitPoint(x: 0.18 + (0.08 * phase), y: 0.06 + (0.03 * phase))
        }
        return UnitPoint(x: 0.84 - (0.06 * phase), y: 0.18 + (0.04 * phase))
    }

    private func endPoint(for layer: Int, phase: CGFloat) -> UnitPoint {
        if layer == 0 {
            return UnitPoint(x: 0.82 - (0.06 * phase), y: 0.96 - (0.03 * phase))
        }
        return UnitPoint(x: 0.12 + (0.05 * phase), y: 0.90 - (0.04 * phase))
    }
}

private struct TaskerGradientDrawingGroupModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.compositingGroup().drawingGroup(opaque: false, colorMode: .extendedLinear)
        } else {
            content
        }
    }
}

public final class TaskerAnimatedGradientLayer: CAGradientLayer {
    private var configuredThemeIndex: Int?

    public func configure(
        theme: TaskerTheme,
        traits: UITraitCollection,
        respectsReduceMotion: Bool = true
    ) {
        frame = bounds
        startPoint = CGPoint(x: 0.15, y: 0.0)
        endPoint = CGPoint(x: 0.85, y: 1.0)
        cornerRadius = theme.tokens.corner.modal
        maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        colors = staticColors(theme: theme, traits: traits)
        locations = [0, 1]

        let shouldReduceMotion = respectsReduceMotion && (UIAccessibility.isReduceMotionEnabled || TaskerGradientDebugSettings.isMotionDisabled)
        if shouldReduceMotion {
            removeAllAnimations()
            logWarning("gradient_motion_fallback_triggered UIKit reduceMotion/debug toggle active")
            return
        }

        if configuredThemeIndex == theme.index { return }
        configuredThemeIndex = theme.index
        addMotionAnimations(theme: theme, traits: traits)
    }

    public func setStaticTransformRasterizationEnabled(_ enabled: Bool) {
        shouldRasterize = enabled
        rasterizationScale = UIScreen.main.scale
    }

    private func addMotionAnimations(theme: TaskerTheme, traits: UITraitCollection) {
        removeAllAnimations()
        let motion = theme.tokens.motion
        let duration = motion.gradientCycleDuration + .random(in: (-motion.gradientCycleRandomness)...motion.gradientCycleRandomness)

        let fromColors = staticColors(theme: theme, traits: traits)
        let toColors = shiftedColors(theme: theme, traits: traits)

        let colorAnimation = CABasicAnimation(keyPath: "colors")
        colorAnimation.fromValue = fromColors
        colorAnimation.toValue = toColors
        colorAnimation.duration = duration
        colorAnimation.autoreverses = true
        colorAnimation.repeatCount = .infinity
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        add(colorAnimation, forKey: "taskerGradientColors")

        let startAnimation = CABasicAnimation(keyPath: "startPoint")
        startAnimation.fromValue = NSValue(cgPoint: CGPoint(x: 0.15, y: 0.0))
        startAnimation.toValue = NSValue(cgPoint: CGPoint(x: 0.22, y: 0.04))
        startAnimation.duration = duration
        startAnimation.autoreverses = true
        startAnimation.repeatCount = .infinity
        startAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        add(startAnimation, forKey: "taskerGradientStartPoint")

        let endAnimation = CABasicAnimation(keyPath: "endPoint")
        endAnimation.fromValue = NSValue(cgPoint: CGPoint(x: 0.85, y: 1.0))
        endAnimation.toValue = NSValue(cgPoint: CGPoint(x: 0.78, y: 0.96))
        endAnimation.duration = duration
        endAnimation.autoreverses = true
        endAnimation.repeatCount = .infinity
        endAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        add(endAnimation, forKey: "taskerGradientEndPoint")
    }

    private func staticColors(theme: TaskerTheme, traits: UITraitCollection) -> [CGColor] {
        let tokens = theme.tokens.color
        return [
            tokens.accentPrimary.resolvedColor(with: traits).cgColor,
            tokens.accentSecondary.resolvedColor(with: traits).cgColor
        ]
    }

    private func shiftedColors(theme: TaskerTheme, traits: UITraitCollection) -> [CGColor] {
        let motion = theme.tokens.motion
        let tokens = theme.tokens.color
        let primary = tokens.accentPrimary.resolvedColor(with: traits)
        let secondary = tokens.accentSecondary.resolvedColor(with: traits)
        return [
            primary.taskerAdjustedColor(
                hueDegrees: motion.gradientHueShiftDegrees,
                saturationPercent: motion.gradientSaturationShiftPercent,
                opacityDelta: motion.gradientOpacityDeltaMax
            ).cgColor,
            secondary.taskerAdjustedColor(
                hueDegrees: -motion.gradientHueShiftDegrees * 0.72,
                saturationPercent: -motion.gradientSaturationShiftPercent * 0.72,
                opacityDelta: -motion.gradientOpacityDeltaMax * 0.5
            ).cgColor
        ]
    }
}

private extension UIColor {
    func taskerAdjustedColor(hueDegrees: CGFloat, saturationPercent: CGFloat, opacityDelta: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }

        let shiftedHue = ((hue * 360 + hueDegrees).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        let shiftedSaturation = max(0, min(1, saturation + (saturationPercent / 100)))
        let shiftedAlpha = max(0.08, min(1, alpha + opacityDelta))
        return UIColor(hue: shiftedHue, saturation: shiftedSaturation, brightness: brightness, alpha: shiftedAlpha)
    }
}
