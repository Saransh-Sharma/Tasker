//
//  PresentationDependencyContainer.swift
//  Tasker
//
//  Dependency injection container for presentation layer with ViewModels
//  This container receives pre-configured dependencies from the State layer
//  and creates ViewModels for the presentation layer.
//

import Foundation
import UIKit

/// Dependency container for Clean Architecture ViewModels
/// Receives dependencies from EnhancedDependencyContainer (State layer)
/// and provides ViewModels to the Presentation layer
public final class PresentationDependencyContainer {

    // MARK: - Singleton

    public static let shared = PresentationDependencyContainer()

    // MARK: - Injected Dependencies (from State layer)

    private var taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private var projectRepository: (any ProjectRepositoryProtocol)!
    private var useCaseCoordinator: UseCaseCoordinator!

    // MARK: - ViewModels (Lazy initialization)

    private var _homeViewModel: HomeViewModel?
    private var _addTaskViewModel: AddTaskViewModel?
    private var _addHabitViewModel: AddHabitViewModel?
    private var _addItemViewModel: AddItemViewModel?
    private var _projectManagementViewModel: ProjectManagementViewModel?
    private var _lifeManagementViewModel: LifeManagementViewModel?
    private var _chartCardViewModel: ChartCardViewModel?
    private var _radarChartCardViewModel: RadarChartCardViewModel?
    private var _projectSelectionViewModel: ProjectSelectionViewModel?
    private var _habitLibraryViewModel: HabitLibraryViewModel?

    // MARK: - Configuration State

    private var isConfigured = false
    public private(set) var v3RuntimeReady = false
    public private(set) var v3RuntimeFailureReason: String?

    public var isConfiguredForRuntime: Bool {
        isConfigured
    }

    // MARK: - Initialization

    /// Initializes a new instance.
    private init() {}

    // MARK: - Configuration

    /// Configure the container with dependencies from the State layer
    /// This is the preferred configuration method that maintains clean architecture
    public func configure(
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        projectRepository: ProjectRepositoryProtocol,
        useCaseCoordinator: UseCaseCoordinator
    ) {
        logDebug("🔧 PresentationDependencyContainer: Starting configuration (Clean Architecture)...")

        self.taskReadModelRepository = taskReadModelRepository
        self.projectRepository = projectRepository
        self.useCaseCoordinator = useCaseCoordinator

        evaluateV3RuntimeReadiness()

        self.isConfigured = true
        logDebug("✅ PresentationDependencyContainer: Configuration completed (Clean Architecture)")
    }

    /// Configure using EnhancedDependencyContainer (convenience method)
    /// Call this after EnhancedDependencyContainer has been configured
    public func configureFromStateLayer() {
        let stateContainer = EnhancedDependencyContainer.shared
        configure(
            taskReadModelRepository: stateContainer.taskReadModelRepository,
            projectRepository: stateContainer.projectRepository,
            useCaseCoordinator: stateContainer.useCaseCoordinator
        )
    }

    // MARK: - Setup Methods

    /// Verifies the container is configured before accessing dependencies
    /// Call this at the start of any method that requires configured dependencies
    private func assertConfigured(file: StaticString = #file, line: UInt = #line) {
        guard isConfigured else {
            fatalError(
                """
                PresentationDependencyContainer is not configured!
                Call configure(...) before accessing ViewModels.
                Location: \(file):\(line)
                """
            )
        }
    }

    /// Executes assertV3RuntimeReady.
    public func assertV3RuntimeReady() throws {
        guard v3RuntimeReady else {
            throw NSError(
                domain: "PresentationDependencyContainer",
                code: 503,
                userInfo: [
                    NSLocalizedDescriptionKey: v3RuntimeFailureReason
                    ?? "V3 runtime is not fully wired in presentation container"
                ]
            )
        }
    }

    /// Executes evaluateV3RuntimeReadiness.
    private func evaluateV3RuntimeReadiness() {
        var missingDependencies: [String] = []
        if taskReadModelRepository == nil {
            missingDependencies.append("taskReadModelRepository")
        }
        if projectRepository == nil {
            missingDependencies.append("projectRepository")
        }
        if useCaseCoordinator == nil {
            missingDependencies.append("useCaseCoordinator")
        }

        v3RuntimeReady = missingDependencies.isEmpty
        v3RuntimeFailureReason = v3RuntimeReady
            ? nil
            : "Presentation dependencies missing: \(missingDependencies.joined(separator: ", "))"
    }

    // MARK: - ViewModel Factory Methods

    /// Get or create HomeViewModel
    public func makeHomeViewModel() -> HomeViewModel {
        assertConfigured()
        if let existing = _homeViewModel {
            return existing
        }

        let viewModel = HomeViewModel(
            useCaseCoordinator: useCaseCoordinator,
            aiSuggestionService: MainActor.assumeIsolated { AISuggestionService.shared }
        )
        _homeViewModel = viewModel
        return viewModel
    }

