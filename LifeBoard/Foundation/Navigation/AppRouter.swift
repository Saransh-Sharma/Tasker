import Foundation
import LifeBoardDomain
import Observation

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
    /// A month of ended sessions: grid, totals, top tasks. Reached from the
    /// settled session's receipt and the "session ended" state.
    case focusHistory
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
        case .weeklyReview:
            // The ritual brings its own footer actions. As a pushed detail the
            // shell's composer and dock covered them, and the violet commit
            // button smeared through the dock glass.
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

    /// A readable width that replaces the mode's default, for routes that lay
    /// out their own columns.
    ///
    /// The mode caps (680 for editor and utility routes) are right for a form
    /// and wrong for a multi-pane surface: the Weekly workspace's side-by-side
    /// tray and wide board, Settings' sidebar and detail, and the Notes split
    /// would all be squeezed into 680 points. `.infinity` means uncapped.
    public var readableWidthOverride: CGFloat? {
        switch self {
        case .weeklyPlanningWorkspace, .weeklyPlanner, .settings, .settingsDetail:
            .infinity
        case .note:
            1080
        default:
            nil
        }
    }
}

/// The single translation boundary from durable domain references to UI routes.
/// Cloud output and persisted cards never carry `AppRoute` values directly.
public enum RecordRouteResolver {
    public static func resolve(_ reference: EvaRecordReference) -> ResolvedRecordRoute {
        let id = reference.recordID
        switch reference.kind {
        case .task:
            return .init(destination: .home, route: .taskDetail(id), requiresProtectedJournalOpen: false)
        case .project:
            return .init(destination: .plan, route: .project(id), requiresProtectedJournalOpen: false)
        case .habit:
            return .init(destination: .track, route: .habitDetail(id), requiresProtectedJournalOpen: false)
        case .tracker:
            return .init(destination: .track, route: .trackerDetail(id), requiresProtectedJournalOpen: false)
        case .routine:
            return .init(destination: .track, route: .routine(id), requiresProtectedJournalOpen: false)
        case .goal:
            return .init(destination: .track, route: .goal(id), requiresProtectedJournalOpen: false)
        case .journal:
            return .init(destination: .track, route: .journalDay(id), requiresProtectedJournalOpen: true)
        case .note:
            return .init(destination: .track, route: .note(id), requiresProtectedJournalOpen: false)
        case .knowledgeFolder:
            return .init(destination: .track, route: .notesLibrary(.folder(id)), requiresProtectedJournalOpen: false)
        case .focusSession:
            return .init(destination: .plan, route: .focusSession(id), requiresProtectedJournalOpen: false)
        case .lifeMoment:
            return .init(destination: .track, route: .lifeMoments(.moment(id)), requiresProtectedJournalOpen: false)
        case .bodyMetric:
            return .init(destination: .track, route: .wellness(.bodyMetric(.bodyMass)), requiresProtectedJournalOpen: false)
        case .hydration, .mood, .sleep, .medication:
            return .init(destination: .track, route: .trackHistory, requiresProtectedJournalOpen: false)
        case .insight:
            return .init(destination: .insights, route: .insightEvidence(id), requiresProtectedJournalOpen: false)
        }
    }

    @MainActor
    public static func open(_ reference: EvaRecordReference, with router: AppRouter) {
        let resolved = resolve(reference)
        if resolved.requiresProtectedJournalOpen {
            router.openProtectedJournalRoute(resolved.route, in: resolved.destination)
        } else {
            router.openLeaf(resolved.route, in: resolved.destination)
        }
    }

    public static func reference(for evidence: EvidenceReference) -> EvaRecordReference? {
        let kind: RecordKind
        switch evidence.kind.lowercased() {
        case "task", "plan": kind = .task
        case "habit": kind = .habit
        case "tracker", "care": kind = .tracker
        case "routine": kind = .routine
        case "goal": kind = .goal
        case "journal": kind = .journal
        case "focus": kind = .focusSession
        case "hydration": kind = .hydration
        case "mood": kind = .mood
        case "sleep": kind = .sleep
        case "medication": kind = .medication
        default: return nil
        }
        return EvaRecordReference(
            kind: kind,
            recordID: evidence.routeID ?? evidence.sourceID,
            title: evidence.display
        )
    }
}

@MainActor
@Observable
public final class AppRouter {
    /// The one receipt the shell shows above the composer. See `ShellReceipt`.
    public var shellReceipt: ShellReceipt?

