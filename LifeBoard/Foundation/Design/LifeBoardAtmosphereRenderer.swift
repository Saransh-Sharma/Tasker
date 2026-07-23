import SwiftUI
import UIKit
import Observation

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

// MARK: - Time-driven celestial atmosphere

public enum LifeBoardCelestialPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case dawn
    case morning
    case midday
    case goldenHour
    case twilight
    case night

    public static func resolve(at date: Date = Date(), calendar: Calendar = .current) -> Self {
        switch calendar.component(.hour, from: date) {
        case 5..<8: .dawn
        case 8..<12: .morning
        case 12..<17: .midday
        case 17..<19: .goldenHour
        case 19..<21: .twilight
        default: .night
        }
    }

    public var semanticDaypart: ResolvedDaypart {
        switch self {
        case .dawn, .morning: .morning
        case .midday: .afternoon
        case .goldenHour, .twilight: .evening
        case .night: .night
        }
    }

    public static func manualPhase(for selection: DaypartSelection) -> Self? {
        switch selection {
        case .automatic: nil
        case .morning: .morning
        case .afternoon: .midday
        case .evening: .goldenHour
        case .night: .night
        }
    }

    public static func nextBoundary(after date: Date, calendar: Calendar = .current) -> Date {
        let phase = resolve(at: date, calendar: calendar)
        let start = calendar.startOfDay(for: date)
        let targetHour: Int
        let dayOffset: Int
        switch phase {
        case .dawn: (targetHour, dayOffset) = (8, 0)
        case .morning: (targetHour, dayOffset) = (12, 0)
        case .midday: (targetHour, dayOffset) = (17, 0)
        case .goldenHour: (targetHour, dayOffset) = (19, 0)
        case .twilight: (targetHour, dayOffset) = (21, 0)
        case .night:
            if calendar.component(.hour, from: date) < 5 {
                (targetHour, dayOffset) = (5, 0)
            } else {
                (targetHour, dayOffset) = (5, 1)
            }
        }
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        return calendar.date(bySettingHour: targetHour, minute: 0, second: 0, of: targetDay)
            ?? date.addingTimeInterval(60)
    }
}

public struct LifeBoardAtmosphereDescriptor: Equatable, Sendable {
    public let phase: LifeBoardCelestialPhase
    public let backgroundAsset: String
    public let celestialAsset: String
    public let fallbackHex: String
    public let usesInverseHeaderInk: Bool
    public let scrimStrength: Double
    public let celestialAnchorX: Double
    public let celestialAnchorY: Double
    public let celestialScale: Double
    public let compactStarCount: Int
    public let regularStarCount: Int

    public static func descriptor(for phase: LifeBoardCelestialPhase) -> Self {
        switch phase {
        case .dawn:
            .init(phase: phase, backgroundAsset: "CelestialDawnBackground", celestialAsset: "CelestialDawn", fallbackHex: "#F2D6B6", usesInverseHeaderInk: false, scrimStrength: 0.10, celestialAnchorX: 0.36, celestialAnchorY: 0.18, celestialScale: 0.70, compactStarCount: 0, regularStarCount: 0)
        case .morning:
            .init(phase: phase, backgroundAsset: "CelestialMorningBackground", celestialAsset: "CelestialMorning", fallbackHex: "#F4D9A8", usesInverseHeaderInk: false, scrimStrength: 0.08, celestialAnchorX: 0.52, celestialAnchorY: 0.13, celestialScale: 0.76, compactStarCount: 0, regularStarCount: 0)
        case .midday:
            .init(phase: phase, backgroundAsset: "CelestialMiddayBackground", celestialAsset: "CelestialMidday", fallbackHex: "#EDC178", usesInverseHeaderInk: false, scrimStrength: 0.12, celestialAnchorX: 0.62, celestialAnchorY: 0.09, celestialScale: 0.68, compactStarCount: 0, regularStarCount: 0)
        case .goldenHour:
            .init(phase: phase, backgroundAsset: "CelestialGoldenHourBackground", celestialAsset: "CelestialGoldenHour", fallbackHex: "#E7B875", usesInverseHeaderInk: false, scrimStrength: 0.13, celestialAnchorX: 0.34, celestialAnchorY: 0.20, celestialScale: 0.66, compactStarCount: 0, regularStarCount: 0)
        case .twilight:
            .init(phase: phase, backgroundAsset: "CelestialTwilightBackground", celestialAsset: "CelestialTwilight", fallbackHex: "#B7A5A2", usesInverseHeaderInk: false, scrimStrength: 0.20, celestialAnchorX: 0.70, celestialAnchorY: 0.16, celestialScale: 0.54, compactStarCount: 8, regularStarCount: 12)
        case .night:
            .init(phase: phase, backgroundAsset: "CelestialNightBackground", celestialAsset: "CelestialNight", fallbackHex: "#343545", usesInverseHeaderInk: true, scrimStrength: 0.30, celestialAnchorX: 0.72, celestialAnchorY: 0.14, celestialScale: 0.50, compactStarCount: 14, regularStarCount: 22)
        }
    }
}