    /// Get or create AddTaskViewModel
    public func makeAddTaskViewModel() -> AddTaskViewModel {
        assertConfigured()
        if let existing = _addTaskViewModel {
            return existing
        }

        let viewModel = AddTaskViewModel(
            taskReadModelRepository: taskReadModelRepository,
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            createTaskDefinitionUseCase: useCaseCoordinator.createTaskDefinition,
            rescheduleTaskDefinitionUseCase: useCaseCoordinator.rescheduleTaskDefinition,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageSectionsUseCase: useCaseCoordinator.manageSections,
            manageTagsUseCase: useCaseCoordinator.manageTags,
            gamificationEngine: useCaseCoordinator.gamificationEngine,
            aiSuggestionService: MainActor.assumeIsolated { AISuggestionService.shared }
        )
        _addTaskViewModel = viewModel
        return viewModel
    }

    /// Get or create AddHabitViewModel
    @MainActor
    public func makeAddHabitViewModel() -> AddHabitViewModel {
        assertConfigured()
        if let existing = _addHabitViewModel {
            return existing
        }

        let viewModel = AddHabitViewModel(
            createHabitUseCase: useCaseCoordinator.createHabit,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            iconCatalog: HabitIconCatalog.shared
        )
        _addHabitViewModel = viewModel
        return viewModel
    }

    /// Get or create AddItemViewModel
    @MainActor
    public func makeAddItemViewModel() -> AddItemViewModel {
        assertConfigured()
        if let existing = _addItemViewModel {
            return existing
        }

        let viewModel = AddItemViewModel(
            taskViewModel: makeAddTaskViewModel(),
            habitViewModel: makeAddHabitViewModel()
        )
        _addItemViewModel = viewModel
        return viewModel
    }

    /// Get or create ProjectManagementViewModel
    public func makeProjectManagementViewModel() -> ProjectManagementViewModel {
        assertConfigured()
        if let existing = _projectManagementViewModel {
            return existing
        }

        let viewModel = ProjectManagementViewModel(
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            getTasksUseCase: useCaseCoordinator.getTasks
        )
        _projectManagementViewModel = viewModel
        return viewModel
    }

    /// Get or create LifeManagementViewModel
    @MainActor
    public func makeLifeManagementViewModel() -> LifeManagementViewModel {
        assertConfigured()
        if let existing = _lifeManagementViewModel {
            return existing
        }

        let viewModel = LifeManagementViewModel(
            useCaseCoordinator: useCaseCoordinator,
            projectRepository: projectRepository
        )
        _lifeManagementViewModel = viewModel
        return viewModel
    }

    /// Executes makeChartCardViewModel.
    public func makeChartCardViewModel() -> ChartCardViewModel {
        assertConfigured()
        if let existing = _chartCardViewModel {
            return existing
        }

        let viewModel = ChartCardViewModel(
            readModelRepository: taskReadModelRepository
        )
        _chartCardViewModel = viewModel
        return viewModel
    }

    /// Executes makeRadarChartCardViewModel.
    public func makeRadarChartCardViewModel() -> RadarChartCardViewModel {
        assertConfigured()
        if let existing = _radarChartCardViewModel {
            return existing
        }

        let viewModel = RadarChartCardViewModel(
            projectRepository: projectRepository,
            readModelRepository: taskReadModelRepository
        )
        _radarChartCardViewModel = viewModel
        return viewModel
    }

    /// Executes makeProjectSelectionViewModel.
    public func makeProjectSelectionViewModel() -> ProjectSelectionViewModel {
        assertConfigured()
        if let existing = _projectSelectionViewModel {
            return existing
        }

        let viewModel = ProjectSelectionViewModel(
            projectRepository: projectRepository,
            readModelRepository: taskReadModelRepository
        )
        _projectSelectionViewModel = viewModel
        return viewModel
    }

    @MainActor
    public func makeHabitLibraryViewModel() -> HabitLibraryViewModel {
        assertConfigured()
        if let existing = _habitLibraryViewModel {
            return existing
        }

        let viewModel = HabitLibraryViewModel(
            getHabitLibraryUseCase: useCaseCoordinator.getHabitLibrary
        )
        _habitLibraryViewModel = viewModel
        return viewModel
    }

    /// Create a fresh AddTaskViewModel (for modal presentations)
    public func makeNewAddTaskViewModel() -> AddTaskViewModel {
        assertConfigured()
        return AddTaskViewModel(
            taskReadModelRepository: taskReadModelRepository,
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            createTaskDefinitionUseCase: useCaseCoordinator.createTaskDefinition,
            rescheduleTaskDefinitionUseCase: useCaseCoordinator.rescheduleTaskDefinition,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageSectionsUseCase: useCaseCoordinator.manageSections,
            manageTagsUseCase: useCaseCoordinator.manageTags,
            gamificationEngine: useCaseCoordinator.gamificationEngine,
            aiSuggestionService: MainActor.assumeIsolated { AISuggestionService.shared }
        )
    }

