import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// Root retention and destination construction: which roots stay built, what
/// each one renders, and the atmosphere and Home-card plumbing around them.
///
/// An `extension` rather than a new type: these read the shell's injected
/// dependencies and its `@State` directly, and rehousing them would mean
/// duplicating that list rather than separating anything.
extension FoundationShell {
    func retainedDestinationNavigation(
        _ destination: Destination,
        router: AppRouter,
        atmosphereSnapshot: AtmosphereSnapshot
    ) -> AnyView {
        guard destination != .eva || router.selectedDestination == .eva else {
            return AnyView(Color.clear.accessibilityHidden(true))
        }
        return AnyView(
            destinationNavigation(
                destination,
                router: router,
                atmosphereSnapshot: atmosphereSnapshot
            )
        )
    }

    func destinationNavigation(
        _ destination: Destination,
        router: AppRouter,
        atmosphereSnapshot: AtmosphereSnapshot
    ) -> some View {
        NavigationStack(path: pathBinding(for: destination)) {
            ZStack {
                activeAtmosphere(for: destination, snapshot: atmosphereSnapshot)
                ScreenScaffold(mode: .ambient, placement: .root(destination)) {
                    VStack(spacing: 0) {
                        if V2FeatureFlags.lifeBoardPremiumIAV5Enabled,
                           router.path(for: destination).isEmpty {
                            sharedRootHeader(destination, atmosphereSnapshot: atmosphereSnapshot)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .padding(.bottom, 6)
                                .accessibilityIdentifier("\(destination.rawValue).header")
                        }
                        StableDestinationRoot {
                            destinationRoot(destination, router: router)
                        }
                    }
                }
                .toolbar(
                    V2FeatureFlags.lifeBoardPremiumIAV5Enabled ? .hidden : .visible,
                    for: .navigationBar
                )
            }
                .navigationDestination(for: AppRoute.self) { route in
                    if let transitionID = route.spatialTransitionID {
                        ZStack {
                            // The warp rides the background plane only. SurfaceCard
                            // content, text and charts must never distort.
                            activeAtmosphere(for: destination, snapshot: atmosphereSnapshot)
                                .lifeboardCardMorphWarp(
                                    origin: .center,
                                    trigger: routeTransitionTrigger
                                )
                            ScreenScaffold(mode: route.screenMode, placement: .root(destination)) {
                                routeView(route)
                            }
                        }
                        .lifeBoardZoomDestination(sourceID: transitionID)
                        .toolbar(.visible, for: .navigationBar)
                        .onAppear {
                            routeTransitionTrigger &+= 1
                            router.acknowledgeRouteAppearance(route, in: destination)
                        }
                    } else {
                        ZStack {
                            activeAtmosphere(for: destination, snapshot: atmosphereSnapshot)
                            ScreenScaffold(mode: route.screenMode, placement: .root(destination)) {
                                routeView(route)
                            }
                        }
                        .toolbar(.visible, for: .navigationBar)
                        .onAppear {
                            router.acknowledgeRouteAppearance(route, in: destination)
                        }
                    }
                }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color.clear)
    }

    @ViewBuilder
    func activeAtmosphere(
        for destination: Destination,
        snapshot: AtmosphereSnapshot
    ) -> some View {
        if destination == runtime.router.selectedDestination {
            AdaptiveAtmosphere(
                snapshot: snapshot,
                placement: .root(destination),
                requestedTier: runtime.preferences.renderingTier,
                comfortProfile: runtime.preferences.comfortProfile
            )
            .lifeboardDaypartBloom(
                center: .topTrailing,
                trigger: daypartBloomTrigger,
                daypart: snapshot.semanticDaypart
            )
            .ignoresSafeArea()
        } else {
            Color.clear
        }
    }

    func homeCardKinds(for destination: Destination) -> [DashboardWidgetKind]? {
        switch destination {
        case .home: return nil
        case .plan: return [.focusNow, .tasks, .scheduleCapacity, .compactTimeline]
        case .track:
            var kinds: [DashboardWidgetKind] = [.care, .routines, .goals, .fasting, .journal, .lifeSnapshot]
            if V2FeatureFlags.wellnessCoreV1Enabled {
                kinds += [.bodyMetric, .workout, .sleep, .movement]
            }
            if V2FeatureFlags.nutritionV1Enabled {
                kinds += [.nutritionSummary, .recentMeal, .logMeal]
            }
            if V2FeatureFlags.lifeMomentsV1Enabled {
                kinds.append(.lifeMoment)
            }
            return kinds
        case .insights: return [.progressReflection, .lifeSnapshot]
        case .eva: return [.progressReflection, .journal, .evaConversation]
        }
    }

