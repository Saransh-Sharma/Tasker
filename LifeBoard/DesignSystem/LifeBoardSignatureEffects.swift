import SwiftUI
import UIKit
@preconcurrency import Metal
/// A compact action surface that morphs around real asynchronous state.
/// Interaction concepts were adapted from Shubham Kumar Singh's Apache-2.0
/// SwiftUI-Animations SubmitView/DownloadButton examples and substantially
/// rewritten for cancellable domain work and LifeBoard accessibility policy.
public struct AsyncActionControl<Receipt: Equatable & Sendable>: View {
    public let title: String
    public let runningTitle: String
    public let successTitle: String
    public let phase: AsyncActionPhase<Receipt>
    public let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        runningTitle: String,
        successTitle: String,
        phase: AsyncActionPhase<Receipt>,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.runningTitle = runningTitle
        self.successTitle = successTitle
        self.phase = phase
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                statusIcon
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .contentTransition(.symbolEffect(.replace))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.bordered)
        .animation(
            MotionOverride.resolve(reduceMotion) ? nil : .spring(response: 0.32, dampingFraction: 0.84),
            value: label
        )
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch phase {
        case .idle:
            Image(systemName: "arrow.up.doc")
        case .running(let progress):
            if let progress {
                ProgressView(value: progress).frame(width: 18, height: 18)
            } else {
                ProgressView().controlSize(.small)
            }
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lifeboard(.statusSuccess))
        case .recoverableFailure:
            Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(Color.lifeboard(.statusWarning))
        case .cancelled:
            Image(systemName: "xmark.circle")
        }
    }

    private var label: String {
        switch phase {
        case .idle: title
        case .running: runningTitle
        case .success: successTitle
        case .recoverableFailure: "Try again"
        case .cancelled: title
        }
    }

    private var accessibilityValue: String {
        switch phase {
        case .idle: "Ready"
        case .running(let progress): progress.map { "\(Int($0 * 100)) percent" } ?? "In progress"
        case .success: "Complete"
        case .recoverableFailure(let failure): failure.message
        case .cancelled: "Cancelled"
        }
    }
}

/// A restrained two-page indicator that exists only while Journal work is active.
/// The page concept was adapted from the Apache-2.0 SwiftUI-Animations BookLoader
/// example and rewritten to pause completely outside real work and under Reduce Motion.
public struct JournalWorkIndicator: View {
    public let isActive: Bool
    public let progress: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    public init(isActive: Bool, progress: Double? = nil) {
        self.isActive = isActive
        self.progress = progress
    }

    public var body: some View {
        Group {
            if isActive {
                if MotionOverride.resolve(reduceMotion) || scenePhase != .active {
                    staticPages(turn: progress ?? 0.5)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 24)) { context in
                        let turn = progress ?? context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 1.2) / 1.2
                        staticPages(turn: turn)
                    }
                }
            }
        }
        .frame(width: 30, height: 24)
        .accessibilityHidden(true)
    }

    private func staticPages(turn: Double) -> some View {
        let normalized = min(1, max(0, turn))
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(.secondary.opacity(0.20))
                .frame(width: 26, height: 18)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(.primary.opacity(0.78))
                .frame(width: 13, height: 18)
                .rotation3DEffect(.degrees(-12 + (24 * normalized)), axis: (x: 0, y: 1, z: 0), anchor: .leading)
                .offset(x: 6)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(.primary.opacity(0.52))
                .frame(width: 13, height: 18)
                .rotation3DEffect(.degrees(12 - (24 * normalized)), axis: (x: 0, y: 1, z: 0), anchor: .trailing)
                .offset(x: -6)
        }
    }
}

/// A short, low-amplitude confirmation ripple for real committed actions.
/// The effect is intentionally local to the control and disappears entirely
/// under Reduce Motion, Low Power, thermal pressure, or an inactive scene.
private struct ConfirmationRippleModifier: ViewModifier {
    let trigger: Int
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @State private var startDate: Date?

    private let duration: TimeInterval = 0.38

    func body(content: Content) -> some View {
        content
            .overlay { ripple }
            .clipped()
            .onChange(of: trigger) { _, _ in
                let policy = MotionPolicy.resolve(
                    reduceMotion: MotionOverride.resolve(reduceMotion),
                    reduceTransparency: reduceTransparency,
                    sceneIsActive: scenePhase == .active
                )
                startDate = policy.allowsSpatialMotion && policy.usesOpaqueSurfaces == false ? Date() : nil
            }
    }

