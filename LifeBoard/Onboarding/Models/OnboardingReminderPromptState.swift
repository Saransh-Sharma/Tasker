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
