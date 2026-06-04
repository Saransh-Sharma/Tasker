import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingHabitTemplateState: Equatable {
    case idle
    case creating
    case created(UUID)
    case failed(String)
}
