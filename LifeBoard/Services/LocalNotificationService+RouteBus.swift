import Foundation

public final class NotificationRouteBus: @unchecked Sendable {
    public static let routeDidChange = Notification.Name("LifeBoardNotificationRouteDidChange")
    public static let shared = NotificationRouteBus()

    private var pendingRoute: NotificationRoute?
    private let lock = NSLock()

    private init() {}

    public func post(route: NotificationRoute) {
        lock.lock()
        pendingRoute = route
        lock.unlock()
        NotificationCenter.default.post(
            name: Self.routeDidChange,
            object: nil,
            userInfo: ["payload": route.payload]
        )
    }

    public func consumePendingRoute() -> NotificationRoute? {
        lock.lock()
        defer { lock.unlock() }
        let route = pendingRoute
        pendingRoute = nil
        return route
    }
}
