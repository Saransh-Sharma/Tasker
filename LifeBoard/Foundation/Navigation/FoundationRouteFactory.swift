import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// The shell's route factory: one `AppRoute` case in, one destination view out.
///
/// An `extension` rather than a separate type because the factory reads sixteen
/// of the shell's injected repositories and nothing else — rehousing them in a
/// second struct would have duplicated the dependency list without separating
/// anything. Those sixteen members are `internal` instead of `private` for this
/// file's benefit; the rest of the shell's state stays private.
extension FoundationShell {
    @ViewBuilder
    func planRoute(lens: PlanLens, title: String, systemImage: String) -> some View {
        if V2FeatureFlags.phase1ExecutionFlagshipEnabled,
           let planDependencies {
            PlanRootView(
                dependencies: planDependencies,
                initialLens: lens,
                rescueRefreshGeneration: planRescueRefreshGeneration,
                onOpenFocus: { _ in runtime.router.select(.plan) },
                onAskEva: { runtime.router.select(.eva) },
                onOpenWeeklyPlanner: { runtime.router.push(.weeklyPlanningWorkspace(.week), in: .plan) },
                onOpenWeeklyReview: { runtime.router.push(.weeklyReview, in: .plan) },
                onOpenOverdueRescue: presentPlanOverdueRescue,
                onOpenTask: { runtime.router.push(.taskDetail($0), in: .plan) },
                onOpenProject: { runtime.router.push(.project($0), in: .plan) }
            )
        } else {
            PlanRollbackRouteView(router: runtime.router)
        }
    }

