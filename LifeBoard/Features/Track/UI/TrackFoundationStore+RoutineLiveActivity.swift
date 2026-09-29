import Foundation

enum RoutineLiveActivityAction: String, Codable, Hashable, Sendable {
    case pause
    case resume
    case stop

    var runCommand: RoutineRunCommand {
        switch self {
        case .pause: .pause
        case .resume: .resume
        case .stop: .stop
        }
    }
}

struct RoutineLiveActivityCommand: Codable, Hashable, Sendable {
    var id: UUID
    var runID: UUID
    var action: RoutineLiveActivityAction
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
import OSLog

actor RoutineLiveActivityCoordinator {
    static let shared = RoutineLiveActivityCoordinator()
    private let logger = Logger(
        subsystem: "com.saransh1337.To-Do-List",
        category: "RoutineLiveActivity"
    )

    @discardableResult
    func synchronize(run: RoutineRun) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let state = contentState(for: run)
        let content = ActivityContent(state: state, staleDate: nil)
        let existing = Activity<RoutineActivityAttributes>.activities.first {
            $0.attributes.runID == run.id
        }
        let isTerminal = switch run.status {
        case .completed, .partial, .abandoned, .skipped: true
        case .running, .paused, .interrupted: false
        }
        if isTerminal {
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
                attributes: RoutineActivityAttributes(
                    runID: run.id,
                    routineID: run.routineID,
                    title: run.versionSnapshot.title
                ),
                content: content,
                pushType: nil
            )
            return true
        } catch {
            logger.error(
                "Live Activity start failed; canonical routine state is unchanged: \(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func endOrphanedActivities(except runID: UUID?) async {
        for activity in Activity<RoutineActivityAttributes>.activities
        where activity.attributes.runID != runID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func contentState(
        for run: RoutineRun
    ) -> RoutineActivityAttributes.ContentState {
        let currentTitle = run.currentStepID.flatMap { currentID in
            run.versionSnapshot.steps.first(where: { $0.id == currentID })?.title
        } ?? String(localized: "All steps done")
        return .init(
            status: run.status.rawValue,
            stepTitle: currentTitle,
            completedStepCount: run.events.count,
            totalStepCount: run.versionSnapshot.steps.count,
            updatedAt: run.updatedAt
        )
    }
}

enum RoutineLiveActivityDeepLink {
    static func command(from url: URL) -> RoutineLiveActivityCommand? {
        guard
            url.scheme?.lowercased() == "lifeboard",
            url.host?.lowercased() == "routine",
            let runID = url.pathComponents.last.flatMap(UUID.init(uuidString:)),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let rawAction = components.queryItems?.first(where: { $0.name == "command" })?.value,
            let action = RoutineLiveActivityAction(rawValue: rawAction),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value
                .flatMap(UUID.init(uuidString:))
        else { return nil }
        return RoutineLiveActivityCommand(id: token, runID: runID, action: action)
    }
}
#else
actor RoutineLiveActivityCoordinator {
    static let shared = RoutineLiveActivityCoordinator()
    @discardableResult
    func synchronize(run: RoutineRun) async -> Bool { false }
    func endOrphanedActivities(except runID: UUID?) async {}
}

enum RoutineLiveActivityDeepLink {
    static func command(from url: URL) -> RoutineLiveActivityCommand? { nil }
}
#endif
