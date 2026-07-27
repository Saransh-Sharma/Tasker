import Observation
import SwiftUI

/// The visual behavior of a LifeBoard screen. The mode controls only presentation;
/// domain state and navigation remain owned by the feature.
public enum LifeBoardScreenMode: String, CaseIterable, Hashable, Sendable {
    case ambient
    case detail
    case editor
    case utility
    case focused
    case critical

    var suppressesAmbientDetail: Bool {
        switch self {
        case .focused, .critical:
            true
        case .ambient, .detail, .editor, .utility:
            false
        }
    }

    var canvasOpacity: Double {
        switch self {
        case .ambient, .detail:
            0
        case .editor:
            0.78
        case .utility:
            0.88
        case .focused, .critical:
            1
        }
    }

    var defaultReadableWidth: CGFloat? {
        switch self {
        case .ambient:
            nil
        case .detail:
            920
        case .editor:
            720
        case .utility, .focused, .critical:
            860
        }
    }
}

/// Stable semantic identities for custom Liquid Glass transitions.
public enum LifeBoardGlassMorphRole: String, Hashable, Sendable {
    case capture
    case captureTray
    case dockSelection
    case evaComposer
    case evaComposerActions
    case floatingToolbar
}

public struct LifeBoardRootHeaderModel: Equatable, Sendable {
    public let title: String
    public let context: String?
    public let captureAvailable: Bool
    public let secondaryActionTitle: String?
    /// Opts the title into the per-glyph touch response. Only Home's greeting
    /// uses it: the other roots title a destination rather than address the
    /// person, and a playful "Insights" would read as noise.
    public let titleRespondsToTouch: Bool

    public init(
        title: String,
        context: String? = nil,
        captureAvailable: Bool = true,
        secondaryActionTitle: String? = nil,
        titleRespondsToTouch: Bool = false
    ) {
        self.title = title
        self.context = context
        self.captureAvailable = captureAvailable
        self.secondaryActionTitle = secondaryActionTitle
        self.titleRespondsToTouch = titleRespondsToTouch
    }
}

/// One quiet, left-aligned header shared by every root. Capture remains visible;
/// optional gestures only accelerate controls that are already on screen.
public struct LifeBoardRootHeader: View {
    public let model: LifeBoardRootHeaderModel
    public let captureExpanded: Bool
    /// True when the header sits over a dark scenic backdrop. The daypart
    /// scene is independent of the system appearance, so a Night scene in Light
    /// appearance resolved cocoa ink onto navy sky and the greeting and date
    /// were effectively invisible.
    public let usesInverseInk: Bool
    public let onCapture: () -> Void
    public let secondaryActions: AnyView?

    public init(
        model: LifeBoardRootHeaderModel,
        captureExpanded: Bool = false,
        usesInverseInk: Bool = false,
        onCapture: @escaping () -> Void,
        secondaryActions: AnyView? = nil
    ) {
        self.model = model
        self.captureExpanded = captureExpanded
        self.usesInverseInk = usesInverseInk
        self.onCapture = onCapture
        self.secondaryActions = secondaryActions
    }

    private var primaryInk: Color {
        usesInverseInk
            ? Color(LifeBoardColorTokens.foundationOnScenicDark)
            : Color(LifeBoardColorTokens.inkPrimary)
    }

    private var secondaryInk: Color {
        usesInverseInk
            ? Color(LifeBoardColorTokens.foundationOnScenicDarkSecondary)
            : Color(LifeBoardColorTokens.inkSecondary)
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                    .modifier(LifeBoardOptionalKineticGreeting(isEnabled: model.titleRespondsToTouch))
                if let context = model.context {
                    Text(context)
                        .font(.subheadline)
                        .foregroundStyle(secondaryInk)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if let secondaryActions {
                        secondaryActions
                    }
                    if model.captureAvailable {
                        Button(action: onCapture) {
                            Image(systemName: captureExpanded ? "xmark" : "plus")
                                .contentTransition(.symbolEffect(.replace))
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(primaryInk)
                        .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                        .lifeBoardGlassIdentity(.capture)
                        .accessibilityLabel(captureExpanded ? "Close capture" : "Capture")
                        .accessibilityIdentifier("foundation.capture")
                    }
                }
            }
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .contain)
    }
}

private struct LifeBoardTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

private struct LifeBoardTransitionCoordinatorKey: EnvironmentKey {
    static let defaultValue: LifeBoardTransitionCoordinator? = nil
}

private struct LifeBoardScreenScaffoldHostedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var lifeBoardTransitionNamespace: Namespace.ID? {
        get { self[LifeBoardTransitionNamespaceKey.self] }
        set { self[LifeBoardTransitionNamespaceKey.self] = newValue }
    }

    var lifeBoardTransitionCoordinator: LifeBoardTransitionCoordinator? {
        get { self[LifeBoardTransitionCoordinatorKey.self] }
        set { self[LifeBoardTransitionCoordinatorKey.self] = newValue }
    }

    var lifeBoardScreenScaffoldIsHosted: Bool {
        get { self[LifeBoardScreenScaffoldHostedKey.self] }
        set { self[LifeBoardScreenScaffoldHostedKey.self] = newValue }
    }
}

