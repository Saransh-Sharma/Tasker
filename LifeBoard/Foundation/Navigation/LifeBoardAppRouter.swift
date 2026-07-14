import Foundation
import Observation

public enum AppRoute: Codable, Hashable, Sendable {
    case taskDetail(UUID)
    case habitDetail(UUID)
    case project(UUID)
    case weeklyPlanner
    case weeklyReview
    case settings
    case tokenGallery
    case referenceDashboard
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
        restore()
        isRestoring = false
        captureRouter.onStateChange = { [weak self] in
            self?.persist()
        }
    }

    public func select(_ destination: LifeBoardDestination) {
        selectedDestination = destination
    }

    public func path(for destination: LifeBoardDestination) -> [AppRoute] {
        paths[destination] ?? []
    }

    public func setPath(_ path: [AppRoute], for destination: LifeBoardDestination) {
        paths[destination] = path
    }

    public func push(_ route: AppRoute, in destination: LifeBoardDestination? = nil) {
        let target = destination ?? selectedDestination
        var path = paths[target] ?? []
        guard path.last != route else { return }
        path.append(route)
        paths[target] = path
        selectedDestination = target
    }

    public func popToRoot(in destination: LifeBoardDestination? = nil) {
        paths[destination ?? selectedDestination] = []
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
            }
        case "habits", "habit":
            guard let rawID = segments.last else {
                if host == "habit" {
                    restoreFallbackToHome(message: "That habit link is incomplete or no longer available.")
                } else {
                    select(.track)
                }
                return true
            }
            guard let id = UUID(uuidString: rawID) else {
                restoreFallbackToHome(message: "That habit link is incomplete or no longer available.")
                return true
            }
            push(.habitDetail(id), in: .track)
        case "insights":
            select(.insights)
        case "chat", "eva":
            select(.eva)
        case "quickadd":
            captureRouter.request(kind: .task, source: .deepLink)
        case "task":
            guard let rawID = segments.first, let id = UUID(uuidString: rawID) else {
                restoreFallbackToHome(message: "That task link is incomplete or no longer available.")
                return true
            }
            push(.taskDetail(id), in: .home)
        case "tasks":
            select(.home)
        default:
            return false
        }
        return true
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
