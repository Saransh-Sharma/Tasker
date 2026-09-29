import Observation
import SwiftUI

/// The visual behavior of a LifeBoard screen. The mode controls only presentation;
/// domain state and navigation remain owned by the feature.
public enum ScreenMode: String, CaseIterable, Hashable, Sendable {
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

    /// `DESIGN.md` iPad: prose and forms are constrained to a 680-point readable
    /// width, primary compositions to 1080.
    ///
    /// These were 920 / 720 / 860 — three numbers, none of which appeared
    /// anywhere else in the codebase and none of which was either contract
    /// value. `680` and `1080` did not occur in the project at all.
    ///
    /// `.ambient` (the five roots) was `nil`, so on a 13" iPad or a wide Mac
    /// window the root dashboards ran edge to edge — phone cards stretched to
    /// ~1300 points. The atmosphere behind them is a sibling of the capped
    /// content and still bleeds to the edges.
    var defaultReadableWidth: CGFloat? {
        switch self {
        case .ambient:
            1080
        case .detail:
            1080
        case .editor:
            680
        case .utility, .focused, .critical:
            680
        }
    }
}

/// Stable semantic identities for custom Liquid Glass transitions.
public enum GlassMorphRole: String, Hashable, Sendable {
    case capture
    case captureTray
    case dockSelection
    case evaComposer
    case evaComposerActions
    case floatingToolbar
}

public struct RootHeaderModel: Equatable, Sendable {
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
public struct AppRootHeader: View {
    public let model: RootHeaderModel
    public let captureExpanded: Bool
    /// True when the header sits over a dark scenic backdrop. The daypart
    /// scene is independent of the system appearance, so a Night scene in Light
    /// appearance resolved cocoa ink onto navy sky and the greeting and date
    /// were effectively invisible.
    public let usesInverseInk: Bool
    public let onCapture: () -> Void
    public let secondaryActions: AnyView?
    /// Drawn before the title. Roots are stack roots and normally have no back
    /// affordance — the dock is the switcher. Eva is the exception: the shell
    /// hides the dock while its composer is focused, so it needs an exit that
    /// does not disappear with the keyboard.
    public let leadingAccessory: AnyView?
    /// Rides the context line (Home's "Smart ⌄" mode menu beside the date), so
    /// a root's lens lives where the person reads what day it is instead of in
    /// a second, repeated date row below the header.
    public let contextAccessory: AnyView?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        model: RootHeaderModel,
        captureExpanded: Bool = false,
        usesInverseInk: Bool = false,
        onCapture: @escaping () -> Void,
        leadingAccessory: AnyView? = nil,
        contextAccessory: AnyView? = nil,
        secondaryActions: AnyView? = nil
    ) {
        self.model = model
        self.captureExpanded = captureExpanded
        self.usesInverseInk = usesInverseInk
        self.onCapture = onCapture
        self.secondaryActions = secondaryActions
        self.leadingAccessory = leadingAccessory
        self.contextAccessory = contextAccessory
    }

    public var body: some View {
        let usesAccessibilityLayout = dynamicTypeSize.isAccessibilitySize
        let layout = usesAccessibilityLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))

        layout {
            VStack(alignment: .leading, spacing: 3) {
                // The accessory rides the title's own row rather than sitting
                // ahead of the whole block. At accessibility sizes this header
                // becomes a VStack, and as a sibling there the accessory was a
                // full extra row: it grew the header, pushed the destination
                // down, and cost Eva's composer its pinned dock clearance.
                HStack(spacing: 8) {
                    if let leadingAccessory {
                        leadingAccessory
                    }
                    Text(model.title)
                        .font(.system(
                            usesAccessibilityLayout ? .title3 : .title2,
                            design: .rounded,
                            weight: .bold
                        ))
                        .foregroundStyle(primaryInk)
                        .lineLimit(usesAccessibilityLayout ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .modifier(OptionalKineticGreeting(isEnabled: model.titleRespondsToTouch))
                }
                if let context = model.context {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(context)
                            .font(usesAccessibilityLayout ? .body : .subheadline)
                            .foregroundStyle(secondaryInk)
                            .lineLimit(usesAccessibilityLayout ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let contextAccessory {
                            contextAccessory
                                .foregroundStyle(primaryInk)
                        }
                    }
                    // Line the context up under the title rather than under
                    // the accessory that now precedes it.
                    .padding(.leading, leadingAccessory == nil ? 0 : 52)
                }
            }
            if usesAccessibilityLayout == false {
                Spacer(minLength: 8)
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if let secondaryActions {
                        secondaryActions
                    }
                    if model.captureAvailable {
                        Button(action: onCapture) {
                            Image(systemName: captureExpanded ? "xmark" : "plus")
                                .contentTransition(.symbolEffect(.replace))
                                // Scales with Dynamic Type up to the point the
                                // glyph would crowd its 44pt glass button.
                                .font(.body.weight(.semibold))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        // Same ground as the "More" control beside it: a
                        // surface backing under the glass, so the glyph reads
                        // when the sun or moon sits behind the header controls.
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .background(Color(SemanticColorTokens.foundationSurfaceSolid).opacity(0.72), in: Circle())
                        .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                        .lifeBoardGlassIdentity(.capture)
                        .accessibilityLabel(captureExpanded ? "Close capture" : "Capture")
                        .accessibilityIdentifier("foundation.capture")
                    }
                }
            }
            .frame(
                maxWidth: usesAccessibilityLayout ? .infinity : nil,
                alignment: .trailing
            )
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .contain)
    }
}

