import Foundation
import Combine
import SwiftUI

public final class ProjectSelectionViewModel: ObservableObject {
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
    func load(completion: @escaping ([ProjectInfo]) -> Void) {
        isLoading = true
        projectRepository.fetchCustomProjects { [weak self] projectResult in
            guard let self else { return }
            switch projectResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    logError("❌ [ProjectSelectionSheet] Failed to load projects: \(error.localizedDescription)")
                    self.availableProjects = []
                    withAnimation {
                        self.isLoading = false
                    }
                    completion([])
                }
            case .success(let projects):
                guard let readModel = self.readModelRepository else {
                    DispatchQueue.main.async {
                        logError("❌ [ProjectSelectionSheet] Task read-model repository is not configured")
                        self.availableProjects = []
                        withAnimation {
                            self.isLoading = false
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

                    DispatchQueue.main.async {
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
