import Foundation
import LifeBoardDomain

public enum RoutineCollectionFocus: Codable, Hashable, Sendable {
    case daypart(ResolvedDaypart)
    case library
}

public enum LifeMomentsFocus: Codable, Hashable, Sendable {
    case overview
    case moment(UUID)
    case add
}

public struct ResolvedRecordRoute: Equatable, Sendable {
    public let destination: Destination
    public let route: AppRoute
    public let requiresProtectedJournalOpen: Bool
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

/// A receipt that has to outlive the screen that made it.
///
/// Deleting or archiving from a detail screen pops that screen, and a receipt
/// drawn inside it would vanish with it — promising an Undo nobody can reach.
/// The shell draws this one above the composer instead (DESIGN.md launch
/// contract 1).
public struct ShellReceipt: Identifiable {
    public let id: UUID
    public let message: String
    public let detail: String?
    /// Returns whether the undo was saved; a failure keeps the receipt up and says so.
    public let undo: (@MainActor () async -> Bool)?

    public init(
        id: UUID = UUID(),
        message: String,
        detail: String? = nil,
        undo: (@MainActor () async -> Bool)? = nil
    ) {
        self.id = id
        self.message = message
        self.detail = detail
        self.undo = undo
    }
}

/// Pure: sheet over the current root, or the Eva tab.
public enum EvaPresentationPolicy {
    public enum Decision: Equatable { case sheet, tab }

    public static func decide(flagOn: Bool, current: Destination) -> Decision {
        guard flagOn, current != .eva else { return .tab }
        return .sheet
    }
}