    @ViewBuilder
    private var ripple: some View {
        if let startDate {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                if elapsed <= duration {
                    let progress = max(0, min(1, elapsed / duration))
                    Circle()
                        .stroke(tint.opacity(0.30 * (1 - progress)), lineWidth: 2)
                        .padding(5)
                        .scaleEffect(0.30 + (0.70 * progress))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

/// The bounded signature Metal effects from the premium redesign brief:
/// `daypartBloom`, `evaInkReveal`, `journalMediaReveal`, `memoryDevelopReveal`, and
/// `fastingEmberRing`, `healthSyncPulse`, and `vitalOrbWarp`. Each enhances an existing state,
/// compiles asynchronously before first use, and degrades to a plain opacity/scale fallback under
/// Reduce Motion, Low Power, thermal pressure, Reduce Transparency, or when the flag is off.
@MainActor
public enum SignatureShaders {
    public enum PreloadState: Equatable, Sendable {
        case idle
        case loading
        case ready(functionCount: Int, durationMilliseconds: Double)
        case unavailable(reason: String)
    }

    private enum PreloadResult: Sendable {
        case ready(functionCount: Int, durationMilliseconds: Double)
        case unavailable(reason: String)
    }

    public private(set) static var preloadState: PreloadState = .idle
    private static var preloadTask: Task<Void, Never>?

    public static let functionNames = [
        "LifeBoardDaypartBloom",
        "LifeBoardEvaInkReveal",
        "LifeBoardJournalMediaReveal",
        "LifeBoardMemoryDevelopReveal",
        "LifeBoardFastingEmberRing",
        "LifeBoardHealthSyncPulse",
        "LifeBoardVitalOrbWarp",
        "LifeBoardClayPressBloom",
        "LifeBoardDaypartCrossDissolve",
        "LifeBoardCompletionBurst",
        "LifeBoardContextLens",
        "LifeBoardChartRevealSweep",
        "LifeBoardLiquidGlassRefract",
        "LifeBoardCardMorphWarp",
        "LifeBoardFirstLight",
        "LifeBoardPaperGrain",
        "LifeBoardDissolveAway",
        "LifeBoardTriageSettle",
        "LifeBoardTaskLandingCaustic",
        "LifeBoardValueDrumWarp",
        "LifeBoardRootTravelShear",
        "LifeBoardAmbientDrift",
        // Lives in LifeBoardCTABezel.metal rather than the signature library,
        // but it is loaded from the same default library and must be verified
        // by the same warm-up — it was the one shader nothing checked for.
        "LifeBoardLiquidMetalBezel"
    ]

    /// Whether custom shaders may run at all right now (flag + energy/thermal, not accessibility —
    /// accessibility is handled per-modifier so Reduce Transparency can still allow a static tint).
    public static var performancePermits: Bool {
        guard V2FeatureFlags.signatureShadersEnabled else { return false }
        let thermal = ProcessInfo.processInfo.thermalState
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return false }
        if thermal == .serious || thermal == .critical { return false }
        return true
    }

    /// Rendering begins only after every named function has been materialized.
    /// A missing/default-library failure therefore degrades to the caller's
    /// ordinary SwiftUI transition instead of attempting a broken shader.
    ///
    /// See `SignatureShaderComfortGate.swift` for why the comfort gate is folded
    /// in here and not into `performancePermits`, and for what is deliberately
    /// left to the individual modifiers.
    public static var isReadyForRendering: Bool {
        performancePermits && ShaderReadiness.comfortPermits && preloadDidFinish
    }

    static var preloadDidFinish: Bool {
        if case .ready = preloadState { return true }
        return false
    }

    /// Loads the app's already-compiled Metal library and materializes every signature function
    /// away from the main actor. SwiftUI does not expose its private stitched render pipeline, so
    /// this deliberately stops at the supported public boundary instead of rasterizing hidden UI.
    /// The measured result is retained for diagnostics and makes repeated calls idempotent.
    public static func warmUp() {
        guard performancePermits else {
            // Publishing on this path matters in both directions. Returning
            // silently used to leave `preloadState` at `.idle` with
            // `engineReady` never set on a cold start; worse, when the device
            // *entered* Low Power the power-state observer re-entered here, hit
            // this guard, and left `engineReady` still `true` — so hero glass
            // and every Metal effect kept drawing under exactly the constraint
            // they were supposed to respect.
            publishEngineReadiness(reason: performanceBlockReason)
            return
        }
        // A previous verdict of `.unavailable` must not be terminal: it is
        // reachable purely from transient state, and the power/thermal
        // observers plus scene activation call back in when that state clears.
        if case .unavailable = preloadState { preloadTask = nil }
        guard preloadTask == nil else { return }
        guard preloadDidFinish == false else {
            publishEngineReadiness()
            return
        }

        preloadState = .loading
        let names = functionNames
        let task = Task.detached(priority: .utility) { () -> PreloadResult in
            let clock = ContinuousClock()
            let started = clock.now

            guard let device = MTLCreateSystemDefaultDevice() else {
                return .unavailable(reason: "Metal is unavailable on this device.")
            }

            do {
                let library = try device.makeDefaultLibrary(bundle: .main)
                for name in names where library.makeFunction(name: name) == nil {
                    return .unavailable(reason: "Compiled shader function \(name) is missing.")
                }
                let elapsed = started.duration(to: clock.now)
                let milliseconds = Double(elapsed.components.seconds) * 1_000
                    + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
                return .ready(functionCount: names.count, durationMilliseconds: milliseconds)
            } catch {
                return .unavailable(reason: "Unable to load compiled signature shaders: \(error.localizedDescription)")
            }
        }

        preloadTask = Task {
            let result = await task.value
            switch result {
            case .ready(let count, let duration):
                preloadState = .ready(functionCount: count, durationMilliseconds: duration)
            case .unavailable(let reason):
                preloadState = .unavailable(reason: reason)
            }
            publishEngineReadiness()
            preloadTask = nil
        }
    }

}

extension SignatureShaders {
    /// Shared `Color` → shader float3. Each modifier used to carry its own private copy.
    static func components(of color: Color) -> (Float, Float, Float) {
        let ui = UIColor(color)
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }

    static func tintComponents(for daypart: ResolvedDaypart) -> (Float, Float, Float) {
        switch daypart {
        case .morning: return (1.0, 0.86, 0.62)
        case .afternoon: return (1.0, 0.94, 0.78)
        case .evening: return (0.98, 0.72, 0.58)
        case .night: return (0.72, 0.78, 0.95)
        }
    }
}

// MARK: - daypartBloom

struct DaypartBloomModifier: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    let tint: Color
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    @State private var startDate: Date?

    private let duration: TimeInterval = 0.6

    func body(content: Content) -> some View {
        content
            .overlay { bloomOverlay }
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive, SignatureShaders.isReadyForRendering else { return }
                startDate = Date()
            }
    }

    @ViewBuilder
    private var bloomOverlay: some View {
        if let startDate, sceneIsActive, SignatureShaders.isReadyForRendering, reduceMotion == false, reduceTransparency == false {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                if elapsed <= duration {
                    let progress = Float(elapsed / duration)
                    let intensity = 1.0 - progress
                    GeometryReader { proxy in
                        let (r, g, b) = tintValues
                        Rectangle()
                            .fill(.clear)
                            .colorEffect(Shader(
                                function: ShaderFunction(library: .default, name: "LifeBoardDaypartBloom"),
                                arguments: [
                                    .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                    .float2(Float(center.x), Float(center.y)),
                                    .float(progress),
                                    .float(intensity),
                                    .float3(r, g, b)
                                ]
                            ))
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                } else {
                    Color.clear
                }
            }
        } else if reduceMotion, let startDate, ProcessInfo.processInfo.isLowPowerModeEnabled == false {
            // Reduce Motion fallback: a brief, non-simulated tint fade — no depth or movement.
            ReduceMotionBloomFallback(startDate: startDate, tint: tint)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var tintValues: (Float, Float, Float) {
        let ui = UIColor(tint)
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }
}

private struct ReduceMotionBloomFallback: View {
    let startDate: Date
    let tint: Color

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let opacity = elapsed <= 0.45 ? (0.28 * (1.0 - elapsed / 0.45)) : 0
            tint.opacity(opacity)
        }
    }
}

// MARK: - evaInkReveal

@MainActor
struct EvaInkRevealModifier: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    let newContentFraction: Double
    let tint: Color
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    @State private var appearDate = Date()

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        if progress >= 1.0 || reduceTransparency || sceneIsActive == false || SignatureShaders.isReadyForRendering == false {
            // Settled or degraded: fully static text, no shimmer.
            content
        } else if reduceMotion {
            content.opacity(0.92 + progress * 0.08)
        } else {
            TimelineView(.animation) { context in
                let time = Float(context.date.timeIntervalSince(appearDate))
                let (r, g, b) = tintValues
                content
                    .colorEffect(Shader(
                        function: ShaderFunction(library: .default, name: "LifeBoardEvaInkReveal"),
                        arguments: [
                            .boundingRect,
                            .float(Float(progress)),
                            .float(Float(min(1, max(0, newContentFraction)))),
                            .float(time),
                            .float3(r, g, b)
                        ]
                    ))
            }
        }
    }

    private var tintValues: (Float, Float, Float) {
        let ui = UIColor(tint)
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }
}

