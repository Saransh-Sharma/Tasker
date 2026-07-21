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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
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
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: policy.allowsIdleMotion == false || scenePhase != .active)) { timeline in
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
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            powerRevision &+= 1
        }
    }

    private var palette: LifeBoardDaypartPalette {
        LifeBoardDaypartTokens.appearancePalette(for: daypart, colorScheme: colorScheme)
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
                color: palette.color(for: .layerOne).opacity(reduceTransparency ? 1 : 0.94),
                scale: 1.0
            )
            drawCloudLayer(
                in: &context,
                canvasSize: canvasSize,
                y: canvasSize.height * 0.24,
                drift: drift * 0.34,
                color: palette.color(for: .layerTwo).opacity(reduceTransparency ? 1 : 0.9),
                scale: 0.78
            )

            let mistRect = CGRect(
                x: canvasSize.width * 0.58 - drift,
                y: canvasSize.height * 0.18,
                width: canvasSize.width * 0.62,
                height: canvasSize.width * 0.48
            )
            context.fill(
                Path(ellipseIn: mistRect),
                with: .color(palette.color(for: .coolMist).opacity(reduceTransparency ? 0.92 : 0.68))
            )

            let grainOpacity = reduceTransparency ? 0 : (daypart == .night ? 0.022 : 0.015)
            for index in 0..<(policy.effectiveTier == .static ? 48 : 72) {
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

public struct LifeBoardGlassSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(
                Color(LifeBoardColorTokens.foundationSurfaceSolid),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else if interactive {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

public extension View {
    func lifeBoardPaperCard() -> some View {
        modifier(LifeBoardPaperCardModifier())
    }

    func lifeBoardGlassSurface(cornerRadius: CGFloat = LifeBoardFoundationRadius.largeCard, interactive: Bool = false) -> some View {
        modifier(LifeBoardGlassSurfaceModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}

// MARK: - Clay surface primitives

/// Shared claymorphism surfaces: warm opaque fills, a soft top highlight, and
/// a low-opacity warm shadow. These are the only sanctioned content
/// elevations; glass remains reserved for chrome.
public extension View {
    func lifeBoardRaisedClayCard(
        palette: LifeBoardDaypartPalette,
        cornerRadius: CGFloat = 20
    ) -> some View {
        let isNight = palette.canvas == LifeBoardDaypartTokens.night.canvas
        let surface = isNight
            ? palette.color(for: .layerOne)
            : Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.94)
        return background(surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isNight ? 0.16 : 0.68), lineWidth: 1)
            }
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.12), radius: 8, y: 4)
    }

    func lifeBoardFloatingClayCard(
        palette: LifeBoardDaypartPalette,
        cornerRadius: CGFloat = 24
    ) -> some View {
        let isNight = palette.canvas == LifeBoardDaypartTokens.night.canvas
        let surface = isNight
            ? palette.color(for: .layerOne)
            : Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.97)
        return background(surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isNight ? 0.2 : 0.76), lineWidth: 1)
            }
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.17), radius: 18, y: 8)
    }

    func lifeBoardEmbeddedClayWell(
        palette: LifeBoardDaypartPalette,
        cornerRadius: CGFloat = 14
    ) -> some View {
        let isNight = palette.canvas == LifeBoardDaypartTokens.night.canvas
        let surface = isNight
            ? palette.color(for: .layerTwo)
            : palette.color(for: .canvasSecondary).opacity(0.72)
        return background(surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(LifeBoardColorTokens.foundationHairline).opacity(0.72), lineWidth: 1)
            }
    }
}

// MARK: - Metric ring

/// The shared circular signal used by Home, Track, and Insights. Values
/// animate only when they change; empty and setup states stay visually and
/// semantically distinct from an honest zero.
public struct LifeBoardMetricRing: View {
    public enum RingState: Equatable, Sendable {
        case loading
        case setupRequired
        case value(progress: Double, centerText: String)
        case complete(centerText: String)
    }

    private let label: String
    private let state: RingState
    private let diameter: CGFloat
    private let palette: LifeBoardDaypartPalette
    /// When set, the interior renders a rising liquid surface (hydration,
    /// fasting) instead of staying empty — the ported wave fill.
    private let liquidTint: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        label: String,
        state: RingState,
        diameter: CGFloat = 60,
        palette: LifeBoardDaypartPalette,
        liquidTint: Color? = nil
    ) {
        self.label = label
        self.state = state
        self.diameter = diameter
        self.palette = palette
        self.liquidTint = liquidTint
    }

    private var progress: Double {
        switch state {
        case .loading, .setupRequired: 0
        case .value(let progress, _): min(1, max(0, progress))
        case .complete: 1
        }
    }

    private var centerText: String? {
        switch state {
        case .loading: nil
        case .setupRequired: nil
        case .value(_, let text), .complete(let text): text
        }
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        Color(LifeBoardColorTokens.metricRingTrack),
                        style: StrokeStyle(
                            lineWidth: 5,
                            dash: state == .setupRequired ? [3, 5] : []
                        )
                    )
                if let liquidTint, state != .loading, state != .setupRequired {
                    LifeBoardLiquidFill(level: progress, tint: liquidTint)
                        .clipShape(Circle().inset(by: 4))
                        .allowsHitTesting(false)
                }
                if case .loading = state {
                    ProgressView().controlSize(.small)
                } else if state != .setupRequired {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.86),
                            value: progress
                        )
                }
                if let centerText {
                    Text(centerText)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                } else if state == .setupRequired {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
            }
            .frame(width: diameter, height: diameter)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValueText)
    }

    private var ringColor: Color {
        if case .complete = state {
            return Color(LifeBoardColorTokens.foundationSageAccent)
        }
        return Color(LifeBoardColorTokens.metricRingFill)
    }

    private var accessibilityValueText: String {
        switch state {
        case .loading: "Loading"
        case .setupRequired: "Set up"
        case .value(let progress, let text): "\(text), \(Int((min(1, max(0, progress)) * 100).rounded())) percent"
        case .complete(let text): "\(text), complete"
        }
    }
}
