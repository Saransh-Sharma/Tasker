import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

final class OnboardingEligibilityService: @unchecked Sendable {
    let stateStore: AppOnboardingStateStore
    let launchArguments: Set<String>
    let fetchLifeAreas: () async throws -> [LifeArea]
    let fetchProjects: () async throws -> [Project]
    let fetchTasks: () async throws -> [TaskDefinition]

    init(
        stateStore: AppOnboardingStateStore = .shared,
        launchArguments: [String] = ProcessInfo.processInfo.arguments,
        fetchLifeAreas: @escaping () async throws -> [LifeArea],
        fetchProjects: @escaping () async throws -> [Project],
        fetchTasks: @escaping () async throws -> [TaskDefinition]
    ) {
        self.stateStore = stateStore
        self.launchArguments = Set(launchArguments)
        self.fetchLifeAreas = fetchLifeAreas
        self.fetchProjects = fetchProjects
        self.fetchTasks = fetchTasks
    }

    convenience init(
        stateStore: AppOnboardingStateStore = .shared,
        lifeAreaRepository: LifeAreaRepositoryProtocol?,
        projectRepository: ProjectRepositoryProtocol?,
        taskRepository: TaskDefinitionRepositoryProtocol?,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.init(
            stateStore: stateStore,
            launchArguments: launchArguments,
            fetchLifeAreas: {
                guard let lifeAreaRepository else { return [] }
                return try await lifeAreaRepository.fetchAllAsync()
            },
            fetchProjects: {
                guard let projectRepository else { return [] }
                return try await projectRepository.fetchAllProjectsAsync()
            },
            fetchTasks: {
                guard let taskRepository else { return [] }
                return try await taskRepository.fetchAllAsync()
            }
        )
    }

    /// Whether the harness asked for onboarding to be skipped outright.
    ///
    /// Exposed separately because `evaluate()` is not the only path to
    /// presentation: resuming an interrupted journey short-circuits ahead of it,
    /// and used to bypass this argument entirely, so a seeded run that had
    /// stored a partial journey would present onboarding despite
    /// `-SKIP_ONBOARDING`. Every presentation path has to consult one policy,
    /// and that policy lives here rather than being restated at each call site.
    var isSuppressedByLaunchArgument: Bool {
        launchArguments.contains("-SKIP_ONBOARDING")
    }

    func evaluate(version: Int = AppOnboardingState.currentVersion) async -> OnboardingEligibility {
        if isSuppressedByLaunchArgument {
            return .suppressed
        }

        let state = stateStore.load()
        // Anyone who has finished setup stays finished, whatever version they
        // finished. Comparing against the current version alone meant every
        // version bump re-presented onboarding to established users; re-running
        // setup is only ever a deliberate act via Settings, which clears this
        // state outright.
        if state.completedVersion != nil, state.outcome != nil {
            return .suppressed
        }
        if state.completedVersion == version {
            return .suppressed
        }

        let snapshot: OnboardingWorkspaceSnapshot
        do {
            async let lifeAreasTask = fetchLifeAreas()
            async let projectsTask = fetchProjects()
            async let tasksTask = fetchTasks()
            let lifeAreas = try await lifeAreasTask
            let projects = try await projectsTask
            let tasks = try await tasksTask
            snapshot = OnboardingWorkspaceSnapshot(
                customLifeAreaCount: lifeAreas.filter(StarterWorkspaceCatalog.isCustomLifeArea).count,
                customProjectCount: projects.filter(StarterWorkspaceCatalog.isCustomProject).count,
                taskCount: tasks.count
            )
        } catch {
            logOnboardingError(
                event: "onboarding_eligibility_failed",
                message: "Failed to inspect workspace for onboarding eligibility",
                fields: ["error": error.localizedDescription]
            )
            return .suppressed
        }

        if snapshot.isEffectivelyEmpty {
            return .fullFlow(snapshot)
        }

        if state.establishedWorkspacePromptDismissedVersion == version {
            return .suppressed
        }

        return .promptOnly(snapshot)
    }
}