    /// Create a fresh AddHabitViewModel (for modal presentations)
    @MainActor
    public func makeNewAddHabitViewModel() -> AddHabitViewModel {
        assertConfigured()
        return AddHabitViewModel(
            createHabitUseCase: useCaseCoordinator.createHabit,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            iconCatalog: HabitIconCatalog.shared
        )
    }

    /// Create a fresh AddItemViewModel (for modal presentations)
    @MainActor
    public func makeNewAddItemViewModel() -> AddItemViewModel {
        assertConfigured()
        return AddItemViewModel(
            taskViewModel: makeNewAddTaskViewModel(),
            habitViewModel: makeNewAddHabitViewModel()
        )
    }

    @MainActor
    public func makeNewHabitLibraryViewModel() -> HabitLibraryViewModel {
        assertConfigured()
        return HabitLibraryViewModel(
            getHabitLibraryUseCase: useCaseCoordinator.getHabitLibrary
        )
    }

    @MainActor
    public func makeHabitBoardViewModel() -> HabitBoardViewModel {
        assertConfigured()
        return HabitBoardViewModel(
            getHabitLibraryUseCase: useCaseCoordinator.getHabitLibrary,
            getHabitHistoryUseCase: useCaseCoordinator.getHabitHistory
        )
    }

    @MainActor
    public func makeHabitDetailViewModel(row: HabitLibraryRow) -> HabitDetailViewModel {
        assertConfigured()
        return HabitDetailViewModel(
            row: row,
            getHabitLibraryUseCase: useCaseCoordinator.getHabitLibrary,
            getHabitHistoryUseCase: useCaseCoordinator.getHabitHistory,
            updateHabitUseCase: useCaseCoordinator.updateHabit,
            pauseHabitUseCase: useCaseCoordinator.pauseHabit,
            archiveHabitUseCase: useCaseCoordinator.archiveHabit,
            resolveHabitOccurrenceUseCase: useCaseCoordinator.resolveHabitOccurrence,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            iconCatalog: HabitIconCatalog.shared
        )
    }

    // MARK: - View Controller Injection

    /// Inject dependencies into a view controller
    public func inject(into viewController: UIViewController) {
        assertConfigured()
        let vcType = String(describing: type(of: viewController))
        logDebug("💉 PresentationDependencyContainer: Injecting into \(vcType)")

        if let containerAware = viewController as? PresentationDependencyContainerAware {
            containerAware.presentationDependencyContainer = self
        }

        // Check for specific view controller types and inject ViewModels
        switch viewController {
        case let homeVC as HomeViewControllerProtocol:
            homeVC.viewModel = makeHomeViewModel()
            if let analyticsInjectable = viewController as? HomeAnalyticsViewModelsInjectable {
                analyticsInjectable.chartCardViewModel = makeChartCardViewModel()
                analyticsInjectable.radarChartCardViewModel = makeRadarChartCardViewModel()
            }
            logDebug("✅ Injected HomeViewModel")

        case let projectVC as ProjectManagementViewControllerProtocol:
            projectVC.viewModel = makeProjectManagementViewModel()
            logDebug("✅ Injected ProjectManagementViewModel")

        case let coordinatorInjectable as UseCaseCoordinatorInjectable:
            coordinatorInjectable.useCaseCoordinator = useCaseCoordinator
            logDebug("✅ Injected UseCaseCoordinator")

        default:
            logDebug("ℹ️ No specific injection for \(vcType)")
        }

        // Inject into child view controllers
        for child in viewController.children {
            inject(into: child)
        }
    }

    /// Attempts dependency injection without crashing when the container is not configured.
    /// Returns true when injection succeeded.
    @discardableResult
    public func tryInject(into viewController: UIViewController) -> Bool {
        guard isConfigured else {
            let vcType = String(describing: type(of: viewController))
            logWarning(
                event: "presentation_injection_skipped_unconfigured",
                message: "Skipping dependency injection because presentation container is not configured",
                fields: ["view_controller": vcType]
            )
            return false
        }
        inject(into: viewController)
        return true
    }

    // MARK: - Direct Access (for migration)

    /// Get the use case coordinator directly (for gradual migration)
    public var coordinator: UseCaseCoordinator {
        assertConfigured()
        return useCaseCoordinator
    }
}

// MARK: - View Controller Protocols

/// Protocol for HomeViewController to receive ViewModel
public protocol HomeViewControllerProtocol: AnyObject {
    var viewModel: HomeViewModel! { get set }
}

public protocol HomeAnalyticsViewModelsInjectable: AnyObject {
    var chartCardViewModel: ChartCardViewModel! { get set }
    var radarChartCardViewModel: RadarChartCardViewModel! { get set }
}

/// Protocol for ProjectManagementViewController to receive ViewModel
public protocol ProjectManagementViewControllerProtocol: AnyObject {
    var viewModel: ProjectManagementViewModel! { get set }
}

public protocol PresentationDependencyContainerAware: AnyObject {
    var presentationDependencyContainer: PresentationDependencyContainer? { get set }
}

public protocol UseCaseCoordinatorInjectable: AnyObject {
    var useCaseCoordinator: UseCaseCoordinator! { get set }
}
