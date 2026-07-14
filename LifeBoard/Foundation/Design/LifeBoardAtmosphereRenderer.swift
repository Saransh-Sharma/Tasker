import SwiftUI
import UIKit

public struct AmbientRenderingPolicy: Equatable, Sendable {
    public let requestedTier: AmbientRenderingTier
    public let effectiveTier: AmbientRenderingTier
    public let maximumParallax: CGFloat
    public let transitionDuration: TimeInterval
    public let allowsIdleMotion: Bool

    public static func resolve(
        requestedTier: AmbientRenderingTier,
        comfortProfile: LifeBoardComfortProfile,
        reduceMotion: Bool,
        lowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) -> AmbientRenderingPolicy {
        let constrained = reduceMotion || lowPowerMode || thermalState == .serious || thermalState == .critical
        let effectiveTier: AmbientRenderingTier
        if reduceMotion {
            effectiveTier = .static
        } else if constrained, requestedTier == .enhanced3D {
            effectiveTier = .ambient2D
        } else {
            effectiveTier = requestedTier
        }

        let maximumParallax: CGFloat
        let transitionDuration: TimeInterval
        let allowsIdleMotion: Bool
        switch comfortProfile {
        case .calm:
            maximumParallax = 0
            transitionDuration = 0.18
            allowsIdleMotion = false
        case .balanced:
            maximumParallax = constrained ? 0 : 4
            transitionDuration = 0.24
            allowsIdleMotion = constrained == false
        case .playful:
            maximumParallax = constrained ? 0 : 8
            transitionDuration = 0.28
            allowsIdleMotion = constrained == false
        }

        return AmbientRenderingPolicy(
            requestedTier: requestedTier,
            effectiveTier: effectiveTier,
            maximumParallax: maximumParallax,
            transitionDuration: transitionDuration,
            allowsIdleMotion: allowsIdleMotion && effectiveTier != .static
        )
    }
}

public struct LifeBoardAtmosphereView: View {
    public let daypart: ResolvedDaypart
    public let requestedTier: AmbientRenderingTier
    public let comfortProfile: LifeBoardComfortProfile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var powerRevision = 0

    public init(
        daypart: ResolvedDaypart,
        requestedTier: AmbientRenderingTier = .ambient2D,
        comfortProfile: LifeBoardComfortProfile = .balanced
    ) {
        self.daypart = daypart
        self.requestedTier = requestedTier
        self.comfortProfile = comfortProfile
    }

    public var body: some View {
        let policy = renderingPolicy
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: policy.allowsIdleMotion == false)) { timeline in
            GeometryReader { proxy in
                atmosphereCanvas(
                    size: proxy.size,
                    date: timeline.date,
                    policy: policy
                )
            }
        }
        .background(palette.color(for: .canvas))
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            powerRevision &+= 1
        }
    }

    private var palette: LifeBoardDaypartPalette {
        LifeBoardDaypartTokens.palette(for: daypart)
    }

    private var renderingPolicy: AmbientRenderingPolicy {
        _ = powerRevision
        return AmbientRenderingPolicy.resolve(
            requestedTier: requestedTier,
            comfortProfile: comfortProfile,
            reduceMotion: reduceMotion
        )
    }

    private func atmosphereCanvas(
        size: CGSize,
        date: Date,
        policy: AmbientRenderingPolicy
    ) -> some View {
        let phase = policy.allowsIdleMotion ? date.timeIntervalSinceReferenceDate : 0
        let drift = CGFloat(sin(phase / 7.5)) * policy.maximumParallax
        let lift = CGFloat(cos(phase / 9.0)) * policy.maximumParallax * 0.55

        return Canvas(rendersAsynchronously: true) { context, canvasSize in
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .linearGradient(
                    Gradient(colors: [
                        palette.color(for: .canvas),
                        palette.color(for: .canvasSecondary)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                )
            )

            let sunDiameter = max(canvasSize.width * 0.72, 260)
            let sunRect = CGRect(
                x: canvasSize.width * 0.18 + drift,
                y: -sunDiameter * 0.28 + lift,
                width: sunDiameter,
                height: sunDiameter
            )
            context.fill(
                Path(ellipseIn: sunRect),
                with: .radialGradient(
                    Gradient(colors: [
                        palette.color(for: .celestialCore),
                        palette.color(for: .celestialPrimary)
                    ]),
                    center: CGPoint(x: sunRect.midX, y: sunRect.midY),
                    startRadius: 4,
                    endRadius: sunDiameter * 0.52
                )
            )

            drawCloudLayer(
                in: &context,
                canvasSize: canvasSize,
                y: canvasSize.height * 0.16,
                drift: -drift * 0.5,
                color: palette.color(for: .layerOne),
                scale: 1.0
            )
            drawCloudLayer(
                in: &context,
                canvasSize: canvasSize,
                y: canvasSize.height * 0.24,
                drift: drift * 0.34,
                color: palette.color(for: .layerTwo),
                scale: 0.78
            )

            let mistRect = CGRect(
                x: canvasSize.width * 0.58 - drift,
                y: canvasSize.height * 0.18,
                width: canvasSize.width * 0.62,
                height: canvasSize.width * 0.48
            )
            context.fill(Path(ellipseIn: mistRect), with: .color(palette.color(for: .coolMist).opacity(0.72)))

            let grainOpacity = daypart == .night ? 0.025 : 0.018
            for index in 0..<96 {
                let x = pseudoRandom(index * 17 + 3) * canvasSize.width
                let y = pseudoRandom(index * 29 + 11) * canvasSize.height
                let diameter = 0.5 + pseudoRandom(index * 7 + 5) * 1.3
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                    with: .color(Color.white.opacity(grainOpacity))
                )
            }
        }
        .rotation3DEffect(
            policy.effectiveTier == .enhanced3D ? .degrees(drift * 0.18) : .zero,
            axis: (x: 0.12, y: 1, z: 0),
            perspective: 0.25
        )
        .scaleEffect(policy.effectiveTier == .enhanced3D ? 1.025 : 1)
        .clipped()
    }

    private func drawCloudLayer(
        in context: inout GraphicsContext,
        canvasSize: CGSize,
        y: CGFloat,
        drift: CGFloat,
        color: Color,
        scale: CGFloat
    ) {
        let diameter = canvasSize.width * 0.48 * scale
        for index in 0..<5 {
            let x = CGFloat(index) * diameter * 0.54 - diameter * 0.42 + drift
            let verticalOffset = index.isMultiple(of: 2) ? diameter * 0.12 : 0
            let rect = CGRect(x: x, y: y + verticalOffset, width: diameter, height: diameter)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.9)))
        }
    }

    private func pseudoRandom(_ seed: Int) -> CGFloat {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}

public struct LifeBoardPaperCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            .background(
                Color(LifeBoardColorTokens.foundationSurfaceSolid)
                    .opacity(reduceTransparency ? 1 : 0.94),
                in: RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous)
                    .stroke(
                        Color(LifeBoardColorTokens.foundationHairline)
                            .opacity(contrast == .increased ? 1 : 0.72),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            }
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow), radius: 6, y: 2)
    }
}

public extension View {
    func lifeBoardPaperCard() -> some View {
        modifier(LifeBoardPaperCardModifier())
    }
}