public struct LifeBoardAtmosphereSnapshot: Equatable, Sendable {
    public let phase: LifeBoardCelestialPhase
    public let semanticDaypart: ResolvedDaypart
    public let observedAt: Date
    public let nextBoundary: Date
    public let transitionIdentity: String

    public init(
        phase: LifeBoardCelestialPhase,
        observedAt: Date,
        nextBoundary: Date,
        transitionIdentity: String? = nil
    ) {
        self.phase = phase
        semanticDaypart = phase.semanticDaypart
        self.observedAt = observedAt
        self.nextBoundary = nextBoundary
        self.transitionIdentity = transitionIdentity ?? "\(phase.rawValue)-\(Int(nextBoundary.timeIntervalSince1970))"
    }

    public static func resolve(at date: Date = Date(), calendar: Calendar = .current) -> Self {
        let phase = LifeBoardCelestialPhase.resolve(at: date, calendar: calendar)
        return .init(
            phase: phase,
            observedAt: date,
            nextBoundary: LifeBoardCelestialPhase.nextBoundary(after: date, calendar: calendar)
        )
    }

    public func replacingPhase(_ phase: LifeBoardCelestialPhase) -> Self {
        .init(
            phase: phase,
            observedAt: observedAt,
            nextBoundary: nextBoundary,
            transitionIdentity: "manual-\(phase.rawValue)-\(Int(nextBoundary.timeIntervalSince1970))"
        )
    }
}

@MainActor
@Observable
public final class LifeBoardAtmosphereClock {
    public private(set) var snapshot: LifeBoardAtmosphereSnapshot
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let calendar: @Sendable () -> Calendar

    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: @escaping @Sendable () -> Calendar = { Calendar.current }
    ) {
        self.now = now
        self.calendar = calendar
        let current = now()
        snapshot = .resolve(at: current, calendar: calendar())
    }

    public func refresh() {
        let current = now()
        snapshot = .resolve(at: current, calendar: calendar())
    }

    public func run() async {
        while Task.isCancelled == false {
            refresh()
            let delay = max(1, snapshot.nextBoundary.timeIntervalSince(now()) + 0.05)
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
        }
    }
}

public enum LifeBoardAtmospherePlacement: String, CaseIterable, Hashable, Sendable {
    case home, plan, track, insights, eva, onboarding, focusedPresentation

    public static func root(_ destination: LifeBoardDestination) -> Self {
        switch destination {
        case .home: .home
        case .plan: .plan
        case .track: .track
        case .insights: .insights
        case .eva: .eva
        }
    }

    var suppressesAmbientDetail: Bool {
        self == .onboarding || self == .focusedPresentation
    }
}

private struct LifeBoardAtmosphereSnapshotKey: EnvironmentKey {
    static let defaultValue = LifeBoardAtmosphereSnapshot.resolve()
}

private struct LifeBoardAtmosphereHostedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var lifeBoardAtmosphereSnapshot: LifeBoardAtmosphereSnapshot {
        get { self[LifeBoardAtmosphereSnapshotKey.self] }
        set { self[LifeBoardAtmosphereSnapshotKey.self] = newValue }
    }

    var lifeBoardAtmosphereIsHosted: Bool {
        get { self[LifeBoardAtmosphereHostedKey.self] }
        set { self[LifeBoardAtmosphereHostedKey.self] = newValue }
    }
}

