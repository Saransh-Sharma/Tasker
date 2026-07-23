import Foundation
import Observation

public enum AppRoute: Codable, Hashable, Sendable {
    case taskDetail(UUID)
    case habitBoard
    case habitLibrary
    case habitDetail(UUID)
    case trackerDetail(UUID)
    case careLibrary
    case project(UUID)
    case routine(UUID)
    case goal(UUID)
    case journalDay(UUID)
    case journalSearch
    case weeklyReflection(Date)
    case note(UUID)
    case knowledgeFolder(UUID)
    case planDay
    case planWeek
    case backlog
    case focusSession(UUID?)
    case weeklyPlanner
    case weeklyReview
    case settings
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
        default:
            nil
        }
    }

    public var screenMode: LifeBoardScreenMode {
        switch self {
        case .settings, .tokenGallery, .referenceDashboard:
            .utility
        case .focusSession:
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

    public init(id: UUID = UUID(), kind: CaptureKind, source: Source, draftID: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.source = source
        self.draftID = draftID
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

    public func request(kind: CaptureKind, source: CaptureRequest.Source, draftID: UUID? = nil) {
        _ = request(CaptureRequest(kind: kind, source: source, draftID: draftID))
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

public struct LifeBoardRestorationState: Codable, Equatable, Sendable {
    public var selectedDestination: LifeBoardDestination
    public var paths: [LifeBoardDestination: [AppRoute]]
    public var dashboardMode: DashboardMode
    public var daypartSelection: DaypartSelection
    public var recoverableCaptureDraftID: UUID?

    public init(
        selectedDestination: LifeBoardDestination = .home,
        paths: [LifeBoardDestination: [AppRoute]] = [:],
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
    public let destination: LifeBoardDestination

    public init(route: AppRoute, destination: LifeBoardDestination) {
        self.route = route
        self.destination = destination
    }
}

@MainActor
@Observable
public final class LifeBoardAppRouter {
    public var selectedDestination: LifeBoardDestination {
        didSet { persist() }
    }
    public var paths: [LifeBoardDestination: [AppRoute]] {
        didSet { persist() }
    }
    public var dashboardMode: DashboardMode {
        didSet { persist() }
    }
    public var activeAlert: AppAlertState?
    public private(set) var deferredProtectedRoute: DeferredProtectedRoute?
    public private(set) var isJournalAccessUnlocked: Bool

    public let captureRouter: CaptureRouter

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var isRestoring = true
    @ObservationIgnored private weak var preferences: LifeBoardPresentationPreferences?

    public init(
        defaults: UserDefaults? = nil,
        preferences: LifeBoardPresentationPreferences? = nil,
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
        isJournalAccessUnlocked = false
        restore()
        // Debug/snapshot affordance: force the initial root so screenshot
        // fixtures can target any tab without simulating navigation.
        #if DEBUG
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-LIFEBOARD_INITIAL_DESTINATION=") }),
           let raw = arg.split(separator: "=").last.map(String.init),
           let destination = LifeBoardDestination(rawValue: raw) {
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

    public func select(_ destination: LifeBoardDestination) {
        selectedDestination = destination
    }

    /// Activates a primary destination using platform tab/sidebar semantics.
    /// Switching destinations preserves each navigation stack; selecting the
    /// already-active destination again returns that stack to its root.
    public func activateRoot(_ destination: LifeBoardDestination) {
        if selectedDestination == destination {
            popToRoot(in: destination)
        } else {
            select(destination)
        }
    }

    public func path(for destination: LifeBoardDestination) -> [AppRoute] {
        paths[destination] ?? []
    }

    public func setPath(_ path: [AppRoute], for destination: LifeBoardDestination) {
        paths[destination] = path
    }

    public func push(_ route: AppRoute, in destination: LifeBoardDestination? = nil) {
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
        in destination: LifeBoardDestination
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

    private func append(_ route: AppRoute, in target: LifeBoardDestination) {
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
        in destination: LifeBoardDestination = .track
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

    public func popToRoot(in destination: LifeBoardDestination? = nil) {
        paths[destination ?? selectedDestination] = []
    }

    public func pop(in destination: LifeBoardDestination? = nil) {
        let target = destination ?? selectedDestination
        guard var path = paths[target], path.isEmpty == false else { return }
        path.removeLast()
        paths[target] = path
    }

    public func restoreFallbackToHome(message: String? = nil) {
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
        case "note":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                select(.track)
                return true
            }
            push(.note(id), in: .track)
        case "project":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                select(.plan)
                return true
            }
            push(.project(id), in: .plan)
        case "routine":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                select(.track)
                return true
            }
            push(.routine(id), in: .track)
        case "goal":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                select(.track)
                return true
            }
            push(.goal(id), in: .track)
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

    public func handle(notificationRoute: LifeBoardNotificationRoute) {
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
        case .dayCompass(let flow, _):
            switch flow {
            case .morningPlan:
                push(.planDay, in: .plan)
            case .replan, .rescue, .inbox:
                push(.backlog, in: .plan)
            case .eveningReview:
                select(.insights)
            case .resumeTask:
                select(.home)
            }
        case .dailySummary(let kind, _):
            select(kind == .morning ? .home : .insights)
        }
    }

    public func restorationSnapshot() -> LifeBoardRestorationState {
        LifeBoardRestorationState(
            selectedDestination: selectedDestination,
            paths: paths,
            dashboardMode: dashboardMode,
            daypartSelection: preferences?.daypartSelection ?? .automatic,
            recoverableCaptureDraftID: captureRouter.recoverableDraftID
        )
    }

    public func persist() {
        guard isRestoring == false, let data = try? encoder.encode(restorationSnapshot()) else { return }
        defaults.set(data, forKey: LifeBoardFoundationPreferenceKey.restorationState)
    }

    private func restore() {
        guard let data = defaults.data(forKey: LifeBoardFoundationPreferenceKey.restorationState),
              let state = try? decoder.decode(LifeBoardRestorationState.self, from: data),
              LifeBoardDestination.allCases.contains(state.selectedDestination) else {
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
        for destination in LifeBoardDestination.allCases {
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

public enum LifeBoardSpotlightRouteTranslator {
    public static let journalPrefix = "lifeboard-journal-"

    public static func url(for searchableItemIdentifier: String) -> URL? {
        guard searchableItemIdentifier.hasPrefix(journalPrefix) else { return nil }
        let rawID = String(searchableItemIdentifier.dropFirst(journalPrefix.count))
        guard let id = UUID(uuidString: rawID) else { return nil }
        return URL(string: "lifeboard://journal/\(id.uuidString)")
    }
}

@MainActor
public final class LifeOSFoundationRuntime {
    public static let shared = LifeOSFoundationRuntime()

    public let preferences: LifeBoardPresentationPreferences
    public let captureRouter: CaptureRouter
    public let router: LifeBoardAppRouter

    private init() {
        let preferences = LifeBoardPresentationPreferences()
        let captureRouter = CaptureRouter()
        self.preferences = preferences
        self.captureRouter = captureRouter
        router = LifeBoardAppRouter(preferences: preferences, captureRouter: captureRouter)
    }

    @discardableResult
    public func handle(url: URL) -> Bool {
        router.handle(url: url)
    }
}
