import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
final class AppOnboardingCoordinator: NSObject {
    weak var hostAdapter: (UIViewController & AppOnboardingHostAdapter)?


    let presentationDependencyContainer: PresentationDependencyContainer

    let guidanceModel: HomeOnboardingGuidanceModel

    let stateStore: AppOnboardingStateStore

    let eligibilityService: OnboardingEligibilityService

    let notificationCenter: NotificationCenter

    let feedbackController = OnboardingFeedbackController()

    var onboardingHost: UIHostingController<AnyView>?

    var promptHost: UIHostingController<AnyView>?

    var hasEvaluatedLaunch = false

    var presentationQueue = OnboardingPresentationQueue()

    var pendingPresentationWasBlocked = false

    let evaAppManager = AppManager()

    lazy var viewModel = OnboardingFlowModel(
        stateStore: stateStore,
        notificationService: EnhancedDependencyContainer.shared.notificationService,
        calendarService: presentationDependencyContainer.coordinator.calendarIntegrationService,
        fetchLifeAreas: { [weak self] in
            guard let self else { return [] }
            return try await self.presentationDependencyContainer.coordinator.lifeAreaRepository.fetchAllAsync()
        },
        fetchProjects: { [weak self] in
            guard let self else { return [] }
            return try await self.presentationDependencyContainer.coordinator.projectRepository.fetchAllProjectsAsync()
        },
        fetchHabit: { [weak self] habitID in
            guard let self else { return nil }
            let habits = try await self.presentationDependencyContainer.coordinator.manageHabits.listAsync()
            return habits.first(where: { $0.id == habitID })
        },
        fetchTask: { [weak self] taskID in
            guard let self else { return nil }
            return try await self.presentationDependencyContainer.coordinator.taskDefinitionRepository.fetchTaskDefinitionAsync(id: taskID)
        },
        createLifeArea: { [weak self] template in
            guard let self else { return LifeArea(name: template.name, color: template.colorHex, icon: template.icon) }
            return try await self.presentationDependencyContainer.coordinator.manageLifeAreas.createAsync(
                name: template.name,
                color: template.colorHex,
                icon: template.icon
            )
        },
        createProject: { [weak self] draft, lifeArea in
            guard let self else { return Project(lifeAreaID: lifeArea.id, name: draft.name, projectDescription: draft.summary) }
            return try await self.presentationDependencyContainer.coordinator.manageProjects.createProjectAsync(
                request: CreateProjectRequest(
                    name: draft.name,
                    description: draft.summary,
                    lifeAreaID: lifeArea.id
                )
            )
        },
        createHabit: { [weak self] request in
            guard let self else {
                return HabitDefinitionRecord(
                    id: request.id,
                    lifeAreaID: request.lifeAreaID,
                    projectID: request.projectID,
                    title: request.title,
                    habitType: CreateHabitUseCase.habitTypeString(kind: request.kind, trackingMode: request.trackingMode),
                    kindRaw: request.kind.rawValue,
                    trackingModeRaw: request.trackingMode.rawValue,
                    iconSymbolName: request.icon.symbolName,
                    iconCategoryKey: request.icon.categoryKey,
                    targetConfigData: try? JSONEncoder().encode(request.targetConfig),
                    metricConfigData: try? JSONEncoder().encode(request.metricConfig),
                    createdAt: request.createdAt,
                    updatedAt: request.createdAt
                )
            }
            return try await self.presentationDependencyContainer.coordinator.createHabit.executeAsync(request: request)
        },
        createTask: { [weak self] request in
            guard let self else { return request.toTaskDefinition(projectName: request.projectName) }
            return try await self.presentationDependencyContainer.coordinator.createTaskDefinition.executeAsync(request: request)
        },
        setTaskCompletion: { [weak self] taskID, isComplete in
            guard let self else {
                var task = TaskDefinition(id: taskID, title: "Task")
                task.isComplete = isComplete
                task.dateCompleted = isComplete ? Date() : nil
                return task
            }
            return try await self.presentationDependencyContainer.coordinator.completeTaskDefinition.setCompletionAsync(taskID: taskID, to: isComplete)
        },
        resolveHabitOccurrence: { [weak self] habitID, action, date in
            guard let self else { return }
            try await self.presentationDependencyContainer.coordinator.resolveHabitOccurrence.executeAsync(
                habitID: habitID,
                action: action,
                on: date,
                mutationContext: HabitMutationContext(source: "onboarding")
            )
        },
        evaAppManager: evaAppManager
    )

    init?(
        homeViewController: HomeViewController,
        presentationDependencyContainer: PresentationDependencyContainer?,
        guidanceModel: HomeOnboardingGuidanceModel,
        stateStore: AppOnboardingStateStore = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        guard let presentationDependencyContainer else { return nil }
        guard presentationDependencyContainer.isConfiguredForRuntime else { return nil }
        self.hostAdapter = homeViewController
        self.presentationDependencyContainer = presentationDependencyContainer
        self.guidanceModel = guidanceModel
        self.stateStore = stateStore
        self.notificationCenter = notificationCenter
        self.eligibilityService = OnboardingEligibilityService(
            stateStore: stateStore,
            lifeAreaRepository: presentationDependencyContainer.coordinator.lifeAreaRepository,
            projectRepository: presentationDependencyContainer.coordinator.projectRepository,
            taskRepository: presentationDependencyContainer.coordinator.taskDefinitionRepository
        )
        super.init()
    }
}