public struct LifeBoardAtmosphereHost<Content: View>: View {
    private let preferences: LifeBoardPresentationPreferences
    private let placement: LifeBoardAtmospherePlacement
    private let content: Content
    @State private var clock: LifeBoardAtmosphereClock

    public init(
        preferences: LifeBoardPresentationPreferences,
        placement: LifeBoardAtmospherePlacement,
        clock: LifeBoardAtmosphereClock? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.preferences = preferences
        self.placement = placement
        self.content = content()
        _clock = State(initialValue: clock ?? LifeBoardAtmosphereClock())
    }

    public var body: some View {
        let snapshot = effectiveSnapshot
        content
            .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("-UI_TESTING") {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Celestial atmosphere: \(snapshot.phase.rawValue)")
                    .accessibilityIdentifier("lifeboard.atmosphere.\(snapshot.phase.rawValue)")
            }
            }
        .environment(\.lifeBoardAtmosphereSnapshot, snapshot)
        .environment(\.lifeBoardAtmosphereIsHosted, true)
        .task { await clock.run() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in clock.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in clock.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in clock.refresh() }
    }

    private var effectiveSnapshot: LifeBoardAtmosphereSnapshot {
        if let fixture = LifeBoardCelestialPhaseFixture.active {
            return clock.snapshot.replacingPhase(fixture.phase)
        }
        _ = preferences.resolvedDaypart(at: clock.snapshot.observedAt)
        guard let manual = LifeBoardCelestialPhase.manualPhase(for: preferences.daypartSelection) else {
            return clock.snapshot
        }
        return clock.snapshot.replacingPhase(manual)
    }
}

public struct LifeBoardAdaptiveAtmosphere: View {
    public let snapshot: LifeBoardAtmosphereSnapshot
    public let placement: LifeBoardAtmospherePlacement
    public let requestedTier: AmbientRenderingTier
    public let comfortProfile: LifeBoardComfortProfile
    public let showsCelestial: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var transitionTrigger = 0
    @State private var powerRevision = 0

    public init(
        snapshot: LifeBoardAtmosphereSnapshot,
        placement: LifeBoardAtmospherePlacement = .home,
        requestedTier: AmbientRenderingTier = .ambient2D,
        comfortProfile: LifeBoardComfortProfile = .balanced,
        showsCelestial: Bool = true
    ) {
        self.snapshot = snapshot
        self.placement = placement
        self.requestedTier = requestedTier
        self.comfortProfile = comfortProfile
        self.showsCelestial = showsCelestial
    }

    public var body: some View {
        let descriptor = LifeBoardAtmosphereDescriptor.descriptor(for: snapshot.phase)
        GeometryReader { proxy in
            let layout = scenicLayout(for: proxy.size)
            ZStack {
                Color(lifeboardHex: descriptor.fallbackHex)

                scenicPlane(descriptor: descriptor, layout: layout)
                    .frame(width: layout.width, height: proxy.size.height)
                    .position(x: layout.midX, y: proxy.size.height / 2)

                if descriptor.compactStarCount > 0, placement.suppressesAmbientDetail == false {
                    starField(descriptor: descriptor, layout: layout, size: proxy.size)
                }

                phaseWash(descriptor: descriptor)

                if showsCelestial {
                    celestial(descriptor: descriptor, layout: layout, size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .lifeboardCelestialTide(
                center: UnitPoint(x: descriptor.celestialAnchorX, y: descriptor.celestialAnchorY),
                trigger: transitionTrigger,
                daypart: snapshot.semanticDaypart
            )
        }
        .animation(reduceMotion ? .linear(duration: 0.18) : .easeInOut(duration: 0.65), value: snapshot.transitionIdentity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onChange(of: snapshot.transitionIdentity) { _, _ in transitionTrigger &+= 1 }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in powerRevision &+= 1 }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in powerRevision &+= 1 }
    }

    private struct ScenicLayout {
        let width: CGFloat
        let minX: CGFloat
        var midX: CGFloat { minX + width / 2 }
    }

    private func scenicLayout(for size: CGSize) -> ScenicLayout {
        let width = size.width >= 700 ? min(520, size.width) : size.width
        return ScenicLayout(width: width, minX: (size.width - width) / 2)
    }

    private func scenicPlane(descriptor: LifeBoardAtmosphereDescriptor, layout: ScenicLayout) -> some View {
        Image(decorative: descriptor.backgroundAsset)
            .resizable()
            .scaledToFill()
            .frame(width: layout.width)
            .clipped()
            .saturation(colorScheme == .dark ? 0.74 : 1)
            .brightness(colorScheme == .dark ? -0.20 : 0)
            .id(descriptor.backgroundAsset)
            .transition(.opacity)
            .overlay {
                if layout.width >= 500 {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [Color(lifeboardHex: descriptor.fallbackHex), .clear], startPoint: .leading, endPoint: .trailing).frame(width: 28)
                        Spacer(minLength: 0)
                        LinearGradient(colors: [.clear, Color(lifeboardHex: descriptor.fallbackHex)], startPoint: .leading, endPoint: .trailing).frame(width: 28)
                    }
                }
            }
    }