// MARK: - journalMediaReveal

@MainActor
struct JournalMediaRevealModifier: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        if progress >= 1.0 || reduceTransparency || sceneIsActive == false || SignatureShaders.isReadyForRendering == false {
            content
        } else if reduceMotion {
            // Reduce Motion: simple cross-fade instead of an aperture.
            content.opacity(progress)
        } else {
            content
                .layerEffect(
                    Shader(
                        function: ShaderFunction(library: .default, name: "LifeBoardJournalMediaReveal"),
                        arguments: [.boundingRect, .float(Float(progress))]
                    ),
                    maxSampleOffset: CGSize(width: 24, height: 24)
                )
        }
    }
}

// MARK: - memoryDevelopReveal

@MainActor
private struct MemoryDevelopRevealModifier: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let settled = min(1, max(0, progress))
        if settled >= 1 || reduceTransparency || sceneIsActive == false || SignatureShaders.isReadyForRendering == false {
            content
        } else if reduceMotion {
            content.opacity(settled)
        } else {
            content.colorEffect(
                Shader(
                    function: ShaderFunction(library: .default, name: "LifeBoardMemoryDevelopReveal"),
                    arguments: [.boundingRect, .float(Float(settled))]
                )
            )
        }
    }
}

// MARK: - fastingEmberRing

@MainActor
private struct FastingEmberRingModifier: ViewModifier {
    let progress: Double
    let tint: Color
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    func body(content: Content) -> some View {
        if reduceMotion || reduceTransparency || sceneIsActive == false || SignatureShaders.isReadyForRendering == false {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: sceneIsActive == false)) { context in
                let time = Float(
                    context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 120)
                )
                let (r, g, b) = tintValues
                content.colorEffect(
                    Shader(
                        function: ShaderFunction(library: .default, name: "LifeBoardFastingEmberRing"),
                        arguments: [
                            .boundingRect,
                            .float(Float(min(1, max(0, progress)))),
                            .float(time),
                            .float3(r, g, b)
                        ]
                    )
                )
            }
        }
    }

    private var tintValues: (Float, Float, Float) {
        let color = UIColor(tint)
        var r: CGFloat = 1, g: CGFloat = 0.65, b: CGFloat = 0.28, a: CGFloat = 1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }
}

// MARK: - healthSyncPulse / vitalOrbWarp

