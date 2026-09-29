import SwiftUI
import LifeBoardDomain

struct HomeQuickCaptureWidget: View {
    let captureRouter: CaptureRouter
    let palette: DaypartPalette

    var body: some View {
        HomeQuickCaptureCardContent(
            includesWater: V2FeatureFlags.careModulesV2Enabled,
            palette: palette,
            onCapture: { kind in
                captureRouter.request(kind: kind, source: .shell)
                Haptic.pick.play()
            }
        )
    }
}

struct HomeTimelineWidget: View {
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let palette: DaypartPalette

    var body: some View {
        HomeTimelineCardContent(
            items: projectionAdapter.snapshot.timelineItems,
            onOpen: { router.select(.plan) },
            palette: palette
        )
    }
}

struct HomeJournalWidget: View {
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette

    var body: some View {
        HomeJournalCardContent(
            onCapture: { captureRouter.request(kind: .journal, source: .widget) },
            onSearch: { router.navigate(.journalSearch, in: .home) },
            onReflection: {
                let week = Calendar.current.dateInterval(of: .weekOfYear, for: HomeReferenceClock.now)?.start ?? HomeReferenceClock.now
                router.navigate(.weeklyReflection(week), in: .home)
            },
            palette: palette
        )
    }
}

struct HomeProgressWidget: View {
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let dayLoopSummary: DayLoopSummary?
    let palette: DaypartPalette

    var body: some View {
        HomeProgressCardContent(
            title: router.dashboardMode == .lowEnergy ? String(localized: "Continuity") : String(localized: "Progress"),
            completionRate: projectionAdapter.snapshot.completionRate,
            openTaskCount: projectionAdapter.snapshot.openTaskCount,
            rhythm: HomeSectionCopy.dayLoopRhythmText(dayLoopSummary), palette: palette,
            onOpen: { router.select(.insights); router.push(.insightEvidence(nil), in: .insights) }
        )
    }
}

/// The product-owned mapping from a Home card to the typed leaf that owns its
/// review and capture experience. Kept pure so route coverage cannot regress
/// behind SwiftUI interaction tests alone.
struct HomeWidgetOpenTarget: Equatable {
    let route: AppRoute
    let actionTitle: String
}

enum HomeWidgetRouteResolver {
    static func target(
        for kind: DashboardWidgetKind,
        resolution: HomeCardResolution?,
        daypart: ResolvedDaypart
    ) -> HomeWidgetOpenTarget? {
        if let route = resolution?.primaryRoute {
            return HomeWidgetOpenTarget(
                route: route,
                actionTitle: resolution?.primaryActionTitle ?? String(localized: "Open")
            )
        }
        switch kind {
        case .goals: return .init(route: .goals, actionTitle: String(localized: "View goals"))
        case .routines: return .init(route: .routines(.daypart(daypart)), actionTitle: String(localized: "View routines"))
        case .lifeMoment: return .init(route: .lifeMoments(.overview), actionTitle: String(localized: "View moments"))
        case .logMeal: return .init(route: .nutrition(.logMeal), actionTitle: String(localized: "Log meal"))
        case .nutritionSummary: return .init(route: .nutrition(.dailySummary), actionTitle: String(localized: "View nutrition"))
        case .bodyMetric: return .init(route: .wellness(.bodyMetric(.bodyMass)), actionTitle: String(localized: "View body metrics"))
        case .workout: return .init(route: .wellness(.workouts), actionTitle: String(localized: "View workouts"))
        case .sleep: return .init(route: .wellness(.sleep), actionTitle: String(localized: "View sleep"))
        case .movement: return .init(route: .wellness(.movement), actionTitle: String(localized: "View movement"))
        case .fasting: return .init(route: .fasting, actionTitle: String(localized: "View fasting"))
        default: return nil
        }
    }

    static func route(for kind: DashboardWidgetKind) -> AppRoute? {
        switch kind {
        case .goals: .goals
        case .routines: .routines(.library)
        case .lifeMoment: .lifeMoments(.overview)
        case .bodyMetric: .wellness(.bodyMetric(.bodyMass))
        case .workout: .wellness(.workouts)
        case .sleep: .wellness(.sleep)
        case .movement: .wellness(.movement)
        case .nutritionSummary: .nutrition(.dailySummary)
        case .logMeal: .nutrition(.logMeal)
        case .fasting: .fasting
        default: nil
        }
    }
}

extension CaptureKind {
    var systemImage: String {
        switch self {
        case .task: return "checkmark.circle"
        case .habit: return "repeat"
        case .journal: return "book.closed"
        case .note: return "note.text"
        case .trackerEntry: return "dial.medium"
        case .mood: return "face.smiling"
        case .hydration: return "drop.fill"
        case .medicationEvent: return "pills"
        case .routineRun: return "figure.mind.and.body"
        case .timeBlock: return "rectangle.inset.filled.and.person.filled"
        }
    }
}

