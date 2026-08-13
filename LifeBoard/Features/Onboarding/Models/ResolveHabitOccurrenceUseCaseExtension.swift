import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension ResolveHabitOccurrenceUseCase {
    func executeAsync(
        habitID: UUID,
        action: HabitOccurrenceAction,
        on date: Date = Date(),
        mutationContext: HabitMutationContext? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            execute(habitID: habitID, action: action, on: date, mutationContext: mutationContext) { result in
                continuation.resume(with: result)
            }
        }
    }
}