@MainActor
private struct HealthSyncPulseModifier: ViewModifier {
    let trigger: Int
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool
    @State private var startDate: Date?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let startDate {
                    TimelineView(.animation) { context in
                        let progress = min(1, context.date.timeIntervalSince(startDate) / 0.52)
                        if reduceMotion || reduceTransparency || sceneIsActive == false || SignatureShaders.isReadyForRendering == false {
                            Color.lifeboard(.statusSuccess)
                                .opacity(0.12 * (1 - progress))
                                .scaleEffect(0.98 + progress * 0.02)
                        } else {
                            GeometryReader { proxy in
                                Rectangle()
                                    .fill(.clear)
                                    .colorEffect(Shader(
                                        function: ShaderFunction(library: .default, name: "LifeBoardHealthSyncPulse"),
                                        arguments: [
                                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                            .float(Float(progress)),
                                            .float3(0.30, 0.82, 0.58)
                                        ]
                                    ))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .clipped()
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive else { return }
                startDate = Date()
            }
    }
}

@MainActor
private struct VitalOrbWarpModifier: ViewModifier {
    let trigger: Int
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool
    @State private var startDate: Date?

    func body(content: Content) -> some View {
        Group {
            if let startDate {
                TimelineView(.animation) { context in
                    let progress = min(1, context.date.timeIntervalSince(startDate) / 0.42)
                    if reduceMotion || reduceTransparency || sceneIsActive == false || SignatureShaders.isReadyForRendering == false {
                        content.scaleEffect(0.985 + progress * 0.015)
                    } else {
                        content.visualEffect { effect, proxy in
                            effect.distortionEffect(
                                Shader(
                                    function: ShaderFunction(library: .default, name: "LifeBoardVitalOrbWarp"),
                                    arguments: [
                                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                        .float(Float(progress))
                                    ]
                                ),
                                maxSampleOffset: CGSize(width: 6, height: 6)
                            )
                        }
                    }
                }
            } else {
                content
            }
        }
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive else { return }
                startDate = Date()
            }
    }
}

// MARK: - Context lens

/// A single bounded refraction used when context moves into capture or Eva.
/// Callers attach it to a background/control plane; readable content is never distorted.
@MainActor
private struct ContextLensModifier: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool
    @State private var startDate: Date?

    private let duration: TimeInterval = 0.38

    func body(content: Content) -> some View {
        Group {
            if let startDate {
                TimelineView(.animation) { context in
                    let progress = min(1, context.date.timeIntervalSince(startDate) / duration)
                    if usesFallback {
                        content.opacity(0.96 + (0.04 * progress))
                    } else {
                        content.visualEffect { effect, proxy in
                            effect.distortionEffect(
                                Shader(
                                    function: ShaderFunction(library: .default, name: "LifeBoardContextLens"),
                                    arguments: [
                                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                        .float2(Float(center.x), Float(center.y)),
                                        .float(Float(progress))
                                    ]
                                ),
                                maxSampleOffset: CGSize(width: 8, height: 8)
                            )
                        }
                    }
                }
            } else {
                content
            }
        }
        .onChange(of: trigger) { _, _ in
            guard sceneIsActive else { return }
            startDate = Date()
        }
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - View sugar

public extension View {
    /// Plays only when `trigger` changes after a real action commits.
    func lifeboardConfirmationRipple(trigger: Int, tint: Color = .white) -> some View {
        modifier(ConfirmationRippleModifier(trigger: trigger, tint: tint))
    }

    /// Plays a radial daypart bloom over this surface each time `trigger` changes.
    @MainActor
    func lifeboardDaypartBloom(center: UnitPoint = .center, trigger: Int, daypart: ResolvedDaypart) -> some View {
        let (r, g, b) = SignatureShaders.tintComponents(for: daypart)
        return modifier(DaypartBloomModifierEnvironment(center: center, trigger: trigger, tint: Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b))))
    }

    /// LifeBoard's signature phase-change moment. The existing bounded Metal
    /// bloom is deliberately reused so the atmosphere receives one light tide
    /// without introducing a second render pipeline or touching foreground UI.
    @MainActor
    func lifeboardCelestialTide(
        center: UnitPoint,
        trigger: Int,
        daypart: ResolvedDaypart
    ) -> some View {
#if targetEnvironment(macCatalyst)
        // The landscape/celestial layers still receive their bounded SwiftUI
        // crossfade and scale interpolation. Catalyst intentionally skips the
        // stitched ripple until a separately profiled renderer gate exists.
        self
#else
        lifeboardDaypartBloom(center: center, trigger: trigger, daypart: daypart)
#endif
    }

    /// Applies the Eva ink-reveal shimmer over freshly streamed text. `progress` 0→1 settles it.
    @MainActor
    func lifeboardEvaInkReveal(
        progress: Double,
        newContentFraction: Double = 1,
        tint: Color = .white
    ) -> some View {
        modifier(EvaInkRevealModifierEnvironment(
            progress: progress,
            newContentFraction: newContentFraction,
            tint: tint
        ))
    }

    /// Reveals protected media with a soft aperture. `progress` 0 (closed) → 1 (open).
    @MainActor
    func lifeboardJournalMediaReveal(progress: Double) -> some View {
        modifier(JournalMediaRevealModifierEnvironment(progress: progress))
    }

    /// Develops a user-opened memory once from warm paper into full color.
    @MainActor
    func lifeboardMemoryDevelopReveal(progress: Double) -> some View {
        modifier(MemoryDevelopRevealModifierEnvironment(progress: progress))
    }

    /// Adds the restrained active-state ember used only by the fasting progress ring.
    @MainActor
    func lifeboardFastingEmberRing(progress: Double, tint: Color) -> some View {
        modifier(FastingEmberRingModifierEnvironment(progress: progress, tint: tint))
    }

    /// One-shot Health authorization/manual-sync confirmation.
    @MainActor
    func lifeboardHealthSyncPulse(trigger: Int) -> some View {
        modifier(HealthSyncPulseModifierEnvironment(trigger: trigger))
    }

    /// Brief deformation for a direct vital interaction or first daily goal crossing.
    @MainActor
    func lifeboardVitalOrbWarp(trigger: Int) -> some View {
        modifier(VitalOrbWarpModifierEnvironment(trigger: trigger))
    }

    /// One-shot contextual handoff. Apply only to a background or control plane.
    @MainActor
    func lifeboardContextLens(center: UnitPoint = .topTrailing, trigger: Int) -> some View {
        modifier(ContextLensModifierEnvironment(center: center, trigger: trigger))
    }