    public var selectedDestination: Destination {
        willSet {
            guard newValue != selectedDestination, !isRestoring else { return }
            selectionGeneration &+= 1
            RootNavigationPerformanceTrace.begin(
                destination: newValue,
                coldMount: !interactiveDestinations.contains(newValue),
                generation: selectionGeneration
            )
        }
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
    /// Eva presented over the current root. Set by `presentEva`, cleared by the sheet.
    var evaSheetRequest: EvaSheetRequest?
    /// Asks the shell to open the Overdue Rescue deck — the same one Plan's
    /// and Home's Rescue rows open. Set by a rescue notification; the shell
    /// presents the deck and clears it.
    public var overdueRescueRequest: Date?
    public private(set) var deferredProtectedRoute: DeferredProtectedRoute?
    public private(set) var pendingRouteRequest: PendingRouteRequest?
    public private(set) var isJournalAccessUnlocked: Bool

    public let captureRouter: CaptureRouter

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let restorationWriter: RestorationWriter
    @ObservationIgnored private var restorationSequence: UInt64 = 0
    @ObservationIgnored private var restorationHandoff: Task<Void, Never>?
    public private(set) var selectionGeneration: UInt64 = 0
    public private(set) var interactiveSelectionGeneration: UInt64?
    @ObservationIgnored private var interactiveDestinations: Set<Destination> = []
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var isRestoring = true
    @ObservationIgnored private weak var preferences: PresentationPreferences?
    @ObservationIgnored private var mountedDestinations: Set<Destination> = []

    public init(
        defaults: UserDefaults? = nil,
        preferences: PresentationPreferences? = nil,
        captureRouter: CaptureRouter = CaptureRouter()
    ) {
        let resolvedDefaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.suiteName)
            ?? .standard
        self.defaults = resolvedDefaults
        restorationWriter = RestorationWriter(
            defaults: .init(value: resolvedDefaults)
        )
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

    public func acknowledgeRouteAppearance(_ route: AppRoute, in destination: Destination) {
        guard let pendingRouteRequest,
              pendingRouteRequest.destination == destination,
              pendingRouteRequest.route == route else { return }
        self.pendingRouteRequest = nil
    }

    public func navigationRootDidMount(_ destination: Destination) {
        mountedDestinations.insert(destination)
    }

    public func navigationRootDidBecomeInteractive(_ destination: Destination, generation: UInt64? = nil) {
        let generation = generation ?? selectionGeneration
        guard destination == selectedDestination, generation == selectionGeneration else { return }
        mountedDestinations.insert(destination)
        interactiveDestinations.insert(destination)
        if interactiveSelectionGeneration != generation { interactiveSelectionGeneration = generation }
        RootNavigationPerformanceTrace.markInteractive(destination: destination, generation: generation)
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
            // `lifeboard://focus/start?preset=<id>` is Control Center's way in:
            // the widget target cannot reach the handoff store, so the link
            // becomes the same pending action Siri submits and the Home
            // adapter starts the session from the person's preset.
            if segments.first?.lowercased() == "start" {
                let presetID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "preset" })?.value
                try? PendingShortcutLaunchActionStore.shared.submit(
                    PendingShortcutLaunchAction(kind: .startFocus, presetID: presetID)
                )
                select(.home)
                NotificationCenter.default.post(name: .lifeboardPendingShortcutHandoff, object: nil)
                return true
            }
            let sessionID = segments.first.flatMap(UUID.init(uuidString:))
            select(.plan)
            push(.focusSession(sessionID), in: .plan)
        case "habits":
            switch segments.first?.lowercased() {
            case nil, "board":
                push(.habitBoard, in: .track)
            case "library", "manage":
                push(.habitLibrary, in: .track)
            case "habit":
                guard segments.count > 1, let id = UUID(uuidString: segments[1]) else {
                    restoreFallbackToHome(message: String(localized: "Couldn’t open that habit."))
                    return true
                }
                RecordRouteResolver.open(.init(kind: .habit, recordID: id, title: "Habit"), with: self)
            case let segment? where UUID(uuidString: segment) != nil:
                // Widgets built before the `habits/habit/<id>` form sent a
                // bare id; installed widgets keep that URL until they refresh.
                RecordRouteResolver.open(.init(kind: .habit, recordID: UUID(uuidString: segment)!, title: "Habit"), with: self)
            default:
                restoreFallbackToHome(message: String(localized: "Couldn’t open that habit."))
            }
        case "habit":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                restoreFallbackToHome(message: String(localized: "Couldn’t open that habit."))
                return true
            }
            RecordRouteResolver.open(.init(kind: .habit, recordID: id, title: "Habit"), with: self)
        case "insights":
            select(.insights)
        case "chat", "eva":
            select(.eva)
        case "journal":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                push(.journalSearch, in: .track)
                return true
            }
            RecordRouteResolver.open(.init(kind: .journal, recordID: id, title: "Journal entry"), with: self)
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
            RecordRouteResolver.open(.init(kind: .tracker, recordID: id, title: "Tracker"), with: self)
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
                restoreFallbackToHome(message: String(localized: "Couldn’t open that page."))
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
                restoreFallbackToHome(message: String(localized: "Couldn’t open that page."))
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
            RecordRouteResolver.open(.init(kind: .note, recordID: id, title: "Note"), with: self)
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
            RecordRouteResolver.open(.init(kind: .project, recordID: id, title: "Project"), with: self)
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
            RecordRouteResolver.open(.init(kind: .routine, recordID: id, title: "Routine"), with: self)
        case "goals":
            openLeaf(.goals, in: .track)
        case "goal":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                openLeaf(.goals, in: .track)
                return true
            }
            RecordRouteResolver.open(.init(kind: .goal, recordID: id, title: "Goal"), with: self)
        case "moments":
            let focus: LifeMomentsFocus = segments.first?.lowercased() == "add" ? .add : .overview
            openLeaf(.lifeMoments(focus), in: .track)
        case "moment":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                openLeaf(.lifeMoments(.overview), in: .track)
                return true
            }
            RecordRouteResolver.open(.init(kind: .lifeMoment, recordID: id, title: "Life moment"), with: self)
        case "settings":
            push(.settings, in: selectedDestination)
        case "quickadd":
            captureRouter.request(kind: .task, source: .deepLink)
        case "task":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                restoreFallbackToHome(message: String(localized: "Couldn’t open that task."))
                return true
            }
            RecordRouteResolver.open(.init(kind: .task, recordID: id, title: "Task"), with: self)
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
                    restoreFallbackToHome(message: String(localized: "Couldn’t open that project."))
                    return true
                }
                push(.project(id), in: .plan)
            default:
                restoreFallbackToHome(message: String(localized: "Couldn’t open that task."))
            }
        default:
            return false
        }
        return true
    }
}

