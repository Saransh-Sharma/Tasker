import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// The shell layout — one tree whose chrome is either the compact dock or the
/// regular-width top switcher — plus the chrome both styles share.
///
/// An `extension` rather than a new type: these read the shell's injected
/// dependencies and its `@State` directly, and rehousing them would mean
/// duplicating that list rather than separating anything.
extension FoundationShell {
    /// The single shell tree.
    ///
    /// `chromeStyle` only changes values — insets, caps, whether the dock row is
    /// drawn — never which container holds the roots. The TabView and each root's
    /// navigation stack keep their identity when a window crosses the
    /// dock/switcher breakpoint, and the composer keeps its structural slot in
    /// the chrome stack, so its draft survives too.
    func shellBody(
        router: AppRouter,
        atmosphereSnapshot: AtmosphereSnapshot
    ) -> some View {
        @Bindable var router = router
        let usesDock = chromeStyle == .dock
        // The floating chrome draws as a bottom overlay. Dashboard roots reserve
        // its measured height here; Eva receives the same measurement through
        // the environment so its nested composer inset can own the final
        // placement. (A TabView's own safeAreaInset does not propagate into
        // per-tab scroll views.)
        return GeometryReader { geometry in
            let shellHeight = geometry.size.height
            let shellBottomInset = geometry.safeAreaInsets.bottom
            let shellCoordinateSpace = FoundationShell.shellCoordinateSpace
            let paletteMaxHeight = max(176, min(320, shellHeight * 0.38))
            ZStack {
                Color(SemanticColorTokens.foundationCanvas)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                // Native tab containment keeps each dashboard root's navigation
                // and scroll state while allowing the system to stop scheduling
                // invisible roots. The dock or the switcher is the only visible
                // tab authority; the system tab bar stays hidden.
                TabView(selection: $router.selectedDestination) {
                    ForEach(Destination.allCases, id: \.self) { destination in
                        Tab(destination.title, systemImage: destination.systemImage, value: destination) {
                            retainedDestinationNavigation(
                                destination,
                                router: router,
                                atmosphereSnapshot: atmosphereSnapshot
                            )
                            .toolbar(.hidden, for: .tabBar)
                            .environment(
                                \.evaComposerBottomClearance,
                                evaComposerBottomClearance(for: destination)
                            )
                            .environment(
                                \.lifeBoardRootActivity,
                                rootActivity(for: destination, router: router)
                            )
                            .environment(
                                \.lifeBoardShellBottomClearance,
                                shellBottomReservation(for: destination)
                            )
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear.frame(height: shellBottomReservation(for: destination))
                            }
                            // `DESIGN.md`'s motion grammar is source → travel →
                            // settle. Each retained root rests on the side it
                            // occupies in the root order and slides to zero as it
                            // arrives, so the eye travels the same direction as
                            // the dock's or switcher's selected well. Offset only:
                            // the shader half of this (`LifeBoardRootTravelShear`)
                            // was deleted for flashing the whole screen.
                            .offset(
                                x: RootTransition.offset(
                                    for: destination,
                                    selected: router.selectedDestination
                                )
                            )
                            .animation(
                                MotionProfile.route.animation(reduceMotion: reduceMotion),
                                value: router.selectedDestination
                            )
                        }
                        .accessibilityIdentifier("foundation.destination.\(destination.rawValue)")
                    }
                }
                .tabViewStyle(.tabBarOnly)
                .toolbar(.hidden, for: .tabBar)
                .modifier(RootTypingContract(
                    composerIsFocused: $lifeThreadComposerIsFocused,
                    focusCapture: homeFocusCaptureAction
                ))
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                // Composer and dock share one GlassEffectContainer so the two
                // chrome layers refract and morph as a single surface rather
                // than two stacked panes.
                if showsShellChrome(for: router.selectedDestination) {
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            if showsFloatingComposer(for: router.selectedDestination) {
                                LifeThreadComposerHost(
                                    router: router,
                                    composer: lifeThreadComposer,
                                    dictationController: dictationController,
                                    homeViewModel: homeViewModel,
                                    runtime: runtime,
                                    lifeBoardMutationCoordinator: lifeBoardMutationCoordinator,
                                    universalInputCoordinator: universalInputCoordinator,
                                    phaseIIRepository: phaseIIRepository,
                                    presentPlanOverdueRescue: presentPlanOverdueRescue,
                                    liveIntentResolveTask: $liveIntentResolveTask,
                                    composerAudioStore: $composerAudioStore,
                                    showsComposerAudioCapture: $showsComposerAudioCapture,
                                    showsDocumentScanner: $showsDocumentScanner,
                                    lifeBoardActionReceipt: $lifeBoardActionReceipt,
                                    lifeThreadComposerIsFocused: $lifeThreadComposerIsFocused,
                                    // Compact width only. At regular width the
                                    // composer has room to spare, so there is
                                    // nothing to compress on scroll.
                                    scrollObserver: usesDock ? composerScrollObserver : nil
                                )
                            }
                            if usesDock {
                                compactNavigationChrome(
                                    router: router,
                                    paletteMaxHeight: paletteMaxHeight
                                )
                                // The dock's *top edge*, not its height.
                                //
                                // Eva replaces the global composer rather than
                                // stacking under it, so its composer has to clear
                                // the dock and nothing else. Measuring where the
                                // dock starts relative to the shell answers the
                                // only question Eva is asking. The shell's bottom
                                // safe-area inset comes back out: Eva's composer
                                // already sits above the home indicator.
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    let dockTop = proxy.frame(in: .named(shellCoordinateSpace)).minY
                                    return shellHeight - dockTop - shellBottomInset
                                } action: { clearance in
                                    measuredDockClearance = max(0, clearance)
                                }
                            }
                        }
                    }
                    // The dock was uncapped: at accessibility sizes an iPad kept
                    // the dock and drew five icon-only buttons across ~1340 pt.
                    .frame(maxWidth: usesDock ? 560 : 720)
                    .padding(.horizontal, usesDock ? 12 : 20)
                    .padding(.bottom, usesDock ? FoundationShell.compactChromeBottomPadding : 12)
                    .background(alignment: .bottom) {
                        if usesDock {
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color(SemanticColorTokens.foundationCanvas)
                                        .opacity(HomeBottomBarVisibilityPolicy.chromeBackdropMaximumOpacity),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 44)
                            .offset(y: -(measuredChromeHeight - 22))
                            .allowsHitTesting(false)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        measuredChromeHeight = height
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(usesDock ? "LifeBoardCompactChrome" : "LifeBoardExpandedChrome")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .coordinateSpace(name: FoundationShell.shellCoordinateSpace)
        .background(Color.clear.ignoresSafeArea())
        .environment(\.lifeBoardComposerScrollObserver, composerScrollObserver)
    }