// The header's ink, kept apart from the view body.
extension AppRootHeader {
    private var primaryInk: Color {
        usesInverseInk
            ? Color(SemanticColorTokens.foundationOnScenicDark)
            : Color(SemanticColorTokens.inkPrimary)
    }

    /// The context line sits straight on the daypart scene, never on a card.
    /// `inkSecondary` measured 2.6:1 on the twilight sky in light appearance
    /// and 4.1:1 on the veiled morning and golden-hour scenes in dark — the sky
    /// moves through mid-tones a grey ink has no headroom for. Primary ink
    /// clears 6:1 on every phase; the title keeps the hierarchy through size
    /// and weight.
    private var secondaryInk: Color {
        usesInverseInk
            ? Color(SemanticColorTokens.foundationOnScenicDarkSecondary)
            : Color(SemanticColorTokens.inkPrimary)
    }
}

// `lifeBoardTransitionNamespace` and `lifeBoardTransitionSource` now live in
// `LifeBoardUI/TransitionSource.swift` so shared primitives — `OpenRow` above
// all — can declare themselves as a zoom source. The destination half stays
// here, because it is applied once per route by the shell rather than by
// content.

private struct TransitionCoordinatorKey: EnvironmentKey {
    static let defaultValue: TransitionCoordinator? = nil
}

private struct ScreenScaffoldHostedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var lifeBoardTransitionCoordinator: TransitionCoordinator? {
        get { self[TransitionCoordinatorKey.self] }
        set { self[TransitionCoordinatorKey.self] = newValue }
    }

    var lifeBoardScreenScaffoldIsHosted: Bool {
        get { self[ScreenScaffoldHostedKey.self] }
        set { self[ScreenScaffoldHostedKey.self] = newValue }
    }
}

/// Window-scoped state for transition identities and replay-safe one-shot effects.
@MainActor
@Observable
public final class TransitionCoordinator {
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
public struct TransitionHost<Content: View>: View {
    private let content: Content
    @Namespace private var namespace
    @State private var coordinator = TransitionCoordinator()

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .environment(\.lifeBoardTransitionNamespace, namespace)
            .environment(\.lifeBoardTransitionCoordinator, coordinator)
    }
}

private struct GlassIdentityModifier: ViewModifier {
    let role: GlassMorphRole?
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

private struct ZoomDestinationModifier: ViewModifier {
    let sourceID: String
    @Environment(\.lifeBoardTransitionNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        // Gated on `animationsDisabled` rather than `reduceMotion` alone: a zoom
        // route is a real 380-500 ms window, and the Foundation UI suite used to
        // pay it on every push because `-UI_TESTING` does not imply Reduce Motion.
        if let namespace,
           LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false,
           ProcessInfo.processInfo.isMacCatalystApp == false {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}

public extension View {
    /// Apply after `lifeBoardSystemGlass` and inside a `GlassEffectContainer`.
    func lifeBoardGlassIdentity(_ role: GlassMorphRole?) -> some View {
        modifier(GlassIdentityModifier(role: role))
    }

    func lifeBoardZoomDestination(sourceID: String) -> some View {
        modifier(ZoomDestinationModifier(sourceID: sourceID))
    }
}

/// Canonical canvas for custom LifeBoard screens and presentations.
///
/// A hosted destination reveals the window's existing celestial renderer. A standalone
/// presentation receives a compatible renderer automatically, so secondary screens never
/// create their own gradient, cloud, or animation world.
public struct ScreenScaffold<Content: View>: View {
    public let mode: ScreenMode
    public let placement: AtmospherePlacement
    public let bottomClearance: CGFloat
    public let readableWidth: CGFloat?
    private let content: Content

    @Environment(\.lifeBoardAtmosphereSnapshot) private var atmosphereSnapshot
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lifeBoardScreenScaffoldIsHosted) private var scaffoldIsHosted

    public init(
        mode: ScreenMode,
        placement: AtmospherePlacement = .secondary,
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
                // Only a genuinely immersive mode (`focused`, `critical`) gets a
                // still scene. Ordinary detail, editor and utility screens keep
                // the drifting atmosphere at reduced amplitude — freezing them
                // was a large part of why the app read as static everywhere
                // outside the five roots.
                AdaptiveAtmosphere(
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
