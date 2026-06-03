import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingInputField: Hashable {
    case workingStyle
    case workBlocker
    case outcome(Int)
}
