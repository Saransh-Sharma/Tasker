import Foundation
import Observation

public enum RoutineCollectionFocus: Codable, Hashable, Sendable {
    case daypart(ResolvedDaypart)
    case library
}

public enum LifeMomentsFocus: Codable, Hashable, Sendable {
    case overview
    case moment(UUID)
    case add
}

public enum AppRoute: Codable, Hashable, Sendable {
    case taskDetail(UUID)
    case habitBoard
    case habitLibrary
    case habitDetail(UUID)
    case trackerDetail(UUID)
    case careLibrary
    case health
    case project(UUID)
    case routines(RoutineCollectionFocus)
    case routine(UUID)
    case goals
    case goal(UUID)
    case lifeMoments(LifeMomentsFocus)
    case journalDay(UUID)
    case journalSearch
    case weeklyReflection(Date)
    case notesLibrary(NotesLibraryDestination)
    case note(UUID)
    case knowledgeFolder(UUID)
    case planDay
    case planWeek
    case backlog
    case focusSession(UUID?)
    /// The end-of-day ritual for a given day. Carries the day rather than
    /// defaulting to "now" so a notification tapped after midnight still closes
    /// the day it was written about.
    case dayClose(Date)
    /// The morning counterpart: what carried, and what tomorrow's first thing
    /// turned out to be. Read-only.
    case dayOpen(Date)
    case weeklyPlanner
    /// "This week" — the day-placement workspace.
    ///
    /// Additive rather than a replacement for `weeklyPlanner`: restoration
    /// paths, deep links and notification routes persisted before this case
    /// existed still decode, and still open the wizard until they are migrated.
    case weeklyPlanningWorkspace(WeeklyPlanningEntry)
    case weeklyReview
    // `planningReview` rendered exactly the same weekly-review route as
    // `weeklyReview` and was never pushed from anywhere. `weeklyReview` now
    // pops the destination it was actually opened from, which is the only
    // behaviour the second case ever added.
    case trackHistory
    case wellness(WellnessHomeCardFocus)
    case nutrition(NutritionHomeCardFocus)
    case fasting
    case insightEvidence(UUID?)
    case healthInsight(HealthInsightDomain)
    case settings
    case settingsDetail(SettingsDetailRoute)
    case tokenGallery
    case referenceDashboard

    public var spatialTransitionID: String? {
        switch self {
        case .taskDetail(let id):
            "route.task.\(id.uuidString)"
        case .habitDetail(let id):
            "route.habit.\(id.uuidString)"
        case .project(let id):
            "route.project.\(id.uuidString)"
        case .journalDay(let id):
            "route.journal.\(id.uuidString)"
        case .note(let id):
            "route.note.\(id.uuidString)"
        case .settingsDetail(let route):
            route.transitionID
        case .weeklyPlanner:
            "route.weekly.week"
        case .weeklyPlanningWorkspace(let entry):
            "route.weekly.\(entry.rawValue)"
        default:
            nil
        }
    }

    /// The workspace entry this route opens, if any.
    ///
    /// `weeklyPlanner` — the retired four-step wizard's route — resolves to the
    /// ordinary week entry so persisted navigation state, `lifeboard://weekly`
    /// deep links and notification payloads written before the workspace existed
    /// restore into the surface that replaced it rather than a dead end.
    public var weeklyPlanningEntry: WeeklyPlanningEntry? {
        switch self {
        case .weeklyPlanner: .week
        case .weeklyPlanningWorkspace(let entry): entry
        default: nil
        }
    }

    public var screenMode: ScreenMode {
        switch self {
        case .settings, .settingsDetail, .tokenGallery, .referenceDashboard:
            .utility
        case .taskDetail, .note, .journalDay:
            .editor
        case .weeklyPlanningWorkspace, .weeklyPlanner:
            // The workspace owns a persistent composer of its own. Without
            // this the global capture field floats over the source tray, and
            // the surface has two competing text targets and two "+" buttons
            // meaning different things.
            .editor
        case .focusSession, .dayClose, .dayOpen:
            // A ritual, like a focus session: the shell drops its star field and
            // celestial tide so the surface can hold attention on its own.
            .focused
        default:
            .detail
        }
    }
}

