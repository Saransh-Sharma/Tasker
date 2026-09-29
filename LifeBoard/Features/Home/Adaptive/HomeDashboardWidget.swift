import SwiftUI
import LifeBoardDomain

struct HomeDashboardWidget: View {
    let placement: DashboardWidgetPlacementValue
    let kind: DashboardWidgetKind
    let preset: WidgetSizePreset
    let daypart: ResolvedDaypart
    let palette: DaypartPalette
    let store: AdaptiveHomeStore
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let captureRouter: CaptureRouter
    let modePolicy: any DashboardModePolicy
    let dashboardDensity: DashboardDensity
    let hasPlanningRepository: Bool
    let hasTrackFoundationRepository: Bool
    let dayLoopSummary: DayLoopSummary?
    let motionAnimation: Animation?
    let reduceMotion: Bool
    let selectedMood: JournalMood
    let moodEnergy: Int?
    @Binding var showsMoodDial: Bool
    @Binding var expandedTaskWidgetIDs: Set<UUID>
    let onOpenWidget: (DashboardWidgetKind) -> Void

    var body: some View {
        VStack(spacing: store.isCustomizing ? 6 : 0) {
            if store.isCustomizing {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.headline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Drag widget")
                        .accessibilityIdentifier("home.widget.drag.\(placement.id.uuidString)")

                    Spacer(minLength: 0)
                    HomeCustomizationControls(
                        placement: placement,
                        displayedKind: kind,
                        store: store
                    )
                }
                .padding(.horizontal, 4)
            }

            Group {
                if preset == .compact {
                    HomeGlanceWidget(
                        kind: kind,
                        daypart: daypart,
                        store: store,
                        lifeOSStore: lifeOSStore,
                        router: router,
                        palette: palette,
                        onOpenWidget: onOpenWidget
                    )
                } else if preset == .standard {
                    // Standard cards must preserve their meaningful primary actions.
                    // Collapsing these into a generic "Open" tile made capture,
                    // recovery, and evidence routes undiscoverable in the curated
                    // two-column Home layout.
                    switch kind {
                    case .care:
                        careWidget
                    case .tasks:
                        tasksWidget
                    case .routines:
                        routinesWidget
                    case .scheduleCapacity:
                        capacityWidget
                    case .journal:
                        journalWidget
                    case .progressReflection:
                        progressWidget
                    default:
                        archetypeWidget
                    }
                } else {
                    switch kind {
                    case .focusNow:
                        focusNowWidget
                    case .lifeSnapshot:
                        lifeSnapshotWidget
                    case .care:
                        careWidget
                    case .tasks:
                        tasksWidget
                    case .routines:
                        routinesWidget
                    case .scheduleCapacity:
                        capacityWidget
                    case .quickCapture:
                        HomeQuickCaptureWidget(captureRouter: captureRouter, palette: palette)
                    case .compactTimeline:
                        HomeTimelineWidget(
                            projectionAdapter: projectionAdapter,
                            router: router,
                            palette: palette
                        )
                    case .journal:
                        journalWidget
                    case .progressReflection:
                        progressWidget
                    case .fasting:
                        HomeFastingWidget(
                            lifeOSStore: lifeOSStore,
                            palette: palette,
                            onOpen: { onOpenWidget(.fasting) }
                        )
                    default:
                        // Was `EmptyView()`. Eleven registered kinds — goals,
                        // body metric, workout, sleep, movement, nutrition,
                        // recent meal, log meal, life moment, saved Eva
                        // insight and setup — reached this branch and drew
                        // nothing. Accessibility text sizes force this preset,
                        // so those cards were blank for anyone using large
                        // type. Every kind now has an archetype, and every
                        // archetype draws.
                        archetypeWidget
                    }
                }
            }
            .modifier(HomeCardIllustratedSurface(
                style: .init(kind: kind, preset: preset),
                palette: palette,
                showsScene: showsDecorativeScene
            ))
            .frame(minHeight: preset.minimumCardHeight)
        }
        .modifier(
            HomeCardReorderModifier(
                placementID: placement.id,
                isEnabled: store.isCustomizing,
                onMove: { sourceID, targetID in store.movePlacement(id: sourceID, before: targetID) },
                onResize: { expanding in store.cycleSize(id: placement.id, expanding: expanding) }
            )
        )
        .onLongPressGesture(minimumDuration: 0.45) {
            guard store.isCustomizing == false else { return }
            withAnimation(motionAnimation) { store.beginCustomization() }
            Haptic.pick.play()
        }
        .accessibilityAction(named: "Customize") { store.beginCustomization() }
        #if DEBUG
        .modifier(HomeProductionPlacementEvidence(id: placement.id))
        #endif
    }

    private var showsDecorativeScene: Bool {
        let snapshot = lifeOSStore.cardSnapshot(kind: kind, size: preset)
        let hasMedia: Bool
        if case .moment(let moment) = snapshot?.payload { hasMedia = moment.imagePath != nil } else { hasMedia = false }
        return HomeCardPresentationStyle.showsScene(availability: snapshot?.availability, hasUserMedia: hasMedia)
    }

    private var archetypeWidget: some View {
        HomeArchetypeWidget(
            kind: kind,
            preset: preset,
            daypart: daypart,
            palette: palette,
            store: store,
            lifeOSStore: lifeOSStore,
            router: router,
            modePolicy: modePolicy,
            dashboardDensity: dashboardDensity,
            onOpenWidget: onOpenWidget
        )
    }

    private var focusNowWidget: some View {
        HomeFocusNowWidget(
            preset: preset,
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            captureRouter: captureRouter,
            palette: palette
        )
    }

    private var lifeSnapshotWidget: some View {
        HomeLifeSnapshotWidget(
            lifeOSStore: lifeOSStore,
            router: router,
            captureRouter: captureRouter,
            palette: palette,
            selectedMood: selectedMood,
            moodEnergy: moodEnergy,
            showsMoodDial: $showsMoodDial
        )
    }

    private var careWidget: some View {
        HomeCareWidget(
            preset: preset,
            lifeOSStore: lifeOSStore,
            router: router,
            daypart: daypart,
            palette: palette
        )
    }

    private var tasksWidget: some View {
        HomeTasksWidget(
            preset: preset,
            placementID: placement.id,
            lifeOSStore: lifeOSStore,
            router: router,
            captureRouter: captureRouter,
            hasPlanningRepository: hasPlanningRepository,
            palette: palette,
            motionAnimation: motionAnimation,
            reduceMotion: reduceMotion,
            expandedTaskWidgetIDs: $expandedTaskWidgetIDs
        )
    }

    private var routinesWidget: some View {
        HomeRoutinesWidget(
            preset: preset,
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            hasTrackFoundationRepository: hasTrackFoundationRepository,
            daypart: daypart,
            palette: palette
        )
    }

    private var capacityWidget: some View {
        HomeCapacityWidget(
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            palette: palette
        )
    }

    private var journalWidget: some View {
        HomeJournalWidget(
            router: router,
            captureRouter: captureRouter,
            palette: palette
        )
    }

    private var progressWidget: some View {
        HomeProgressWidget(
            projectionAdapter: projectionAdapter,
            router: router,
            dayLoopSummary: dayLoopSummary,
            palette: palette
        )
    }
}

