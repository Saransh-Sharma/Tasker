import Foundation
import LifeBoardDomain

public struct ResolvedEvaNavigationTarget: Equatable, Sendable {
    public let destination: Destination
    public let route: AppRoute?
    public let requiresProtectedJournalOpen: Bool
}

public enum EvaNavigationTargetResolver {
    public static func resolve(_ target: EvaNavigationTarget) -> ResolvedEvaNavigationTarget {
        switch target {
        case .home, .today: .init(destination: .home, route: nil, requiresProtectedJournalOpen: false)
        case .dayPlan: .init(destination: .plan, route: .planDay, requiresProtectedJournalOpen: false)
        case .weekPlan: .init(destination: .plan, route: .planWeek, requiresProtectedJournalOpen: false)
        case .weeklyReview: .init(destination: .plan, route: .weeklyReview, requiresProtectedJournalOpen: false)
        case .backlog: .init(destination: .plan, route: .backlog, requiresProtectedJournalOpen: false)
        case .focus: .init(destination: .plan, route: .focusSession(nil), requiresProtectedJournalOpen: false)
        case .habits: .init(destination: .track, route: .habitBoard, requiresProtectedJournalOpen: false)
        case .trackers: .init(destination: .track, route: .careLibrary, requiresProtectedJournalOpen: false)
        case .journal: .init(destination: .track, route: .journalSearch, requiresProtectedJournalOpen: true)
        case .notes: .init(destination: .track, route: .notesLibrary(.collection(.all)), requiresProtectedJournalOpen: false)
        case .goals: .init(destination: .track, route: .goals, requiresProtectedJournalOpen: false)
        case .routines: .init(destination: .track, route: .routines(.library), requiresProtectedJournalOpen: false)
        case .lifeMoments: .init(destination: .track, route: .lifeMoments(.overview), requiresProtectedJournalOpen: false)
        case .wellness: .init(destination: .track, route: .wellness(.bodyMetric(.bodyMass)), requiresProtectedJournalOpen: false)
        case .nutrition: .init(destination: .track, route: .nutrition(.dailySummary), requiresProtectedJournalOpen: false)
        case .fasting: .init(destination: .track, route: .fasting, requiresProtectedJournalOpen: false)
        case .insights: .init(destination: .insights, route: nil, requiresProtectedJournalOpen: false)
        case .settings: .init(destination: .eva, route: .settings, requiresProtectedJournalOpen: false)
        case .eva: .init(destination: .eva, route: nil, requiresProtectedJournalOpen: false)
        }
    }

    @MainActor
    public static func open(_ target: EvaNavigationTarget, with router: AppRouter) {
        let resolved = resolve(target)
        guard let route = resolved.route else {
            router.activateRoot(resolved.destination)
            return
        }
        if resolved.requiresProtectedJournalOpen {
            router.openProtectedJournalRoute(route, in: resolved.destination)
        } else {
            router.openLeaf(route, in: resolved.destination)
        }
    }
}

extension AppRouter {
    /// The one way a surface asks Eva something. Submits the launch request
    /// the chat consumes, then either lifts a sheet over the current root or
    /// falls back to the Eva tab (flag off, or already on Eva).
    func presentEva(context: EvaLaunchContext?, prompt: String?) {
        try? EvaChatLaunchRequestStore.shared.submit(.init(prompt: prompt, context: context))
        switch EvaPresentationPolicy.decide(flagOn: V2FeatureFlags.evaContextSheetV1Enabled, current: selectedDestination) {
        case .sheet:
            evaSheetRequest = EvaSheetRequest(context: context)
        case .tab:
            select(.eva)
        }
    }

    public func select(_ destination: Destination) {
        selectedDestination = destination
    }

