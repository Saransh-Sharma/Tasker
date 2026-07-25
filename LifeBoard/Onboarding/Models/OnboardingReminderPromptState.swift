import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingReminderPromptState: Equatable {
    case hidden
    case prompt
    case openSettings
}

enum OnboardingHealthPermissionState: Equatable {
    case ready
    case requesting
    case completed
    case skipped
}
