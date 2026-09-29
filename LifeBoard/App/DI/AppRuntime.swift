import CoreData
import Foundation
import Observation

@MainActor
struct AppUseCases {
    let coordinator: UseCaseCoordinator
}

@MainActor
struct FeatureRouteFactories {
    let makeHomeViewModel: () -> HomeViewModel
}

@MainActor
struct AppPlatformServices {
    let notifications: any NotificationServiceProtocol
    let reminders: (any AppleRemindersRepositoryProtocol)?
    let calendarEvents: (any CalendarEventsRepositoryProtocol)?
}

/// The complete, immutable dependency graph for a ready application runtime.
/// Keeping this value main-actor isolated prevents UIKit, Core Data, and legacy
/// callback services from crossing isolation domains accidentally.
@MainActor
struct AppGraph {
    let persistence: LifeBoardPersistenceStack
    let repositories: LifeBoardRepositoryBundle
    let useCases: AppUseCases
    let featureFactories: FeatureRouteFactories
    let platformServices: AppPlatformServices
}

@MainActor
enum AppRuntimeState {
    case bootstrapping(BootstrapProgress)
    case ready(AppGraph)
    case failed(BootstrapFailure)
}

@MainActor
protocol AppBootstrapping: AnyObject {
    func bootstrap() async -> Result<AppGraph, BootstrapFailure>
    func recover(using action: BootstrapRecoveryAction) async -> Result<AppGraph, BootstrapFailure>
}

extension AppBootstrapping {
    func recover(using action: BootstrapRecoveryAction) async -> Result<AppGraph, BootstrapFailure> {
        _ = action
        return await bootstrap()
    }
}

/// Owns graph construction during the compatibility milestone. Persistence
/// opening still enters through AppDelegate, but no consumer can observe the
/// repository bundle until every required dependency validates successfully.
@MainActor
final class AppBootstrapCoordinator: AppBootstrapping {
    typealias BootstrapOperation = @MainActor () async -> Result<AppGraph, BootstrapFailure>
    typealias RecoveryOperation = @MainActor (BootstrapRecoveryAction) async -> Result<AppGraph, BootstrapFailure>

    private let bootstrapOperation: BootstrapOperation?
    private let recoveryOperation: RecoveryOperation?

    init(
        bootstrapOperation: BootstrapOperation? = nil,
        recoveryOperation: RecoveryOperation? = nil
    ) {
        self.bootstrapOperation = bootstrapOperation
        self.recoveryOperation = recoveryOperation
    }

    func bootstrap() async -> Result<AppGraph, BootstrapFailure> {
        guard let bootstrapOperation else {
            return .failure(Self.unavailableFailure())
        }
        return await bootstrapOperation()
    }

    func recover(using action: BootstrapRecoveryAction) async -> Result<AppGraph, BootstrapFailure> {
        if let recoveryOperation {
            return await recoveryOperation(action)
        }
        return await bootstrap()
    }

    func composeGraph(
        container: NSPersistentCloudKitContainer,
        syncModeProvider: @escaping @Sendable () -> PersistentSyncMode
    ) throws -> AppGraph {
        let persistence = LifeBoardPersistenceStack(container: container)
        let repositories = persistence.makeRepositoryBundle(syncModeProvider: syncModeProvider)
        let compatibilityRoot = CompositionRoot.shared
        compatibilityRoot.configure(with: repositories)
        try compatibilityRoot.assertV3RuntimeReady()

        guard let notificationService = compatibilityRoot.notificationService else {
            throw BootstrapFailure.dependencyGraph()
        }

        return AppGraph(
            persistence: persistence,
            repositories: repositories,
            useCases: AppUseCases(coordinator: compatibilityRoot.useCaseCoordinator),
            featureFactories: FeatureRouteFactories(
                makeHomeViewModel: { compatibilityRoot.makeHomeViewModel() }
            ),
            platformServices: AppPlatformServices(
                notifications: notificationService,
                reminders: compatibilityRoot.remindersProvider,
                calendarEvents: compatibilityRoot.calendarEventsProvider
            )
        )
    }

    private static func unavailableFailure() -> BootstrapFailure {
        BootstrapFailure(
            code: .coordinatorUnavailable,
            userFacingMessage: "LifeBoard is not ready to start yet.",
            recoveryActions: [.retry]
        )
    }
}

@MainActor
@Observable
final class AppRuntime {
    private(set) var state: AppRuntimeState = .bootstrapping(.starting)

    @ObservationIgnored private var bootstrapper: (any AppBootstrapping)?
    @ObservationIgnored private var generation: UInt64 = 0

    init(bootstrapper: (any AppBootstrapping)? = nil) {
        self.bootstrapper = bootstrapper
    }

    func install(bootstrapper: any AppBootstrapping) {
        self.bootstrapper = bootstrapper
    }

    func bootstrap() {
        run(action: nil)
    }

    func retryBootstrap() {
        run(action: .retry)
    }

    func performRecovery(_ action: BootstrapRecoveryAction) {
        run(action: action)
    }

    func publishBootstrapping(_ progress: BootstrapProgress) {
        generation &+= 1
        state = .bootstrapping(progress)
    }

    func publishReady(_ graph: AppGraph) {
        state = .ready(graph)
    }

    func publishFailure(_ failure: BootstrapFailure) {
        state = .failed(failure)
    }

    private func run(action: BootstrapRecoveryAction?) {
        generation &+= 1
        let requestedGeneration = generation
        state = .bootstrapping(action == nil ? .starting : .openingPersistentStores)

        guard let bootstrapper else {
            state = .failed(BootstrapFailure(
                code: .coordinatorUnavailable,
                userFacingMessage: "LifeBoard is not ready to start yet."
            ))
            return
        }

        Task { [weak self] in
            let result: Result<AppGraph, BootstrapFailure>
            if let action {
                result = await bootstrapper.recover(using: action)
            } else {
                result = await bootstrapper.bootstrap()
            }
            guard let self, self.generation == requestedGeneration else { return }
            switch result {
            case .success(let graph):
                self.state = .ready(graph)
            case .failure(let failure):
                self.state = .failed(failure)
            }
        }
    }
}
