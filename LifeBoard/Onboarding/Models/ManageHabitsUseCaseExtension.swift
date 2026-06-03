import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension ManageHabitsUseCase {
    func listAsync() async throws -> [HabitDefinitionRecord] {
        try await withCheckedThrowingContinuation { continuation in
            list { result in
                continuation.resume(with: result)
            }
        }
    }
}