    @MainActor
    func addCardToHome(
        _ kind: DashboardWidgetKind,
        size: WidgetSizePreset,
        from destination: Destination
    ) async {
        do {
            let before = try await dashboardLayoutRepository.fetchHome()
                ?? DashboardLayoutValue(
                    mode: .smart,
                    isDefault: true,
                    placements: CoreDataDashboardLayoutRepository.curatedHomePlacements()
                )
            var draft = HomeLayoutDraft(layout: before)
            let registry = DefaultDashboardWidgetRegistry.shared
            guard let descriptor = registry.descriptor(for: kind) else { return }
            if let existing = draft.current.placements.first(where: { $0.widgetKind == kind.rawValue }),
               descriptor.multiplicity == .singleton {
                draft.setVisible(true, id: existing.id)
                draft.resize(id: existing.id, to: size, registry: registry)
                draft.setOwnership(.pinned, id: existing.id)
                draft.setSource(.init(destination: destination), id: existing.id)
            } else {
                draft.add(kind: kind, size: size, registry: registry)
                if let added = draft.current.placements.last(where: { $0.widgetKind == kind.rawValue }) {
                    draft.setSource(.init(destination: destination), id: added.id)
                }
            }
            let after = try draft.committedLayout()
            try await dashboardLayoutRepository.saveHome(after)
            let transaction = HomeLayoutTransaction(before: before, after: after)
            withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86)) {
                homeCardReceipt = .init(
                    title: "\(descriptor.title) added to Home",
                    transaction: transaction
                )
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch {
            runtime.router.activeAlert = .init(
                title: "Couldn’t update Home",
                message: "Your current Home layout is unchanged. Please try again."
            )
        }
    }

    func destinationRoot(
        _ destination: Destination,
        router: AppRouter
    ) -> AnyView {
        if destination == .home,
           showsReferenceHome == false {
            return AnyView(AdaptiveHome(
                projectionAdapter: homeProjectionAdapter,
                preferences: runtime.preferences,
                router: router,
                captureRouter: runtime.captureRouter,
                repository: dashboardLayoutRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                trackFoundationRepository: trackFoundationRepository,
                goalSampleProvider: goalSampleProvider,
                wellnessRepository: wellnessRepository,
                nutritionRepository: nutritionRepository,
                lifeMomentRepository: lifeMomentRepository,
                showsEmbeddedComposer: false,
                onCustomizationChanged: { isCustomizing in
                    homeIsCustomizing = isCustomizing
                }
            ))
        } else if destination == .plan,
                  V2FeatureFlags.phase1ExecutionFlagshipEnabled,
                  let planDependencies {
            return AnyView(PlanRootView(
                dependencies: planDependencies,
                rescueRefreshGeneration: planRescueRefreshGeneration,
                onOpenFocus: { _ in router.select(.plan) },
                onAskEva: { router.select(.eva) },
                onOpenWeeklyPlanner: { router.push(.weeklyPlanningWorkspace(.week), in: .plan) },
                onOpenWeeklyReview: { router.push(.weeklyReview, in: .plan) },
                onOpenOverdueRescue: presentPlanOverdueRescue,
                onReviewCapture: { item in
                    // Filing an unreviewed capture goes through the ordinary task
                    // editor seeded with the raw text, so the parser's proposal is
                    // something the user confirms rather than inherits.
                    runtime.captureRouter.request(
                        CaptureRequest(kind: .task, source: .shell, prefilledText: item.title)
                    )
                },
                onOpenTask: { router.push(.taskDetail($0), in: .plan) },
                onOpenProject: { router.push(.project($0), in: .plan) }
            ))
        } else if destination == .plan {
            return AnyView(PlanRollbackRouteView(router: router))
        } else if destination == .track,
                  V2FeatureFlags.trackFoundationsV2Enabled,
                  V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
            return AnyView(TrackFoundationRootView(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                linkedMutationApplier: routineLinkedMutationApplier,
                goalSampleProvider: goalSampleProvider,
                starterPackMutationApplier: starterPackMutationApplier,
                habitRecoveryMutationApplier: habitRecoveryMutationApplier,
                sourcePickerRepository: ComposedTypedSourcePickerRepository(
                    planningProjection: planningRepository,
                    trackFoundation: trackFoundationRepository,
                    phaseII: phaseIIRepository,
                    habitRuntime: habitRuntimeReadRepository
                ),
                nutritionRepository: nutritionRepository,
                lifeMomentRepository: lifeMomentRepository,
                wellnessRepository: wellnessRepository,
                onOpenHabitBoard: { router.push(.habitBoard, in: .track) },
                onOpenHealth: { router.push(.health, in: .track) }
            ))
        } else if destination == .track {
            return AnyView(BehaviorAreaRouteView(
                repository: phaseIIRepository,
                initialArea: .medication,
                onOpenHabitBoard: { router.push(.habitBoard, in: .track) },
                onOpenHealth: { router.push(.health, in: .track) }
            ))
        } else if destination == .home {
            return AnyView(ReferenceDashboard(preferences: runtime.preferences)
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
            )
        } else if destination == .insights {
            return AnyView(InsightsDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                wellnessRepository: wellnessRepository,
                planningRepository: planningRepository,
                gamificationRepository: gamificationRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: router
            ))
        } else if destination == .eva {
            return AnyView(EvaDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: router
            ))
        }
        return AnyView(EmptyView())
    }
}
