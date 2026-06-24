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
    public func loadProjects() {
        loadProjects(generation: nextReloadGeneration())
    }

    /// Executes loadProjects.

    func loadProjects(generation: Int, completion: (@Sendable () -> Void)? = nil) {
        let interval = LifeBoardPerformanceTrace.begin("HomeLoadProjects")
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            let preparedResult = result.map { projectsWithStats in
                projectsWithStats.map { $0.project }
            }
            Task { @MainActor in
                defer { LifeBoardPerformanceTrace.end(interval) }
                defer { completion?() }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=projects generation=\(generation)")
                    return
                }
                switch preparedResult {
                case .success(let loadedProjects):
                    self.assignIfChanged(\.projects, loadedProjects)
                    self.normalizeCustomProjectOrderIfNeeded(from: loadedProjects)

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadLifeAreas.

    func loadLifeAreas(generation: Int) {
        useCaseCoordinator.manageLifeAreas.list { [weak self] result in
            let preparedResult = result.map { loadedLifeAreas in
                loadedLifeAreas
                    .filter { !$0.isArchived }
                    .sorted {
                        if $0.sortOrder != $1.sortOrder {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
            }
            Task { @MainActor in
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else { return }

                switch preparedResult {
                case .success(let sortedLifeAreas):
                    self.assignIfChanged(\.lifeAreas, sortedLifeAreas)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadTags.

    func loadTags(generation: Int, completion: (@Sendable () -> Void)? = nil) {
        let interval = LifeBoardPerformanceTrace.begin("HomeLoadTags")
        useCaseCoordinator.manageTags.list { [weak self] result in
            let preparedResult = result.map { loadedTags in
                loadedTags.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
            Task { @MainActor in
                defer { LifeBoardPerformanceTrace.end(interval) }
                defer { completion?() }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=tags generation=\(generation)")
                    return
                }

                switch preparedResult {
                case .success(let sortedTags):
                    self.assignIfChanged(\.tags, sortedTags)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clears task-related cache entries to force fresh reads.

}