    /// What File ▸ New (⌘N) should create where the person is now.
    ///
    /// Journal and notes screens get their own kind of new thing; everywhere
    /// else it is a task, as before. Eva is handled by the command itself (a new
    /// chat is not a capture).
    public var contextualCaptureKind: CaptureKind {
        switch path(for: selectedDestination).last {
        case .journalDay, .journalSearch, .weeklyReflection:
            .journal
        case .notesLibrary, .note, .knowledgeFolder:
            .note
        default:
            .task
        }
    }

    /// Activates a root, popping it when it is already selected.
    public func activateRoot(_ destination: Destination) {
        if selectedDestination == destination {
            popToRoot(in: destination)
        } else {
            select(destination)
        }
    }

    public func path(for destination: Destination) -> [AppRoute] {
        paths[destination] ?? []
    }

    public func setPath(_ path: [AppRoute], for destination: Destination) {
        if let pendingRouteRequest,
           pendingRouteRequest.destination == destination,
           path != [pendingRouteRequest.route] {
            return
        }
        paths[destination] = path
    }

    /// Performs an interactive cross-root transition without racing SwiftUI's
    /// current TabView selection write-back. Boundary routing and restoration
    /// continue to use synchronous `push`; views use this method when a tap
    /// changes both the primary destination and its typed leaf.
    @discardableResult
    public func navigate(
        _ route: AppRoute,
        in destination: Destination
    ) -> _Concurrency.Task<Void, Never> {
        if selectedDestination != destination { select(destination) }
        return Task { @MainActor [weak self] in
            // Let TabView/NavigationStack finish writing the interaction that
            // exposed this root before appending its next typed leaf. Without
            // this boundary, a rapid root-pop followed by a new action can let
            // SwiftUI write the just-popped empty path over the new route.
            await Task.yield()
            guard let self, self.selectedDestination == destination else { return }
            self.push(route, in: destination)
        }
    }

    /// Opens a typed leaf as a deterministic cross-root deep link.
    ///
    /// Unlike `navigate`, this replaces any stale path owned by the target
    /// root. A Home health card therefore always lands on exactly one useful
    /// screen, and Back returns to Track rather than walking through whatever
    /// the person last viewed there.
    @discardableResult
    public func navigateReplacingPath(
        _ route: AppRoute,
        in destination: Destination
    ) -> _Concurrency.Task<Void, Never> {
        openLeaf(route, in: destination)
        return Task { @MainActor in }
    }

    public func handle(notificationRoute: NotificationRoute) {
        switch notificationRoute {
        case .homeToday(let taskID):
            if let taskID { push(.taskDetail(taskID), in: .home) }
            else { select(.home) }
        case .taskDetail(let taskID):
            push(.taskDetail(taskID), in: .home)
        case .weeklyPlanner:
            push(.weeklyPlanner, in: .plan)
        case .weeklyReview:
            push(.weeklyReview, in: .plan)
        case .homeDone:
            // The nightly "Close the day" action closes the day it was sent
            // about, not the Insights tab.
            push(.dayClose(Date()), in: .home)
        case .dayCompass(let flow, let dateStamp):
            // The stamp was already parsed off the payload and then discarded,
            // so a notification tapped after midnight opened whatever "today"
            // had become. Resolving it means the 21:00 nudge still closes the
            // day it was written about.
            let day = Self.notificationDate(from: dateStamp)
            switch flow {
            case .morningPlan:
                push(.dayOpen(day), in: .home)
            case .rescue:
                // The deck Home's and Plan's Rescue rows open, not the backlog.
                select(.home)
                overdueRescueRequest = day
            case .replan, .inbox:
                push(.backlog, in: .plan)
            case .eveningReview:
                // Was `.insights`, which meant the evening notification and the
                // Home row led to two different places for the same ritual.
                push(.dayClose(day), in: .home)
            case .resumeTask:
                select(.home)
            }
        case .dailySummary(let kind, let dateStamp):
            let day = Self.notificationDate(from: dateStamp)
            switch kind {
            case .morning:
                select(.home)
            case .nightly:
                push(.dayClose(day), in: .home)
            }
        }
    }
}