extension DashboardWidgetDescriptor {
    var defaultSize: WidgetSizePreset {
        for preferred in [WidgetSizePreset.standard, .wide, .compact, .tall] where supportedSizes.contains(preferred) {
            return preferred
        }
        return supportedSizes.first ?? .standard
    }

    var systemImage: String {
        switch kind {
        case .focusNow: return "scope"
        case .lifeSnapshot: return "heart.text.square"
        case .care: return "cross.case"
        case .tasks: return "checklist"
        case .routines: return "repeat"
        case .scheduleCapacity: return "calendar.badge.clock"
        case .quickCapture: return "plus.circle"
        case .compactTimeline: return "timeline.selection"
        case .journal: return "book.closed"
        case .progressReflection: return "chart.line.uptrend.xyaxis"
        case .fasting: return "timer"
        case .bodyMetric: return "scalemass"
        case .workout: return "figure.run"
        case .sleep: return "bed.double"
        case .movement: return "figure.walk"
        case .lifeMoment: return "calendar.badge.clock"
        default: return "square.grid.2x2"
        }
    }
}
extension HomeWidgetRouteResolver {
    /// Opens a dashboard widget's destination. `focusComposer` is the one
    /// case that stays on Home: quick capture just focuses the composer.
    @MainActor
    static func open(_ kind: DashboardWidgetKind, router: AppRouter, focusComposer: () -> Void) {

        if let route = HomeWidgetRouteResolver.route(for: kind) {
            router.openLeaf(route, in: .track)
            return
        }
        switch kind {
        case .focusNow, .tasks:
            router.select(.plan)
        case .lifeSnapshot, .care, .routines:
            router.select(.track)
        case .scheduleCapacity, .compactTimeline:
            router.navigate(.planDay, in: .plan)
        case .quickCapture:
            focusComposer()
        case .journal:
            router.select(.track)
        case .progressReflection:
            router.select(.insights)
        case .fasting:
            router.navigateReplacingPath(.fasting, in: .track)
        case .setupChecklist:
            // The card lists what is still optional to connect; Setup Center
            // is where each of those steps actually happens.
            router.push(.settingsDetail(.setupCenter), in: .home)
        default:
            break
        }
    
    }
}

/// How Home reaches the habit board without touching the composition root
/// itself: the shell injects both closures, so the runtime gate is still
/// evaluated on every body pass and the view model is still built only inside
/// the section's own autoclosure. Absent (the default) means no habits
/// section, exactly like an unconfigured container today.
struct HomeHabitsTodayCapability {
    let isAvailable: @MainActor () -> Bool
    let makeViewModel: @MainActor () -> HabitBoardViewModel
}

extension EnvironmentValues {
    @Entry var homeHabitsToday: HomeHabitsTodayCapability? = nil
}

/// Quick Capture's "type something". Home has no composer of its own — the
/// shell owns the one floating composer — so the shell supplies what the tap
/// does: raise that composer, or open the header's capture tray where the
/// composer isn't shown. It used to focus a composer Home never mounted, and
/// the card did nothing at all.
struct HomeFocusCaptureAction {
    let perform: @MainActor () -> Void
}

extension EnvironmentValues {
    @Entry var homeFocusCapture: HomeFocusCaptureAction? = nil
}

// Folded in from Foundation/Design/HomeFastingWidget.swift: its only consumer is
// `HomeDashboardWidget`, so it moved with the rest of the widget bodies.
struct HomeFastingWidget: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let palette: DaypartPalette
    let onOpen: () -> Void

    var body: some View {
        if let fast = lifeOSStore.activeFast {
            ActiveVisibleTimeline(every: 1) { context in
                let elapsed = fast.elapsed(at: context.date)
                let progress = fast.targetDuration.map { $0 > 0 ? min(1, elapsed / $0) : 0 } ?? 0
                HomeFastingCardContent(
                    elapsed: HomeSectionCopy.duration(elapsed),
                    finish: fast.targetDuration.map {
                        elapsed >= $0 ? String(localized: "Goal reached") : String(localized: "\(HomeSectionCopy.duration($0-elapsed)) to go")
                    } ?? String(localized: "No goal set"),
                    progress: progress, palette: palette, onOpen: onOpen,
                    onEnd: { Task { await lifeOSStore.endActiveFast() } }
                )
            }
        } else {
            HomeFastingCardContent(elapsed: nil, finish: "", progress: 0, palette: palette, onOpen: onOpen)
        }
    }
}