public struct AppAlertState: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String

    public init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }
}

public struct CaptureRequest: Identifiable, Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        case shell
        case widget
        case appIntent
        case spotlight
        case shareExtension
        case deepLink
    }

    public let id: UUID
    public let kind: CaptureKind
    public let source: Source
    public let draftID: UUID?
    public let presentationContext: CapturePresentationContext?
    /// Seed text for the editor, used when reviewing an already-captured item.
    ///
    /// Carries the *raw* capture, not the parser's rewritten title: review means
    /// the user sees exactly what they said and decides what it becomes. Decoded
    /// with `decodeIfPresent` so previously persisted requests keep restoring.
    public let prefilledText: String?
    /// Structured capture metadata including proposals from universal input.
    public let captureSeed: CaptureSeed?

    public init(
        id: UUID = UUID(),
        kind: CaptureKind,
        source: Source,
        draftID: UUID? = nil,
        presentationContext: CapturePresentationContext? = nil,
        prefilledText: String? = nil,
        captureSeed: CaptureSeed? = nil
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.draftID = draftID
        self.presentationContext = presentationContext
        self.prefilledText = prefilledText
        self.captureSeed = captureSeed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(CaptureKind.self, forKey: .kind)
        source = try container.decode(Source.self, forKey: .source)
        draftID = try container.decodeIfPresent(UUID.self, forKey: .draftID)
        presentationContext = try container.decodeIfPresent(
            CapturePresentationContext.self,
            forKey: .presentationContext
        )
        prefilledText = try container.decodeIfPresent(String.self, forKey: .prefilledText)
        captureSeed = try container.decodeIfPresent(CaptureSeed.self, forKey: .captureSeed)
    }
}

@MainActor
@Observable
public final class CaptureRouter {
    public private(set) var activeRequest: CaptureRequest?
    public private(set) var pendingRequests: [CaptureRequest] = []
    public private(set) var recoverableDraftID: UUID?

    @ObservationIgnored var onStateChange: (@MainActor () -> Void)?

    public init() {}

    @discardableResult
    public func request(_ request: CaptureRequest) -> Bool {
        if activeRequest.map({ isSameLogicalRequest($0, request) }) == true
            || pendingRequests.contains(where: { isSameLogicalRequest($0, request) }) {
            return false
        }
        if activeRequest == nil {
            activeRequest = request
        } else {
            pendingRequests.append(request)
        }
        refreshRecoverableDraftID()
        onStateChange?()
        return true
    }

    public func request(
        kind: CaptureKind,
        source: CaptureRequest.Source,
        draftID: UUID? = nil,
        presentationContext: CapturePresentationContext? = nil
    ) {
        _ = request(CaptureRequest(
            kind: kind,
            source: source,
            draftID: draftID,
            presentationContext: presentationContext
        ))
    }

    /// Universal-input convenience: requests a capture while passing
    /// through the prefilled raw text and the structured `CaptureSeed`
    /// (parsed task proposals + input source) so editors can prefill
    /// and present correctable chips. The convenience keeps existing
    /// callers source-compatible.
    public func request(
        kind: CaptureKind,
        source: CaptureRequest.Source,
        prefilledText: String? = nil,
        captureSeed: CaptureSeed? = nil,
        draftID: UUID? = nil,
        presentationContext: CapturePresentationContext? = nil
    ) {
        _ = request(CaptureRequest(
            kind: kind,
            source: source,
            draftID: draftID,
            presentationContext: presentationContext,
            prefilledText: prefilledText,
            captureSeed: captureSeed
        ))
    }

