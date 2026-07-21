import Foundation
import OSLog
import UserNotifications

enum FocusNotificationFallbackDecision: Equatable {
    case schedule(after: TimeInterval)
    case cancel
}

enum FocusNotificationFallbackPolicy {
    static func decision(
        for session: FocusSessionV2,
        now: Date,
        liveActivitiesAvailable: Bool,
        notificationsAuthorized: Bool
    ) -> FocusNotificationFallbackDecision {
        guard liveActivitiesAvailable == false,
              notificationsAuthorized,
              session.state == .running else { return .cancel }
        let remaining = session.targetDuration - session.focusedDuration(at: now)
        return remaining > 0 ? .schedule(after: remaining) : .cancel
    }
}

enum FocusStartupRepairPolicy {
    static func commandKind(for session: FocusSessionV2, now: Date) -> FocusSessionCommandKind? {
        guard session.state == .running,
              session.targetDuration > 0,
              session.focusedDuration(at: now) >= session.targetDuration else { return nil }
        return .end(.completed)
    }
}

actor FocusNotificationFallbackCoordinator {
    static let shared = FocusNotificationFallbackCoordinator()
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func synchronize(
        session: FocusSessionV2,
        title: String,
        liveActivitiesAvailable: Bool,
        now: Date = Date()
    ) async {
        let settings = await center.notificationSettings()
        let authorized = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
        let identifier = Self.identifier(for: session.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard case let .schedule(delay) = FocusNotificationFallbackPolicy.decision(
            for: session,
            now: now,
            liveActivitiesAvailable: liveActivitiesAvailable,
            notificationsAuthorized: authorized
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Your focus block is complete. Open LifeBoard to record the outcome."
        content.sound = .default
        content.userInfo = ["focusSessionID": session.id.uuidString]
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        )
        try? await center.add(request)
    }

    func cancelAll() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix("lifeboard.focus.fallback.") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func identifier(for sessionID: UUID) -> String {
        "lifeboard.focus.fallback.\(sessionID.uuidString)"
    }
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

actor FocusLiveActivityCoordinator {
    static let shared = FocusLiveActivityCoordinator()
    private let logger = Logger(subsystem: "com.saransh1337.To-Do-List", category: "FocusLiveActivity")

    @discardableResult
    func synchronize(session: FocusSessionV2, title: String = "Focus session", now: Date = Date()) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let state = contentState(for: session, now: now)
        let content = ActivityContent(state: state, staleDate: state.expectedEndAt)
        let existing = Activity<LifeBoardFocusActivityAttributes>.activities.first {
            $0.attributes.sessionID == session.id
        }

        if session.state == .ended {
            if let existing {
                await existing.end(content, dismissalPolicy: .immediate)
            }
            return true
        }

        if let existing {
            await existing.update(content)
            return true
        }

        do {
            _ = try Activity.request(
                attributes: LifeBoardFocusActivityAttributes(sessionID: session.id, title: title),
                content: content,
                pushType: nil
            )
            return true
        } catch {
            logger.error("Live Activity start failed; in-app focus remains authoritative: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    func endOrphanedActivities(except sessionID: UUID?) async {
        for activity in Activity<LifeBoardFocusActivityAttributes>.activities
        where activity.attributes.sessionID != sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func contentState(for session: FocusSessionV2, now: Date) -> LifeBoardFocusActivityAttributes.ContentState {
        let focused = session.focusedDuration(at: now)
        let remaining = max(0, session.targetDuration - focused)
        return .init(
            phase: session.state.rawValue,
            remainingDuration: remaining,
            expectedEndAt: session.state == .running ? now.addingTimeInterval(remaining) : nil,
            updatedAt: now
        )
    }
}

enum FocusLiveActivityDeepLink {
    static func command(from url: URL) -> FocusSessionCommand? {
        guard url.scheme?.lowercased() == "lifeboard", url.host?.lowercased() == "focus",
              let sessionID = url.pathComponents.last.flatMap(UUID.init(uuidString:)),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawCommand = components.queryItems?.first(where: { $0.name == "command" })?.value,
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value.flatMap(UUID.init(uuidString:))
        else { return nil }

        let kind: FocusSessionCommandKind
        switch rawCommand {
        case "pause": kind = .pause
        case "resume": kind = .resume
        case "end": kind = .end(.stopped)
        default: return nil
        }
        return FocusSessionCommand(id: token, sessionID: sessionID, kind: kind)
    }
}
#else
actor FocusLiveActivityCoordinator {
    static let shared = FocusLiveActivityCoordinator()
    @discardableResult
    func synchronize(session: FocusSessionV2, title: String = "Focus session", now: Date = Date()) async -> Bool { false }
    func endOrphanedActivities(except sessionID: UUID?) async {}
}

enum FocusLiveActivityDeepLink {
    static func command(from url: URL) -> FocusSessionCommand? { nil }
}
#endif
