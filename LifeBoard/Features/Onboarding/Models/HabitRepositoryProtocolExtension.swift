import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension HabitRepositoryProtocol {
    func fetchAllAsync() async throws -> [HabitDefinitionRecord] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }
}