    @ViewBuilder
    func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .tokenGallery:
            TokenGallery(preferences: runtime.preferences)
        case .referenceDashboard:
            ReferenceDashboard(preferences: runtime.preferences)
                .navigationTitle("Reference dashboard")
                .navigationBarTitleDisplayMode(.inline)
        case .planDay:
            planRoute(lens: .day, title: "Day", systemImage: "sun.max")
        case .planWeek:
            planRoute(lens: .week, title: "Week", systemImage: "calendar")
        case .backlog:
            planRoute(lens: .backlog, title: "Backlog", systemImage: "tray.full")
        // `weeklyPlanner` is the retired four-step wizard's route. It is kept so
        // persisted navigation state, deep links and notification payloads
        // written before the workspace existed still restore — into the surface
        // that replaced it. `WeeklyPlannerView` is now unreachable in the
        // product and can be deleted once a release has passed.
        case .weeklyPlanner, .weeklyPlanningWorkspace:
            if let planDependencies, let entry = route.weeklyPlanningEntry {
                WeeklyPlanningWorkspaceRoute(
                    dependencies: planDependencies,
                    entry: entry,
                    onClose: { runtime.router.pop(in: .plan) }
                )
            } else {
                PlanRollbackRouteView(router: runtime.router)
            }
        case .weeklyReview:
            // Insights pushes this into its own stack; popping `.plan`
            // unconditionally meant Close did nothing when opened from there.
            WeeklyReviewRoute(
                onClose: { runtime.router.pop(in: runtime.router.selectedDestination) }
            )
        case .trackHistory:
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                TrackFoundationRootView(
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
                    initialLens: .history,
                    onOpenHabitBoard: { runtime.router.push(.habitBoard, in: .track) },
                    onOpenHealth: { runtime.router.push(.health, in: .track) }
                )
            } else {
                BehaviorAreaRouteView(
                    repository: phaseIIRepository,
                    initialArea: .medication,
                    onOpenHabitBoard: { runtime.router.push(.habitBoard, in: .track) },
                    onOpenHealth: { runtime.router.push(.health, in: .track) }
                )
            }
        case .insightEvidence(let evidenceID):
            InsightsDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                wellnessRepository: wellnessRepository,
                planningRepository: planningRepository,
                gamificationRepository: gamificationRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: runtime.router,
                // A named record wants the widest window, not just today.
                initialLens: evidenceID == nil ? .overview : .review,
                focusedEvidenceID: evidenceID
            )
        case .healthInsight(let domain):
            HealthInsightDetailView(
                domain: domain,
                wellnessRepository: wellnessRepository
            )
        case .settings:
            SettingsRouteView(router: runtime.router)
        case .settingsDetail(let settingsRoute):
            SettingsDetailRouteView(route: settingsRoute, router: runtime.router)
        case .taskDetail(let id):
            if let planDependencies {
                TaskRouteView(
                    id: id,
                    dependencies: planDependencies,
                    router: runtime.router
                )
            } else {
                PlanRollbackRouteView(router: runtime.router)
            }
        case .habitDetail(let id):
            HabitRouteView(id: id, repository: habitRuntimeReadRepository, router: runtime.router)
        case .habitBoard:
            HabitBoardScreen(
                viewModel: CompositionRoot.shared.makeHabitBoardViewModel(),
                presentationStyle: .pushed,
                onManageHabits: { runtime.router.push(.habitLibrary, in: .track) }
            )
        case .habitLibrary:
            HabitLibraryView(
                viewModel: CompositionRoot.shared.makeNewHabitLibraryViewModel(),
                presentationStyle: .pushed
            )
        case .trackerDetail(let id):
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                TrackerRouteView(id: id, repository: phaseIIRepository)
            } else {
                BehaviorAreaRouteView(
                    repository: phaseIIRepository,
                    initialArea: .trackers
                )
            }
        case .careLibrary:
            BehaviorAreaRouteView(
                repository: phaseIIRepository,
                initialArea: .medication,
                onOpenHabitBoard: { runtime.router.push(.habitBoard, in: .track) },
                onOpenHealth: { runtime.router.push(.health, in: .track) }
            )
        case .health:
            HealthHubView(
                trackRepository: trackFoundationRepository,
                wellnessRepository: wellnessRepository,
                nutritionRepository: nutritionRepository
            )
        case .project(let id):
            if let planDependencies {
                ProjectRouteView(
                    id: id,
                    dependencies: planDependencies,
                    router: runtime.router
                )
            } else {
                PlanRollbackRouteView(router: runtime.router)
            }
        case .routine(let id):
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                RoutineRouteView(
                    id: id,
                    repository: trackFoundationRepository,
                    router: runtime.router
                )
            } else {
                BehaviorAreaRouteView(repository: phaseIIRepository)
            }
        case .goal(let id):
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                GoalRouteView(
                    id: id,
                    repository: trackFoundationRepository,
                    sampleProvider: goalSampleProvider,
                    sourceRepository: ComposedTypedSourcePickerRepository(
                        planningProjection: planningRepository,
                        trackFoundation: trackFoundationRepository,
                        phaseII: phaseIIRepository,
                        habitRuntime: habitRuntimeReadRepository
                    ),
                    router: runtime.router
                )
            } else {
                BehaviorAreaRouteView(repository: phaseIIRepository)
            }
        case .journalDay(let id):
            JournalDayRouteView(id: id, repository: phaseIIRepository)
        case .journalSearch:
            JournalModuleView(
                repository: phaseIIRepository,
                initialSection: .library,
                router: runtime.router
            )
        case .weeklyReflection(let date):
            JournalModuleView(
                repository: phaseIIRepository,
                initialSection: .insights,
                reflectionWeekDate: date,
                router: runtime.router
            )
        case .notesLibrary(let destination):
            KnowledgeModuleView(
                repository: phaseIIRepository,
                initialDestination: destination
            )
        case .note(let id):
            KnowledgeModuleView(repository: phaseIIRepository, initialNoteID: id)
        case .knowledgeFolder(let id):
            KnowledgeModuleView(repository: phaseIIRepository, initialFolderID: id)
        case .focusSession(let id):
            if let planDependencies {
                FocusSessionRouteView(
                    sessionID: id,
                    dependencies: planDependencies,
                    router: runtime.router,
                    rescueRefreshGeneration: planRescueRefreshGeneration,
                    onOpenOverdueRescue: presentPlanOverdueRescue
                )
            } else {
                PlanRollbackRouteView(router: runtime.router)
            }
        case .dayClose(let date):
            // Two gates, both required. The flag hides the ritual; the
            // dependencies are what it is built from. Either being absent
            // restores the previous end-of-day experience, which is no ritual
            // at all — and nothing written while it was on becomes unreachable,
            // because everything it writes lives in Plan's own ledger.
            if V2FeatureFlags.dayCloseV1Enabled, let planDependencies {
                DayCloseRouteView(
                    date: date,
                    mode: .close,
                    dependencies: planDependencies,
                    router: runtime.router
                )
                .lifeBoardZoomDestination(sourceID: DayLoopTransition.close)
            } else {
                PlanRollbackRouteView(router: runtime.router)
            }
        case .dayOpen(let date):
            if V2FeatureFlags.dayCloseV1Enabled, let planDependencies {
                DayCloseRouteView(
                    date: date,
                    mode: .open,
                    dependencies: planDependencies,
                    router: runtime.router
                )
                .lifeBoardZoomDestination(sourceID: DayLoopTransition.open)
            } else {
                PlanRollbackRouteView(router: runtime.router)
            }
        }
    }}
