import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingOutcome: String, Codable, Equatable {
    case completed
    case skippedAfterWelcome
}
