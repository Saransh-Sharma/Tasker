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
import CoreData  // Required for legacy configure(with:) method - only used for backward compatibility

/// Dependency container for Clean Architecture ViewModels
/// Receives dependencies from EnhancedDependencyContainer (State layer)
/// and provides ViewModels to the Presentation layer
public final class PresentationDependencyContainer {

    // MARK: - Singleton

    public static let shared = PresentationDependencyContainer()

    // MARK: - Injected Dependencies (from State layer)

    private var taskRepository: (any TaskRepositoryProtocol)!
    private var projectRepository: (any ProjectRepositoryProtocol)!
    private var cacheService: CacheServiceProtocol!
    private var useCaseCoordinator: UseCaseCoordinator!

    // MARK: - Use Cases (created from injected dependencies)

    private var createTaskUseCase: CreateTaskUseCase!
    private var completeTaskUseCase: CompleteTaskUseCase!
    private var deleteTaskUseCase: DeleteTaskUseCase!
    private var updateTaskUseCase: UpdateTaskUseCase!
    private var rescheduleTaskUseCase: RescheduleTaskUseCase!
    private var getTasksUseCase: GetTasksUseCase!
    private var manageProjectsUseCase: ManageProjectsUseCase!
    private var calculateAnalyticsUseCase: CalculateAnalyticsUseCase!

    // MARK: - ViewModels (Lazy initialization)

    private var _homeViewModel: HomeViewModel?
    private var _addTaskViewModel: AddTaskViewModel?
    private var _projectManagementViewModel: ProjectManagementViewModel?
    private var _chartCardViewModel: ChartCardViewModel?
    private var _radarChartCardViewModel: RadarChartCardViewModel?
    private var _projectSelectionViewModel: ProjectSelectionViewModel?

    // MARK: - Configuration State

    private var isConfigured = false

    public var isConfiguredForRuntime: Bool {
        isConfigured
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Configure the container with dependencies from the State layer
    /// This is the preferred configuration method that maintains clean architecture
    public func configure(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        cacheService: CacheServiceProtocol?,
        useCaseCoordinator: UseCaseCoordinator
    ) {
        logDebug("🔧 PresentationDependencyContainer: Starting configuration (Clean Architecture)...")

        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.cacheService = cacheService ?? InMemoryCacheService()
        self.useCaseCoordinator = useCaseCoordinator

        // Initialize use cases from injected dependencies
        setupUseCases()

        self.isConfigured = true
        logDebug("✅ PresentationDependencyContainer: Configuration completed (Clean Architecture)")
    }

    /// Configure using EnhancedDependencyContainer (convenience method)
    /// Call this after EnhancedDependencyContainer has been configured
    public func configureFromStateLayer() {
        let stateContainer = EnhancedDependencyContainer.shared
        configure(
            taskRepository: stateContainer.taskRepository,
            projectRepository: stateContainer.projectRepository,
            cacheService: stateContainer.cacheService,
            useCaseCoordinator: stateContainer.useCaseCoordinator
        )
    }

    /// Legacy configuration method for backward compatibility with AppDelegate
    /// This configures both State and Presentation layers in one call
    @objc public func configure(with container: NSPersistentContainer) {
        logDebug("🔧 PresentationDependencyContainer: Legacy configuration with NSPersistentContainer...")

        // First configure the State layer (EnhancedDependencyContainer)
        EnhancedDependencyContainer.shared.configure(with: container)

        // Then configure this container from the State layer
        configureFromStateLayer()

        logDebug("✅ PresentationDependencyContainer: Legacy configuration completed")
    }

    // MARK: - Setup Methods

    /// Verifies the container is configured before accessing dependencies
    /// Call this at the start of any method that requires configured dependencies
    private func assertConfigured(file: StaticString = #file, line: UInt = #line) {
        guard isConfigured else {
            fatalError(
                """
                PresentationDependencyContainer is not configured!
                Call configure(...) or configureFromStateLayer() before accessing ViewModels.
                Location: \(file):\(line)
                """
            )
        }
    }

    private func setupUseCases() {
        // Use DefaultTaskScoringService which conforms to TaskScoringServiceProtocol
        let scoringService = DefaultTaskScoringService()

        // Task use cases
        self.createTaskUseCase = CreateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        self.completeTaskUseCase = CompleteTaskUseCase(
            taskRepository: taskRepository,
            scoringService: scoringService,
            analyticsService: nil
        )

        self.deleteTaskUseCase = DeleteTaskUseCase(
            taskRepository: taskRepository,
            notificationService: nil,
            analyticsService: nil
        )

        self.updateTaskUseCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        self.rescheduleTaskUseCase = RescheduleTaskUseCase(
            taskRepository: taskRepository,
            notificationService: nil
        )

        self.getTasksUseCase = GetTasksUseCase(
            taskRepository: taskRepository,
            cacheService: cacheService
        )

        // Project use cases
        self.manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: projectRepository,
            taskRepository: taskRepository
        )

        // Analytics use cases
        self.calculateAnalyticsUseCase = CalculateAnalyticsUseCase(
            taskRepository: taskRepository,
            scoringService: scoringService,
            cacheService: cacheService
        )
    }
    
