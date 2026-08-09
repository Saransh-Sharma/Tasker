import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension CompleteTaskDefinitionUseCase {
    func setCompletionAsync(taskID: UUID, to isComplete: Bool) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            setCompletion(taskID: taskID, to: isComplete) { result in
                continuation.resume(with: result)
            }
        }
    }
}