    public func completeActiveRequest() {
        activeRequest = pendingRequests.isEmpty ? nil : pendingRequests.removeFirst()
        refreshRecoverableDraftID()
        onStateChange?()
    }

    public func cancelActiveRequest() {
        completeActiveRequest()
    }

    public func restoreRecoverableDraftID(_ draftID: UUID?) {
        recoverableDraftID = draftID
    }

    private func isSameLogicalRequest(_ lhs: CaptureRequest, _ rhs: CaptureRequest) -> Bool {
        lhs.kind == rhs.kind && lhs.draftID == rhs.draftID
    }

    private func refreshRecoverableDraftID() {
        recoverableDraftID = activeRequest?.draftID
            ?? pendingRequests.lazy.compactMap(\.draftID).first
    }
}

public struct RestorationState: Codable, Equatable, Sendable {
    public var selectedDestination: Destination
    public var paths: [Destination: [AppRoute]]
    public var dashboardMode: DashboardMode
    public var daypartSelection: DaypartSelection
    public var recoverableCaptureDraftID: UUID?

    public init(
        selectedDestination: Destination = .home,
        paths: [Destination: [AppRoute]] = [:],
        dashboardMode: DashboardMode = .smart,
        daypartSelection: DaypartSelection = .automatic,
        recoverableCaptureDraftID: UUID? = nil
    ) {
        self.selectedDestination = selectedDestination
        self.paths = paths
        self.dashboardMode = dashboardMode
        self.daypartSelection = daypartSelection
        self.recoverableCaptureDraftID = recoverableCaptureDraftID
    }
}

public struct DeferredProtectedRoute: Equatable, Sendable {
    public let route: AppRoute
    public let destination: Destination

    public init(route: AppRoute, destination: Destination) {
        self.route = route
        self.destination = destination
    }
}

public struct PendingRouteRequest: Equatable, Sendable {
    public let id: UUID
    public let destination: Destination
    public let route: AppRoute

    public init(id: UUID = UUID(), destination: Destination, route: AppRoute) {
        (self.id, self.destination, self.route) = (id, destination, route)
    }
}

@MainActor
@Observable
public final class AppRouter {
    public var selectedDestination: Destination {
        didSet {
            guard oldValue != selectedDestination else {
                persist()
                return
            }
            if selectedDestination == .eva {
                // Begin before observation-driven SwiftUI work runs so this
                // includes destination metadata construction and first mount.
                EvaNavigationPerformanceTrace.begin()
            } else if oldValue == .eva {
                EvaNavigationPerformanceTrace.cancel()
            }
            persist()
        }
    }
    public var paths: [Destination: [AppRoute]] {
        didSet { persist() }
    }
    public var dashboardMode: DashboardMode {
        didSet { persist() }
    }
    public var activeAlert: AppAlertState?
    public private(set) var deferredProtectedRoute: DeferredProtectedRoute?
    public private(set) var pendingRouteRequest: PendingRouteRequest?
    public private(set) var isJournalAccessUnlocked: Bool

    public let captureRouter: CaptureRouter

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var isRestoring = true
    @ObservationIgnored private weak var preferences: PresentationPreferences?
    @ObservationIgnored private var mountedDestinations: Set<Destination> = []

