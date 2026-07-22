import SwiftUI
import UIKit
@preconcurrency import Metal

public struct LifeBoardMotionPolicy: Equatable, Sendable {
    public let allowsCustomShaders: Bool
    public let allowsIdleMotion: Bool
    public let usesOpaqueSurfaces: Bool
    public let transitionDuration: TimeInterval
    public let springDamping: Double

    public static func resolve(
        reduceMotion: Bool,
        reduceTransparency: Bool,
        lowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState,
        sceneIsActive: Bool,
        supportsCustomShaders: Bool = true,
        isCatalyst: Bool = ProcessInfo.processInfo.isMacCatalystApp
    ) -> LifeBoardMotionPolicy {
        let thermallyConstrained = thermalState == .serious || thermalState == .critical
        let energyConstrained = lowPowerMode || thermallyConstrained
        let allowsMotion = sceneIsActive && reduceMotion == false && energyConstrained == false
        let allowsShaders = allowsMotion && reduceTransparency == false && supportsCustomShaders && isCatalyst == false
        return LifeBoardMotionPolicy(
            allowsCustomShaders: allowsShaders,
            allowsIdleMotion: allowsMotion,
            usesOpaqueSurfaces: reduceTransparency,
            transitionDuration: reduceMotion ? 0 : (energyConstrained ? 0.12 : 0.28),
            springDamping: reduceMotion ? 1 : 0.82
        )
    }
}

public struct AsyncActionFailure: Error, Equatable, Sendable {
    public enum Recovery: String, Equatable, Sendable { case retry, edit, discard, reopen }

    public let message: String
    public let recovery: Recovery

    public init(message: String, recovery: Recovery) {
        self.message = message
        self.recovery = recovery
    }
}

public enum AsyncActionPhase<Receipt: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case running(progress: Double?)
    case success(receipt: Receipt)
    case recoverableFailure(AsyncActionFailure)
    case cancelled
}

/// A compact action surface that morphs around real asynchronous state.
/// Interaction concepts were adapted from Shubham Kumar Singh's Apache-2.0
/// SwiftUI-Animations SubmitView/DownloadButton examples and substantially
/// rewritten for cancellable domain work and LifeBoard accessibility policy.
public struct LifeBoardAsyncActionControl<Receipt: Equatable & Sendable>: View {
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
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84), value: label)
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
public struct LifeBoardJournalWorkIndicator: View {
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
                if reduceMotion || scenePhase != .active {
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
private struct LifeBoardConfirmationRippleModifier: ViewModifier {
    let trigger: Int
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startDate: Date?

    private let duration: TimeInterval = 0.38

    func body(content: Content) -> some View {
        content
            .overlay { ripple }
            .clipped()
            .onChange(of: trigger) { _, _ in
                let policy = LifeBoardMotionPolicy.resolve(
                    reduceMotion: reduceMotion,
                    reduceTransparency: false,
                    sceneIsActive: scenePhase == .active
                )
                startDate = policy.allowsIdleMotion ? Date() : nil
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
/// `fastingEmberRing`. Each enhances an existing state,
/// compiles asynchronously before first use, and degrades to a plain opacity/scale fallback under
/// Reduce Motion, Low Power, thermal pressure, Reduce Transparency, or when the flag is off.
@MainActor
public enum LifeBoardSignatureShaders {
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

    private static let functionNames = [
        "LifeBoardDaypartBloom",
        "LifeBoardEvaInkReveal",
        "LifeBoardJournalMediaReveal",
        "LifeBoardMemoryDevelopReveal",
        "LifeBoardFastingEmberRing"
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
    public static var isReadyForRendering: Bool {
        guard performancePermits else { return false }
        if case .ready = preloadState { return true }
        return false
    }

    /// Loads the app's already-compiled Metal library and materializes every signature function
    /// away from the main actor. SwiftUI does not expose its private stitched render pipeline, so
    /// this deliberately stops at the supported public boundary instead of rasterizing hidden UI.
    /// The measured result is retained for diagnostics and makes repeated calls idempotent.
    public static func warmUp() {
        guard performancePermits else { return }
        guard preloadTask == nil else { return }

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
            preloadTask = nil
        }
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
                guard sceneIsActive, LifeBoardSignatureShaders.isReadyForRendering else { return }
                startDate = Date()
            }
    }

    @ViewBuilder
    private var bloomOverlay: some View {
        if let startDate, sceneIsActive, LifeBoardSignatureShaders.isReadyForRendering, reduceMotion == false, reduceTransparency == false {
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
        if progress >= 1.0 || reduceTransparency || sceneIsActive == false || LifeBoardSignatureShaders.isReadyForRendering == false {
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
        if progress >= 1.0 || reduceTransparency || sceneIsActive == false || LifeBoardSignatureShaders.isReadyForRendering == false {
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
        if settled >= 1 || reduceTransparency || sceneIsActive == false || LifeBoardSignatureShaders.isReadyForRendering == false {
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
        if reduceMotion || reduceTransparency || sceneIsActive == false || LifeBoardSignatureShaders.isReadyForRendering == false {
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

// MARK: - View sugar

public extension View {
    /// Plays only when `trigger` changes after a real action commits.
    func lifeboardConfirmationRipple(trigger: Int, tint: Color = .white) -> some View {
        modifier(LifeBoardConfirmationRippleModifier(trigger: trigger, tint: tint))
    }

    /// Plays a radial daypart bloom over this surface each time `trigger` changes.
    @MainActor
    func lifeboardDaypartBloom(center: UnitPoint = .center, trigger: Int, daypart: ResolvedDaypart) -> some View {
        let (r, g, b) = LifeBoardSignatureShaders.tintComponents(for: daypart)
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
            reduceMotion: reduceMotion,
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
            reduceMotion: reduceMotion,
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
            reduceMotion: reduceMotion,
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
            reduceMotion: reduceMotion,
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
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ))
    }
}