    private func phaseWash(descriptor: LifeBoardAtmosphereDescriptor) -> some View {
        let contrastBoost = accessibilityContrast == .increased ? 0.12 : 0
        let darkBoost = colorScheme == .dark ? 0.20 : 0
        return LinearGradient(
            colors: descriptor.usesInverseHeaderInk
                ? [Color.black.opacity(descriptor.scrimStrength + contrastBoost), Color.clear, Color(LifeBoardColorTokens.foundationCanvas).opacity(0.12 + darkBoost)]
                : [Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(descriptor.scrimStrength + contrastBoost), Color.clear, Color(LifeBoardColorTokens.foundationCanvas).opacity(darkBoost)],
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(reduceTransparency ? 1 : 0.94)
    }

    @ViewBuilder
    private func celestial(
        descriptor: LifeBoardAtmosphereDescriptor,
        layout: ScenicLayout,
        size: CGSize
    ) -> some View {
        let policy = motionPolicy
        let paused = policy.allowsIdleMotion == false || placement.suppressesAmbientDetail || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1 / 12, paused: paused)) { context in
            let phase = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            let amplitude = celestialAmplitude
            let driftX = CGFloat(sin(phase / 10.8)) * amplitude
            let driftY = CGFloat(cos(phase / 12.0)) * amplitude * 0.66
            let rotation = Double(sin(phase / 11.6)) * (comfortProfile == .playful ? 0.15 : 0.10)
            let breath = 1 + CGFloat(sin(phase / 9.8)) * (comfortProfile == .playful ? 0.004 : 0.003)
            let diameter = min(520, max(snapshot.phase == .night || snapshot.phase == .twilight ? 180 : 220, layout.width * descriptor.celestialScale))

            Image(decorative: descriptor.celestialAsset)
                .resizable()
                .scaledToFit()
                .frame(width: diameter, height: diameter)
                .opacity(reduceTransparency ? 0.94 : 1)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(breath)
                .position(
                    x: layout.minX + layout.width * descriptor.celestialAnchorX + driftX,
                    y: size.height * descriptor.celestialAnchorY + driftY
                )
                .id(descriptor.celestialAsset)
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
        }
    }

    private func starField(
        descriptor: LifeBoardAtmosphereDescriptor,
        layout: ScenicLayout,
        size: CGSize
    ) -> some View {
        let policy = motionPolicy
        let count = size.width >= 700 ? descriptor.regularStarCount : descriptor.compactStarCount
        let visibleCount = reduceTransparency ? max(4, count / 2) : count
        let paused = policy.allowsIdleMotion == false || scenePhase != .active
        return TimelineView(.animation(minimumInterval: 1 / 12, paused: paused)) { context in
            let time = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas(rendersAsynchronously: true) { graphics, canvasSize in
                for index in 0..<visibleCount {
                    let x = layout.minX + pseudoRandom(index * 41 + 7) * layout.width
                    let y = 18 + pseudoRandom(index * 67 + 19) * canvasSize.height * 0.40
                    let base = 0.8 + pseudoRandom(index * 23 + 3) * 1.4
                    let cycle = 5 + pseudoRandom(index * 13 + 2) * 5
                    let wave = paused ? 0.72 : 0.55 + 0.30 * sin((time / cycle + Double(index)) * .pi * 2)
                    let opacity = reduceTransparency ? max(0.58, wave) : wave
                    let rect = CGRect(x: x, y: y, width: base, height: base)
                    let color = index.isMultiple(of: 3)
                        ? Color(lifeboardHex: "#E7DDF1")
                        : Color(lifeboardHex: "#FFF3D9")
                    graphics.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
                }
            }
        }
    }

    private var motionPolicy: LifeBoardMotionPolicy {
        _ = powerRevision
        return LifeBoardMotionPolicy.resolve(
            reduceMotion: reduceMotion || LifeBoardVisualAppearanceFixture.active?.usesReducedMotion == true,
            reduceTransparency: reduceTransparency || LifeBoardVisualAppearanceFixture.active?.usesReducedTransparency == true,
            sceneIsActive: scenePhase == .active,
            comfortProfile: comfortProfile,
            isFocusedPresentation: placement.suppressesAmbientDetail
        )
    }

    private var celestialAmplitude: CGFloat {
        guard motionPolicy.allowsIdleMotion, requestedTier != .static else { return 0 }
        return switch comfortProfile {
        case .calm: 0
        case .balanced: 3
        case .playful: 4
        }
    }

    private func pseudoRandom(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return value - floor(value)
    }
}