    public init(
        defaults: UserDefaults? = nil,
        preferences: PresentationPreferences? = nil,
        captureRouter: CaptureRouter = CaptureRouter()
    ) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.suiteName)
            ?? .standard
        self.preferences = preferences
        self.captureRouter = captureRouter
        selectedDestination = .home
        paths = [:]
        dashboardMode = .smart
        deferredProtectedRoute = nil
        pendingRouteRequest = nil
        isJournalAccessUnlocked = false
        restore()
        // Debug/snapshot affordance: force the initial root so screenshot
        // fixtures can target any tab without simulating navigation.
        #if DEBUG
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-LIFEBOARD_INITIAL_DESTINATION=") }),
           let raw = arg.split(separator: "=").last.map(String.init),
           let destination = Destination(rawValue: raw) {
            selectedDestination = destination
        }
        #endif
        isRestoring = false
        if journalAuthenticationIsRequired {
            sanitizeProtectedJournalRoutesForLockedSession()
            persist()
        } else {
            isJournalAccessUnlocked = true
        }
        captureRouter.onStateChange = { [weak self] in
            self?.persist()
        }
    }

    public func select(_ destination: Destination) {
        selectedDestination = destination
    }

    /// Activates a primary destination using platform tab/sidebar semantics.
    /// Switching destinations preserves each navigation stack; selecting the
    /// already-active destination again returns that stack to its root.
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

    public func acknowledgeRouteAppearance(_ route: AppRoute, in destination: Destination) {
        guard let pendingRouteRequest,
              pendingRouteRequest.destination == destination,
              pendingRouteRequest.route == route else { return }
        self.pendingRouteRequest = nil
    }

    public func navigationRootDidMount(_ destination: Destination) {
        mountedDestinations.insert(destination)
    }

    public func push(_ route: AppRoute, in destination: Destination? = nil) {
        let target = destination ?? selectedDestination
        if route.requiresJournalUnlock,
           journalAuthenticationIsRequired,
           isJournalAccessUnlocked == false {
            openProtectedJournalRoute(route, in: target)
            return
        }
        append(route, in: target)
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

    public func openLeaf(_ route: AppRoute, in destination: Destination) {
        if paths[destination] == [route], mountedDestinations.contains(destination) {
            pendingRouteRequest = nil
            selectedDestination = destination
            return
        }
        if pendingRouteRequest?.destination == destination,
           pendingRouteRequest?.route == route {
            selectedDestination = destination
            return
        }
        pendingRouteRequest = PendingRouteRequest(destination: destination, route: route)
        selectedDestination = destination
        paths[destination] = [route]
    }

    private func append(_ route: AppRoute, in target: Destination) {
        var path = paths[target] ?? []
        guard path.last != route else { return }
        path.append(route)
        // Switch the visible root before mutating its stack. SwiftUI's TabView
        // can otherwise write its still-active selection back during the path
        // update and strand the new leaf behind an inactive destination.
        selectedDestination = target
        paths[target] = path
    }

    /// Opens a Journal route without ever placing its sensitive identifier in a
    /// visible or persisted navigation path before the current app session unlocks.
    public func openProtectedJournalRoute(
        _ route: AppRoute,
        in destination: Destination = .track
    ) {
        guard route.requiresJournalUnlock else {
            append(route, in: destination)
            return
        }
        guard journalAuthenticationIsRequired, isJournalAccessUnlocked == false else {
            append(route, in: destination)
            return
        }

        deferredProtectedRoute = DeferredProtectedRoute(route: route, destination: destination)
        var path = paths[destination] ?? []
        if path.last != .journalSearch { path.append(.journalSearch) }
        paths[destination] = path
        selectedDestination = destination
    }

    /// Resumes the most recent protected route only after successful device authentication.
    public func journalDidUnlock() {
        isJournalAccessUnlocked = true
        guard let deferredProtectedRoute else { return }
        var path = paths[deferredProtectedRoute.destination] ?? []
        if path.last == .journalSearch { path.removeLast() }
        if path.last != deferredProtectedRoute.route { path.append(deferredProtectedRoute.route) }
        paths[deferredProtectedRoute.destination] = path
        selectedDestination = deferredProtectedRoute.destination
        self.deferredProtectedRoute = nil
    }

    /// Removes protected routes from both the visible and restorable navigation state.
    public func journalDidLock() {
        guard journalAuthenticationIsRequired else {
            isJournalAccessUnlocked = true
            deferredProtectedRoute = nil
            return
        }
        isJournalAccessUnlocked = false
        sanitizeProtectedJournalRoutesForLockedSession()
        persist()
    }

    public func popToRoot(in destination: Destination? = nil) {
        let target = destination ?? selectedDestination
        if pendingRouteRequest?.destination == target { pendingRouteRequest = nil }
        paths[target] = []
    }

    public func pop(in destination: Destination? = nil) {
        let target = destination ?? selectedDestination
        if pendingRouteRequest?.destination == target { pendingRouteRequest = nil }
        guard var path = paths[target], path.isEmpty == false else { return }
        path.removeLast()
        paths[target] = path
    }

    public func restoreFallbackToHome(message: String? = nil) {
        pendingRouteRequest = nil
        selectedDestination = .home
        paths = [:]
        if let message {
            activeAlert = AppAlertState(title: "Opened Home", message: message)
        }
    }

    public func handle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["lifeboard", "tasker"].contains(scheme),
              let host = url.host?.lowercased() else {
            return false
        }
        let segments = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "home":
            select(.home)
        case "calendar", "weekly":
            select(.plan)
            if host == "weekly", segments.first?.lowercased() == "review" {
                push(.weeklyReview, in: .plan)
            } else if host == "weekly" {
                push(.weeklyPlanner, in: .plan)
            } else if segments.first?.lowercased() == "day" {
                push(.planDay, in: .plan)
            } else if host == "calendar", [nil, "schedule"].contains(segments.first?.lowercased()) {
                push(.planDay, in: .plan)
            }
        case "day", "planday":
            select(.plan)
            push(.planDay, in: .plan)
        case "week", "planweek":
            select(.plan)
            push(.planWeek, in: .plan)
        case "backlog":
            select(.plan)
            push(.backlog, in: .plan)
        case "focus":
            let sessionID = segments.first.flatMap(UUID.init(uuidString:))
            push(.focusSession(sessionID), in: .plan)
        case "habits":
            switch segments.first?.lowercased() {
            case nil, "board":
                push(.habitBoard, in: .track)
            case "library", "manage":
                push(.habitLibrary, in: .track)
            case "habit":
                guard segments.count > 1, let id = UUID(uuidString: segments[1]) else {
                    restoreFallbackToHome(message: "That habit link is incomplete or no longer available.")
                    return true
                }
                push(.habitDetail(id), in: .track)
            default:
                restoreFallbackToHome(message: "That habit destination is unavailable. Opened Home instead.")
            }
        case "habit":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                restoreFallbackToHome(message: "That habit link is incomplete or no longer available.")
                return true
            }
            push(.habitDetail(id), in: .track)
        case "insights":
            select(.insights)
        case "chat", "eva":
            select(.eva)
        case "journal":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                push(.journalSearch, in: .track)
                return true
            }
            openProtectedJournalRoute(.journalDay(id), in: .track)
        case "reflection":
            let weekStart = url.queryValue(named: "weekStart")
                .flatMap(Self.deepLinkDateFormatter.date(from:))
                ?? Date()
            openProtectedJournalRoute(.weeklyReflection(weekStart), in: .track)
        case "tracker":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                push(.careLibrary, in: .track)
                return true
            }
            push(.trackerDetail(id), in: .track)
        case "care":
            push(.careLibrary, in: .track)
        case "wellness":
            let focus: WellnessHomeCardFocus?
            switch segments.first?.lowercased() {
            case "body", "body-metric", "bodymetric":
                if let rawMetric = url.queryValue(named: "metric") {
                    focus = BodyMetricKind(rawValue: rawMetric).map(WellnessHomeCardFocus.bodyMetric)
                } else {
                    focus = .bodyMetric(.bodyMass)
                }
            case "workout", "workouts":
                focus = .workouts
            case "sleep":
                focus = .sleep
            case "movement":
                focus = .movement
            default:
                focus = nil
            }
            guard let focus else {
                restoreFallbackToHome(message: "That wellness destination is unavailable. Opened Home instead.")
                return true
            }
            openLeaf(.wellness(focus), in: .track)
        case "nutrition":
            let focus: NutritionHomeCardFocus?
            switch segments.first?.lowercased() {
            case nil, "summary": focus = .dailySummary
            case "log", "log-meal", "logmeal": focus = .logMeal
            case "recent", "recent-meal", "recentmeal": focus = .recentMeal
            default: focus = nil
            }
            guard let focus else {
                restoreFallbackToHome(message: "That nutrition destination is unavailable. Opened Home instead.")
                return true
            }
            openLeaf(.nutrition(focus), in: .track)
        case "fasting":
            openLeaf(.fasting, in: .track)
        case "note":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                select(.track)
                captureRouter.request(
                    kind: .note,
                    source: .deepLink,
                    draftID: UUID()
                )
                return true
            }
            push(.note(id), in: .track)
        case "notes":
            let collection = url.queryValue(named: "collection")
                .flatMap(KnowledgeNoteCollection.init(rawValue:))
                ?? .all
            let folderID = url.queryValue(named: "folder").flatMap(UUID.init(uuidString:))
            let tagID = url.queryValue(named: "tag").flatMap(UUID.init(uuidString:))
            let searchText = url.queryValue(named: "search") ?? ""
            let sort = url.queryValue(named: "sort")
                .flatMap(KnowledgeNoteSort.init(rawValue:))
                ?? .updatedDescending
            push(
                .notesLibrary(.library(.init(
                    collection: collection,
                    folderID: folderID,
                    tagIDs: tagID.map { [$0] } ?? [],
                    searchText: searchText,
                    sort: sort
                ))),
                in: .track
            )
        case "project":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                select(.plan)
                return true
            }
            push(.project(id), in: .plan)
        case "routines":
            let focus = url.queryValue(named: "daypart")
                .flatMap(ResolvedDaypart.init(rawValue:))
                .map(RoutineCollectionFocus.daypart)
                ?? .library
            openLeaf(.routines(focus), in: .track)
        case "routine":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                openLeaf(.routines(.library), in: .track)
                return true
            }
            openLeaf(.routine(id), in: .track)
        case "goals":
            openLeaf(.goals, in: .track)
        case "goal":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                openLeaf(.goals, in: .track)
                return true
            }
            openLeaf(.goal(id), in: .track)
        case "moments":
            let focus: LifeMomentsFocus = segments.first?.lowercased() == "add" ? .add : .overview
            openLeaf(.lifeMoments(focus), in: .track)
        case "moment":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                openLeaf(.lifeMoments(.overview), in: .track)
                return true
            }
            openLeaf(.lifeMoments(.moment(id)), in: .track)
        case "settings":
            push(.settings, in: selectedDestination)
        case "quickadd":
            captureRouter.request(kind: .task, source: .deepLink)
        case "task":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                restoreFallbackToHome(message: "That task link is incomplete or no longer available.")
                return true
            }
            push(.taskDetail(id), in: .home)
        case "tasks":
            switch segments.first?.lowercased() {
            case nil, "today":
                select(.home)
            case "upcoming":
                push(.planDay, in: .plan)
            case "overdue":
                push(.backlog, in: .plan)
            case "project":
                guard segments.count > 1, let id = UUID(uuidString: segments[1]) else {
                    restoreFallbackToHome(message: "That project link is incomplete or no longer available.")
                    return true
                }
                push(.project(id), in: .plan)
            default:
                restoreFallbackToHome(message: "That task destination is unavailable. Opened Home instead.")
            }
        default:
            return false
        }
        return true
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
            select(.insights)
        case .dayCompass(let flow, let dateStamp):
            // The stamp was already parsed off the payload and then discarded,
            // so a notification tapped after midnight opened whatever "today"
            // had become. Resolving it means the 21:00 nudge still closes the
            // day it was written about.
            let day = Self.notificationDate(from: dateStamp)
            switch flow {
            case .morningPlan:
                push(.dayOpen(day), in: .home)
            case .replan, .rescue, .inbox:
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

    /// Resolves a `yyyyMMdd` notification stamp to a date, falling back to now.
    ///
    /// Parsed at local midnight so `PlanningDay(date:)` lands on the intended
    /// calendar day rather than drifting across a time-zone boundary.
    /// `nonisolated` because it is pure date parsing over its argument and
    /// touches no router state — callers should not need the main actor to
    /// resolve a stamp.
    nonisolated static func notificationDate(from stamp: String?) -> Date {
        guard let stamp, stamp.isEmpty == false else { return Date() }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: stamp) ?? Date()
    }

    public func restorationSnapshot() -> RestorationState {
        RestorationState(
            selectedDestination: selectedDestination,
            paths: paths,
            dashboardMode: dashboardMode,
            daypartSelection: preferences?.daypartSelection ?? .automatic,
            recoverableCaptureDraftID: captureRouter.recoverableDraftID
        )
    }

    public func persist() {
        guard isRestoring == false, let data = try? encoder.encode(restorationSnapshot()) else { return }
        defaults.set(data, forKey: FoundationPreferenceKey.restorationState)
    }

    private func restore() {
        guard let data = defaults.data(forKey: FoundationPreferenceKey.restorationState),
              let state = try? decoder.decode(RestorationState.self, from: data),
              Destination.allCases.contains(state.selectedDestination) else {
            return
        }
        selectedDestination = state.selectedDestination
        paths = state.paths
        dashboardMode = state.dashboardMode
        preferences?.daypartSelection = state.daypartSelection
        captureRouter.restoreRecoverableDraftID(state.recoverableCaptureDraftID)
    }

    private var journalAuthenticationIsRequired: Bool {
        JournalPrivacyPolicyPersistence.load(from: defaults).requiresAuthentication
    }

    private func sanitizeProtectedJournalRoutesForLockedSession() {
        for destination in Destination.allCases {
            guard let path = paths[destination],
                  let protectedIndex = path.firstIndex(where: \.requiresJournalUnlock) else { continue }
            if deferredProtectedRoute == nil,
               let protectedRoute = path.last(where: \.requiresJournalUnlock) {
                deferredProtectedRoute = DeferredProtectedRoute(
                    route: protectedRoute,
                    destination: destination
                )
            }
            var safePath = Array(path[..<protectedIndex])
            if safePath.last != .journalSearch { safePath.append(.journalSearch) }
            paths[destination] = safePath
        }
    }

    private static let deepLinkDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension AppRoute {
    var requiresJournalUnlock: Bool {
        switch self {
        case .journalDay, .weeklyReflection:
            true
        default:
            false
        }
    }
}

