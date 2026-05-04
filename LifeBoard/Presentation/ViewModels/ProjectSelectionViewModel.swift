import Foundation
import Combine
import SwiftUI

@MainActor
public final class ProjectSelectionViewModel: ObservableObject, @unchecked Sendable {
    @Published var availableProjects: [ProjectInfo] = []
    @Published var isLoading = true

    private let projectRepository: ProjectRepositoryProtocol
    private let readModelRepository: TaskReadModelRepositoryProtocol?

    /// Initializes a new instance.
    init(
        projectRepository: ProjectRepositoryProtocol,
        readModelRepository: TaskReadModelRepositoryProtocol? = nil
    ) {
        self.projectRepository = projectRepository
        self.readModelRepository = readModelRepository
    }

    /// Executes load.
    func load(completion: @escaping @MainActor @Sendable ([ProjectInfo]) -> Void) {
        isLoading = true
        let readModelRepository = self.readModelRepository
        projectRepository.fetchCustomProjects { [readModelRepository] projectResult in
            switch projectResult {
            case .failure(let error):
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    logError("❌ [ProjectSelectionSheet] Failed to load projects: \(message)")
                    self?.availableProjects = []
                    withAnimation {
                        self?.isLoading = false
                    }
                    completion([])
                }
            case .success(let projects):
                guard let readModel = readModelRepository else {
                    Task { @MainActor [weak self] in
                        logError("❌ [ProjectSelectionSheet] Task read-model repository is not configured")
                        self?.availableProjects = []
                        withAnimation {
                            self?.isLoading = false
                        }
                        completion([])
                    }
                    return
                }

                readModel.fetchProjectTaskCounts(includeCompleted: true) { countResult in
                    let taskCountsByProject = (try? countResult.get()) ?? [:]
                    let infos = projects
                        .filter { $0.id != ProjectConstants.inboxProjectID }
                        .map { project in
                            ProjectInfo(
                                id: project.id,
                                name: project.name,
                                taskCount: taskCountsByProject[project.id, default: 0]
                            )
                        }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                    Task { @MainActor in
                        self.availableProjects = infos
                        withAnimation {
                            self.isLoading = false
                        }
                        completion(infos)
                    }
                }
            }
        }
    }
}
