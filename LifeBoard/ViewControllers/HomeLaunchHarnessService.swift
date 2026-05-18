import Foundation
import UIKit

struct HomeLaunchHarnessWorkspaceSeeders {
    let establishedSeed: (@escaping () -> Void) -> Void
    let rescueSeed: (@escaping () -> Void) -> Void
    let focusSeed: (@escaping () -> Void) -> Void
    let habitBoardSeed: (@escaping () -> Void) -> Void
    let quietTrackingSeed: (@escaping () -> Void) -> Void
}

@MainActor
final class UITestWorkspaceSeeder {
    private let seeders: HomeLaunchHarnessWorkspaceSeeders

    init(seeders: HomeLaunchHarnessWorkspaceSeeders) {
        self.seeders = seeders
    }

    func seed(completion: @escaping () -> Void) {
        seeders.establishedSeed {
            self.seeders.rescueSeed {
                self.seeders.focusSeed {
                    self.seeders.habitBoardSeed {
                        self.seeders.quietTrackingSeed {
                            completion()
                        }
                    }
                }
            }
        }
    }
}

@MainActor
final class HomeLaunchHarnessService {
    private static var hasConsumedUITestRoute = false
    private static var hasConsumedUITestOpenSettings = false

    func consumeUITestInjectedRouteIfNeeded(routeHandler: (LifeBoardNotificationRoute) -> Void) {
        guard Self.hasConsumedUITestRoute == false else { return }
        let prefix = "-LIFEBOARD_TEST_ROUTE:"
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else { return }
        let payload = String(argument.dropFirst(prefix.count))
        guard payload.isEmpty == false else { return }
        Self.hasConsumedUITestRoute = true
        let route = LifeBoardNotificationRoute.from(payload: payload, fallbackTaskID: nil)
        routeHandler(route)
    }

    func consumeUITestOpenSettingsIfNeeded(
        canOpenSettings: @escaping () -> Bool,
        openSettings: @escaping () -> Void
    ) {
        guard Self.hasConsumedUITestOpenSettings == false else { return }
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_OPEN_SETTINGS") else { return }
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
        seedUITestWorkspacesIfNeeded(
            seeders: HomeLaunchHarnessWorkspaceSeeders(
                establishedSeed: establishedSeed,
                rescueSeed: rescueSeed,
                focusSeed: focusSeed,
                habitBoardSeed: habitBoardSeed,
                quietTrackingSeed: quietTrackingSeed
            ),
            completion: completion
        )
    }

    func seedUITestWorkspacesIfNeeded(
        seeders: HomeLaunchHarnessWorkspaceSeeders,
        completion: @escaping () -> Void
    ) {
        UITestWorkspaceSeeder(seeders: seeders).seed(completion: completion)
    }
}