private extension URL {
    func queryValue(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

public enum SpotlightRouteTranslator {
    public static let journalPrefix = "lifeboard-journal-"

    public static func url(for searchableItemIdentifier: String) -> URL? {
        guard searchableItemIdentifier.hasPrefix(journalPrefix) else { return nil }
        let rawID = String(searchableItemIdentifier.dropFirst(journalPrefix.count))
        guard let id = UUID(uuidString: rawID) else { return nil }
        return URL(string: "lifeboard://journal/\(id.uuidString)")
    }
}

@MainActor
public final class FoundationCoordinator {
    public static let shared = FoundationCoordinator()

    public let preferences: PresentationPreferences
    public let captureRouter: CaptureRouter
    public let router: AppRouter

    private init() {
        let preferences = PresentationPreferences()
        let captureRouter = CaptureRouter()
        self.preferences = preferences
        self.captureRouter = captureRouter
        router = AppRouter(preferences: preferences, captureRouter: captureRouter)
        // Store creation and recovery run at utility priority. Starting here
        // lets the Foundation shell reach its first frame without making the
        // first Eva tap perform synchronous disk work.
        LLMStoreBootstrap.shared.start()
    }

    @discardableResult
    public func handle(url: URL) -> Bool {
        router.handle(url: url)
    }
}
