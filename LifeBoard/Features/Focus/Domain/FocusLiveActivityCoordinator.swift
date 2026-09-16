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
        // Reaching zero is a prompt, never an inferred completion. Pausing
        // preserves the exact focused duration and asks the user to Finish,
        // Continue Later, or Abandon when LifeBoard becomes active again.
        return .pause
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
        let existing = Activity<FocusActivityAttributes>.activities.first {
            $0.attributes.sessionID == session.id
        }

        if session.state == .ended {
            // "Done · 25 min" stays on the Lock Screen for a minute, so ending
            // from the island reads as finished rather than as vanished.
            if let existing {
                await existing.end(content, dismissalPolicy: .after(now.addingTimeInterval(60)))
            }
            return true
        }

        if let existing {
            await existing.update(content)
            return true
        }

        do {
            _ = try Activity.request(
                attributes: FocusActivityAttributes(sessionID: session.id, title: title),
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
        for activity in Activity<FocusActivityAttributes>.activities
        where activity.attributes.sessionID != sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func contentState(for session: FocusSessionV2, now: Date) -> FocusActivityAttributes.ContentState {
        let focused = session.focusedDuration(at: now)
        let remaining = max(0, session.targetDuration - focused)
        return .init(
            phase: session.state.rawValue,
            remainingDuration: remaining,
            expectedEndAt: session.state == .running ? now.addingTimeInterval(remaining) : nil,
            updatedAt: now,
            targetDuration: session.targetDuration > 0 ? session.targetDuration : nil,
            focusedDuration: focused
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

/// Runs a focus command that arrived from outside the app's own screens — a
/// Live Activity button's intent or a `lifeboard://focus` link — and brings the
/// activity and notification fallback in line with the result.
enum FocusLiveActivityCommandRunner {
    static func run(_ command: FocusSessionCommand, repository: CoreDataPlanningRepository) async throws {
        let session = try await repository.handle(command)
        let liveActivitiesAvailable = await FocusLiveActivityCoordinator.shared.synchronize(session: session)
        await FocusNotificationFallbackCoordinator.shared.synchronize(
            session: session,
            title: "Focus session",
            liveActivitiesAvailable: liveActivitiesAvailable
        )
        await MainActor.run {
            // Plan and Focus reload what the Lock Screen just changed.
            NotificationCenter.default.post(name: .foundationDomainMaintenanceCommitted, object: nil)
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    /// Installed at launch so Live Activity buttons act without opening the app.
    static func installIntentBridge(makeRepository: @escaping @Sendable () -> CoreDataPlanningRepository) {
        FocusLiveActivityIntentBridge.perform = { url in
            guard let command = FocusLiveActivityDeepLink.command(from: url) else { return }
            try? await run(command, repository: makeRepository())
        }
    }
    #endif
}
