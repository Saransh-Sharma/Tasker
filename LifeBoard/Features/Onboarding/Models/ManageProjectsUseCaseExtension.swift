import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension ManageProjectsUseCase {
    func createProjectAsync(request: CreateProjectRequest) async throws -> Project {
        try await withCheckedThrowingContinuation { continuation in
            createProject(request: request) { result in
                switch result {
                case .success(let project):
                    continuation.resume(returning: project)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
