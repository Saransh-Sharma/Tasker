import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// The two shell layouts — the compact dock and the expanded sidebar — plus
/// the chrome they share.
///
/// An `extension` rather than a new type: these read the shell's injected
/// dependencies and its `@State` directly, and rehousing them would mean
/// duplicating that list rather than separating anything.
extension FoundationShell {
    func compactShell(
        router: AppRouter,
        atmosphereSnapshot: AtmosphereSnapshot
    ) -> some View {
        @Bindable var router = router
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
                // invisible roots. The custom dock remains the only visible tab
                // authority; its local matched-geometry animation is independent
                // of this selection transaction.
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
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear.frame(height: reservedDestinationChromeHeight(for: destination))
                            }
                            // `DESIGN.md`'s motion grammar is source → travel →
                            // settle, and a root change had no travel at all:
                            // `RootTransition.offset` was written for exactly
                            // this, carried a full doc comment and its own
                            // tests, and had zero production callers — the
                            // content pane just cut. Each retained root now
                            // rests on the side it occupies in the dock order
                            // and slides to zero as it arrives, so the eye
                            // travels the same direction as the dock's selected
                            // well. Offset only: the shader half of this
                            // (`LifeBoardRootTravelShear`) was deleted for
                            // flashing the whole screen, and is not coming back.
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
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                // Composer and dock share one GlassEffectContainer so the two
                // chrome layers refract and morph as a single surface rather
                // than two stacked panes.
                if showsCompactChrome(for: router.selectedDestination) {
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
                                    scrollObserver: composerScrollObserver
                                )
                            }
                            compactNavigationChrome(
                                router: router,
                                paletteMaxHeight: paletteMaxHeight
                            )
                            // The dock's *top edge*, not its height.
                            //
                            // Eva replaces the global composer rather than
                            // stacking under it, so its composer has to clear
                            // the dock and nothing else. Height alone is not
                            // enough for that: the chrome stack also carries the
                            // global composer on other destinations, and the
                            // dock's own layout height exceeds the pill that is
                            // actually drawn. Measuring where the dock starts
                            // relative to the shell answers the only question
                            // Eva is asking — how far above the bottom edge its
                            // composer must sit — without modelling anything
                            // about what else shares the container.
                            //
                            // The shell's bottom safe-area inset comes back out
                            // of the answer. Eva's composer is placed by
                            // `safeAreaInset(edge: .bottom)`, so it already sits
                            // above the home indicator; the shell this dock is
                            // measured against does not. Leaving the inset in
                            // counted that strip twice and lifted the composer
                            // by a home indicator's height on every device that
                            // has one.
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                let dockTop = proxy.frame(in: .named(shellCoordinateSpace)).minY
                                return shellHeight - dockTop - shellBottomInset
                            } action: { clearance in
                                measuredDockClearance = max(0, clearance)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, FoundationShell.compactChromeBottomPadding)
                    .background(alignment: .bottom) {
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
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        measuredChromeHeight = height
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("LifeBoardCompactChrome")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .coordinateSpace(name: FoundationShell.shellCoordinateSpace)
        .background(Color.clear.ignoresSafeArea())
        // Compact width only. At regular width the composer anchors to the
        // detail column with room to spare, so there is nothing to compress.
        .environment(\.lifeBoardComposerScrollObserver, composerScrollObserver)
    }

    /// Horizontal centre of a dock slot in unit space, so the refraction lens
    /// tracks the selection pill rather than sitting at a fixed point.

    func compactNavigationChrome(router: AppRouter, paletteMaxHeight: CGFloat) -> some View {
        // The enclosing GlassEffectContainer lives in `compactShell` so the
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
                                    .font(.system(size: 17, weight: router.selectedDestination == destination ? .semibold : .regular))
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
                        .accessibilityValue(
                            router.path(for: destination).isEmpty
                                ? "Root"
                                : "Detail depth \(router.path(for: destination).count)"
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
                // The selected well genuinely bends the content beneath it, so
                // the dock reads as glass rather than a tinted capsule. Bounded
                // to six points and centred on the current target.
                .lifeboardLiquidGlassRefract(
                    center: dockSelectionCenter(for: router.selectedDestination),
                    radius: 0.16,
                    strength: 1
                )
                .lifeBoardGlassSurface(cornerRadius: 30, interactive: true)
                .lifeBoardGlassIdentity(.dockSelection)
                .overlay { RoundedRectangle(cornerRadius: 30).stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1) }
                .shadow(color: Color(SemanticColorTokens.foundationWarmShadow).opacity(0.18), radius: 12, y: 6)
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
        let headerOwnsCapture = showsFloatingComposer(for: destination) == false
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
        case .plan: "Plan"
        case .track: "Track"
        case .insights: "Insights"
        case .eva: "Eva"
        }
    }

    func rootHeaderContext(for destination: Destination) -> String {
        switch destination {
        case .home:
            Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .plan: "Make room for what matters."
        case .track: "Record what helps, skip what doesn’t."
        case .insights: "Notice change without turning life into a score."
        // The privacy promise moved to the lock badge on Eva's own strip,
        // which expands to the full sentence and the sharing controls on
        // tap. Repeating it here spent two wrapped lines of a chat screen
        // restating something that never changes.
        case .eva: "Ask or use / commands"
        }
    }

    func captureTrayTitle(_ kind: CaptureKind) -> String {
        switch kind {
        case .trackerEntry: "Tracker"
        case .mood: "Care"
        default: kind.title
        }
    }

}

