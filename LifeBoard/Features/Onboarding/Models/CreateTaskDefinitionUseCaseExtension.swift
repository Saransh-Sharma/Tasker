import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension CreateTaskDefinitionUseCase {
    func executeAsync(request: CreateTaskDefinitionRequest) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            execute(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }
}
