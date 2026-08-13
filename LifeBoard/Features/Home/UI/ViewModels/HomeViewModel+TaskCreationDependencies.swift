//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    public func createTaskDefinition(
        request: CreateTaskDefinitionRequest,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let createdTask):
                    self?.enqueueReload(
                        source: "create_task_definition",
                        reason: .created,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(createdTask))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes createTagForTaskDetail.

    public func createTagForTaskDetail(
        name: String,
        completion: @escaping @Sendable (Result<TagDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.manageTags.create(name: name, color: nil, icon: nil) { [weak self] result in
            Task { @MainActor in
                if case .success(let createdTag) = result {
                    self?.upsertTag(createdTag)
                }
                completion(result)
            }
        }
    }

    /// Executes createProjectForTaskDetail.

    public func createProjectForTaskDetail(
        name: String,
        completion: @escaping @Sendable (Result<Project, Error>) -> Void
    ) {
        useCaseCoordinator.manageProjects.createProject(request: CreateProjectRequest(name: name)) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let project):
                    self?.loadProjects()
                    completion(.success(project))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

}
