import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension LifeAreaRepositoryProtocol {
    func fetchAllAsync() async throws -> [LifeArea] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }
}
