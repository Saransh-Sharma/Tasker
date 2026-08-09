//
//  CompositionRoot.swift
//  LifeBoard
//
//  Dependency injection container for presentation layer with ViewModels
//  This container receives pre-configured dependencies from the State layer
//  and creates ViewModels for the presentation layer.
//

import Foundation
import UIKit

/// Explicit capabilities required by Plan and Inbox.
///
/// The composition root resolves repositories once and passes this value down
/// through the shell. SwiftUI views therefore never name either dependency
/// container and previews/tests can provide focused substitutes.
struct PlanFeatureDependencies {
    let planningRepository: CoreDataPlanningRepository
    let inboxCommitCoordinator: InboxCommitCoordinator
    let taskExecutionProjection: TaskExecutionProjection
    let taskBatchMutationCoordinator: TaskBatchMutationCoordinator
    let projectTemplateInstantiationService: ProjectTemplateInstantiationService
    let focusCommands: FocusSessionCommands
    let focusXPSubscriber: FocusCompletionXPSubscriber
    let projectMilestoneRepository: any ProjectMilestoneRepository
    let taskDefinitionRepository: any TaskDefinitionRepositoryProtocol
    let projectRepository: any ProjectRepositoryProtocol
    let sectionRepository: (any SectionRepositoryProtocol)?
    let lifeAreaRepository: (any LifeAreaRepositoryProtocol)?
    let tagRepository: any TagRepositoryProtocol
    let taskTagLinkRepository: (any TaskTagLinkRepositoryProtocol)?
    let taskDependencyRepository: (any TaskDependencyRepositoryProtocol)?
    /// Optional because the composition root builds it only once the write-closed
    /// adapters are available. Close the Day treats its absence as "the note
    /// cannot be saved right now" and still lets the day close — the
    /// reconciliation and the note are separate writes by design.
    let reflectionNoteRepository: (any ReflectionNoteRepositoryProtocol)?

    init(
        planningRepository: CoreDataPlanningRepository,
        taskDefinitionRepository: any TaskDefinitionRepositoryProtocol,
        projectRepository: any ProjectRepositoryProtocol,
        sectionRepository: (any SectionRepositoryProtocol)? = nil,
        lifeAreaRepository: (any LifeAreaRepositoryProtocol)? = nil,
        tagRepository: any TagRepositoryProtocol,
        gamificationEngine: GamificationService,
        taskTagLinkRepository: (any TaskTagLinkRepositoryProtocol)? = nil,
        taskDependencyRepository: (any TaskDependencyRepositoryProtocol)? = nil,
        reflectionNoteRepository: (any ReflectionNoteRepositoryProtocol)? = nil
    ) {
        self.planningRepository = planningRepository
        inboxCommitCoordinator = InboxCommitCoordinator(
            writer: CoreDataInboxTaskWriter(
                tasks: taskDefinitionRepository,
                projects: projectRepository,
                tags: tagRepository,
                taskTagLinks: taskTagLinkRepository
            )
        )
        taskExecutionProjection = TaskExecutionProjection(
            repository: planningRepository,
            taskDefinitions: {
                try await withCheckedThrowingContinuation { continuation in
                    taskDefinitionRepository.fetchAll { continuation.resume(with: $0) }
                }
            }
        )
        taskBatchMutationCoordinator = TaskBatchMutationCoordinator(
            tasks: taskDefinitionRepository,
            planning: planningRepository,
            tagLinks: taskTagLinkRepository
        )
        focusCommands = FocusSessionCommands(repository: planningRepository)
        focusXPSubscriber = FocusCompletionXPSubscriber(
            events: focusCommands.completionEvents,
            engine: gamificationEngine
        )
        projectMilestoneRepository = planningRepository
        projectTemplateInstantiationService = ProjectTemplateInstantiationService(
            projects: projectRepository,
            sections: sectionRepository,
            tasks: taskDefinitionRepository,
            tagLinks: taskTagLinkRepository,
            dependencyLinks: taskDependencyRepository,
            milestones: planningRepository,
            planning: planningRepository
        )
        self.taskDefinitionRepository = taskDefinitionRepository
        self.projectRepository = projectRepository
        self.sectionRepository = sectionRepository
        self.lifeAreaRepository = lifeAreaRepository
        self.tagRepository = tagRepository
        self.taskTagLinkRepository = taskTagLinkRepository
        self.taskDependencyRepository = taskDependencyRepository
        self.reflectionNoteRepository = reflectionNoteRepository
    }
}

/// Dependency container for Clean Architecture ViewModels
/// Receives dependencies from CompositionRoot (State layer)
/// and provides ViewModels to the Presentation layer
@MainActor
// The view-model half of the composition root.
//
// This was `CompositionRoot`, a second singleton that
// `configureFromStateLayer()` populated by reaching into the first one.
// Two roots meant two configure calls in a required order, enforced by a
// comment in AppDelegate. One root means the order is the method body.
extension CompositionRoot {

    // MARK: - Singleton


    // MARK: - Injected Dependencies (from State layer)


    // MARK: - ViewModels (Lazy initialization)


    // MARK: - Configuration State


    public var isConfiguredForRuntime: Bool {
        isConfigured
    }

    // MARK: - Configuration

    /// Configured means the one `configure(with:)` has run. There is no second
    /// flag to keep in step now that there is no second container.
    private var isConfigured: Bool { persistentContainer != nil && useCaseCoordinator != nil }

    private func resetCachedViewModelsForRuntimeReconfiguration() {
        guard isConfigured else { return }

        _homeViewModel = nil
        _addTaskViewModel = nil
        _addHabitViewModel = nil
        _projectManagementViewModel = nil
        _lifeManagementViewModel = nil
        _projectSelectionViewModel = nil
        _habitLibraryViewModel = nil

        logDebug("♻️ CompositionRoot: Reset cached ViewModels for runtime reconfiguration")
    }

