import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension TaskDefinitionRepositoryProtocol {
    func fetchAllAsync() async throws -> [TaskDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchTaskDefinitionAsync(id: UUID) async throws -> TaskDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            fetchTaskDefinition(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }
}
