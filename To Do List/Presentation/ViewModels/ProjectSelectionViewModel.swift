import Foundation
import Combine
import SwiftUI

public final class ProjectSelectionViewModel: ObservableObject {
    @Published var availableProjects: [ProjectInfo] = []
    @Published var isLoading = true

    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol

    init(taskRepository: TaskRepositoryProtocol, projectRepository: ProjectRepositoryProtocol) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
    }

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
                self.taskRepository.fetchAllTasks { taskResult in
                    let allTasks = (try? taskResult.get()) ?? []
                    let taskCountsByProject = allTasks.reduce(into: [UUID: Int]()) { counts, task in
                        counts[task.projectID, default: 0] += 1
                    }

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
