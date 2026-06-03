import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingEvaPreparationState: Codable, Equatable {
    var phase: OnboardingEvaPreparationPhase = .idle
    var selectedModelName: String?
    var progress: Double = 0
    var cellularConsentGranted = false
    var statusMessage: String?

    var isReady: Bool {
        phase == .ready
    }
}