/// Renders a card from its registered archetype rather than a per-kind
/// case. This is the universal body: any registered kind draws something
/// meaningful at any preset, which is what makes the old `EmptyView()`
/// fallthrough unrepresentable.
struct HomeArchetypeWidget: View {
    let kind: DashboardWidgetKind
    let preset: WidgetSizePreset
    let daypart: ResolvedDaypart
    let palette: DaypartPalette
    let store: AdaptiveHomeStore
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let modePolicy: any DashboardModePolicy
    let dashboardDensity: DashboardDensity
    let onOpenWidget: (DashboardWidgetKind) -> Void

    /// Counts opens so the card warps as its destination arrives — the
    /// `source` of source → travel → settle. Without it a whole screen
    /// replaces a motionless card, which reads as a cut.

    var body: some View {
        let descriptor = store.registry.descriptor(for: kind)
        let resolution = lifeOSStore.cardResolution(kind: kind, size: preset)
        let target = HomeWidgetRouteResolver.target(
            for: kind,
            resolution: resolution,
            daypart: daypart
        )
        HomeCardBody(
            snapshot: relabeledSnapshot(resolution?.snapshot ?? lifeOSStore.cardSnapshot(kind: kind, size: preset), target: target),
            archetype: descriptor?.archetype ?? .queue,
            preset: preset,
            palette: palette,
            title: descriptor?.title ?? "LifeBoard",
            symbol: HomeSectionCopy.symbol(for: kind, store: store),
            queueLimit: modePolicy
                .sectionBudget(for: router.dashboardMode)
                .applying(dashboardDensity)
                .queueLimit,
            onAction: { action in
                if let target {
                    router.openLeaf(target.route, in: .track)
                } else if let destination = action.destination {
                    router.select(destination)
                } else {
                    onOpenWidget(kind)
                }
            },
            onOpen: {
                if let target {
                    router.openLeaf(target.route, in: .track)
                } else {
                    onOpenWidget(kind)
                }
            }
        )
        // No warp on the card itself: `cardMorphWarp` belongs behind a
        // row-to-detail transition, and it distorted this card's text. The
        // shell already warps the atmosphere plane when the route is pushed.
        .accessibilityHint("Opens the source")
    }