    /// Draws a chart or sparkline in behind a travelling mask. Mask only — it
    /// never tints or moves the data, so values stay readable throughout.
    @MainActor
    func lifeboardChartRevealSweep(progress: Double) -> some View {
        modifier(ChartRevealSweepModifierEnvironment(progress: progress))
    }

    /// A one-shot directional warmth beneath the Inbox deck after a real triage
    /// decision. Positive direction travels forward/right; negative direction
    /// reverses for Skip. The plane is fully static outside the bounded pulse.
    @MainActor
    func lifeboardTriageSettle(trigger: Int, direction: Double) -> some View {
        modifier(TriageSettleModifierEnvironment(trigger: trigger, direction: direction))
    }

    /// One bounded caustic beneath a day after a task placement persists.
    @MainActor
    func lifeboardTaskLandingCaustic(
        trigger: Int,
        center: UnitPoint = .center,
        tint: Color = Color(SemanticColorTokens.foundationApricotAccent)
    ) -> some View {
        modifier(TaskLandingCausticModifierEnvironment(
            trigger: trigger,
            center: center,
            tint: tint
        ))
    }

    /// Refracts content beneath a moving selection well. Control plane only.
    @MainActor
    func lifeboardLiquidGlassRefract(center: UnitPoint, radius: Double, strength: Double) -> some View {
        modifier(LiquidGlassRefractModifierEnvironment(center: center, radius: radius, strength: strength))
    }

    /// Eases the background plane out of the way during a card-to-detail zoom.
    /// Never apply to the card itself; text and charts must not distort.
    @MainActor
    func lifeboardCardMorphWarp(origin: UnitPoint, trigger: Int) -> some View {
        modifier(CardMorphWarpModifierEnvironment(origin: origin, trigger: trigger))
    }

    /// Static warm tooth for large canvas areas. Never animates.
    @MainActor
    func lifeboardPaperGrain(intensity: Double = 1) -> some View {
        modifier(PaperGrainModifierEnvironment(intensity: intensity))
    }

    /// Erodes a completed row away instead of fading it.
    @MainActor
    func lifeboardDissolveAway(progress: Double, tint: Color) -> some View {
        modifier(DissolveAwayModifierEnvironment(progress: progress, tint: tint))
    }

    /// One warm sweep across a surface as the morning is committed to.
    ///
    /// Fires on the persisted-state boundary, never on selection — the light is
    /// the day starting, not a preview of it.
    @MainActor
    func lifeboardFirstLight(trigger: Int, tint: Color) -> some View {
        modifier(FirstLightModifierEnvironment(trigger: trigger, tint: tint))
    }
}

// MARK: - triageSettle