    // MARK: - Setup Methods

    /// Verifies the container is configured before accessing dependencies
    /// Call this at the start of any method that requires configured dependencies
    private func assertConfigured(file: StaticString = #file, line: UInt = #line) {
        guard isConfigured else {
            fatalError(
                """
                CompositionRoot is not configured!
                Call configure(with:) before accessing ViewModels.
                Location: \(file):\(line)
                """
            )
        }
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
            aiSuggestionService: AISuggestionService.shared
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
            buildWeeklyPlanSnapshotUseCase: useCaseCoordinator.buildWeeklyPlanSnapshot,
            rescheduleTaskDefinitionUseCase: useCaseCoordinator.rescheduleTaskDefinition,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageSectionsUseCase: useCaseCoordinator.manageSections,
            manageTagsUseCase: useCaseCoordinator.manageTags,
            gamificationEngine: useCaseCoordinator.gamificationEngine,
            aiSuggestionService: AISuggestionService.shared
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

    /// Get or create ProjectManagementViewModel
    public func makeProjectManagementViewModel() -> ProjectManagementViewModel {
        assertConfigured()
        if let existing = _projectManagementViewModel {
            return existing
        }

        let viewModel = ProjectManagementViewModel(
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            getTasksUseCase: useCaseCoordinator.getTasks,
            buildWeeklyPlanSnapshotUseCase: useCaseCoordinator.buildWeeklyPlanSnapshot,
            updateTaskDefinitionUseCase: useCaseCoordinator.updateTaskDefinition,
            reflectionNoteRepository: useCaseCoordinator.reflectionNoteRepository,
            gamificationEngine: useCaseCoordinator.gamificationEngine
        )
        _projectManagementViewModel = viewModel
        return viewModel
    }

    @MainActor
    public func makeWeeklyPlannerViewModel(
        referenceDate: Date = Date(),
        plannerPresentation: WeeklyPlannerPresentationMode = .thisWeek
    ) -> WeeklyPlannerViewModel {
        assertConfigured()
        return WeeklyPlannerViewModel(
            referenceDate: referenceDate,
            plannerPresentation: plannerPresentation,
            buildWeeklyPlanSnapshot: useCaseCoordinator.buildWeeklyPlanSnapshot,
            estimateWeeklyCapacity: useCaseCoordinator.estimateWeeklyCapacity,
            getHabitLibraryUseCase: useCaseCoordinator.getHabitLibrary,
            projectRepository: useCaseCoordinator.projectRepository,
            taskDefinitionRepository: useCaseCoordinator.taskDefinitionRepository,
            saveWeeklyPlanUseCase: useCaseCoordinator.saveWeeklyPlan,
            homeAIActionCoordinator: HomeAIActionCoordinator(
                pipeline: useCaseCoordinator.assistantActionPipeline
            ),
            gamificationEngine: useCaseCoordinator.gamificationEngine
        )
    }

    @MainActor
    public func makeWeeklyReviewViewModel(referenceDate: Date = Date()) -> WeeklyReviewViewModel {
        assertConfigured()
        return WeeklyReviewViewModel(
            referenceDate: referenceDate,
            buildWeeklyPlanSnapshot: useCaseCoordinator.buildWeeklyPlanSnapshot,
            getHabitLibraryUseCase: useCaseCoordinator.getHabitLibrary,
            completeWeeklyReviewUseCase: useCaseCoordinator.completeWeeklyReview,
            draftStore: useCaseCoordinator.weeklyReviewDraftStore,
            reflectionNoteRepository: useCaseCoordinator.reflectionNoteRepository,
            gamificationEngine: useCaseCoordinator.gamificationEngine
        )
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
            buildWeeklyPlanSnapshotUseCase: useCaseCoordinator.buildWeeklyPlanSnapshot,
            rescheduleTaskDefinitionUseCase: useCaseCoordinator.rescheduleTaskDefinition,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageSectionsUseCase: useCaseCoordinator.manageSections,
            manageTagsUseCase: useCaseCoordinator.manageTags,
            gamificationEngine: useCaseCoordinator.gamificationEngine,
            aiSuggestionService: AISuggestionService.shared
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
            resetHabitOccurrenceUseCase: useCaseCoordinator.resetHabitOccurrence,
            manageLifeAreasUseCase: useCaseCoordinator.manageLifeAreas,
            manageProjectsUseCase: useCaseCoordinator.manageProjects,
            iconCatalog: HabitIconCatalog.shared
        )
    }

    // MARK: - View Controller Injection

    /// Inject dependencies into a view controller
    @MainActor public func inject(into viewController: UIViewController) {
        assertConfigured()
        let vcType = String(describing: type(of: viewController))
        logDebug("💉 CompositionRoot: Injecting into \(vcType)")

        if let containerAware = viewController as? CompositionRootAware {
            containerAware.presentationDependencyContainer = self
        }

        // Check for remaining UIKit controller types and inject ViewModels.
        switch viewController {
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
    @MainActor public func tryInject(into viewController: UIViewController) -> Bool {
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

/// Protocol for ProjectManagementViewController to receive ViewModel
@MainActor public protocol ProjectManagementViewControllerProtocol: AnyObject {
    var viewModel: ProjectManagementViewModel! { get set }
}

@MainActor public protocol CompositionRootAware: AnyObject {
    var presentationDependencyContainer: CompositionRoot? { get set }
}

@MainActor public protocol UseCaseCoordinatorInjectable: AnyObject {
    var useCaseCoordinator: UseCaseCoordinator! { get set }
}
