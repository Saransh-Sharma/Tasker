import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension CalendarIntegrationService {
    func requestAccessAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAccess(source: "onboarding") { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