private struct TriageSettleModifierEnvironment: ViewModifier {
    let trigger: Int
    let direction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.modifier(TriageSettleModifier(
            trigger: trigger,
            direction: direction,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct TriageSettleModifier: ViewModifier {
    let trigger: Int
    let direction: Double
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    @State private var startDate: Date?
    private let duration: TimeInterval = 0.48

    func body(content: Content) -> some View {
        content
            .overlay { settlePlane }
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive else { return }
                startDate = Date()
            }
    }

    @ViewBuilder
    private var settlePlane: some View {
        if let startDate, sceneIsActive {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                if elapsed <= duration {
                    let progress = max(0, min(1, elapsed / duration))
                    if usesFallback {
                        Color(SemanticColorTokens.foundationApricotAccent)
                            .opacity(0.16 * sin(progress * .pi))
                    } else {
                        GeometryReader { proxy in
                            Color.white.opacity(0.001)
                                .colorEffect(Shader(
                                    function: ShaderFunction(
                                        library: .default,
                                        name: "LifeBoardTriageSettle"
                                    ),
                                    arguments: [
                                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                        .float(Float(progress)),
                                        .float(Float(direction >= 0 ? 1 : -1)),
                                        .float3(0.94, 0.47, 0.25)
                                    ]
                                ))
                        }
                    }
                } else {
                    Color.clear
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var usesFallback: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        reduceMotion || reduceTransparency
            || SignatureShaders.isReadyForRendering == false
#endif
    }
}

// MARK: - taskLandingCaustic

private struct TaskLandingCausticModifierEnvironment: ViewModifier {
    let trigger: Int
    let center: UnitPoint
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.modifier(TaskLandingCausticModifier(
            trigger: trigger,
            center: center,
            tint: tint,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct TaskLandingCausticModifier: ViewModifier {
    let trigger: Int
    let center: UnitPoint
    let tint: Color
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    @State private var startDate: Date?
    private let duration: TimeInterval = 0.42

    func body(content: Content) -> some View {
        content
            .background { causticPlane }
            .clipped()
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive else { return }
                startDate = Date()
            }
    }

    @ViewBuilder
    private var causticPlane: some View {
        if let startDate, sceneIsActive {
            TimelineView(.animation) { context in
                let progress = max(0, min(1, context.date.timeIntervalSince(startDate) / duration))
                if progress >= 1 {
                    Color.clear
                        .task { self.startDate = nil }
                } else if usesFallback {
                    tint.opacity(0.10 * sin(progress * .pi))
                } else {
                    GeometryReader { proxy in
                        let components = SignatureShaders.components(of: tint)
                        Color.white.opacity(0.001)
                            .colorEffect(Shader(
                                function: ShaderFunction(
                                    library: .default,
                                    name: "LifeBoardTaskLandingCaustic"
                                ),
                                arguments: [
                                    .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                    .float2(Float(center.x), Float(center.y)),
                                    .float(Float(progress)),
                                    .float3(components.0, components.1, components.2)
                                ]
                            ))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - chartRevealSweep

private struct ChartRevealSweepModifierEnvironment: ViewModifier {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(ChartRevealSweepModifier(
            progress: progress,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct ChartRevealSweepModifier: ViewModifier {
    let progress: Double
    let reduceMotion: Bool
    let sceneIsActive: Bool

    func body(content: Content) -> some View {
        // A settled chart carries no shader at all, so there is no residual
        // GPU work once the reveal finishes.
        if usesFallback || progress >= 0.999 {
            content.opacity(usesFallback ? 1 : 1)
        } else {
            content.layerEffect(
                Shader(
                    function: ShaderFunction(library: .default, name: "LifeBoardChartRevealSweep"),
                    arguments: [
                        .float2(1, 1),
                        .float(Float(max(0, min(1, progress)))),
                        .float(0.16)
                    ]
                ),
                maxSampleOffset: .zero
            )
        }
    }

    private var usesFallback: Bool {
        reduceMotion || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - liquidGlassRefract

private struct LiquidGlassRefractModifierEnvironment: ViewModifier {
    let center: UnitPoint
    let radius: Double
    let strength: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(LiquidGlassRefractModifier(
            center: center,
            radius: radius,
            strength: strength,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct LiquidGlassRefractModifier: ViewModifier {
    let center: UnitPoint
    let radius: Double
    let strength: Double
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    func body(content: Content) -> some View {
        if usesFallback || strength <= 0.001 {
            content
        } else {
            content.visualEffect { effect, proxy in
                effect.distortionEffect(
                    Shader(
                        function: ShaderFunction(library: .default, name: "LifeBoardLiquidGlassRefract"),
                        arguments: [
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float2(Float(center.x), Float(center.y)),
                            .float(Float(radius)),
                            .float(Float(strength))
                        ]
                    ),
                    maxSampleOffset: CGSize(width: 6, height: 6)
                )
            }
        }
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - cardMorphWarp

private struct CardMorphWarpModifierEnvironment: ViewModifier {
    let origin: UnitPoint
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(CardMorphWarpModifier(
            origin: origin,
            trigger: trigger,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct CardMorphWarpModifier: ViewModifier {
    let origin: UnitPoint
    let trigger: Int
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool
    @State private var startDate: Date?

    private let duration: TimeInterval = 0.38

    func body(content: Content) -> some View {
        Group {
            if let startDate, usesFallback == false {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let progress = min(1, elapsed / duration)
                    content.visualEffect { effect, proxy in
                        effect.distortionEffect(
                            Shader(
                                function: ShaderFunction(library: .default, name: "LifeBoardCardMorphWarp"),
                                arguments: [
                                    .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                    .float2(Float(origin.x), Float(origin.y)),
                                    .float(Float(progress))
                                ]
                            ),
                            maxSampleOffset: CGSize(width: 8, height: 8)
                        )
                    }
                    .task(id: progress >= 1) {
                        // Drop the timeline the moment the pass completes so no
                        // shader work survives the transition.
                        if progress >= 1 { self.startDate = nil }
                    }
                }
            } else {
                content
            }
        }
        .onChange(of: trigger) { _, _ in
            guard sceneIsActive, usesFallback == false else { return }
            startDate = Date()
        }
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - paperGrain

private struct PaperGrainModifierEnvironment: ViewModifier {
    let intensity: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.modifier(PaperGrainModifier(
            intensity: intensity,
            reduceTransparency: reduceTransparency,
            increasedContrast: contrast == .increased
        ))
    }
}

struct PaperGrainModifier: ViewModifier {
    let intensity: Double
    let reduceTransparency: Bool
    let increasedContrast: Bool

    func body(content: Content) -> some View {
        // Grain is texture, not information. Increased Contrast removes it so
        // it can never eat into a text/background ratio.
        if increasedContrast || reduceTransparency || SignatureShaders.isReadyForRendering == false {
            content
        } else {
            content.layerEffect(
                Shader(
                    function: ShaderFunction(library: .default, name: "LifeBoardPaperGrain"),
                    arguments: [
                        .float2(1, 1),
                        .float(Float(max(0, min(1, intensity))))
                    ]
                ),
                maxSampleOffset: .zero
            )
        }
    }
}

// MARK: - ambientDrift

/// The ambient tier's public surface, kept in its own extension because the
/// boundary-effect extension above is at the file-size ratchet's per-type cap.
public extension View {
    /// Continuous, bounded luminance drift for a hero surface — the ambient
    /// tier. Unlike every other signature effect this one never settles; it
    /// runs until the motion policy withdraws it. One per screen.
    @MainActor
    func lifeboardAmbientDrift(intensity: Double = 1) -> some View {
        modifier(AmbientDriftModifierEnvironment(intensity: intensity))
    }
}

/// The ambient tier's shader. The only effect in this file driven by wall time
/// rather than a one-shot trigger, so it is the only one that owns a
/// `TimelineView` — hence the DESIGN.md budget of one per screen.
private struct AmbientDriftModifierEnvironment: ViewModifier {
    let intensity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(AmbientDriftModifier(
            intensity: intensity,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct AmbientDriftModifier: ViewModifier {
    let intensity: Double
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }

    func body(content: Content) -> some View {
        if usesFallback || intensity <= 0.001 {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: sceneIsActive == false)) { context in
                let time = Float(
                    context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 86_837)
                )
                content.layerEffect(
                    Shader(
                        function: ShaderFunction(library: .default, name: "LifeBoardAmbientDrift"),
                        arguments: [
                            .float2(1, 1),
                            .float(time),
                            .float(Float(max(0, min(1, intensity))))
                        ]
                    ),
                    maxSampleOffset: .zero
                )
            }
        }
    }
}

// MARK: - dissolveAway

private struct DissolveAwayModifierEnvironment: ViewModifier {
    let progress: Double
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(DissolveAwayModifier(
            progress: progress,
            tint: tint,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct DissolveAwayModifier: ViewModifier {
    let progress: Double
    let tint: Color
    let reduceMotion: Bool
    let sceneIsActive: Bool

    func body(content: Content) -> some View {
        if usesFallback {
            // Reduce Motion still needs the item to leave; it just fades.
            content.opacity(1 - max(0, min(1, progress)))
        } else if progress <= 0.001 {
            content
        } else {
            let components = SignatureShaders.components(of: tint)
            content.layerEffect(
                Shader(
                    function: ShaderFunction(library: .default, name: "LifeBoardDissolveAway"),
                    arguments: [
                        .float2(1, 1),
                        .float(Float(max(0, min(1, progress)))),
                        .float3(components.0, components.1, components.2)
                    ]
                ),
                maxSampleOffset: .zero
            )
        }
    }

    private var usesFallback: Bool {
        reduceMotion || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// Environment-reading wrappers so the accessibility flags come from the view tree.
private struct DaypartBloomModifierEnvironment: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(DaypartBloomModifier(
            center: center, trigger: trigger, tint: tint,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct EvaInkRevealModifierEnvironment: ViewModifier {
    let progress: Double
    let newContentFraction: Double
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(EvaInkRevealModifier(
            progress: progress,
            newContentFraction: newContentFraction,
            tint: tint,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct JournalMediaRevealModifierEnvironment: ViewModifier {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(JournalMediaRevealModifier(
            progress: progress,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct MemoryDevelopRevealModifierEnvironment: ViewModifier {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(MemoryDevelopRevealModifier(
            progress: progress,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct FastingEmberRingModifierEnvironment: ViewModifier {
    let progress: Double
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.modifier(FastingEmberRingModifier(
            progress: progress,
            tint: tint,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct HealthSyncPulseModifierEnvironment: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.modifier(HealthSyncPulseModifier(
            trigger: trigger,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct VitalOrbWarpModifierEnvironment: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.modifier(VitalOrbWarpModifier(
            trigger: trigger,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

// MARK: - Clay press bloom

/// The tactile signature: pressing a clay surface pushes a shaded dimple into
/// it ringed by displaced light. One-shot and interaction-bound — there is
/// deliberately no ambient variant.
@MainActor
private struct ClayPressBloomModifier: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    let tint: Color
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool
    @State private var startDate: Date?

    private static let duration: TimeInterval = 0.44

    func body(content: Content) -> some View {
        content
            .overlay {
                if let startDate {
                    TimelineView(.animation) { context in
                        let progress = min(1, context.date.timeIntervalSince(startDate) / Self.duration)
                        if usesFallback {
                            // Reduce Motion still gets a readable confirmation,
                            // just without spatial energy.
                            tint.opacity(0.10 * (1 - progress))
                        } else {
                            GeometryReader { proxy in
                                Rectangle()
                                    .fill(.clear)
                                    .colorEffect(Shader(
                                        function: ShaderFunction(library: .default, name: "LifeBoardClayPressBloom"),
                                        arguments: [
                                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                            .float2(Float(center.x), Float(center.y)),
                                            .float(Float(progress)),
                                            .float3(1.0, 0.92, 0.78)
                                        ]
                                    ))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .clipped()
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive else { return }
                startDate = Date()
            }
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - Daypart cross dissolve

/// The screen changing time of day. An organic light front sweeps across the
/// surface carrying the incoming daypart's colour, so a daypart boundary or a
/// manual override is a moment rather than a swap.
@MainActor
private struct DaypartCrossDissolveModifier: ViewModifier {
    let trigger: Int
    let daypart: ResolvedDaypart
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool
    @State private var startDate: Date?

    private static let duration: TimeInterval = 0.9

    func body(content: Content) -> some View {
        content
            .overlay {
                if let startDate {
                    TimelineView(.animation) { context in
                        let progress = min(1, context.date.timeIntervalSince(startDate) / Self.duration)
                        if usesFallback {
                            // A plain cross-fade of the incoming light, which is
                            // what Apple's guidance asks for in place of spatial
                            // motion under Reduce Motion.
                            fallbackTint
                                .opacity(0.16 * sin(progress * .pi))
                        } else {
                            GeometryReader { proxy in
                                let tint = SignatureShaders.tintComponents(for: daypart)
                                Rectangle()
                                    .fill(.clear)
                                    .colorEffect(Shader(
                                        function: ShaderFunction(library: .default, name: "LifeBoardDaypartCrossDissolve"),
                                        arguments: [
                                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                            .float(Float(progress)),
                                            .float3(tint.0, tint.1, tint.2)
                                        ]
                                    ))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive else { return }
                startDate = Date()
            }
    }

    private var fallbackTint: Color {
        let tint = SignatureShaders.tintComponents(for: daypart)
        return Color(red: Double(tint.0), green: Double(tint.1), blue: Double(tint.2))
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - Completion burst

/// A commitment finishing. Replaces the CPU particle celebration with a single
/// expanding ring of warm light.
@MainActor
private struct CompletionBurstModifier: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool
    @State private var startDate: Date?

    private static let duration: TimeInterval = 0.6

    func body(content: Content) -> some View {
        content
            .overlay {
                if let startDate {
                    TimelineView(.animation) { context in
                        let progress = min(1, context.date.timeIntervalSince(startDate) / Self.duration)
                        if usesFallback {
                            Color.lifeboard(.statusSuccess)
                                .opacity(0.14 * (1 - progress))
                        } else {
                            GeometryReader { proxy in
                                Rectangle()
                                    .fill(.clear)
                                    .colorEffect(Shader(
                                        function: ShaderFunction(library: .default, name: "LifeBoardCompletionBurst"),
                                        arguments: [
                                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                            .float2(Float(center.x), Float(center.y)),
                                            .float(Float(progress)),
                                            .float3(0.96, 0.82, 0.52)
                                        ]
                                    ))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .clipped()
            .onChange(of: trigger) { _, _ in
                guard sceneIsActive else { return }
                startDate = Date()
            }
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - Environment wrappers

private struct ClayPressBloomModifierEnvironment: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(ClayPressBloomModifier(
            center: center, trigger: trigger, tint: tint,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct DaypartCrossDissolveModifierEnvironment: ViewModifier {
    let trigger: Int
    let daypart: ResolvedDaypart
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(DaypartCrossDissolveModifier(
            trigger: trigger, daypart: daypart,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct CompletionBurstModifierEnvironment: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(CompletionBurstModifier(
            center: center, trigger: trigger,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

private struct ContextLensModifierEnvironment: ViewModifier {
    let center: UnitPoint
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content.modifier(ContextLensModifier(
            center: center,
            trigger: trigger,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

public extension View {
    /// One-shot dimple-and-lip bloom at the touch point of a clay surface.
    @MainActor
    func lifeboardClayPressBloom(
        center: UnitPoint = .center,
        trigger: Int,
        tint: Color = Color(SemanticColorTokens.foundationSunAccent)
    ) -> some View {
        modifier(ClayPressBloomModifierEnvironment(center: center, trigger: trigger, tint: tint))
    }

    /// One-shot organic light front for a daypart boundary or manual override.
    @MainActor
    func lifeboardDaypartCrossDissolve(trigger: Int, daypart: ResolvedDaypart) -> some View {
        modifier(DaypartCrossDissolveModifierEnvironment(trigger: trigger, daypart: daypart))
    }

    /// One-shot expanding ring for a completed commitment.
    @MainActor
    func lifeboardCompletionBurst(center: UnitPoint = .center, trigger: Int) -> some View {
        modifier(CompletionBurstModifierEnvironment(center: center, trigger: trigger))
    }
}

// MARK: - firstLight

private struct FirstLightModifierEnvironment: ViewModifier {
    let trigger: Int
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.modifier(FirstLightModifier(
            trigger: trigger,
            tint: tint,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct FirstLightModifier: ViewModifier {
    let trigger: Int
    let tint: Color
    let reduceMotion: Bool
    let sceneIsActive: Bool

    /// Matches `LifeBoardAnimation.firstLight` so the sweep and whatever the
    /// caller animates alongside it finish together.
    static let duration: TimeInterval = 0.72

    @State private var startDate: Date?

    func body(content: Content) -> some View {
        Group {
            if usesFallback || startDate == nil {
                content
            } else if let startDate {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let progress = min(1, max(0, elapsed / Self.duration))
                    if progress >= 1 {
                        // Settled: no residue, and the TimelineView stops
                        // mattering once `startDate` is cleared below.
                        content
                    } else {
                        let components = SignatureShaders.components(of: tint)
                        content.visualEffect { effect, proxy in
                            effect.colorEffect(
                                Shader(
                                    function: ShaderFunction(library: .default, name: "LifeBoardFirstLight"),
                                    arguments: [
                                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                        .float(Float(progress)),
                                        .float3(components.0, components.1, components.2)
                                    ]
                                )
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: trigger) { _, _ in
            guard trigger > 0, usesFallback == false else { return }
            startDate = Date()
            // Hand the view back unmodified once the sweep is done. Leaving the
            // TimelineView mounted would be an ambient loop in all but name.
            Task {
                try? await Task.sleep(nanoseconds: UInt64((Self.duration + 0.05) * 1_000_000_000))
                startDate = nil
            }
        }
    }

    private var usesFallback: Bool {
        reduceMotion || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

// MARK: - valueDrumWarp

private struct ValueDrumWarpModifierEnvironment: ViewModifier {
    let grip: Double
    let center: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.modifier(ValueDrumWarpModifier(
            grip: grip,
            center: center,
            reduceMotion: MotionOverride.resolve(reduceMotion),
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}

struct ValueDrumWarpModifier: ViewModifier {
    let grip: Double
    let center: Double
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let sceneIsActive: Bool

    func body(content: Content) -> some View {
        // No `TimelineView`, unlike every other travelling effect in this file.
        // `grip` is driven directly by the drag, so the warp is already
        // frame-synchronous with the finger; adding a timeline would only give
        // the effect a way to outlive the gesture that justifies it.
        if usesFallback || grip <= 0.001 {
            content
        } else {
            content.visualEffect { effect, proxy in
                effect.distortionEffect(
                    Shader(
                        function: ShaderFunction(library: .default, name: "LifeBoardValueDrumWarp"),
                        arguments: [
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(Float(grip)),
                            .float(Float(center))
                        ]
                    ),
                    maxSampleOffset: CGSize(width: 10, height: 10)
                )
            }
        }
    }

    private var usesFallback: Bool {
        reduceMotion || reduceTransparency || sceneIsActive == false
            || SignatureShaders.isReadyForRendering == false
    }
}

public extension View {
    /// The value tape's cylinder warp, for the duration of a scrub.
    ///
    /// Apply to the tick track only — never to the numeric readout, its unit, or
    /// any prose. `grip` is 1 while the finger is down and 0 at rest; at rest
    /// there is no shader in the render tree at all.
    func lifeboardValueDrumWarp(grip: Double, center: Double = 0.5) -> some View {
        modifier(ValueDrumWarpModifierEnvironment(grip: grip, center: center))
    }
}