    // MARK: - ViewModel Factory Methods

    /// Get or create HomeViewModel
    public func makeHomeViewModel() -> HomeViewModel {
        assertConfigured()
        if let existing = _homeViewModel {
            return existing
        }

        let viewModel = HomeViewModel(useCaseCoordinator: useCaseCoordinator)
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
            taskRepository: taskRepository,
            createTaskUseCase: createTaskUseCase,
            manageProjectsUseCase: manageProjectsUseCase,
            rescheduleTaskUseCase: rescheduleTaskUseCase,
            createTaskDefinitionUseCase: useCaseCoordinator.createTaskDefinition,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageSectionsUseCase: useCaseCoordinator.manageSections,
            manageTagsUseCase: useCaseCoordinator.manageTags
        )
        _addTaskViewModel = viewModel
        return viewModel
    }

    /// Get or create ProjectManagementViewModel
    public func makeProjectManagementViewModel() -> ProjectManagementViewModel {
        assertConfigured()
        if let existing = _projectManagementViewModel {
            return existing
        }

        let viewModel = ProjectManagementViewModel(
            manageProjectsUseCase: manageProjectsUseCase,
            getTasksUseCase: getTasksUseCase
        )
        _projectManagementViewModel = viewModel
        return viewModel
    }

    public func makeChartCardViewModel() -> ChartCardViewModel {
        assertConfigured()
        if let existing = _chartCardViewModel {
            return existing
        }

        let viewModel = ChartCardViewModel(taskRepository: taskRepository)
        _chartCardViewModel = viewModel
        return viewModel
    }

    public func makeRadarChartCardViewModel() -> RadarChartCardViewModel {
        assertConfigured()
        if let existing = _radarChartCardViewModel {
            return existing
        }

        let viewModel = RadarChartCardViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        _radarChartCardViewModel = viewModel
        return viewModel
    }

    public func makeProjectSelectionViewModel() -> ProjectSelectionViewModel {
        assertConfigured()
        if let existing = _projectSelectionViewModel {
            return existing
        }

        let viewModel = ProjectSelectionViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        _projectSelectionViewModel = viewModel
        return viewModel
    }

    /// Create a fresh AddTaskViewModel (for modal presentations)
    public func makeNewAddTaskViewModel() -> AddTaskViewModel {
        assertConfigured()
        return AddTaskViewModel(
            taskRepository: taskRepository,
            createTaskUseCase: createTaskUseCase,
            manageProjectsUseCase: manageProjectsUseCase,
            rescheduleTaskUseCase: rescheduleTaskUseCase,
            createTaskDefinitionUseCase: useCaseCoordinator.createTaskDefinition,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageSectionsUseCase: useCaseCoordinator.manageSections,
            manageTagsUseCase: useCaseCoordinator.manageTags
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

        case let addTaskVC as AddTaskViewControllerProtocol:
            addTaskVC.viewModel = makeNewAddTaskViewModel()
            logDebug("✅ Injected AddTaskViewModel")

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

/// Protocol for AddTaskViewController to receive ViewModel
/// Note: viewModel is optional because the ViewModel path may be disabled
public protocol AddTaskViewControllerProtocol: AnyObject {
    var viewModel: AddTaskViewModel? { get set }
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
