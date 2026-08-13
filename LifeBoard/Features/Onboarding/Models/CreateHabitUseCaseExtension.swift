import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension CreateHabitUseCase {
    func executeAsync(request: CreateHabitRequest) async throws -> HabitDefinitionRecord {
        try await withCheckedThrowingContinuation { continuation in
            execute(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }
}
