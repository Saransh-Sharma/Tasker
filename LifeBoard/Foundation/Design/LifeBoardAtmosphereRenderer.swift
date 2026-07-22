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
            reduceMotion: reduceMotion || LifeBoardVisualAppearanceFixture.active?.usesReducedMotion == true
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
                color: palette.color(for: .layerOne).opacity(effectiveReduceTransparency ? 1 : 0.94),
                scale: 1.0
            )
            drawCloudLayer(
                in: &context,
                canvasSize: canvasSize,
                y: canvasSize.height * 0.24,
                drift: drift * 0.34,
                color: palette.color(for: .layerTwo).opacity(effectiveReduceTransparency ? 1 : 0.9),
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
                with: .color(palette.color(for: .coolMist).opacity(effectiveReduceTransparency ? 0.92 : 0.68))
            )

            let grainOpacity = effectiveReduceTransparency ? 0 : (daypart == .night ? 0.022 : 0.015)
            for index in 0..<(policy.effectiveTier == .static ? 48 : 72) {
                let x = pseudoRandom(index * 17 + 3) * canvasSize.width
                let y = pseudoRandom(index * 29 + 11) * canvasSize.height
                let diameter = 0.5 + pseudoRandom(index * 7 + 5) * 1.3
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                    with: .color(Color.lifeboard(.textInverse).opacity(grainOpacity))
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

    private var effectiveReduceTransparency: Bool {
        reduceTransparency || LifeBoardVisualAppearanceFixture.active?.usesReducedTransparency == true
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

        var canvasAsset: String {
            switch self {
            case .home: "HomeScenicNoSun"
            case .plan, .secondary: "PlanScenicNoSun"
            }
        }

        var sunAsset: String {
            switch self {
            case .home: "SunDay"
            case .plan, .secondary: "SunDayPlan"
            }
        }
    }

    public let scene: Scene
    public let daypart: ResolvedDaypart
    public let requestedTier: AmbientRenderingTier
    public let comfortProfile: LifeBoardComfortProfile
    public let showsSun: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var daypartRevision = 0
    @State private var powerRevision = 0

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
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                palette.color(for: .canvas)

                Image(decorative: scene.canvasAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .clipped()
                    .saturation(colorScheme == .dark ? 0.72 : 1)
                    .brightness(colorScheme == .dark ? -0.28 : 0)

                daypartWash

                if showsSun {
                    celestialLayer(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .lifeboardDaypartBloom(center: .init(x: 0.52, y: 0.16), trigger: daypartRevision, daypart: daypart)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onChange(of: daypart) { _, _ in daypartRevision &+= 1 }
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
            reduceMotion: reduceMotion || LifeBoardVisualAppearanceFixture.active?.usesReducedMotion == true
        )
    }

    private var daypartWash: some View {
        LinearGradient(
            colors: [
                palette.color(for: .celestialPrimary).opacity(daypart == .night ? 0.24 : 0.08),
                palette.color(for: .canvas).opacity(colorScheme == .dark ? 0.62 : 0.04),
                palette.color(for: .canvasSecondary).opacity(colorScheme == .dark ? 0.78 : 0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func celestialLayer(in size: CGSize) -> some View {
        let policy = renderingPolicy
        if policy.allowsIdleMotion, scenePhase == .active {
            TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                celestialImage(in: size, phase: timeline.date.timeIntervalSinceReferenceDate, policy: policy)
            }
        } else {
            celestialImage(in: size, phase: 0, policy: policy)
        }
    }

    private func celestialImage(
        in size: CGSize,
        phase: TimeInterval,
        policy: AmbientRenderingPolicy
    ) -> some View {
        let diameter = daypart == .night
            ? min(max(size.width * 0.42, 150), 240)
            : min(max(size.width * (scene == .home ? 0.70 : 0.62), 220), 430)
        let drift = CGFloat(sin(phase / 8.5)) * policy.maximumParallax
        let lift = CGFloat(cos(phase / 10.0)) * policy.maximumParallax * 0.55
        return Group {
            if daypart == .night {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(palette.color(for: .celestialPrimary).opacity(0.84))
                        Circle()
                            .fill(Color(LifeBoardColorTokens.inkPrimary))
                            .scaleEffect(0.82)
                            .offset(x: diameter * 0.20, y: -diameter * 0.08)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()

                    Image(systemName: "sparkles")
                        .font(.system(size: max(18, diameter * 0.13), weight: .medium))
                        .foregroundStyle(palette.color(for: .celestialCore))
                        .offset(x: diameter * 0.04, y: -diameter * 0.04)
                }
            } else {
                Image(decorative: scene.sunAsset)
                    .resizable()
                    .scaledToFit()
            }
        }
            .frame(width: diameter, height: diameter)
            .opacity(effectiveReduceTransparency ? 0.88 : 0.96)
            .offset(x: drift, y: -diameter * (scene == .home ? 0.26 : 0.18) + lift)
            .scaleEffect(policy.effectiveTier == .enhanced3D ? 1.025 : 1)
    }

    private var effectiveReduceTransparency: Bool {
        reduceTransparency || LifeBoardVisualAppearanceFixture.active?.usesReducedTransparency == true
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

public struct LifeBoardVisualFixtureSurface: View {
    public let fixture: LifeBoardVisualFixture

    public init(fixture: LifeBoardVisualFixture) {
        self.fixture = fixture
    }

    public var body: some View {
        ZStack {
            Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
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