/// Window-scoped state for transition identities and replay-safe one-shot effects.
@MainActor
@Observable
public final class LifeBoardTransitionCoordinator {
    public private(set) var routeRevision = 0
    private var consumedOneShotKeys: Set<String> = []

    public init() {}

    public func noteRouteChange() {
        routeRevision &+= 1
    }

    /// Returns true exactly once for a semantic event key during this window session.
    public func claimOneShot(_ key: String) -> Bool {
        consumedOneShotKeys.insert(key).inserted
    }

    public func resetOneShot(_ key: String) {
        consumedOneShotKeys.remove(key)
    }
}

/// Installs one namespace and one coordinator for an entire window hierarchy.
public struct LifeBoardTransitionHost<Content: View>: View {
    private let content: Content
    @Namespace private var namespace
    @State private var coordinator = LifeBoardTransitionCoordinator()

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .environment(\.lifeBoardTransitionNamespace, namespace)
            .environment(\.lifeBoardTransitionCoordinator, coordinator)
    }
}

private struct LifeBoardGlassIdentityModifier: ViewModifier {
    let role: LifeBoardGlassMorphRole?
    @Environment(\.lifeBoardTransitionNamespace) private var namespace

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), let namespace {
            content.glassEffectID(role?.rawValue, in: namespace)
        } else {
            content
        }
    }
}

private struct LifeBoardTransitionSourceModifier: ViewModifier {
    let id: String
    @Environment(\.lifeBoardTransitionNamespace) private var namespace

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct LifeBoardZoomDestinationModifier: ViewModifier {
    let sourceID: String
    @Environment(\.lifeBoardTransitionNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace, reduceMotion == false, ProcessInfo.processInfo.isMacCatalystApp == false {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}

public extension View {
    /// Apply after `lifeBoardSystemGlass` and inside a `GlassEffectContainer`.
    func lifeBoardGlassIdentity(_ role: LifeBoardGlassMorphRole?) -> some View {
        modifier(LifeBoardGlassIdentityModifier(role: role))
    }

    func lifeBoardTransitionSource(_ id: String) -> some View {
        modifier(LifeBoardTransitionSourceModifier(id: id))
    }

    func lifeBoardZoomDestination(sourceID: String) -> some View {
        modifier(LifeBoardZoomDestinationModifier(sourceID: sourceID))
    }
}

/// Canonical canvas for custom LifeBoard screens and presentations.
///
/// A hosted destination reveals the window's existing celestial renderer. A standalone
/// presentation receives a compatible renderer automatically, so secondary screens never
/// create their own gradient, cloud, or animation world.
public struct LifeBoardScreenScaffold<Content: View>: View {
    public let mode: LifeBoardScreenMode
    public let placement: LifeBoardAtmospherePlacement
    public let bottomClearance: CGFloat
    public let readableWidth: CGFloat?
    private let content: Content

    @Environment(\.lifeBoardAtmosphereSnapshot) private var atmosphereSnapshot
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lifeBoardScreenScaffoldIsHosted) private var scaffoldIsHosted

    public init(
        mode: LifeBoardScreenMode,
        placement: LifeBoardAtmospherePlacement = .focusedPresentation,
        bottomClearance: CGFloat = 0,
        readableWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.mode = mode
        self.placement = placement
        self.bottomClearance = bottomClearance
        self.readableWidth = readableWidth
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .top) {
            canvas
            content
                .environment(\.lifeBoardScreenScaffoldIsHosted, true)
                .frame(maxWidth: resolvedReadableWidth, maxHeight: .infinity, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if bottomClearance > 0 {
                        Color.clear.frame(height: bottomClearance)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var canvas: some View {
        ZStack {
            if scaffoldIsHosted == false, atmosphereIsHosted == false {
                LifeBoardAdaptiveAtmosphere(
                    snapshot: atmosphereSnapshot,
                    placement: mode.suppressesAmbientDetail ? .focusedPresentation : placement,
                    requestedTier: mode.suppressesAmbientDetail ? .static : .ambient2D
                )
            }

            if scaffoldIsHosted == false, mode.canvasOpacity > 0 {
                Color.lifeboard(.bgCanvas)
                    .opacity(reduceTransparency ? 1 : mode.canvasOpacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var resolvedReadableWidth: CGFloat? {
        guard layoutClass.isPad else { return nil }
        return readableWidth ?? mode.defaultReadableWidth
    }
}

/// Canonical wrapper for LifeBoard-owned sheets and covers. Apple-owned
/// controllers remain native and are intentionally exempt.
public struct LifeBoardPresentationScaffold<Content: View>: View {
    public let mode: LifeBoardScreenMode
    public let readableWidth: CGFloat?
    private let content: Content

    public init(
        mode: LifeBoardScreenMode,
        readableWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.mode = mode
        self.readableWidth = readableWidth
        self.content = content()
    }

    public var body: some View {
        LifeBoardScreenScaffold(
            mode: mode,
            placement: .focusedPresentation,
            bottomClearance: mode == .editor ? 8 : 0,
            readableWidth: readableWidth
        ) {
            content
                .scrollDismissesKeyboard(.interactively)
        }
        .presentationBackground(Color.lifeboard(.bgElevated))
        .presentationCornerRadius(mode == .critical ? 24 : 30)
        .presentationDragIndicator(mode == .critical ? .hidden : .visible)
    }
}
