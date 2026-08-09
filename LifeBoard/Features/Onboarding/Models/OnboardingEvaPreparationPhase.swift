import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingEvaPreparationPhase: String, Codable, Equatable {
    case idle
    case waitingForCellularConsent
    case downloading
    case ready
    case deferred
    case failed
}
