import Foundation
import LifeBoardDomain
import LifeBoardUI
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

/// When each Pomodoro phase of a running session ends, as notifications.
///
/// Phases only advanced while the Focus screen was open, so a session running
/// in the background passed its break silently. Each phase end is scheduled
/// up front, assuming the next phase starts when the last one ends (which is
/// what the in-app auto-advance does); any pause, resume or end reschedules.
enum FocusPomodoroNotificationPlan {
    struct Alert: Equatable {
        let fireDate: Date
        let title: String
        let body: String
    }

    static func alerts(
        from current: FocusPomodoroPhase,
        focus: TimeInterval,
        breakDuration: TimeInterval,
        rounds: Int,
        now: Date
    ) -> [Alert] {
        let totalRounds = max(1, rounds)
        var alerts: [Alert] = []
        var kind = current.kind
        var round = current.round
        var endsAt = current.phaseEndsAt
        // Bounded: two phases per round at most.
        for _ in 0..<(totalRounds * 2) {
            switch kind {
            case .focus:
                alerts.append(.init(
                    fireDate: endsAt,
                    title: String(localized: "Break"),
                    body: String(localized: "Round \(round) of \(totalRounds) done · \(LifeBoardDuration.text(minutes: Int((breakDuration / 60).rounded()))) break")
                ))
                kind = .rest
                endsAt = endsAt.addingTimeInterval(max(0, breakDuration))
            case .rest:
                if round >= totalRounds {
                    alerts.append(.init(
                        fireDate: endsAt,
                        title: String(localized: "Focus done"),
                        body: String(localized: "All \(totalRounds) rounds done")
                    ))
                    return alerts.filter { $0.fireDate > now }
                }
                round += 1
                alerts.append(.init(
                    fireDate: endsAt,
                    title: String(localized: "Back to focus"),
                    body: String(localized: "Round \(round) of \(totalRounds)")
                ))
                kind = .focus
                endsAt = endsAt.addingTimeInterval(max(0, focus))
            }
        }
        return alerts.filter { $0.fireDate > now }
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
        let phasePrefix = Self.phaseIdentifierPrefix(for: session.id)
        let stalePhases = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(phasePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: [identifier] + stalePhases)

        // Pomodoro phase ends are announced whether or not a Live Activity is
        // showing: the activity counts down, it does not alert. Paused or
        // ended sessions get none — the removal above cancelled them.
        if authorized, session.state == .running {
            await schedulePomodoroPhases(for: session, prefix: phasePrefix, now: now)
        }

        guard case let .schedule(delay) = FocusNotificationFallbackPolicy.decision(
            for: session,
            now: now,
            liveActivitiesAvailable: liveActivitiesAvailable,
            notificationsAuthorized: authorized
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Focus done")
        content.body = Self.completionBody(title: title, duration: session.targetDuration)
        content.sound = .default
        content.userInfo = Self.userInfo(for: session)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        )
        try? await center.add(request)
    }

    /// "25 min on ‘Write spec’", or just the length when the session has no
    /// name of its own (the generic "Focus session" title).
    static func completionBody(title: String, duration: TimeInterval) -> String {
        let length = LifeBoardDuration.text(seconds: duration)
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false, name != "Focus session" else { return length }
        return String(localized: "\(length) on ‘\(name)’")
    }

    private func schedulePomodoroPhases(for session: FocusSessionV2, prefix: String, now: Date) async {
        guard let companion = try? await FocusSessionCompanionStore.shared.companion(sessionID: session.id, now: now),
              case let .pomodoro(focus, breakDuration, rounds) = companion.mode,
              let phase = companion.pomodoroPhase else { return }
        let alerts = FocusPomodoroNotificationPlan.alerts(
            from: phase,
            focus: focus,
            breakDuration: breakDuration,
            rounds: rounds,
            now: now
        )
        for (index, alert) in alerts.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            content.userInfo = Self.userInfo(for: session)
            let request = UNNotificationRequest(
                identifier: "\(prefix)\(index)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, alert.fireDate.timeIntervalSince(now)),
                    repeats: false
                )
            )
            try? await center.add(request)
        }
    }

    /// Carries the session and a route in the same keys `LocalNotificationService`
    /// writes, so a tap lands on the focus session (or its task) instead of
    /// just opening the app.
    private static func userInfo(for session: FocusSessionV2) -> [String: String] {
        var info = [
            "focusSessionID": session.id.uuidString,
            LocalNotificationRequest.UserInfoKey.route: "focus_session:\(session.id.uuidString)"
        ]
        if let taskID = session.taskID {
            info[LocalNotificationRequest.UserInfoKey.taskID] = taskID.uuidString
        }
        return info
    }

    private static func phaseIdentifierPrefix(for sessionID: UUID) -> String {
        "lifeboard.focus.fallback.phase.\(sessionID.uuidString)."
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