extension AppRouter {
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
        guard isRestoring == false else { return }
        restorationSequence &+= 1
        let envelope = RestorationEnvelope(sequence: restorationSequence, state: restorationSnapshot())
        restorationHandoff?.cancel()
        restorationHandoff = Task { [restorationWriter] in
            guard !Task.isCancelled else { return }
            await restorationWriter.enqueue(envelope)
        }
    }

    public func flushPersistence() async {
        guard isRestoring == false else { return }
        restorationSequence &+= 1
        let envelope = RestorationEnvelope(sequence: restorationSequence, state: restorationSnapshot())
        restorationHandoff?.cancel()
        restorationHandoff = nil
        await restorationWriter.flush(envelope)
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

    public static func reference(for searchableItemIdentifier: String) -> EvaRecordReference? {
        guard searchableItemIdentifier.hasPrefix(journalPrefix) else { return nil }
        let rawID = String(searchableItemIdentifier.dropFirst(journalPrefix.count))
        guard let id = UUID(uuidString: rawID) else { return nil }
        return EvaRecordReference(kind: .journal, recordID: id, title: "Journal entry")
    }

    public static func url(for searchableItemIdentifier: String) -> URL? {
        guard let reference = reference(for: searchableItemIdentifier) else { return nil }
        return URL(string: "lifeboard://journal/\(reference.recordID.uuidString)")
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

    /// A coordinator for a second window (iPad Stage Manager / Split View,
    /// or another Mac window).
    ///
    /// Each window needs its own navigation — one shared router made every
    /// window follow the others' taps — and its own restoration record, so it
    /// reads and writes a suite named for its scene session. Preferences
    /// (appearance, comfort, daypart) stay shared: they are the person's, not
    /// the window's.
    public init(secondaryWindowFor sceneIdentifier: String, sharing base: FoundationCoordinator) {
        preferences = base.preferences
        let captureRouter = CaptureRouter()
        self.captureRouter = captureRouter
        router = AppRouter(
            defaults: UserDefaults(suiteName: "lifeboard.window.\(sceneIdentifier)"),
            preferences: base.preferences,
            captureRouter: captureRouter
        )
    }

    @discardableResult
    public func handle(url: URL) -> Bool {
        router.handle(url: url)
    }
}