public struct LifeBoardAtmosphereView: View {
    public let daypart: ResolvedDaypart
    public let requestedTier: AmbientRenderingTier
    public let comfortProfile: LifeBoardComfortProfile

    @Environment(\.lifeBoardAtmosphereSnapshot) private var sharedSnapshot
    @Environment(\.lifeBoardAtmosphereIsHosted) private var isHosted

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
        Group {
            if isHosted {
                Color.clear
            } else {
                LifeBoardAdaptiveAtmosphere(
                    snapshot: compatibleSnapshot,
                    placement: .track,
                    requestedTier: requestedTier,
                    comfortProfile: comfortProfile
                )
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var compatibleSnapshot: LifeBoardAtmosphereSnapshot {
        if sharedSnapshot.semanticDaypart == daypart { return sharedSnapshot }
        let phase: LifeBoardCelestialPhase
        switch daypart {
        case .morning: phase = .morning
        case .afternoon: phase = .midday
        case .evening: phase = .goldenHour
        case .night: phase = .night
        }
        return sharedSnapshot.replacingPhase(phase)
    }
}

// MARK: - Scenic paper backdrops

/// The user-supplied paper artwork is intentionally kept separate from the
/// transparent celestial assets. This lets daypart motion move one small
/// decorative layer while the readable canvas remains perfectly stable.
public struct LifeBoardScenicBackdrop: View {
    public enum Scene: String, CaseIterable, Sendable {
        case home
        case plan
        case secondary
    }

    public let scene: Scene
    public let daypart: ResolvedDaypart
    public let requestedTier: AmbientRenderingTier
    public let comfortProfile: LifeBoardComfortProfile
    public let showsSun: Bool

    @Environment(\.lifeBoardAtmosphereSnapshot) private var sharedSnapshot
    @Environment(\.lifeBoardAtmosphereIsHosted) private var isHosted

    public init(
        scene: Scene,
        daypart: ResolvedDaypart,
        requestedTier: AmbientRenderingTier = .ambient2D,
        comfortProfile: LifeBoardComfortProfile = .balanced,
        showsSun: Bool = true
    ) {
        self.scene = scene
        self.daypart = daypart
        self.requestedTier = requestedTier
        self.comfortProfile = comfortProfile
        self.showsSun = showsSun
    }

    public var body: some View {
        Group {
            if isHosted {
                Color.clear
            } else {
                LifeBoardAdaptiveAtmosphere(
                    snapshot: compatibleSnapshot,
                    placement: placement,
                    requestedTier: requestedTier,
                    comfortProfile: comfortProfile,
                    showsCelestial: showsSun
                )
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var placement: LifeBoardAtmospherePlacement {
        switch scene {
        case .home: .home
        case .plan: .plan
        case .secondary: .insights
        }
    }

    private var compatibleSnapshot: LifeBoardAtmosphereSnapshot {
        if sharedSnapshot.semanticDaypart == daypart { return sharedSnapshot }
        let phase: LifeBoardCelestialPhase
        switch daypart {
        case .morning: phase = .morning
        case .afternoon: phase = .midday
        case .evening: phase = .goldenHour
        case .night: phase = .night
        }
        return sharedSnapshot.replacingPhase(phase)
    }
}

// MARK: - Shared premium content primitives

/// Opaque reading surface for information. Glass is intentionally excluded
/// from this component so text, charts, forms, and lists remain quiet.
public struct LifeBoardPaperSection<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    public init(
        cornerRadius: CGFloat = LifeBoardFoundationRadius.card,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            .background(
                Color(LifeBoardColorTokens.foundationSurfaceSolid),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        Color(LifeBoardColorTokens.foundationHairline),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            }
    }
}

public struct LifeBoardTactileTile<Label: View>: View {
    private let action: () -> Void
    private let accessibilityLabel: String
    private let label: Label

    public init(
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button {
            LifeBoardFeedback.selection()
            action()
        } label: {
            label
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(LifeBoardTactileTileButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

public struct LifeBoardTactileTileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background(
                Color(LifeBoardColorTokens.foundationSurfaceSolid),
                in: RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous)
                    .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && reduceMotion == false ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : LifeBoardAnimation.rolePress, value: configuration.isPressed)
    }
}

public enum LifeBoardVisualFixtureRoot: String, CaseIterable, Sendable {
    case home
    case plan
    case track
    case insights
    case eva
}

public enum LifeBoardVisualFixtureState: String, CaseIterable, Sendable {
    case populated
    case empty
    case loading
    case stale
    case offline
    case denied
    case recoverableError = "recoverable-error"
    case locked
    case destructiveConfirmation = "destructive-confirmation"
}

/// Deterministic, launch-argument driven fixtures used by screenshot and UI
/// tests. The production app never enters one of these states implicitly.
public struct LifeBoardVisualFixture: Equatable, Identifiable, Sendable {
    public static let launchArgumentPrefix = "-LIFEBOARD_VISUAL_FIXTURE="

    public let root: LifeBoardVisualFixtureRoot
    public let state: LifeBoardVisualFixtureState

    public var id: String { "\(root.rawValue).\(state.rawValue)" }
    public var launchArgument: String { "\(Self.launchArgumentPrefix)\(root.rawValue):\(state.rawValue)" }

    public init(root: LifeBoardVisualFixtureRoot, state: LifeBoardVisualFixtureState) {
        self.root = root
        self.state = state
    }

    public init?(arguments: [String]) {
        guard let argument = arguments.first(where: { $0.hasPrefix(Self.launchArgumentPrefix) }) else { return nil }
        let payload = argument.dropFirst(Self.launchArgumentPrefix.count)
        let components = payload.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2,
              let root = LifeBoardVisualFixtureRoot(rawValue: components[0]),
              let state = LifeBoardVisualFixtureState(rawValue: components[1]) else { return nil }
        self.init(root: root, state: state)
    }

    public static let catalog: [LifeBoardVisualFixture] = LifeBoardVisualFixtureRoot.allCases.flatMap { root in
        LifeBoardVisualFixtureState.allCases.map { state in
            LifeBoardVisualFixture(root: root, state: state)
        }
    }
}

/// A deterministic appearance override used only when a screenshot/UI-test
/// launch argument is present. Keeping this separate from user preferences
/// lets the evidence suite exercise comfort modes without mutating Simulator
/// global settings or changing production behavior.
public enum LifeBoardVisualAppearanceFixture: String, CaseIterable, Sendable {
    case light
    case dark
    case highContrastLight = "high-contrast-light"
    case highContrastDark = "high-contrast-dark"
    case reducedTransparency = "reduced-transparency"
    case reducedMotion = "reduced-motion"
    case grayscale

    public static let launchArgumentPrefix = "-LIFEBOARD_VISUAL_APPEARANCE="

    public static var active: LifeBoardVisualAppearanceFixture? {
        LifeBoardVisualAppearanceFixture(arguments: ProcessInfo.processInfo.arguments)
    }

    public init?(arguments: [String]) {
        guard let argument = arguments.first(where: { $0.hasPrefix(Self.launchArgumentPrefix) }) else {
            return nil
        }
        self.init(rawValue: String(argument.dropFirst(Self.launchArgumentPrefix.count)))
    }

    public var launchArgument: String { "\(Self.launchArgumentPrefix)\(rawValue)" }

    public var preferredColorScheme: ColorScheme {
        self == .dark || self == .highContrastDark ? .dark : .light
    }

    public var usesHighContrast: Bool {
        self == .highContrastLight || self == .highContrastDark
    }

    public var usesReducedTransparency: Bool { self == .reducedTransparency }
    public var usesReducedMotion: Bool { self == .reducedMotion }
    public var usesGrayscale: Bool { self == .grayscale }
}

/// Screenshot/UI-test-only phase override. It is intentionally launch-argument
/// driven and never persisted to presentation preferences.
public struct LifeBoardCelestialPhaseFixture: Equatable, Sendable {
    public static let launchArgumentPrefix = "-LIFEBOARD_CELESTIAL_PHASE="
    public let phase: LifeBoardCelestialPhase

    public static var active: Self? { Self(arguments: ProcessInfo.processInfo.arguments) }

    public init(phase: LifeBoardCelestialPhase) {
        self.phase = phase
    }

    public init?(arguments: [String]) {
        guard let argument = arguments.first(where: { $0.hasPrefix(Self.launchArgumentPrefix) }),
              let phase = LifeBoardCelestialPhase(rawValue: String(argument.dropFirst(Self.launchArgumentPrefix.count))) else {
            return nil
        }
        self.phase = phase
    }

    public var launchArgument: String { "\(Self.launchArgumentPrefix)\(phase.rawValue)" }
}

public struct LifeBoardVisualFixtureSurface: View {
    public let fixture: LifeBoardVisualFixture

    public init(fixture: LifeBoardVisualFixture) {
        self.fixture = fixture
    }

    public var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            LifeBoardStatusSurface(
                state: statusState,
                title: copy.title,
                message: copy.message,
                actionTitle: copy.action
            ) {}
            .padding(16)
            .frame(maxWidth: 520)
        }
        .accessibilityIdentifier("fixture.\(fixture.id)")
    }

    private var statusState: LifeBoardStatusSurface.State {
        switch fixture.state {
        case .populated, .empty: .empty
        case .loading: .loading
        case .stale: .stale
        case .offline: .offline
        case .denied: .denied
        case .recoverableError: .recoverableError
        case .locked: .locked
        case .destructiveConfirmation: .destructiveConfirmation
        }
    }

    private var copy: (title: String, message: String, action: String?) {
        let rootName = fixture.root.rawValue.capitalized
        return switch fixture.state {
        case .populated: ("\(rootName) is ready", "Deterministic populated content is available.", nil)
        case .empty: ("A little room to begin", "Your \(fixture.root.rawValue) space will grow as you use LifeBoard.", "Add something")
        case .loading: ("Gathering \(fixture.root.rawValue)", "This will disappear as soon as authoritative data arrives.", nil)
        case .stale: ("Last known view", "Some information is out of date. Your saved work is still here.", "Refresh")
        case .offline: ("You’re offline", "You can keep working locally. Connected details will return later.", "Try again")
        case .denied: ("Permission stays with you", "LifeBoard can continue without this access, or you can enable it in Settings.", "Open Settings")
        case .recoverableError: ("That didn’t quite land", "Nothing was lost. Try the operation again when you’re ready.", "Try again")
        case .locked: ("This space is protected", "Unlock to reveal private content.", "Unlock")
        case .destructiveConfirmation: ("Confirm this change", "This action affects saved information and needs your approval.", "Review")
        }
    }
}

public struct LifeBoardStatusSurface: View {
    public enum State: Equatable, Sendable {
        case loading
        case empty
        case stale
        case offline
        case denied
        case recoverableError
        case locked
        case destructiveConfirmation
    }

    private let state: State
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        state: State,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.state = state
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        LifeBoardPaperSection {
            HStack(alignment: .top, spacing: 12) {
                statusIcon
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .fixedSize(horizontal: false, vertical: true)

                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .padding(.top, 4)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeboard.status.\(accessibilityIdentifierSuffix)")
    }

    @ViewBuilder
    private var statusIcon: some View {
        if state == .loading {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var systemImage: String {
        switch state {
        case .loading: "hourglass"
        case .empty: "sparkles"
        case .stale: "clock.arrow.circlepath"
        case .offline: "wifi.slash"
        case .denied: "hand.raised"
        case .recoverableError: "arrow.clockwise.circle"
        case .locked: "lock"
        case .destructiveConfirmation: "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch state {
        case .recoverableError, .destructiveConfirmation:
            Color.lifeboard(.statusWarning)
        case .denied, .locked:
            Color.lifeboard(.textSecondary)
        default:
            Color.lifeboard(.accentPrimary)
        }
    }

    private var accessibilityIdentifierSuffix: String {
        switch state {
        case .loading: "loading"
        case .empty: "empty"
        case .stale: "stale"
        case .offline: "offline"
        case .denied: "denied"
        case .recoverableError: "error"
        case .locked: "locked"
        case .destructiveConfirmation: "confirmation"
        }
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
                    .opacity(effectiveReduceTransparency ? 1 : 0.94),
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

    private var effectiveReduceTransparency: Bool {
        reduceTransparency || LifeBoardVisualAppearanceFixture.active?.usesReducedTransparency == true
    }
}

public struct LifeBoardGlassSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        if reduceTransparency || LifeBoardVisualAppearanceFixture.active?.usesReducedTransparency == true {
            content.background(
                Color(LifeBoardColorTokens.foundationSurfaceSolid),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content.lifeBoardSystemGlass(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                interactive: interactive
            )
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
                    .stroke(Color.lifeboard(.textInverse).opacity(isNight ? 0.16 : 0.68), lineWidth: 1)
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
                    .stroke(Color.lifeboard(.textInverse).opacity(isNight ? 0.2 : 0.76), lineWidth: 1)
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
        case unavailable
        case stale(progress: Double, centerText: String)
        case zero(centerText: String)
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
        case .loading, .setupRequired, .unavailable, .zero: 0
        case .stale(let progress, _), .value(let progress, _): min(1, max(0, progress))
        case .complete: 1
        }
    }

    private var centerText: String? {
        switch state {
        case .loading, .setupRequired, .unavailable: nil
        case .stale(_, let text), .zero(let text), .value(_, let text), .complete(let text): text
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
                            dash: usesDashedTrack ? [3, 5] : []
                        )
                    )
                if let liquidTint, permitsProgressLayer {
                    LifeBoardLiquidFill(level: progress, tint: liquidTint)
                        .clipShape(Circle().inset(by: 4))
                        .allowsHitTesting(false)
                }
                if case .loading = state {
                    ProgressView().controlSize(.small)
                } else if permitsProgressLayer {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            reduceMotion ? nil : LifeBoardAnimation.numericUpdate,
                            value: progress
                        )
                }
                if let centerText {
                    Text(centerText)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                } else if let statusSymbol {
                    Image(systemName: statusSymbol)
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
        if case .stale = state {
            return Color(LifeBoardColorTokens.foundationApricotAccent)
        }
        return Color(LifeBoardColorTokens.metricRingFill)
    }

    private var usesDashedTrack: Bool {
        switch state {
        case .setupRequired, .unavailable, .stale: true
        default: false
        }
    }

    private var permitsProgressLayer: Bool {
        switch state {
        case .stale, .value, .complete: true
        case .loading, .setupRequired, .unavailable, .zero: false
        }
    }

    private var statusSymbol: String? {
        switch state {
        case .setupRequired: "plus"
        case .unavailable: "slash"
        default: nil
        }
    }

    private var accessibilityValueText: String {
        switch state {
        case .loading: "Loading"
        case .setupRequired: "Set up"
        case .unavailable: "Unavailable"
        case .stale(let progress, let text): "\(text), out of date, \(Int((min(1, max(0, progress)) * 100).rounded())) percent"
        case .zero(let text): "\(text), no progress recorded"
        case .value(let progress, let text): "\(text), \(Int((min(1, max(0, progress)) * 100).rounded())) percent"
        case .complete(let text): "\(text), complete"
        }
    }
}
