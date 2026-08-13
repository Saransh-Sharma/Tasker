import Foundation
import UIKit

struct HomeLaunchHarnessWorkspaceSeeders {
    let establishedSeed: (@escaping () -> Void) -> Void
    let searchSeed: (@escaping () -> Void) -> Void
    let rescueSeed: (@escaping () -> Void) -> Void
    let focusSeed: (@escaping () -> Void) -> Void
    let habitBoardSeed: (@escaping () -> Void) -> Void
    let quietTrackingSeed: (@escaping () -> Void) -> Void
    let fullTimelineSeed: (@escaping () -> Void) -> Void
    let appStoreScreenshotSeed: (@escaping () -> Void) -> Void

    init(
        establishedSeed: @escaping (@escaping () -> Void) -> Void,
        searchSeed: @escaping (@escaping () -> Void) -> Void = { completion in completion() },
        rescueSeed: @escaping (@escaping () -> Void) -> Void,
        focusSeed: @escaping (@escaping () -> Void) -> Void,
        habitBoardSeed: @escaping (@escaping () -> Void) -> Void,
        quietTrackingSeed: @escaping (@escaping () -> Void) -> Void,
        fullTimelineSeed: @escaping (@escaping () -> Void) -> Void = { completion in completion() },
        appStoreScreenshotSeed: @escaping (@escaping () -> Void) -> Void = { completion in completion() }
    ) {
        self.establishedSeed = establishedSeed
        self.searchSeed = searchSeed
        self.rescueSeed = rescueSeed
        self.focusSeed = focusSeed
        self.habitBoardSeed = habitBoardSeed
        self.quietTrackingSeed = quietTrackingSeed
        self.fullTimelineSeed = fullTimelineSeed
        self.appStoreScreenshotSeed = appStoreScreenshotSeed
    }
}

@MainActor
final class UITestWorkspaceSeeder {
    private let seeders: HomeLaunchHarnessWorkspaceSeeders

    init(seeders: HomeLaunchHarnessWorkspaceSeeders) {
        self.seeders = seeders
    }

    func seed(completion: @escaping () -> Void) {
        seeders.establishedSeed {
            self.seeders.searchSeed {
                self.seeders.rescueSeed {
                    self.seeders.focusSeed {
                        self.seeders.habitBoardSeed {
                            self.seeders.quietTrackingSeed {
                                self.seeders.fullTimelineSeed {
                                    self.seeders.appStoreScreenshotSeed {
                                        completion()
                                    }
                                }
                            }
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
    private static var hasConsumedUITestDeepLink = false
    private static var hasConsumedUITestOpenSettings = false

    func consumeUITestInjectedRouteIfNeeded(routeHandler: (NotificationRoute) -> Void) {
        guard Self.hasConsumedUITestRoute == false else { return }
        guard let payload = Self.firstRoutePayload(prefixes: ["-LIFEBOARD_TEST_POST_SEED_ROUTE:", "-LIFEBOARD_TEST_ROUTE:"]) else {
            return
        }
        guard payload.isEmpty == false else { return }
        Self.hasConsumedUITestRoute = true
        let route = NotificationRoute.from(payload: payload, fallbackTaskID: nil)
        routeHandler(route)
    }

    func consumeUITestInjectedDeepLinkIfNeeded(deepLinkHandler: (URL) -> Void) {
        guard Self.hasConsumedUITestDeepLink == false else { return }
        guard let payload = Self.firstRoutePayload(prefixes: ["-LIFEBOARD_TEST_DEEP_LINK:"]),
              let url = URL(string: payload) else {
            return
        }
        Self.hasConsumedUITestDeepLink = true
        deepLinkHandler(url)
    }

    private static func firstRoutePayload(prefixes: [String]) -> String? {
        for prefix in prefixes {
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) {
                return String(argument.dropFirst(prefix.count))
            }
        }
        return nil
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
        searchSeed: @escaping (@escaping () -> Void) -> Void = { completion in completion() },
        rescueSeed: @escaping (@escaping () -> Void) -> Void,
        focusSeed: @escaping (@escaping () -> Void) -> Void,
        habitBoardSeed: @escaping (@escaping () -> Void) -> Void,
        quietTrackingSeed: @escaping (@escaping () -> Void) -> Void,
        fullTimelineSeed: @escaping (@escaping () -> Void) -> Void,
        appStoreScreenshotSeed: @escaping (@escaping () -> Void) -> Void = { completion in completion() },
        completion: @escaping () -> Void
    ) {
        seedUITestWorkspacesIfNeeded(
            seeders: HomeLaunchHarnessWorkspaceSeeders(
                establishedSeed: establishedSeed,
                searchSeed: searchSeed,
                rescueSeed: rescueSeed,
                focusSeed: focusSeed,
                habitBoardSeed: habitBoardSeed,
                quietTrackingSeed: quietTrackingSeed,
                fullTimelineSeed: fullTimelineSeed,
                appStoreScreenshotSeed: appStoreScreenshotSeed
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

/// App-level UI-test and screenshot workspace orchestration.
///
/// Seeders write through canonical repositories and refresh the shared Home
/// view model after the final write. They no longer require a Home controller
/// lifecycle just to make deterministic journeys available.
@MainActor
final class LaunchCoordinator {
    private let service = HomeLaunchHarnessService()
    private let workspaceSeeder = HomeUITestWorkspaceSeeder()
    private let presentationDependencies: CompositionRoot
    private let homeViewModel: HomeViewModel
    private let router: AppRouter

    init(
        presentationDependencies: CompositionRoot,
        homeViewModel: HomeViewModel,
        router: AppRouter
    ) {
        self.presentationDependencies = presentationDependencies
        self.homeViewModel = homeViewModel
        self.router = router
    }

    func seedUITestWorkspacesIfNeeded(completion: @escaping () -> Void = {}) {
        let dependencies = presentationDependencies
        let viewModel = homeViewModel
        let workspaceSeeder = self.workspaceSeeder
        service.seedUITestWorkspacesIfNeeded(
            seeders: HomeLaunchHarnessWorkspaceSeeders(
                establishedSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedUITestEstablishedWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        completion: done
                    )
                },
                searchSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedUITestSearchWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        viewModel: viewModel,
                        completion: done
                    )
                },
                rescueSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedUITestRescueWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        viewModel: viewModel,
                        completion: done
                    )
                },
                focusSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedUITestFocusWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        completion: done
                    )
                },
                habitBoardSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedUITestHabitBoardWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        completion: done
                    )
                },
                quietTrackingSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedUITestQuietTrackingWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        completion: done
                    )
                },
                fullTimelineSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedUITestFullTimelineWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        viewModel: viewModel,
                        completion: done
                    )
                },
                appStoreScreenshotSeed: { [workspaceSeeder] done in
                    workspaceSeeder.seedAppStoreScreenshotWorkspaceIfNeeded(
                        presentationDependencyContainer: dependencies,
                        viewModel: viewModel,
                        completion: done
                    )
                }
            )
        ) { [weak self] in
            guard let self else {
                completion()
                return
            }
            homeViewModel.invalidateTaskCaches()
            homeViewModel.loadTasksForSelectedDate()
            service.consumeUITestInjectedRouteIfNeeded { [router] route in
                router.handle(notificationRoute: route)
            }
            service.consumeUITestInjectedDeepLinkIfNeeded { [router] url in
                _ = router.handle(url: url)
            }
            service.consumeUITestOpenSettingsIfNeeded(
                canOpenSettings: { true },
                openSettings: { [router] in router.push(.settings, in: router.selectedDestination) }
            )
            completion()
        }
    }
}
