import UIKit

extension AppDelegate {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    /// Lets the fasting and routine Live Activity buttons act in place.
    ///
    /// Each closure does what `SceneDelegate.handleIncomingURL` does for the
    /// same `lifeboard://fasting/…` / `lifeboard://routine/…` URL, minus the
    /// routing and alerts — the person is on the Lock Screen, not in the app.
    /// Returns `true` only when the command was saved.
    static func installFastingAndRoutineIntentBridges() {
        FastingLiveActivityIntentBridge.perform = { url in
            guard let command = FastingLiveActivityDeepLink.command(from: url),
                  V2FeatureFlags.trackBehaviorFlagshipV1Enabled,
                  let store = await AppDelegate.fastingStoreWhenReady() else {
                return false
            }
            do {
                guard try await store.activeSession()?.id == command.sessionID else { return false }
                switch command.action {
                case .finish:
                    _ = try await store.finish()
                case .cancel:
                    _ = try await store.cancel()
                }
                return true
            } catch {
                logWarning(
                    event: "fasting_live_activity_intent_failed",
                    message: "Fasting Live Activity command was not applied",
                    fields: ["error": error.localizedDescription]
                )
                return false
            }
        }

        RoutineLiveActivityIntentBridge.perform = { url in
            guard let command = RoutineLiveActivityDeepLink.command(from: url),
                  V2FeatureFlags.trackBehaviorFlagshipV1Enabled,
                  let repository = await AppDelegate.routineRepositoryWhenReady() else {
                return false
            }
            do {
                guard let run = try await repository
                    .fetchRoutineRuns(routineID: nil)
                    .first(where: { $0.id == command.runID }) else {
                    return false
                }
                let transition = DefaultRoutineExecutionService().apply(
                    command: command.action.runCommand,
                    to: run,
                    at: Date()
                )
                try await repository.saveRoutineRun(transition.run)
                await RoutineLiveActivityCoordinator.shared.synchronize(run: transition.run)
                SystemSurfaceRefresher.requestRefreshSoon()
                return true
            } catch {
                logWarning(
                    event: "routine_live_activity_intent_failed",
                    message: "Routine Live Activity command was not applied",
                    fields: ["error": error.localizedDescription]
                )
                return false
            }
        }
    }

    private static func fastingStoreWhenReady() async -> FastingTimerStore? {
        guard let container = await readyWritableContainer() else { return nil }
        return FastingTimerStore(
            repository: FastingRepositoryAdapter(
                repository: CoreDataLifeBoardPhaseIIRepository(container: container)
            )
        )
    }

    private static func routineRepositoryWhenReady() async -> CoreDataTrackFoundationRepository? {
        guard let container = await readyWritableContainer() else { return nil }
        return CoreDataTrackFoundationRepository(container: container)
    }
    #endif
}