    /// Whether the bottom chrome stack is drawn at all.
    ///
    /// With the dock, the dock is always there (the composer may not be). With
    /// the switcher, the stack is only the composer, so it follows it.
    func showsShellChrome(for destination: Destination) -> Bool {
        switch chromeStyle {
        case .dock:
            showsCompactChrome(for: destination)
        case .topSwitcher:
            showsFloatingComposer(for: destination) && showsGlobalChrome(for: destination)
        }
    }

    /// Bottom space each root reserves for the chrome stack drawn over it.
    func shellBottomReservation(for destination: Destination) -> CGFloat {
        switch chromeStyle {
        case .dock:
            reservedDestinationChromeHeight(for: destination)
        case .topSwitcher:
            // Eva hosts its own composer, so it reserves nothing.
            showsFloatingComposer(for: destination) ? reservedChromeHeight(for: destination) : 0
        }
    }

    /// Horizontal centre of a dock slot in unit space, so the refraction lens
    /// tracks the selection pill rather than sitting at a fixed point.

    func compactNavigationChrome(router: AppRouter, paletteMaxHeight: CGFloat) -> some View {
        // The enclosing GlassEffectContainer lives in `shellBody` so the
        // dock and composer morph together.
        Group {
            ZStack {
                HStack(spacing: 0) {
                    ForEach(Destination.allCases, id: \.self) { destination in
                        Button {
                            router.activateRoot(destination)
                            // Intent-named rather than engine-named: this is a
                            // selection moving, and `Haptic` is the layer that
                            // honours `MotionPolicy.allowsHaptics`.
                            Haptic.pick.play()
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: destination.systemImage)
                                    // Scales with Dynamic Type; a fixed 17pt is
                                    // the one size that cannot. Bounded at
                                    // `accessibility1` because the dock is
                                    // fixed chrome carrying five targets — past
                                    // that the glyphs crowd each other out and
                                    // start eating the composer above them.
                                    .font(.body.weight(router.selectedDestination == destination ? .semibold : .regular))
                                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                    .modifier(
                                        DockLift(
                                            isSelected: router.selectedDestination == destination,
                                            reduceMotion: reduceMotion
                                        )
                                    )
                                if dynamicTypeSize.isAccessibilitySize == false {
                                    Text(destination.title)
                                        .font(.caption2.weight(router.selectedDestination == destination ? .semibold : .regular))
                                }
                            }
                            .foregroundStyle(
                                router.selectedDestination == destination
                                    ? Color(SemanticColorTokens.inkPrimary)
                                    : Color(SemanticColorTokens.inkSecondary)
                            )
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background {
                                if router.selectedDestination == destination {
                                    Capsule()
                                        .fill(Color(SemanticColorTokens.foundationSurfaceSelected).opacity(0.9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 5)
                                        .matchedGeometryEffect(id: "foundation.dock.selection", in: dockSelectionNamespace)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(destination.title)
                        // "Root" / "Detail depth N" was a test probe read
                        // aloud to everyone. UI tests still get it; people get
                        // what tapping does instead.
                        .accessibilityValue(
                            LifeBoardAnimation.isUITesting
                                ? (router.path(for: destination).isEmpty
                                    ? "Root"
                                    : "Detail depth \(router.path(for: destination).count)")
                                : ""
                        )
                        .accessibilityHint(
                            router.selectedDestination == destination && router.path(for: destination).isEmpty == false
                                ? "Returns to the top of \(destination.title)"
                                : ""
                        )
                        .accessibilityAddTraits(router.selectedDestination == destination ? .isSelected : [])
                        .accessibilityIdentifier("foundation.destination.\(destination.rawValue)")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .animation(
                    MotionProfile.selection.animation(reduceMotion: reduceMotion),
                    value: router.selectedDestination
                )
                // No refraction on this row. `lifeboardLiquidGlassRefract` bent
                // the row it was applied to — the dock's own glyph and label —
                // so the selected destination rendered as a warped blob smeared
                // over its title ("Pıan") in every appearance. The system glass
                // below already refracts what is behind the dock.
                .lifeBoardGlassSurface(cornerRadius: Radius.dock, interactive: true)
                .lifeBoardGlassIdentity(.dockSelection)
                .overlay {
                    // Continuous corners, like every other rounded shape in the
                    // product; a plain `cornerRadius:` draws circular ones.
                    RoundedRectangle(cornerRadius: Radius.dock, style: .continuous)
                        .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
                }
                .lifeboardElevation(.e3, cornerRadius: Radius.dock, includesBorder: false)
            }
        }
    }

    func rootActivity(for destination: Destination, router: AppRouter) -> RootActivityState {
        RootActivityState(
            isSelected: router.selectedDestination == destination,
            sceneIsActive: scenePhase == .active
        )
    }

    func sharedRootHeader(
        _ destination: Destination,
        atmosphereSnapshot: AtmosphereSnapshot
    ) -> some View {
        // Where the floating composer is mounted it owns capture; a second
        // "+" in the header would offer the same tray twice.
        // Eva is the exception: its own composer is the capture surface, so a
        // header "+" there was a second, different "add" beside it.
        let headerOwnsCapture = destination != .eva && showsFloatingComposer(for: destination) == false
        return ScreenRootHeader(
            destination: destination,
            atmosphereSnapshot: atmosphereSnapshot,
            runtime: runtime,
            headerOwnsCapture: headerOwnsCapture,
            title: rootHeaderTitle(for: destination),
            context: rootHeaderContext(for: destination),
            homeCardKinds: homeCardKinds(for: destination),
            primaryCaptureKinds: primaryCaptureKinds,
            trayTitle: captureTrayTitle,
            onCommitCapture: commitCompactCapture,
            captureState: $compactCaptureState,
            captureRippleTrigger: $compactCaptureRippleTrigger,
            showsHomeDisplayPanel: $showsHomeDisplayPanel,
            homeCardPlacementRequest: $homeCardPlacementRequest
        )
    }

    func rootHeaderTitle(for destination: Destination) -> String {
        switch destination {
        case .home: runtime.preferences.resolvedDaypart().greeting
        case .plan: String(localized: "Plan")
        // Track is where a person records what the day was like, so it opens
        // on the same greeting as Home rather than on its own name. It used to
        // show "Track" here and then its own greeting underneath, two headings
        // that filled the first screen.
        case .track: runtime.preferences.resolvedDaypart().greeting
        case .insights: String(localized: "Insights")
        case .eva: String(localized: "Eva")
        }
    }

    /// The line under a root's title: a fact, or nothing. An empty string
    /// drops the line (`ScreenRootHeader` passes `nil` for it).
    func rootHeaderContext(for destination: Destination) -> String {
        switch destination {
        // Home and Track carry a control on this line (the mode menu, the
        // daypart indicator), so both keep the date under their greeting.
        case .home, .track:
            Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .plan, .insights: ""
        // The privacy promise moved to the lock badge on Eva's own strip,
        // which expands to the full sentence and the sharing controls on
        // tap. Repeating it here spent two wrapped lines of a chat screen
        // restating something that never changes.
        case .eva: String(localized: "Ask \(AssistantIdentityText.currentSnapshot().displayName) or type /")
        }
    }

    func captureTrayTitle(_ kind: CaptureKind) -> String {
        switch kind {
        case .trackerEntry: String(localized: "Tracker")
        case .mood: String(localized: "Mood")
        default: kind.title
        }
    }

}

/// The regular-width switcher. Root shortcuts (⌘1–5) live in the main menu —
/// see `AppCommandMenu`.
///
/// Two extensions rather than one, because the file-size gate measures the
/// largest *top-level declaration* — that number is the `-Onone` stack-overflow
/// predictor, since Debug inlines computed `some View` properties into their
/// caller's frame.
extension FoundationShell {
    func expandedRootSwitcher(router: AppRouter) -> some View {
        @Bindable var router = router
        return HStack(spacing: 4) {
            ForEach(Destination.allCases, id: \.self) { destination in
                let isSelected = router.selectedDestination == destination
                Button {
                    // The same rule as the phone dock: a second tap on the
                    // current root returns to its top.
                    router.activateRoot(destination)
                    Haptic.pick.play()
                } label: {
                    Label(destination.title, systemImage: destination.systemImage)
                        // A type token rather than a hand-rolled weight ramp.
                        // `DESIGN.md` wants selection carried by "position,
                        // shape, label, and accessibility state — not tint
                        // alone", and the capsule plus `.isSelected` already do
                        // that, so the weight was a fourth cue doing no work the
                        // others were not.
                        .lifeboardFont(.buttonSmall)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .background {
                            if isSelected {
                                // One lens that moves between roots, as on the
                                // phone dock — `DESIGN.md` asks the iPad
                                // switcher for the same contract, and a capsule
                                // drawn inside each button simply appeared and
                                // disappeared.
                                // The recessed well plus a hairline: the soft
                                // canvas was the same cream as the bar in light,
                                // so the selected root was nearly invisible.
                                Capsule(style: .continuous)
                                    .fill(Color(SemanticColorTokens.foundationSurfaceRecessed))
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
                                    }
                                    .matchedGeometryEffect(
                                        id: "foundation.dock.selection",
                                        in: dockSelectionNamespace
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                // `DESIGN.md` iPad: "Pointer targets, hover treatment, keyboard
                // focus, and root shortcuts are part of the design." The
                // shortcuts were here; the pointer treatment was not.
                .hoverEffect(.highlight)
                .accessibilityIdentifier("foundation.expanded.destination.\(destination.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(8)
        .animation(MotionProfile.selection.animation(reduceMotion: reduceMotion), value: router.selectedDestination)
        .frame(maxWidth: 720)
        // The switcher is the iPad's dock. `DESIGN.md`'s shape vocabulary gives
        // dock and composer clusters 30; 24 is the *hero* radius, which the
        // document calls "the continuity" between a card and the hero it opens
        // into — chrome borrowing it blurs that.
        .lifeBoardGlassSurface(cornerRadius: Radius.dock, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.dock, style: .continuous)
                .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foundation.expanded.rootSwitcher")
    }
}

/// The keyboard contract for the five roots (`DESIGN.md`).
///
/// The keyboard belongs to the floating composer, not to root content, so any
/// drag on a root puts it away. That is the platform default for scroll views,
/// stated once here because four roots had each narrowed it to
/// `.interactively`, which only moves once the drag reaches the keyboard. A tap
/// on a root puts the keyboard away too and still reaches what was tapped;
/// one-tap commit controls hold off while the composer has the keyboard. Home's
/// Quick Capture card raises the same composer.
struct RootTypingContract: ViewModifier {
    let composerIsFocused: FocusState<Bool>.Binding
    let focusCapture: HomeFocusCaptureAction

    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.immediately)
            .dismissesKeyboardOnTap(composerIsFocused)
            .environment(\.homeFocusCapture, focusCapture)
    }
}
