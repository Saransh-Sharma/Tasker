import Foundation
import UIKit

@MainActor
final class HomeLaunchHarnessService {
    private static var hasConsumedUITestRoute = false
    private static var hasConsumedUITestOpenSettings = false

    func consumeUITestInjectedRouteIfNeeded(routeHandler: (TaskerNotificationRoute) -> Void) {
        guard Self.hasConsumedUITestRoute == false else { return }
        let prefix = "-TASKER_TEST_ROUTE:"
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else { return }
        let payload = String(argument.dropFirst(prefix.count))
        guard payload.isEmpty == false else { return }
        Self.hasConsumedUITestRoute = true
        let route = TaskerNotificationRoute.from(payload: payload, fallbackTaskID: nil)
        routeHandler(route)
    }

    func consumeUITestOpenSettingsIfNeeded(
        canOpenSettings: @escaping () -> Bool,
        openSettings: @escaping () -> Void
    ) {
        guard Self.hasConsumedUITestOpenSettings == false else { return }
        guard ProcessInfo.processInfo.arguments.contains("-TASKER_TEST_OPEN_SETTINGS") else { return }
        guard canOpenSettings() else { return }

        Self.hasConsumedUITestOpenSettings = true
        DispatchQueue.main.async {
            guard canOpenSettings() else { return }
            openSettings()
        }
    }

    func seedUITestWorkspacesIfNeeded(
        establishedSeed: @escaping (@escaping () -> Void) -> Void,
        rescueSeed: @escaping (@escaping () -> Void) -> Void,
        focusSeed: @escaping (@escaping () -> Void) -> Void,
        habitBoardSeed: @escaping (@escaping () -> Void) -> Void,
        quietTrackingSeed: @escaping (@escaping () -> Void) -> Void,
        completion: @escaping () -> Void
    ) {
        establishedSeed {
            rescueSeed {
                focusSeed {
                    habitBoardSeed {
                        quietTrackingSeed {
                            completion()
                        }
                    }
                }
            }
        }
    }
}