/// The regular-width shell, split from the compact one above.
///
/// Two extensions rather than one, because the file-size gate measures the
/// largest *top-level declaration* — that number is the `-Onone` stack-overflow
/// predictor, since Debug inlines computed `some View` properties into their
/// caller's frame. One extension holding both shells crossed 400 lines when the
/// root-travel shear landed. The compact/expanded seam is where it was always
/// going to divide: the two share no state and no layout.
extension FoundationShell {
    func expandedShell(
        router: AppRouter,
        atmosphereSnapshot: AtmosphereSnapshot
    ) -> some View {
        @Bindable var router = router
        // Keep TabView's selection and state-retention semantics, but let the
        // clay switcher below be the one regular-width root authority. A
        // sidebar-adaptable style duplicated navigation at full width and hid
        // its reveal affordance at some Split View widths.
        return TabView(selection: $router.selectedDestination) {
            ForEach(Destination.allCases, id: \.self) { destination in
                Tab(destination.title, systemImage: destination.systemImage, value: destination) {
                    retainedDestinationNavigation(
                        destination,
                        router: router,
                        atmosphereSnapshot: atmosphereSnapshot
                    )
                    .toolbar(.hidden, for: .tabBar)
                    .environment(
                        \.lifeBoardRootActivity,
                        rootActivity(for: destination, router: router)
                    )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        // Eva hosts its own composer, so it reserves nothing.
                        Color.clear.frame(
                            height: showsFloatingComposer(for: destination)
                                ? reservedChromeHeight(for: destination)
                                : 0
                        )
                    }
                }
                .accessibilityIdentifier("foundation.destination.\(destination.rawValue)")
            }
        }
        .tabViewStyle(.tabBarOnly)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            // Keep the five roots directly reachable to touch, pointer,
            // keyboard, VoiceOver, and Switch Control at every regular width.
            // Detail and ritual routes keep their own navigation bar and do
            // not need a second switcher.
            if router.path(for: router.selectedDestination).isEmpty {
                expandedRootSwitcher(router: router)
            }
        }
        .overlay(alignment: .bottom) {
            // Capture is not iPhone-only: the composer anchors to the detail
            // column at regular width too.
            if showsFloatingComposer(for: router.selectedDestination),
               showsGlobalChrome(for: router.selectedDestination) {
                GlassEffectContainer(spacing: 12) {
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
                        lifeThreadComposerIsFocused: $lifeThreadComposerIsFocused
                    )
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    measuredChromeHeight = height
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("LifeBoardExpandedChrome")
            }
        }
    }

    func expandedRootSwitcher(router: AppRouter) -> some View {
        @Bindable var router = router
        return HStack(spacing: 4) {
            ForEach(Destination.allCases, id: \.self) { destination in
                let isSelected = router.selectedDestination == destination
                Button {
                    router.select(destination)
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
                                Capsule(style: .continuous)
                                    .fill(Color(SemanticColorTokens.foundationCanvasSoft).opacity(0.82))
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
                .keyboardShortcut(
                    KeyEquivalent(Character(String(
                        Destination.allCases.firstIndex(of: destination).map { $0 + 1 } ?? 0
                    ))),
                    modifiers: [.command, .option]
                )
            }
        }
        .padding(8)
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