    private func relabeledSnapshot(
        _ snapshot: HomeCardSnapshot?,
        target: HomeWidgetOpenTarget?
    ) -> HomeCardSnapshot? {
        guard var snapshot, let target, snapshot.actions.isEmpty == false else { return snapshot }
        snapshot.actions = snapshot.actions.enumerated().map { index, action in
            guard index == 0 else { return action }
            return HomeCardActionDescriptor(
                id: action.id,
                title: target.actionTitle,
                systemImage: action.systemImage,
                role: action.role,
                destination: action.destination,
                requiresMutationPreview: action.requiresMutationPreview
            )
        }
        return snapshot
    }
}

struct HomeGlanceWidget: View {
    let kind: DashboardWidgetKind
    let daypart: ResolvedDaypart
    let store: AdaptiveHomeStore
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let palette: DaypartPalette
    let onOpenWidget: (DashboardWidgetKind) -> Void

    var body: some View {
        let descriptor = store.registry.descriptor(for: kind)
        let target = HomeWidgetRouteResolver.target(
            for: kind,
            resolution: lifeOSStore.cardResolution(kind: kind, size: .compact),
            daypart: daypart
        )
        HomeGlanceCardContent(
            title: HomeCardPresentationStyle.glanceTitle(for: kind, fallback: descriptor?.title ?? "LifeBoard"),
            summary: HomeSectionCopy.widgetSummary(kind, size: .compact, lifeOSStore: lifeOSStore),
            symbol: descriptor?.systemImage ?? "square.grid.2x2",
            palette: palette,
            onOpen: {
            if let target {
                router.openLeaf(target.route, in: .track)
            } else {
                onOpenWidget(kind)
            }

            }
        )
    }
}

struct HomeCustomizationControls: View {
    let placement: DashboardWidgetPlacementValue
    /// The kind the card is currently *drawing*, which is what "Freeze current
    /// card" has to capture. Resolved by the caller so smart-slot resolution
    /// happens exactly once per placement.
    let displayedKind: DashboardWidgetKind
    let store: AdaptiveHomeStore

