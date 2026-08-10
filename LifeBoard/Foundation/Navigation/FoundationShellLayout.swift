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
        // The floating chrome draws as a bottom overlay, and each root reserves
        // its measured height as a clear bottom inset. This is the measured
        // content clearance the plan calls for: every root's final row clears
        // the dock and composer, with no blank footer band and no content
        // resting under the translucent composer. (A TabView's own
        // safeAreaInset does not propagate into per-tab scroll views.)
        return GeometryReader { geometry in
            // A plain stack rather than a TabView.
            //
            // At compact width the TabView switched nothing: the floating dock
            // is the switcher and the system tab bar was hidden, so all it
            // contributed was a container whose cross-dissolve could not be
            // replaced. Holding the roots in a stack lets a root change read as
            // travel — the arriving root slides in from the side it sits on in
            // the dock — while visited dashboard roots stay in the hierarchy,
            // so their scroll position and navigation depth survive. Eva is
            // rebuilt on demand to release its visibility-scoped runtime work.
            //
            // The regular-width shell keeps its TabView: there the sidebar and
            // top bar are the switcher, and there is nothing to replace it with.
            ZStack {
                // Nothing is ever behind the roots for longer than it takes one
                // of them to build, but "nothing" here is the system's white
                // window backing, not the warm canvas. Laying the canvas under
                // the stack means any gap reads as the app's own paper.
                Color(SemanticColorTokens.foundationCanvas)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                ForEach(Destination.allCases, id: \.self) { destination in
                    // Built when first selected, and kept afterwards. Dashboard
                    // roots stay alive; Eva is removed when inactive. Building
                    // all five up front would wake every root's stores on launch.
                    if RootRetention.isRendered(
                        destination,
                        selected: router.selectedDestination,
                        visited: visitedRoots
                    ) {
                        let isCurrent = router.selectedDestination == destination
                        destinationNavigation(destination, router: router, atmosphereSnapshot: atmosphereSnapshot)
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear.frame(height: reservedChromeHeight(for: destination))
                            }
                            .offset(
                                x: RootTransition.offset(
                                    for: destination,
                                    selected: router.selectedDestination,
                                    distance: reduceMotion ? 0 : RootTransition.slideDistance
                                )
                            )
                            .opacity(isCurrent ? 1 : 0)
                            .zIndex(isCurrent ? 1 : 0)
                            // A root that is not on screen must not take taps or
                            // hold VoiceOver focus while it sits in the stack.
                            .allowsHitTesting(isCurrent)
                            .accessibilityHidden(isCurrent == false)
                    }
                }
            }
            .onChange(of: router.selectedDestination, initial: true) { previous, destination in
                // Retention only. Selection alone is enough to *render* a root
                // (see `isRendered` above); this is what keeps it in the
                // hierarchy after the selection moves on.
                visitedRoots = RootRetention.retained(
                    visited: visitedRoots,
                    previous: previous,
                    selected: destination
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                // Composer and dock share one GlassEffectContainer so the two
                // chrome layers refract and morph as a single surface rather
                // than two stacked panes.
                if showsGlobalChrome(for: router.selectedDestination) {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) {
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
                                    lifeThreadComposerIsFocused: $lifeThreadComposerIsFocused
                                )
                            }
                            compactNavigationChrome(
                                router: router,
                                paletteMaxHeight: max(176, min(320, geometry.size.height * 0.38))
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
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
                }
            }
        }
        .background(Color.clear.ignoresSafeArea())
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
                            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                                router.activateRoot(destination)
                            }
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
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
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
        case .eva: "Private context, shared only when you choose."
        }
    }

    func captureTrayTitle(_ kind: CaptureKind) -> String {
        switch kind {
        case .trackerEntry: "Tracker"
        case .mood: "Care"
        default: kind.title
        }
    }

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
                GlassEffectContainer(spacing: 10) {
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
                .padding(.bottom, 10)
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
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
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
        .padding(6)
        .frame(maxWidth: 720)
        .lifeBoardGlassSurface(cornerRadius: 24, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foundation.expanded.rootSwitcher")
    }
}