    var body: some View {
        Menu {
            if let descriptor = store.registry.descriptor(for: DashboardWidgetKind(rawValue: placement.widgetKind)) {
                Section("Size") {
                    ForEach(WidgetSizePreset.allCases, id: \.self) { size in
                        if descriptor.supportedSizes.contains(size) {
                            Button(size.title) { store.resizePlacement(id: placement.id, to: size) }
                        }
                    }
                }
            }
            Button("Move earlier", systemImage: "arrow.up") { store.movePlacement(id: placement.id, offset: -1) }
            Button("Move later", systemImage: "arrow.down") { store.movePlacement(id: placement.id, offset: 1) }
            Button(
                placement.ownership == .smart ? "Make pinned" : "Make adaptive",
                systemImage: placement.ownership == .smart ? "pin" : "sparkles"
            ) {
                store.toggleSmartSlot(id: placement.id)
            }
            if placement.ownership == .smart {
                let slot = placement.smartSlot ?? .init()
                Section("Smart slot") {
                    Button(
                        slot.frozenWidgetKind == nil ? "Freeze current card" : "Resume adapting",
                        systemImage: slot.frozenWidgetKind == nil ? "snowflake" : "sparkles"
                    ) {
                        let displayed = displayedKind
                        store.updateSmartSlot(id: placement.id) {
                            $0.frozenWidgetKind = slot.frozenWidgetKind == nil ? displayed.rawValue : nil
                        }
                    }
                    Menu("When it adapts", systemImage: "clock") {
                        ForEach(HomeSmartSlotSchedule.allCases, id: \.self) { schedule in
                            Button {
                                store.updateSmartSlot(id: placement.id) { $0.schedule = schedule }
                            } label: {
                                if slot.schedule == schedule {
                                    Label(schedule.title, systemImage: "checkmark")
                                } else {
                                    Text(schedule.title)
                                }
                            }
                        }
                    }
                    Menu("Allowed sections", systemImage: "square.grid.2x2") {
                        ForEach(Destination.allCases, id: \.self) { destination in
                            Button {
                                store.updateSmartSlot(id: placement.id) { configuration in
                                    if configuration.allowedDestinations.contains(destination),
                                       configuration.allowedDestinations.count > 1 {
                                        configuration.allowedDestinations.remove(destination)
                                    } else {
                                        configuration.allowedDestinations.insert(destination)
                                    }
                                }
                            } label: {
                                Label(
                                    destination.title,
                                    systemImage: slot.allowedDestinations.contains(destination) ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                    }
                }
            }
            Button("Hide", systemImage: "eye.slash", role: .destructive) { store.hidePlacement(id: placement.id) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Circle())
                .lifeboardElevation(.e1, cornerRadius: 24, includesBorder: false)
        }
        .accessibilityLabel("Edit card")
        .accessibilityIdentifier("home.widget.edit.\(placement.id.uuidString)")
        .accessibilityAction(named: "Move before") { store.movePlacement(id: placement.id, offset: -1) }
        .accessibilityAction(named: "Move after") { store.movePlacement(id: placement.id, offset: 1) }
        .accessibilityAction(named: "Hide") { store.hidePlacement(id: placement.id) }
    }
}

/// Drives the one-shot erosion when a card is hidden from Home. The animation
/// owns only its own progress; the layout draft has already removed the card,
/// so an interrupted dissolve can never strand the board in a wrong state.
struct HomeCardDissolveModifier: ViewModifier {
    let isDissolving: Bool
    let tint: Color
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    private let duration: TimeInterval = 0.36

    func body(content: Content) -> some View {
        content
            .lifeboardDissolveAway(progress: progress, tint: tint)
            .onChange(of: isDissolving) { _, dissolving in
                guard dissolving else {
                    progress = 0
                    return
                }
                // The role resolves Reduce Motion and the UI-testing switches;
                // with no animation there is nothing to watch, so finish now.
                guard let animation = MotionProfile.cardReflow.animation(reduceMotion: reduceMotion) else {
                    onFinish()
                    return
                }
                withAnimation(animation) { progress = 1 }
                Task {
                    try? await Task.sleep(for: .seconds(duration))
                    progress = 0
                    onFinish()
                }
            }
    }
}

struct HomeCardReorderModifier: ViewModifier {
    let placementID: UUID
    let isEnabled: Bool
    let onMove: (UUID, UUID) -> Void
    let onResize: (Bool) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .draggable(placementID.uuidString) {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Color(SemanticColorTokens.foundationSurfaceSolid).opacity(0.94))
                        .frame(width: 170, height: 108)
                        .overlay {
                            Image(systemName: "hand.draw.fill")
                                .font(.title2)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                        .lifeboardElevation(.e2, cornerRadius: Radius.card, includesBorder: false)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let source = items.compactMap(UUID.init(uuidString:)).first,
                          source != placementID else { return false }
                    onMove(source, placementID)
                    Haptic.pick.play()
                    return true
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .onEnded { value in
                            if value.magnification > 1.08 { onResize(true) }
                            if value.magnification < 0.92 { onResize(false) }
                        }
                )
        } else {
            content
        }
    }
}

extension WidgetSizePreset {
    var minimumCardHeight: CGFloat {
        switch self {
        case .compact: return 104
        case .standard, .wide: return 178
        case .tall: return 260
        case .expanded: return 340
        }
    }
}
